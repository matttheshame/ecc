-- Brusk — the RPC surface used by the app. Every write goes through these functions:
-- one place validates geography, time, text, rate limits, then applies thresholds.
-- Errors are raised as BRUSK_* codes that the app maps to localized messages.
set search_path = public, extensions;

-- ── Map: aggregated, confirmed zones only (spec §4.3: zones, not points) ─────────────────
create or replace function public.get_zones(
  p_period_days integer default 30,
  p_categories  public.report_category[] default null,
  p_commune     text default null
)
returns table (
  category         public.report_category,
  hex_i            integer,
  hex_j            integer,
  outline          jsonb,
  center_lat       double precision,
  center_lon       double precision,
  confirmed_count  integer,
  intensity        double precision,
  trend            integer,
  unresolved_since timestamptz,
  resolved_count   integer,
  latest_at        timestamptz,
  commune_code     text
)
language sql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
  with visible as (
    select r.category, r.hex_i, r.hex_j, r.status, r.created_at, r.commune_code
    from public.reports r
    where r.status <> 'pending'
      and r.created_at > now() - make_interval(days => least(greatest(coalesce(p_period_days, 30), 1), 365))
      and (p_categories is null or r.category = any (p_categories))
      and (p_commune is null or r.commune_code = p_commune)
  ), cells as (
    select v.category, v.hex_i, v.hex_j,
           count(*)::integer                                          as confirmed_count,
           (count(*) filter (where v.status = 'resolved'))::integer   as resolved_count,
           min(v.created_at) filter (where v.status <> 'resolved')    as unresolved_since,
           max(v.created_at)                                          as latest_at,
           mode() within group (order by v.commune_code)              as commune_code
    from visible v
    group by v.category, v.hex_i, v.hex_j
  )
  select c.category, c.hex_i, c.hex_j,
         ST_AsGeoJSON(ST_Transform(public.cell_polygon(c.hex_i, c.hex_j), 4326), 6)::jsonb,
         ST_Y(g.center), ST_X(g.center),
         c.confirmed_count,
         c.confirmed_count::double precision / greatest(max(c.confirmed_count) over (), 1),
         t.trend,
         c.unresolved_since, c.resolved_count, c.latest_at, c.commune_code
  from cells c
  cross join lateral (
    select ST_Transform(ST_Centroid(public.cell_polygon(c.hex_i, c.hex_j)), 4326) as center
  ) g
  cross join lateral (
    -- Trend: last 30 days against the 30 before, independent of the period filter.
    select case
             when recent > previous * 1.25 + 1 then 1
             when recent * 1.25 + 1 < previous then -1
             else 0
           end as trend
    from (
      select count(*) filter (where r.created_at > now() - interval '30 days') as recent,
             count(*) filter (where r.created_at <= now() - interval '30 days'
                                and r.created_at >  now() - interval '60 days') as previous
      from public.reports r
      where r.category = c.category and r.hex_i = c.hex_i and r.hex_j = c.hex_j and r.status <> 'pending'
    ) counts
  ) t
$$;

