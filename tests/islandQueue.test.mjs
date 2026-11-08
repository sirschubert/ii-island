import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadJs } from './loadjs.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const q = loadJs(path.join(here, '..', 'src', 'islandQueue.js'));

test('priority order', () => {
  let s = q.newState();
  s = q.push(s, { id: 'm', kind: 'music', payload: {}, ttl: 4000 }, 0);
  s = q.push(s, { id: 'n', kind: 'notif', payload: {}, ttl: 7000 }, 1);
  s = q.push(s, { id: 'p', kind: 'claudePerm', sessionId: 's1', payload: {}, ttl: 0, staleAfter: 600000 }, 2);
  assert.equal(q.view(s, true).main.kind, 'claudePerm');
  s = q.remove(s, 'p');
  assert.equal(q.view(s, true).main.kind, 'notif');
});

test('music event uses latest track, replaces previous', () => {
  let s = q.newState();
  s = q.push(s, { id: 'm1', kind: 'music', payload: { title: 'first' }, ttl: 4000 }, 0);
  s = q.push(s, { id: 'm2', kind: 'music', payload: { title: 'second' }, ttl: 4000 }, 10);
  const music = s.events.filter((e) => e.kind === 'music');
  assert.equal(music.length, 1);
  assert.equal(music[0].payload.title, 'second');
});

test('burst of 10 notifs', () => {
  let s = q.newState();
  for (let i = 0; i < 10; i++) {
    s = q.push(s, { id: 'n' + i, kind: 'notif', payload: {}, ttl: 7000 }, i);
  }
  const v = q.view(s, false);
  assert.equal(v.main.id, 'n9');
  assert.equal(v.extra, 9);
  const r = q.expire(s, 7000);
  assert.equal(r.expired.length, 1);
  assert.equal(r.expired[0].id, 'n0');
});

test('perm sticky until session event', () => {
  let s = q.newState();
  s = q.push(s, { id: 'p', kind: 'claudePerm', sessionId: 's1', payload: {}, ttl: 0, staleAfter: 600000 }, 0);
  assert.equal(q.expire(s, 599999).expired.length, 0);
  s = q.push(s, { id: 'l', kind: 'claudeLive', sessionId: 's1', payload: {}, ttl: 0, staleAfter: 600000 }, 599999);
  assert.equal(s.events.some((e) => e.kind === 'claudePerm'), false);
  assert.equal(q.view(s, false).main.kind, 'claudeLive');
});

test('stale live expires', () => {
  let s = q.newState();
  s = q.push(s, { id: 'l', kind: 'claudeLive', sessionId: 's1', payload: {}, ttl: 0, staleAfter: 600000 }, 0);
  s = q.push(s, { id: 'l', kind: 'claudeLive', sessionId: 's1', payload: {}, ttl: 0, staleAfter: 600000 }, 300000);
  assert.equal(q.expire(s, 899999).expired.length, 0);
  const r = q.expire(s, 900000);
  assert.equal(r.expired.length, 1);
  assert.equal(r.expired[0].kind, 'claudeLive');
});

test('done clears live', () => {
  let s = q.newState();
  s = q.push(s, { id: 'l', kind: 'claudeLive', sessionId: 's1', payload: {}, ttl: 0, staleAfter: 600000 }, 0);
  s = q.push(s, { id: 'd', kind: 'claudeDone', sessionId: 's1', payload: {}, ttl: 4000 }, 1000);
  assert.equal(s.events.length, 1);
  assert.equal(s.events[0].kind, 'claudeDone');
});

test('bubble only when playing and main not music', () => {
  let s = q.newState();
  s = q.push(s, { id: 'n1', kind: 'notif', payload: {}, ttl: 7000 }, 0);
  assert.equal(q.view(s, true).bubble, true);
  assert.equal(q.view(s, false).bubble, false);

  let m = q.newState();
  m = q.push(m, { id: 'm', kind: 'music', payload: {}, ttl: 4000 }, 0);
  assert.equal(q.view(m, true).bubble, false);
});

test('empty', () => {
  const v = q.view(q.newState(), true);
  assert.equal(v.main, null);
  assert.equal(v.bubble, false);
  assert.equal(v.extra, 0);
});

test('same-millisecond notifs: newest pushed is main', () => {
  let s = q.newState();
  for (let i = 0; i < 3; i++) s = q.push(s, { id: 'm' + i, kind: 'notif', payload: {}, ttl: 7000 }, 1000);
  const v = q.view(s, false);
  assert.equal(v.main.id, 'm2');
  assert.equal(v.extra, 2);
});

test('info cards rank with notifications, below claude permission', () => {
  let s = q.newState();
  s = q.push(s, { id: 'i1', kind: 'info', payload: {}, ttl: 5000 }, 0);
  s = q.push(s, { id: 'mu', kind: 'music', payload: {}, ttl: 4000 }, 1);
  assert.equal(q.view(s, false).main.id, 'i1');
  s = q.push(s, { id: 'p', kind: 'claudePerm', sessionId: 's', payload: {}, ttl: 0 }, 2);
  assert.equal(q.view(s, false).main.id, 'p');
});

test('removeKind drops every event of that kind only', () => {
  let s = q.newState();
  s = q.push(s, { id: 'n1', kind: 'notif', payload: {}, ttl: 7000 }, 0);
  s = q.push(s, { id: 'n2', kind: 'notif', payload: {}, ttl: 7000 }, 1);
  s = q.push(s, { id: 'i1', kind: 'info', payload: {}, ttl: 5000 }, 2);
  s = q.removeKind(s, 'notif');
  assert.deepEqual(Array.from(s.events, e => e.id), ['i1']);
});
