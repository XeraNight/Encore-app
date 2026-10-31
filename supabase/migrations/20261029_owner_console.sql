-- Owner console = full support control. Every owner action lands in owner_actions (who, whom, what, when). The
-- console shows counts and state, never the content of notes or diaries. Only the owner functions below write the
-- record (security definer), so neither the iPhone nor the owner can skip or erase an entry.

-- 1. The record. No foreign keys: an entry outlives the account it names.
create table public.owner_actions (
  id bigint generated always as identity primary key,
  owner_id uuid not null,
  target_user_id uuid,
  action text not null check (action in (
    'grant_plan', 'ban', 'unban', 'verify_dancer', 'unverify_dancer', 'unlink_dancer',
    'remove_connection', 'remove_couple', 'delete_account')),
  detail text,
  created_at timestamptz not null default now()
);
create index owner_actions_target_recent on public.owner_actions (target_user_id, created_at desc);
alter table public.owner_actions enable row level security;
revoke all on public.owner_actions from anon, authenticated;

create function public.log_owner_action(p_target uuid, p_action text, p_detail text default null)
returns void language sql security definer set search_path = '' as $$
  insert into public.owner_actions (owner_id, target_user_id, action, detail)
  values ((select auth.uid()), p_target, p_action, left(p_detail, 200));
$$;
revoke execute on function public.log_owner_action(uuid, text, text) from public, anon, authenticated;

-- A deleted account (Edge Function owner-delete-account) joins the same record.
create function public.owner_delete_log_to_actions()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.outcome = 'deleted' then
    insert into public.owner_actions (owner_id, target_user_id, action) values (new.owner_id, new.target_user_id, 'delete_account');
  end if;
  return new;
end $$;
revoke execute on function public.owner_delete_log_to_actions() from public, anon, authenticated;
create trigger owner_delete_log_to_actions after insert on public.owner_delete_log
  for each row execute function public.owner_delete_log_to_actions();

