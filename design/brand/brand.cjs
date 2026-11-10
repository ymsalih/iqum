// IQUM brand geometry (original artwork). One source of truth for the mark,
// app icon, card back, wordmark logo and store feature graphic.
'use strict';

const C = Object.freeze({
  ink: '#10302B',
  petrol: '#145249',
  petrolDeep: '#0B2E2A',
  petrolMid: '#1B6B5E',
  porcelain: '#FFFBF3',
  porcelainShade: '#E9DFCC',
  amber: '#F2A93B',
  amberLight: '#FFD58A',
  amberDeep: '#B9741A',
  coral: '#E8664F',
});

/**
 * The mark: a face-down amber card behind a porcelain card that is mid-flip.
 * The front card carries a "Q" drawn as an eye (ring + pupil) with an amber
 * tail that breaks out of the card edge. Bold outlines keep it legible at 24 px.
 * Drawn in a 120×120 box.
 */
function markShapes({ outline = C.ink } = {}) {
  return `
  <g stroke-linejoin="round">
    <g transform="rotate(-14 46 62)">
      <rect x="16" y="27" width="60" height="78" rx="13" fill="${C.amberDeep}" stroke="${outline}" stroke-width="4"/>
      <rect x="16" y="21" width="60" height="78" rx="13" fill="${C.amber}" stroke="${outline}" stroke-width="4"/>
      <rect x="24" y="29" width="44" height="62" rx="7" fill="none" stroke="${C.amberLight}" stroke-width="3"/>
      <path d="M46 46l8 14-8 14-8-14z" fill="${C.amberLight}"/>
    </g>
    <g transform="rotate(9 72 62)">
      <rect x="42" y="25" width="62" height="82" rx="14" fill="${C.porcelainShade}" stroke="${outline}" stroke-width="4"/>
      <rect x="42" y="19" width="62" height="82" rx="14" fill="${C.porcelain}" stroke="${outline}" stroke-width="4"/>
    </g>
    <circle cx="73" cy="58" r="17.5" fill="none" stroke="${C.petrol}" stroke-width="10"/>
    <circle cx="76.5" cy="54.5" r="6.5" fill="${C.petrol}"/>
    <path d="M82 67q8 6 11 17" fill="none" stroke="${outline}" stroke-width="14" stroke-linecap="round"/>
    <path d="M82 67q8 6 11 17" fill="none" stroke="${C.amber}" stroke-width="7" stroke-linecap="round"/>
  </g>`;
}

const svg = (w, h, body, label) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" role="img" aria-label="${label}">${body}</svg>`;

const mark = () => svg(120, 120, markShapes(), 'IQUM simgesi');

function appIcon() {
  return svg(1024, 1024, `
  <defs>
    <radialGradient id="bg" cx="38%" cy="30%" r="80%">
      <stop offset="0" stop-color="${C.petrolMid}"/>
      <stop offset="1" stop-color="${C.petrolDeep}"/>
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <g fill="none" stroke="#FFFFFF" stroke-opacity=".06" stroke-width="6">
    <path d="M-40 760 L520 200 L1080 760"/><path d="M-40 900 L520 340 L1080 900"/>
  </g>
  <g transform="translate(112 118) scale(6.6)">${markShapes()}</g>`, 'IQUM uygulama simgesi');
}

/** Card back used by every face-down game card (porcelain-safe at 40–90 px). */
function cardBack() {
  const w = 300, h = 360;
  let dots = '';
  for (let y = 18; y < h; y += 28) {
    for (let x = (y / 28) % 2 ? 32 : 18; x < w; x += 28) dots += `<path d="M${x} ${y - 5}l5 5-5 5-5-5z"/>`;
  }
  return svg(w, h, `
  <rect width="${w}" height="${h}" fill="${C.petrol}"/>
  <g fill="${C.petrolMid}">${dots}</g>
  <rect x="16" y="16" width="${w - 32}" height="${h - 32}" rx="18" fill="none" stroke="${C.amber}" stroke-opacity=".55" stroke-width="5"/>
  <circle cx="150" cy="180" r="66" fill="${C.petrolDeep}"/>
  <circle cx="150" cy="180" r="66" fill="none" stroke="${C.amber}" stroke-width="7"/>
  <circle cx="146" cy="174" r="27" fill="none" stroke="${C.porcelain}" stroke-width="15"/>
  <circle cx="151" cy="169" r="10" fill="${C.porcelain}"/>
  <path d="M163 191q12 9 16 25" fill="none" stroke="${C.amber}" stroke-width="13" stroke-linecap="round"/>`, 'IQUM kart sırtı');
}

module.exports = { C, markShapes, mark, appIcon, cardBack, svg };