-- ── Zone sheet: weekly counts and neighbourhood score ─────────────────────────────────────
create or replace function public.zone_detail(p_category public.report_category, p_hex_i integer, p_hex_j integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_zone     jsonb;
  v_weekly   jsonb;
  v_center   extensions.geometry := ST_Centroid(public.cell_polygon(p_hex_i, p_hex_j));
  v_radius   double precision := public.setting('score_radius_m');
  v_local    numeric;
  v_total    numeric;
  v_expected numeric;
  v_score    integer;
begin
  select to_jsonb(z) into v_zone
  from public.get_zones(365, array[p_category], null) z
  where z.hex_i = p_hex_i and z.hex_j = p_hex_j;
  if v_zone is null then
    raise exception 'BRUSK_NOT_FOUND';
  end if;

  select jsonb_agg(n order by w desc) into v_weekly
  from (
    select w, (select count(*) from public.reports r
               where r.category = p_category and r.hex_i = p_hex_i and r.hex_j = p_hex_j
                 and r.status <> 'pending'
                 and r.created_at >  now() - make_interval(weeks => w + 1)
                 and r.created_at <= now() - make_interval(weeks => w))::integer as n
    from generate_series(7, 0, -1) as w
  ) weeks;

  -- Neighbourhood score, 0–100, higher is calmer: open confirmed reports of this
  -- category within the radius over 30 days, against what an average circle of the
  -- same size in Brussels (≈ 162 km²) would hold. Calibrate during the MVP.
  select count(*) into v_local
  from public.reports r
  where r.category = p_category and r.status in ('confirmed', 'sent')
    and r.created_at > now() - interval '30 days'
    and ST_DWithin(r.location, v_center, v_radius);
  select count(*) into v_total
  from public.reports r
  where r.category = p_category and r.status in ('confirmed', 'sent')
    and r.created_at > now() - interval '30 days';
  v_expected := greatest(v_total * (pi() * v_radius * v_radius) / 162000000.0, 0.5);
  v_score := round(100.0 / (1 + v_local / v_expected));

  return jsonb_build_object('zone', v_zone, 'weekly_counts', v_weekly, 'neighbourhood_score', v_score);
end
$$;

-- ── Create a report (spec §5 écran 2) ─────────────────────────────────────────────────────
create or replace function public.submit_report(
  p_id          uuid,
  p_category    public.report_category,
  p_lat         double precision,
  p_lon         double precision,
  p_occurred_at timestamptz,
  p_note        text default null,
  p_photo_path  text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_profile public.profiles;
  v_note    text := nullif(btrim(p_note), '');
  v_report  public.reports;
begin
  if v_uid is null then raise exception 'BRUSK_NOT_AUTHENTICATED'; end if;
  select * into v_profile from public.profiles where id = v_uid;
  if v_profile.id is null or v_profile.is_restricted then raise exception 'BRUSK_RATE_LIMIT'; end if;

  if p_lat is null or p_lon is null or p_lat not between 50.76 and 50.92 or p_lon not between 4.24 and 4.49 then
    raise exception 'BRUSK_OUTSIDE_BRUSSELS';
  end if;
  if p_occurred_at is null or p_occurred_at > now() + interval '5 minutes' or p_occurred_at < now() - interval '7 days' then
    raise exception 'BRUSK_INVALID_TIME';
  end if;
  if v_note is not null and (char_length(v_note) > 140 or public.text_violates_policy(v_note)) then
    raise exception 'BRUSK_TEXT_POLICY';
  end if;
  if p_photo_path is not null and p_photo_path !~ ('^' || v_uid::text || '/[0-9a-f-]{36}\.jpg$') then
    raise exception 'BRUSK_INVALID_PHOTO';
  end if;
  if (select count(*) from public.reports where author_id = v_uid and created_at > now() - interval '1 day')
       >= public.setting('max_reports_per_day') then
    raise exception 'BRUSK_RATE_LIMIT';
  end if;

  insert into public.reports (id, author_id, category, location, occurred_at, note, photo_path)
  values (
    coalesce(p_id, gen_random_uuid()), v_uid, p_category,
    ST_Transform(ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326), 31370),
    p_occurred_at, v_note, p_photo_path
  )
  returning * into v_report;

  perform public.refresh_cell(v_report.category, v_report.hex_i, v_report.hex_j);

  select * into v_report from public.reports where id = v_report.id;
  return jsonb_build_object('id', v_report.id, 'status', v_report.status);
end
$$;

-- ── Around me: recent reports the caller can confirm (one per cell, cell centre only) ───
create or replace function public.nearby_reports(p_lat double precision, p_lon double precision)
returns table (
  id            uuid,
  category      public.report_category,
  center_lat    double precision,
  center_lon    double precision,
  distance_m    integer,
  occurred_at   timestamptz,
  confirmations integer
)
language sql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
  with me as (
    select ST_Transform(ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326), 31370) as point
  ), candidates as (
    select distinct on (r.category, r.hex_i, r.hex_j)
           r.id, r.category, r.hex_i, r.hex_j, r.occurred_at,
           ST_Distance(r.location, me.point) as distance
    from public.reports r, me
    where auth.uid() is not null
      and r.status in ('pending', 'confirmed')
      and r.created_at > now() - make_interval(days => public.setting('nearby_days')::integer)
      and r.author_id is distinct from auth.uid()
      and ST_DWithin(r.location, me.point, public.setting('nearby_radius_m')::double precision)
      and not exists (select 1 from public.confirmations c where c.report_id = r.id and c.user_id = auth.uid())
      -- Already involved in this cell (own report or confirmation): nothing to add.
      and not exists (
        select 1 from public.reports m
        where m.category = r.category and m.hex_i = r.hex_i and m.hex_j = r.hex_j
          and m.created_at > now() - make_interval(days => public.setting('window_days')::integer)
          and (m.author_id = auth.uid()
               or exists (select 1 from public.confirmations c2 where c2.report_id = m.id and c2.user_id = auth.uid()))
      )
    order by r.category, r.hex_i, r.hex_j, r.created_at desc
  )
  select c.id, c.category,
         ST_Y(ST_Transform(ST_Centroid(public.cell_polygon(c.hex_i, c.hex_j)), 4326)),
         ST_X(ST_Transform(ST_Centroid(public.cell_polygon(c.hex_i, c.hex_j)), 4326)),
         greatest(50, (round(c.distance / 50.0) * 50))::integer,
         date_trunc('hour', c.occurred_at),
         (select count(*) from public.confirmations x where x.report_id = c.id)::integer
  from candidates c
  order by c.distance
  limit 30
