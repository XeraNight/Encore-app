-- One account per dancer, one couple per account. The ksis-page function links a couple only when the account's
-- name (Apple, Google, registration or the e-mail before @) matches one of its two dancers; otherwise it files a
-- request and the owner decides in the console. KSIS has no login, so this is as far as checking can go.

-- 1. Which of the two dancers the account is. Rows from before learn it on their next save.
alter table public.user_couples add column if not exists side text check (side in ('partner', 'partnerka'));

-- 2. One couple per account; one account per dancer of a pair (checked 25. 10. 2026: no duplicates today).
create unique index if not exists user_couples_one_per_account on public.user_couples (user_id);
create unique index if not exists user_couples_one_account_per_dancer on public.user_couples (pair_number, side)
  where pair_number is not null and side is not null;

-- 3. Requests when the name does not match. `couple` is the row the server would store, so approving needs no
--    second visit to KSIS. Only the server writes; the dancer sees their own, the owner all.
create table if not exists public.ksis_link_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pair_number integer not null,
  side text not null check (side in ('partner', 'partnerka')),
  dancer_name text not null,
  account_name text not null,
  couple jsonb not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'refused')),
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
alter table public.ksis_link_requests enable row level security;
revoke all on public.ksis_link_requests from anon, authenticated;
grant select on public.ksis_link_requests to authenticated;
create policy ksis_link_requests_read on public.ksis_link_requests for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_app_owner()));
create unique index if not exists ksis_link_requests_one_pending on public.ksis_link_requests (user_id)
  where status = 'pending';

-- 4. The owner approves (the couple is linked as the request says) or refuses.
create or replace function public.owner_decide_link_request(p_request_id uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_request public.ksis_link_requests%rowtype;
begin
  if not public.is_app_owner() then
    raise exception 'Only the owner decides' using errcode = '42501';
  end if;
  select * into v_request from public.ksis_link_requests where id = p_request_id and status = 'pending' for update;
  if not found then
    raise exception 'No such pending request' using errcode = 'P0002';
  end if;

  if p_approve then
    insert into public.user_couples (
      user_id, pair_number, side, partner_names, partner_name, club, age_category,
      stt_class, stt_points, stt_finals, stt_last_change, lat_class, lat_points, lat_finals, lat_last_change,
      discipline, partner_consent, ksis_refreshed_at, updated_at)
    values (
      v_request.user_id, v_request.pair_number, v_request.side,
      v_request.couple ->> 'partner_names', v_request.couple ->> 'partner_name', v_request.couple ->> 'club',
      v_request.couple ->> 'age_category',
      v_request.couple ->> 'stt_class', (v_request.couple ->> 'stt_points')::int, (v_request.couple ->> 'stt_finals')::int,
      (v_request.couple ->> 'stt_last_change')::date,
      v_request.couple ->> 'lat_class', (v_request.couple ->> 'lat_points')::int, (v_request.couple ->> 'lat_finals')::int,
      (v_request.couple ->> 'lat_last_change')::date,
      'ALL', true, now(), now());
  end if;

  update public.ksis_link_requests
     set status = case when p_approve then 'approved' else 'refused' end, decided_at = now()
   where id = p_request_id;
end;
$$;
revoke execute on function public.owner_decide_link_request(uuid, boolean) from public, anon;
grant execute on function public.owner_decide_link_request(uuid, boolean) to authenticated;
