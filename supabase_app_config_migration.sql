-- ==============================================================================
-- Migration: App Version & APK Release Management (app_config + Storage)
-- ==============================================================================

-- 1. Create app_config table
CREATE TABLE IF NOT EXISTS public.app_config (
    id TEXT PRIMARY KEY DEFAULT 'default',
    latest_version TEXT,
    min_required_version TEXT,
    apk_url TEXT,
    release_notes TEXT,
    force_update BOOLEAN DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Enable Row Level Security (RLS)
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies:
-- Allow everyone (anonymous & authenticated) to read app configuration
DROP POLICY IF EXISTS "App config is readable by everyone" ON public.app_config;
CREATE POLICY "App config is readable by everyone" 
ON public.app_config FOR SELECT 
USING (true);

-- Allow active moderators and admins to update or insert app config
DROP POLICY IF EXISTS "App config is modifiable by active moderators" ON public.app_config;
CREATE POLICY "App config is modifiable by active moderators" 
ON public.app_config FOR ALL 
USING (
    EXISTS (
        SELECT 1 FROM public.moderators 
        WHERE id = auth.uid()::text AND is_active = true
    ) OR auth.role() = 'service_role'
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.moderators 
        WHERE id = auth.uid()::text AND is_active = true
    ) OR auth.role() = 'service_role'
);

-- 4. Insert Default Configuration Row
INSERT INTO public.app_config (
    id, 
    latest_version, 
    min_required_version, 
    apk_url, 
    release_notes, 
    force_update
) VALUES (
    'default', 
    '1.0.0', 
    '1.0.0', 
    NULL, 
    'Initial production release with lyrics, audio player, and vocal training.', 
    false
) ON CONFLICT (id) DO NOTHING;

-- 5. Realtime Replication for Instant App Notifications
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'app_config'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.app_config;
    END IF;
END $$;

-- 6. Storage Bucket for APK Releases (app-releases)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'app-releases', 
    'app-releases', 
    true, 
    157286400, -- 150MB max file size
    ARRAY['application/vnd.android.package-archive', 'application/octet-stream', 'application/x-zip-compressed']
)
ON CONFLICT (id) DO UPDATE SET 
    public = true,
    file_size_limit = 157286400,
    allowed_mime_types = ARRAY['application/vnd.android.package-archive', 'application/octet-stream', 'application/x-zip-compressed'];

-- Storage RLS Policies: Public read, Moderator write
DROP POLICY IF EXISTS "Public can view APK releases" ON storage.objects;
CREATE POLICY "Public can view APK releases" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'app-releases');

DROP POLICY IF EXISTS "Active moderators can upload APK releases" ON storage.objects;
CREATE POLICY "Active moderators can upload APK releases" 
ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'app-releases' AND (
        EXISTS (
            SELECT 1 FROM public.moderators 
            WHERE id = auth.uid()::text AND is_active = true
        ) OR auth.role() = 'service_role'
    )
);

DROP POLICY IF EXISTS "Active moderators can update APK releases" ON storage.objects;
CREATE POLICY "Active moderators can update APK releases" 
ON storage.objects FOR UPDATE 
USING (
    bucket_id = 'app-releases' AND (
        EXISTS (
            SELECT 1 FROM public.moderators 
            WHERE id = auth.uid()::text AND is_active = true
        ) OR auth.role() = 'service_role'
    )
);

DROP POLICY IF EXISTS "Active moderators can delete APK releases" ON storage.objects;
CREATE POLICY "Active moderators can delete APK releases" 
ON storage.objects FOR DELETE 
USING (
    bucket_id = 'app-releases' AND (
        EXISTS (
            SELECT 1 FROM public.moderators 
            WHERE id = auth.uid()::text AND is_active = true
        ) OR auth.role() = 'service_role'
    )
);
