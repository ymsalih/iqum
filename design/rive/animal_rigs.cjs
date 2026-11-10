// Rigs for IQUM's 12 original animals. Element indices refer to the paint-order
// list of shapes in design/animals.cjs; "i.s" selects sub-path s of element i.
// Pivots are in the 128×128 artwork space. Each animal gets two short one-shot
// animations: `reveal` (card opens) and `celebrate` (pair found / correct answer).
// Frames are at 60 fps. Values are offsets from the rest pose (x/y/rotation)
// or absolute scale. Nothing loops; the Flutter side stops the controller.
'use strict';

const wag = (from, amp, beats, step = 6) => {
  const keys = [[from, 0]];
  for (let b = 0; b < beats; b++) keys.push([from + step * (b + 1), b % 2 ? amp * 0.7 : -amp]);
  keys.push([from + step * (beats + 1), 0]);
  return keys;
};
const flapScale = (from, low, beats, step = 5) => {
  const keys = [[from, 1]];
  for (let b = 0; b < beats; b++) keys.push([from + step * (2 * b + 1), low], [from + step * (2 * b + 2), 1]);
  return keys;
};
const blink = (at) => ({ scaleY: [[0, 1], [at, 1], [at + 3, 0.12], [at + 7, 1]] });

/** Shared root motion: pop-in on reveal, double hop on celebrate. */
const rootReveal = {
  scaleX: [[0, 0.82], [8, 0.96], [15, 1.07], [22, 0.98], [28, 1]],
  scaleY: [[0, 0.82], [8, 1.1], [15, 0.94], [22, 1.02], [28, 1]],
};
const rootCelebrate = {
  y: [[0, 0], [9, -13], [17, 0], [24, -6], [30, 0]],
  rotation: [[0, 0], [9, -0.09], [17, 0.06], [24, -0.03], [30, 0]],
  scaleX: [[0, 1], [5, 0.95], [9, 1], [17, 1.08], [20, 1], [30, 1.04], [34, 1]],
  scaleY: [[0, 1], [5, 1.06], [9, 1], [17, 0.92], [20, 1], [30, 0.96], [34, 1]],
};

