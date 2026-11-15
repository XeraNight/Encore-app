-- A banned or suspended account can no longer look other dancers up (it could not connect anyway).
create or replace function public.search_dancers(query text)
returns table(id uuid, dancer_code text, full_name text, club text, avatar_url text)
language plpgsql security definer set search_path = public as $$
declare
  v_clean text := trim(query);
  v_like  text := replace(replace(replace(v_clean, '\', '\\'), '%', '\%'), '_', '\_');
begin
  if length(v_clean) < 2 or not public.is_account_active() then return; end if;
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
