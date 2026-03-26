import { createClient } from '@supabase/supabase-js';
import * as SecureStore from 'expo-secure-store';

// Same credentials as web config.js
const SUPABASE_URL = 'https://qqnrucnsvupfywyzlofa.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFxbnJ1Y25zdnVwZnl3eXpsb2ZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNzk1MjEsImV4cCI6MjA4OTc1NTUyMX0.9zyd5GBq9WCXl0XcCXDge311LGqPKZ4IV4Pm-GA1Mu0';

export const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Secure storage helpers for auth persistence
export const SecureStorage = {
  async save(key: string, value: string) {
    await SecureStore.setItemAsync(key, value);
  },
  async get(key: string): Promise<string | null> {
    return await SecureStore.getItemAsync(key);
  },
  async remove(key: string) {
    await SecureStore.deleteItemAsync(key);
  },
};

// Types matching the Supabase schema
export interface Restaurant {
  id: string;
  name: string;
  slug: string;
  owner_password: string;
  total_tables: number;
  created_at: string;
}

export interface Dish {
  id: string;
  restaurant_id: string;
  name: string;
  description: string;
  price: number;
  category: string;
  emoji: string;
  available: boolean;
  created_at: string;
}

export interface OrderItem {
  name: string;
  qty: number;
  price: number;
  emoji: string;
}

export interface Order {
  id: string;
  restaurant_id: string;
  table_number: string;
  customer_name?: string;
  customer_phone?: string;
  customer_uid?: string;
  items: OrderItem[];
  total: number;
  status: 'pending' | 'preparing' | 'ready' | 'completed';
  note: string;
  estimated_time?: string;
  created_at: string;
}
