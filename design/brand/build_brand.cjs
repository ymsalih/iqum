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
const B = require('./brand.cjs');
const { C, markShapes, mark, appIcon, cardBack, svg } = B;

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
  const title = text(display, 'IQUM', 440, 222, 150, C.porcelain, 4);
  const line1 = text(body, 'Kartları aç. Yolu hatırla.', 446, 292, 40, C.amberLight);
  const line2 = text(body, 'Rakibine hafızanı göster.', 446, 342, 40, C.porcelain);
  return svg(1024, 500, `
  <defs><radialGradient id="g" cx="30%" cy="35%" r="85%"><stop offset="0" stop-color="${C.petrolMid}"/><stop offset="1" stop-color="${C.petrolDeep}"/></radialGradient></defs>
  <rect width="1024" height="500" fill="url(#g)"/>
  <circle cx="225" cy="262" r="190" fill="#FFFFFF" fill-opacity=".05"/>
  <g transform="translate(225 255) scale(4.1) translate(-50 -54)">${B.qGem()}</g>
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
  await png(B.splashMark(), [288, 288], 'assets/brand/owl.png');
  await png(cardBack(), [300, 360], 'assets/brand/card-back.png', true);
  await png(appIcon(), [1024, 1024], 'assets/brand/app-icon.png', true);
  fs.rmSync(path.join(root, 'assets/brand/mark-light.png'), { force: true });

  // Android: legacy square icon (API < 26) plus adaptive layers (API 26+),
  // so launchers mask a full-bleed icon instead of shrinking it into a plate.
  const res = 'android/app/src/main/res';
  for (const [density, scale] of Object.entries({ mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 })) {
    await png(B.legacyIcon(), [48 * scale, 48 * scale], `${res}/mipmap-${density}/ic_launcher.png`);
    for (const [name, source] of [['ic_launcher_background', B.adaptiveBackground()], ['ic_launcher_foreground', B.adaptiveForeground()], ['ic_launcher_monochrome', B.adaptiveMonochrome()]]) {
      await png(source, [108 * scale, 108 * scale], `${res}/mipmap-${density}/${name}.png`, name === 'ic_launcher_background');
    }
    await png(B.splashMark(), [120 * scale, 120 * scale], `${res}/drawable-${density}/splash_mark.png`);
  }
  const adaptive = `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
`;
  fs.writeFileSync(at(`${res}/mipmap-anydpi-v26/ic_launcher.xml`), adaptive);
  // iOS launch image (centred on petrol by LaunchScreen.storyboard).
  const launch = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
  for (const [suffix, scale] of [['', 1], ['@2x', 2], ['@3x', 3]]) {
    await png(B.splashMark(), [120 * scale, 120 * scale], `${launch}/LaunchImage${suffix}.png`);
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

  // Web brand kit: logo files for the website and anything outside the app.
  const kit = 'store_assets/brand-kit';
  const kitFiles = {
    'iqum-logo.svg': logo(),
    'iqum-logo-light.svg': logo(C.porcelain),
    'iqum-mark.svg': mark(),
    'iqum-owl.svg': B.splashMark(),
    'iqum-app-icon.svg': appIcon(),
  };
  for (const [file, content] of Object.entries(kitFiles)) fs.writeFileSync(at(`${kit}/${file}`), content);
  const logoWidth = (source) => Number(/viewBox="0 0 ([\d.]+) /.exec(source)[1]);
  const wide = logo();
  await png(wide, [1200, Math.round(1200 * 120 / logoWidth(wide))], `${kit}/iqum-logo.png`);
  await png(logo(C.porcelain), [1200, Math.round(1200 * 120 / logoWidth(wide))], `${kit}/iqum-logo-light.png`);
  await png(mark(), [512, 512], `${kit}/iqum-mark-512.png`);
  await png(B.splashMark(), [512, 512], `${kit}/iqum-owl-512.png`);
  await png(appIcon(), [180, 180], `${kit}/apple-touch-icon.png`, true);
  for (const size of [16, 32, 48, 192, 512]) await png(mark(), [size, size], `${kit}/favicon-${size}.png`);

  console.log('Brand: mark, owl, card back, app/adaptive/iOS/store icons, splash images and feature graphic regenerated.');
})().catch((e) => { console.error(e); process.exitCode = 1; });
