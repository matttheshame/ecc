-- Input validation and rate limits in submit_report (spec §4.3, §8).
begin;
select plan(11);

select tests.create_user('a@example.org') as a \gset
select tests.create_user('b@example.org') as b \gset
select tests.act_as(:'a');

select throws_ok($$ select public.submit_report(gen_random_uuid(), 'road', 48.8566, 2.3522, now(), null, null) $$,
  'P0001', 'BRUSK_OUTSIDE_BRUSSELS', 'reports outside the region are refused');
select throws_ok($$ select public.submit_report(gen_random_uuid(), 'road', 50.8467, 4.3525, now() + interval '1 hour', null, null) $$,
  'P0001', 'BRUSK_INVALID_TIME', 'future times are refused');
select throws_ok($$ select public.submit_report(gen_random_uuid(), 'road', 50.8467, 4.3525, now() - interval '8 days', null, null) $$,
  'P0001', 'BRUSK_INVALID_TIME', 'facts older than 7 days are refused');
select throws_ok($$ select public.submit_report(gen_random_uuid(), 'road', 50.8467, 4.3525, now(), 'Appelez le 0470 12 34 56', null) $$,
  'P0001', 'BRUSK_TEXT_POLICY', 'phone numbers in notes are refused');
select throws_ok($$ select public.submit_report(gen_random_uuid(), 'road', 50.8467, 4.3525, now(), 'voiture 1-ABC-123 sur la piste', null) $$,
  'P0001', 'BRUSK_TEXT_POLICY', 'licence plates in notes are refused');
select throws_ok($$ select public.submit_report(gen_random_uuid(), 'road', 50.8467, 4.3525, now(), repeat('a', 141), null) $$,
  'P0001', 'BRUSK_TEXT_POLICY', 'notes longer than 140 characters are refused');
select lives_ok($$ select public.submit_report(gen_random_uuid(), 'cleanliness', 50.8467, 4.3525, now(), 'Sacs noirs éventrés depuis le 01/10', null) $$,
  'a normal note about a place is accepted');
select throws_ok(
  format($$ select public.submit_report(gen_random_uuid(), 'road', 50.8467, 4.3525, now(), null, '%s/00000000-0000-4000-8000-000000000001.jpg') $$, :'b'),
  'P0001', 'BRUSK_INVALID_PHOTO', 'a photo path in someone else''s folder is refused');
select lives_ok(
  format($$ select public.submit_report('00000000-0000-4000-8000-000000000001', 'road', 50.8467, 4.3525, now(), null, '%s/00000000-0000-4000-8000-000000000001.jpg') $$, :'a'),
  'a photo path in the caller''s own folder is accepted');

-- 10 per day: 2 already made above, 8 more pass, the 11th fails.
select lives_ok($$ select public.submit_report(gen_random_uuid(), 'road', 50.8467, 4.3525, now(), null, null) from generate_series(1, 8) $$,
  'up to 10 reports per day');
select throws_ok($$ select public.submit_report(gen_random_uuid(), 'road', 50.8467, 4.3525, now(), null, null) $$,
  'P0001', 'BRUSK_RATE_LIMIT', 'the 11th report of the day is refused');
reset role;

select * from finish();
rollback;
