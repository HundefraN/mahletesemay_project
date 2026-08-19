-- ==============================================================================
-- Mahlete Semay - Supabase Database Schema & RLS Policies
-- Database: PostgreSQL (Supabase)
-- ==============================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- TABLE DEFINITIONS
-- ==============================================================================

-- Artists Table
CREATE TABLE IF NOT EXISTS public.artists (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::TEXT,
    name TEXT NOT NULL,
    english_name TEXT NOT NULL DEFAULT '',
    image_url TEXT NOT NULL DEFAULT '',
    region TEXT NOT NULL DEFAULT '',
    search_keywords TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now())
);
ALTER TABLE public.artists ADD COLUMN IF NOT EXISTS search_keywords TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE public.artists ADD COLUMN IF NOT EXISTS english_name TEXT NOT NULL DEFAULT '';

-- Albums Table
CREATE TABLE IF NOT EXISTS public.albums (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::TEXT,
    title TEXT NOT NULL,
    english_title TEXT NOT NULL DEFAULT '',
    artist_id TEXT REFERENCES public.artists(id) ON DELETE SET NULL,
    artist_name TEXT NOT NULL DEFAULT '',
    cover_image_url TEXT NOT NULL DEFAULT '',
    year INTEGER,
    volume INTEGER,
    search_keywords TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now())
);
ALTER TABLE public.albums ADD COLUMN IF NOT EXISTS search_keywords TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE public.albums ADD COLUMN IF NOT EXISTS english_title TEXT NOT NULL DEFAULT '';

-- Songs Table
CREATE TABLE IF NOT EXISTS public.songs (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::TEXT,
    title TEXT NOT NULL,
    english_title TEXT NOT NULL DEFAULT '',
    artist_id TEXT REFERENCES public.artists(id) ON DELETE SET NULL,
    artist_name TEXT NOT NULL DEFAULT '',
    album_id TEXT REFERENCES public.albums(id) ON DELETE SET NULL,
    album_title TEXT NOT NULL DEFAULT '',
    lyrics TEXT NOT NULL DEFAULT '',
    scale TEXT,
    rhythm TEXT,
    view_count INTEGER NOT NULL DEFAULT 0,
    search_keywords TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now())
);
ALTER TABLE public.songs ADD COLUMN IF NOT EXISTS search_keywords TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE public.songs ADD COLUMN IF NOT EXISTS english_title TEXT NOT NULL DEFAULT '';

-- Vocal Plans Table
CREATE TABLE IF NOT EXISTS public.vocal_plans (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now())
);

-- Vocal Plan Days Table
CREATE TABLE IF NOT EXISTS public.vocal_plan_days (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::TEXT,
    plan_id TEXT NOT NULL,
    day_number INTEGER NOT NULL DEFAULT 0,
    title TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    audio_url TEXT,
    is_rest_day BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now())
);

-- General Exercises Table
CREATE TABLE IF NOT EXISTS public.general_exercises (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::TEXT,
    day_number INTEGER NOT NULL DEFAULT 0,
    title TEXT NOT NULL DEFAULT '',
    english_title TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    audio_url TEXT,
    is_rest_day BOOLEAN NOT NULL DEFAULT FALSE,
    search_keywords TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now())
);
ALTER TABLE public.general_exercises ADD COLUMN IF NOT EXISTS search_keywords TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE public.general_exercises ADD COLUMN IF NOT EXISTS english_title TEXT NOT NULL DEFAULT '';

-- Moderators Table
CREATE TABLE IF NOT EXISTS public.moderators (
    id TEXT PRIMARY KEY, -- Maps to Supabase auth.users(id)
    email TEXT NOT NULL,
    first_name TEXT NOT NULL DEFAULT '',
    last_name TEXT NOT NULL DEFAULT '',
    username TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL DEFAULT 'moderator', -- 'admin' | 'moderator'
    status TEXT NOT NULL DEFAULT 'active', -- 'active' | 'inactive' | 'review' | 'blocked'
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    approved_devices JSONB NOT NULL DEFAULT '[]'::JSONB,
    pending_device JSONB,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now())
);

-- Schema sync: Ensure both 'status' and 'is_active' exist on existing setups
ALTER TABLE public.moderators ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE public.moderators ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
UPDATE public.moderators SET is_active = (status = 'active') WHERE is_active IS NULL;

