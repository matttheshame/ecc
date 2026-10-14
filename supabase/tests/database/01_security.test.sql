-- Deny-by-default: RLS everywhere, no public access to raw reports, no identity columns.
begin;
select plan(14);

select is(
  (select count(*)::integer from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  0, 'every public table has row-level security enabled');

select is_empty(
  $$ select table_name || '.' || column_name from information_schema.columns
     where table_schema = 'public'
       and column_name ~* '^(.*_)?(name|first_name|last_name|full_name|nickname|pseudo|username|email|phone|phone_number|address|birth.*|gender|description)$'
       and (table_name, column_name) not in (('walk_sessions', 'contact_email'), ('communes', 'name_fr'), ('communes', 'name_nl'), ('app_settings', 'description')) $$,
  'no person-identifying columns in public tables (contact_email is per walk and purged)');

-- Fixture: one user with one report.
select tests.create_user('a@example.org') as a \gset
select tests.create_user('b@example.org') as b \gset
select tests.act_as(:'a');
select lives_ok(
  $$ select public.submit_report(gen_random_uuid(), 'road', 50.8467, 4.3525, now(), 'Nid-de-poule au milieu de la piste', null) $$,
  'a signed-in user can submit a report');
reset role;

-- Anonymous visitors.
select tests.act_as_anon();
select throws_ok($$ select * from public.reports $$, '42501', null, 'anon cannot read raw reports');
select throws_ok($$ select * from public.profiles $$, '42501', null, 'anon cannot read profiles');
select lives_ok($$ select * from public.get_zones(30, null, null) $$, 'anon can read aggregated zones');
select throws_ok(
  $$ select public.submit_report(gen_random_uuid(), 'road', 50.8467, 4.3525, now(), null, null) $$,
  '42501', null, 'anon cannot submit');
select lives_ok($$ select * from public.communes $$, 'anon can read the commune list');
reset role;

-- Another user sees nothing of A's.
select tests.act_as(:'b');
select is((select count(*)::integer from public.reports), 0, 'B cannot see A''s report (RLS)');
select is((select count(*)::integer from public.my_reports()), 0, 'my_reports() is scoped to the caller');
select throws_ok($$ select * from public.outbox $$, '42501', null, 'clients cannot read the routing queue');
select throws_ok($$ select * from public.moderation_queue $$, '42501', null, 'clients cannot read the moderation queue');
select throws_ok($$ select public.mark_cell_resolved('road', 0, 0) $$, '42501', null, 'clients cannot resolve cells');
reset role;

select tests.act_as(:'a');
select is((select count(*)::integer from public.reports), 1, 'A sees their own report');
reset role;

select * from finish();
rollback;
