require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const BUCKET_NAME = 'dish-images';

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_KEY in .env');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function sync() {
  console.log('🔄 Syncing dish images from storage to database...');

  // 1. Fetch all storage objects in the bucket
  const { data: objects, error: storageErr } = await supabase.storage
    .from(BUCKET_NAME)
    .list('', { limit: 1000, recursive: true });

  if (storageErr) {
    console.error('❌ Failed to list storage objects:', storageErr.message);
    return;
  }

  console.log(`📂 Found ${objects.length} objects in storage.`);

  // 2. Fetch all restaurants and dishes
  const { data: restaurants, error: restErr } = await supabase.from('restaurants').select('id, slug');
  const { data: dishes, error: dishErr } = await supabase.from('dishes').select('id, name, restaurant_id');

  if (restErr || dishErr) {
    console.error('❌ Failed to fetch database records');
    return;
  }

  const restMap = Object.fromEntries(restaurants.map(r => [r.id, r.slug]));
  let updatedCount = 0;

  for (const obj of objects) {
    // Expected path format: slug/dish-name.jpg
    const parts = obj.name.split('/');
    if (parts.length < 2) continue;

    const slug = parts[0];
    const filename = parts[parts.length - 1].toLowerCase();

    // Find dishes for this restaurant slug
    const possibleDishes = dishes.filter(d => restMap[d.restaurant_id] === slug);

    for (const dish of possibleDishes) {
      const kebabName = dish.name.toLowerCase().replace(/[^a-z0-9]/g, '-') + '.jpg';
      const simpleName = dish.name.toLowerCase().replace(/\s+/g, '-') + '.jpg';

      if (filename === kebabName || filename === simpleName) {
        const { data: { publicUrl } } = supabase.storage
          .from(BUCKET_NAME)
          .getPublicUrl(obj.name);

        console.log(`✨ Matching ${dish.name} -> ${obj.name}`);
        
        const { error: updateErr } = await supabase
          .from('dishes')
          .update({
            image_url: publicUrl,
            image_generated: true,
            emoji: null
          })
          .eq('id', dish.id);

        if (!updateErr) updatedCount++;
        else console.error(`❌ Failed to update ${dish.name}:`, updateErr.message);
      }
    }
  }

  console.log(`\n✅ Finished! Updated ${updatedCount} dishes.`);
}

sync();
