-- Prepojenia pred v1, nasadené 14. 11. 2026 (Jakubovo áno po ukázaní SQL a nanečisto skúške).
-- Čo opravuje (zistené čítaním živých pravidiel a dvoma pokusmi, ktoré sa celé vrátili späť):
--   A. cudzí človek vedel cez API poslať žiadosť „tréner“; po prijatí čítal a menil zostavy tanečníka
--      a appka v1 nemá obrazovku, kde by to tanečník videl alebo zrušil (trénerské nástroje sú vypnuté);
--   B. pravidlo „len jeden partner“ sa pozeralo s právami toho, kto ťuká, takže partnera druhej strany nevidelo;
--   C. hľadanie podľa začiatku ID („DNC“) vypísalo všetky účty, aj tanečníkov do 17 rokov;
--   D. tú istú dvojicu sa dalo uložiť dvakrát (A,B aj B,A), takže jeden človek mohol byť v Spojeniach dvakrát;
--   E. druhý iPhone si vyrobil nový QR kód a potichu zrušil ten na prvom iPhone a v Peňaženke.

-- 1. Pravidlá páru bežia s právami vlastníka (musia vidieť riadky oboch ľudí) a platia pre každého, kto zapisuje:
--    každý má najviac jedného partnera a pár sa vyberá z prijatých spojení.
create or replace function public.enforce_single_partner()
returns trigger language plpgsql security definer set search_path = '' as $$
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
  if not exists (
    select 1 from public.connections c
     where c.relationship_type = 'connection' and c.status = 'accepted'
       and least(c.user_a_id, c.user_b_id) = least(new.user_a_id, new.user_b_id)
       and greatest(c.user_a_id, c.user_b_id) = greatest(new.user_a_id, new.user_b_id)
  ) then
    raise exception 'Pár si vyberáš zo svojich spojení.' using errcode = 'P0001', hint = 'not_connected';
  end if;
  return new;
end;
$$;
revoke execute on function public.enforce_single_partner() from public, anon, authenticated;

-- 2. Žiadosti „tréner“ z appky server odmietne, kým trénerské nástroje nevyjdú. Zvyšok funkcie je bez zmeny.
create or replace function public.guard_connection_changes()
returns trigger language plpgsql set search_path = public as $$
declare
  v_me uuid := auth.uid();
begin
  -- Service role, SQL editor and SECURITY DEFINER functions are not restricted here.
  if v_me is null or current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  -- Coach links wait for the coach tools: the v1 app has no screen that shows or ends one.
  if new.relationship_type = 'coach_student' and new.status in ('pending', 'accepted')
     and (tg_op = 'INSERT' or new.status is distinct from old.status) then
    raise exception 'Coach connections are not available yet' using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'pending'
       or new.initiated_by is distinct from v_me
       or v_me not in (new.user_a_id, new.user_b_id)
       or new.user_a_id = new.user_b_id then
      raise exception 'Invalid connection request' using errcode = '42501';
    end if;
    return new;
  end if;

  -- UPDATE (this also covers upsert on conflict)
  if new.user_a_id is distinct from old.user_a_id
     or new.user_b_id is distinct from old.user_b_id
     or new.relationship_type is distinct from old.relationship_type then
    raise exception 'Connection parties cannot change' using errcode = '42501';
  end if;

  if new.status = old.status then
    new.initiated_by := old.initiated_by;
    return new;
  end if;

  if new.status in ('accepted', 'rejected') then
    if old.status <> 'pending' or old.initiated_by = v_me then
      raise exception 'Only the invited person can answer a pending request' using errcode = '42501';
    end if;
    new.initiated_by := old.initiated_by;
  elsif new.status = 'revoked' then
    if old.status not in ('pending', 'accepted') then
      raise exception 'Nothing to revoke' using errcode = '42501';
    end if;
    new.initiated_by := old.initiated_by;
  elsif new.status = 'pending' then
    if old.status not in ('rejected', 'revoked') or new.initiated_by is distinct from v_me then
      raise exception 'Invalid connection request' using errcode = '42501';
    end if;
  else
    raise exception 'Invalid connection status' using errcode = '42501';
  end if;

  return new;
end;
$$;

