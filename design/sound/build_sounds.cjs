// Synthesises IQUM's three short UI cues (original, no samples):
//   flip    – papery card snap (filtered noise + falling tick)
//   success – three-note bell arpeggio
//   error   – soft descending wooden "bonk"
//   node design/sound/build_sounds.cjs
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const RATE = 22050;
let seed = 7;
const noise = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x3fffffff - 1; };

function write(name, samples) {
  const peak = Math.max(...samples.map(Math.abs)) || 1;
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((v, i) => data.writeInt16LE(Math.round((v / peak) * 0.6 * 32767), i * 2));
  const h = Buffer.alloc(44);
  h.write('RIFF'); h.writeUInt32LE(36 + data.length, 4); h.write('WAVEfmt ', 8); h.writeUInt32LE(16, 16);
  h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(RATE, 24); h.writeUInt32LE(RATE * 2, 28);
  h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34); h.write('data', 36); h.writeUInt32LE(data.length, 40);
  fs.writeFileSync(path.join(__dirname, '..', '..', 'assets', 'sounds', `${name}.wav`), Buffer.concat([h, data]));
}

const env = (t, attack, decay) => (t < attack ? t / attack : Math.exp(-(t - attack) * decay));

function flip() {
  const n = Math.floor(RATE * 0.11), out = new Array(n).fill(0);
  let lp = 0, phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    lp += 0.35 * (noise() - lp); // soft low-pass: paper, not hiss
    const freq = 1500 * Math.exp(-t * 28) + 380;
    phase += (2 * Math.PI * freq) / RATE;
    out[i] = lp * env(t, 0.002, 55) * 0.9 + Math.sin(phase) * env(t, 0.001, 70) * 0.35;
  }
  return out;
}

function bell(out, start, f, gain) {
  const partials = [[1, 1, 7], [2.76, 0.32, 11], [5.4, 0.12, 18], [2, 0.18, 9]];
  for (let i = Math.floor(start * RATE); i < out.length; i++) {
    const t = i / RATE - start;
    for (const [m, g, d] of partials) out[i] += Math.sin(2 * Math.PI * f * m * t) * g * gain * env(t, 0.003, d);
  }
}

function success() {
  const out = new Array(Math.floor(RATE * 0.55)).fill(0);
  bell(out, 0, 784, 0.8); bell(out, 0.07, 988, 0.85); bell(out, 0.14, 1319, 1);
  return out;
}

function error() {
  const out = new Array(Math.floor(RATE * 0.32)).fill(0);
  for (const [start, f] of [[0, 196], [0.11, 147]]) {
    for (let i = Math.floor(start * RATE); i < out.length; i++) {
      const t = i / RATE - start;
      const s = Math.sin(2 * Math.PI * f * t) + Math.sin(2 * Math.PI * f * 3 * t) / 6 + Math.sin(2 * Math.PI * f * 2.02 * t) / 5;
      out[i] += s * env(t, 0.004, 22) * 0.8;
    }
  }
  return out;
}

write('flip', flip());
write('success', success());
write('error', error());
console.log('Sounds: flip, success, error regenerated in assets/sounds.');
