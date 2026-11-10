// IQUM brand geometry (original artwork). One source of truth for the mark,
// app icon (iOS + Android adaptive layers), card back, wordmark logo, splash
// and store feature graphic.
'use strict';

const C = Object.freeze({
  ink: '#10302B',
  petrol: '#145249',
  petrolDeep: '#0B2E2A',
  petrolMid: '#1B6B5E',
  petrolGlow: '#23806F',
  porcelain: '#FFFBF3',
  porcelainShade: '#E9DFCC',
  amber: '#F2A93B',
  amberLight: '#FFD58A',
  amberDeep: '#B9741A',
  amberShadow: '#8A5410',
});

/**
 * "Bilge", the IQUM owl: the keeper of memories. A geometric amber head on a
 * solid lip, porcelain face discs and big petrol eyes with bright glints.
 * One eye winks: "I remember". Drawn in a 100×100 box, optically centred.
 * `mono` draws a flat silhouette with cut-out eyes (Android 13 themed icon).
 */
const HEAD = 'M19 15C27 22 35 26 50 26C65 26 73 22 81 15C87 28 89 41 89 55C89 76 72 90 50 90C28 90 11 76 11 55C11 41 13 28 19 15Z';
function qGem({ mono = null, lip = true } = {}) {
  if (mono) {
    return `<defs><mask id="eyes"><rect width="100" height="100" fill="#fff"/>
      <circle cx="34" cy="53" r="13" fill="#000"/><path d="M57 54Q66 46 75 54" stroke="#000" stroke-width="6" stroke-linecap="round" fill="none"/>
      <path d="M50 61l5 6-5 7-5-7z" fill="#000"/></mask></defs>
    <path d="${HEAD}" fill="${mono}" mask="url(#eyes)"/>`;
  }
  const d = 5; // lip depth
  return `
  <g stroke-linecap="round" stroke-linejoin="round">
    ${lip ? `<path d="${HEAD}" fill="${C.amberShadow}" transform="translate(0 ${d})"/>` : ''}
    <path d="${HEAD}" fill="${C.amber}"/>
    <path d="M17 50C17 36 20 27 22 22" fill="none" stroke="${C.amberLight}" stroke-width="3.6"/>
    <path d="M13 51C13 33 31 29 50 39C69 29 87 33 87 51C87 68 70 74 50 79C30 74 13 68 13 51Z" fill="${C.amberLight}"/>
    <path d="M39 83.5l4 3.2 4-3.2M53 83.5l4 3.2 4-3.2" fill="none" stroke="${C.amberDeep}" stroke-width="2.6"/>
    <circle cx="34" cy="53" r="17.5" fill="${C.porcelain}"/>
    <circle cx="66" cy="53" r="17.5" fill="${C.porcelain}"/>
    <path d="M50 44C47 47 47 59 50 62C53 59 53 47 50 44Z" fill="${C.porcelainShade}"/>
    <circle cx="34" cy="53" r="11.5" fill="${C.petrolMid}"/>
    <circle cx="34" cy="53" r="7.5" fill="${C.petrolDeep}"/>
    <circle cx="38" cy="48.5" r="3.4" fill="${C.porcelain}"/>
    <circle cx="30.5" cy="57" r="1.6" fill="${C.porcelain}"/>
    <path d="M57 54Q66 45 75 54" fill="none" stroke="${C.petrolDeep}" stroke-width="5"/>
    <path d="M50 61l5.5 6.5-5.5 7.5-5.5-7.5z" fill="${C.amberDeep}"/>
    <path d="M50 61l5.5 6.5H44.5z" fill="${C.amberLight}" opacity=".55"/>
    <path d="M27 33Q34 29 42 33M58 33Q66 29 73 33" fill="none" stroke="${C.amberDeep}" stroke-width="3.4"/>
  </g>`;
}

const svg = (w, h, body, label) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" role="img" aria-label="${label}">${body}</svg>`;

const felt = (id) => `
  <radialGradient id="${id}" cx="34%" cy="26%" r="88%">
    <stop offset="0" stop-color="${C.petrolGlow}"/>
    <stop offset=".55" stop-color="${C.petrol}"/>
    <stop offset="1" stop-color="${C.petrolDeep}"/>
  </radialGradient>`;

