-- ─────────────────────────────────────────────────────────
-- GoDine — Alter Migration: Bill Sent + Cancelled Status
-- Run this in: Supabase → SQL Editor → New Query → Run
-- ─────────────────────────────────────────────────────────

-- 1. Add bill_sent column to orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS bill_sent boolean DEFAULT false;

-- 2. Update status CHECK to include 'cancelled'
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE orders ADD CONSTRAINT orders_status_check
  CHECK (status IN ('pending','preparing','ready','completed','cancelled'));
