-- ==============================================================================
-- Mahlete Semay - Invitation Claim & Auth Login Fix
-- Run this in the Supabase SQL Editor (once) to fix:
--   1. Moderators getting "Invitation code was not found" on signup
--   2. Intermittent login error: Database error querying schema
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Repair existing auth.users rows that break GoTrue login
--    GoTrue throws "unexpected_failure / Database error querying schema"
--    when token varchar columns are NULL.
-- ------------------------------------------------------------------------------
UPDATE auth.users
SET confirmation_token = COALESCE(confirmation_token, ''),
    recovery_token = COALESCE(recovery_token, ''),
    email_change_token_new = COALESCE(email_change_token_new, ''),
    email_change = COALESCE(email_change, ''),
    email_change_token_current = COALESCE(email_change_token_current, ''),
    reauthentication_token = COALESCE(reauthentication_token, ''),
    phone_change = COALESCE(phone_change, ''),
    phone_change_token = COALESCE(phone_change_token, '')
WHERE confirmation_token IS NULL
   OR recovery_token IS NULL
   OR email_change_token_new IS NULL
   OR email_change IS NULL
   OR email_change_token_current IS NULL
   OR reauthentication_token IS NULL
   OR phone_change IS NULL
   OR phone_change_token IS NULL;

-- Keep extra GoTrue columns valid when they exist
DO $$
BEGIN
    UPDATE auth.users
    SET email_change_confirm_status = COALESCE(email_change_confirm_status, 0)
    WHERE email_change_confirm_status IS NULL;
EXCEPTION WHEN undefined_column THEN
    NULL;
END $$;

-- ------------------------------------------------------------------------------
-- 2. Prevent NULL tokens on every future insert/update
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_auth_user_token_defaults()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth
AS $$
BEGIN
    NEW.confirmation_token := COALESCE(NEW.confirmation_token, '');
    NEW.recovery_token := COALESCE(NEW.recovery_token, '');
    NEW.email_change_token_new := COALESCE(NEW.email_change_token_new, '');
    NEW.email_change := COALESCE(NEW.email_change, '');
    NEW.email_change_token_current := COALESCE(NEW.email_change_token_current, '');
    NEW.reauthentication_token := COALESCE(NEW.reauthentication_token, '');
    NEW.phone_change := COALESCE(NEW.phone_change, '');
    NEW.phone_change_token := COALESCE(NEW.phone_change_token, '');
    RETURN NEW;
END;
$$;

DO $$
BEGIN
    DROP TRIGGER IF EXISTS trg_enforce_auth_user_token_defaults ON auth.users;
    CREATE TRIGGER trg_enforce_auth_user_token_defaults
        BEFORE INSERT OR UPDATE ON auth.users
        FOR EACH ROW
        EXECUTE FUNCTION public.enforce_auth_user_token_defaults();
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not attach auth.users token trigger: %', SQLERRM;
END $$;

-- ------------------------------------------------------------------------------
-- 3. Secure single-code lookup for anonymous claimers
--    Invitations stay hidden from public table SELECT (admin-only RLS).
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.lookup_invitation_for_claim(
    p_code TEXT,
    p_email TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invitation RECORD;
    v_clean_code TEXT;
    v_clean_email TEXT;
BEGIN
    v_clean_code := UPPER(REPLACE(REPLACE(TRIM(COALESCE(p_code, '')), '-', ''), ' ', ''));
    v_clean_email := LOWER(TRIM(COALESCE(p_email, '')));

    IF v_clean_code = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invitation code is required.');
    END IF;

    SELECT * INTO v_invitation
    FROM public.invitations
    WHERE UPPER(REPLACE(REPLACE(TRIM(code), '-', ''), ' ', '')) = v_clean_code
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid invitation code.');
    END IF;

    IF v_invitation.status = 'revoked' THEN
        RETURN jsonb_build_object('success', false, 'error', 'This invitation was revoked by an administrator.');
    END IF;

    IF v_clean_email <> '' AND LOWER(TRIM(v_invitation.email)) <> v_clean_email THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'This invitation code belongs to a different email address.',
            'email', v_invitation.email
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'id', v_invitation.id,
        'code', v_invitation.code,
        'email', v_invitation.email,
        'first_name', v_invitation.first_name,
        'last_name', v_invitation.last_name,
        'role', COALESCE(v_invitation.role, 'moderator'),
        'status', v_invitation.status
    );