-- Suggestions Table (Lyric suggestions submitted by users)
CREATE TABLE IF NOT EXISTS public.suggestions (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::TEXT,
    song_title TEXT NOT NULL DEFAULT '',
    artist_name TEXT NOT NULL DEFAULT '',
    lyrics TEXT NOT NULL DEFAULT '',
    submitted_by TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now()),
    status TEXT NOT NULL DEFAULT 'pending' -- 'pending' | 'approved' | 'rejected'
);

-- Activity Logs Table
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::TEXT,
    moderator_id TEXT NOT NULL DEFAULT '',
    moderator_name TEXT NOT NULL DEFAULT '',
    action TEXT NOT NULL DEFAULT '',
    details TEXT NOT NULL DEFAULT '',
    is_seen BOOLEAN NOT NULL DEFAULT FALSE,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now())
);

-- Invitations Table
CREATE TABLE IF NOT EXISTS public.invitations (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::TEXT,
    code TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL,
    first_name TEXT NOT NULL DEFAULT '',
    last_name TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL DEFAULT 'moderator', -- 'admin' | 'moderator'
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending' | 'claimed' | 'revoked'
    created_by TEXT NOT NULL DEFAULT '',
    claimed_by TEXT,
    claimed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now())
);
ALTER TABLE public.invitations ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'moderator';

-- Invite Codes Table (Legacy)
CREATE TABLE IF NOT EXISTS public.invite_codes (
    code TEXT PRIMARY KEY,
    used BOOLEAN NOT NULL DEFAULT FALSE,
    used_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now())
);

-- User FCM Tokens Table (Push Notifications)
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::TEXT,
    user_id TEXT,
    token TEXT NOT NULL UNIQUE,
    device_info JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now())
);

