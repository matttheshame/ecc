-- Brusk — functions for edge functions (service role only) and moderators.
set search_path = public, extensions;

-- Public walk page (edge function walk-view). Exposes the last position only while the
-- walk is active or alerted, and the final status for one hour after it ends.
create or replace function public.walk_public_view(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'status', w.status,
    'language', w.language,
    'expected_arrival_at', w.expected_arrival_at,
    'last_seen_at', case when w.status in ('active', 'alerted') then w.last_seen_at end,
    'last_lat', case when w.status in ('active', 'alerted') then w.last_lat end,
    'last_lon', case when w.status in ('active', 'alerted') then w.last_lon end)
  from public.walk_sessions w
  where w.share_token = p_token
    and (w.ended_at is null or w.ended_at > now() - interval '1 hour')
$$;

-- Walks whose arrival was not confirmed in time (edge function walk-watchdog).
-- Marks them alerted atomically so a contact is never e-mailed twice.
create or replace function public.claim_overdue_walks()
returns table (
  id                  uuid,
  contact_email       text,
  language            public.app_language,
  share_token         text,
  expected_arrival_at timestamptz,
  last_lat            double precision,
  last_lon            double precision,
  last_seen_at        timestamptz
)
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.walk_sessions w
  set status = 'alerted', alerted_at = now()
  where w.status = 'active'
    and w.expected_arrival_at + make_interval(mins => public.setting('walk_grace_minutes')::integer) < now()
  returning w.id, w.contact_email, w.language, w.share_token, w.expected_arrival_at, w.last_lat, w.last_lon, w.last_seen_at
$$;

-- Daily maintenance (edge function maintenance): purge walks, list reports to anonymise.
create or replace function public.purge_walks()
returns integer
language sql
security definer
set search_path = public, pg_temp
as $$
  with gone as (
    delete from public.walk_sessions
    where (ended_at is not null and ended_at < now() - interval '24 hours')
       or started_at < now() - interval '27 hours'
    returning 1
  )
  select count(*)::integer from gone
$$;

create or replace function public.reports_to_anonymise()
returns table (id uuid, photo_path text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select r.id, r.photo_path
  from public.reports r
  where r.created_at < now() - make_interval(months => public.setting('retention_months')::integer)
    and (r.author_id is not null or r.note is not null or r.photo_path is not null)
  limit 1000
$$;

create or replace function public.anonymise_reports(p_ids uuid[])
returns integer
language sql
security definer
set search_path = public, pg_temp
as $$
  with done as (
    update public.reports set author_id = null, note = null, photo_path = null
    where id = any (p_ids)
    returning 1
  )
  select count(*)::integer from done
$$;

-- Routing queue (edge function dispatch-outbox).
create or replace function public.mark_dispatched(p_outbox_id bigint, p_error text default null)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_report uuid;
  v_destination text;
begin
  if p_error is not null then
    update public.outbox set attempts = attempts + 1, last_error = p_error where id = p_outbox_id;
    return;
  end if;
  update public.outbox set sent_at = now(), attempts = attempts + 1, last_error = null
  where id = p_outbox_id
  returning report_id, destination into v_report, v_destination;
  update public.reports
  set status = 'sent', routed_to = v_destination, routed_at = now()
  where id = v_report and status = 'confirmed';
end
$$;

-- Moderators: mark a cell resolved once the service confirms the fix.
create or replace function public.mark_cell_resolved(p_category public.report_category, p_hex_i integer, p_hex_j integer)
returns integer
language sql
security definer
set search_path = public, pg_temp
as $$
  with done as (
    update public.reports set status = 'resolved', resolved_at = now()
    where category = p_category and hex_i = p_hex_i and hex_j = p_hex_j and status <> 'resolved'
    returning 1
  )
  select count(*)::integer from done
$$;

-- Moderators: confirmed abuse lowers the author's trust (spec §8, serial accounts).
create or replace function public.add_moderation_strike(p_user uuid, p_restrict boolean default false)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.profiles
  set moderation_strikes = moderation_strikes + 1, is_restricted = is_restricted or p_restrict
  where id = p_user;
  select public.recompute_trust(p_user);
$$;

-- Moderation queue: flagged cells, personal-data flags first, with the notes to review.
create or replace view public.moderation_queue
with (security_invoker = true)
as
select f.category, f.hex_i, f.hex_j,
       count(*)                                          as flags,
       count(*) filter (where f.reason = 'personal_data') as personal_data_flags,
       min(f.created_at)                                 as first_flagged_at,
       (select array_agg(r.note) filter (where r.note is not null)
        from public.reports r
        where r.category = f.category and r.hex_i = f.hex_i and r.hex_j = f.hex_j) as notes
from public.content_flags f
where f.handled_at is null
group by f.category, f.hex_i, f.hex_j
order by personal_data_flags desc, flags desc, first_flagged_at;

-- Exact point of a confirmed, routable report, for the service that must fix it
-- (edge function dispatch-outbox). Never callable by clients.
create or replace function public.report_point_for_service(p_report_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
  select jsonb_build_object(
    'lat', round(ST_Y(ST_Transform(r.location, 4326))::numeric, 6),
    'lon', round(ST_X(ST_Transform(r.location, 4326))::numeric, 6))
  from public.reports r
  join public.routing_rules rr on rr.category = r.category
  where r.id = p_report_id and r.status in ('confirmed', 'sent')
$$;
