-- Brusk — server-side logic: cells, trust score, neighbour confirmation, routing queue.
set search_path = public, extensions;

-- ── New auth user → profile (language from sign-up metadata) ─────────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_language text := new.raw_user_meta_data ->> 'language';
begin
  insert into public.profiles (id, language)
  values (new.id, case when v_language in ('fr', 'nl', 'en') then v_language::public.app_language else 'fr' end)
  on conflict (id) do nothing;
  return new;
end
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Account deletion: anonymise before the profile disappears. Reports keep only
-- category/place/time so zone counts stay honest; notes and photo paths are erased.
create or replace function public.anonymise_before_profile_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.reports set note = null, photo_path = null where author_id = old.id;
  return old;
end
$$;

create trigger profiles_anonymise_reports
  before delete on public.profiles
  for each row execute function public.anonymise_before_profile_delete();

-- ── Cells: hexagons in Belgian Lambert 72 (metres) ───────────────────────────────────────
create or replace function public.cell_polygon(p_hex_i integer, p_hex_j integer)
returns extensions.geometry
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select ST_SetSRID(ST_Hexagon(public.setting('hex_edge_m')::float8, p_hex_i, p_hex_j), 31370)
$$;

create or replace function public.assign_report_cell()
returns trigger
language plpgsql
set search_path = public, extensions, pg_temp
as $$
declare
  v_cell record;
begin
  select h.i, h.j into v_cell
  from ST_HexagonGrid(public.setting('hex_edge_m')::float8, ST_Expand(new.location, 1)) as h
  where ST_Intersects(h.geom, new.location)
  order by h.i, h.j
  limit 1;
  new.hex_i := v_cell.i;
  new.hex_j := v_cell.j;
  if new.commune_code is null then
    select c.nis_code into new.commune_code
    from public.communes c
    where c.geom is not null and ST_Contains(c.geom, new.location)
    limit 1;
  end if;
  return new;
end
$$;

create trigger reports_assign_cell
  before insert or update of location on public.reports
  for each row execute function public.assign_report_cell();

-- ── Trust score (spec §4.2): new accounts weigh little; confirmations raise it ────────────
create or replace function public.recompute_trust(p_user uuid)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.profiles p
  set trust_weight = case
    when p.is_restricted then 0.10
    else least(1.00, greatest(0.10,
        0.30
      + 0.15 * p.validated_reports
      + 0.05 * p.useful_confirmations
      + case when p.created_at < now() - interval '14 days' then 0.10 else 0 end
      - 0.25 * p.moderation_strikes))
  end
  where p.id = p_user
$$;

-- ── Neighbour confirmation (spec §4.2) ────────────────────────────────────────────────────
-- A cell × category becomes visible (its reports turn 'confirmed') once enough DISTINCT
-- people — authors of recent reports there, plus people who confirmed them — with enough
-- summed trust are involved. Newly confirmed reports credit their authors and confirmers,
-- and road/cleanliness reports are queued for the responsible service.
create or replace function public.refresh_cell(p_category public.report_category, p_hex_i integer, p_hex_j integer)
returns boolean
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_since   timestamptz := now() - make_interval(days => public.setting('window_days')::integer);
  v_users   integer;
  v_weight  numeric;
  v_ids     uuid[];
begin
  with open_reports as (
    select r.id, r.author_id
    from public.reports r
    where r.category = p_category and r.hex_i = p_hex_i and r.hex_j = p_hex_j
      and r.status <> 'resolved' and r.created_at > v_since
  ), participants as (
    select o.author_id as user_id from open_reports o where o.author_id is not null
    union
    select c.user_id from public.confirmations c join open_reports o on o.id = c.report_id
  )
  select count(*), coalesce(sum(p.trust_weight), 0)
  into v_users, v_weight
  from participants x
  join public.profiles p on p.id = x.user_id;

  if v_users < public.setting('min_distinct_users') or v_weight < public.setting('min_trust_weight') then
    return false;
  end if;

  with newly as (
    update public.reports r
    set status = 'confirmed', confirmed_at = now()
    where r.category = p_category and r.hex_i = p_hex_i and r.hex_j = p_hex_j
      and r.status = 'pending' and r.created_at > v_since
    returning r.id
  )
  select coalesce(array_agg(id), '{}') into v_ids from newly;

  if cardinality(v_ids) > 0 then
    update public.profiles p
    set validated_reports = p.validated_reports + x.n
    from (select author_id, count(*)::integer as n from public.reports
          where id = any (v_ids) and author_id is not null group by author_id) x
    where p.id = x.author_id;

    update public.profiles p
    set useful_confirmations = p.useful_confirmations + x.n
    from (select user_id, count(*)::integer as n from public.confirmations
          where report_id = any (v_ids) group by user_id) x
    where p.id = x.user_id;

    perform public.recompute_trust(u.user_id)
    from (select author_id as user_id from public.reports where id = any (v_ids) and author_id is not null
          union
          select user_id from public.confirmations where report_id = any (v_ids)) u;

    insert into public.outbox (report_id, destination)
    select r.id, rr.destination
    from public.reports r
    join public.routing_rules rr on rr.category = r.category
    where r.id = any (v_ids)
    on conflict (report_id) do nothing;
  end if;

  return true;
end
$$;

-- ── Server-side text policy (spec §4.3, §8). The app applies a richer check first. ───────
create or replace function public.text_violates_policy(p_text text)
returns boolean
language sql
immutable
as $$
  select p_text ~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'                      -- e-mail
      or p_text ~* '(https?://|www\.)'                                           -- link
      or p_text ~* '(\+|00)[0-9]{2,3}[ .]?[0-9]([ ./-]?[0-9]){6,}'               -- international phone
      or p_text ~* '(^|[^0-9])0[1-9]([ ./-]?[0-9]){7,8}([^0-9]|$)'               -- Belgian phone
      or p_text ~* '\m[1-9][ -]?[a-z]{3}[ -]?[0-9]{3}\M'                         -- plate 1-ABC-123
      or p_text ~* '\m[a-z]{3}-?[0-9]{3}\M'                                      -- plate ABC-123
      or p_text ~* '(^|\s)@[a-z0-9_]{2,}'                                        -- @handle
$$;
