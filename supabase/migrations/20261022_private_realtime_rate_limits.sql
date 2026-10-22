-- 1. A routine is shared only between its owner and an accepted partner (coaches come later). One check for
--    both the live channel and deleting figures.
create or replace function public.is_routine_owner_or_partner(p_routine_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from routines r
    where r.id = p_routine_id
      and (r.user_id = auth.uid() or exists (
        select 1 from connections c
        where c.status = 'accepted' and c.relationship_type = 'partner'
          and ((c.user_a_id = auth.uid() and c.user_b_id = r.user_id)
            or (c.user_b_id = auth.uid() and c.user_a_id = r.user_id))))
  );
$$;
revoke all on function public.is_routine_owner_or_partner(uuid) from public, anon;
grant execute on function public.is_routine_owner_or_partner(uuid) to authenticated;

-- The live channel canvas_<routine id> is private: only the owner and the partner may join, read or send.
-- The topic is compared as text, so a made-up topic can never break the check.
create policy "canvas owner and partner receive" on realtime.messages
  for select to authenticated
  using (
    realtime.topic() like 'canvas\_%'
    and exists (select 1 from public.routines r
                where r.id::text = substring(realtime.topic() from 8)
                  and public.is_routine_owner_or_partner(r.id))
  );

create policy "canvas owner and partner send" on realtime.messages
  for insert to authenticated
  with check (
    realtime.topic() like 'canvas\_%'
    and exists (select 1 from public.routines r
                where r.id::text = substring(realtime.topic() from 8)
                  and public.is_routine_owner_or_partner(r.id))
  );

-- The partner may delete figures too (before, the server silently refused and the figure came back).
drop policy if exists canvas_delete on public.canvas_nodes;
create policy canvas_delete on public.canvas_nodes
  for delete using (public.is_routine_owner_or_partner(routine_id));

-- 2. The server's clock decides when a routine changed, not the phone's (a wrong phone clock must not make
--    an older version look newer). Stored as one moment (UTC); the app shows it in Slovak time.
create or replace function public.stamp_routine_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists routines_server_time on public.routines;
create trigger routines_server_time
  before insert or update on public.routines
  for each row execute function public.stamp_routine_updated_at();

-- 3. Rate limits per account: generous for dancers, a wall for scripts. Only the functions below touch the
--    table (RLS on, no policies, no grants).
create table if not exists public.rate_limits (
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  window_start timestamptz not null default now(),
  hits integer not null default 0,
  primary key (user_id, action)
);
alter table public.rate_limits enable row level security;
revoke all on public.rate_limits from anon, authenticated;

create or replace function public.check_rate_limit(p_action text, p_max integer, p_window interval)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_hits integer;
begin
  if v_uid is null then return; end if;   -- service role, cron
  insert into rate_limits as r (user_id, action, window_start, hits)
  values (v_uid, p_action, now(), 1)
  on conflict (user_id, action) do update
    set hits = case when r.window_start < now() - p_window then 1 else r.hits + 1 end,
        window_start = case when r.window_start < now() - p_window then now() else r.window_start end
  returning hits into v_hits;
  if v_hits > p_max then
    raise exception 'Too many requests' using errcode = 'P0001', hint = 'rate_limited';
  end if;
end;
$$;
revoke all on function public.check_rate_limit(text, integer, interval) from public, anon, authenticated;

create or replace function public.limit_writes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.check_rate_limit(tg_argv[0], tg_argv[1]::integer, tg_argv[2]::interval);
  return new;
end;
$$;
revoke all on function public.limit_writes() from public, anon, authenticated;

drop trigger if exists connections_rate_limit on public.connections;
create trigger connections_rate_limit before insert on public.connections
  for each row execute function public.limit_writes('connection_request', '30', '1 day');

drop trigger if exists invite_tokens_rate_limit on public.invite_tokens;
create trigger invite_tokens_rate_limit before insert on public.invite_tokens
  for each row execute function public.limit_writes('invite_token', '20', '1 day');

-- Every routine upload upserts the routine row; an active dancer rearranging figures stays far below these.
drop trigger if exists routines_rate_limit on public.routines;
create trigger routines_rate_limit before insert on public.routines
  for each row execute function public.limit_writes('routine_write', '2000', '1 day');

drop trigger if exists canvas_nodes_rate_limit on public.canvas_nodes;
create trigger canvas_nodes_rate_limit before insert on public.canvas_nodes
  for each row execute function public.limit_writes('figure_write', '5000', '1 day');

-- 4. Dancer search: at most 120 searches in 10 minutes, and % or _ typed by the user are plain characters
--    (before, a search for "%%" matched everyone, so the whole list could be read out page by page).
create or replace function public.search_dancers(query text)
returns table(id uuid, dancer_code text, full_name text, club text, avatar_url text)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_query text := replace(replace(replace(trim(query), '\', '\\'), '%', '\%'), '_', '\_');
begin
  if length(trim(query)) < 2 then return; end if;
  perform public.check_rate_limit('dancer_search', 120, interval '10 minutes');
  return query
  select p.id, p.dancer_code, coalesce(p.name, p.full_name, 'Tanečník'), p.club, p.avatar_url
  from public.profiles p
  where (p.account_status is null or p.account_status = 'active')
    and (p.dancer_code ilike v_query || '%' or coalesce(p.name, p.full_name) ilike '%' || v_query || '%')
    and not public.is_blocked_between(p.id, auth.uid())
  limit 10;
end;
$function$;
