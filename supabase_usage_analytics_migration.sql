-- App install + website visit tracking.
-- Run this in the Supabase SQL editor.

CREATE TABLE IF NOT EXISTS public.usage_devices (
    id TEXT PRIMARY KEY,
    channel TEXT NOT NULL CHECK (channel IN ('app', 'web')),
    platform TEXT NOT NULL DEFAULT '',
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now()),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now()),
    visit_count INTEGER NOT NULL DEFAULT 1,
    app_version TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS public.usage_daily_visits (
    device_id TEXT NOT NULL REFERENCES public.usage_devices(id) ON DELETE CASCADE,
    visit_date DATE NOT NULL,
    channel TEXT NOT NULL CHECK (channel IN ('app', 'web')),
    PRIMARY KEY (device_id, visit_date)
);

CREATE INDEX IF NOT EXISTS idx_usage_devices_channel ON public.usage_devices(channel);
CREATE INDEX IF NOT EXISTS idx_usage_devices_first_seen ON public.usage_devices(first_seen_at DESC);
CREATE INDEX IF NOT EXISTS idx_usage_daily_visits_channel_date
    ON public.usage_daily_visits(channel, visit_date);

ALTER TABLE public.usage_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_daily_visits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Active moderators can read usage devices" ON public.usage_devices;
DROP POLICY IF EXISTS "Active moderators can read usage daily visits" ON public.usage_daily_visits;

CREATE POLICY "Active moderators can read usage devices"
    ON public.usage_devices FOR SELECT
    USING (is_active_moderator());

CREATE POLICY "Active moderators can read usage daily visits"
    ON public.usage_daily_visits FOR SELECT
    USING (is_active_moderator());

CREATE OR REPLACE FUNCTION public.record_usage_ping(
    p_device_id TEXT,
    p_channel TEXT,
    p_platform TEXT DEFAULT '',
    p_app_version TEXT DEFAULT ''
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_today DATE := (timezone('utc', now()))::date;
    v_channel TEXT;
    v_platform TEXT;
    v_version TEXT;
BEGIN
    IF p_device_id IS NULL OR p_device_id !~ '^[A-Za-z0-9_-]{8,64}$' THEN
        RAISE EXCEPTION 'invalid device id';
    END IF;

    v_channel := lower(trim(p_channel));
    IF v_channel NOT IN ('app', 'web') THEN
        RAISE EXCEPTION 'invalid channel';
    END IF;

    v_platform := left(coalesce(trim(p_platform), ''), 32);
    v_version := left(coalesce(trim(p_app_version), ''), 32);

    INSERT INTO public.usage_devices (
        id, channel, platform, first_seen_at, last_seen_at, visit_count, app_version
    )
    VALUES (
        p_device_id,
        v_channel,
        v_platform,
        timezone('utc', now()),
        timezone('utc', now()),
        1,
        v_version
    )
    ON CONFLICT (id) DO UPDATE
    SET last_seen_at = timezone('utc', now()),
        platform = CASE
            WHEN EXCLUDED.platform <> '' THEN EXCLUDED.platform
            ELSE usage_devices.platform
        END,
        app_version = CASE
            WHEN EXCLUDED.app_version <> '' THEN EXCLUDED.app_version
            ELSE usage_devices.app_version
        END,
        visit_count = usage_devices.visit_count + CASE
            WHEN usage_devices.last_seen_at::date < v_today THEN 1
            ELSE 0
        END;

    INSERT INTO public.usage_daily_visits (device_id, visit_date, channel)
    VALUES (p_device_id, v_today, v_channel)
    ON CONFLICT (device_id, visit_date) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_usage_stats()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result JSONB;
BEGIN
    IF NOT is_active_moderator() THEN
        RAISE EXCEPTION 'not authorized';
    END IF;

    SELECT jsonb_build_object(
        'app_installs', (
            SELECT COUNT(*) FROM public.usage_devices WHERE channel = 'app'
        ),
        'website_visitors', (
            SELECT COUNT(*) FROM public.usage_devices WHERE channel = 'web'
        ),
        'website_visits', (
            SELECT COUNT(*) FROM public.usage_daily_visits WHERE channel = 'web'
        ),
        'app_opens', (
            SELECT COUNT(*) FROM public.usage_daily_visits WHERE channel = 'app'
        ),
        'installs_today', (
            SELECT COUNT(*)
            FROM public.usage_devices
            WHERE channel = 'app'
              AND first_seen_at >= date_trunc('day', timezone('utc', now()))
        ),
        'visitors_today', (
            SELECT COUNT(*)
            FROM public.usage_daily_visits
            WHERE channel = 'web'
              AND visit_date = (timezone('utc', now()))::date
        ),
        'last_7_days', (
            SELECT COALESCE(jsonb_agg(to_jsonb(d) ORDER BY d.day), '[]'::JSONB)
            FROM (
                SELECT
                    gs::date AS day,
                    (
                        SELECT COUNT(*)
                        FROM public.usage_devices
                        WHERE channel = 'app'
                          AND first_seen_at >= gs
                          AND first_seen_at < gs + INTERVAL '1 day'
                    ) AS app_installs,
                    (
                        SELECT COUNT(*)
                        FROM public.usage_daily_visits
                        WHERE channel = 'web'
                          AND visit_date = gs::date
                    ) AS website_visits
                FROM generate_series(
                    (timezone('utc', now()))::date - 6,
                    (timezone('utc', now()))::date,
                    INTERVAL '1 day'
                ) AS gs
            ) d
        )
    ) INTO result;

    RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.record_usage_ping(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_usage_ping(TEXT, TEXT, TEXT, TEXT)
    TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_usage_stats() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_usage_stats()
    TO authenticated, service_role;
