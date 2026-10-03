-- ==============================================================================
-- Game Ratings & Weighted Ratings (IGDB Bayesian Average)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.game_ratings (
    igdb_id BIGINT PRIMARY KEY,
    title TEXT NOT NULL,
    slug TEXT,
    cover_url TEXT,
    release_year INTEGER,
    first_release_date BIGINT,
    genres TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    platforms TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    platform_ids INTEGER[] NOT NULL DEFAULT '{}'::INTEGER[],
    total_rating DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    total_rating_count INTEGER NOT NULL DEFAULT 0,
    weighted_score DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    overall_rank INTEGER,
    genre_ranks JSONB NOT NULL DEFAULT '{}'::JSONB,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    computed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indices for rapid sorting, search, and filtering
CREATE INDEX IF NOT EXISTS idx_game_ratings_weighted ON public.game_ratings(weighted_score DESC);
CREATE INDEX IF NOT EXISTS idx_game_ratings_overall_rank ON public.game_ratings(overall_rank ASC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_game_ratings_release_year ON public.game_ratings(release_year);
CREATE INDEX IF NOT EXISTS idx_game_ratings_platforms ON public.game_ratings USING GIN(platforms);
CREATE INDEX IF NOT EXISTS idx_game_ratings_platform_ids ON public.game_ratings USING GIN(platform_ids);
CREATE INDEX IF NOT EXISTS idx_game_ratings_genres ON public.game_ratings USING GIN(genres);
CREATE INDEX IF NOT EXISTS idx_game_ratings_title ON public.game_ratings(title);

-- Row Level Security (RLS)
ALTER TABLE public.game_ratings ENABLE ROW LEVEL SECURITY;

-- Allow public read access to game_ratings for everyone
CREATE POLICY "Allow public read access on game_ratings"
    ON public.game_ratings
    FOR SELECT
    USING (true);

-- Allow service role full management
CREATE POLICY "Allow service role all on game_ratings"
    ON public.game_ratings
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Allow anon access for local dev / scripting
CREATE POLICY "Allow anon all for dev on game_ratings"
    ON public.game_ratings
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);
