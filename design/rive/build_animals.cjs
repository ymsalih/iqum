// Builds assets/art/<animal>.riv from IQUM's original vector animals.
//   node design/rive/build_animals.cjs
// Each file: one 128×128 artboard, `reveal` + `celebrate` one-shot animations,
// and a default state machine (Entry → reveal; Any + trigger `match` → celebrate).
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { animals, line } = require('../animals.cjs');
const { T, ANIMATABLE, RivWriter } = require('./riv_writer.cjs');
const { elements, parsePath, parseRotate, color } = require('./svg_shapes.cjs');
const { rigs, rootReveal, rootCelebrate } = require('./animal_rigs.cjs');

const SIZE = 128, FPS = 60;
const out = path.join(__dirname, '..', '..', 'assets', 'art');

function build(key) {
  const rig = rigs[key];
  if (!rig) throw new Error(`Missing rig for ${key}`);
  const els = elements(animals[key][1]);
  const rootPivot = rig.root ?? [64, 116];

  // Part tree: root first, then parts (parents always precede children).
  const parts = [{ name: 'root', pivot: rootPivot, parent: null }];
  for (const p of rig.parts) parts.push({ ...p, parent: p.parent ?? 'root' });
  const partIndex = new Map(parts.map((p, i) => [p.name, i]));
  for (const p of parts.slice(1)) {
    if (!partIndex.has(p.parent) || partIndex.get(p.parent) >= partIndex.get(p.name)) throw new Error(`${key}: bad parent for ${p.name}`);
  }

  // Assign each element (or sub-path) to the most specific part listing it.
  const owner = (ref) => {
    let found = 'root';
    for (const p of rig.parts) if (p.els.some((e) => String(e) === ref)) found = p.name;
    return found;
  };

  // Paint-order list of drawable pieces: [{part, el, subpaths|primitive}]
  const pieces = [];
  els.forEach((el, i) => {
    if (el.tag === 'path') {
      const subs = parsePath(el.attrs.d);
      const groups = new Map();
      subs.forEach((s, si) => {
        const part = rig.parts.some((p) => p.els.some((e) => String(e) === `${i}.${si}`)) ? owner(`${i}.${si}`) : owner(String(i));
        if (!groups.has(part)) groups.set(part, []);
        groups.get(part).push(s);
      });
      for (const [part, subpaths] of groups) pieces.push({ part, el, subpaths });
    } else {
      pieces.push({ part: owner(String(i)), el });
    }
  });

  const w = new RivWriter();
  w.header();
  w.object(T.backboard);
  const ids = []; // artboard object list, index = id
  const add = (typeKey, props, label) => { w.object(typeKey, props); ids.push(label ?? typeKey); return ids.length - 1; };
  add(T.artboard, { name: key, width: SIZE, height: SIZE, clip: false, defaultStateMachineId: 0 });

  const nodeId = new Map();
  for (const p of parts) {
    const parent = p.parent ? parts[partIndex.get(p.parent)] : null;
    const id = add(T.node, {
      name: p.name,
      parentId: parent ? nodeId.get(parent.name) : 0,
      x: p.pivot[0] - (parent ? parent.pivot[0] : 0),
      y: p.pivot[1] - (parent ? parent.pivot[1] : 0),
    }, `node:${p.name}`);
    nodeId.set(p.name, id);
  }
  const rest = new Map(parts.map((p) => {
    const parent = p.parent ? parts[partIndex.get(p.parent)] : null;
    return [p.name, { x: p.pivot[0] - (parent ? parent.pivot[0] : 0), y: p.pivot[1] - (parent ? parent.pivot[1] : 0), rotation: 0, scaleX: 1, scaleY: 1, opacity: 1 }];
  }));

  // Rive draws the first drawable on top, so write pieces in reverse SVG order.
  for (const piece of [...pieces].reverse()) {
    const { el } = piece;
    const part = parts[partIndex.get(piece.part)];
    const shape = add(T.shape, { parentId: nodeId.get(part.name), x: -part.pivot[0], y: -part.pivot[1] });
    const a = el.attrs;
    if (el.tag === 'path') {
      for (const sub of piece.subpaths) {
        const pathId = add(T.pointsPath, { parentId: shape, isClosed: sub.closed });
        for (const v of sub.vertices) {
          add(T.cubicDetachedVertex, {
            parentId: pathId, vx: v.x, vy: v.y,
            inRotation: Math.atan2(v.in.y - v.y, v.in.x - v.x), inDistance: Math.hypot(v.in.x - v.x, v.in.y - v.y),
            outRotation: Math.atan2(v.out.y - v.y, v.out.x - v.x), outDistance: Math.hypot(v.out.x - v.x, v.out.y - v.y),
          });
        }
      }
    } else if (el.tag === 'circle' || el.tag === 'ellipse') {
      const rx = +(a.rx ?? a.r), ry = +(a.ry ?? a.r), rot = parseRotate(a.transform);
      if (rot && (Math.abs(rot.cx - +a.cx) > 1e-6 || Math.abs(rot.cy - +a.cy) > 1e-6)) throw new Error(`${key}: off-centre ellipse rotation`);
      add(T.ellipse, { parentId: shape, x: +a.cx, y: +a.cy, rotation: rot ? (rot.degrees * Math.PI) / 180 : undefined, paramWidth: 2 * rx, paramHeight: 2 * ry });
    } else if (el.tag === 'rect') {
      add(T.rectangle, { parentId: shape, x: +a.x + +a.width / 2, y: +a.y + +a.height / 2, paramWidth: +a.width, paramHeight: +a.height, cornerRadius: a.rx ? +a.rx : undefined });
    }
    // SVG default fill is black; the shared group stroke is `line`, 2.6, round.
    const fill = a.fill === undefined ? 0xff000000 : color(a.fill);
    const stroke = a.stroke === undefined ? color(line) : color(a.stroke);
    if (fill !== null) {
      const f = add(T.fill, { parentId: shape });
      add(T.solidColor, { parentId: f, colorValue: fill });
    }
    if (stroke !== null) {
      const s = add(T.stroke, { parentId: shape, thickness: a['stroke-width'] ? +a['stroke-width'] : 2.6, cap: 1, join: 1 });
      add(T.solidColor, { parentId: s, colorValue: stroke });
    }
  }

  const ease = add(T.cubicEase, { x1: 0.42, y1: 0, x2: 0.58, y2: 1 }, 'ease');

  const animations = [
    { name: 'reveal', tracks: { root: rootReveal, ...rig.reveal } },
    { name: 'celebrate', tracks: { root: rig.rootCelebrate ?? rootCelebrate, ...rig.celebrate } },
  ];
  for (const anim of animations) {
    let last = 0;
    for (const props of Object.values(anim.tracks)) for (const keys of Object.values(props)) for (const [f] of keys) last = Math.max(last, f);
    w.object(T.linearAnimation, { animationName: anim.name, fps: FPS, duration: last + 1, loop: 0 });
    for (const [partName, props] of Object.entries(anim.tracks)) {
      if (!nodeId.has(partName)) throw new Error(`${key}/${anim.name}: unknown part ${partName}`);
      w.object(T.keyedObject, { objectId: nodeId.get(partName) });
      for (const [prop, keys] of Object.entries(props)) {
        if (!(prop in ANIMATABLE)) throw new Error(`Unknown animated property ${prop}`);
        w.object(T.keyedProperty, { propertyKey: ANIMATABLE[prop] });
        const base = rest.get(partName)[prop];
        const offset = prop === 'x' || prop === 'y' || prop === 'rotation';
        for (const [frame, value] of [...keys].sort((p, q) => p[0] - q[0])) {
          w.object(T.keyFrameDouble, { frame, interpolationType: 2, interpolatorId: ease, value: offset ? base + value : value });
        }
      }
    }
  }

  // State machine: states are [entry, any, exit, reveal, celebrate].
  w.object(T.stateMachine, { animationName: 'State Machine 1' });
  w.object(T.trigger, { componentName: 'match' });
  w.object(T.layer, { componentName: 'Layer 1' });
  w.object(T.entryState);
  w.object(T.transition, { stateToId: 3 });
  w.object(T.anyState);
  w.object(T.transition, { stateToId: 4 });
  w.object(T.triggerCondition, { inputId: 0 });
  w.object(T.exitState);
  w.object(T.animationState, { animationId: 0 });
  w.object(T.animationState, { animationId: 1 });

  return w.buffer();
}

let total = 0;
for (const key of Object.keys(animals)) {
  const bytes = build(key);
  total += bytes.length;
  fs.writeFileSync(path.join(out, `${key}.riv`), bytes);
}
console.log(`Built ${Object.keys(animals).length} Rive animals into assets/art (${(total / 1024).toFixed(1)} KiB total).`);