END;
$$;

CREATE INDEX IF NOT EXISTS idx_invitations_code_normalized
    ON public.invitations (UPPER(REPLACE(REPLACE(TRIM(code), '-', ''), ' ', '')));

-- ------------------------------------------------------------------------------
-- 4. Stronger claim function: valid invite match + GoTrue-safe user/identity
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.repair_auth_users_schema()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_updated_count INT;
BEGIN
    UPDATE auth.users
    SET confirmation_token = COALESCE(confirmation_token, ''),
        recovery_token = COALESCE(recovery_token, ''),
        email_change_token_new = COALESCE(email_change_token_new, ''),
        email_change = COALESCE(email_change, ''),
        email_change_token_current = COALESCE(email_change_token_current, ''),
        reauthentication_token = COALESCE(reauthentication_token, ''),
        phone_change = COALESCE(phone_change, ''),
        phone_change_token = COALESCE(phone_change_token, '')
    WHERE confirmation_token IS NULL
       OR recovery_token IS NULL
       OR email_change_token_new IS NULL
       OR email_change IS NULL
       OR email_change_token_current IS NULL
       OR reauthentication_token IS NULL
       OR phone_change IS NULL
       OR phone_change_token IS NULL;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RETURN jsonb_build_object('success', true, 'repaired_users', v_updated_count);
END;
$$;

