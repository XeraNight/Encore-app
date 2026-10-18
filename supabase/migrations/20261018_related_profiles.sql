-- Names and photos of the people a dancer is connected with (any request state) or has blocked.
-- profiles_select lets a dancer read only their own row, so the app showed partners as "Tanečník".
-- Whoever blocked the caller is left out. Applied in Supabase on 18. 10. 2026.
create or replace function public.related_profiles()
returns table (id uuid, dancer_code text, full_name text,
              club text, avatar_url text)
language sql stable security definer set search_path = public as $$
  select p.id, p.dancer_code,
         coalesce(p.name, p.full_name, 'Tanečník'), p.club, p.avatar_url
  from public.profiles p
  where p.id in (
      select case when c.user_a_id = auth.uid()
                  then c.user_b_id else c.user_a_id end
      from public.connections c
      where auth.uid() in (c.user_a_id, c.user_b_id)
      union
      select b.blocked_id from public.user_blocks b
      where b.blocker_id = auth.uid())
    and not exists (select 1 from public.user_blocks b
                    where b.blocker_id = p.id
                      and b.blocked_id = auth.uid());
$$;
revoke execute on function public.related_profiles()
  from public, anon;
grant execute on function public.related_profiles()
  to authenticated;
