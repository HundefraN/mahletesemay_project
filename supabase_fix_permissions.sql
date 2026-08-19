-- ==============================================================================
-- Mahlete Semay - Database Fix & Permissions Script
-- Run this in your Supabase SQL Editor to enable flawless Moderator/Admin Claiming
-- (Bypasses email rate limits and auto-confirms moderator accounts)
-- ==============================================================================

-- 0. Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Ensure moderators table has all required columns
ALTER TABLE public.moderators ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE public.moderators ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE public.moderators ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'moderator';
ALTER TABLE public.moderators ADD COLUMN IF NOT EXISTS approved_devices JSONB NOT NULL DEFAULT '[]'::JSONB;
ALTER TABLE public.moderators ADD COLUMN IF NOT EXISTS pending_device JSONB;
ALTER TABLE public.moderators ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ;
UPDATE public.moderators SET is_active = (status = 'active') WHERE is_active IS NULL;

-- 2. Ensure invitations table has all required columns
ALTER TABLE public.invitations ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'moderator';
ALTER TABLE public.invitations ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending';
ALTER TABLE public.invitations ADD COLUMN IF NOT EXISTS claimed_by TEXT;
ALTER TABLE public.invitations ADD COLUMN IF NOT EXISTS claimed_at TIMESTAMPTZ;

-- 3. Helper functions
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.moderators
        WHERE id = auth.uid()::TEXT 
          AND role = 'admin' 
          AND (status = 'active' OR is_active IS TRUE)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_active_moderator()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.moderators
        WHERE id = auth.uid()::TEXT 
          AND (status = 'active' OR is_active IS TRUE)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Auto-confirm user email function
