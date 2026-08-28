-- ==============================================================================
-- Gameshelf Complete Database Schema for Supabase Cloud
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Games Table
CREATE TABLE IF NOT EXISTS public.games (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
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

-- 2. Collections Table
CREATE TABLE IF NOT EXISTS public.collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    game_ids UUID[] NOT NULL DEFAULT '{}'::UUID[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY,
    username TEXT,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. User Games Table
CREATE TABLE IF NOT EXISTS public.user_games (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    igdb_id BIGINT,
    first_release_date BIGINT,
    title TEXT NOT NULL,
    cover_url TEXT,
    platform TEXT,
    platforms TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    genres TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    developers TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    status TEXT NOT NULL DEFAULT 'Backlog',
    rating FLOAT,
    igdb_rating DOUBLE PRECISION,
    release_year INTEGER,
    estimated_hours INTEGER,
    is_owned BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT NOT NULL DEFAULT '',
    todos JSONB NOT NULL DEFAULT '[]'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Pairing Sessions Table (Lösenordsfri parkoppling)
CREATE TABLE IF NOT EXISTS public.pairing_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(12) UNIQUE NOT NULL,
    user_id UUID,
    session_data JSONB DEFAULT '{}'::JSONB,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '15 minutes')
);

-- Indices
CREATE INDEX IF NOT EXISTS idx_games_user_id ON public.games(user_id);
CREATE INDEX IF NOT EXISTS idx_collections_user_id ON public.collections(user_id);
CREATE INDEX IF NOT EXISTS idx_user_games_user_id ON public.user_games(user_id);
CREATE INDEX IF NOT EXISTS idx_user_games_status ON public.user_games(status);
CREATE INDEX IF NOT EXISTS idx_pairing_sessions_code ON public.pairing_sessions(code);

-- Updated at Trigger
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_games_updated_at ON public.games;
CREATE TRIGGER set_games_updated_at BEFORE UPDATE ON public.games FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_collections_updated_at ON public.collections;
CREATE TRIGGER set_collections_updated_at BEFORE UPDATE ON public.collections FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_user_games_updated_at ON public.user_games;
CREATE TRIGGER set_user_games_updated_at BEFORE UPDATE ON public.user_games FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;
CREATE TRIGGER set_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Enable Row Level Security (RLS)
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pairing_sessions ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Allow full access on games" ON public.games FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow full access on collections" ON public.collections FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow full access on profiles" ON public.profiles FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow full access on user_games" ON public.user_games FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow full access on pairing_sessions" ON public.pairing_sessions FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- Enable Realtime & Full Replica Identity
ALTER TABLE public.games REPLICA IDENTITY FULL;
ALTER TABLE public.collections REPLICA IDENTITY FULL;
ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.user_games REPLICA IDENTITY FULL;
ALTER TABLE public.pairing_sessions REPLICA IDENTITY FULL;

-- Add tables to realtime publication (handle if already added)
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.games;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.collections;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_games;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.pairing_sessions;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
END $$;
