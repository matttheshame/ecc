-- Brusk — row-level security and privileges. Deny by default.
-- Public data is only ever reachable through aggregate RPCs (get_zones, zone_detail).
set search_path = public, extensions;

-- ── RLS on every table ─────────────────────────────────────────────────────────────────────
alter table public.app_settings  enable row level security;
alter table public.communes      enable row level security;
alter table public.profiles      enable row level security;
alter table public.reports       enable row level security;
alter table public.confirmations enable row level security;
alter table public.routing_rules enable row level security;
alter table public.outbox        enable row level security;
alter table public.content_flags enable row level security;
alter table public.walk_sessions enable row level security;

-- Reference data, readable by everyone.
create policy communes_read on public.communes for select to anon, authenticated using (true);

-- Own rows only. No insert/update/delete policies on reports, confirmations, profiles:
-- writes go through the SECURITY DEFINER functions, which validate everything.
create policy profiles_own   on public.profiles      for select to authenticated using (id = (select auth.uid()));
create policy reports_own    on public.reports       for select to authenticated using (author_id = (select auth.uid()));
create policy confirms_own   on public.confirmations for select to authenticated using (user_id = (select auth.uid()));
create policy walks_own      on public.walk_sessions for select to authenticated using (owner_id = (select auth.uid()));
-- app_settings, routing_rules, outbox, content_flags: no client policy at all.

-- ── Table privileges ───────────────────────────────────────────────────────────────────────
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
grant select on public.communes to anon, authenticated;
grant select on public.profiles, public.reports, public.confirmations, public.walk_sessions to authenticated;
revoke all on public.moderation_queue from anon, authenticated;

-- ── Function privileges: explicit allow-list ────────────────────────────────────────────────
revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function public.get_zones(integer, public.report_category[], text)               to anon, authenticated;
grant execute on function public.zone_detail(public.report_category, integer, integer)           to anon, authenticated;
grant execute on function public.submit_report(uuid, public.report_category, double precision, double precision, timestamptz, text, text) to authenticated;
grant execute on function public.nearby_reports(double precision, double precision)              to authenticated;
grant execute on function public.confirm_report(uuid, double precision, double precision)        to authenticated;
grant execute on function public.my_reports()                                                    to authenticated;
grant execute on function public.delete_my_report(uuid)                                          to authenticated;
grant execute on function public.my_trust()                                                      to authenticated;
grant execute on function public.set_language(public.app_language)                               to authenticated;
grant execute on function public.flag_zone(public.report_category, integer, integer, public.flag_reason) to authenticated;
grant execute on function public.start_walk(text, timestamptz, public.app_language)              to authenticated;
grant execute on function public.walk_ping(uuid, double precision, double precision)             to authenticated;
grant execute on function public.walk_extend(uuid, timestamptz)                                  to authenticated;
grant execute on function public.walk_end(uuid, boolean)                                         to authenticated;

grant execute on function public.walk_public_view(text)                                         to service_role;
grant execute on function public.claim_overdue_walks()                                          to service_role;
grant execute on function public.purge_walks()                                                  to service_role;
grant execute on function public.reports_to_anonymise()                                         to service_role;
grant execute on function public.anonymise_reports(uuid[])                                      to service_role;
grant execute on function public.mark_dispatched(bigint, text)                                  to service_role;
grant execute on function public.mark_cell_resolved(public.report_category, integer, integer)   to service_role;
grant execute on function public.add_moderation_strike(uuid, boolean)                           to service_role;
grant execute on function public.report_point_for_service(uuid)                                 to service_role;

-- Future functions are not executable by clients unless granted explicitly.
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