-- 3. Hľadanie: ID tanečníka iba celé (aj bez „DNC-“), meno ako doteraz (iba 17+).
create or replace function public.search_dancers(query text)
returns table(id uuid, dancer_code text, full_name text, club text, avatar_url text)
language plpgsql security definer set search_path = public as $$
declare
  v_clean text := trim(query);
  v_like  text := replace(replace(replace(v_clean, '\', '\\'), '%', '\%'), '_', '\_');
begin
  if length(v_clean) < 2 then return; end if;
  perform public.check_rate_limit('dancer_search', 120, interval '10 minutes');
  return query
  select p.id, p.dancer_code, coalesce(p.name, p.full_name, 'Tanečník'), p.club, p.avatar_url
  from public.profiles p
  where (p.account_status is null or p.account_status = 'active')
    and (p.dancer_code in (upper(v_clean), 'DNC-' || v_clean)
         or (coalesce(p.name, p.full_name) ilike '%' || v_like || '%'
             and p.birth_year <= extract(year from now())::int - 17))
    and not public.is_blocked_between(p.id, auth.uid())
  limit 10;
end;
$$;

-- 4. Dvojica je uložená vždy v jednom poradí (menšie ID prvé), takže ten istý človek nemôže byť dvakrát.
update public.connections
   set user_a_id = least(user_a_id, user_b_id), user_b_id = greatest(user_a_id, user_b_id)
 where relationship_type in ('connection', 'partner') and user_a_id > user_b_id;
alter table public.connections add constraint connections_pair_order
  check (relationship_type = 'coach_student' or user_a_id < user_b_id);

--    QR pozvánka ukladá v tom istom poradí a zablokovaný účet ju nepoužije. Zvyšok funkcie je bez zmeny.
create or replace function public.respond_to_friend_invite(p_token text, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = 'public' as $function$
declare
  v_caller uuid := auth.uid();
  v_token  public.invite_tokens%rowtype;
begin
  if v_caller is null or not public.is_account_active() then
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
    values (least(v_token.user_id, v_caller), greatest(v_token.user_id, v_caller), 'connection', 'pending', v_caller);
  end if;

  return jsonb_build_object('success', true, 'status', 'pending',
                            'message', 'Žiadosť je odoslaná. Spojíte sa, keď ju potvrdí.');
end;
$function$;

--    To isté poradie pri zmene páru späť na spojenie. Zvyšok funkcie je bez zmeny.
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
    values (least(v_conn.user_a_id, v_conn.user_b_id), greatest(v_conn.user_a_id, v_conn.user_b_id), 'connection', 'accepted', v_me);
  end if;
end;
$$;

-- 5. QR kód karty: server vráti ten istý platný kód každému zariadeniu. Nový vyrobí, až keď starému ostáva
--    menej ako týždeň, a starý nechá dobehnúť. Zrušiť ho hneď vie iba „Nový QR“ (create_friend_invite_token).
--    PLATNOSŤ: 30 dní je môj návrh; ak ostane 7 dní, zmenia sa iba dve čísla nižšie (30 -> 7, '7 days' -> '1 day').
create or replace function public.current_friend_invite_token()
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_token text;
begin
  if v_me is null or not public.is_account_active() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  select t.token into v_token from public.invite_tokens t
   where t.user_id = v_me and t.revoked_at is null and t.expires_at > now() + interval '7 days'
   order by t.expires_at desc limit 1;
  if v_token is null then
    v_token := 'tok_' || replace(gen_random_uuid()::text, '-', '');
    insert into public.invite_tokens (user_id, token, expires_at) values (v_me, v_token, now() + interval '30 days');
  end if;
  return v_token;
end;
$$;
revoke execute on function public.current_friend_invite_token() from public, anon;
grant execute on function public.current_friend_invite_token() to authenticated;

--    „Nový QR“: appka si už nevyberie ľubovoľnú platnosť (doteraz mohla poslať aj 36 500 dní).
create or replace function public.create_friend_invite_token(p_expires_in_days integer default 7)
returns text language plpgsql security definer set search_path = 'public' as $function$
declare
  new_token text;
  caller_id uuid := auth.uid();
  v_days integer := least(greatest(coalesce(p_expires_in_days, 7), 1), 30);
begin
  if caller_id is null then
    raise exception 'Neautorizovaný prístup.';
  end if;

  update public.invite_tokens
     set revoked_at = now()
   where user_id = caller_id and revoked_at is null;

  new_token := 'tok_' || replace(gen_random_uuid()::text, '-', '');

  insert into public.invite_tokens (user_id, token, expires_at)
  values (caller_id, new_token, now() + make_interval(days => v_days));

  return new_token;
end;
$function$;
