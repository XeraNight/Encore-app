-- ==============================================================================
-- 🔒 ENCORE — COMPREHENSIVE SECURITY HARDENING, SCHEMA FIXES & INVITES MIGRATION
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. PROFILES: Schema Drift Fixes & New Metadata Columns
-- ------------------------------------------------------------------------------

-- Generated column full_name from name to resolve all RPCs, views and queries
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS full_name TEXT GENERATED ALWAYS AS (COALESCE(name, 'Tanečník')) STORED;

-- Columns for KSIS, dancer groups, card theme, moderation, and role
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS ksis_id TEXT,
  ADD COLUMN IF NOT EXISTS dancer_groups JSONB DEFAULT '["Štandardné tance", "Latinskoamerické tance"]'::jsonb,
  ADD COLUMN IF NOT EXISTS card_theme JSONB DEFAULT '{"theme_id": "carmine_gold", "background_color": "rgb(102, 3, 18)", "foreground_color": "rgb(255, 230, 153)", "label_color": "rgb(212, 175, 55)", "logo_text": "ENCORE"}'::jsonb,
  ADD COLUMN IF NOT EXISTS account_status TEXT DEFAULT 'active' CHECK (account_status IN ('active', 'suspended', 'banned')),
  ADD COLUMN IF NOT EXISTS ban_reason TEXT,
  ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user' CHECK (role IN ('user', 'coach', 'admin', 'owner')),
  ADD COLUMN IF NOT EXISTS dancer_code TEXT UNIQUE;

-- ------------------------------------------------------------------------------
-- 2. HELPER: is_app_owner() (Deterministic email verification, not mutable role)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_app_owner()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND LOWER(u.email) = 'jakubkalina05@gmail.com'
      AND u.email_confirmed_at IS NOT NULL
  );
$$;

REVOKE EXECUTE ON FUNCTION public.is_app_owner() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.is_app_owner() TO authenticated;

-- ------------------------------------------------------------------------------
-- 3. REVOKE ANONYMOUS ACCESS TO USER & DATA TABLES
-- ------------------------------------------------------------------------------

REVOKE ALL ON TABLE public.routines, public.canvas_nodes,
                    public.figure_library_items, public.profiles,
                    public.user_entitlements, public.connections FROM anon;

-- ------------------------------------------------------------------------------
-- 4. CLEAN OLD INSECURE POLICIES ON CORE TABLES
-- ------------------------------------------------------------------------------

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT policyname, tablename FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('routines','canvas_nodes','figure_library_items','profiles','user_entitlements')
  LOOP
    EXECUTE FORMAT('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

ALTER TABLE public.routines            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.canvas_nodes        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.figure_library_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_entitlements   ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 5. OWNERSHIP COLUMNS & BACKFILL (routines & figure_library_items)
-- ------------------------------------------------------------------------------

ALTER TABLE public.routines
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) DEFAULT auth.uid();
ALTER TABLE public.routines
  ADD COLUMN IF NOT EXISTS last_modified_by TEXT;

ALTER TABLE public.figure_library_items
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid();

-- Backfill existing rows without an owner to app owner (jakubkalina05@gmail.com)
UPDATE public.routines
   SET user_id = (SELECT id FROM auth.users WHERE LOWER(email) = 'jakubkalina05@gmail.com' LIMIT 1)
 WHERE user_id IS NULL;

UPDATE public.figure_library_items
   SET user_id = (SELECT id FROM auth.users WHERE LOWER(email) = 'jakubkalina05@gmail.com' LIMIT 1)
 WHERE user_id IS NULL;

-- ------------------------------------------------------------------------------
-- 6. STRICT RLS POLICIES: PROFILES
-- ------------------------------------------------------------------------------

-- Users read their own profile; app owner can read all profiles for administration
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = id OR public.is_app_owner());

CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ------------------------------------------------------------------------------
-- 7. TRIGGER: Protect privileged columns in profiles (role, account_status, ban_reason)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.protect_profile_privileged_columns()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- Service role / postgres / auth triggers have auth.uid() null
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  -- Normal signups cannot assign themselves admin/owner or banned status
  IF TG_OP = 'INSERT' THEN
    NEW.role := 'user';
    NEW.account_status := 'active';
    NEW.ban_reason := NULL;
    RETURN NEW;
  END IF;

  -- Updates: regular user cannot escalate role or clear own ban
  IF (NEW.role IS DISTINCT FROM OLD.role
      OR NEW.account_status IS DISTINCT FROM OLD.account_status
      OR NEW.ban_reason IS DISTINCT FROM OLD.ban_reason)
     AND NOT public.is_app_owner() THEN
    RAISE EXCEPTION 'Zmena roly alebo stavu účtu nie je povolená.' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_protect_profile_privileged ON public.profiles;
