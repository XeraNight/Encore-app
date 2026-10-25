-- Clean-up after the 25. 10. 2026 audit: the export includes the KSIS dancer, the owner no longer writes into other
-- people's figures, nobody writes a KSIS number into their profile, and the old friends system goes.

-- 1. My data export (GDPR art. 15 and 20): the KSIS dancer in, the old friends table out.
create or replace function public.export_my_data()
returns jsonb language plpgsql stable security definer set search_path = '' as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'exported_at', now(),

    'account', (
      select jsonb_build_object(
        'id', u.id,
        'email', u.email,
        'created_at', u.created_at,
        'email_confirmed_at', u.email_confirmed_at,
        'last_sign_in_at', u.last_sign_in_at,
        'sign_in_methods', u.raw_app_meta_data->'providers'
      )
      from auth.users u
      where u.id = v_uid
    ),

    'profile', (
      select to_jsonb(p) - 'invite_code'
      from public.profiles p
      where p.id = v_uid
    ),

    'routines', coalesce((
      select jsonb_agg(
        to_jsonb(r) || jsonb_build_object('figures', coalesce((
          select jsonb_agg(to_jsonb(n) - 'coach_notes_by' order by n.order_index)
          from public.canvas_nodes n
          where n.routine_id = r.id
        ), '[]'::jsonb))
        order by r.updated_at desc)
      from public.routines r
      where r.user_id = v_uid
    ), '[]'::jsonb),

    'coach_notes_written', coalesce((
      select jsonb_agg(jsonb_build_object('figure_id', n.id, 'note', n.coach_notes, 'written_at', n.coach_notes_at)
                       order by n.coach_notes_at)
      from public.canvas_nodes n
      where n.coach_notes_by = v_uid
    ), '[]'::jsonb),

    'figure_library', coalesce((
      select jsonb_agg(to_jsonb(f) order by f.created_at)
      from public.figure_library_items f
      where f.user_id = v_uid
    ), '[]'::jsonb),

    'connections', coalesce((
      select jsonb_agg(jsonb_build_object(
        'relationship', c.relationship_type,
        'status', c.status,
        'other_person', other.full_name,
        'requested_by_me', c.initiated_by = v_uid,
        'created_at', c.created_at,
        'updated_at', c.updated_at
      ) order by c.created_at)
      from public.connections c
      left join public.profiles other
        on other.id = case when c.user_a_id = v_uid then c.user_b_id else c.user_a_id end
      where v_uid in (c.user_a_id, c.user_b_id)
    ), '[]'::jsonb),

    'ksis_dancer', (
      select to_jsonb(d) - 'verified_by'
      from public.ksis_dancers d
      where d.user_id = v_uid
    ),

    'couples', coalesce((
      select jsonb_agg(to_jsonb(uc) order by uc.created_at)
      from public.user_couples uc
      where uc.user_id = v_uid
    ), '[]'::jsonb),

    'competition_results', coalesce((
      select jsonb_agg(to_jsonb(cr) order by cr.date desc)
      from public.competition_results cr
      where cr.user_id = v_uid
    ), '[]'::jsonb),

    'membership', (
      select to_jsonb(e) - 'granted_by'
      from public.user_entitlements e
      where e.user_id = v_uid
    ),

    'invite_links', coalesce((
      select jsonb_agg(jsonb_build_object('created_at', t.created_at, 'expires_at', t.expires_at, 'revoked_at', t.revoked_at)
                       order by t.created_at)
      from public.invite_tokens t
      where t.user_id = v_uid
    ), '[]'::jsonb),

    'emails_sent', coalesce((
      select jsonb_agg(jsonb_build_object('kind', l.kind, 'sent_at', l.created_at) order by l.created_at)
      from public.email_send_log l
      where l.user_id = v_uid
    ), '[]'::jsonb),

    'shared_videos', coalesce((
      select jsonb_agg(jsonb_build_object(
        'figure_id', v.canvas_node_id,
        'size_bytes', v.size_bytes,
        'status', v.status,
        'shared_at', v.created_at
      ) order by v.created_at)
      from public.shared_videos v
      where v.owner_id = v_uid
    ), '[]'::jsonb),

    'coach_lessons_written', coalesce((
      select jsonb_agg(jsonb_build_object(
        'student', coalesce(other.name, other.full_name),
        'lesson_date', l.lesson_date,
        'summary', l.summary,
        'created_at', l.created_at
      ) order by l.lesson_date, l.created_at)
      from public.coach_lessons l
      left join public.profiles other on other.id = l.student_id
      where l.coach_id = v_uid
    ), '[]'::jsonb),

    'guest_coach_keys_made', coalesce((
      select jsonb_agg(jsonb_build_object(
        'routine_id', k.routine_id,
        'created_at', k.created_at,
        'expires_at', k.expires_at,
        'revoked_at', k.revoked_at,
        'used_by', k.guest_name,
        'used_at', k.redeemed_at
      ) order by k.created_at)
      from public.guest_coach_keys k
      where k.owner_id = v_uid
    ), '[]'::jsonb),

    'guest_coach_keys_used', coalesce((
      select jsonb_agg(jsonb_build_object(
        'routine', r.name,
        'used_at', k.redeemed_at,
        'expires_at', k.expires_at,
        'revoked_at', k.revoked_at
      ) order by k.redeemed_at)
      from public.guest_coach_keys k
      left join public.routines r on r.id = k.routine_id
      where k.guest_id = v_uid
    ), '[]'::jsonb),

    'guest_notes_written', coalesce((
      select jsonb_agg(jsonb_build_object('figure_id', g.node_id, 'note', g.body, 'written_at', g.created_at)
                       order by g.created_at)
      from public.guest_coach_notes g
      where g.author_id = v_uid
    ), '[]'::jsonb),

    'guest_notes_on_my_routines', coalesce((
      select jsonb_agg(jsonb_build_object('figure_id', g.node_id, 'note', g.body, 'by', k.guest_name, 'written_at', g.created_at)
                       order by g.created_at)
      from public.guest_coach_notes g
      join public.routines r on r.id = g.routine_id and r.user_id = v_uid
      left join public.guest_coach_keys k on k.id = g.key_id
    ), '[]'::jsonb),

    'uploaded_files', coalesce((
      select jsonb_agg(jsonb_build_object(
        'path', o.name,
        'size_bytes', (o.metadata->>'size')::bigint,
        'uploaded_at', o.created_at
      ) order by o.created_at)
      from storage.objects o
      where o.bucket_id = 'encore-media'
        and (storage.foldername(o.name))[1] = v_uid::text
    ), '[]'::jsonb)
  );
