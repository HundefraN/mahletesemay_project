-- Background / killed-state push + silent catalog sync.
-- Run in the Supabase SQL editor AFTER deploying supabase/functions/send-push.
--
-- Required secret (CLI):
--   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
--
-- The Flutter admin client also invokes send-push after catalog writes.
-- These triggers cover edits made in the dashboard or any other client.
-- A 15-second dedup key prevents double tray alerts when both fire.

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE TABLE IF NOT EXISTS public.push_dedup (
    key TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::TEXT, now())
);

ALTER TABLE public.push_dedup ENABLE ROW LEVEL SECURITY;
GRANT ALL ON TABLE public.push_dedup TO service_role;
GRANT ALL ON TABLE public.push_dedup TO postgres;

DROP POLICY IF EXISTS "push_dedup_service_only" ON public.push_dedup;
CREATE POLICY "push_dedup_service_only" ON public.push_dedup
    FOR ALL
    USING (false)
    WITH CHECK (false);

CREATE INDEX IF NOT EXISTS idx_push_dedup_created_at ON public.push_dedup (created_at);

-- Drop rows older than 10 minutes so the table stays small.
CREATE OR REPLACE FUNCTION public.cleanup_push_dedup()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    DELETE FROM public.push_dedup
    WHERE created_at < timezone('utc'::TEXT, now()) - INTERVAL '10 minutes';
$$;

CREATE OR REPLACE FUNCTION public.notify_content_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    request_body jsonb;
    is_silent boolean := true;
    entity_name text;
    record_id text;
    functions_url text;
    service_key text;
BEGIN
    -- view_count ticks must never wake every device.
    IF TG_TABLE_NAME = 'songs' AND TG_OP = 'UPDATE' THEN
        IF NEW.title IS NOT DISTINCT FROM OLD.title
           AND NEW.lyrics IS NOT DISTINCT FROM OLD.lyrics
           AND NEW.artist_name IS NOT DISTINCT FROM OLD.artist_name
           AND NEW.artist_id IS NOT DISTINCT FROM OLD.artist_id
           AND NEW.album_id IS NOT DISTINCT FROM OLD.album_id
           AND NEW.album_title IS NOT DISTINCT FROM OLD.album_title
           AND NEW.english_title IS NOT DISTINCT FROM OLD.english_title
           AND NEW.scale IS NOT DISTINCT FROM OLD.scale
           AND NEW.rhythm IS NOT DISTINCT FROM OLD.rhythm
           AND NEW.search_keywords IS NOT DISTINCT FROM OLD.search_keywords
        THEN
            RETURN NEW;
        END IF;
    END IF;

    IF TG_TABLE_NAME = 'songs' AND TG_OP = 'INSERT' THEN
        is_silent := false;
    END IF;

    entity_name := CASE TG_TABLE_NAME
        WHEN 'artists' THEN 'artist'
        WHEN 'albums' THEN 'album'
        WHEN 'songs' THEN 'song'
        ELSE 'all'
    END;

    record_id := COALESCE(NEW.id, OLD.id)::text;

    request_body := jsonb_build_object(
        'type', CASE WHEN is_silent THEN 'content_updated' ELSE 'new_content' END,
        'silent', is_silent,
        'entity', entity_name,
        'entityId', record_id
    );

    IF NOT is_silent THEN
        request_body := request_body || jsonb_build_object(
            'title', 'New Song Available',
            'body', format(
                '"%s" by %s is now in your library.',
                COALESCE(NEW.title, 'A new song'),
                COALESCE(NEW.artist_name, 'Mahlete Semay')
            ),
            'reference', record_id
        );
    END IF;

    functions_url := current_setting('app.settings.edge_functions_url', true);
    service_key := current_setting('app.settings.service_role_key', true);

    IF functions_url IS NULL OR functions_url = '' THEN
        functions_url := 'https://onsvnudakxkrqazrufar.supabase.co/functions/v1';
    END IF;

    -- Optional: ALTER DATABASE postgres SET app.settings.service_role_key = '<service_role>';
    -- Prefer a Dashboard Database Webhook if you do not want the key in Postgres settings.
    IF service_key IS NULL OR service_key = '' THEN
        RAISE NOTICE 'notify_content_change: skipped HTTP, service role key not configured';
        RETURN COALESCE(NEW, OLD);
    END IF;

    PERFORM net.http_post(
        url := functions_url || '/send-push',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || service_key
        ),
        body := request_body
    );

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_artists_notify_content ON public.artists;
CREATE TRIGGER trg_artists_notify_content
    AFTER INSERT OR UPDATE OR DELETE ON public.artists
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_content_change();

DROP TRIGGER IF EXISTS trg_albums_notify_content ON public.albums;
CREATE TRIGGER trg_albums_notify_content
    AFTER INSERT OR UPDATE OR DELETE ON public.albums
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_content_change();

DROP TRIGGER IF EXISTS trg_songs_notify_content ON public.songs;
CREATE TRIGGER trg_songs_notify_content
    AFTER INSERT OR UPDATE OR DELETE ON public.songs
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_content_change();
