-- Security audit 13. 10. 2026 (E1, E3).
--
-- E1: an invite token (QR on the Wallet card, /add?t=tok_…) gave the scanner an accepted partner connection at
--     once, and turned a revoked or rejected one back to accepted. Now it only sends a request; the card owner
--     accepts it in the app (Priatelia → Chcú sa prepojiť), which guard_connection_changes allows only to them.
--     The token stays valid, so the QR on the Wallet card keeps working for the next person.
-- E3: a partner or coach could set routines.user_id to themselves (WITH CHECK passed) and so take the routine,
--     or move figures into their own routine. Owner columns can no longer change. The app's sync never sends
--     these columns on update.

create or replace function public.respond_to_friend_invite(p_token text, p_accept boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_token  public.invite_tokens%rowtype;
  v_conn   public.connections%rowtype;
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

  -- Declining a scanned QR changes nothing on the server.
  if not p_accept then
    return jsonb_build_object('success', true, 'status', 'declined', 'message', 'Pozvánka bola odmietnutá.');
  end if;

  select * into v_conn from public.connections
  where relationship_type = 'partner'
    and ((user_a_id = v_caller and user_b_id = v_token.user_id)
      or (user_a_id = v_token.user_id and user_b_id = v_caller))
  limit 1;

  if found and v_conn.status in ('pending', 'accepted') then
    return jsonb_build_object('success', true, 'status', v_conn.status, 'message', 'Žiadosť už existuje.');
  elsif found then
    -- rejected / revoked: a new request, never straight back to accepted.
    update public.connections
    set status = 'pending', initiated_by = v_caller, updated_at = now()
    where id = v_conn.id;
  else
    insert into public.connections (user_a_id, user_b_id, relationship_type, status, initiated_by)
    values (v_token.user_id, v_caller, 'partner', 'pending', v_caller);
  end if;

  return jsonb_build_object('success', true, 'status', 'pending',
                            'message', 'Žiadosť je odoslaná. Prepojíte sa, keď ju potvrdí.');
end;
$$;

revoke execute on function public.respond_to_friend_invite(text, boolean) from public, anon;
grant  execute on function public.respond_to_friend_invite(text, boolean) to authenticated;

create or replace function public.guard_owner_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_table_name = 'routines' and new.user_id is distinct from old.user_id then
    raise exception 'Routine owner cannot change' using errcode = '42501';
  end if;
  if tg_table_name = 'canvas_nodes' and new.routine_id is distinct from old.routine_id then
    raise exception 'Figure cannot move to another routine' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_owner_columns() from public, anon, authenticated;

drop trigger if exists routines_guard_owner on public.routines;
create trigger routines_guard_owner
  before update on public.routines
  for each row execute function public.guard_owner_columns();

drop trigger if exists canvas_nodes_guard_routine on public.canvas_nodes;
create trigger canvas_nodes_guard_routine
  before update on public.canvas_nodes
  for each row execute function public.guard_owner_columns();

-- Check once by hand: partner connections that were accepted straight from a QR scan.
--   select * from public.connections where relationship_type = 'partner' and status = 'accepted';
