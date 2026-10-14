-- Privacy guarantees (spec §4.1, §4.3) and the walk-home lifecycle (spec §5 écran 4).
begin;
select plan(17);

select tests.create_user('a@example.org') as a \gset
select tests.create_user('b@example.org') as b \gset
select tests.create_user('c@example.org') as c \gset

select tests.act_as(:'a');
select public.submit_report('00000000-0000-4000-8000-0000000000a1', 'cleanliness', 50.84701, 4.35277, now(), 'Dépôt devant le n°12', null);
select is(
  (select round(lat::numeric, 5) from public.my_reports() where id = '00000000-0000-4000-8000-0000000000a1'),
  50.84701, 'the author gets their exact coordinates back');
reset role;

-- The neighbour only ever sees the cell centre and a rounded distance.
select tests.act_as(:'b');
select isnt(
  (select round(center_lat::numeric, 5) from public.nearby_reports(50.8466, 4.3530)),
  50.84701, 'nearby_reports returns the cell centre, not the exact point');
select is((select distance_m % 50 from public.nearby_reports(50.8466, 4.3530)), 0, 'distances are rounded to 50 m');
select is((select extract(minute from occurred_at)::integer from public.nearby_reports(50.8466, 4.3530)), 0, 'times are rounded to the hour');
reset role;

-- Zones expose no author, note or photo.
select is_empty(
  $$ select attname from pg_attribute
     where attrelid = (select prorettype from pg_proc where proname = 'get_zones')::regclass
       and attname in ('author_id', 'note', 'photo_path') $$,
  'get_zones has no author, note or photo column');
select is(
  (select string_agg(parameter_name, ',' order by ordinal_position) from information_schema.parameters
   where specific_name like 'get_zones%' and parameter_mode = 'OUT'),
  'category,hex_i,hex_j,outline,center_lat,center_lon,confirmed_count,intensity,trend,unresolved_since,resolved_count,latest_at,commune_code',
  'get_zones returns aggregate columns only');

-- Account deletion: notes and photo paths go, the anonymous fact stays for the counts.
delete from auth.users where id = :'a';
select is((select count(*)::integer from public.profiles where id = :'a'), 0, 'the profile is deleted with the auth user');
select is((select author_id from public.reports where id = '00000000-0000-4000-8000-0000000000a1'), null::uuid, 'the report is detached from the person');
select is((select note from public.reports where id = '00000000-0000-4000-8000-0000000000a1'), null, 'the note is erased');

-- Retention: anonymise after 12 months.
update public.reports set created_at = now() - interval '13 months', author_id = :'b', note = 'old note'
where id = '00000000-0000-4000-8000-0000000000a1';
select tests.act_as_service();
select is((select count(*)::integer from public.reports_to_anonymise()), 1, 'reports older than 12 months are listed for anonymisation');
select is(public.anonymise_reports(array['00000000-0000-4000-8000-0000000000a1'::uuid]), 1, 'and anonymised');
reset role;

-- Walk home: start, ping, public view, overdue alert exactly once, purge.
select tests.act_as(:'c');
select (public.start_walk('friend@example.org', now() + interval '20 minutes', 'nl') ->> 'share_token') as token \gset
select public.walk_ping(id, 50.85, 4.35) from public.walk_sessions;
select throws_ok($$ select public.start_walk('friend@example.org', now() + interval '4 hours', 'nl') $$,
  'P0001', 'BRUSK_INVALID_TIME', 'a walk cannot last more than 3 hours');
reset role;

select tests.act_as_service();
select is((public.walk_public_view(:'token') ->> 'last_lat')::numeric, 50.85, 'the contact sees the last position while active');
reset role;
update public.walk_sessions set expected_arrival_at = now() - interval '6 minutes', started_at = now() - interval '30 minutes';
select tests.act_as_service();
select is((select count(*)::integer from public.claim_overdue_walks()), 1, 'an overdue walk is claimed for alerting');
select is((select count(*)::integer from public.claim_overdue_walks()), 0, 'and never twice');
reset role;

select tests.act_as(:'c');
select public.walk_end(id, true) from public.walk_sessions;
reset role;
select tests.act_as_service();
select is(public.walk_public_view(:'token') ->> 'last_lat', null, 'after arrival the position is hidden');
reset role;
update public.walk_sessions set ended_at = now() - interval '25 hours';
select tests.act_as_service();
select is(public.purge_walks(), 1, 'walk data is purged 24 hours after the end');
reset role;

select * from finish();
rollback;
