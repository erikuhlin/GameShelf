-- Add completed_year and completed_date to user_games and games tables
ALTER TABLE public.user_games ADD COLUMN IF NOT EXISTS completed_year INTEGER;
ALTER TABLE public.user_games ADD COLUMN IF NOT EXISTS completed_date TIMESTAMPTZ;

ALTER TABLE public.games ADD COLUMN IF NOT EXISTS completed_year INTEGER;
ALTER TABLE public.games ADD COLUMN IF NOT EXISTS completed_date TIMESTAMPTZ;

-- Create indices for completed_year for fast goal calculations
CREATE INDEX IF NOT EXISTS idx_user_games_completed_year ON public.user_games(completed_year);
CREATE INDEX IF NOT EXISTS idx_games_completed_year ON public.games(completed_year);
