-- Brusk — storage bucket, scheduled jobs, reference data.
set search_path = public, extensions;

-- ── Storage: private bucket for anonymised photos ──────────────────────────────────────────
-- Path convention: <user id>/<report id>.jpg. Only the owner can write or read their
-- folder; services get time-limited signed URLs from the dispatch function.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('report-photos', 'report-photos', false, 3145728, array['image/jpeg'])
on conflict (id) do nothing;

create policy photos_insert_own on storage.objects for insert to authenticated
  with check (bucket_id = 'report-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy photos_select_own on storage.objects for select to authenticated
  using (bucket_id = 'report-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy photos_delete_own on storage.objects for delete to authenticated
  using (bucket_id = 'report-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ── Scheduled jobs (pg_cron + pg_net call the edge functions) ───────────────────────────────
-- Requires the pg_cron and pg_net extensions (Dashboard → Database → Extensions) and two
-- Vault secrets: project_url and service_role_key. See README "Scheduled jobs".
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from pg_extension where extname = 'pg_net') then
    perform cron.schedule('brusk-walk-watchdog', '* * * * *', $job$
      select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/walk-watchdog',
        headers := jsonb_build_object('Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')))
    $job$);
    perform cron.schedule('brusk-dispatch-outbox', '*/5 * * * *', $job$
      select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/dispatch-outbox',
        headers := jsonb_build_object('Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')))
    $job$);
    perform cron.schedule('brusk-maintenance', '17 3 * * *', $job$
      select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/maintenance',
        headers := jsonb_build_object('Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')))
    $job$);
  else
    raise notice 'pg_cron/pg_net not enabled: schedule walk-watchdog, dispatch-outbox and maintenance manually (README).';
  end if;
end
$$;

-- ── The 19 communes (NIS codes, official FR/NL names). Geometry: import from UrbIS ──────────
insert into public.communes (nis_code, name_fr, name_nl) values
  ('21001', 'Anderlecht', 'Anderlecht'),
  ('21002', 'Auderghem', 'Oudergem'),
  ('21003', 'Berchem-Sainte-Agathe', 'Sint-Agatha-Berchem'),
  ('21004', 'Bruxelles', 'Brussel'),
  ('21005', 'Etterbeek', 'Etterbeek'),
  ('21006', 'Evere', 'Evere'),
  ('21007', 'Forest', 'Vorst'),
  ('21008', 'Ganshoren', 'Ganshoren'),
  ('21009', 'Ixelles', 'Elsene'),
  ('21010', 'Jette', 'Jette'),
  ('21011', 'Koekelberg', 'Koekelberg'),
  ('21012', 'Molenbeek-Saint-Jean', 'Sint-Jans-Molenbeek'),
  ('21013', 'Saint-Gilles', 'Sint-Gillis'),
  ('21014', 'Saint-Josse-ten-Noode', 'Sint-Joost-ten-Node'),
  ('21015', 'Schaerbeek', 'Schaarbeek'),
  ('21016', 'Uccle', 'Ukkel'),
  ('21017', 'Watermael-Boitsfort', 'Watermaal-Bosvoorde'),
  ('21018', 'Woluwe-Saint-Lambert', 'Sint-Lambrechts-Woluwe'),
  ('21019', 'Woluwe-Saint-Pierre', 'Sint-Pieters-Woluwe')
on conflict (nis_code) do nothing;
