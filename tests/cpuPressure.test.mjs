import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadJs } from './loadjs.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const m = loadJs(path.join(here, '..', 'src', 'providers', 'cpuPressure.js'));
const plain = (v) => JSON.parse(JSON.stringify(v));
const limits = { hot: 88, cool: 75, polls: 3 };

function run(percents) {
  let state = { count: 0, warned: false };
  const warnings = [];
  for (const p of percents) {
    state = m.step(state, p, limits);
    warnings.push(state.warn);
  }
  return warnings;
}

test('one busy program below the overall limit never warns', () => {
  // 100%+ of a core on a 16-thread machine is only about 10% overall.
  assert.deepEqual(run([10, 12, 11, 12, 10, 12]), [false, false, false, false, false, false]);
});

test('warns once overall CPU stays near 90 for 3 polls', () => {
  assert.deepEqual(run([90, 92, 93]), [false, false, true]);
});

test('a short spike does not warn', () => {
  assert.deepEqual(run([95, 96, 40, 95, 96, 40]), [false, false, false, false, false, false]);
});

test('warns only once while the load stays up', () => {
  assert.deepEqual(run([90, 90, 90, 90, 90, 90, 90]), [false, false, true, false, false, false, false]);
});

test('hovering just under the limit does not warn again', () => {
  assert.deepEqual(run([90, 90, 90, 80, 90, 90, 90]), [false, false, true, false, false, false, false]);
});

test('warns again after the machine has really cooled down', () => {
  assert.deepEqual(run([90, 90, 90, 30, 90, 90, 90]), [false, false, true, false, false, false, true]);
});

test('parseSample picks the highest program that is not ignored', () => {
  const text = '16\n900 740.0 top\n812 640.5 ffmpeg\n77 120.0 zen\n';
  assert.deepEqual(plain(m.parseSample(text, ['top', 'qs'])), {
    cores: 16,
    top: { pid: '812', cpu: 640.5, name: 'ffmpeg' },
  });
});

test('parseSample has no top program when everything is ignored or idle', () => {
  assert.equal(m.parseSample('8\n1 90.0 top\n', ['top']).top, null);
  assert.equal(m.parseSample('8\n1 0.0 zen\n', []).top, null);
  assert.equal(m.parseSample('', []).top, null);
});

test('machineShare turns per-core percent into share of the whole machine', () => {
  assert.equal(m.machineShare(640, 16), 40);
  assert.equal(m.machineShare(640, 0), 640);
});
