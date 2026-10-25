-- Since 20261013_invite_pending_and_owner_guard.sql every update of a routine or a figure failed: the guard read
-- new.routine_id on routines and new.user_id on canvas_nodes, and PL/pgSQL looks up every column an expression names,
-- so it raised "record new has no field ...". One branch per table reads only that table's column. The iPhone kept
-- every change waiting (SyncLedger) and sends it on the next run.

create or replace function public.guard_owner_columns()
returns trigger language plpgsql set search_path = public as $$
begin
  if tg_table_name = 'routines' then
    if new.user_id is distinct from old.user_id then
      raise exception 'Routine owner cannot change' using errcode = '42501';
    end if;
  elsif tg_table_name = 'canvas_nodes' then
    if new.routine_id is distinct from old.routine_id then
      raise exception 'Figure cannot move to another routine' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.guard_owner_columns() from public, anon, authenticated;
