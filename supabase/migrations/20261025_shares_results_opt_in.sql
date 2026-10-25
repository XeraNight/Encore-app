-- Showing my KSIS couple and saved competitions to my connections is my choice, off by default.
-- Replaces the policy from 20261025_connections_single_partner.sql that showed the couple without asking.

alter table public.profiles add column if not exists shares_results boolean not null default false;

-- True when the owner switched sharing on and the caller is connected with them (connection or partner).
create or replace function public.shares_results_with(p_owner uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = p_owner and p.shares_results)
     and exists (
       select 1 from public.connections c
        where c.status = 'accepted' and c.relationship_type in ('connection', 'partner')
          and ((c.user_a_id = (select auth.uid()) and c.user_b_id = p_owner)
            or (c.user_b_id = (select auth.uid()) and c.user_a_id = p_owner))
     );
$$;
revoke execute on function public.shares_results_with(uuid) from public, anon;
grant execute on function public.shares_results_with(uuid) to authenticated;

drop policy if exists user_couples_select_connections on public.user_couples;
create policy user_couples_select_connections on public.user_couples for select to authenticated
  using (public.shares_results_with(user_id));

create policy competition_results_select_connections on public.competition_results for select to authenticated
  using (not is_deleted and public.shares_results_with(user_id));