/** Full-bleed felt background (iOS icon, Android background layer). */
function feltLayer(size) {
  return `<defs>${felt('felt')}</defs>
  <rect width="${size}" height="${size}" fill="url(#felt)"/>
  <circle cx="${size * .47}" cy="${size * .46}" r="${size * .43}" fill="none" stroke="#FFFFFF" stroke-opacity=".05" stroke-width="${size * .02}"/>`;
}

/** iOS / store icon: opaque, square, full bleed (the OS applies the mask). */
function appIcon() {
  return svg(1024, 1024, `${feltLayer(1024)}
  <g transform="translate(512 512) scale(7.6) translate(-50 -54)">${qGem()}</g>`, 'IQUM uygulama simgesi');
}

/** Android adaptive layers on the 108 dp canvas (safe zone: 66 dp circle). */
function adaptiveBackground() {
  return svg(432, 432, feltLayer(432), 'IQUM simge zemini');
}
function adaptiveForeground() {
  return svg(432, 432, `<g transform="translate(216 216) scale(2.75) translate(-50 -54)">${qGem()}</g>`, 'IQUM simge önyüzü');
}
function adaptiveMonochrome() {
  return svg(432, 432, `<g transform="translate(216 216) scale(2.75) translate(-50 -54)">${qGem({ mono: '#FFFFFF' })}</g>`, 'IQUM tek renk simge');
}
/** Legacy (pre-Android 8) launcher icon: rounded square that fills its cell. */
function legacyIcon() {
  return svg(192, 192, `<defs>${felt('felt')}<clipPath id="r"><rect width="192" height="192" rx="42"/></clipPath></defs>
  <g clip-path="url(#r)"><rect width="192" height="192" fill="url(#felt)"/></g>
  <g transform="translate(96 98) scale(1.5) translate(-50 -54)">${qGem()}</g>`, 'IQUM simgesi');
}

/** In-app mark: the icon as a small raised felt tile with its own lip. */
function markShapes() {
  return `<defs>${felt('mfelt')}</defs>
  <rect x="6" y="11" width="108" height="104" rx="30" fill="${C.petrolDeep}"/>
  <rect x="6" y="5" width="108" height="104" rx="30" fill="url(#mfelt)"/>
  <g transform="translate(60 57) scale(1.06) translate(-50 -54)">${qGem()}</g>`;
}
const mark = () => svg(120, 120, markShapes(), 'IQUM simgesi');

/** Splash centre image (transparent; sits on petrol). */
function splashMark() {
  return svg(288, 288, `<g transform="translate(144 144) scale(2.2) translate(-50 -54)">${qGem()}</g>`, 'IQUM');
}

/** Card back used by every face-down game card (porcelain-safe at 40–90 px). */
function cardBack() {
  const w = 300, h = 360;
  let dots = '';
  for (let y = 18; y < h; y += 28) {
    for (let x = (y / 28) % 2 ? 32 : 18; x < w; x += 28) dots += `<path d="M${x} ${y - 4}l4 4-4 4-4-4z"/>`;
  }
  return svg(w, h, `<defs>${felt('cb')}</defs>
  <rect width="${w}" height="${h}" fill="url(#cb)"/>
  <g fill="#FFFFFF" fill-opacity=".07">${dots}</g>
  <rect x="15" y="15" width="${w - 30}" height="${h - 30}" rx="20" fill="none" stroke="${C.amber}" stroke-opacity=".7" stroke-width="5"/>
  <rect x="27" y="27" width="${w - 54}" height="${h - 54}" rx="12" fill="none" stroke="${C.amberLight}" stroke-opacity=".25" stroke-width="2"/>
  <circle cx="150" cy="184" r="78" fill="${C.petrolDeep}"/>
  <circle cx="150" cy="180" r="78" fill="${C.petrol}"/>
  <circle cx="150" cy="180" r="78" fill="none" stroke="${C.amber}" stroke-width="6"/>
  <circle cx="150" cy="180" r="66" fill="none" stroke="${C.amberLight}" stroke-opacity=".35" stroke-width="2"/>
  <g transform="translate(150 182) scale(1.3) translate(-50 -54)">${qGem()}</g>`, 'IQUM kart sırtı');
}

module.exports = {
  C, qGem, markShapes, mark, appIcon, adaptiveBackground, adaptiveForeground,
  adaptiveMonochrome, legacyIcon, splashMark, cardBack, svg,
};
