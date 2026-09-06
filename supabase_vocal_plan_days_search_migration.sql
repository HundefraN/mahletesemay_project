-- Add search columns to vocal plan days so admin writes match general exercises.
ALTER TABLE public.vocal_plan_days
    ADD COLUMN IF NOT EXISTS english_title TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS search_keywords TEXT[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_vocal_plan_days_search_keywords
    ON public.vocal_plan_days USING GIN (search_keywords);
