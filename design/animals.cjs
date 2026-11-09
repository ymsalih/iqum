// Original IQUM animal artwork. Large silhouettes and natural colours remain
// distinct at 32–56 logical pixels. No fonts, filters or external resources.
const line = '#342F2C';
const eye = (x, y, r = 4) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${line}" stroke="none"/><circle cx="${x + 1}" cy="${y - 1.2}" r="1.25" fill="#FFFCF3" stroke="none"/>`;
const animals = {
  kus: ['Kuş', `
    <path d="M42 78 12 87l13-24 24 1" fill="#226781"/>
    <path d="m60 96-3 13m18-12 3 12m-28 1h15m7 0h15" fill="none" stroke="#8C592D" stroke-width="3.5"/>
    <path d="M30 66c0-19 15-27 34-25 2-15 11-24 25-24 17 0 27 12 26 27-1 9-6 16-14 20-1 24-15 36-38 36-20 0-33-13-33-34Z" fill="#48A3B5"/>
    <path d="M69 50c-7 6-13 14-13 27 0 15 13 23 28 17 11-5 17-17 17-30-13 0-22-3-32-14Z" fill="#F1B36F" stroke="none"/>
    <path d="M34 61c9-8 28-7 39 3-4 18-16 23-31 16Z" fill="#277A95"/>
    <path d="m112 39 11 8-13 4" fill="#EAB54A"/>
    ${eye(98, 36, 4.5)}
    <path d="m43 69 15 1" fill="none" stroke="#76BBC6"/>
  `],
  tavsan: ['Tavşan', `
    <ellipse cx="41" cy="35" rx="11" ry="28" transform="rotate(-13 41 35)" fill="#DFE2DD"/>
    <ellipse cx="71" cy="32" rx="10" ry="27" transform="rotate(7 71 32)" fill="#DFE2DD"/>
    <path d="m40 16 5 35m28-35-3 33" fill="none" stroke="#DEA1A0" stroke-width="7"/>
    <circle cx="102" cy="91" r="12" fill="#FFFCF3"/>
    <ellipse cx="69" cy="86" rx="30" ry="27" fill="#CCD2CD"/>
    <ellipse cx="57" cy="66" rx="32" ry="28" fill="#E7E9E0"/>
    <ellipse cx="56" cy="79" rx="18" ry="11" fill="#FFFCF3" stroke="none"/>
    ${eye(43, 63)}${eye(68, 63)}
    <path d="m51 74 10 0-5 5Z" fill="#D08889" stroke-width="1.8"/>
    <path d="M56 80v5m-7-1q7 6 14 0" fill="none" stroke-width="1.8"/>
    <ellipse cx="42" cy="110" rx="17" ry="6" fill="#E7E9E0"/>
    <ellipse cx="81" cy="110" rx="19" ry="6" fill="#E7E9E0"/>
  `],
  balik: ['Balık', `
    <path d="M37 64 12 39c-7 13-7 37 0 50Z" fill="#DC793E"/>
    <path d="M49 40c7-14 19-18 32-14L75 47m-20 39 17 17 12-19" fill="#EAA74C"/>
    <path d="M30 65c15-31 66-36 88 0-20 35-70 31-88 0Z" fill="#F4B44F"/>
    <path d="M39 66c7 15 26 23 43 18-17-2-31-11-36-22Z" fill="#E58D3E" stroke="none"/>
    <path d="M78 48q-12 17 0 34" fill="none" stroke="#B56536"/>
    <path d="m58 60 13 7-13 9Z" fill="#E88C40" stroke="#B56536"/>
    <circle cx="96" cy="58" r="9" fill="#FFFCF3" stroke="none"/>
    ${eye(98, 58, 4.5)}
    <path d="m111 71 6-3M14 51l13 13-13 13" fill="none" stroke="#B56536" stroke-width="2"/>
  `],
  kelebek: ['Kelebek', `
    <path d="M59 62C43 15 10 14 9 42 7 63 31 70 54 69c-39-3-38 30-22 38 15 7 25-12 29-31Z" fill="#956DB4"/>
    <path d="M69 62c16-47 49-48 50-20 2 21-22 28-45 27 39-3 38 30 22 38-15 7-25-12-29-31Z" fill="#956DB4"/>
    <path d="M51 57C37 32 21 30 19 44c0 12 13 16 32 13Zm26 0c14-25 30-27 32-13 0 12-13 16-32 13Z" fill="#E6B76C" stroke="none"/>
    <path d="M52 79c-17-7-24 8-16 15 7 6 15-2 16-15Zm24 0c17-7 24 8 16 15-7 6-15-2-16-15Z" fill="#78B3AF" stroke="none"/>
    <path d="m60 42-9-16m17 16 9-16" fill="none" stroke-width="3"/>
    <circle cx="50" cy="24" r="3.5" fill="#342F2C" stroke="none"/><circle cx="78" cy="24" r="3.5" fill="#342F2C" stroke="none"/>
    <rect x="59" y="43" width="10" height="48" rx="5" fill="#554238"/>
    <circle cx="64" cy="44" r="8" fill="#554238"/>
    <path d="M61 62h6m-6 10h6m-6 10h6" stroke="#B7A48A" stroke-width="2"/>
  `],
  kaplumbaga: ['Kaplumbağa', `
    <path d="m30 80-10 18c4 6 12 6 16 1l7-15m25-1 6 16c5 4 13 2 15-3l-9-16" fill="#7DA764"/>
    <path d="m17 71-10 8 18 1" fill="#8FB774"/>
    <path d="M82 71c8-9 11-24 22-23 14 0 20 10 16 22-3 12-17 16-27 12L78 84" fill="#A6C881"/>
    <path d="M19 76c0-31 17-47 37-47 23 0 38 21 38 47-16 15-57 15-75 0Z" fill="#477B55"/>
    <path d="m43 42 23-1 14 18-11 19-25-1-13-19Z" fill="#6C9B65"/>
    <path d="m43 42-4-8m27 7 6-7m8 25 12-3m-23 22 7 7m-32-8-6 8M31 58l-10-2" fill="none" stroke="#C0CB83" stroke-width="2"/>
    <path d="M20 76q37 18 73 0" fill="none" stroke="#D2D699" stroke-width="4"/>
    ${eye(108, 59, 4)}
    <path d="m111 73 6-2" fill="none" stroke-width="1.8"/>
  `],
  kedi: ['Kedi', `
    <path d="M44 102C9 107 8 78 14 65c4-8 13-5 11 3-8 21 4 23 21 19" fill="#D6A86C"/>
    <ellipse cx="68" cy="91" rx="25" ry="24" fill="#D6A86C"/>
    <ellipse cx="68" cy="96" rx="12" ry="18" fill="#F4DBB0" stroke="none"/>
    <path d="M38 52 35 19l24 14c7-2 12-2 19 0l24-14-3 34c13 28-4 42-30 42-28 0-44-17-31-43Z" fill="#E5BC83"/>
    <path d="m42 30 2 18 12-10m38-8-2 18-12-10" fill="#D89F9A" stroke="none"/>
    <path d="M62 34v11m12-11-1 11M39 58l10 2m49-2-10 2" fill="none" stroke="#A16D43" stroke-width="3.5"/>
    ${eye(54, 60, 4.5)}${eye(84, 60, 4.5)}
    <ellipse cx="68" cy="75" rx="16" ry="10" fill="#FFF0D3" stroke="none"/>
    <path d="m64 70 9 0-5 5Z" fill="#B97471" stroke-width="1.5"/>
    <path d="M68 75v4m-7 0q7 7 14 0M49 73l-17-3m18 9-17 2m55-8 17-3m-18 9 17 2" fill="none" stroke-width="1.7"/>
    <path d="M49 108v7h17v-9m8 0v9h16v-7" fill="#E5BC83"/>
  `],
  tilki: ['Tilki', `
    <path d="M66 100C35 116 10 95 15 59c10 14 29 14 30 31l21-6Z" fill="#D66D36"/>
    <path d="M15 59c1 17 6 28 16 33l8-11C29 73 22 72 15 59Z" fill="#FFF0D3"/>
    <path d="M53 75c-8 17-9 29-4 40h40c7-17 5-32-3-43Z" fill="#DA783C"/>
    <path d="m51 103-1 12h13l3-13m12 0 1 13h12l-1-13" fill="#6D4936"/>
    <path d="m39 49-2-34 25 18c5-1 10-1 16 0l24-19-2 35c10 16 4 26-30 43-32-17-42-28-31-43Z" fill="#E98C42"/>
    <path d="m45 29 1 19 12-11m35-8-1 19-12-11" fill="#694A3E" stroke="none"/>
    <path d="M39 55c3 17 15 26 31 36 16-10 27-19 30-36L80 65 70 79 59 65Z" fill="#FFF0D3" stroke="none"/>
    ${eye(54, 54, 3.7)}${eye(85, 54, 3.7)}
    <path d="m63 76 14 0-7 8Z" fill="#342F2C" stroke-width="1.5"/>
  `],
  fil: ['Fil', `
    <path d="M31 48c-16-8-23 4-22 17" fill="none" stroke="#718F99" stroke-width="6"/>
    <path d="M23 65c0-25 17-37 43-37 28 0 41 18 38 42l-7 29H83l-3-14H51l-3 14H32Z" fill="#94AEB6"/>
    <path d="m32 91-1 18h17l4-20m27 0 3 20h16l-1-20" fill="#94AEB6"/>
    <path d="M81 33c24-2 35 11 33 31l-3 28c0 7 3 8 9 5 0 14-16 20-24 9-6-8-3-23-3-32L79 63Z" fill="#A6BDC2"/>
    <path d="M79 36c-24-10-37 8-31 29 3 13 16 16 29 7Z" fill="#7D9DA7"/>
    <path d="M72 44c-12-2-20 6-16 17 2 6 6 8 13 8" fill="none" stroke="#AAC4C9" stroke-width="3"/>
    <path d="M97 70c-5 11-11 13-14 5" fill="#FFF0D3" stroke-width="2"/>
    ${eye(101, 51, 3.7)}
    <path d="M102 85h7m-8 8h8M36 105h8m42 0h8" fill="none" stroke="#647F89" stroke-width="2"/>
  `],
  at: ['At', `
    <path d="M36 56C12 37 7 63 14 85c6-16 14-15 23-17" fill="#5E4032"/>
    <path d="M30 59h41l7-28 18-8 6 14 16 18c0 9-6 14-13 12L91 57l-6 22 11 31H82L69 83H48l-8 27H26l9-36Z" fill="#B78254"/>
    <path d="m81 30 1-18 10 12m1 2 8-14 2 22" fill="#B78254"/>
    <path d="M80 28C67 28 67 47 62 55l13 4 10-30Z" fill="#5E4032"/>
    <path d="m90 34 8 2 2 10-6-2Z" fill="#F5E4C8" stroke="none"/>
    <path d="m101 49 16 6c0 8-7 12-13 10l-6-7Z" fill="#D7B08A" stroke="none"/>
    ${eye(99, 39, 3)}
    <circle cx="111" cy="56" r="2" fill="#5E4032" stroke="none"/>
    <path d="M27 103h15v8H26Zm54 0h13l3 8H82Z" fill="#5E4032" stroke-width="2"/>
    <path d="M42 66h22" fill="none" stroke="#D5A878" stroke-width="3"/>
  `],
  baykus: ['Baykuş', `
    <path d="m44 107-4 9m17-8 1 9m16-9-1 9m15-10 4 9" fill="none" stroke="#A46E35" stroke-width="3.5"/>
    <path d="m29 45-2-28 26 13h23l26-13-2 28c19 30 5 66-35 67-40-1-54-34-36-67Z" fill="#936843"/>
    <path d="M32 66c-5 22 4 34 17 40L46 70m50-4c5 22-4 34-17 40l3-36" fill="#6E503B"/>
    <path d="M40 76c3 20 10 29 25 29 16 0 23-10 26-29Z" fill="#D6AE76" stroke="none"/>
    <ellipse cx="46" cy="55" rx="22" ry="25" fill="#F3E2BA"/>
    <ellipse cx="84" cy="55" rx="22" ry="25" fill="#F3E2BA"/>
    <circle cx="47" cy="55" r="11" fill="#DCA94B" stroke="none"/><circle cx="83" cy="55" r="11" fill="#DCA94B" stroke="none"/>
    ${eye(47, 55, 7)}${eye(83, 55, 7)}
    <path d="m58 72 14 0-7 12Z" fill="#D89838" stroke-width="2"/>
    <path d="m51 91 5 5 5-5m8 0 5 5 5-5" fill="none" stroke="#9D784B" stroke-width="2"/>
  `],
  salyangoz: ['Salyangoz', `
    <path d="m94 65-2-26m12 29 10-24" fill="none" stroke="#A08246" stroke-width="4"/>
    <circle cx="92" cy="35" r="6" fill="#C7B879"/><circle cx="116" cy="41" r="6" fill="#C7B879"/>
    ${eye(93, 35, 2.3)}${eye(117, 41, 2.3)}
    <path d="M16 91h64c7-5 8-14 10-23 2-8 14-8 18 0 4 11 3 19 11 25 5 5 1 13-8 13H26c-17 0-21-9-10-15Z" fill="#CDBD7A"/>
    <path d="M16 99h94" fill="none" stroke="#A58D51" stroke-width="2.5"/>
    <circle cx="52" cy="64" r="33" fill="#B77C4E"/>
    <path d="M29 77C12 45 55 23 72 48c19 29-22 49-31 24-6-17 18-27 21-10 2 8-9 12-12 6" fill="none" stroke="#F0D5A1" stroke-width="5.5"/>
    <path d="m100 80 6 1" fill="none" stroke="#735F37" stroke-width="2"/>
  `],
  denizati: ['Denizatı', `
    <path d="m57 35-17 3 10 12-13 9 14 8-12 11 15 6" fill="#D4AA6C"/>
    <path d="m76 14-7-7-8 13c-16 5-21 21-14 35l8 10c5 8 4 12 12 20 7 9 6 18-3 22-9 4-17-2-17-8 0-5 6-7 10-3 3-12-13-17-20-7-12 18 10 38 30 29 18-7 23-23 13-39-7-12-9-17-3-28l25 1 9-12-21-11c0-12-5-18-14-17Z" fill="#62A9A5"/>
    <path d="M67 53c-6 9-2 21 6 31 11 16 9 27-7 34" fill="none" stroke="#386F74" stroke-width="3"/>
    <path d="m52 58 12 3m-10 7 10 2m-6 7 10 2" fill="none" stroke="#D1DFC1" stroke-width="3"/>
    <path d="m79 54 14 9-15 10" fill="#D4AA6C"/>
    <path d="m99 36 8 4-4 6h-8" fill="#91C4B5" stroke-width="2"/>
    ${eye(77, 31, 4.5)}
  `],
};

module.exports = { animals, line };