end;
$function$;

-- 2. Who may add and change figures: the routine's owner, the partner and the coach (whose changes the coach-notes
--    trigger limits). Before, the policies only asked who may see the routine, and the owner of Encore sees all.
create function public.can_edit_routine(p_routine uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.routines r
     where r.id = p_routine
       and (r.user_id = (select auth.uid())
         or exists (
           select 1 from public.connections c
            where c.status = 'accepted'
              and ((c.relationship_type = 'partner'
                    and ((c.user_a_id = (select auth.uid()) and c.user_b_id = r.user_id)
                      or (c.user_b_id = (select auth.uid()) and c.user_a_id = r.user_id)))
                or (c.relationship_type = 'coach_student'
                    and c.user_b_id = (select auth.uid()) and c.user_a_id = r.user_id)))));
$$;
revoke execute on function public.can_edit_routine(uuid) from public, anon;
grant execute on function public.can_edit_routine(uuid) to authenticated;

drop policy canvas_insert on public.canvas_nodes;
create policy canvas_insert on public.canvas_nodes for insert to authenticated
  with check (public.can_edit_routine(routine_id));
drop policy canvas_update on public.canvas_nodes;
create policy canvas_update on public.canvas_nodes for update to authenticated
  using (public.can_edit_routine(routine_id)) with check (public.can_edit_routine(routine_id));

-- 3. A KSIS number is verified in Súťaže (ksis_dancers), never typed into the profile.
create or replace function public.protect_profile_privileged_columns()
returns trigger language plpgsql security definer set search_path to 'public' as $function$
BEGIN
  -- Service role / postgres / auth triggers have no JWT user
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.role := 'user';
    NEW.account_status := 'active';
    NEW.ban_reason := NULL;
    NEW.dancer_code := NULL;            -- generated by trg_zz_profiles_server_defaults
    RETURN NEW;
  END IF;

  IF public.is_app_owner() THEN
    RETURN NEW;
  END IF;

  IF NEW.role IS DISTINCT FROM OLD.role
     OR NEW.account_status IS DISTINCT FROM OLD.account_status
     OR NEW.ban_reason IS DISTINCT FROM OLD.ban_reason THEN
    RAISE EXCEPTION 'Zmena roly alebo stavu účtu nie je povolená.' USING ERRCODE = '42501';
  END IF;

  IF NEW.dancer_code IS DISTINCT FROM OLD.dancer_code AND OLD.dancer_code IS NOT NULL THEN
    RAISE EXCEPTION 'Dancer ID sa nedá meniť.' USING ERRCODE = '42501';
  END IF;

  IF NEW.invite_code IS DISTINCT FROM OLD.invite_code AND OLD.invite_code IS NOT NULL THEN
    RAISE EXCEPTION 'Kód pozvánky sa nedá meniť.' USING ERRCODE = '42501';
  END IF;

  IF NEW.email IS DISTINCT FROM OLD.email THEN
    RAISE EXCEPTION 'E-mail sa mení cez nastavenia účtu, nie cez profil.' USING ERRCODE = '42501';
  END IF;

  IF NEW.ksis_id IS DISTINCT FROM OLD.ksis_id THEN
    RAISE EXCEPTION 'Číslo z KSIS sa overuje v Súťažiach, do profilu sa nepíše.' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;

-- 4. The old friends system and a table nothing reads (its class numbers were not the competition rules).
revoke execute on function public.refuse_blocked_connection() from public, anon, authenticated;
drop function public.send_friend_request_by_code(text);
drop table public.friends;
drop table public.advancement_rules;
