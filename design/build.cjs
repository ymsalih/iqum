const fs = require('node:fs');
const path = require('node:path');
const base = __dirname;
const assetsDir = path.join(base, 'assets');
// Original vector game artwork. Static artwork can be raster-cached in Flutter.
const { animals, line } = require('./animals.cjs');
for (const [key, [label, shape]] of Object.entries(animals)) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img" aria-label="${label}"><g stroke="${line}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round">${shape}</g></svg>`;
  fs.writeFileSync(path.join(assetsDir, `${key}.svg`), svg);
}
const artwork = {};
for (const name of fs.readdirSync(assetsDir).filter(name => name.endsWith('.svg'))) {
  artwork[name.replace('.svg', '')] = `data:image/svg+xml;base64,${fs.readFileSync(path.join(assetsDir, name)).toString('base64')}`;
}
const source = fs.readFileSync(path.join(base, 'preview.source.html'), 'utf8');
const fragment = source.replace('const IQUM_ASSETS = {};', `const IQUM_ASSETS = ${JSON.stringify(artwork)};`);
fs.writeFileSync(path.join(base, 'iqum-preview.html'), fragment);
const shell = fs.readFileSync(path.join(base, 'shell.css'), 'utf8');
fs.writeFileSync(path.join(base, 'index.html'), `<!doctype html>\n<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>IQUM · Tasarım önizlemesi</title><style>${shell}</style></head><body>${fragment}</body></html>`);
console.log('Built design/iqum-preview.html and design/index.html; '+Object.keys(animals).length+' original animal artworks.');
