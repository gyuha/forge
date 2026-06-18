#!/usr/bin/env node
// resolve-forge-root.js — node twin of resolve-forge-root.sh (ADR-0022).
//
// Prints the resolved forge root (ADR-0011 / FORGE-ROOT.md) on stdout; a
// one-line fallback warning on stderr when not on a named branch / non-git.
// node is the fallback when bash is unavailable (PowerShell-blocked Windows).
//
// Also exports resolveForgeRoot() so the node twins of other scripts can reuse
// the resolution without spawning a subprocess (DRY — see forge-status.js).
//
// Usage (CLI):  node scripts/resolve-forge-root.js
// Usage (lib):  const { resolveForgeRoot } = require('./resolve-forge-root.js')
'use strict';

const fs = require('fs');
const { execSync } = require('child_process');

function resolveForgeRoot() {
  // Anchor to the git repo root so state resolves from a subdirectory too
  // (ADR-0022 review). Non-git → empty top → CWD-relative `.forge` fallback.
  let top = '';
  try {
    top = execSync('git rev-parse --show-toplevel', { stdio: ['ignore', 'pipe', 'ignore'] })
      .toString().trim();
  } catch (_) { top = ''; }
  const prefix = top ? `${top}/` : '';

  let branch = '';
  try {
    branch = execSync('git rev-parse --abbrev-ref HEAD', { stdio: ['ignore', 'pipe', 'ignore'] })
      .toString().trim();
  } catch (_) { branch = ''; }

  let defaultBranch = 'main';
  try {
    const m = fs.readFileSync(`${top || '.'}/.forge/config.json`, 'utf8').match(/"defaultBranch"\s*:\s*"([^"]*)"/);
    if (m && m[1]) defaultBranch = m[1];
  } catch (_) { /* no config */ }

  if (!branch || branch === 'HEAD') {
    return { root: `${prefix}.forge`, fallback: true };
  }
  if (branch === defaultBranch) {
    return { root: `${prefix}.forge`, fallback: false };
  }
  return { root: `${prefix}.forge/branch/${branch}`, fallback: false };
}

module.exports = { resolveForgeRoot };

if (require.main === module) {
  const { root, fallback } = resolveForgeRoot();
  if (fallback) {
    process.stderr.write('resolve-forge-root: not on a named branch; using default .forge/ root\n');
  }
  process.stdout.write(root + '\n');
}