DROP FUNCTION IF EXISTS public.claim_moderator_account(UUID, TEXT, TEXT, JSONB);
DROP FUNCTION IF EXISTS public.claim_moderator_account(TEXT, TEXT, TEXT, JSONB, UUID);
DROP FUNCTION IF EXISTS public.claim_moderator_account(TEXT, TEXT, TEXT, JSONB);
DROP FUNCTION IF EXISTS public.claim_moderator_account;

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

    SELECT * INTO v_invitation
    FROM public.invitations
    WHERE LOWER(TRIM(email)) = v_clean_email
      AND UPPER(REPLACE(REPLACE(TRIM(code), '-', ''), ' ', '')) = v_clean_code
    LIMIT 1;

    IF NOT FOUND THEN
        IF EXISTS (
            SELECT 1 FROM public.invitations
            WHERE UPPER(REPLACE(REPLACE(TRIM(code), '-', ''), ' ', '')) = v_clean_code
        ) THEN
            RETURN jsonb_build_object('success', false, 'error', 'This invitation code belongs to a different email address.');
        ELSE
            RETURN jsonb_build_object('success', false, 'error', 'Invalid invitation code.');
        END IF;
    END IF;

    IF v_invitation.status = 'revoked' THEN
        RETURN jsonb_build_object('success', false, 'error', 'This invitation was revoked by an administrator.');
    END IF;

    v_role := COALESCE(v_invitation.role, 'moderator');

    IF p_password IS NOT NULL AND LENGTH(TRIM(p_password)) >= 6 THEN
        v_encrypted_pw := crypt(TRIM(p_password), gen_salt('bf', 10));
    END IF;

    SELECT id INTO v_existing_auth_id
    FROM auth.users
    WHERE LOWER(TRIM(email)) = v_clean_email
    LIMIT 1;

    IF v_existing_auth_id IS NOT NULL THEN
        v_user_id := v_existing_auth_id;
        UPDATE auth.users
        SET encrypted_password = COALESCE(v_encrypted_pw, encrypted_password),
            email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
            confirmation_token = COALESCE(confirmation_token, ''),
            recovery_token = COALESCE(recovery_token, ''),
            email_change_token_new = COALESCE(email_change_token_new, ''),
            email_change = COALESCE(email_change, ''),
            email_change_token_current = COALESCE(email_change_token_current, ''),
            reauthentication_token = COALESCE(reauthentication_token, ''),
            phone_change = COALESCE(phone_change, ''),
            phone_change_token = COALESCE(phone_change_token, ''),
            updated_at = NOW(),
            raw_app_meta_data = '{"provider": "email", "providers": ["email"]}'::jsonb
        WHERE id = v_user_id;
    ELSE
        v_user_id := COALESCE(p_user_id, gen_random_uuid());
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            confirmation_token,
            recovery_token,
            email_change_token_new,
            email_change,
            email_change_token_current,
            reauthentication_token,
            phone_change,
            phone_change_token,
            raw_app_meta_data,
            raw_user_meta_data,
            is_super_admin,
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
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '{"provider": "email", "providers": ["email"]}'::jsonb,
            jsonb_build_object('firstName', v_invitation.first_name, 'lastName', v_invitation.last_name, 'sub', v_user_id::text),
            FALSE,
            NOW(),
            NOW()
        );
    END IF;

    -- Always re-assert GoTrue-safe token values after insert/update
    UPDATE auth.users
    SET confirmation_token = COALESCE(confirmation_token, ''),
        recovery_token = COALESCE(recovery_token, ''),
        email_change_token_new = COALESCE(email_change_token_new, ''),
        email_change = COALESCE(email_change, ''),
        email_change_token_current = COALESCE(email_change_token_current, ''),
        reauthentication_token = COALESCE(reauthentication_token, ''),
        phone_change = COALESCE(phone_change, ''),
        phone_change_token = COALESCE(phone_change_token, ''),
        email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
        updated_at = NOW()
    WHERE id = v_user_id;

    BEGIN
        UPDATE auth.users
        SET email_change_confirm_status = COALESCE(email_change_confirm_status, 0)
        WHERE id = v_user_id;
    EXCEPTION WHEN undefined_column OR OTHERS THEN
        NULL;
    END;

    -- Ensure an email identity exists (required by current GoTrue)
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM auth.identities
            WHERE user_id = v_user_id AND provider = 'email'
        ) THEN
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
                v_user_id,
                v_user_id,
                jsonb_build_object('sub', v_user_id::TEXT, 'email', v_clean_email, 'email_verified', true),
                'email',
                v_user_id::TEXT,
                NOW(),
                NOW(),
                NOW()
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        BEGIN
            INSERT INTO auth.identities (
                user_id,
                identity_data,
                provider,
                provider_id,
                last_sign_in_at,
                created_at,
                updated_at
            ) VALUES (
                v_user_id,
                jsonb_build_object('sub', v_user_id::TEXT, 'email', v_clean_email, 'email_verified', true),
                'email',
                v_user_id::TEXT,
                NOW(),
                NOW(),
                NOW()
            );
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END;

    IF p_device_info IS NOT NULL AND p_device_info::TEXT != 'null' AND p_device_info::TEXT != '{}' THEN
        v_devices := jsonb_build_array(p_device_info);
    ELSE
        v_devices := '[]'::jsonb;
    END IF;

    v_username := LOWER(REPLACE(COALESCE(v_invitation.first_name, 'user'), ' ', '')) || '.' || LOWER(REPLACE(COALESCE(v_invitation.last_name, 'mod'), ' ', ''));

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

    UPDATE public.invitations
    SET status = 'claimed',
        claimed_by = v_user_id::TEXT,
        claimed_at = NOW()
    WHERE id = v_invitation.id;

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

-- ------------------------------------------------------------------------------
-- 5. Grants: anonymous users must be able to look up/claim an invite
--    and self-heal auth token columns before they have a session.
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.lookup_invitation_for_claim(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_moderator_account(TEXT, TEXT, TEXT, JSONB, UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.repair_auth_users_schema() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_user_email(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_active_moderator() TO anon, authenticated, service_role;

SELECT public.repair_auth_users_schema();

COMMIT;
