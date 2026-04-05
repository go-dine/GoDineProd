const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const config = fs.readFileSync('./config.js', 'utf8');
const matchUrl = config.match(/const SUPABASE_URL = ["']([^"']+)["']/);
const matchKey = config.match(/const SUPABASE_ANON_KEY = ["']([^"']+)["']/);

if (!matchUrl || !matchKey) {
  console.log('Could not find Supabase config');
  process.exit(1);
}

const supabase = createClient(matchUrl[1], matchKey[1]);

async function testPlaceOrder() {
  const { data: restaurant } = await supabase.from('restaurants').select('id').limit(1).single();
  if (!restaurant) {
    console.log('No restaurant found');
    return;
  }
  
  const { data, error } = await supabase.from('orders').insert({
    restaurant_id: restaurant.id,
    table_number: '1',
    customer_name: 'Test',
    customer_phone: '+919999999999',
    customer_uid: null,
    items: [],
    total: 0,
    note: 'Test order',
    token_number: '12',
    status: 'pending',
    payment_method: 'cash'
  }).select().single();

  console.log('Result:', { data, error });
}

testPlaceOrder();
