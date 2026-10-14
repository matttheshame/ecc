-- Test helpers: create users and act as them, the way PostgREST does with a JWT.
create schema if not exists tests;

create or replace function tests.create_user(p_email text, p_language text default 'fr', p_age interval default interval '0')
returns uuid
language plpgsql
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, email, raw_user_meta_data) values (v_id, p_email, jsonb_build_object('language', p_language));
  update public.profiles set created_at = now() - p_age where id = v_id;
  return v_id;
end
$$;

-- Switch to the `authenticated` role with the given user as JWT subject.
create or replace function tests.act_as(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end
$$;

create or replace function tests.act_as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'set local role anon';
end
$$;

create or replace function tests.act_as_service()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'set local role service_role';
end
$$;

grant usage on schema tests to anon, authenticated, service_role;
grant execute on all functions in schema tests to anon, authenticated, service_role;
