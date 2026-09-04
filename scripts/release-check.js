#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const repo = path.resolve(__dirname, '..');
const readJson = (p) => {
  if (!fs.existsSync(path.join(repo, p))) {
    process.stderr.write(`release:check: missing manifest: ${p}\n`);
    process.exit(1);
  }
  return JSON.parse(fs.readFileSync(path.join(repo, p), 'utf8'));
};
const claude = readJson('.claude-plugin/plugin.json');
const market = readJson('.claude-plugin/marketplace.json');
const codex = readJson('.codex-plugin/plugin.json');
const versions = [claude.version, market.metadata.version, market.plugins[0].version, codex.version];
const errors = [];

if (new Set(versions).size !== 1) errors.push(`manifest version drift: ${versions.join(' / ')}`);
if (codex.skills !== './skills/') errors.push('Codex manifest must point to ./skills/');
if (!fs.existsSync(path.join(repo, 'hooks', 'hooks.json'))) errors.push('missing default Codex hook file: hooks/hooks.json');
for (const host of ['claude', 'codex']) {
  for (const file of ['interaction.md', 'execution.md', 'capabilities.json']) {
    if (!fs.existsSync(path.join(repo, 'hosts', host, file))) errors.push(`missing host adapter: hosts/${host}/${file}`);
  }
}

// Capability vocabulary — derived from core/HOST.md's table, never hardcoded here.
// That table is the single definition (see core/HOST.md); a second copy in this
// script would be the very drift this check exists to prevent.
const hostDoc = path.join(repo, 'core', 'HOST.md');
const canonical = fs.existsSync(hostDoc)
  ? (fs.readFileSync(hostDoc, 'utf8').match(/^\| `[a-z_]+`/gm) || []).map((l) => l.replace(/^\| `([a-z_]+)`/, '$1'))
  : [];
if (!canonical.length) {
  errors.push('cannot derive the capability vocabulary from core/HOST.md');
} else {
  for (const host of ['claude', 'codex']) {
    const cap = path.join(repo, 'hosts', host, 'capabilities.json');
    if (!fs.existsSync(cap)) continue; // already reported above
    let obj = null;
    try { obj = JSON.parse(fs.readFileSync(cap, 'utf8')); } catch (_) { obj = null; }
    const flatBool = obj !== null && typeof obj === 'object' && !Array.isArray(obj)
      && Object.values(obj).every((v) => typeof v === 'boolean');
    if (!flatBool) {
      errors.push(`hosts/${host}/capabilities.json must be a flat object of boolean values`);
      continue;
    }
    const keys = Object.keys(obj);
    const missing = canonical.filter((k) => !keys.includes(k));
    const unknown = keys.filter((k) => !canonical.includes(k));
    if (missing.length) errors.push(`hosts/${host}/capabilities.json missing keys: ${missing.join(', ')}`);
    if (unknown.length) errors.push(`hosts/${host}/capabilities.json unknown keys: ${unknown.join(', ')}`);
  }

  // docs/codex.md claims to be "the same declaration in two forms" as the Codex
  // capabilities.json. Enforce the part a machine can settle: every capability
  // key is NAMED in that table. The status wording itself stays human-reviewed —
  // this gate does not claim more than it checks.
  for (const doc of ['docs/codex.md', 'docs/en/codex.md']) {
    const f = path.join(repo, doc);
    if (!fs.existsSync(f)) {
      errors.push(`${doc} is missing (the Codex capability table has no home)`);
      continue;
    }
    const text = fs.readFileSync(f, 'utf8');
    const undocumented = canonical.filter((k) => !text.includes(`\`${k}\``));
    if (undocumented.length) errors.push(`${doc} does not name capability keys: ${undocumented.join(', ')}`);
  }
}

if (errors.length) {
  for (const error of errors) process.stderr.write(`release:check: ${error}\n`);
  process.exit(1);
}
process.stdout.write(`release:check: ok (forge ${versions[0]}, shared skills + Claude/Codex adapters)\n`);
