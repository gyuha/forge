// Execute the batch half under real cmd.exe; Unix wrapper tests cannot cover it.
'use strict';
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
if (process.platform !== 'win32') {
  console.log('SKIP: Windows cmd.exe is required');
  process.exit(0);
}
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'forge-hook-windows-'));
try {
  fs.mkdirSync(path.join(dir, 'hooks'));
  fs.mkdirSync(path.join(dir, 'scripts'));
  fs.copyFileSync(path.join(__dirname, 'run-hook.cmd'), path.join(dir, 'hooks', 'run-hook.cmd'));
  const run = () => spawnSync(process.env.ComSpec || 'cmd.exe', ['/d', '/c', 'hooks\\run-hook.cmd stop'], { cwd: dir, encoding: 'utf8' });
  for (const code of [0, 1, 2]) {
    // No .sh file: exercise the actual Node fallback even if Git Bash exists.
    fs.writeFileSync(path.join(dir, 'scripts', 'forge-hook-stop.js'), `process.exit(${code});\n`);
    const result = run();
    assert.strictEqual(result.status, code, `node exit ${code}: ${result.error || result.stderr}`);
  }
  const candidates = ['C:\\Program Files\\Git\\bin\\bash.exe', 'C:\\Program Files (x86)\\Git\\bin\\bash.exe', 'bash'];
  const bashAvailable = candidates.some((cmd) => spawnSync(cmd, ['--version'], { encoding: 'utf8' }).status === 0);
  if (bashAvailable) {
    for (const code of [0, 1, 2]) {
      fs.writeFileSync(path.join(dir, 'scripts', 'forge-hook-stop.sh'), `#!/bin/bash\nexit ${code}\n`);
      const result = run();
      assert.strictEqual(result.status, code, `bash exit ${code}: ${result.error || result.stderr}`);
    }
  } else console.log('SKIP: Bash branch (no Bash runtime)');
  console.log('Windows hook exit propagation: PASS');
} finally {
  fs.rmSync(dir, { recursive: true, force: true });
}
