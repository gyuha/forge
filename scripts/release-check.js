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

if (errors.length) {
  for (const error of errors) process.stderr.write(`release:check: ${error}\n`);
  process.exit(1);
}
process.stdout.write(`release:check: ok (forge ${versions[0]}, shared skills + Claude/Codex adapters)\n`);
