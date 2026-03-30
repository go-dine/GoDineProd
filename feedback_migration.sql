-- ─────────────────────────────────────────────────────────
-- GoDine — Feedback Table Migration
-- Run this in: Supabase → SQL Editor → New Query → Run
-- ─────────────────────────────────────────────────────────

-- Feedback table
create table if not exists feedback (
  id              uuid    default gen_random_uuid() primary key,
  order_id        uuid    references orders(id) on delete cascade,
  restaurant_id   uuid    not null references restaurants(id) on delete cascade,
  customer_name   text,
  customer_phone  text,
  food_rating     integer not null check (food_rating between 1 and 5),
  service_rating  integer not null check (service_rating between 1 and 5),
  comment         text    default '',
  created_at      timestamptz default now()
);

-- Enable Realtime for feedback
alter publication supabase_realtime add table feedback;

-- Disable RLS for development
alter table feedback disable row level security;