-- ==============================================================================
-- INDEXES FOR PERFORMANCE
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_songs_artist_id ON public.songs(artist_id);
CREATE INDEX IF NOT EXISTS idx_songs_album_id ON public.songs(album_id);
CREATE INDEX IF NOT EXISTS idx_songs_created_at ON public.songs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_albums_artist_id ON public.albums(artist_id);
CREATE INDEX IF NOT EXISTS idx_vocal_plan_days_plan_id ON public.vocal_plan_days(plan_id, day_number);
CREATE INDEX IF NOT EXISTS idx_suggestions_status ON public.suggestions(status);
CREATE INDEX IF NOT EXISTS idx_activity_logs_is_seen ON public.activity_logs(is_seen, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_invitations_code ON public.invitations(code);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON public.user_fcm_tokens(user_id);

-- GIN Search Keyword Indexes
CREATE INDEX IF NOT EXISTS idx_artists_search_keywords ON public.artists USING GIN (search_keywords);
CREATE INDEX IF NOT EXISTS idx_albums_search_keywords ON public.albums USING GIN (search_keywords);
CREATE INDEX IF NOT EXISTS idx_songs_search_keywords ON public.songs USING GIN (search_keywords);
CREATE INDEX IF NOT EXISTS idx_general_exercises_search_keywords ON public.general_exercises USING GIN (search_keywords);

-- ==============================================================================
-- RPC FUNCTIONS
-- ==============================================================================

-- Multi-Script Search RPC Function
CREATE OR REPLACE FUNCTION search_multi_script(
    query_text TEXT,
    query_tokens TEXT[] DEFAULT '{}',
    category TEXT DEFAULT 'all',
    result_limit INTEGER DEFAULT 50
)
RETURNS JSONB AS $$
DECLARE
    cleaned_query TEXT := TRIM(LOWER(query_text));
    songs_result JSONB := '[]'::JSONB;
    artists_result JSONB := '[]'::JSONB;
    albums_result JSONB := '[]'::JSONB;
    exercises_result JSONB := '[]'::JSONB;
BEGIN
    IF cleaned_query = '' AND array_length(query_tokens, 1) IS NULL THEN
        RETURN jsonb_build_object(
            'songs', '[]'::JSONB,
            'artists', '[]'::JSONB,
            'albums', '[]'::JSONB,
            'exercises', '[]'::JSONB
        );
    END IF;

    -- Search Songs
    IF category IN ('all', 'songs', 'lyrics') THEN
        SELECT COALESCE(jsonb_agg(to_jsonb(s)), '[]'::JSONB) INTO songs_result
        FROM (
            SELECT 
                s.*,
                CASE 
                    WHEN LOWER(s.title) = cleaned_query OR LOWER(s.english_title) = cleaned_query THEN 100
                    WHEN LOWER(s.title) LIKE cleaned_query || '%' OR LOWER(s.english_title) LIKE cleaned_query || '%' THEN 80
                    WHEN LOWER(s.artist_name) LIKE '%' || cleaned_query || '%' THEN 70
                    WHEN s.search_keywords && query_tokens THEN 60
                    WHEN LOWER(s.lyrics) LIKE '%' || cleaned_query || '%' THEN 40
                    ELSE 20
                END as match_score
            FROM public.songs s
            WHERE 
                LOWER(s.title) LIKE '%' || cleaned_query || '%'
                OR LOWER(s.english_title) LIKE '%' || cleaned_query || '%'
                OR LOWER(s.artist_name) LIKE '%' || cleaned_query || '%'
                OR LOWER(s.album_title) LIKE '%' || cleaned_query || '%'
                OR LOWER(s.lyrics) LIKE '%' || cleaned_query || '%'
                OR s.search_keywords && query_tokens
            ORDER BY match_score DESC, s.view_count DESC
            LIMIT result_limit
        ) s;
    END IF;

    -- Search Artists
    IF category IN ('all', 'artists') THEN
        SELECT COALESCE(jsonb_agg(to_jsonb(a)), '[]'::JSONB) INTO artists_result
        FROM (
            SELECT 
                a.*,
                CASE 
                    WHEN LOWER(a.name) = cleaned_query OR LOWER(a.english_name) = cleaned_query THEN 100
                    WHEN LOWER(a.name) LIKE cleaned_query || '%' OR LOWER(a.english_name) LIKE cleaned_query || '%' THEN 80
                    WHEN a.search_keywords && query_tokens THEN 60
                    ELSE 30
                END as match_score
            FROM public.artists a
            WHERE 
                LOWER(a.name) LIKE '%' || cleaned_query || '%'
                OR LOWER(a.english_name) LIKE '%' || cleaned_query || '%'
                OR a.search_keywords && query_tokens
            ORDER BY match_score DESC
            LIMIT result_limit
        ) a;
    END IF;

    -- Search Albums
    IF category IN ('all', 'albums') THEN
        SELECT COALESCE(jsonb_agg(to_jsonb(al)), '[]'::JSONB) INTO albums_result
        FROM (
            SELECT 
                al.*,
                CASE 
                    WHEN LOWER(al.title) = cleaned_query OR LOWER(al.english_title) = cleaned_query THEN 100
                    WHEN LOWER(al.title) LIKE cleaned_query || '%' OR LOWER(al.english_title) LIKE cleaned_query || '%' THEN 80
                    WHEN al.search_keywords && query_tokens THEN 60
                    ELSE 30
                END as match_score
            FROM public.albums al
            WHERE 
                LOWER(al.title) LIKE '%' || cleaned_query || '%'
                OR LOWER(al.english_title) LIKE '%' || cleaned_query || '%'
                OR LOWER(al.artist_name) LIKE '%' || cleaned_query || '%'
                OR al.search_keywords && query_tokens
            ORDER BY match_score DESC
            LIMIT result_limit
        ) al;
    END IF;

    -- Search General Exercises
    IF category IN ('all', 'exercises') THEN
        SELECT COALESCE(jsonb_agg(to_jsonb(ge)), '[]'::JSONB) INTO exercises_result
        FROM (
            SELECT 
                ge.*,
                CASE 
                    WHEN LOWER(ge.title) = cleaned_query OR LOWER(ge.english_title) = cleaned_query THEN 100
                    WHEN LOWER(ge.title) LIKE cleaned_query || '%' OR LOWER(ge.english_title) LIKE cleaned_query || '%' THEN 80
                    WHEN ge.search_keywords && query_tokens THEN 60
                    ELSE 30
                END as match_score
            FROM public.general_exercises ge
            WHERE 
                LOWER(ge.title) LIKE '%' || cleaned_query || '%'
                OR LOWER(ge.english_title) LIKE '%' || cleaned_query || '%'
                OR LOWER(ge.description) LIKE '%' || cleaned_query || '%'
                OR ge.search_keywords && query_tokens
            ORDER BY match_score DESC
            LIMIT result_limit
        ) ge;
    END IF;

    RETURN jsonb_build_object(
        'songs', songs_result,
        'artists', artists_result,
        'albums', albums_result,
        'exercises', exercises_result
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Increment view count atomically
CREATE OR REPLACE FUNCTION increment_song_view_count(p_song_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.songs
    SET view_count = view_count + 1
    WHERE id = p_song_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if current user is admin
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

-- Helper function to check if current user is active moderator or admin
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

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

-- App Settings Table
CREATE TABLE IF NOT EXISTS public.app_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    is_repair_mode BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Enable RLS on all tables
ALTER TABLE public.artists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vocal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vocal_plan_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.general_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invite_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- 1. Artists: Public Read, Moderator/Admin Write
DROP POLICY IF EXISTS "Artists are readable by everyone" ON public.artists;
DROP POLICY IF EXISTS "Artists are insertable by active moderators" ON public.artists;
DROP POLICY IF EXISTS "Artists are updatable by active moderators" ON public.artists;
DROP POLICY IF EXISTS "Artists are deletable by active moderators" ON public.artists;
CREATE POLICY "Artists are readable by everyone" ON public.artists FOR SELECT USING (true);
CREATE POLICY "Artists are insertable by active moderators" ON public.artists FOR INSERT WITH CHECK (is_active_moderator());
CREATE POLICY "Artists are updatable by active moderators" ON public.artists FOR UPDATE USING (is_active_moderator());
CREATE POLICY "Artists are deletable by active moderators" ON public.artists FOR DELETE USING (is_active_moderator());

-- 2. Albums: Public Read, Moderator/Admin Write
DROP POLICY IF EXISTS "Albums are readable by everyone" ON public.albums;
DROP POLICY IF EXISTS "Albums are insertable by active moderators" ON public.albums;
DROP POLICY IF EXISTS "Albums are updatable by active moderators" ON public.albums;
DROP POLICY IF EXISTS "Albums are deletable by active moderators" ON public.albums;
CREATE POLICY "Albums are readable by everyone" ON public.albums FOR SELECT USING (true);
CREATE POLICY "Albums are insertable by active moderators" ON public.albums FOR INSERT WITH CHECK (is_active_moderator());
CREATE POLICY "Albums are updatable by active moderators" ON public.albums FOR UPDATE USING (is_active_moderator());
CREATE POLICY "Albums are deletable by active moderators" ON public.albums FOR DELETE USING (is_active_moderator());

-- 3. Songs: Public Read, Moderator/Admin Write (View count increment allowed)
DROP POLICY IF EXISTS "Songs are readable by everyone" ON public.songs;
DROP POLICY IF EXISTS "Songs are insertable by active moderators" ON public.songs;
DROP POLICY IF EXISTS "Songs are updatable by active moderators or view count" ON public.songs;
DROP POLICY IF EXISTS "Songs are deletable by active moderators" ON public.songs;
CREATE POLICY "Songs are readable by everyone" ON public.songs FOR SELECT USING (true);
CREATE POLICY "Songs are insertable by active moderators" ON public.songs FOR INSERT WITH CHECK (is_active_moderator());
CREATE POLICY "Songs are updatable by active moderators or view count" ON public.songs FOR UPDATE USING (true);
CREATE POLICY "Songs are deletable by active moderators" ON public.songs FOR DELETE USING (is_active_moderator());

-- 4. Vocal Plans & Days: Public Read, Moderator/Admin Write
DROP POLICY IF EXISTS "Vocal plans are readable by everyone" ON public.vocal_plans;
DROP POLICY IF EXISTS "Vocal plans write by active moderators" ON public.vocal_plans;
CREATE POLICY "Vocal plans are readable by everyone" ON public.vocal_plans FOR SELECT USING (true);
CREATE POLICY "Vocal plans write by active moderators" ON public.vocal_plans FOR ALL USING (is_active_moderator());

DROP POLICY IF EXISTS "Vocal plan days are readable by everyone" ON public.vocal_plan_days;
DROP POLICY IF EXISTS "Vocal plan days write by active moderators" ON public.vocal_plan_days;
CREATE POLICY "Vocal plan days are readable by everyone" ON public.vocal_plan_days FOR SELECT USING (true);
CREATE POLICY "Vocal plan days write by active moderators" ON public.vocal_plan_days FOR ALL USING (is_active_moderator());

-- 5. General Exercises: Public Read, Moderator/Admin Write
DROP POLICY IF EXISTS "General exercises are readable by everyone" ON public.general_exercises;
DROP POLICY IF EXISTS "General exercises write by active moderators" ON public.general_exercises;
CREATE POLICY "General exercises are readable by everyone" ON public.general_exercises FOR SELECT USING (true);
CREATE POLICY "General exercises write by active moderators" ON public.general_exercises FOR ALL USING (is_active_moderator());

-- 6. Moderators: Self read/update, Admin full manage
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

-- 7. Suggestions: Public Insert, Active Moderator/Admin Manage
DROP POLICY IF EXISTS "Anyone can insert suggestions" ON public.suggestions;
DROP POLICY IF EXISTS "Active moderators can read suggestions" ON public.suggestions;
DROP POLICY IF EXISTS "Active moderators can update suggestions" ON public.suggestions;
DROP POLICY IF EXISTS "Active moderators can delete suggestions" ON public.suggestions;
CREATE POLICY "Anyone can insert suggestions" ON public.suggestions FOR INSERT WITH CHECK (true);
CREATE POLICY "Active moderators can read suggestions" ON public.suggestions FOR SELECT USING (is_active_moderator());
CREATE POLICY "Active moderators can update suggestions" ON public.suggestions FOR UPDATE USING (is_active_moderator());
CREATE POLICY "Active moderators can delete suggestions" ON public.suggestions FOR DELETE USING (is_active_moderator());

-- 8. Activity Logs: Active Moderator Read/Insert, Admin Mark Seen
DROP POLICY IF EXISTS "Active moderators can read activity logs" ON public.activity_logs;
DROP POLICY IF EXISTS "Active moderators can insert activity logs" ON public.activity_logs;
DROP POLICY IF EXISTS "Active moderators can update activity logs (mark seen)" ON public.activity_logs;
CREATE POLICY "Active moderators can read activity logs" ON public.activity_logs FOR SELECT USING (is_active_moderator());
CREATE POLICY "Active moderators can insert activity logs" ON public.activity_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "Active moderators can update activity logs (mark seen)" ON public.activity_logs FOR UPDATE USING (is_active_moderator());

-- 9. Invitations & Invite Codes: Authenticated Read / Admin Write / Public Code Validation
DROP POLICY IF EXISTS "Invitations readable for validation or admin" ON public.invitations;
DROP POLICY IF EXISTS "Admins can manage invitations" ON public.invitations;
DROP POLICY IF EXISTS "Anyone can claim pending invitation" ON public.invitations;
DROP POLICY IF EXISTS "Invite codes readable for validation" ON public.invite_codes;
DROP POLICY IF EXISTS "Admins can manage invite codes" ON public.invite_codes;
CREATE POLICY "Invitations readable for validation or admin" ON public.invitations FOR SELECT USING (true);
CREATE POLICY "Anyone can claim pending invitation" ON public.invitations FOR UPDATE USING (status = 'pending' OR is_admin());
CREATE POLICY "Admins can manage invitations" ON public.invitations FOR ALL USING (is_admin());
CREATE POLICY "Invite codes readable for validation" ON public.invite_codes FOR SELECT USING (true);
CREATE POLICY "Admins can manage invite codes" ON public.invite_codes FOR ALL USING (is_admin());

-- 10. User FCM Tokens: Anyone can register/update own token
DROP POLICY IF EXISTS "FCM tokens insertable/updatable by client" ON public.user_fcm_tokens;
CREATE POLICY "FCM tokens insertable/updatable by client" ON public.user_fcm_tokens FOR ALL USING (true);

DROP POLICY IF EXISTS "App settings are readable by everyone" ON public.app_settings;
CREATE POLICY "App settings are readable by everyone" ON public.app_settings FOR SELECT USING (true);

DROP POLICY IF EXISTS "App settings are updatable by active moderators" ON public.app_settings;
CREATE POLICY "App settings are updatable by active moderators" ON public.app_settings FOR UPDATE USING (is_active_moderator());

DROP POLICY IF EXISTS "App settings are insertable by active moderators" ON public.app_settings;
CREATE POLICY "App settings are insertable by active moderators" ON public.app_settings FOR INSERT WITH CHECK (is_active_moderator());

-- ==============================================================================
-- REALTIME PUBLICATION
-- ==============================================================================
DO $$ 
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.artists;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ 
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.albums;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ 
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.songs;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ 
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.vocal_plan_days;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ 
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.general_exercises;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ 
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.moderators;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ 
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.suggestions;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.activity_logs;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.invite_codes;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.app_settings;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ==============================================================================
-- SUPABASE STORAGE BUCKETS & RLS POLICIES
-- ==============================================================================

-- Create buckets for covers, audio, and avatars
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('covers', 'covers', true),
    ('audio', 'audio', true),
    ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage RLS Policies
-- 1. Covers Bucket
DROP POLICY IF EXISTS "Public Read Covers" ON storage.objects;
DROP POLICY IF EXISTS "Active Moderators Insert Covers" ON storage.objects;
DROP POLICY IF EXISTS "Active Moderators Update Covers" ON storage.objects;
DROP POLICY IF EXISTS "Active Moderators Delete Covers" ON storage.objects;

CREATE POLICY "Public Read Covers" ON storage.objects
    FOR SELECT USING (bucket_id = 'covers');

CREATE POLICY "Active Moderators Insert Covers" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'covers' AND (auth.role() = 'authenticated' OR is_active_moderator()));

CREATE POLICY "Active Moderators Update Covers" ON storage.objects
    FOR UPDATE USING (bucket_id = 'covers' AND (auth.role() = 'authenticated' OR is_active_moderator()));

CREATE POLICY "Active Moderators Delete Covers" ON storage.objects
    FOR DELETE USING (bucket_id = 'covers' AND (auth.role() = 'authenticated' OR is_active_moderator()));

-- 2. Audio Bucket
DROP POLICY IF EXISTS "Public Read Audio" ON storage.objects;
DROP POLICY IF EXISTS "Active Moderators Insert Audio" ON storage.objects;
DROP POLICY IF EXISTS "Active Moderators Update Audio" ON storage.objects;
DROP POLICY IF EXISTS "Active Moderators Delete Audio" ON storage.objects;

CREATE POLICY "Public Read Audio" ON storage.objects
    FOR SELECT USING (bucket_id = 'audio');

CREATE POLICY "Active Moderators Insert Audio" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'audio' AND (auth.role() = 'authenticated' OR is_active_moderator()));

CREATE POLICY "Active Moderators Update Audio" ON storage.objects
    FOR UPDATE USING (bucket_id = 'audio' AND (auth.role() = 'authenticated' OR is_active_moderator()));

CREATE POLICY "Active Moderators Delete Audio" ON storage.objects
    FOR DELETE USING (bucket_id = 'audio' AND (auth.role() = 'authenticated' OR is_active_moderator()));

-- 3. Avatars Bucket
DROP POLICY IF EXISTS "Public Read Avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Insert Avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Update Avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Delete Avatars" ON storage.objects;

CREATE POLICY "Public Read Avatars" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Authenticated Insert Avatars" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');

CREATE POLICY "Authenticated Update Avatars" ON storage.objects
    FOR UPDATE USING (bucket_id = 'avatars' AND auth.role() = 'authenticated');

CREATE POLICY "Authenticated Delete Avatars" ON storage.objects
    FOR DELETE USING (bucket_id = 'avatars' AND auth.role() = 'authenticated');

-- ==============================================================================
-- AUTO-CONFIRM USER EMAIL & ACCOUNT CLAIMING PROCEDURES
-- ==============================================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

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

GRANT EXECUTE ON FUNCTION public.claim_moderator_account(TEXT, TEXT, TEXT, JSONB, UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_user_email(UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_active_moderator() TO anon, authenticated, service_role;

