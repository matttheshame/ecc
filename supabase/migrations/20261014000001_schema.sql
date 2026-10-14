-- Brusk — schema. Spec: fiche produit v0.1, §4 (founding principles), §6 (routing).
-- Principles enforced here, not just in the app:
--   * a report is a place + a type + a time; no person data columns exist at all;
--   * identity (e-mail) lives only in auth.users, never in public tables;
--   * exact points are never readable by anyone but their author (RLS + RPCs);
--   * thresholds are data (app_settings), tunable during the MVP without a redeploy.

create extension if not exists postgis with schema extensions;
create extension if not exists pgcrypto with schema extensions;

set search_path = public, extensions;

-- ── Types ────────────────────────────────────────────────────────────────────────────
create type public.report_category as enum ('road', 'cleanliness', 'insecurity', 'harassment');
create type public.report_status   as enum ('pending', 'confirmed', 'sent', 'resolved');
create type public.app_language    as enum ('fr', 'nl', 'en');
create type public.walk_status     as enum ('active', 'arrived', 'alerted', 'cancelled');
create type public.flag_reason     as enum ('personal_data', 'offensive', 'wrong_place', 'other');

-- ── Tunable thresholds (spec §4.2: "seuils à calibrer pendant le MVP") ─────────────────
create table public.app_settings (
  key         text primary key,
  value       numeric not null,
  description text not null
);

insert into public.app_settings (key, value, description) values
  ('min_distinct_users',        3,    'Distinct people (reporters ∪ confirmers) needed before a cell becomes a visible zone'),
  ('min_trust_weight',          1.0,  'Summed trust weight of those people needed before a cell becomes visible'),
  ('window_days',               30,   'Reports older than this no longer count towards confirming a cell'),
  ('hex_edge_m',                120,  'Edge length of the hexagonal cells, in metres (Belgian Lambert 72)'),
  ('max_reports_per_day',       10,   'Rate limit per user'),
  ('max_confirmations_per_day', 50,   'Rate limit per user'),
  ('max_flags_per_day',         20,   'Rate limit per user'),
  ('confirm_radius_m',          1500, 'A confirmation must come from within this distance of the report'),
  ('nearby_radius_m',           1000, 'Radius of the "around me" list'),
  ('nearby_days',               7,    'Age limit of the "around me" list'),
  ('score_radius_m',            500,  'Radius used for the neighbourhood score'),
  ('retention_months',          12,   'Reports are anonymised after this many months'),
  ('walk_grace_minutes',        5,    'Delay after the expected arrival before the walk contact is alerted');

create or replace function public.setting(p_key text)
returns numeric
language sql
stable
set search_path = public, pg_temp
as $$
  select value from public.app_settings where key = p_key
$$;

-- ── Communes (19). Geometry imported from UrbIS (see README), nullable until then ──────
create table public.communes (
  nis_code text primary key,
  name_fr  text not null,
  name_nl  text not null,
  geom     extensions.geometry(MultiPolygon, 31370)
);
create index communes_geom_idx on public.communes using gist (geom);

-- ── Profiles: no name, no handle, nothing public ─────────────────────────────────────────
create table public.profiles (
  id                   uuid primary key references auth.users (id) on delete cascade,
  created_at           timestamptz not null default now(),
  language             public.app_language not null default 'fr',
  trust_weight         real not null default 0.30 check (trust_weight between 0.10 and 1.00),
  validated_reports    integer not null default 0 check (validated_reports >= 0),
  useful_confirmations integer not null default 0 check (useful_confirmations >= 0),
  moderation_strikes   integer not null default 0 check (moderation_strikes >= 0),
  is_restricted        boolean not null default false
);

-- ── Reports: a place + a type + a time (spec §4.3) ───────────────────────────────────────
create table public.reports (
  id           uuid primary key default gen_random_uuid(),
  author_id    uuid references public.profiles (id) on delete set null,
  category     public.report_category not null,
  location     extensions.geometry(Point, 31370) not null,
  hex_i        integer not null,
  hex_j        integer not null,
  commune_code text references public.communes (nis_code),
  occurred_at  timestamptz not null,
  created_at   timestamptz not null default now(),
  note         text check (note is null or char_length(note) <= 140),
  photo_path   text,
  status       public.report_status not null default 'pending',
  confirmed_at timestamptz,
  routed_to    text,
  routed_at    timestamptz,
  resolved_at  timestamptz
);
create index reports_cell_idx     on public.reports (category, hex_i, hex_j, created_at desc);
create index reports_location_idx on public.reports using gist (location);
create index reports_author_idx   on public.reports (author_id, created_at desc);
create index reports_status_idx   on public.reports (status, created_at desc);

-- ── Neighbour confirmations (spec §4.2, §5 écran 3) ──────────────────────────────────────
create table public.confirmations (
  report_id  uuid not null references public.reports (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (report_id, user_id)
);
create index confirmations_user_idx on public.confirmations (user_id, created_at desc);

-- ── Routing (spec §6). Serious categories have no rule: never sent automatically ────────
create table public.routing_rules (
  category    public.report_category primary key,
  destination text not null
);
insert into public.routing_rules (category, destination) values
  ('cleanliness', 'bruxelles_proprete'),
  ('road',        'commune');

create table public.outbox (
  id          bigint generated always as identity primary key,
  report_id   uuid not null references public.reports (id) on delete cascade,
  destination text not null,
  created_at  timestamptz not null default now(),
  sent_at     timestamptz,
  attempts    integer not null default 0,
  last_error  text,
  unique (report_id)
);

-- ── Moderation (App Store UGC rules, spec §8) ─────────────────────────────────────────────
create table public.content_flags (
  id         bigint generated always as identity primary key,
  flagger_id uuid references public.profiles (id) on delete set null,
  category   public.report_category not null,
  hex_i      integer not null,
  hex_j      integer not null,
  reason     public.flag_reason not null,
  created_at timestamptz not null default now(),
  handled_at timestamptz,
  unique (flagger_id, category, hex_i, hex_j)
);

-- ── "Je rentre seul·e" (spec §5 écran 4). Last position only, purged after 24 h ──────────
create table public.walk_sessions (
  id                  uuid primary key default gen_random_uuid(),
  owner_id            uuid not null references public.profiles (id) on delete cascade,
  share_token         text not null unique default encode(extensions.gen_random_bytes(24), 'hex'),
  contact_email       text not null check (contact_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]{2,}$'),
  language            public.app_language not null default 'fr',
  started_at          timestamptz not null default now(),
  expected_arrival_at timestamptz not null,
  last_lat            double precision,
  last_lon            double precision,
  last_seen_at        timestamptz,
  status              public.walk_status not null default 'active',
  alerted_at          timestamptz,
  ended_at            timestamptz,
  check (expected_arrival_at <= started_at + interval '3 hours')
);
create index walk_sessions_due_idx on public.walk_sessions (status, expected_arrival_at);
create unique index walk_sessions_one_active on public.walk_sessions (owner_id) where status = 'active';
