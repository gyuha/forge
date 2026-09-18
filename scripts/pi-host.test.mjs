#!/usr/bin/env node
// Integration test using an installed Pi SDK; no model call or settings writes.
// Optional: FORGE_PI_PACKAGE_ROOT=/path/to/@earendil-works/pi-coding-agent
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execFileSync } from 'node:child_process';
import { pathToFileURL, fileURLToPath } from 'node:url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function main() {
  const repo = path.resolve(__dirname, '..');
  let sdkRoot = process.env.FORGE_PI_PACKAGE_ROOT;
  if (!sdkRoot) {
    const command = process.platform === 'win32' ? 'where' : 'which';
    const cli = execFileSync(command, ['pi'], { encoding: 'utf8' }).trim().split(/\r?\n/)[0];
    sdkRoot = path.resolve(path.dirname(fs.realpathSync(cli)), '../..');
  }
  const { DefaultResourceLoader, SettingsManager } = await import(pathToFileURL(path.join(sdkRoot, 'dist/index.js')));
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'forge-pi-'));
  try {
    const installed = path.join(temp, 'installed forge');
    const project = path.join(temp, 'project');
    fs.mkdirSync(installed); fs.mkdirSync(project);
    for (const dir of ['skills', 'core', 'hosts', 'scripts']) {
      fs.cpSync(path.join(repo, dir), path.join(installed, dir), { recursive: true });
    }
    fs.copyFileSync(path.join(repo, 'package.json'), path.join(installed, 'package.json'));
    const loader = new DefaultResourceLoader({
      cwd: project, agentDir: path.join(temp, 'agent'),
      settingsManager: SettingsManager.inMemory({ packages: [installed] }),
      noExtensions: true, noPromptTemplates: true, noThemes: true, noContextFiles: true,
    });
    await loader.reload();
    const { skills, diagnostics } = loader.getSkills();
    const belongs = file => file.startsWith(installed + path.sep);
    const loaded = skills.filter(s => belongs(s.filePath));
    assert.deepEqual(diagnostics.filter(d => belongs(d.path)), [], 'Forge loader diagnostics');
    const expected = fs.readdirSync(path.join(installed, 'skills')).filter(name =>
      fs.existsSync(path.join(installed, 'skills', name, 'SKILL.md'))).sort();
    assert.equal(expected.length, 22, 'catalogue size');
    assert.deepEqual(loaded.map(s => s.name).sort(), expected, 'all shared skills, no companion docs as skills');
    for (const skill of loaded) {
      assert.equal(skill.baseDir, path.join(installed, 'skills', skill.name));
      assert.ok(skill.description.length > 0);
      // Every local Markdown link in each entrypoint resolves from its loaded location.
      const body = fs.readFileSync(skill.filePath, 'utf8');
      for (const match of body.matchAll(/\]\((\.{1,2}\/[^)#]+)(?:#[^)]*)?\)/g)) {
        assert.ok(fs.existsSync(path.resolve(skill.baseDir, match[1])), `${skill.name}: ${match[1]}`);
      }
      const description = body.match(/^description: (.+)$/m)[1];
      if (description.startsWith('"')) assert.equal(skill.description, JSON.parse(description));
    }
    const skill = loaded.find(s => s.name === 'fg-status');
    const pluginRoot = path.resolve(skill.baseDir, '../..');
    assert.equal(pluginRoot, installed);
    const caps = JSON.parse(fs.readFileSync(path.join(pluginRoot, 'hosts/pi/capabilities.json')));
    assert.ok(Object.values(caps).every(value => value === false), 'basic host has no native extensions');
    const output = execFileSync(process.execPath, [path.join(pluginRoot, 'scripts/forge-status.js')], {
      cwd: project, encoding: 'utf8', env: { ...process.env, CLAUDE_PLUGIN_ROOT: '', PLUGIN_ROOT: '' },
    });
    assert.match(output, /No forge state/, 'status reads caller project, not installation state');
    assert.ok(!fs.existsSync(path.join(project, '.forge')), 'read-only status');
    console.log(`PI HOST OK: Pi ${JSON.parse(fs.readFileSync(path.join(sdkRoot, 'package.json'))).version}; ${loaded.length} skills, links, external cwd, status fallback`);
  } finally { fs.rmSync(temp, { recursive: true, force: true }); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
