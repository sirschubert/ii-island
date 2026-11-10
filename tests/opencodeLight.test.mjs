import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadJs } from './loadjs.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const m = loadJs(path.join(here, '..', 'src', 'cards', 'opencodeLight.js'));
const plain = (v) => JSON.parse(JSON.stringify(v));

test('ringPoint follows the centre of the logo ring clockwise', () => {
  assert.deepEqual(plain(m.ringPoint(0)), [30, 30]);
  assert.deepEqual(plain(m.ringPoint(180)), [210, 30]);
  assert.deepEqual(plain(m.ringPoint(420)), [210, 270]);
  assert.deepEqual(plain(m.ringPoint(600)), [30, 270]);
  assert.deepEqual(plain(m.ringPoint(840)), [30, 30]);
  assert.deepEqual(plain(m.ringPoint(-60)), [30, 90]);
});

test('sweep starts at the head and fades along its tail', () => {
  const segments = plain(m.sweep(0.25));
  assert.deepEqual(segments[0].points.at(-1), plain(m.ringPoint(210)));
  assert.equal(segments[0].alpha, 1);
  for (let i = 1; i < segments.length; i++)
    assert.ok(segments[i].alpha < segments[i - 1].alpha);
});

test('segments join up, so the band has no holes', () => {
  const segments = plain(m.sweep(0.6));
  for (let i = 1; i < segments.length; i++)
    assert.deepEqual(segments[i].points.at(-1), segments[i - 1].points[0]);
});

test('a segment crossing a corner bends through it, also before the start of a lap', () => {
  const crossing = (progress) => plain(m.sweep(progress)).flatMap((s) => s.points);
  const hasPoint = (points, p) => points.some(([x, y]) => x === p[0] && y === p[1]);
  assert.ok(hasPoint(crossing(0.5), [210, 30]));
  assert.ok(hasPoint(crossing(0.05), [30, 270]));
});

test('every point stays on the ring centre line', () => {
  for (const progress of [0, 0.13, 0.37, 0.5, 0.99])
    for (const { points } of plain(m.sweep(progress)))
      for (const [x, y] of points)
        assert.ok((x === 30 || x === 210 || y === 30 || y === 270) && x >= 30 && x <= 210 && y >= 30 && y <= 270);
});
