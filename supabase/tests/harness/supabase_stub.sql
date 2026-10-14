-- Minimal stand-in for the Supabase platform, so migrations and tests run on a plain
-- Postgres + PostGIS (CI, laptops without Docker). On real Supabase, skip this file:
-- `supabase db reset && supabase test db` uses the genuine auth/storage schemas.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end
$$;

create schema if not exists extensions;
create schema if not exists auth;
create schema if not exists storage;
grant usage on schema public, extensions, auth, storage to anon, authenticated, service_role;

create table if not exists auth.users (
  id                 uuid primary key,
  email              text,
  raw_user_meta_data jsonb default '{}'::jsonb,
  created_at         timestamptz default now()
);

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid
$$;
grant execute on function auth.uid() to anon, authenticated, service_role;

create table if not exists storage.buckets (
  id                 text primary key,
  name               text not null,
  public             boolean default false,
  file_size_limit    bigint,
  allowed_mime_types text[]
);

create table if not exists storage.objects (
  id        uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets (id),
  name      text not null,
  owner     uuid
);
alter table storage.objects enable row level security;
grant select, insert, delete on storage.objects to authenticated;

create or replace function storage.foldername(name text)
returns text[]
language sql
immutable
as $$
  select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
$$;
grant execute on function storage.foldername(text) to anon, authenticated, service_role;

-- Supabase's default grants: every new object in public is granted to the API roles.
-- The migrations must revoke what clients should not have; mirroring the defaults here
-- makes those revokes actually tested instead of passing trivially.
alter default privileges in schema public grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
