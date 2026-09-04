-- ==============================================================================
-- MAHLETE SEMAY - DATABASE SECURITY HARDENING MIGRATION
-- ==============================================================================
-- Run this script in your Supabase SQL Editor to patch RLS vulnerabilities
-- and protect your application from privilege escalation and unauthorized access.
-- ==============================================================================

BEGIN;

-- 1. SECURE MODERATORS TABLE
-- ------------------------------------------------------------------------------
-- Prevent arbitrary account creation and privilege escalation
DROP POLICY IF EXISTS "Admins can insert moderators or user upon claiming" ON public.moderators;
DROP POLICY IF EXISTS "Admins can insert moderators" ON public.moderators;
DROP POLICY IF EXISTS "Moderators can update own record (devices, last login) or admin full update" ON public.moderators;
DROP POLICY IF EXISTS "Moderators can update own safe profile or admin full update" ON public.moderators;

-- Only true admins can directly insert rows into public.moderators.
-- (Regular users claiming an invite are inserted securely via the claim_moderator_account SECURITY DEFINER function).
CREATE POLICY "Admins can insert moderators" ON public.moderators
    FOR INSERT WITH CHECK (is_admin());

-- Users can update their own row (e.g. approved devices, last login),
-- but CANNOT change their own role or status. Admins have unrestricted update access.
CREATE POLICY "Moderators can update own safe profile or admin full update" ON public.moderators
    FOR UPDATE 
    USING (auth.uid()::TEXT = id OR is_admin())
    WITH CHECK (
        is_admin() OR (
            auth.uid()::TEXT = id
            AND role = (SELECT m.role FROM public.moderators m WHERE m.id = auth.uid()::TEXT)
            AND status = (SELECT m.status FROM public.moderators m WHERE m.id = auth.uid()::TEXT)
        )
    );

-- 2. SECURE INVITATIONS & INVITE CODES TABLES
-- ------------------------------------------------------------------------------
-- Prevent public scraping/harvesting of secret invite codes & invited emails
DROP POLICY IF EXISTS "Invitations readable for validation or admin" ON public.invitations;
DROP POLICY IF EXISTS "Only admins can view invitations" ON public.invitations;
DROP POLICY IF EXISTS "Invite codes readable for validation" ON public.invite_codes;
DROP POLICY IF EXISTS "Only admins can view invite codes" ON public.invite_codes;

-- Only authenticated administrators can list/read invitations and invite codes.
-- Account claiming is verified server-side inside claim_moderator_account().
CREATE POLICY "Only admins can view invitations" ON public.invitations
    FOR SELECT USING (is_admin());

CREATE POLICY "Only admins can view invite codes" ON public.invite_codes
    FOR SELECT USING (is_admin());

-- 3. HARDEN SENSITIVE STORED PROCEDURES
-- ------------------------------------------------------------------------------
-- Revoke anonymous execution of repair_auth_users_schema
REVOKE EXECUTE ON FUNCTION public.repair_auth_users_schema() FROM anon;
GRANT EXECUTE ON FUNCTION public.repair_auth_users_schema() TO authenticated, service_role;

-- Restrict confirm_user_email so callers cannot confirm arbitrary third-party accounts
CREATE OR REPLACE FUNCTION public.confirm_user_email(user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  -- Caller must be confirming their own account, or be an admin / service_role
  IF auth.uid() = user_id OR is_admin() OR auth.role() = 'service_role' THEN
    UPDATE auth.users
    SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
    WHERE id = user_id;
  ELSE
    RAISE EXCEPTION 'Unauthorized attempt to confirm user email';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.confirm_user_email(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.confirm_user_email(UUID) TO authenticated, service_role;

COMMIT;
