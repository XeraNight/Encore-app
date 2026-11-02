-- KSIS without verification (decided 31 Oct 2026). Without documents nobody can check an identity remotely, so most
-- dancers would wait forever and their connections would never see their results. A dancer who picks themselves in
-- the KSIS members list is that dancer. Several accounts may pick the same number: results are public in KSIS
-- anyway, and one account per number without verification would let whoever comes first lock out the real dancer.
-- On a report the owner unlinks or bans a fake account. Replaces the verification of 20261025_ksis_dancer_identity.sql,
-- owner_set_dancer of 20261029_owner_console.sql and all of 20261029b_ksis_vouch_in_person.sql.
-- Deploy the ksis-page function without the status first: the one before reads the column dropped here.

-- 1. Verification goes: in person, by the partner and by the owner.
drop function public.vouch_dancer(text);
drop function public.peek_verify_code(text);
drop function public.open_verify_code();
drop function public.vouch_target(text);
drop table public.ksis_verify_codes;
drop function public.confirm_partner(uuid);
drop function public.my_partner_waiting();
drop function public.owner_set_dancer(uuid, text);
drop index public.ksis_dancers_one_verified;
alter table public.ksis_dancers
  drop column status, drop column verified_by, drop column verified_at, drop column verified_how;

-- 2. Connections see the results of whoever shares them (still opt-in, off by default).
create or replace function public.shares_results_with(p_owner uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = p_owner and p.shares_results)
     and exists (
       select 1 from public.connections c
        where c.status = 'accepted' and c.relationship_type in ('connection', 'partner')
          and ((c.user_a_id = (select auth.uid()) and c.user_b_id = p_owner)
            or (c.user_b_id = (select auth.uid()) and c.user_a_id = p_owner)));
$$;

-- 3. The owner unlinks a dancer (a fake account, a wrong pick) with their couples and results, as picking another
--    dancer does (ksis-page); the account can find itself again.
create function public.owner_unlink_dancer(p_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_number integer;
begin
  if not public.is_app_owner() then
    raise exception 'Only the owner unlinks' using errcode = '42501';
  end if;
  delete from public.ksis_dancers where user_id = p_user returning person_number into v_number;
  if v_number is null then
    raise exception 'No dancer to unlink' using errcode = 'P0002';
  end if;
  delete from public.competition_results where user_id = p_user;
  delete from public.user_couples where user_id = p_user;
  perform public.log_owner_action(p_user, 'unlink_dancer', 'KSIS č. ' || v_number);
end $$;
revoke execute on function public.owner_unlink_dancer(uuid) from public, anon;
grant execute on function public.owner_unlink_dancer(uuid) to authenticated;

alter table public.owner_actions drop constraint owner_actions_action_check;
alter table public.owner_actions add constraint owner_actions_action_check check (action in (
  'grant_plan', 'ban', 'unban', 'unlink_dancer', 'remove_connection', 'remove_couple', 'delete_account'));

-- 4. The console: the card tells how many other accounts picked the same number (a fake shows up there),
--    the overview counts accounts linked to KSIS.
create or replace function public.owner_user_card(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_card jsonb;
begin
  if not public.is_app_owner() then
    raise exception 'Only the owner reads' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'email_confirmed', u.email_confirmed_at is not null,
    'providers', coalesce(u.raw_app_meta_data -> 'providers', '[]'::jsonb),
    'created_at', u.created_at,
    'last_sign_in_at', u.last_sign_in_at,
    'app_version', p.app_version,
    'dancer', (
      select jsonb_build_object('person_number', d.person_number, 'name', d.name, 'club', d.club,
                                'other_accounts', (select count(*) from public.ksis_dancers o
                                                    where o.person_number = d.person_number and o.user_id <> p_user))
        from public.ksis_dancers d
       where d.user_id = p_user),
    'couples', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'pair_number', c.pair_number, 'partner_names', c.partner_names, 'is_current', c.is_current,
               'results', (select count(*) from public.competition_results r
                            where r.user_id = p_user and r.couple_id = c.couple_id and not r.is_deleted))
             order by c.is_current desc, c.created_at desc)
        from public.user_couples c where c.user_id = p_user), '[]'::jsonb),
    'connections', coalesce((
      select jsonb_agg(jsonb_build_object('id', c.id, 'name', coalesce(o.name, o.full_name, ''),
                                          'type', c.relationship_type, 'status', c.status)
             order by c.created_at desc)
        from public.connections c
        left join public.profiles o on o.id = case when c.user_a_id = p_user then c.user_b_id else c.user_a_id end
       where p_user in (c.user_a_id, c.user_b_id) and c.status in ('pending', 'accepted')), '[]'::jsonb),
    'routines', (select count(*) from public.routines where user_id = p_user),
    'figures', (select count(*) from public.canvas_nodes n join public.routines r on r.id = n.routine_id where r.user_id = p_user),
    'records', coalesce((
      select jsonb_object_agg(k.kind, k.n)
        from (select kind, count(*) as n from public.device_records where user_id = p_user and not deleted group by kind) k),
      '{}'::jsonb),
    'last_sync', greatest(
      (select max(updated_at) from public.routines where user_id = p_user),
      (select max(updated_at) from public.device_records where user_id = p_user)),
    'actions', coalesce((
      select jsonb_agg(jsonb_build_object('action', a.action, 'detail', a.detail, 'created_at', a.created_at)
             order by a.created_at desc)
        from (select * from public.owner_actions where target_user_id = p_user order by created_at desc limit 10) a),
      '[]'::jsonb))
    into v_card
    from auth.users u left join public.profiles p on p.id = u.id
   where u.id = p_user;
  if v_card is null then
    raise exception 'No such user' using errcode = 'P0002';
  end if;
  return v_card;
end $$;

create or replace function public.owner_overview()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_app_owner() then
    raise exception 'Only the owner reads' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'users', (select count(*) from auth.users),
    'new_this_week', (select count(*) from auth.users where created_at > now() - interval '7 days'),
    'dancers', (select count(*) from public.ksis_dancers),
    'plus', (select count(*) from public.user_entitlements where tier = 'plus' and (expires_at is null or expires_at > now())),
    'premium', (select count(*) from public.user_entitlements where tier = 'premium' and (expires_at is null or expires_at > now())));
end $$;
