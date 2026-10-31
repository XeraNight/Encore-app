-- Verification in person, without documents: a pending dancer shows a verification QR (random, 5 minutes, no
-- personal data) and a verified dancer of the same KSIS club, or the partner of their current couple, scans it and
-- confirms they know them. The code only says who asks; who may vouch is decided here. One dancer vouches for at
-- most 10 others in 30 days. The owner sees who vouched (ksis_dancers.verified_by) and can take it back.

-- 1. Live codes. No policies: only the functions below read and write them.
create table public.ksis_verify_codes (
  code text primary key,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  expires_at timestamptz not null
);
alter table public.ksis_verify_codes enable row level security;
revoke all on public.ksis_verify_codes from anon, authenticated;

-- 2. The pending dancer opens a code; it replaces their previous one (expired codes of anyone go too).
create function public.open_verify_code()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := (select auth.uid());
  v_code text := replace(gen_random_uuid()::text, '-', '');
  v_expires timestamptz := now() + interval '5 minutes';
begin
  if not exists (select 1 from public.ksis_dancers where user_id = v_me and status = 'pending') then
    raise exception 'not_pending' using errcode = 'P0001';
  end if;
  delete from public.ksis_verify_codes where user_id = v_me or expires_at < now();
  insert into public.ksis_verify_codes (code, user_id, expires_at) values (v_code, v_me, v_expires);
  return jsonb_build_object('code', v_code, 'expires_at', v_expires);
end $$;

-- 3. Whom the code asks for, when the caller may vouch for them. Each refusal is its own message for the app.
create function public.vouch_target(p_code text)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare
  v_me uuid := (select auth.uid());
  v_my_club text;
  v_target uuid;
  v_target_club text;
begin
  select club into v_my_club from public.ksis_dancers where user_id = v_me and status = 'verified';
  if not found then
    raise exception 'not_verified' using errcode = 'P0001';
  end if;
  select user_id into v_target from public.ksis_verify_codes where code = p_code and expires_at > now();
  if v_target is null then
    raise exception 'expired' using errcode = 'P0001';
  end if;
  select club into v_target_club from public.ksis_dancers where user_id = v_target and status = 'pending';
  if not found then
    raise exception 'already_verified' using errcode = 'P0001';
  end if;
  -- A dancer without a club in KSIS can be vouched for only by their partner.
  if not (coalesce(lower(trim(v_target_club)) = lower(trim(v_my_club)), false)
          or exists (
            select 1 from public.user_couples mine
              join public.user_couples theirs
                on theirs.pair_number = mine.pair_number and theirs.side <> mine.side and theirs.is_current
             where mine.user_id = v_me and mine.is_current and theirs.user_id = v_target)) then
    raise exception 'not_eligible' using errcode = 'P0001';
  end if;
  if (select count(*) from public.ksis_dancers
       where verified_by = v_me and verified_how = 'vouch' and verified_at > now() - interval '30 days') >= 10 then
    raise exception 'limit' using errcode = 'P0001';
  end if;
  return v_target;
end $$;
revoke execute on function public.vouch_target(text) from public, anon, authenticated;

-- 4. The scanner sees whom they vouch for before confirming.
create function public.peek_verify_code(p_code text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_target uuid := public.vouch_target(p_code);
begin
  return (
    select jsonb_build_object('name', d.name, 'club', d.club, 'person_number', d.person_number,
                              'account_name', coalesce(p.name, p.full_name, ''), 'avatar_url', p.avatar_url)
      from public.ksis_dancers d left join public.profiles p on p.id = d.user_id
     where d.user_id = v_target);
end $$;

-- 5. "I know them in person." The unique index still keeps one verified account per KSIS number (23505).
create function public.vouch_dancer(p_code text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_target uuid := public.vouch_target(p_code);
begin
  update public.ksis_dancers
     set status = 'verified', verified_by = (select auth.uid()), verified_at = now(), verified_how = 'vouch', updated_at = now()
   where user_id = v_target and status = 'pending';
  delete from public.ksis_verify_codes where user_id = v_target;
end $$;

revoke execute on function public.open_verify_code(), public.peek_verify_code(text), public.vouch_dancer(text)
  from public, anon;
grant execute on function public.open_verify_code(), public.peek_verify_code(text), public.vouch_dancer(text)
  to authenticated;