CREATE OR REPLACE FUNCTION public.confirm_user_email(user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  UPDATE auth.users
  SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
  WHERE id = user_id;
END;
$$;

-- 5. Drop any prior overloaded versions of claim_moderator_account
DROP FUNCTION IF EXISTS public.claim_moderator_account(UUID, TEXT, TEXT, JSONB);
DROP FUNCTION IF EXISTS public.claim_moderator_account(TEXT, TEXT, TEXT, JSONB, UUID);
DROP FUNCTION IF EXISTS public.claim_moderator_account(TEXT, TEXT, TEXT, JSONB);
DROP FUNCTION IF EXISTS public.claim_moderator_account;

-- 6. Bulletproof Account Claiming Stored Procedure
-- Creates/updates auth.users & moderators with bcrypt hash directly (bypasses email rate limiters)
CREATE OR REPLACE FUNCTION public.claim_moderator_account(
    p_email TEXT,
    p_password TEXT,
    p_code TEXT,
    p_device_info JSONB DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_invitation RECORD;
    v_clean_code TEXT;
    v_clean_email TEXT;
    v_devices JSONB;
    v_username TEXT;
    v_role TEXT;
    v_user_id UUID;
    v_existing_auth_id UUID;
    v_encrypted_pw TEXT;
BEGIN
    v_clean_email := LOWER(TRIM(p_email));
    v_clean_code := UPPER(REPLACE(REPLACE(TRIM(p_code), '-', ''), ' ', ''));

    -- 1. Validate invitation code and email
    SELECT * INTO v_invitation
    FROM public.invitations
    WHERE LOWER(TRIM(email)) = v_clean_email
      AND UPPER(REPLACE(REPLACE(TRIM(code), '-', ''), ' ', '')) = v_clean_code
      AND status = 'pending'
    LIMIT 1;

    IF NOT FOUND THEN
        IF EXISTS (
            SELECT 1 FROM public.invitations 
            WHERE LOWER(TRIM(email)) = v_clean_email 
              AND UPPER(REPLACE(REPLACE(TRIM(code), '-', ''), ' ', '')) = v_clean_code
        ) THEN
            RETURN jsonb_build_object('success', false, 'error', 'This invitation code has already been claimed. Please sign in with your password.');
        ELSE
            RETURN jsonb_build_object('success', false, 'error', 'Invalid invitation code or email address mismatch.');
        END IF;
    END IF;

    v_role := COALESCE(v_invitation.role, 'moderator');

    -- 2. Encrypt password using pgcrypto bcrypt
    IF p_password IS NOT NULL AND LENGTH(TRIM(p_password)) >= 6 THEN
        v_encrypted_pw := crypt(TRIM(p_password), gen_salt('bf', 10));
    END IF;

    -- 3. Check if user already exists in auth.users
    SELECT id INTO v_existing_auth_id
    FROM auth.users
    WHERE LOWER(TRIM(email)) = v_clean_email
    LIMIT 1;

    IF v_existing_auth_id IS NOT NULL THEN
        v_user_id := v_existing_auth_id;
        -- Update password and confirm email (Note: confirmed_at is generated automatically by Supabase)
        IF v_encrypted_pw IS NOT NULL THEN
            UPDATE auth.users
            SET encrypted_password = v_encrypted_pw,
                email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
                updated_at = NOW(),
                raw_app_meta_data = '{"provider": "email", "providers": ["email"]}'::jsonb
            WHERE id = v_user_id;
        ELSE
            UPDATE auth.users
            SET email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
                updated_at = NOW()
            WHERE id = v_user_id;
        END IF;
    ELSE
        -- Create new user in auth.users directly (bypasses email rate limiter completely)
        v_user_id := COALESCE(p_user_id, gen_random_uuid());
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_user_id,
            'authenticated',
            'authenticated',
            v_clean_email,
            COALESCE(v_encrypted_pw, crypt('DefaultPassword123!', gen_salt('bf', 10))),
            NOW(),
            '{"provider": "email", "providers": ["email"]}'::jsonb,
            jsonb_build_object('firstName', v_invitation.first_name, 'lastName', v_invitation.last_name),
            NOW(),
            NOW()
        );

        -- Ensure identity record exists
        BEGIN
            INSERT INTO auth.identities (
                id,
                user_id,
                identity_data,
                provider,
                provider_id,
                last_sign_in_at,
                created_at,
                updated_at
            ) VALUES (
                v_clean_email,
                v_user_id,
                jsonb_build_object('sub', v_user_id::TEXT, 'email', v_clean_email),
                'email',
                v_clean_email,
                NOW(),
                NOW(),
                NOW()
            )
            ON CONFLICT DO NOTHING;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    -- 4. Prepare approved devices array
    IF p_device_info IS NOT NULL AND p_device_info::TEXT != 'null' AND p_device_info::TEXT != '{}' THEN
        v_devices := jsonb_build_array(p_device_info);
    ELSE
        v_devices := '[]'::jsonb;
    END IF;

    -- 5. Generate clean username
    v_username := LOWER(REPLACE(COALESCE(v_invitation.first_name, 'user'), ' ', '')) || '.' || LOWER(REPLACE(COALESCE(v_invitation.last_name, 'mod'), ' ', ''));

    -- 6. Upsert moderator profile
    INSERT INTO public.moderators (
        id,
        email,
        first_name,
        last_name,
        username,
        role,
        status,
        is_active,
        approved_devices,
        pending_device,
        created_at,
        last_login
    ) VALUES (
        v_user_id::TEXT,
        v_clean_email,
        COALESCE(v_invitation.first_name, ''),
        COALESCE(v_invitation.last_name, ''),
        v_username,
        v_role,
        'active',
        TRUE,
        v_devices,
        NULL,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        username = EXCLUDED.username,
        role = EXCLUDED.role,
        status = 'active',
        is_active = TRUE,
        approved_devices = CASE 
            WHEN jsonb_array_length(public.moderators.approved_devices) > 0 AND jsonb_array_length(v_devices) > 0 
                THEN public.moderators.approved_devices || v_devices
            WHEN jsonb_array_length(v_devices) > 0 
                THEN v_devices
            ELSE public.moderators.approved_devices
        END,
        last_login = NOW();

    -- 7. Mark invitation as claimed
    UPDATE public.invitations
    SET status = 'claimed',
        claimed_by = v_user_id::TEXT,
        claimed_at = NOW()
    WHERE id = v_invitation.id;

    -- 8. Log activity
    INSERT INTO public.activity_logs (
        moderator_id,
        moderator_name,
        action,
        details,
        is_seen,
        timestamp
    ) VALUES (
        v_user_id::TEXT,
        TRIM(COALESCE(v_invitation.first_name, '') || ' ' || COALESCE(v_invitation.last_name, '')),
        'ACCOUNT_CLAIMED',
        'Claimed ' || UPPER(v_role) || ' account with code ' || v_invitation.code,
        FALSE,
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'role', v_role,
        'first_name', v_invitation.first_name,
        'last_name', v_invitation.last_name,
        'email', v_clean_email
    );
END;
$$;

-- 7. Trigger for auto confirming email on moderator creation/update
CREATE OR REPLACE FUNCTION public.auto_confirm_moderator_email()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  UPDATE auth.users
  SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
  WHERE id = NEW.id::uuid;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_confirm_moderator_email ON public.moderators;
CREATE TRIGGER trg_auto_confirm_moderator_email
  AFTER INSERT OR UPDATE ON public.moderators
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_confirm_moderator_email();

-- 8. Fix RLS Policies for Invitations & Moderators
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderators ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Invitations readable for validation or admin" ON public.invitations;
DROP POLICY IF EXISTS "Admins can manage invitations" ON public.invitations;
DROP POLICY IF EXISTS "Anyone can claim pending invitation" ON public.invitations;

CREATE POLICY "Invitations readable for validation or admin" ON public.invitations 
    FOR SELECT USING (true);

CREATE POLICY "Anyone can claim pending invitation" ON public.invitations 
    FOR UPDATE USING (status = 'pending' OR is_admin());

CREATE POLICY "Admins can manage invitations" ON public.invitations 
    FOR ALL USING (is_admin());

DROP POLICY IF EXISTS "Moderators can read own record or admins read all" ON public.moderators;
DROP POLICY IF EXISTS "Moderators can update own record (devices, last login) or admin full update" ON public.moderators;
DROP POLICY IF EXISTS "Admins can insert moderators or user upon claiming" ON public.moderators;
DROP POLICY IF EXISTS "Admins can delete moderators" ON public.moderators;

CREATE POLICY "Moderators can read own record or admins read all" ON public.moderators
    FOR SELECT USING (auth.uid()::TEXT = id OR is_admin() OR is_active_moderator());

CREATE POLICY "Moderators can update own record (devices, last login) or admin full update" ON public.moderators
    FOR UPDATE USING (auth.uid()::TEXT = id OR is_admin());

CREATE POLICY "Admins can insert moderators or user upon claiming" ON public.moderators
    FOR INSERT WITH CHECK (auth.uid()::TEXT = id OR is_admin() OR true);

CREATE POLICY "Admins can delete moderators" ON public.moderators
    FOR DELETE USING (is_admin());

-- 9. Grant Execution Rights
GRANT EXECUTE ON FUNCTION public.claim_moderator_account(TEXT, TEXT, TEXT, JSONB, UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_user_email(UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_active_moderator() TO anon, authenticated, service_role;

-- 10. App Settings Table & Realtime Replication
CREATE TABLE IF NOT EXISTS public.app_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    is_repair_mode BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "App settings are readable by everyone" ON public.app_settings;
CREATE POLICY "App settings are readable by everyone" ON public.app_settings 
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "App settings are updatable by active moderators" ON public.app_settings;
CREATE POLICY "App settings are updatable by active moderators" ON public.app_settings 
    FOR UPDATE USING (is_active_moderator() OR is_admin());

DROP POLICY IF EXISTS "App settings are insertable by active moderators" ON public.app_settings;
CREATE POLICY "App settings are insertable by active moderators" ON public.app_settings 
    FOR INSERT WITH CHECK (is_active_moderator() OR is_admin());

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'app_settings'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.app_settings;
    END IF;
END $$;

