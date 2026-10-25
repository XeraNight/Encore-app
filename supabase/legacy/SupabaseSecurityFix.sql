-- Encore Supabase security hardening
-- Run this in Supabase Dashboard > SQL Editor.
--
-- This is the app-compatible lockdown: it enables RLS and blocks anonymous public
-- access, while still allowing signed-in users to sync existing data. For strict
-- per-user privacy, add user_id ownership policies after backfilling existing rows.

begin;

-- The security advisor reported this SECURITY DEFINER function as executable by
-- broad roles. It should not be callable by app users.
revoke execute on function public.rls_auto_enable() from public;
revoke execute on function public.rls_auto_enable() from anon;
revoke execute on function public.rls_auto_enable() from authenticated;

-- Public tables must not be readable/writable without Row Level Security.
alter table public.routines enable row level security;
alter table public.figure_library_items enable row level security;
alter table public.canvas_nodes enable row level security;

-- Remove default anonymous table privileges. The app uses the anon key, but users
-- should authenticate before database rows are accessible.
revoke all on table public.routines from anon;
revoke all on table public.figure_library_items from anon;
revoke all on table public.canvas_nodes from anon;

-- Drop only Encore policies managed by this file, so re-running is safe.
drop policy if exists "encore_authenticated_routines_select" on public.routines;
drop policy if exists "encore_authenticated_routines_insert" on public.routines;
drop policy if exists "encore_authenticated_routines_update" on public.routines;
drop policy if exists "encore_authenticated_routines_delete" on public.routines;

drop policy if exists "encore_authenticated_figures_select" on public.figure_library_items;
drop policy if exists "encore_authenticated_figures_insert" on public.figure_library_items;
drop policy if exists "encore_authenticated_figures_update" on public.figure_library_items;
drop policy if exists "encore_authenticated_figures_delete" on public.figure_library_items;

drop policy if exists "encore_authenticated_canvas_select" on public.canvas_nodes;
drop policy if exists "encore_authenticated_canvas_insert" on public.canvas_nodes;
drop policy if exists "encore_authenticated_canvas_update" on public.canvas_nodes;
drop policy if exists "encore_authenticated_canvas_delete" on public.canvas_nodes;

-- App-compatible policies. These remove anonymous public access, but signed-in
-- users can still sync. This keeps the current app functional because the Swift
-- rows do not yet include user_id/owner_id columns.
create policy "encore_authenticated_routines_select"
on public.routines for select
to authenticated
using (true);

create policy "encore_authenticated_routines_insert"
on public.routines for insert
to authenticated
with check (true);

create policy "encore_authenticated_routines_update"
on public.routines for update
to authenticated
using (true)
with check (true);

create policy "encore_authenticated_routines_delete"
on public.routines for delete
to authenticated
using (true);

create policy "encore_authenticated_figures_select"
on public.figure_library_items for select
to authenticated
using (true);

create policy "encore_authenticated_figures_insert"
on public.figure_library_items for insert
to authenticated
with check (true);

create policy "encore_authenticated_figures_update"
on public.figure_library_items for update
to authenticated
using (true)
with check (true);

create policy "encore_authenticated_figures_delete"
on public.figure_library_items for delete
to authenticated
using (true);

create policy "encore_authenticated_canvas_select"
on public.canvas_nodes for select
to authenticated
using (true);

create policy "encore_authenticated_canvas_insert"
on public.canvas_nodes for insert
to authenticated
with check (true);

create policy "encore_authenticated_canvas_update"
on public.canvas_nodes for update
to authenticated
using (true)
with check (true);

create policy "encore_authenticated_canvas_delete"
on public.canvas_nodes for delete
to authenticated
using (true);

commit;

-- Verify after running:
--
-- select schemaname, tablename, rowsecurity
-- from pg_tables
-- where schemaname = 'public'
--   and tablename in ('routines', 'figure_library_items', 'canvas_nodes');
--
-- select schemaname, tablename, policyname, roles, cmd, qual, with_check
-- from pg_policies
-- where schemaname = 'public'
--   and tablename in ('routines', 'figure_library_items', 'canvas_nodes')
-- order by tablename, policyname;
--
-- Production privacy next step:
-- 1. Add user_id uuid columns to routines and figure_library_items.
-- 2. Backfill existing rows to your auth.users.id.
-- 3. Replace the authenticated-all policies above with auth.uid() = user_id.
-- 4. Restrict canvas_nodes through the parent routine owner/member policy.
