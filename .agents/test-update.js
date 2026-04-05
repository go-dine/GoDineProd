const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const config = fs.readFileSync('./config.js', 'utf8');
const matchUrl = config.match(/const SUPABASE_URL = ["']([^"']+)["']/);
const matchKey = config.match(/const SUPABASE_ANON_KEY = ["']([^"']+)["']/);

if (!matchUrl || !matchKey) {
  console.log('Could not find config');
  process.exit(1);
}

const sb = createClient(matchUrl[1], matchKey[1]);

async function run() {
  const { data: rest } = await sb.from('restaurants').select('id').limit(1).single();
  console.log('Got restaurant:', rest.id);

  // Insert
  let { data: order, error: insertErr } = await sb.from('orders').insert({
    restaurant_id: rest.id,
    table_number: '1',
    customer_name: 'Cancel Test',
    items: [],
    total: 0,
    status: 'pending'
  }).select().single();

  if (insertErr) {
    console.error('Insert failed:', insertErr);
    return;
  }
  
  console.log('Inserted order:', order.id);

  // Update
  const { data: updated, error: updateErr } = await sb.from('orders')
    .update({ status: 'cancelled' })
    .eq('id', order.id)
    .select();
    
  if (updateErr) {
    console.error('Update failed:', updateErr);
  } else {
    console.log('Update succeeded:', updated);
  }
}

run();
