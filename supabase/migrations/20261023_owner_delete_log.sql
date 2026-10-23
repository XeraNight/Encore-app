-- Owner console: deleting someone's account (Edge Function owner-delete-account).
-- Every attempt is written here: the record of who deleted which account and when, and the count of wrong PINs
-- that stops guessing (5 per hour). Only the deleted account's id is kept, not its e-mail.
-- No policies: only the service role (the Edge Function) reads and writes it.
create table if not exists public.owner_delete_log (
  id bigint generated always as identity primary key,
  owner_id uuid not null,
  target_user_id uuid not null,
  outcome text not null check (outcome in ('wrong_pin', 'deleted', 'failed')),
  created_at timestamptz not null default now()
);
alter table public.owner_delete_log enable row level security;
revoke all on public.owner_delete_log from anon, authenticated;
create index if not exists owner_delete_log_owner_recent on public.owner_delete_log (owner_id, created_at desc);
