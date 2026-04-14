-- ─────────────────────────────────────────────────────────
-- GoDine — Multi-Restaurant Database Setup
-- Run this in: Supabase → SQL Editor → New Query → Run
-- ─────────────────────────────────────────────────────────

-- Restaurants table
create table if not exists restaurants (
  id             uuid    default gen_random_uuid() primary key,
  name           text    not null,
  slug           text    not null unique,
  owner_password text    not null,
  total_tables   integer default 10,
  created_at     timestamptz default now()
);

-- Dishes table (scoped to restaurant)
create table if not exists dishes (
  id            uuid    default gen_random_uuid() primary key,
  restaurant_id uuid    not null references restaurants(id) on delete cascade,
  name          text    not null,
  description   text    default '',
  price         numeric(10,2) not null,
  category      text    default 'Main Course',
  emoji         text    default '🍽️',
  available     boolean default true,
  created_at    timestamptz default now()
);

-- Orders table (scoped to restaurant)
create table if not exists orders (
  id            uuid    default gen_random_uuid() primary key,
  restaurant_id uuid    not null references restaurants(id) on delete cascade,
  table_number  text    not null,
  items         jsonb   not null default '[]',
  total         numeric(10,2) not null default 0,
  status        text    default 'pending'
                        check (status in ('pending','preparing','ready','completed')),
  note          text    default '',
  customer_name text,
  customer_phone text,
  customer_uid  uuid    references auth.users(id) on delete set null,
  estimated_time text,
  created_at    timestamptz default now()
);

-- Enable Realtime for orders
alter publication supabase_realtime add table orders;

-- Disable RLS for development (enable for production)
alter table restaurants disable row level security;
alter table dishes      disable row level security;
alter table orders      disable row level security;

-- ─────────────────────────────────────────────────────────
-- Seed: Demo restaurant + 12 sample dishes
-- ─────────────────────────────────────────────────────────

insert into restaurants (id, name, slug, owner_password, total_tables) values
  ('00000000-0000-0000-0000-000000000001', 'The Rustic Fork', 'demo', 'demo1234', 10);

insert into dishes (restaurant_id, name, description, price, category, emoji) values
  ('00000000-0000-0000-0000-000000000001', 'Pasta Arrabbiata',    'Spicy tomato penne, parmesan',       280,  'Main Course', '🍝'),
  ('00000000-0000-0000-0000-000000000001', 'Smash Burger',        'Double patty, secret sauce, fries',  320,  'Main Course', '🍔'),
  ('00000000-0000-0000-0000-000000000001', 'Margherita Pizza',    'Classic with fresh basil',           350,  'Main Course', '🍕'),
  ('00000000-0000-0000-0000-000000000001', 'Grilled Chicken',     'Herb-marinated, side salad',         380,  'Main Course', '🍗'),
  ('00000000-0000-0000-0000-000000000001', 'Caesar Salad',        'Romaine, croutons, parmesan',        220,  'Starters',    '🥗'),
  ('00000000-0000-0000-0000-000000000001', 'Garlic Bread',        'Toasted with herb butter',           120,  'Starters',    '🥖'),
  ('00000000-0000-0000-0000-000000000001', 'Veg Spring Rolls',    'Crispy, sweet chilli dip',           160,  'Starters',    '🥟'),
  ('00000000-0000-0000-0000-000000000001', 'Cold Coffee',         'Chilled espresso, milk, ice',        150,  'Beverages',   '☕'),
  ('00000000-0000-0000-0000-000000000001', 'Mango Lassi',         'Fresh mango, yogurt, chilled',       120,  'Beverages',   '🥤'),
  ('00000000-0000-0000-0000-000000000001', 'Fresh Lime Soda',     'Sweet or salt, chilled',              80,  'Beverages',   '🍋'),
  ('00000000-0000-0000-0000-000000000001', 'Chocolate Lava Cake', 'Warm, vanilla ice cream',            220,  'Desserts',    '🍫'),
  ('00000000-0000-0000-0000-000000000001', 'Gulab Jamun',         'Classic, sugar syrup, warm',         140,  'Desserts',    '🍮');

-- ─────────────────────────────────────────────────────────
-- Image Generator Extension
-- ─────────────────────────────────────────────────────────

-- Ensure columns exist
alter table dishes add column if not exists image_url text;
alter table dishes add column if not exists image_generated boolean default false;
alter table dishes add column if not exists image_updated_at timestamp;

-- Create storage bucket (ignore if exists)
insert into storage.buckets (id, name, public) 
values ('dish-images', 'dish-images', true)
on conflict (id) do nothing;

-- Storage Policies
-- Note: These might fail if already created or if run multiple times without proper guards
-- But for a clean setup.sql they are perfect.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public Access' AND tablename = 'objects' AND schemaname = 'storage') THEN
        create policy "Public Access" on storage.objects for select using (bucket_id = 'dish-images');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service Role Access' AND tablename = 'objects' AND schemaname = 'storage') THEN
        create policy "Service Role Access" on storage.objects for all using (bucket_id = 'dish-images') with check (bucket_id = 'dish-images');
    END IF;
END $$;
