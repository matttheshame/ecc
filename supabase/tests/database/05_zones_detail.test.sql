-- Zone payload, detail and filters as consumed by the app (Rows.swift).
begin;
select plan(10);

-- Lower the thresholds for this test only.
update public.app_settings set value = 1 where key in ('min_distinct_users');
update public.app_settings set value = 0.3 where key in ('min_trust_weight');

select tests.create_user('a@example.org') as a \gset
select tests.act_as(:'a');
select public.submit_report(gen_random_uuid(), 'cleanliness', 50.8330, 4.3450, now(), null, null);
reset role;

select tests.act_as_anon();
select is((select count(*)::integer from public.get_zones(7, null, null)), 1, 'a confirmed cell is listed');
select is((select outline ->> 'type' from public.get_zones(7, null, null)), 'Polygon', 'outline is GeoJSON');
select is((select jsonb_array_length(outline -> 'coordinates' -> 0) from public.get_zones(7, null, null)), 7, 'a closed hexagon ring (6 + 1 points)');
select ok((select center_lat between 50.832 and 50.834 and center_lon between 4.344 and 4.346 from public.get_zones(7, null, null)),
  'the centre is within the cell (WGS84)');
select is((select intensity from public.get_zones(7, null, null)), 1::double precision, 'intensity is relative to the busiest zone');
select is((select count(*)::integer from public.get_zones(7, array['road']::public.report_category[], null)), 0, 'category filter applies');
select is((select count(*)::integer from public.get_zones(7, null, '21009')), 0, 'commune filter applies');

select is(
  (select jsonb_array_length(public.zone_detail('cleanliness', hex_i, hex_j) -> 'weekly_counts') from public.get_zones(7, null, null)),
  8, 'zone_detail returns 8 weekly counts');
select ok(
  (select (public.zone_detail('cleanliness', hex_i, hex_j) ->> 'neighbourhood_score')::integer between 0 and 100 from public.get_zones(7, null, null)),
  'the neighbourhood score is between 0 and 100');
select throws_ok($$ select public.zone_detail('road', 0, 0) $$, 'P0001', 'BRUSK_NOT_FOUND', 'unknown or unconfirmed cells are not exposed');
reset role;

select * from finish();
rollback;