$$;

-- ── One-tap confirmation (spec §5 écran 3) ────────────────────────────────────────────────
create or replace function public.confirm_report(p_report_id uuid, p_lat double precision, p_lon double precision)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid    uuid := auth.uid();
  v_report public.reports;
  v_here   extensions.geometry;
  v_shown  boolean;
begin
  if v_uid is null then raise exception 'BRUSK_NOT_AUTHENTICATED'; end if;
  if exists (select 1 from public.profiles where id = v_uid and is_restricted) then raise exception 'BRUSK_RATE_LIMIT'; end if;
  if (select count(*) from public.confirmations where user_id = v_uid and created_at > now() - interval '1 day')
       >= public.setting('max_confirmations_per_day') then
    raise exception 'BRUSK_RATE_LIMIT';
  end if;

  select * into v_report from public.reports where id = p_report_id;
  if v_report.id is null or v_report.status = 'resolved'
     or v_report.created_at < now() - make_interval(days => public.setting('window_days')::integer) then
    raise exception 'BRUSK_NOT_FOUND';
  end if;
  if v_report.author_id = v_uid then raise exception 'BRUSK_ALREADY_CONFIRMED'; end if;

  v_here := ST_Transform(ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326), 31370);
  if not ST_DWithin(v_report.location, v_here, public.setting('confirm_radius_m')::double precision) then
    raise exception 'BRUSK_TOO_FAR';
  end if;

  insert into public.confirmations (report_id, user_id) values (p_report_id, v_uid)
  on conflict do nothing;
  if not found then raise exception 'BRUSK_ALREADY_CONFIRMED'; end if;

  v_shown := public.refresh_cell(v_report.category, v_report.hex_i, v_report.hex_j);
  return jsonb_build_object('ok', true, 'zone_visible', v_shown);
end
$$;

