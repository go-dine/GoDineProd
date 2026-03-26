-- Subscription Tracking Columns Migration
-- Run this directly inside the Supabase SQL Editor

ALTER TABLE public.restaurants 
ADD COLUMN IF NOT EXISTS subscription_end TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '14 days');

ALTER TABLE public.restaurants 
ADD COLUMN IF NOT EXISTS is_trial BOOLEAN DEFAULT true;
