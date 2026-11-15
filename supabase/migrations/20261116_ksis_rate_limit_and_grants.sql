-- 16. 11. 2026. Reading KSIS pages: a rate limit per dancer, and the table rights nobody uses.

-- 1. The limit for a named account. The Edge Function ksis-page runs with the service role, where auth.uid() is
--    null, so it passes the dancer's id itself. Only the service role may call it.
create or replace function public.check_user_rate_limit(p_user uuid, p_action text, p_max integer, p_window interval)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hits integer;
begin
  insert into rate_limits as r (user_id, action, window_start, hits)
  values (p_user, p_action, now(), 1)
  on conflict (user_id, action) do update
    set hits = case when r.window_start < now() - p_window then 1 else r.hits + 1 end,
        window_start = case when r.window_start < now() - p_window then now() else r.window_start end
  returning hits into v_hits;
  if v_hits > p_max then
    raise exception 'Too many requests' using errcode = 'P0001', hint = 'rate_limited';
  end if;
end;
$$;
revoke all on function public.check_user_rate_limit(uuid, text, integer, interval) from public, anon, authenticated;
grant execute on function public.check_user_rate_limit(uuid, text, integer, interval) to service_role;

-- 2. The signed-in caller's own limit counts through the same function (one place for the rule).
create or replace function public.check_rate_limit(p_action text, p_max integer, p_window interval)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then return; end if;   -- service role, cron
  perform public.check_user_rate_limit(auth.uid(), p_action, p_max, p_window);
end;
$$;

-- 3. Rights nobody uses. TRUNCATE ignores row security, TRIGGER and REFERENCES belong to a table's owner. Through
--    the API none of them can be used, but a right that is not needed is not left open. New tables get none of them.
revoke truncate, trigger, references on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke truncate, trigger, references on tables from anon, authenticated;

-- 4. Competition results and couples are read by signed-in dancers only (their policies say so); no anonymous reading.
revoke select on public.competition_results, public.user_couples from anon;
