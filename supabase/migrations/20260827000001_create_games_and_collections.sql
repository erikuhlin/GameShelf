-- Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Games table
CREATE TABLE IF NOT EXISTS public.games (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID DEFAULT auth.uid(),
    title TEXT NOT NULL,
    platforms TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    release_year INTEGER,
    genres TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    developers TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    status TEXT NOT NULL DEFAULT 'Backlog',
    rating INTEGER,
    igdb_rating DOUBLE PRECISION,
    cover_url TEXT,
    igdb_id BIGINT,
    estimated_hours INTEGER,
    is_owned BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT NOT NULL DEFAULT '',
    todos JSONB NOT NULL DEFAULT '[]'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Collections table
CREATE TABLE IF NOT EXISTS public.collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID DEFAULT auth.uid(),
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    game_ids UUID[] NOT NULL DEFAULT '{}'::UUID[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indices for performance
CREATE INDEX IF NOT EXISTS idx_games_user_id ON public.games(user_id);
CREATE INDEX IF NOT EXISTS idx_games_status ON public.games(status);
CREATE INDEX IF NOT EXISTS idx_games_igdb_id ON public.games(igdb_id);
CREATE INDEX IF NOT EXISTS idx_collections_user_id ON public.collections(user_id);

-- Automatic updated_at trigger function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_games_updated_at ON public.games;
CREATE TRIGGER set_games_updated_at
    BEFORE UPDATE ON public.games
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_collections_updated_at ON public.collections;
CREATE TRIGGER set_collections_updated_at
    BEFORE UPDATE ON public.collections
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Enable Row Level Security (RLS)
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;

-- RLS Policies for games
-- Allow authenticated users access to their own rows
CREATE POLICY "Users can manage their own games"
    ON public.games
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Allow anonymous access for local development / single-user mode
CREATE POLICY "Allow anon access for local dev on games"
    ON public.games
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

-- RLS Policies for collections
CREATE POLICY "Users can manage their own collections"
    ON public.collections
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow anon access for local dev on collections"
    ON public.collections
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

-- Enable Supabase Realtime & Replica Identity for both tables
ALTER TABLE public.games REPLICA IDENTITY FULL;
ALTER TABLE public.collections REPLICA IDENTITY FULL;

ALTER PUBLICATION supabase_realtime ADD TABLE public.games;
ALTER PUBLICATION supabase_realtime ADD TABLE public.collections;
