-- ==============================================================================
-- Pairing Sessions Table (Lösenordsfri parkoppling mellan iOS och Web)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.pairing_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(12) UNIQUE NOT NULL,
    user_id UUID,
    session_data JSONB DEFAULT '{}'::JSONB,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'expired'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '15 minutes')
);

-- Index för snabb sökning på kod
CREATE INDEX IF NOT EXISTS idx_pairing_sessions_code ON public.pairing_sessions(code);

-- RLS
ALTER TABLE public.pairing_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon insert and select on pairing_sessions"
    ON public.pairing_sessions
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- Realtime aktivering
ALTER PUBLICATION supabase_realtime ADD TABLE public.pairing_sessions;
