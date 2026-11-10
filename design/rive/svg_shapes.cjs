// Parses the small SVG vocabulary used by design/animals.cjs into absolute
// cubic sub-paths, ellipses and rounded rectangles for the Rive writer.
'use strict';

function attrs(source) {
  const out = {};
  for (const m of source.matchAll(/([\w-]+)="([^"]*)"/g)) out[m[1]] = m[2];
  return out;
}

/** Returns [{tag, attrs}] in paint order (later = on top). */
function elements(fragment) {
  return [...fragment.matchAll(/<(path|circle|ellipse|rect)\b([^>]*)\/>/g)].map((m) => ({ tag: m[1], attrs: attrs(m[2]) }));
}

function tokens(d) {
  return [...d.matchAll(/[MmLlHhVvCcSsQqTtZzAa]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?/g)].map((m) => m[0]);
}

/**
 * Converts SVG path data to sub-paths of vertices:
 * {closed, vertices:[{x,y,in:{x,y},out:{x,y}}]} with absolute control points.
 */
function parsePath(d) {
  const t = tokens(d);
  let i = 0, cmd = null, cx = 0, cy = 0, sx = 0, sy = 0;
  let lastC2 = null, lastQ = null;
  const subpaths = [];
  let current = null;
  const num = () => { const v = parseFloat(t[i++]); if (Number.isNaN(v)) throw new Error(`Bad path data near ${t.slice(i - 3, i + 3).join(' ')}`); return v; };
  const start = (x, y) => {
    finishOpen();
    current = { closed: false, vertices: [{ x, y, in: { x, y }, out: { x, y } }] };
    subpaths.push(current);
    cx = sx = x; cy = sy = y;
  };
  const cubic = (c1x, c1y, c2x, c2y, x, y) => {
    const prev = current.vertices[current.vertices.length - 1];
    prev.out = { x: c1x, y: c1y };
    current.vertices.push({ x, y, in: { x: c2x, y: c2y }, out: { x, y } });
    cx = x; cy = y;
  };
  const line = (x, y) => cubic(cx, cy, x, y, x, y);
  function finishOpen() { /* open sub-paths keep zero-length end handles */ }
  while (i < t.length) {
    if (/[A-Za-z]/.test(t[i])) cmd = t[i++];
    const rel = cmd === cmd.toLowerCase();
    const ox = rel ? cx : 0, oy = rel ? cy : 0;
    switch (cmd.toUpperCase()) {
      case 'M': {
        const x = num() + ox, y = num() + oy;
        start(x, y);
        cmd = rel ? 'l' : 'L'; // implicit lineto after moveto
        lastC2 = lastQ = null;
        break;
      }
      case 'L': line(num() + ox, num() + oy); lastC2 = lastQ = null; break;
      case 'H': line(num() + ox, cy); lastC2 = lastQ = null; break;
      case 'V': line(cx, num() + oy); lastC2 = lastQ = null; break;
      case 'C': {
        const c1x = num() + ox, c1y = num() + oy, c2x = num() + ox, c2y = num() + oy, x = num() + ox, y = num() + oy;
        cubic(c1x, c1y, c2x, c2y, x, y); lastC2 = { x: c2x, y: c2y }; lastQ = null; break;
      }
      case 'S': {
        const c1x = lastC2 ? 2 * cx - lastC2.x : cx, c1y = lastC2 ? 2 * cy - lastC2.y : cy;
        const c2x = num() + ox, c2y = num() + oy, x = num() + ox, y = num() + oy;
        cubic(c1x, c1y, c2x, c2y, x, y); lastC2 = { x: c2x, y: c2y }; lastQ = null; break;
      }
      case 'Q': case 'T': {
        let qx, qy;
        if (cmd.toUpperCase() === 'Q') { qx = num() + ox; qy = num() + oy; }
        else { qx = lastQ ? 2 * cx - lastQ.x : cx; qy = lastQ ? 2 * cy - lastQ.y : cy; }
        const x = num() + ox, y = num() + oy;
        cubic(cx + (2 / 3) * (qx - cx), cy + (2 / 3) * (qy - cy), x + (2 / 3) * (qx - x), y + (2 / 3) * (qy - y), x, y);
        lastQ = { x: qx, y: qy }; lastC2 = null; break;
      }
      case 'Z': {
        current.closed = true;
        const v = current.vertices, first = v[0], last = v[v.length - 1];
        if (v.length > 1 && Math.hypot(first.x - last.x, first.y - last.y) < 1e-3) {
          first.in = last.in; // the explicit end point is the start vertex
          v.pop();
        }
        cx = sx; cy = sy; lastC2 = lastQ = null;
        // A following command without M starts at the sub-path start.
        if (i < t.length && !/[Mm]/.test(t[i])) start(sx, sy);
        break;
      }
      case 'A': throw new Error('Arc commands are not used by IQUM artwork');
      default: throw new Error(`Unsupported path command ${cmd}`);
    }
  }
  return subpaths.filter((s) => s.vertices.length > 1);
}

function parseRotate(transform) {
  if (!transform) return null;
  const m = /rotate\(\s*(-?[\d.]+)(?:[\s,]+(-?[\d.]+)[\s,]+(-?[\d.]+))?\s*\)/.exec(transform);
  if (!m) throw new Error(`Unsupported transform ${transform}`);
  return { degrees: +m[1], cx: m[2] === undefined ? 0 : +m[2], cy: m[3] === undefined ? 0 : +m[3] };
}

function color(value) {
  if (!value || value === 'none') return null;
  const m = /^#([0-9a-f]{6})$/i.exec(value);
  if (!m) throw new Error(`Unsupported colour ${value}`);
  return (0xff000000 | parseInt(m[1], 16)) >>> 0;
}

module.exports = { elements, parsePath, parseRotate, color };
