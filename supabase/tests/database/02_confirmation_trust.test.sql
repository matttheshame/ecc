-- Spec §4.2: a zone appears only when several DIFFERENT people report the same type at
-- the same place; new accounts weigh little; confirmations raise trust.
begin;
select plan(25);

select tests.create_user('a@example.org') as a \gset
select tests.create_user('b@example.org') as b \gset
select tests.create_user('c@example.org') as c \gset
select tests.create_user('d@example.org') as d \gset
select tests.create_user('e@example.org') as e \gset

select is((select trust_weight from public.profiles where id = :'a'), 0.30::real, 'a new account starts at the lowest normal weight');

-- Three new accounts report the same thing within a few metres.
select tests.act_as(:'a');
select public.submit_report('00000000-0000-4000-8000-00000000000a', 'road', 50.84670, 4.35250, now(), null, null);
reset role;
select tests.act_as(:'b');
select public.submit_report('00000000-0000-4000-8000-00000000000b', 'road', 50.84672, 4.35253, now(), null, null);
reset role;

select is((select count(*)::integer from public.get_zones(30, null, null)), 0, 'two people are not enough: no zone yet');

select tests.act_as(:'c');
select public.submit_report('00000000-0000-4000-8000-00000000000c', 'road', 50.84668, 4.35248, now(), null, null);
reset role;

select is((select count(distinct (hex_i, hex_j))::integer from public.reports), 1, 'the three reports fall in the same cell');
select is((select count(*)::integer from public.get_zones(30, null, null)), 0,
  'three brand-new accounts (0.9 trust) cannot make a zone appear on their own');
select is((select status::text from public.reports where id = '00000000-0000-4000-8000-00000000000a'), 'pending', 'reports stay pending');

-- A fourth person confirms from nearby: threshold reached.
select tests.act_as(:'d');
select is((select count(*)::integer from public.nearby_reports(50.8466, 4.3526)), 1, 'D sees one item to confirm (one per cell)');
select is(
  (select (public.confirm_report('00000000-0000-4000-8000-00000000000a', 50.8466, 4.3526) ->> 'zone_visible')::boolean),
  true, 'D''s confirmation makes the zone visible');
select throws_ok($$ select public.confirm_report('00000000-0000-4000-8000-00000000000a', 50.8466, 4.3526) $$,
  'P0001', 'BRUSK_ALREADY_CONFIRMED', 'confirming twice is refused');
reset role;

select is((select count(*)::integer from public.reports where status = 'confirmed'), 3, 'all three reports are now confirmed');
select is((select confirmed_count from public.get_zones(30, null, null)), 3, 'the zone counts reports, not confirmations');
select is((select validated_reports from public.profiles where id = :'a'), 1, 'authors get credit for a confirmed report');
select is((select trust_weight from public.profiles where id = :'a'), 0.45::real, 'author trust rises to 0.45');
select is((select useful_confirmations from public.profiles where id = :'d'), 1, 'the confirmer gets credit');
select is((select trust_weight from public.profiles where id = :'d'), 0.35::real, 'confirmer trust rises to 0.35');

-- Routing (spec §6): road → commune queue.
select is((select count(*)::integer from public.outbox where destination = 'commune'), 3, 'confirmed road reports are queued for the commune');

select tests.act_as_service();
select ok((select (public.report_point_for_service('00000000-0000-4000-8000-00000000000a') ->> 'lat')::numeric between 50.846 and 50.848),
  'the service gets the exact point of a confirmed road report');
reset role;
select tests.act_as(:'d');
select throws_ok($$ select public.report_point_for_service('00000000-0000-4000-8000-00000000000a') $$, '42501', null,
  'clients can never call the service-only point lookup');
reset role;

-- Self-confirmation and distance rules.
select tests.act_as(:'a');
select throws_ok($$ select public.confirm_report('00000000-0000-4000-8000-00000000000a', 50.8467, 4.3525) $$,
  'P0001', 'BRUSK_ALREADY_CONFIRMED', 'nobody can confirm their own report');
reset role;
select tests.act_as(:'e');
select throws_ok($$ select public.confirm_report('00000000-0000-4000-8000-00000000000b', 50.8800, 4.4000) $$,
  'P0001', 'BRUSK_TOO_FAR', 'confirmations must come from nearby');
reset role;

-- Harassment follows the same threshold but is never routed automatically.
select tests.create_user('f@example.org', 'nl', interval '30 days') as f \gset
update public.profiles set validated_reports = 3 where id = :'f';
select public.recompute_trust(:'f');
select is((select trust_weight from public.profiles where id = :'f'), 0.85::real, 'an established, older account weighs 0.85');

select tests.act_as(:'a');
select public.submit_report(gen_random_uuid(), 'harassment', 50.8300, 4.3560, now(), null, null);
reset role;
select tests.act_as(:'b');
select public.submit_report(gen_random_uuid(), 'harassment', 50.8300, 4.3560, now(), null, null);
reset role;
select tests.act_as(:'f');
select public.submit_report(gen_random_uuid(), 'harassment', 50.8300, 4.3560, now(), null, null);
reset role;

select is((select count(*)::integer from public.get_zones(30, array['harassment']::public.report_category[], null)), 1,
  'two regular users + one established user make a harassment zone appear');
select is((select count(*)::integer from public.outbox o join public.reports r on r.id = o.report_id where r.category = 'harassment'), 0,
  'harassment is never sent to any service automatically');
select tests.act_as_service();
select is((select public.report_point_for_service(id) from public.reports where category = 'harassment' limit 1), null::jsonb,
  'no exact point is ever released for harassment');
reset role;

-- Categories are independent.
select is((select count(*)::integer from public.get_zones(30, array['cleanliness']::public.report_category[], null)), 0,
  'a road zone does not create a cleanliness zone');

-- Restricted accounts drop to the floor weight.
select public.add_moderation_strike(:'c', true);
select is((select trust_weight from public.profiles where id = :'c'), 0.10::real, 'a restricted account weighs 0.10');

select * from finish();
rollback;
