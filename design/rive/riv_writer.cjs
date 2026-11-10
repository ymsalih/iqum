// Minimal Rive runtime-format (.riv, major 7) writer for IQUM's own artwork.
// Type/property keys come from rive-runtime's generated headers
// (rive_native 0.1.11, runtime/include/rive/generated/**/*_base.hpp).
// Only the objects IQUM needs are listed; unknown keys are never written.
'use strict';

const T = Object.freeze({
  backboard: 23, artboard: 1, node: 2, shape: 3, pointsPath: 16, ellipse: 4,
  rectangle: 7, cubicDetachedVertex: 6, fill: 20, stroke: 24, solidColor: 18,
  linearAnimation: 31, keyedObject: 25, keyedProperty: 26, keyFrameDouble: 30,
  cubicEase: 28, stateMachine: 53, trigger: 58, layer: 57, entryState: 63,
  anyState: 62, exitState: 64, animationState: 61, transition: 65,
  triggerCondition: 68,
});

// [key, field type]. Field types: u = varuint, d = float32, c = color, b = bool, s = string.
const P = Object.freeze({
  name: [4, 's'], parentId: [5, 'u'],
  x: [13, 'd'], y: [14, 'd'], rotation: [15, 'd'], scaleX: [16, 'd'], scaleY: [17, 'd'], opacity: [18, 'd'],
  width: [7, 'd'], height: [8, 'd'], clip: [196, 'b'], defaultStateMachineId: [236, 'u'],
  isClosed: [32, 'b'],
  vx: [24, 'd'], vy: [25, 'd'], inRotation: [84, 'd'], inDistance: [85, 'd'], outRotation: [86, 'd'], outDistance: [87, 'd'],
  paramWidth: [20, 'd'], paramHeight: [21, 'd'], cornerRadius: [31, 'd'],
  colorValue: [37, 'c'], fillRule: [40, 'u'], thickness: [47, 'd'], cap: [48, 'u'], join: [49, 'u'],
  animationName: [55, 's'], fps: [56, 'u'], duration: [57, 'u'], speed: [58, 'd'], loop: [59, 'u'],
  objectId: [51, 'u'], propertyKey: [53, 'u'], frame: [67, 'u'], interpolationType: [68, 'u'],
  interpolatorId: [69, 'u'], value: [70, 'd'], x1: [63, 'd'], y1: [64, 'd'], x2: [65, 'd'], y2: [66, 'd'],
  componentName: [138, 's'], animationId: [149, 'u'], stateToId: [151, 'u'], inputId: [155, 'u'],
});

// Animatable node properties (property keys written into KeyedProperty).
const ANIMATABLE = Object.freeze({ x: 13, y: 14, rotation: 15, scaleX: 16, scaleY: 17, opacity: 18 });

class RivWriter {
  constructor() { this.bytes = []; }
  varuint(n) {
    if (!Number.isInteger(n) || n < 0) throw new Error(`varuint needs a non-negative integer, got ${n}`);
    do { let b = n & 0x7f; n = Math.floor(n / 128); if (n) b |= 0x80; this.bytes.push(b); } while (n);
  }
  f32(v) { const b = Buffer.alloc(4); b.writeFloatLE(v); this.bytes.push(...b); }
  u32(v) { const b = Buffer.alloc(4); b.writeUInt32LE(v >>> 0); this.bytes.push(...b); }
  header() {
    for (const ch of 'RIVE') this.bytes.push(ch.charCodeAt(0));
    this.varuint(7); this.varuint(2); this.varuint(0); // major, minor, file id
    this.varuint(0); // empty property table of contents: only core-known keys are used
  }
  object(typeKey, props = {}) {
    this.varuint(typeKey);
    for (const [name, value] of Object.entries(props)) {
      if (value === undefined || value === null) continue;
      const def = P[name];
      if (!def) throw new Error(`Unknown property ${name}`);
      const [key, type] = def;
      this.varuint(key);
      if (type === 'u') this.varuint(value);
      else if (type === 'd') this.f32(value);
      else if (type === 'c') this.u32(value);
      else if (type === 'b') this.bytes.push(value ? 1 : 0);
      else if (type === 's') { const s = Buffer.from(String(value), 'utf8'); this.varuint(s.length); this.bytes.push(...s); }
    }
    this.varuint(0);
  }
  buffer() { return Buffer.from(this.bytes); }
}

module.exports = { T, P, ANIMATABLE, RivWriter };