-- 2. Plans. One function for a gift by account or by e-mail; the direct write from the iPhone goes.
create function public.owner_grant_plan(p_user uuid, p_tier text, p_duration_months integer, p_note text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_tier text := lower(p_tier);
  v_expires timestamptz := case when p_duration_months > 0 then now() + make_interval(months => p_duration_months) end;
begin
  if not public.is_app_owner() then
    raise exception 'Only the owner grants' using errcode = '42501';
  end if;
  if v_tier not in ('free', 'plus', 'premium') then
    raise exception 'Unknown plan' using errcode = '22023';
  end if;
  insert into public.user_entitlements (user_id, tier, source, expires_at, granted_by, notes, updated_at)
  values (p_user, v_tier, 'owner_grant', v_expires, auth.uid(), p_note, now())
  on conflict (user_id) do update set
    tier = excluded.tier, source = excluded.source, expires_at = excluded.expires_at,
    granted_by = excluded.granted_by, notes = excluded.notes, updated_at = now();
  perform public.log_owner_action(p_user, 'grant_plan', initcap(v_tier) || case
    when v_tier = 'free' then ''
    when v_expires is null then ' navždy'
    else ' do ' || to_char(v_expires, 'FMDD. FMMM. YYYY') end);
end $$;

drop policy entitlements_owner_write on public.user_entitlements;

create or replace function public.admin_grant_entitlement_by_email(p_email text, p_tier text,
  p_duration_months integer default null, p_note text default 'VIP Darovanie od majiteľa')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_target uuid;
begin
  if not public.is_app_owner() then
    return jsonb_build_object('success', false, 'error_code', 'FORBIDDEN', 'message', 'Nemáš oprávnenie majiteľa aplikácie.');
  end if;
  if lower(p_tier) not in ('free', 'plus', 'premium') then
    return jsonb_build_object('success', false, 'error_code', 'BAD_TIER', 'message', 'Neplatná úroveň predplatného.');
  end if;
  select id into v_target from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if v_target is null then
    return jsonb_build_object('success', false, 'error_code', 'USER_NOT_FOUND',
                              'message', 'Používateľ ' || p_email || ' sa ešte nezaregistroval v Encore.');
  end if;
  perform public.owner_grant_plan(v_target, p_tier, p_duration_months, p_note);
  return jsonb_build_object('success', true, 'message', 'Plán ' || upper(p_tier) || ' bol úspešne udelený pre ' || p_email || '!');
end $$;

-- 3. Ban and unban, now written to the record (the body is otherwise the one from before).
create or replace function public.admin_set_account_status(p_user uuid, p_banned boolean, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_app_owner() then
    return jsonb_build_object('success', false, 'error_code', 'FORBIDDEN', 'message', 'Nemáš oprávnenie majiteľa aplikácie.');
  end if;
  if p_user = auth.uid() then
    return jsonb_build_object('success', false, 'error_code', 'SELF', 'message', 'Nemôžeš zablokovať vlastný účet.');
  end if;

  update public.profiles
     set account_status = case when p_banned then 'banned' else 'active' end,
         ban_reason     = case when p_banned then left(p_reason, 300) end
   where id = p_user;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'NOT_FOUND');
  end if;

  if p_banned then
    -- GoTrue refuses sign-in and token refresh for banned users; killing sessions ends them now.
    update auth.users set banned_until = now() + interval '100 years' where id = p_user;
    delete from auth.sessions where user_id = p_user;
  else
    update auth.users set banned_until = null where id = p_user;
  end if;

  perform public.log_owner_action(p_user, case when p_banned then 'ban' else 'unban' end,
                                  case when p_banned then p_reason end);
  return jsonb_build_object('success', true, 'banned', p_banned);
end $$;

-- 4. KSIS both ways: verify, take the verification back (the link stays, pending) or unlink the dancer (any status,
--    the account can find itself again). How each verified dancer got there: owner, partner or in person (vouch).
alter table public.ksis_dancers add column verified_how text check (verified_how in ('owner', 'partner', 'vouch'));
update public.ksis_dancers
   set verified_how = case when public.is_owner_account(verified_by) then 'owner' else 'partner' end
 where status = 'verified';

create function public.owner_set_dancer(p_user uuid, p_status text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_number integer;
begin
  if not public.is_app_owner() then
    raise exception 'Only the owner decides' using errcode = '42501';
  end if;
  if p_status = 'none' then
    delete from public.ksis_dancers where user_id = p_user returning person_number into v_number;
  elsif p_status in ('verified', 'pending') then
    update public.ksis_dancers
       set status = p_status,
           verified_by = case when p_status = 'verified' then auth.uid() end,
           verified_at = case when p_status = 'verified' then now() end,
           verified_how = case when p_status = 'verified' then 'owner' end,
           updated_at = now()
     where user_id = p_user and status <> p_status
    returning person_number into v_number;
  else
    raise exception 'Unknown status' using errcode = '22023';
  end if;
  if v_number is null then
    raise exception 'Nothing to change' using errcode = 'P0002';
  end if;
  perform public.log_owner_action(p_user,
    case p_status when 'verified' then 'verify_dancer' when 'pending' then 'unverify_dancer' else 'unlink_dancer' end,
    'KSIS č. ' || v_number);
end $$;

drop function public.owner_decide_dancer(uuid, boolean);

create or replace function public.confirm_partner(p_partner uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := (select auth.uid());
begin
  if not exists (select 1 from public.ksis_dancers where user_id = v_me and status = 'verified') then
    raise exception 'Only a verified dancer confirms' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.user_couples mine
      join public.user_couples theirs on theirs.pair_number = mine.pair_number and theirs.side <> mine.side
     where mine.user_id = v_me and mine.is_current and theirs.user_id = p_partner and theirs.is_current) then
    raise exception 'Not the partner of your current couple' using errcode = '42501';
  end if;
  update public.ksis_dancers
     set status = 'verified', verified_by = v_me, verified_at = now(), verified_how = 'partner', updated_at = now()
   where user_id = p_partner and status = 'pending';
  if not found then
    raise exception 'No pending dancer to confirm' using errcode = 'P0002';
  end if;
end $$;

-- 5. Removing a connection (the same "revoked" the app writes) or a couple with its results.
create function public.owner_remove_connection(p_user uuid, p_connection uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_type text;
begin
  if not public.is_app_owner() then
    raise exception 'Only the owner removes' using errcode = '42501';
  end if;
  update public.connections set status = 'revoked', updated_at = now()
   where id = p_connection and p_user in (user_a_id, user_b_id) and status in ('pending', 'accepted')
  returning relationship_type into v_type;
  if v_type is null then
    raise exception 'No such connection' using errcode = 'P0002';
  end if;
  perform public.log_owner_action(p_user, 'remove_connection', v_type);
end $$;

create function public.owner_remove_couple(p_user uuid, p_couple uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_couple public.user_couples%rowtype;
begin
  if not public.is_app_owner() then
    raise exception 'Only the owner removes' using errcode = '42501';
  end if;
  delete from public.user_couples where id = p_couple and user_id = p_user returning * into v_couple;
  if v_couple.id is null then
    raise exception 'No such couple' using errcode = 'P0002';
  end if;
  if v_couple.couple_id is not null then
    delete from public.competition_results where user_id = p_user and couple_id = v_couple.couple_id;
  end if;
  perform public.log_owner_action(p_user, 'remove_couple', 'pár č. ' || lpad(v_couple.pair_number::text, 5, '0'));
end $$;

-- 6. What the console reads: one user's card (state and counts, no content), the overview and the record.
create function public.owner_user_card(p_user uuid)
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
      select jsonb_build_object('person_number', d.person_number, 'name', d.name, 'club', d.club, 'status', d.status,
                                'verified_how', d.verified_how, 'verified_at', d.verified_at,
                                'verified_by_name', coalesce(v.name, v.full_name))
        from public.ksis_dancers d left join public.profiles v on v.id = d.verified_by
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

create function public.owner_overview()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_app_owner() then
    raise exception 'Only the owner reads' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'users', (select count(*) from auth.users),
    'new_this_week', (select count(*) from auth.users where created_at > now() - interval '7 days'),
    'verified', (select count(*) from public.ksis_dancers where status = 'verified'),
    'plus', (select count(*) from public.user_entitlements where tier = 'plus' and (expires_at is null or expires_at > now())),
    'premium', (select count(*) from public.user_entitlements where tier = 'premium' and (expires_at is null or expires_at > now())));
end $$;

create function public.owner_recent_actions()
returns table (action text, detail text, created_at timestamptz, target_user_id uuid, target_name text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_app_owner() then
    raise exception 'Only the owner reads' using errcode = '42501';
  end if;
  return query
    select a.action, a.detail, a.created_at, a.target_user_id, coalesce(p.name, p.full_name)
      from public.owner_actions a left join public.profiles p on p.id = a.target_user_id
     order by a.created_at desc
     limit 50;
end $$;

revoke execute on function public.owner_grant_plan(uuid, text, integer, text), public.owner_set_dancer(uuid, text),
  public.owner_remove_connection(uuid, uuid), public.owner_remove_couple(uuid, uuid), public.owner_user_card(uuid),
  public.owner_overview(), public.owner_recent_actions() from public, anon;
grant execute on function public.owner_grant_plan(uuid, text, integer, text), public.owner_set_dancer(uuid, text),
  public.owner_remove_connection(uuid, uuid), public.owner_remove_couple(uuid, uuid), public.owner_user_card(uuid),
  public.owner_overview(), public.owner_recent_actions() to authenticated;
