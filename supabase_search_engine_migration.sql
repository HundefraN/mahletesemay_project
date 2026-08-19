-- ==============================================================================
-- Mahlete Semay - Multi-Script Search Engine Migration
-- Enables fast, indexed search across Artists, Albums, Songs, and Exercises
-- Supports Amharic script & English phonetic transliterations
-- ==============================================================================

-- 1. Enable pg_trgm extension for fuzzy trigram text matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. Add search columns to Artists
ALTER TABLE public.artists 
    ADD COLUMN IF NOT EXISTS search_keywords TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS english_name TEXT NOT NULL DEFAULT '';

-- 3. Add search columns to Albums
ALTER TABLE public.albums 
    ADD COLUMN IF NOT EXISTS search_keywords TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS english_title TEXT NOT NULL DEFAULT '';

-- 4. Add search columns to Songs
ALTER TABLE public.songs 
    ADD COLUMN IF NOT EXISTS search_keywords TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS english_title TEXT NOT NULL DEFAULT '';

-- 5. Add search columns to General Exercises
ALTER TABLE public.general_exercises 
    ADD COLUMN IF NOT EXISTS search_keywords TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS english_title TEXT NOT NULL DEFAULT '';

-- 6. Create GIN Indexes on search_keywords for array overlap and containment queries
CREATE INDEX IF NOT EXISTS idx_artists_search_keywords ON public.artists USING GIN (search_keywords);
CREATE INDEX IF NOT EXISTS idx_albums_search_keywords ON public.albums USING GIN (search_keywords);
CREATE INDEX IF NOT EXISTS idx_songs_search_keywords ON public.songs USING GIN (search_keywords);
CREATE INDEX IF NOT EXISTS idx_general_exercises_search_keywords ON public.general_exercises USING GIN (search_keywords);

-- 7. Create Trigram Indexes for fast ILIKE and substring queries
CREATE INDEX IF NOT EXISTS idx_artists_name_trgm ON public.artists USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_artists_english_name_trgm ON public.artists USING GIN (english_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_albums_title_trgm ON public.albums USING GIN (title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_albums_english_title_trgm ON public.albums USING GIN (english_title gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_songs_title_trgm ON public.songs USING GIN (title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_songs_english_title_trgm ON public.songs USING GIN (english_title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_songs_artist_name_trgm ON public.songs USING GIN (artist_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_songs_lyrics_trgm ON public.songs USING GIN (lyrics gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_general_exercises_title_trgm ON public.general_exercises USING GIN (title gin_trgm_ops);

-- 8. PostgreSQL RPC Search Function for Server-Side Unified Multi-Script Search
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
