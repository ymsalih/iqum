const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const { animals } = require('../design/animals.cjs');
const root = path.join(__dirname, '..');

(async () => {
  const layers = [];
  for (const [i, [key, [label]]] of Object.entries(animals).entries()) {
    const x = 28 + i % 4 * 280, y = 28 + Math.floor(i / 4) * 258;
    const frame = `<svg xmlns="http://www.w3.org/2000/svg" width="264" height="238"><rect width="264" height="238" rx="16" fill="#E6DECE"/><text x="22" y="31" font-family="Segoe UI,Arial" font-size="18" fill="#342F2C">${label}</text><rect x="16" y="49" width="146" height="170" rx="9" fill="#F4F0E6"/><rect x="181" y="111" width="64" height="80" rx="6" fill="#DDE3CC"/><text x="213" y="212" text-anchor="middle" font-family="Segoe UI,Arial" font-size="12" fill="#6E685D">40 px</text></svg>`;
    layers.push({ input: Buffer.from(frame), left: x, top: y });
    for (const [size, dx, dy] of [[136, 22, 66], [40, 193, 130]]) {
      layers.push({ input: await sharp(path.join(root, 'assets/art', `${key}.png`)).resize(size, size).png().toBuffer(), left: x + dx, top: y + dy });
    }
  }
  const folder = path.join(root, 'output/artwork');
  fs.mkdirSync(folder, { recursive: true });
  await sharp({ create: { width: 1160, height: 810, channels: 3, background: '#F4F0E6' } }).composite(layers).png().toFile(path.join(folder, 'animals-overview.png'));
  console.log('Rendered 12 animals at large size and 40 px card size.');
})().catch(error => { console.error(error); process.exitCode = 1; });
