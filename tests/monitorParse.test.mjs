import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadJs } from './loadjs.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const m = loadJs(path.join(here, '..', 'src', 'monitor', 'monitorParse.js'));

// vm contexts use their own realm, so normalise results before deep comparison
const plain = (v) => JSON.parse(JSON.stringify(v));

test('parseNvidiaSmi ok', () => {
  const r = m.parseNvidiaSmi('NVIDIA GeForce GTX 1660, 41, 3100, 6144, 58\n');
  assert.deepEqual(plain(r), { name: 'NVIDIA GeForce GTX 1660', util: 41, memUsedMiB: 3100, memTotalMiB: 6144, tempC: 58 });
});

test('parseNvidiaSmi rejects garbage', () => {
  assert.equal(m.parseNvidiaSmi(''), null);
  assert.equal(m.parseNvidiaSmi("NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver"), null);
  assert.equal(m.parseNvidiaSmi('[N/A], [N/A]'), null);
});

test('parseNvidiaSmi rejects real driver error (exit 9 output on this machine)', () => {
  const real = 'NVIDIA-SMI has failed because it couldn\'t communicate with the NVIDIA driver. Make sure that the latest NVIDIA driver is installed and running.\n\n';
  assert.equal(m.parseNvidiaSmi(real), null);
});

test('parsePs top n', () => {
  const r = m.parsePs('firefox 8.1\nqs 3.4\nsteam 2.2\n', 2);
  assert.deepEqual(plain(r), [{ name: 'firefox', cpu: 8.1 }, { name: 'qs', cpu: 3.4 }]);
});

test('parseCpuFreqMHz', () => {
  assert.equal(m.parseCpuFreqMHz('cpu MHz : 4000.000\ncpu MHz : 4400.000\n'), 4200);
  assert.equal(m.parseCpuFreqMHz('processor : 0\nmodel name : foo\n'), null);
});

test('parseCpuFreqMHz real /proc/cpuinfo format (tab-separated)', () => {
  const real = 'cpu MHz\t\t: 4300.452\ncpu MHz\t\t: 4301.124\ncpu MHz\t\t: 4300.467\n';
  assert.ok(Math.abs(m.parseCpuFreqMHz(real) - 4300.681) < 0.001);
});

test('pickCpuTemp', () => {
  assert.equal(m.pickCpuTemp('{"coretemp-isa-0000":{"Package id 0":{"temp1_input":62.0}}}'), 62);
  assert.equal(m.pickCpuTemp('{}'), null);
});

test('pickCpuTemp real sensors -j output', () => {
  const real = '{"coretemp-isa-0000":{"Adapter":"ISA adapter","Package id 0":{"temp1_input":45.000000,"temp1_max":82.000000,"temp1_crit":100.000000,"temp1_crit_alarm":0.000000},"Core 0":{"temp2_input":41.000000,"temp2_max":82.000000,"temp2_crit":100.000000,"temp2_crit_alarm":0.000000}},"acpitz-acpi-0":{"Adapter":"ACPI interface","temp1":{"temp1_input":27.800000},"temp2":{"temp2_input":29.800000}}}';
  assert.equal(m.pickCpuTemp(real), 45);
});