-- ── The caller's own data ─────────────────────────────────────────────────────────────────
create or replace function public.my_reports()
returns table (
  id            uuid,
  category      public.report_category,
  lat           double precision,
  lon           double precision,
  occurred_at   timestamptz,
  created_at    timestamptz,
  status        public.report_status,
  routed_to     text,
  note          text,
  has_photo     boolean,
  confirmations integer
)
language sql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
  select r.id, r.category,
         ST_Y(ST_Transform(r.location, 4326)), ST_X(ST_Transform(r.location, 4326)),
         r.occurred_at, r.created_at, r.status, r.routed_to, r.note, r.photo_path is not null,
         (select count(*) from public.confirmations c where c.report_id = r.id)::integer
  from public.reports r
  where r.author_id = auth.uid()
  order by r.created_at desc
$$;

create or replace function public.delete_my_report(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'BRUSK_NOT_AUTHENTICATED'; end if;
  delete from public.reports where id = p_id and author_id = auth.uid();
end
$$;

create or replace function public.my_trust()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'trust_weight', p.trust_weight,
    'validated_reports', p.validated_reports,
    'useful_confirmations', p.useful_confirmations)
  from public.profiles p
  where p.id = auth.uid()
$$;

create or replace function public.set_language(p_language public.app_language)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.profiles set language = p_language where id = auth.uid()
$$;

-- ── Moderation flag on a zone (App Store UGC) ─────────────────────────────────────────────
create or replace function public.flag_zone(p_category public.report_category, p_hex_i integer, p_hex_j integer, p_reason public.flag_reason)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'BRUSK_NOT_AUTHENTICATED'; end if;
  if (select count(*) from public.content_flags where flagger_id = auth.uid() and created_at > now() - interval '1 day')
       >= public.setting('max_flags_per_day') then
    raise exception 'BRUSK_RATE_LIMIT';
  end if;
  insert into public.content_flags (flagger_id, category, hex_i, hex_j, reason)
  values (auth.uid(), p_category, p_hex_i, p_hex_j, p_reason)
  on conflict (flagger_id, category, hex_i, hex_j) do nothing;
end
$$;

-- ── Walking home alone ─────────────────────────────────────────────────────────────────────
create or replace function public.start_walk(p_contact_email text, p_expected_arrival timestamptz, p_language public.app_language)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_session public.walk_sessions;
begin
  if auth.uid() is null then raise exception 'BRUSK_NOT_AUTHENTICATED'; end if;
  if p_expected_arrival <= now() or p_expected_arrival > now() + interval '3 hours' then
    raise exception 'BRUSK_INVALID_TIME';
  end if;
  -- One walk at a time: a new one cancels any forgotten session.
  update public.walk_sessions set status = 'cancelled', ended_at = now()
  where owner_id = auth.uid() and status = 'active';
  insert into public.walk_sessions (owner_id, contact_email, expected_arrival_at, language)
  values (auth.uid(), btrim(p_contact_email), p_expected_arrival, p_language)
  returning * into v_session;
  return jsonb_build_object('id', v_session.id, 'share_token', v_session.share_token);
end
$$;

create or replace function public.walk_ping(p_id uuid, p_lat double precision, p_lon double precision)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.walk_sessions
  set last_lat = p_lat, last_lon = p_lon, last_seen_at = now()
  where id = p_id and owner_id = auth.uid() and status in ('active', 'alerted')
$$;

create or replace function public.walk_extend(p_id uuid, p_expected_arrival timestamptz)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.walk_sessions
  set expected_arrival_at = least(p_expected_arrival, started_at + interval '3 hours')
  where id = p_id and owner_id = auth.uid() and status = 'active' and p_expected_arrival > now();
end
$$;

create or replace function public.walk_end(p_id uuid, p_arrived boolean)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.walk_sessions
  set status = case when p_arrived then 'arrived'::public.walk_status else 'cancelled'::public.walk_status end,
      ended_at = now()
  where id = p_id and owner_id = auth.uid() and status in ('active', 'alerted')
$$;
