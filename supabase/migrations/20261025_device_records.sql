-- Backup of what lives only on the iPhone: the diary, the plan and the notes. Text and links to media only; videos
-- stay in Fotky, voice notes and photos on the iPhone. The iPhone saves first and sends what changed in batches
-- (DeviceBackup); an empty iPhone is filled back from here. Only the user reads and writes their own rows.

create table public.device_records (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind text not null check (kind in ('training_log', 'planned_session', 'planned_competition',
                                     'training_cadence', 'lesson_priority', 'instant_note')),
  id uuid not null,
  payload jsonb not null check (pg_column_size(payload) < 65536),
  updated_at timestamptz not null,
  deleted boolean not null default false,
  primary key (user_id, kind, id)
);
alter table public.device_records enable row level security;
create policy device_records_own on public.device_records for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create trigger device_records_rate_limit before insert on public.device_records
  for each row execute function public.limit_writes('device_record', '5000', '1 day');

-- The export includes the backup (GDPR art. 15 and 20).
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

    'this_iphone_backup', coalesce((
      select jsonb_agg(jsonb_build_object('kind', b.kind, 'id', b.id, 'record', b.payload, 'saved_at', b.updated_at)
                       order by b.kind, b.updated_at)
      from public.device_records b
      where b.user_id = v_uid and not b.deleted
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