CREATE TRIGGER trg_protect_profile_privileged
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_profile_privileged_columns();

-- ------------------------------------------------------------------------------
-- 8. STRICT RLS POLICIES: ROUTINES
-- ------------------------------------------------------------------------------

CREATE POLICY "routines_select" ON public.routines
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_app_owner()
    OR EXISTS (
      SELECT 1 FROM public.connections c
      WHERE c.status = 'accepted' AND (
        (c.relationship_type = 'partner' AND
          ((c.user_a_id = auth.uid() AND c.user_b_id = routines.user_id) OR
           (c.user_b_id = auth.uid() AND c.user_a_id = routines.user_id)))
        OR (c.relationship_type = 'coach_student' AND
            c.user_b_id = auth.uid() AND c.user_a_id = routines.user_id)
      )
    )
  );

CREATE POLICY "routines_insert" ON public.routines
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "routines_update" ON public.routines
  FOR UPDATE TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.connections c
      WHERE c.status = 'accepted' AND (
        (c.relationship_type = 'partner' AND
          ((c.user_a_id = auth.uid() AND c.user_b_id = routines.user_id) OR
           (c.user_b_id = auth.uid() AND c.user_a_id = routines.user_id)))
        OR (c.relationship_type = 'coach_student' AND
            c.user_b_id = auth.uid() AND c.user_a_id = routines.user_id)
      )
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.connections c
      WHERE c.status = 'accepted' AND (
        (c.relationship_type = 'partner' AND
          ((c.user_a_id = auth.uid() AND c.user_b_id = routines.user_id) OR
           (c.user_b_id = auth.uid() AND c.user_a_id = routines.user_id)))
        OR (c.relationship_type = 'coach_student' AND
            c.user_b_id = auth.uid() AND c.user_a_id = routines.user_id)
      )
    )
  );

CREATE POLICY "routines_delete" ON public.routines
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 9. STRICT RLS POLICIES: CANVAS_NODES (Derived from parent routine)
-- ------------------------------------------------------------------------------

CREATE POLICY "canvas_select" ON public.canvas_nodes
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.routines r WHERE r.id = canvas_nodes.routine_id));

CREATE POLICY "canvas_insert" ON public.canvas_nodes
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.routines r WHERE r.id = canvas_nodes.routine_id));

CREATE POLICY "canvas_update" ON public.canvas_nodes
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.routines r WHERE r.id = canvas_nodes.routine_id))
  WITH CHECK (EXISTS (SELECT 1 FROM public.routines r WHERE r.id = canvas_nodes.routine_id));

CREATE POLICY "canvas_delete" ON public.canvas_nodes
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.routines r WHERE r.id = canvas_nodes.routine_id AND r.user_id = auth.uid()));

-- ------------------------------------------------------------------------------
-- 10. STRICT RLS POLICIES: FIGURE_LIBRARY_ITEMS (User private)
-- ------------------------------------------------------------------------------

CREATE POLICY "figures_owner_all" ON public.figure_library_items
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 11. STRICT RLS POLICIES: USER_ENTITLEMENTS
-- ------------------------------------------------------------------------------

CREATE POLICY "entitlements_select" ON public.user_entitlements
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR public.is_app_owner());

CREATE POLICY "entitlements_owner_write" ON public.user_entitlements
  FOR ALL TO authenticated
  USING (public.is_app_owner())
  WITH CHECK (public.is_app_owner());

