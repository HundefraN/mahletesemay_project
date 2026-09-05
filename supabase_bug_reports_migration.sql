-- Bug & crash reports submitted by app users, plus screenshot storage.
-- Run this in the Supabase SQL editor.

CREATE TABLE IF NOT EXISTS public.bug_reports (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::TEXT,
    type TEXT NOT NULL DEFAULT 'bug',
    title TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    screenshot_urls TEXT[] NOT NULL DEFAULT '{}',
    contact_email TEXT,
    app_version TEXT NOT NULL DEFAULT '',
    build_number TEXT NOT NULL DEFAULT '',
    platform TEXT NOT NULL DEFAULT '',
    device_model TEXT NOT NULL DEFAULT '',
    os_version TEXT NOT NULL DEFAULT '',
    locale TEXT NOT NULL DEFAULT '',
    stack_trace TEXT,
    status TEXT NOT NULL DEFAULT 'open',
    admin_notes TEXT NOT NULL DEFAULT '',
    is_seen BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now()),
    CONSTRAINT bug_reports_type_check CHECK (type IN ('bug', 'crash', 'feedback')),
    CONSTRAINT bug_reports_status_check CHECK (status IN ('open', 'in_progress', 'resolved'))
);

CREATE INDEX IF NOT EXISTS idx_bug_reports_status ON public.bug_reports(status);
CREATE INDEX IF NOT EXISTS idx_bug_reports_is_seen ON public.bug_reports(is_seen, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bug_reports_created_at ON public.bug_reports(created_at DESC);

ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can insert bug reports" ON public.bug_reports;
DROP POLICY IF EXISTS "Active moderators can read bug reports" ON public.bug_reports;
DROP POLICY IF EXISTS "Active moderators can update bug reports" ON public.bug_reports;
DROP POLICY IF EXISTS "Active moderators can delete bug reports" ON public.bug_reports;

CREATE POLICY "Anyone can insert bug reports"
    ON public.bug_reports FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Active moderators can read bug reports"
    ON public.bug_reports FOR SELECT
    USING (is_active_moderator());

CREATE POLICY "Active moderators can update bug reports"
    ON public.bug_reports FOR UPDATE
    USING (is_active_moderator());

CREATE POLICY "Active moderators can delete bug reports"
    ON public.bug_reports FOR DELETE
    USING (is_active_moderator());

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'bug_reports'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.bug_reports;
    END IF;
END $$;

INSERT INTO storage.buckets (id, name, public)
VALUES ('bug-reports', 'bug-reports', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public Read Bug Reports" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can upload bug report screenshots" ON storage.objects;
DROP POLICY IF EXISTS "Active moderators can update bug report screenshots" ON storage.objects;
DROP POLICY IF EXISTS "Active moderators can delete bug report screenshots" ON storage.objects;

CREATE POLICY "Public Read Bug Reports"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'bug-reports');

CREATE POLICY "Anyone can upload bug report screenshots"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'bug-reports');

CREATE POLICY "Active moderators can update bug report screenshots"
    ON storage.objects FOR UPDATE
    USING (bucket_id = 'bug-reports' AND is_active_moderator());

CREATE POLICY "Active moderators can delete bug report screenshots"
    ON storage.objects FOR DELETE
    USING (bucket_id = 'bug-reports' AND is_active_moderator());
