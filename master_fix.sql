-- ─────────────────────────────────────────────────────────
-- GoDine — Master Database Fix
-- Run this in: Supabase → SQL Editor → New Query → Run
-- ─────────────────────────────────────────────────────────

-- 1. Create missing 'leads' table
CREATE TABLE IF NOT EXISTS public.leads (
  id              UUID         DEFAULT gen_random_uuid() PRIMARY KEY,
  restaurant_name TEXT         NOT NULL,
  location        TEXT         NOT NULL,
  phone           TEXT         NOT NULL,
  created_at      TIMESTAMPTZ  DEFAULT now()
);

-- 2. Add missing 'token_number' to 'orders'
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS token_number TEXT;

-- 3. Add subscription tracking to 'restaurants'
ALTER TABLE public.restaurants 
ADD COLUMN IF NOT EXISTS subscription_end TIMESTAMPTZ DEFAULT (now() + interval '14 days');

ALTER TABLE public.restaurants 
ADD COLUMN IF NOT EXISTS is_trial BOOLEAN DEFAULT true;

-- 4. Enable Realtime for all tracked tables
-- Ensure publication exists
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;

-- Add tables to publication
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE leads;
ALTER PUBLICATION supabase_realtime ADD TABLE waiter_calls;

-- 5. Set Replica Identity to FULL for Realtime tables
-- This ensures that for UPDATE events, we get old vs new data and reliable filtering.
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.waiter_calls REPLICA IDENTITY FULL;

-- 6. Disable RLS for development (Recommended only for initial setup)
ALTER TABLE leads DISABLE ROW LEVEL SECURITY;
ALTER TABLE restaurants DISABLE ROW LEVEL SECURITY;
ALTER TABLE orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE dishes DISABLE ROW LEVEL SECURITY;
ALTER TABLE waiter_calls DISABLE ROW LEVEL SECURITY;