-- ------------------------------------------------------------------------------
-- 12. RPC: admin_grant_entitlement_by_email (Owner VIP Gift)
-- ------------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.admin_grant_entitlement_by_email(TEXT, TEXT, INT, TEXT);
CREATE OR REPLACE FUNCTION public.admin_grant_entitlement_by_email(
  p_email TEXT,
  p_tier TEXT,
  p_duration_months INT DEFAULT NULL,
  p_note TEXT DEFAULT 'VIP Darovanie od majiteľa'
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_target UUID;
  v_exp TIMESTAMPTZ := NULL;
BEGIN
  IF NOT public.is_app_owner() THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'FORBIDDEN',
                              'message', 'Nemáš oprávnenie majiteľa aplikácie.');
  END IF;

  IF LOWER(p_tier) NOT IN ('free', 'plus', 'studio') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'BAD_TIER',
                              'message', 'Neplatná úroveň predplatného.');
  END IF;

  SELECT id INTO v_target
  FROM auth.users
  WHERE LOWER(email) = LOWER(TRIM(p_email))
  LIMIT 1;

  IF v_target IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'USER_NOT_FOUND',
      'message', 'Používateľ ' || p_email || ' sa ešte nezaregistroval v Encore.'
    );
  END IF;

  IF p_duration_months IS NOT NULL AND p_duration_months > 0 THEN
    v_exp := now() + (p_duration_months || ' months')::interval;
  END IF;

  INSERT INTO public.user_entitlements (user_id, tier, source, expires_at, granted_by, notes, updated_at)
  VALUES (v_target, LOWER(p_tier), 'owner_grant', v_exp, auth.uid(), p_note, now())
  ON CONFLICT (user_id) DO UPDATE SET
    tier = EXCLUDED.tier,
    source = 'owner_grant',
    expires_at = EXCLUDED.expires_at,
    granted_by = auth.uid(),
    notes = EXCLUDED.notes,
    updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Plán ' || UPPER(p_tier) || ' bol úspešne udelený pre ' || p_email || '!'
  );
END $$;

