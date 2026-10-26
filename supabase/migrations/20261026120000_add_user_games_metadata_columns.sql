-- ==============================================================================
-- Add first-class metadata columns to user_games and games tables
-- Replaces legacy <!--GS_META:...--> notes packing with dedicated columns.
-- ==============================================================================

-- 1. Add new columns to user_games
ALTER TABLE public.user_games
    ADD COLUMN IF NOT EXISTS story_progress TEXT,
    ADD COLUMN IF NOT EXISTS hours_played DOUBLE PRECISION DEFAULT 0,
    ADD COLUMN IF NOT EXISTS progress_note TEXT,
    ADD COLUMN IF NOT EXISTS note_updated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS play_types TEXT[] NOT NULL DEFAULT '{"singlePlayer"}'::TEXT[],
    ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'none',
    ADD COLUMN IF NOT EXISTS is_backlog BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS last_played_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS started_playing_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS paused_date TIMESTAMPTZ;

-- 2. Add new columns to games (legacy/single-tenant table)
ALTER TABLE public.games
    ADD COLUMN IF NOT EXISTS story_progress TEXT,
    ADD COLUMN IF NOT EXISTS hours_played DOUBLE PRECISION DEFAULT 0,
    ADD COLUMN IF NOT EXISTS progress_note TEXT,
    ADD COLUMN IF NOT EXISTS note_updated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS play_types TEXT[] NOT NULL DEFAULT '{"singlePlayer"}'::TEXT[],
    ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'none',
    ADD COLUMN IF NOT EXISTS is_backlog BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS last_played_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS started_playing_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS paused_date TIMESTAMPTZ;

-- 3. Indices for fast querying, filtering, and sorting
CREATE INDEX IF NOT EXISTS idx_user_games_last_played ON public.user_games(last_played_date);
CREATE INDEX IF NOT EXISTS idx_user_games_story_progress ON public.user_games(story_progress);
CREATE INDEX IF NOT EXISTS idx_user_games_priority ON public.user_games(priority);
CREATE INDEX IF NOT EXISTS idx_user_games_is_backlog ON public.user_games(is_backlog);

-- 4. Backfill existing metadata from <!--GS_META:...--> inside notes to the new columns
DO $$
DECLARE
    r RECORD;
    meta JSONB;
    meta_text TEXT;
BEGIN
    FOR r IN SELECT id, notes FROM public.user_games WHERE notes LIKE '<!--GS_META:%' LOOP
        meta_text := substring(r.notes from '<!--GS_META:(.*?)-->');
        IF meta_text IS NOT NULL THEN
            BEGIN
                meta := meta_text::jsonb;
                UPDATE public.user_games
                SET
                    story_progress = COALESCE(story_progress, meta->>'story_progress'),
                    hours_played = COALESCE(NULLIF(hours_played, 0), (meta->>'hours_played')::double precision, 0),
                    progress_note = COALESCE(progress_note, meta->>'progress_note'),
                    note_updated_at = COALESCE(note_updated_at, (meta->>'note_updated_at')::timestamptz),
                    priority = COALESCE(NULLIF(priority, 'none'), meta->>'priority', 'none'),
                    is_backlog = COALESCE(is_backlog, (meta->>'is_backlog')::boolean, false),
                    last_played_date = COALESCE(last_played_date, (meta->>'last_played_date')::timestamptz),
                    started_playing_date = COALESCE(started_playing_date, (meta->>'started_playing_date')::timestamptz),
                    paused_date = COALESCE(paused_date, (meta->>'paused_date')::timestamptz),
                    completed_year = COALESCE(completed_year, (meta->>'completed_year')::integer),
                    completed_date = COALESCE(completed_date, (meta->>'completed_date')::timestamptz),
                    notes = trim(regexp_replace(notes, '^<!--GS_META:.*?-->\r?\n?', ''))
                WHERE id = r.id;
            EXCEPTION WHEN OTHERS THEN
                -- Ignore JSON parse errors and leave untouched
            END;
        END IF;
    END LOOP;
END $$;
