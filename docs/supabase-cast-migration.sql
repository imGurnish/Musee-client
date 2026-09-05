-- =============================================================================
-- Musee Sync & Cast Feature - Supabase SQL Migration
-- Run this script in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/xvpputhovrhgowfkjhfv/sql/new
-- =============================================================================

-- 1. Device Auth Tokens (for TV / Car QR-code sign in)
CREATE TABLE IF NOT EXISTS public.device_auth_tokens (
  token        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  device_name  TEXT,
  status       TEXT NOT NULL DEFAULT 'pending', -- pending | approved | expired
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at   TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '5 minutes'),
  approved_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_device_auth_tokens_expires_at ON public.device_auth_tokens(expires_at);

-- 2. Cast Sessions (Receivers & Controllers)
CREATE TABLE IF NOT EXISTS public.cast_sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  session_code  TEXT UNIQUE,           -- e.g. "JAZZ42"
  device_name   TEXT,
  status        TEXT NOT NULL DEFAULT 'active', -- active | ended
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_cast_sessions_code ON public.cast_sessions(session_code);
CREATE INDEX IF NOT EXISTS idx_cast_sessions_owner ON public.cast_sessions(owner_id);

-- 3. Cast Session State (Single source of truth for playback & EQ)
CREATE TABLE IF NOT EXISTS public.cast_session_state (
  session_id                 UUID PRIMARY KEY REFERENCES public.cast_sessions(id) ON DELETE CASCADE,
  current_track_id           TEXT,
  current_track_title        TEXT,
  current_track_artist       TEXT,
  current_track_album        TEXT,
  current_track_image_url    TEXT,
  current_track_duration_ms  BIGINT,
  queue                      JSONB NOT NULL DEFAULT '[]'::jsonb,
  queue_index                INT NOT NULL DEFAULT 0,
  position_ms                BIGINT NOT NULL DEFAULT 0,
  is_playing                 BOOLEAN NOT NULL DEFAULT false,
  volume                     FLOAT NOT NULL DEFAULT 1.0,
  shuffle                    BOOLEAN NOT NULL DEFAULT false,
  repeat_mode                TEXT NOT NULL DEFAULT 'none',
  
  -- Equalizer & Audio controls
  eq_enabled                 BOOLEAN NOT NULL DEFAULT true,
  eq_preset                  TEXT NOT NULL DEFAULT 'normal',
  eq_bands                   JSONB NOT NULL DEFAULT '[0.0, 0.0, 0.0, 0.0, 0.0]'::jsonb,
  bass_level                 INT NOT NULL DEFAULT 0,
  surround_level             INT NOT NULL DEFAULT 0,
  crossfade_enabled          BOOLEAN NOT NULL DEFAULT false,
  normalize_volume           BOOLEAN NOT NULL DEFAULT false,

  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Idempotent column additions for existing tables
ALTER TABLE public.cast_session_state ADD COLUMN IF NOT EXISTS current_track_title TEXT;
ALTER TABLE public.cast_session_state ADD COLUMN IF NOT EXISTS current_track_artist TEXT;
ALTER TABLE public.cast_session_state ADD COLUMN IF NOT EXISTS current_track_album TEXT;
ALTER TABLE public.cast_session_state ADD COLUMN IF NOT EXISTS current_track_image_url TEXT;
ALTER TABLE public.cast_session_state ADD COLUMN IF NOT EXISTS current_track_duration_ms BIGINT;

-- 4. Cast Session Receivers (Track connected devices)
CREATE TABLE IF NOT EXISTS public.cast_session_receivers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id  UUID NOT NULL REFERENCES public.cast_sessions(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  device_name TEXT,
  joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  left_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_cast_receivers_session ON public.cast_session_receivers(session_id);

-- 5. Enable Realtime on cast tables
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.cast_session_state;
  EXCEPTION WHEN duplicate_object THEN
    NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.device_auth_tokens;
  EXCEPTION WHEN duplicate_object THEN
    NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.cast_sessions;
  EXCEPTION WHEN duplicate_object THEN
    NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.cast_session_receivers;
  EXCEPTION WHEN duplicate_object THEN
    NULL;
  END;
END $$;

-- 6. Row Level Security (RLS)
ALTER TABLE public.device_auth_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cast_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cast_session_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cast_session_receivers ENABLE ROW LEVEL SECURITY;

-- Device auth tokens: open for pending pairing
DROP POLICY IF EXISTS "Anyone can manage device_auth_tokens" ON public.device_auth_tokens;
CREATE POLICY "Anyone can manage device_auth_tokens"
  ON public.device_auth_tokens FOR ALL
  USING (true)
  WITH CHECK (true);

-- Cast sessions: open for active sessions & pairing codes
DROP POLICY IF EXISTS "Anyone can read active cast_sessions" ON public.cast_sessions;
CREATE POLICY "Anyone can read active cast_sessions"
  ON public.cast_sessions FOR SELECT
  USING (status = 'active');

DROP POLICY IF EXISTS "Anyone can create cast_sessions" ON public.cast_sessions;
CREATE POLICY "Anyone can create cast_sessions"
  ON public.cast_sessions FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can update cast_sessions" ON public.cast_sessions;
CREATE POLICY "Anyone can update cast_sessions"
  ON public.cast_sessions FOR UPDATE
  USING (true);

-- Cast session state: accessible by anyone in the session
DROP POLICY IF EXISTS "Anyone can manage cast_session_state" ON public.cast_session_state;
CREATE POLICY "Anyone can manage cast_session_state"
  ON public.cast_session_state FOR ALL
  USING (true)
  WITH CHECK (true);

-- Cast receivers: open for registration
DROP POLICY IF EXISTS "Anyone can manage cast_session_receivers" ON public.cast_session_receivers;
CREATE POLICY "Anyone can manage cast_session_receivers"
  ON public.cast_session_receivers FOR ALL
  USING (true)
  WITH CHECK (true);

-- 7. Reload PostgREST schema cache immediately
NOTIFY pgrst, 'reload schema';
