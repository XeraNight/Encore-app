-- Connections: a plain connection gives no access; the partner, only one, shares the routines.
-- Every rule that gives access names 'partner' or 'coach_student' explicitly (routines, canvas, the live
-- channel, shared videos; checked 25. 10. 2026), so a plain connection reaches nothing of the other person.

-- 1. The new type.
alter table public.connections drop constraint connections_relationship_type_check;
alter table public.connections add constraint connections_relationship_type_check
  check (relationship_type in ('connection', 'partner', 'coach_student'));

-- 2. Only one partner: a partner request can be sent and accepted only while neither side has one.
--    Rows that keep their status are left alone, so older double partners can still be ended.
create or replace function public.enforce_single_partner()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.relationship_type <> 'partner' or new.status not in ('pending', 'accepted') then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.status = old.status then
    return new;
  end if;
  if exists (
    select 1 from public.connections c
     where c.id <> new.id and c.relationship_type = 'partner' and c.status = 'accepted'
       and (c.user_a_id in (new.user_a_id, new.user_b_id) or c.user_b_id in (new.user_a_id, new.user_b_id))
  ) then
    raise exception 'Jeden z vás už má partnera alebo partnerku.' using errcode = 'P0001', hint = 'already_has_partner';
  end if;
  return new;
end;
$$;

create trigger connections_single_partner before insert or update on public.connections
  for each row execute function public.enforce_single_partner();

-- 3. A QR invite asks for a plain connection.
create or replace function public.respond_to_friend_invite(p_token text, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = 'public' as $function$
declare
  v_caller uuid := auth.uid();
  v_token  public.invite_tokens%rowtype;
begin
  if v_caller is null then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED', 'message', 'Musíš byť prihlásený.');
  end if;

  select * into v_token from public.invite_tokens where token = p_token;
  if not found or v_token.revoked_at is not null or v_token.expires_at < now() then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_TOKEN', 'message', 'Pozvánka je neplatná alebo expirovala.');
  end if;
  if v_caller = v_token.user_id then
    return jsonb_build_object('success', false, 'error_code', 'SELF_INVITE', 'message', 'Nemôžeš potvrdiť pozvánku sám sebe.');
  end if;

  if not p_accept then
    return jsonb_build_object('success', true, 'status', 'declined', 'message', 'Pozvánka bola odmietnutá.');
  end if;

  if exists (
    select 1 from public.connections
     where relationship_type in ('connection', 'partner') and status in ('pending', 'accepted')
       and ((user_a_id = v_caller and user_b_id = v_token.user_id) or (user_a_id = v_token.user_id and user_b_id = v_caller))
  ) then
    return jsonb_build_object('success', true, 'status', 'pending', 'message', 'Už ste spojení alebo žiadosť čaká.');
  end if;

  update public.connections
     set status = 'pending', initiated_by = v_caller, updated_at = now()
   where relationship_type = 'connection' and status in ('rejected', 'revoked')
     and ((user_a_id = v_caller and user_b_id = v_token.user_id) or (user_a_id = v_token.user_id and user_b_id = v_caller));
  if not found then
    insert into public.connections (user_a_id, user_b_id, relationship_type, status, initiated_by)
    values (v_token.user_id, v_caller, 'connection', 'pending', v_caller);
  end if;

  return jsonb_build_object('success', true, 'status', 'pending',
                            'message', 'Žiadosť je odoslaná. Spojíte sa, keď ju potvrdí.');
end;
$function$;

-- 4. Either side turns a partner into a plain connection; the access to each other's routines ends at once.
create or replace function public.make_plain_connection(p_connection_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_conn public.connections%rowtype;
begin
  select * into v_conn from public.connections where id = p_connection_id;
  if not found or v_me is null or v_me not in (v_conn.user_a_id, v_conn.user_b_id)
     or v_conn.relationship_type <> 'partner' or v_conn.status <> 'accepted' then
    raise exception 'Not your partner connection' using errcode = '42501';
  end if;

  update public.connections set status = 'revoked', updated_at = now() where id = v_conn.id;

  update public.connections set status = 'accepted', updated_at = now()
   where relationship_type = 'connection'
     and ((user_a_id = v_conn.user_a_id and user_b_id = v_conn.user_b_id)
       or (user_a_id = v_conn.user_b_id and user_b_id = v_conn.user_a_id));
  if not found then
    insert into public.connections (user_a_id, user_b_id, relationship_type, status, initiated_by)
    values (v_conn.user_a_id, v_conn.user_b_id, 'connection', 'accepted', v_me);
  end if;
end;
$$;

revoke execute on function public.make_plain_connection(uuid) from public, anon;
grant execute on function public.make_plain_connection(uuid) to authenticated;

-- 5. Connected people see each other's linked KSIS couple (class and points, public in KSIS). Nothing else.
create policy user_couples_select_connections on public.user_couples for select to authenticated
  using (exists (
    select 1 from public.connections c
     where c.status = 'accepted' and c.relationship_type in ('connection', 'partner')
       and ((c.user_a_id = (select auth.uid()) and c.user_b_id = user_couples.user_id)
         or (c.user_b_id = (select auth.uid()) and c.user_a_id = user_couples.user_id))
  ));
