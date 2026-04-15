require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const BUCKET_NAME = 'dish-images';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

function getFiles(dir, files = []) {
  if (!fs.existsSync(dir)) return files;
  const fileList = fs.readdirSync(dir);
  for (const file of fileList) {
    const name = path.join(dir, file);
    if (fs.statSync(name).isDirectory()) {
      getFiles(name, files);
    } else if (name.endsWith('.jpg')) {
      files.push(name);
    }
  }
  return files;
}

async function fixImages() {
  const imagesDir = path.join(__dirname, '../public/dish-images');
  const files = getFiles(imagesDir);
  let fixedCount = 0;

  for (const filePath of files) {
    const content = fs.readFileSync(filePath, 'utf8');
    
    // Check if the file starts with JSON curly brace
    if (content.trim().startsWith('{')) {
      try {
        const json = JSON.parse(content);
        if (json.result && json.result.image) {
          const base64Data = json.result.image;
          const imageBuffer = Buffer.from(base64Data, 'base64');
          
          // Overwrite the file with the proper binary
          fs.writeFileSync(filePath, imageBuffer);
          
          // Re-upload to Supabase
          const relativePath = path.relative(imagesDir, filePath).replace(/\\/g, '/');
          const { error: uploadErr } = await supabase.storage
            .from(BUCKET_NAME)
            .upload(relativePath, imageBuffer, {
              contentType: 'image/jpeg',
              upsert: true
            });
            
          if (uploadErr) {
            console.error(`❌ Failed to upload ${relativePath}:`, uploadErr);
          } else {
            console.log(`✅ Fixed and uploaded: ${relativePath}`);
            fixedCount++;
          }
        }
      } catch (err) {
        console.error(`❌ Error parsing JSON for ${filePath}:`, err.message);
      }
    } else {
      // File is already binary
    }
  }
  console.log(`\n🎉 Successfully fixed ${fixedCount} images!`);
}

fixImages();