const rigs = {
  kus: {
    parts: [
      { name: 'tail', pivot: [44, 76], els: [0] },
      { name: 'wing', pivot: [40, 64], els: [4, 8] },
      { name: 'eye', pivot: [98, 36], els: [6, 7] },
    ],
    reveal: { wing: { rotation: wag(8, 0.45, 3, 5) }, tail: { rotation: wag(10, 0.2, 2) }, eye: blink(26) },
    celebrate: { wing: { rotation: wag(0, 0.6, 5, 5) }, tail: { rotation: wag(4, 0.25, 3) } },
  },
  tavsan: {
    parts: [
      { name: 'earL', pivot: [45, 58], els: [0, '2.0'] },
      { name: 'earR', pivot: [68, 56], els: [1, '2.1'] },
      { name: 'eyeL', pivot: [43, 63], els: [7, 8] },
      { name: 'eyeR', pivot: [68, 63], els: [9, 10] },
    ],
    reveal: { earL: { rotation: wag(8, 0.18, 3) }, earR: { rotation: wag(11, -0.16, 3) }, eyeL: blink(26), eyeR: blink(26) },
    celebrate: { earL: { rotation: wag(0, 0.26, 4, 5) }, earR: { rotation: wag(2, -0.24, 4, 5) } },
  },
  balik: {
    parts: [
      { name: 'tail', pivot: [37, 64], els: [0, '9.1'] },
      { name: 'fins', pivot: [70, 64], els: [1, 5] },
      { name: 'eye', pivot: [98, 58], els: [7, 8] },
    ],
    reveal: { tail: { rotation: wag(6, 0.32, 4, 5) }, fins: { scaleY: flapScale(10, 0.85, 2) }, eye: blink(26) },
    celebrate: { tail: { rotation: wag(0, 0.45, 6, 4) }, fins: { scaleY: flapScale(4, 0.8, 3) } },
  },
  kelebek: {
    parts: [
      { name: 'wingL', pivot: [61, 62], els: [0, '2.0', '3.0'] },
      { name: 'wingR', pivot: [67, 62], els: [1, '2.1', '3.1'] },
      { name: 'antennae', pivot: [64, 42], els: [4, 5, 6] },
    ],
    reveal: { wingL: { scaleX: flapScale(6, 0.35, 2) }, wingR: { scaleX: flapScale(6, 0.35, 2) }, antennae: { rotation: wag(10, 0.12, 2) } },
    celebrate: { wingL: { scaleX: flapScale(0, 0.25, 4, 4) }, wingR: { scaleX: flapScale(0, 0.25, 4, 4) }, antennae: { rotation: wag(4, 0.16, 3) } },
  },
  kaplumbaga: {
    parts: [
      { name: 'head', pivot: [84, 76], els: [2, 7, 8, 9] },
      { name: 'eye', pivot: [108, 59], els: [7, 8], parent: 'head' },
    ],
    reveal: { head: { x: [[0, -10], [12, -10], [22, 2], [28, 0]] }, eye: blink(30) },
    celebrate: { head: { rotation: wag(0, -0.18, 4, 6), x: [[0, 0], [8, 3], [30, 0]] } },
  },
  kedi: {
    parts: [
      { name: 'tail', pivot: [44, 100], els: [0] },
      { name: 'head', pivot: [68, 92], els: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12] },
      { name: 'eyeL', pivot: [54, 60], els: [6, 7], parent: 'head' },
      { name: 'eyeR', pivot: [84, 60], els: [8, 9], parent: 'head' },
    ],
    reveal: { tail: { rotation: wag(6, 0.22, 3) }, head: { rotation: wag(10, 0.08, 2, 7) }, eyeL: blink(27), eyeR: blink(27) },
    celebrate: { tail: { rotation: wag(0, 0.3, 5, 5) }, head: { rotation: wag(2, 0.12, 3, 7) } },
  },
  tilki: {
    parts: [
      { name: 'tail', pivot: [60, 100], els: [0, 1] },
      { name: 'head', pivot: [70, 88], els: [4, 5, 6, 7, 8, 9, 10, 11] },
      { name: 'eyeL', pivot: [54, 54], els: [7, 8], parent: 'head' },
      { name: 'eyeR', pivot: [85, 54], els: [9, 10], parent: 'head' },
    ],
    reveal: { tail: { rotation: wag(6, 0.2, 3) }, head: { rotation: wag(10, -0.08, 2, 7) }, eyeL: blink(27), eyeR: blink(27) },
    celebrate: { tail: { rotation: wag(0, 0.28, 5, 5) }, head: { rotation: wag(2, -0.12, 3, 7) } },
  },
  fil: {
    parts: [
      { name: 'tail', pivot: [31, 50], els: [0] },
      { name: 'head', pivot: [84, 62], els: [3, 4, 5, 6, 7, 8, '9.0', '9.1'] },
      { name: 'ear', pivot: [79, 40], els: [4, 5], parent: 'head' },
      { name: 'eye', pivot: [101, 51], els: [7, 8], parent: 'head' },
    ],
    reveal: { head: { rotation: [[0, 0], [10, -0.14], [20, 0.03], [28, 0]] }, ear: { scaleX: flapScale(8, 0.8, 2) }, tail: { rotation: wag(8, 0.25, 2) }, eye: blink(28) },
    celebrate: { head: { rotation: [[0, 0], [10, -0.22], [22, -0.18], [32, 0]] }, ear: { scaleX: flapScale(0, 0.75, 4) }, tail: { rotation: wag(0, 0.3, 4) } },
  },
  at: {
    root: [40, 112],
    parts: [
      { name: 'tail', pivot: [35, 58], els: [0] },
      { name: 'mane', pivot: [76, 34], els: [3] },
      { name: 'eye', pivot: [99, 39], els: [6, 7] },
    ],
    reveal: { tail: { rotation: wag(6, 0.25, 3) }, mane: { rotation: wag(10, 0.06, 2) }, eye: blink(27) },
    celebrate: { tail: { rotation: wag(0, 0.32, 5, 5) }, mane: { rotation: wag(4, 0.08, 3) } },
    rootCelebrate: { rotation: [[0, 0], [10, -0.16], [20, -0.12], [30, 0]], y: [[0, 0], [10, -4], [30, 0]] },
  },
  baykus: {
    parts: [
      { name: 'wingL', pivot: [42, 68], els: ['2.0'] },
      { name: 'wingR', pivot: [88, 68], els: ['2.1'] },
      { name: 'eyeL', pivot: [47, 55], els: [8, 9] },
      { name: 'eyeR', pivot: [83, 55], els: [10, 11] },
    ],
    reveal: { wingL: { rotation: wag(8, 0.2, 2) }, wingR: { rotation: wag(8, -0.2, 2) }, eyeL: blink(18), eyeR: blink(18) },
    celebrate: { wingL: { rotation: wag(0, 0.32, 4, 5) }, wingR: { rotation: wag(0, -0.32, 4, 5) }, eyeL: blink(20), eyeR: blink(20) },
  },
  salyangoz: {
    parts: [
      { name: 'stalkL', pivot: [94, 66], els: ['0.0', 1, 3, 4] },
      { name: 'stalkR', pivot: [104, 68], els: ['0.1', 2, 5, 6] },
      { name: 'shell', pivot: [52, 94], els: [9, 10] },
    ],
    reveal: { stalkL: { rotation: wag(8, -0.14, 3) }, stalkR: { rotation: wag(10, 0.14, 3) }, shell: { rotation: wag(6, 0.05, 2, 8) } },
    celebrate: { stalkL: { rotation: wag(0, -0.2, 4, 5) }, stalkR: { rotation: wag(2, 0.2, 4, 5) }, shell: { rotation: wag(0, 0.08, 3, 8) } },
  },
  denizati: {
    root: [64, 112],
    parts: [
      { name: 'fin', pivot: [56, 52], els: [0, 4] },
      { name: 'eye', pivot: [77, 31], els: [6, 7] },
    ],
    reveal: { fin: { scaleX: flapScale(6, 0.7, 3, 4) }, eye: blink(27) },
    celebrate: { fin: { scaleX: flapScale(0, 0.6, 5, 4) } },
    rootCelebrate: { y: [[0, 0], [10, -10], [20, -2], [28, -8], [38, 0]], rotation: [[0, 0], [10, 0.08], [24, -0.06], [38, 0]] },
  },
};

module.exports = { rigs, rootReveal, rootCelebrate };
