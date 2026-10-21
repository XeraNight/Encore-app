-- Bars of a figure in a routine: with the dance's tempo they give the figure's and the routine's length.
-- Owner and partner set them; the coach may not (the coach guard now compares this column too).

alter table public.canvas_nodes
  add column if not exists bars smallint check (bars between 1 and 64);

-- Same as the live function, with bars added to the columns a coach must not change.
create or replace function public.guard_canvas_coach_notes()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_is_coach boolean; v_is_owner boolean;
begin
  if auth.uid() is null then return new; end if;
  v_is_owner := exists (select 1 from routines r where r.id = new.routine_id and r.user_id = auth.uid());
  v_is_coach := not v_is_owner and public.is_coach_of_routine(new.routine_id);
  if v_is_coach then
    if (new.x, new.y, new.figure_name, new.rhythm, new.notes, new.video_path, new.order_index, new.transition_notes, new.routine_id, new.bars)
       is distinct from
       (old.x, old.y, old.figure_name, old.rhythm, old.notes, old.video_path, old.order_index, old.transition_notes, old.routine_id, old.bars) then
      raise exception 'Coach may only edit coach notes' using errcode = '42501';
    end if;
    if new.coach_notes is distinct from old.coach_notes then
      new.coach_notes_by := auth.uid();
      new.coach_notes_at := now();
      new.coach_notes_by_name := (select left(p.name, 60) from profiles p where p.id = auth.uid());
    else
      new.coach_notes_by := old.coach_notes_by;
      new.coach_notes_at := old.coach_notes_at;
      new.coach_notes_by_name := old.coach_notes_by_name;
    end if;
  else
    new.coach_notes := old.coach_notes;
    new.coach_notes_by := old.coach_notes_by;
    new.coach_notes_at := old.coach_notes_at;
    new.coach_notes_by_name := old.coach_notes_by_name;
  end if;
  return new;
end; $function$;