REVOKE EXECUTE ON FUNCTION public.admin_grant_entitlement_by_email(TEXT, TEXT, INT, TEXT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_grant_entitlement_by_email(TEXT, TEXT, INT, TEXT) TO authenticated;

-- ------------------------------------------------------------------------------
-- 13. RPC: admin_set_account_status (Owner Ban / Unban)
-- ------------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.admin_set_account_status(UUID, BOOLEAN, TEXT);
CREATE OR REPLACE FUNCTION public.admin_set_account_status(
  p_user UUID,
  p_banned BOOLEAN,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_app_owner() THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'FORBIDDEN',
                              'message', 'Nemáš oprávnenie majiteľa aplikácie.');
  END IF;

  UPDATE public.profiles
     SET account_status = CASE WHEN p_banned THEN 'banned' ELSE 'active' END,
         ban_reason     = CASE WHEN p_banned THEN p_reason ELSE NULL END
   WHERE id = p_user;

  RETURN jsonb_build_object('success', FOUND, 'banned', p_banned);
END $$;

REVOKE EXECUTE ON FUNCTION public.admin_set_account_status(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_set_account_status(UUID, BOOLEAN, TEXT) TO authenticated;

-- ------------------------------------------------------------------------------
-- 14. RPC: record_app_store_transaction (Secure User StoreKit Sync)
-- ------------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.record_app_store_transaction(TEXT, TEXT, TIMESTAMPTZ);
CREATE OR REPLACE FUNCTION public.record_app_store_transaction(
  p_tier TEXT,
  p_product_id TEXT,
  p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  END IF;

  IF LOWER(p_tier) NOT IN ('free', 'plus', 'studio') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'BAD_TIER');
  END IF;

  INSERT INTO public.user_entitlements (user_id, tier, source, expires_at, notes, updated_at)
  VALUES (v_user, LOWER(p_tier), 'storekit', p_expires_at, 'StoreKit 2: ' || p_product_id, now())
  ON CONFLICT (user_id) DO UPDATE SET
    tier = CASE
      WHEN user_entitlements.source = 'owner_grant' AND user_entitlements.tier = 'studio' THEN user_entitlements.tier
      ELSE EXCLUDED.tier
    END,
    source = CASE
      WHEN user_entitlements.source = 'owner_grant' AND user_entitlements.tier = 'studio' THEN user_entitlements.source
      ELSE 'storekit'
    END,
    expires_at = CASE
      WHEN user_entitlements.source = 'owner_grant' AND user_entitlements.tier = 'studio' THEN user_entitlements.expires_at
      ELSE EXCLUDED.expires_at
    END,
    notes = EXCLUDED.notes,
    updated_at = now();

  RETURN jsonb_build_object('success', true);
END $$;

REVOKE EXECUTE ON FUNCTION public.record_app_store_transaction(TEXT, TEXT, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.record_app_store_transaction(TEXT, TEXT, TIMESTAMPTZ) TO authenticated;

-- ------------------------------------------------------------------------------
-- 15. RPC: search_dancers (Authenticated Search)
-- ------------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.search_dancers(TEXT);
CREATE OR REPLACE FUNCTION public.search_dancers(query TEXT)
RETURNS TABLE (
  id UUID,
  dancer_code TEXT,
  full_name TEXT,
  club TEXT,
  avatar_url TEXT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  IF length(trim(query)) < 2 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT p.id,
         p.dancer_code,
         COALESCE(p.name, p.full_name, 'Tanečník') AS full_name,
         p.club,
         p.avatar_url
  FROM public.profiles p
  WHERE (p.account_status IS NULL OR p.account_status = 'active')
    AND (p.dancer_code ILIKE query || '%' OR COALESCE(p.name, p.full_name) ILIKE '%' || query || '%')
  LIMIT 10;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.search_dancers(TEXT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.search_dancers(TEXT) TO authenticated;

-- ------------------------------------------------------------------------------
-- 16. TABLE & FUNCTIONS: INVITE_TOKENS (Secure QR & Universal Links)
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.invite_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT UNIQUE NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days'),
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invite_tokens_token ON public.invite_tokens(token);
CREATE INDEX IF NOT EXISTS idx_invite_tokens_user ON public.invite_tokens(user_id);

ALTER TABLE public.invite_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "invite_tokens_owner_all" ON public.invite_tokens;
CREATE POLICY "invite_tokens_owner_all" ON public.invite_tokens
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- RPC: create_friend_invite_token
DROP FUNCTION IF EXISTS public.create_friend_invite_token(INT);
CREATE OR REPLACE FUNCTION public.create_friend_invite_token(p_expires_in_days INT DEFAULT 7)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_token TEXT;
  caller_id UUID := auth.uid();
BEGIN
  IF caller_id IS NULL THEN
    RAISE EXCEPTION 'Neautorizovaný prístup.';
  END IF;

  UPDATE public.invite_tokens
  SET revoked_at = now()
  WHERE user_id = caller_id AND revoked_at IS NULL;

  new_token := 'tok_' || replace(gen_random_uuid()::text, '-', '');

  INSERT INTO public.invite_tokens (user_id, token, expires_at)
  VALUES (caller_id, new_token, now() + (p_expires_in_days || ' days')::interval);

  RETURN new_token;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_friend_invite_token(INT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.create_friend_invite_token(INT) TO authenticated;

-- RPC: get_friend_invite_preview (Safe public preview)
DROP FUNCTION IF EXISTS public.get_friend_invite_preview(TEXT);
CREATE OR REPLACE FUNCTION public.get_friend_invite_preview(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token RECORD;
  v_profile RECORD;
  v_caller UUID := auth.uid();
  v_is_self BOOLEAN := FALSE;
  v_already_connected BOOLEAN := FALSE;
  v_pending BOOLEAN := FALSE;
BEGIN
  SELECT * INTO v_token
  FROM public.invite_tokens
  WHERE token = p_token;

  IF v_token IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'NOT_FOUND', 'message', 'Pozvánka neexistuje.');
  END IF;

  IF v_token.revoked_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'REVOKED', 'message', 'Tento QR kód bol zrušený a obnovený novým.');
  END IF;

  IF v_token.expires_at < now() THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'EXPIRED', 'message', 'Platnosť tohto QR kódu vypršala.');
  END IF;

  IF v_caller IS NOT NULL AND v_caller = v_token.user_id THEN
    v_is_self := TRUE;
  END IF;

  IF v_caller IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.connections
      WHERE ((user_a_id = v_caller AND user_b_id = v_token.user_id)
          OR (user_a_id = v_token.user_id AND user_b_id = v_caller))
        AND status = 'accepted'
    ) INTO v_already_connected;

    SELECT EXISTS (
      SELECT 1 FROM public.connections
      WHERE ((user_a_id = v_caller AND user_b_id = v_token.user_id)
          OR (user_a_id = v_token.user_id AND user_b_id = v_caller))
        AND status = 'pending'
    ) INTO v_pending;
  END IF;

  SELECT name, full_name, club, avatar_url, ksis_id, dancer_code, dancer_groups, card_theme
  INTO v_profile
  FROM public.profiles
  WHERE id = v_token.user_id;

  RETURN jsonb_build_object(
    'success', true,
    'is_self', v_is_self,
    'already_connected', v_already_connected,
    'is_pending', v_pending,
    'inviter', jsonb_build_object(
      'name', COALESCE(v_profile.name, v_profile.full_name, 'Tanečník Encore'),
      'club', COALESCE(v_profile.club, 'Individuálny'),
      'avatar_url', v_profile.avatar_url,
      'ksis_id', v_profile.ksis_id,
      'dancer_code', COALESCE(v_profile.dancer_code, 'DNC-0000'),
      'dancer_groups', COALESCE(v_profile.dancer_groups, '["Štandard", "Latina"]'::jsonb),
      'card_theme', v_profile.card_theme
    )
  );
END;
$$;

-- Allow anon and authenticated to preview invite
GRANT EXECUTE ON FUNCTION public.get_friend_invite_preview(TEXT) TO anon, authenticated;

-- RPC: respond_to_friend_invite
DROP FUNCTION IF EXISTS public.respond_to_friend_invite(TEXT, BOOLEAN);
CREATE OR REPLACE FUNCTION public.respond_to_friend_invite(p_token TEXT, p_accept BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token RECORD;
  v_caller UUID := auth.uid();
  v_existing_conn RECORD;
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED', 'message', 'Musíš byť prihlásený.');
  END IF;

  SELECT * INTO v_token
  FROM public.invite_tokens
  WHERE token = p_token;

  IF v_token IS NULL OR v_token.revoked_at IS NOT NULL OR v_token.expires_at < now() THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_TOKEN', 'message', 'Pozvánka je neplatná alebo expirovala.');
  END IF;

  IF v_caller = v_token.user_id THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'SELF_INVITE', 'message', 'Nemôžeš potvrdiť pozvánku sám sebe.');
  END IF;

  SELECT * INTO v_existing_conn
  FROM public.connections
  WHERE (user_a_id = v_caller AND user_b_id = v_token.user_id AND relationship_type = 'partner')
     OR (user_a_id = v_token.user_id AND user_b_id = v_caller AND relationship_type = 'partner');

  IF p_accept THEN
    IF v_existing_conn IS NOT NULL THEN
      UPDATE public.connections
      SET status = 'accepted', updated_at = now()
      WHERE id = v_existing_conn.id;
    ELSE
      INSERT INTO public.connections (user_a_id, user_b_id, relationship_type, status, initiated_by)
      VALUES (v_token.user_id, v_caller, 'partner', 'accepted', v_caller);
    END IF;

    RETURN jsonb_build_object('success', true, 'status', 'accepted', 'message', 'Pozvánka bola úspešne prijatá.');
  ELSE
    IF v_existing_conn IS NOT NULL AND v_existing_conn.status = 'pending' THEN
      UPDATE public.connections
      SET status = 'rejected', updated_at = now()
      WHERE id = v_existing_conn.id;
    END IF;

    RETURN jsonb_build_object('success', true, 'status', 'rejected', 'message', 'Pozvánka bola odmietnutá.');
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.respond_to_friend_invite(TEXT, BOOLEAN) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.respond_to_friend_invite(TEXT, BOOLEAN) TO authenticated;

-- ------------------------------------------------------------------------------
-- 17. STORAGE: BUCKET encore-media & STORAGE RLS POLICIES
-- ------------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'encore-media',
  'encore-media',
  false,
  104857600, -- 100 MB max file size
  ARRAY['video/mp4', 'video/quicktime', 'image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 104857600,
  allowed_mime_types = ARRAY['video/mp4', 'video/quicktime', 'image/jpeg', 'image/png', 'image/webp'];

-- Storage RLS on storage.objects
DROP POLICY IF EXISTS "encore_media_insert" ON storage.objects;
CREATE POLICY "encore_media_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'encore-media'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_app_owner()
    )
  );

DROP POLICY IF EXISTS "encore_media_update" ON storage.objects;
CREATE POLICY "encore_media_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'encore-media'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_app_owner()
    )
  );

DROP POLICY IF EXISTS "encore_media_select" ON storage.objects;
CREATE POLICY "encore_media_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'encore-media'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_app_owner()
      OR EXISTS (
        SELECT 1 FROM public.connections c
        WHERE c.status = 'accepted' AND (
          (c.relationship_type = 'partner' AND
            ((c.user_a_id = auth.uid() AND c.user_b_id::text = (storage.foldername(name))[1]) OR
             (c.user_b_id = auth.uid() AND c.user_a_id::text = (storage.foldername(name))[1])))
          OR (c.relationship_type = 'coach_student' AND
              c.user_b_id = auth.uid() AND c.user_a_id::text = (storage.foldername(name))[1])
        )
      )
    )
  );

DROP POLICY IF EXISTS "encore_media_delete" ON storage.objects;
CREATE POLICY "encore_media_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'encore-media'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_app_owner()
    )
  );

COMMIT;

NOTIFY pgrst, 'reload schema';
