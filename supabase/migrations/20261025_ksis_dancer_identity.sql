-- KSIS: the dancer finds themselves in the members list by the personal number. Until verified the data is only for
-- them; verified (by the owner, or by their verified partner) is one account per personal number. Couples are a
-- history: one current, the ones before stay with their results. Replaces 20261025_ksis_link_verification.sql.

-- 1. Who the account is in KSIS. Only the server writes (ksis-page); the dancer reads their own, the owner all.
create table public.ksis_dancers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  person_number integer not null,
  name text not null,
  club text,
  stt_class text,
  lat_class text,
  status text not null default 'pending' check (status in ('pending', 'verified')),
  verified_by uuid references auth.users(id) on delete set null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index ksis_dancers_one_verified on public.ksis_dancers (person_number) where status = 'verified';
alter table public.ksis_dancers enable row level security;
revoke all on public.ksis_dancers from anon, authenticated;
grant select on public.ksis_dancers to authenticated;
create policy ksis_dancers_read on public.ksis_dancers for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_app_owner()));

-- 2. Couples as a history: several per account, one current; nothing is deleted when the partner changes.
--    A couple is its number and its partnerka: KSIS numbers a couple with the partner's personal number, so a partner
--    who changes partnerka may keep the number. The server writes the key; rows from before learn it on their next save.
drop index public.user_couples_one_per_account;
drop index public.user_couples_one_account_per_dancer;
drop index public.user_couples_user_pair_unique;
drop trigger trg_user_couples_max_limit on public.user_couples;
drop function public.check_user_couples_max_limit();
alter table public.user_couples add column is_current boolean not null default true;
alter table public.user_couples add column couple_key text;
create unique index user_couples_one_current on public.user_couples (user_id) where is_current;
create unique index user_couples_one_per_couple on public.user_couples (user_id, couple_key) where couple_key is not null;

-- 3. Connections see results only of a verified dancer.
create or replace function public.shares_results_with(p_owner uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = p_owner and p.shares_results)
     and exists (select 1 from public.ksis_dancers d where d.user_id = p_owner and d.status = 'verified')
     and exists (
       select 1 from public.connections c
        where c.status = 'accepted' and c.relationship_type in ('connection', 'partner')
          and ((c.user_a_id = (select auth.uid()) and c.user_b_id = p_owner)
            or (c.user_b_id = (select auth.uid()) and c.user_a_id = p_owner)));
$$;

-- 4. The owner verifies or refuses (a refused dancer can find themselves again).
create function public.owner_decide_dancer(p_user uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_app_owner() then
    raise exception 'Only the owner decides' using errcode = '42501';
  end if;
  if p_approve then
    update public.ksis_dancers set status = 'verified', verified_by = auth.uid(), verified_at = now(), updated_at = now()
     where user_id = p_user and status = 'pending';
  else
    delete from public.ksis_dancers where user_id = p_user and status = 'pending';
  end if;
  if not found then
    raise exception 'No such pending dancer' using errcode = 'P0002';
  end if;
end $$;

-- 5. A verified dancer confirms the partner of their current couple, and sees who waits for it.
create function public.confirm_partner(p_partner uuid)
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
  update public.ksis_dancers set status = 'verified', verified_by = v_me, verified_at = now(), updated_at = now()
   where user_id = p_partner and status = 'pending';
  if not found then
    raise exception 'No pending dancer to confirm' using errcode = 'P0002';
  end if;
end $$;

create function public.my_partner_waiting()
returns table (user_id uuid, account_name text, ksis_name text)
language sql stable security definer set search_path = '' as $$
  select d.user_id, coalesce(p.name, p.full_name, ''), d.name
    from public.user_couples mine
    join public.user_couples theirs
      on theirs.pair_number = mine.pair_number and theirs.side <> mine.side and theirs.is_current
    join public.ksis_dancers d on d.user_id = theirs.user_id and d.status = 'pending'
    left join public.profiles p on p.id = d.user_id
   where mine.user_id = (select auth.uid()) and mine.is_current
     and exists (select 1 from public.ksis_dancers me where me.user_id = (select auth.uid()) and me.status = 'verified');
$$;

revoke execute on function public.owner_decide_dancer(uuid, boolean), public.confirm_partner(uuid),
  public.my_partner_waiting() from public, anon;
grant execute on function public.owner_decide_dancer(uuid, boolean), public.confirm_partner(uuid),
  public.my_partner_waiting() to authenticated;

-- 6. The way before goes (no requests were filed).
drop function public.owner_decide_link_request(uuid, boolean);
drop table public.ksis_link_requests;
