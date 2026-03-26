-- Run this in: Supabase → SQL Editor → New Query → Run
ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;
