'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const ui = require('./forge-monitor-ui/app.js');

test('every API request carries the URL key without changing the path', () => {
  assert.equal(ui.apiURL('/api/snapshot', '?key=a%2Bb'), '/api/snapshot?key=a%2Bb');
  assert.equal(ui.apiURL('/api/history/abc', ''), '/api/history/abc?key=');
});
test('disconnected and archived observations never imply a running agent', () => {
  assert.equal(ui.agentState('running', false, false), '연결 끊김 · 마지막 상태: 실행 중');
  assert.equal(ui.agentState('running', true, true), '종료된 세션 · 마지막 상태: 실행 중');
  assert.equal(ui.agentState('unknown', true, false), '확인 불가');
});
test('pipeline uses recorded verification and retro, not agent activity', () => {
  assert.equal(ui.phase({plan:'# Task',run:'',status:''}), 'run');
  assert.equal(ui.phase({plan:'# Task',run:'result',status:'verified: failed (error)'}), 'verify');
  assert.equal(ui.phase({plan:'# Task',run:'result',status:'verified: yes\nretro: pending'}), 'seal');
  assert.equal(ui.phase({plan:'# Task',run:'result',status:'- verified: YES (checked)'}), 'seal');
  assert.equal(ui.phase({plan:'# Task',run:'result',status:' - status: DONE'}), 'done');
  assert.equal(ui.phase(null), null);
});
test('progress without real counts remains unknown', () => {
  assert.equal(ui.progressText(null), '진행률 확인 불가');
  assert.equal(ui.progressText({completed:2,total:5}), '완료 2 / 5개 항목');
  assert.equal(ui.progressText({completed:8,total:5}), '진행률 확인 불가');
});
test('late live response cannot replace selected history; stale history cannot replace live', async () => {
  const pending = [];
  const renders = [];
  const c = ui.createController(url => new Promise(resolve => pending.push({url,resolve})), state => renders.push({...state}));
  const live = c.load();
  const history = c.select('abc');
  pending[1].resolve({project:{name:'archive'}});
  await history;
  pending[0].resolve({project:{name:'live'}});
  await live;
  assert.equal(c.state.snapshot.project.name, 'archive');
  assert.equal(c.state.record, 'abc');
  const old = c.select('old');
  const current = c.select(null);
  pending[3].resolve({project:{name:'new live'}});
  await current;
  pending[2].resolve({project:{name:'old'}});
  await old;
  assert.equal(c.state.snapshot.project.name, 'new live');
});
test('failed refresh keeps last data with explicit disconnected state', async () => {
  let failed = false;
  const c = ui.createController(async () => {if(failed) throw Error('offline');return {updatedAt:'old'};}, () => {});
  await c.load(); failed = true; await c.load();
  assert.equal(c.state.snapshot.updatedAt, 'old');
  assert.equal(c.state.connected, false);
});
