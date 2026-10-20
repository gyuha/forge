'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const hooks = JSON.parse(fs.readFileSync(path.join(root, 'hooks/hooks.json'))).hooks;
const events = ['SessionStart', 'SessionEnd', 'UserPromptSubmit', 'Stop', 'SubagentStart', 'SubagentStop', 'PreToolUse', 'PostToolUse', 'PostToolUseFailure', 'PermissionRequest', 'Notification'];
test('all observation events dispatch the shipped Node hook without a shell and are silent when inactive', () => {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'forge-monitor-wiring-'));
  try {
    for (const event of events) {
      const handler = (hooks[event] || []).flatMap(group => group.hooks).find(hook => hook.args?.some(arg => arg.endsWith('/scripts/forge-hook-monitor.js')));
      assert.ok(handler, `missing monitor event ${event}`);
      assert.equal(handler.command, 'node');
      assert.equal(handler.shell, undefined);
      const args = handler.args.map(arg => arg.replace('${CLAUDE_PLUGIN_ROOT}', root));
      const result = spawnSync(process.execPath, args, { cwd, input: JSON.stringify({ hook_event_name: event, cwd, session_id: 'inactive' }), encoding: 'utf8' });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(result.stdout, '');
      assert.equal(result.stderr, '');
    }
    assert.deepEqual(fs.readdirSync(cwd), []);
  } finally { fs.rmSync(cwd, { recursive: true, force: true }); }
});
test('existing continuation and entry hooks are preserved', () => {
  assert.ok(hooks.SessionStart.some(group => group.matcher === 'startup|resume|clear|compact' && group.hooks.some(hook => hook.command.includes('run-hook.cmd') && hook.command.endsWith('session-start'))));
  assert.ok(hooks.Stop.some(group => group.hooks.some(hook => hook.command.includes('run-hook.cmd') && hook.command.endsWith('stop'))));
});
test('retention config command preserves project keys and rejects invalid input', () => {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'forge-monitor-config-'));
  try {
    fs.mkdirSync(path.join(cwd, '.forge'));
    const file = path.join(cwd, '.forge/config.json');
    fs.writeFileSync(file, JSON.stringify({ tdd: true, custom: { value: 42 } }));
    for (const value of ['keep', 'delete']) {
      const result = spawnSync(process.execPath, [path.join(root, 'scripts/forge-monitor.js'), 'config', value], { cwd, encoding: 'utf8' });
      assert.equal(result.status, 0, result.stderr);
      assert.deepEqual(JSON.parse(fs.readFileSync(file)), { tdd: true, custom: { value: 42 }, monitorRetention: value });
    }
    const before = fs.readFileSync(file, 'utf8');
    const result = spawnSync(process.execPath, [path.join(root, 'scripts/forge-monitor.js'), 'config', 'invalid'], { cwd, encoding: 'utf8' });
    assert.notEqual(result.status, 0);
    assert.equal(fs.readFileSync(file, 'utf8'), before);
  } finally { fs.rmSync(cwd, { recursive: true, force: true }); }
});
