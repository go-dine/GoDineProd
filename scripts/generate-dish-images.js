require('dotenv').config();
const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');
const { createClient } = require('@supabase/supabase-js');

// ── CONFIG ──
const CF_ACCOUNT_ID = process.env.CF_ACCOUNT_ID;
const CF_API_TOKEN = process.env.CF_API_TOKEN;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

const BUCKET_NAME = 'dish-images';
const LOG_FILE = path.join(__dirname, '../public/dish-images/generation-log.json');

// ── INIT ──
if (!CF_ACCOUNT_ID || !CF_API_TOKEN || !SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('\x1b[31m%s\x1b[0m', '❌ Missing environment variables!');
  console.log('Please create a .env file with:');
  console.log('CF_ACCOUNT_ID=...\nCF_API_TOKEN=...\nSUPABASE_URL=...\nSUPABASE_SERVICE_KEY=...');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// ── PROMPT ENGINEERING ──
function buildFoodPrompt(dish) {
  const category = (dish.category || '').toLowerCase();
  let style = 'A photorealistic, high-end restaurant food photography shot.';
  
  if (category.includes('drink') || category.includes('beverage')) {
    style = 'Professional beverage photography, condensation on glass, soft studio lighting, bokeh background.';
  } else if (category.includes('dessert') || category.includes('sweet')) {
    style = 'Gourmet dessert photography, macro focus on textures, drizzled sauce, elegant plating.';
  } else if (category.includes('burger') || category.includes('sandwich')) {
    style = 'Cross-section food photography, dramatic lighting, visible textures of ingredients, gourmet style.';
  } else if (category.includes('pizza') || category.includes('italian')) {
    style = 'Authentic italian food photography, steam rising, vibrant colors, rustic wooden table background.';
  }

  return `${style} Dish: ${dish.name}. Features: ${dish.description || 'Appetizing presentation'}. 
          Plated on a premium minimalist ceramic plate. 8k resolution, cinematic lighting, sharp focus, 
          ultra-realistic textures, vibrant natural colors, shot on Sony A7R IV. NO TEXT, NO LABELS, NO WATERMARKS.`;
}

// ── HELPERS ──
const delay = (ms) => new Promise(res => setTimeout(res, ms));

async function generateAIImage(prompt) {
  const url = `https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/ai/run/@cf/black-forest-labs/flux-1-schnell`;
  
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${CF_API_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ prompt })
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Cloudflare AI Error: ${err}`);
  }

  // Cloudflare returns an image buffer directly for this model or a JSON with base64/url depending on response
  // Flux returns an image stream (application/octet-stream)
  const resText = await response.text();
  try {
    const json = JSON.parse(resText);
    if (json.result && json.result.image) {
      return Buffer.from(json.result.image, 'base64');
    } else {
      throw new Error("Invalid JSON response shape from Cloudflare AI");
    }
  } catch (e) {
    // If it's not JSON, maybe it's a direct buffer stream
    return Buffer.from(resText, 'binary');
  }
}

async function run() {
  console.log('\x1b[36m%s\x1b[0m', '🚀 Starting GoDine Dish Image Generator...');

  // 1. Fetch dishes needing images (those with emojis and no image_url)
  // Or dishes where image_generated is false
  const { data: dishes, error: fetchErr } = await supabase
    .from('dishes')
    .select('*, restaurants(name, slug)')
    .eq('image_generated', false)
    .limit(200);

  if (fetchErr) {
    console.error('Failed to fetch dishes:', fetchErr);
    return;
  }

  if (!dishes || dishes.length === 0) {
    console.log('✅ No dishes need processing.');
    return;
  }

  console.log(`📦 Found ${dishes.length} dishes to process.`);

  const logs = fs.existsSync(LOG_FILE) ? JSON.parse(fs.readFileSync(LOG_FILE)) : [];

  for (const dish of dishes) {
    const restSlug = dish.restaurants.slug || 'generic';
    const filename = `${dish.id}.jpg`;
    const localDir = path.join(__dirname, `../public/dish-images/${restSlug}`);
    const localPath = path.join(localDir, filename);
    const storagePath = `${restSlug}/${filename}`;

    console.log(`\n⏳ Processing: ${dish.name} (${restSlug})...`);

    try {
      // 1. Generate Image
      const prompt = buildFoodPrompt(dish);
      const imageBuffer = await generateAIImage(prompt);

      // 2. Save Locally
      if (!fs.existsSync(localDir)) fs.mkdirSync(localDir, { recursive: true });
      fs.writeFileSync(localPath, imageBuffer);
      console.log(`   ✅ Saved locally: ${localPath}`);

      // 3. Upload to Supabase Storage
      const { data: uploadData, error: uploadErr } = await supabase.storage
        .from(BUCKET_NAME)
        .upload(storagePath, imageBuffer, {
          contentType: 'image/jpeg',
          upsert: true
        });

      if (uploadErr) throw uploadErr;

      // 4. Get Public URL
      const { data: { publicUrl } } = supabase.storage
        .from(BUCKET_NAME)
        .getPublicUrl(storagePath);

      // 5. Update Database record
      const { error: updateErr } = await supabase
        .from('dishes')
        .update({
          image_url: publicUrl,
          image_generated: true,
          emoji: null, // Clear emoji as we now have a real photo
          image_updated_at: new Date().toISOString()
        })
        .eq('id', dish.id);

      if (updateErr) throw updateErr;

      console.log(`   ✨ Success! Public URL: ${publicUrl}`);
      
      logs.push({
        id: dish.id,
        name: dish.name,
        restaurant: restSlug,
        url: publicUrl,
        timestamp: new Date().toISOString()
      });

    } catch (err) {
      console.error(`   ❌ Failed: ${err.message}`);
      logs.push({
        id: dish.id,
        name: dish.name,
        error: err.message,
        timestamp: new Date().toISOString()
      });
    }

    // Rate limiting delay
    await delay(1500);
  }

  fs.writeFileSync(LOG_FILE, JSON.stringify(logs, null, 2));
  console.log(`\n🏁 Done! Log saved to ${LOG_FILE}`);
}

run();
