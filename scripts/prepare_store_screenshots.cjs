// Makes the store screenshots upload-ready: opaque PNG (no alpha channel),
// exact store sizes. Run after the screenshot test:
//   IQUM_STORE_SHOTS=store_assets/screenshots flutter test test/store_screenshots_test.dart
//   node scripts/prepare_store_screenshots.cjs      (needs `sharp`)
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');

sharp.cache(false); // Windows: do not keep the files being rewritten open.

const root = path.join(__dirname, '..', 'store_assets', 'screenshots');
const sizes = {
  'android-phone': [1080, 1920], // Google Play phone
  'ios-iphone-6.9': [1320, 2868], // App Store iPhone 6.9"
  'ios-ipad-13': [2064, 2752], // App Store iPad 13"
};

(async () => {
  let count = 0;
  for (const [device, [w, h]] of Object.entries(sizes)) {
    const dir = path.join(root, device);
    if (!fs.existsSync(dir)) throw new Error(`Missing ${dir}; run the screenshot test first.`);
    for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.png')).sort()) {
      const full = path.join(dir, file);
      const meta = await sharp(full).metadata();
      if (meta.width !== w || meta.height !== h) {
        throw new Error(`${device}/${file} is ${meta.width}×${meta.height}, expected ${w}×${h}`);
      }
      const flat = await sharp(fs.readFileSync(full)).flatten({ background: '#F6F0E4' }).removeAlpha()
        .png({ compressionLevel: 9 }).toBuffer();
      fs.writeFileSync(full, flat);
      count++;
    }
  }
  console.log(`Store screenshots ready: ${count} opaque PNGs.`);
})().catch((e) => { console.error(e.message); process.exitCode = 1; });
