-- App Review 1.2: a dancer can block another one. A block ends their connection (the app revokes it),
-- refuses new requests and acceptances either way (also through the QR invite) and hides both people
-- from each other's search. The blocked person is never told. Applied in Supabase on 18. 10. 2026.
create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
alter table public.user_blocks enable row level security;
create policy "user_blocks_own" on public.user_blocks for all to authenticated
  using (auth.uid() = blocker_id) with check (auth.uid() = blocker_id);

-- Only for server functions: a blocked person must not learn about the block.
create or replace function public.is_blocked_between(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_blocks
                 where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a));
$$;
revoke execute on function public.is_blocked_between(uuid, uuid) from public, anon, authenticated;

-- No new or renewed request or acceptance between blocked people (also through the QR invite).
create or replace function public.refuse_blocked_connection()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status in ('pending', 'accepted')
     and (tg_op = 'INSERT' or old.status is distinct from new.status)
     and public.is_blocked_between(new.user_a_id, new.user_b_id) then
    raise exception 'Connection not allowed' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists refuse_blocked_connection on public.connections;
create trigger refuse_blocked_connection before insert or update on public.connections
  for each row execute function public.refuse_blocked_connection();

-- search_dancers as in 20261004, plus: blocked people do not find each other.
create or replace function public.search_dancers(query text)
returns table (id uuid, dancer_code text, full_name text, club text, avatar_url text)
security definer set search_path = public language plpgsql as $$
begin
  if length(trim(query)) < 2 then return; end if;
  return query
  select p.id, p.dancer_code, coalesce(p.name, p.full_name, 'Tanečník'), p.club, p.avatar_url
  from public.profiles p
  where (p.account_status is null or p.account_status = 'active')
    and (p.dancer_code ilike query || '%' or coalesce(p.name, p.full_name) ilike '%' || query || '%')
    and not public.is_blocked_between(p.id, auth.uid())
  limit 10;
end;
$$;
