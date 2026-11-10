// Regenerates every IQUM brand raster from design/brand/brand.cjs.
//   npm i --no-save sharp opentype.js   (once, anywhere on NODE_PATH)
//   node design/brand/build_brand.cjs
// Outputs: design/assets/iqum-*.svg, assets/brand/*.png, Android launcher
// mipmaps, iOS AppIcon set, store icons and the Google Play feature graphic.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const opentype = require('opentype.js');
const { C, markShapes, mark, appIcon, cardBack, svg } = require('./brand.cjs');

const root = path.join(__dirname, '..', '..');
const at = (p) => { const full = path.join(root, p); fs.mkdirSync(path.dirname(full), { recursive: true }); return full; };
const display = opentype.loadSync(path.join(root, 'assets/fonts/Baloo2-ExtraBold.ttf'));
const body = opentype.loadSync(path.join(root, 'assets/fonts/Nunito-ExtraBold.ttf'));

/** Text as outlined SVG path so no renderer needs the font installed. */
function text(font, value, x, y, size, fill, spacing = 0) {
  let cursor = x, d = '';
  for (const ch of value) {
    const glyph = font.charToGlyph(ch);
    d += glyph.getPath(cursor, y, size).toPathData(2);
    cursor += (glyph.advanceWidth / font.unitsPerEm) * size + spacing;
  }
  return { svg: `<path d="${d}" fill="${fill}"/>`, width: cursor - x - spacing };
}

function logo(color = C.ink) {
  const word = text(display, 'IQUM', 128, 92, 84, color, 2);
  return svg(Math.ceil(140 + word.width), 120, `${markShapes()}${word.svg}`, 'IQUM logosu');
}

function featureGraphic() {
  const title = text(display, 'IQUM', 430, 218, 150, C.porcelain, 4);
  const line1 = text(body, 'Kartları aç. Yolu hatırla.', 436, 290, 40, C.amberLight);
  const line2 = text(body, 'Rakibine hafızanı göster.', 436, 340, 40, C.porcelain);
  return svg(1024, 500, `
  <defs><radialGradient id="g" cx="30%" cy="35%" r="85%"><stop offset="0" stop-color="${C.petrolMid}"/><stop offset="1" stop-color="${C.petrolDeep}"/></radialGradient></defs>
  <rect width="1024" height="500" fill="url(#g)"/>
  <g transform="translate(36 66) scale(3.0)">${markShapes()}</g>
  ${title.svg}${line1.svg}${line2.svg}`, 'IQUM tanıtım grafiği');
}

(async () => {
  const sources = {
    'design/assets/iqum-mark.svg': mark(),
    'design/assets/iqum-app-icon.svg': appIcon(),
    'design/assets/iqum-logo.svg': logo(),
    'design/assets/iqum-logo-light.svg': logo(C.porcelain),
    'design/assets/iqum-card-back.svg': cardBack(),
    'design/assets/iqum-feature-graphic.svg': featureGraphic(),
  };
  for (const [file, content] of Object.entries(sources)) fs.writeFileSync(at(file), content);
  for (const stale of ['iqum-mark-light.svg', 'iqum-logo-mono.svg', 'iqum-monochrome.svg', 'iqum-app-icon-1024.png']) {
    fs.rmSync(path.join(root, 'design/assets', stale), { force: true });
  }

  const png = (source, size, file, opaque = false) => {
    let img = sharp(Buffer.from(source), { density: 300 }).resize(size[0], size[1]);
    if (opaque) img = img.removeAlpha();
    return img.png({ compressionLevel: 9 }).toFile(at(file));
  };
  await png(mark(), [256, 256], 'assets/brand/mark.png');
  await png(cardBack(), [300, 360], 'assets/brand/card-back.png', true);
  await png(appIcon(), [1024, 1024], 'assets/brand/app-icon.png', true);
  fs.rmSync(path.join(root, 'assets/brand/mark-light.png'), { force: true });

  for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
    await png(appIcon(), [size, size], `android/app/src/main/res/mipmap-${density}/ic_launcher.png`, true);
  }
  const iconSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  for (const icon of JSON.parse(fs.readFileSync(path.join(root, iconSet, 'Contents.json'))).images) {
    if (!icon.filename) continue;
    const size = Math.round(parseFloat(icon.size) * parseFloat(icon.scale));
    await png(appIcon(), [size, size], `${iconSet}/${icon.filename}`, true);
  }
  await png(appIcon(), [512, 512], 'store_assets/google-play-icon.png', true);
  await png(appIcon(), [1024, 1024], 'store_assets/app-store-icon.png', true);
  await png(featureGraphic(), [1024, 500], 'store_assets/google-play-feature-graphic.png', true);
  console.log('Brand: mark, card back, app/launcher/iOS/store icons and feature graphic regenerated.');
})().catch((e) => { console.error(e); process.exitCode = 1; });
