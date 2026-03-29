-- ─────────────────────────────────────────────────────────
-- GoDine — Leads & Realtime Migration
-- Adds waitlist table and enables real-time updates
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS leads (
  id              UUID         DEFAULT gen_random_uuid() PRIMARY KEY,
  restaurant_name TEXT         NOT NULL,
  location        TEXT         NOT NULL,
  phone           TEXT         NOT NULL,
  created_at      TIMESTAMPTZ  DEFAULT now()
);

-- Enable Realtime for leads
-- First check if the publication exists (it should from setup.sql)
-- Then add the table
ALTER PUBLICATION supabase_realtime ADD TABLE leads;

-- Disable RLS for development
ALTER TABLE leads DISABLE ROW LEVEL SECURITY;
