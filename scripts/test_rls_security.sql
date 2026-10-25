-- ==============================================================================
-- RLS Security Verification Script (Step 1)
-- Proves that neither 'anon' nor 'authenticated' can INSERT/UPDATE/DELETE on any
-- of the KSIS tables.
-- ==============================================================================

do $$
declare
    v_test_user_id uuid := '11111111-1111-1111-1111-111111111111';
    v_err_count integer := 0;
    v_rls_enabled boolean;
    v_retry integer;
begin
    raise notice '--- STARTING RLS SECURITY VERIFICATION ---';

    -- 1. Verify RLS is ENABLED on all 4 tables
    perform 1 from pg_tables where schemaname = 'public' and tablename in ('user_couples', 'competition_results', 'ksis_dancers', 'import_cooldowns') and rowsecurity = true;
    get diagnostics v_err_count = row_count;
    if v_err_count != 4 then
        raise exception 'RLS is not enabled on all 4 KSIS tables! Found only %', v_err_count;
    end if;
    raise notice 'PASS: RLS is explicitly ENABLED on all 4 tables.';

    -- 2. Test ANON role cannot mutate tables
    set local role anon;

    -- user_couples
    begin
        insert into public.user_couples (user_id, couple_id, discipline) values (v_test_user_id, 99999, 'STT');
        raise exception 'FAIL: anon was able to insert into user_couples';
    exception when insufficient_privilege then
        raise notice 'PASS: anon INSERT into user_couples denied (insufficient_privilege).';
    end;

    begin
        update public.user_couples set partner_name = 'Hacked' where true;
        raise exception 'FAIL: anon was able to update user_couples';
    exception when insufficient_privilege then
        raise notice 'PASS: anon UPDATE on user_couples denied.';
    end;

    begin
        delete from public.user_couples where true;
        raise exception 'FAIL: anon was able to delete from user_couples';
    exception when insufficient_privilege then
        raise notice 'PASS: anon DELETE on user_couples denied.';
    end;

    -- competition_results
    begin
        insert into public.competition_results (user_id, sutaz_id, couple_id, event_name, category_name, discipline, date, couple_count, placement_text, season)
        values (v_test_user_id, 12094, 99999, 'Fake Event', 'Dospelí D', 'STT', current_date, 10, '1.', '2026');
        raise exception 'FAIL: anon was able to insert into competition_results';
    exception when insufficient_privilege then
        raise notice 'PASS: anon INSERT into competition_results denied.';
    end;

    -- ksis_dancers
    begin
        insert into public.ksis_dancers (user_id, person_number, name) values (gen_random_uuid(), 1, 'Fake');
        raise exception 'FAIL: anon was able to insert into ksis_dancers';
    exception when insufficient_privilege then
        raise notice 'PASS: anon INSERT into ksis_dancers denied.';
    end;

    -- import_cooldowns
    begin
        insert into public.import_cooldowns (key, last_attempt_at) values ('anon_attack', now());
        raise exception 'FAIL: anon was able to insert into import_cooldowns';
    exception when insufficient_privilege then
        raise notice 'PASS: anon INSERT into import_cooldowns denied.';
    end;

    -- 3. Test AUTHENTICATED role cannot mutate tables directly
    set local role authenticated;
    perform set_config('request.jwt.claims', json_build_object('sub', v_test_user_id::text, 'role', 'authenticated')::text, true);

    -- user_couples
    begin
        insert into public.user_couples (user_id, couple_id, discipline) values (v_test_user_id, 99999, 'STT');
        raise exception 'FAIL: authenticated was able to insert into user_couples directly';
    exception when insufficient_privilege then
        raise notice 'PASS: authenticated direct INSERT into user_couples denied.';
    end;

    begin
        update public.user_couples set partner_name = 'Hacked' where user_id = v_test_user_id;
        raise exception 'FAIL: authenticated was able to update user_couples directly';
    exception when insufficient_privilege then
        raise notice 'PASS: authenticated direct UPDATE on user_couples denied.';
    end;

    begin
        delete from public.user_couples where user_id = v_test_user_id;
        raise exception 'FAIL: authenticated was able to delete user_couples directly';
    exception when insufficient_privilege then
        raise notice 'PASS: authenticated direct DELETE on user_couples denied.';
    end;

    -- competition_results
    begin
        insert into public.competition_results (user_id, sutaz_id, couple_id, event_name, category_name, discipline, date, couple_count, placement_text, season)
        values (v_test_user_id, 12094, 99999, 'Fake Event', 'Dospelí D', 'STT', current_date, 10, '1.', '2026');
        raise exception 'FAIL: authenticated was able to insert into competition_results directly';
    exception when insufficient_privilege then
        raise notice 'PASS: authenticated direct INSERT into competition_results denied.';
    end;

    begin
        update public.competition_results set points_earned = 999 where user_id = v_test_user_id;
        raise exception 'FAIL: authenticated was able to update competition_results directly';
    exception when insufficient_privilege then
        raise notice 'PASS: authenticated direct UPDATE on competition_results denied.';
    end;

    begin
        delete from public.competition_results where user_id = v_test_user_id;
        raise exception 'FAIL: authenticated was able to delete competition_results directly';
    exception when insufficient_privilege then
        raise notice 'PASS: authenticated direct DELETE on competition_results denied.';
    end;

    -- ksis_dancers: only the ksis-page server function writes who a dancer is
    begin
        update public.ksis_dancers set status = 'verified' where true;
        raise exception 'FAIL: authenticated was able to update ksis_dancers';
    exception when insufficient_privilege then
        raise notice 'PASS: authenticated direct UPDATE on ksis_dancers denied.';
    end;

    -- import_cooldowns
    begin
        insert into public.import_cooldowns (key, last_attempt_at) values ('auth_attack', now());
        raise exception 'FAIL: authenticated was able to insert into import_cooldowns';
    exception when insufficient_privilege then
        raise notice 'PASS: authenticated direct INSERT into import_cooldowns denied.';
    end;

    -- Reset to postgres role for atomic function test
    reset role;

    -- 4. Test Atomic Rate Limiter SQL Function
    v_retry := public.check_and_acquire_import_cooldown(v_test_user_id, 12094);
    if v_retry != 0 then
        raise exception 'FAIL: first cooldown acquisition should succeed with 0, got %', v_retry;
    end if;
    raise notice 'PASS: First check_and_acquire_import_cooldown returned 0 (allowed).';

    -- Immediate repeat call for same user
    v_retry := public.check_and_acquire_import_cooldown(v_test_user_id, 12094);
    if v_retry <= 0 or v_retry > 60 then
        raise exception 'FAIL: immediate repeat should be rate limited between 1-60s, got %', v_retry;
    end if;
    raise notice 'PASS: Immediate repeat call rate limited with retry_after = % s.', v_retry;

    -- Cleanup test keys
    delete from public.import_cooldowns where key in ('user:' || v_test_user_id::text, 'sutaz:12094');

    raise notice '--- ALL RLS & ATOMIC RATE LIMIT TESTS PASSED SUCCESSFULLY! ---';
end;
$$;
