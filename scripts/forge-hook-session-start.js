#!/usr/bin/env node
// forge-hook-session-start.js — node twin of forge-hook-session-start.sh
// (ADR-0022). SessionStart hook body: inject the unsealed-tail notice into the
// session context (ADR 260727-201031).
//
// node is the fallback when bash is unavailable (e.g. Windows without git-bash);
// the hooks/ wrapper picks whichever runtime exists. Output MUST stay byte-identical
// to the bash primary — enforced by forge-hook-session-start.parity.test.sh.
//
// Contract (see the .sh header for the full rationale): silent unless there is
// real debt (unsealed active slot / parked executed/ / loop.md); a backlog-only or
// promoted-but-unrun state is not debt. Always exits 0.
//
// Usage:  node scripts/forge-hook-session-start.js
'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { resolveForgeRoot } = require('./resolve-forge-root.js');

const MAX_ITEMS = 3;

const { root } = resolveForgeRoot();
if (!isDir(root)) process.exit(0);

// Repo-relative label for messages (the resolver returns an absolute path inside
// a git repo; an absolute path in the injected block would be noise).
let top = '';
try {
  top = execSync('git rev-parse --show-toplevel', { stdio: ['ignore', 'pipe', 'ignore'] })
    .toString().trim();
} catch (_) { top = ''; }
const disp = top && root.startsWith(`${top}/`) ? root.slice(top.length + 1) : root;

function isDir(p) { try { return fs.statSync(p).isDirectory(); } catch (_) { return false; } }
function read(p) { try { return fs.readFileSync(p, 'utf8').replace(/\r/g, ''); } catch (_) { return ''; } }

// Full value after the colon — accepts both `field:` and `- field:` (dash-list
// legacy) and tolerates CRLF, like the bash `field()`.
function field(file, name) {
  const re = new RegExp(`^[ \\t]*-?[ \\t]*${name}:[ \\t]*(.*)$`, 'm');
  const m = read(file).match(re);
  return m ? m[1].replace(/[ \t]+$/, '') : '';
}
function slugof(planFile) {
  const m = read(planFile).match(/forge-slug:[ \t]*([^ ]*)[ \t]*-->/);
  return m ? m[1] : '';
}
function taskof(planFile) {
  const m = read(planFile).match(/task:[ \t]*(\d+)/);
  return m ? m[1] : '';
}

function mkItem(tsk, slug, where, v, r) {
  const prefix = tsk ? `task ${tsk} ` : '';
  return `- ${prefix}\`${slug}\` — ${where}, verified: ${v || 'pending'}, retro: ${r || 'pending'}`;
}

// --- Collect debt items ------------------------------------------------------
const items = [];

// Active slot: debt only when it has actually run and is not sealed. A promoted
// plan with no run.md is deliberate backlog stacking, not debt.
if (fs.existsSync(path.join(root, 'run.md'))) {
  const statusFile = path.join(root, 'STATUS.md');
  if (field(statusFile, 'status') !== 'done') {
    const planFile = path.join(root, 'plan.md');
    const slug = slugof(planFile) || field(statusFile, 'slug') || '(unknown)';
    items.push(mkItem(taskof(planFile), slug, 'active slot',
                      field(statusFile, 'verified'), field(statusFile, 'retro')));
  }
}

// Parked tasks awaiting retro. Sorted by bytes to match the bash glob under
// LC_ALL=C (a Hangul slug would diverge under locale collation).
let parkedDirs = [];
try {
  parkedDirs = fs.readdirSync(path.join(root, 'executed'), { withFileTypes: true })
    .filter((e) => e.isDirectory()).map((e) => e.name)
    .sort((a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b)));
} catch (_) { parkedDirs = []; }

for (const name of parkedDirs) {
  const d = path.join(root, 'executed', name);
  const planFile = path.join(d, 'plan.md');
  const statusFile = path.join(d, 'STATUS.md');
  const slug = slugof(planFile) || field(statusFile, 'slug') || name;
  items.push(mkItem(taskof(planFile), slug, 'parked (executed/)',
                    field(statusFile, 'verified'), field(statusFile, 'retro')));
}

// --- Goal loop ---------------------------------------------------------------
let loopLine = '';
const loopFile = path.join(root, 'loop.md');
if (fs.existsSync(loopFile)) {
  const first = (read(loopFile).split('\n')[0] || '');
  const goal = first
    .replace(/^#[ \t]*/, '')
    .replace(/^LOOP[ \t]*/, '')
    .replace(/^—[ \t]*/, '')
    .replace(/^-+[ \t]*/, '')
    .replace(/[ \t]+$/, '') || '(unnamed goal)';
  const wall = field(loopFile, 'wall');
  loopLine = (!wall || wall === 'none')
    ? `Goal loop: ${goal} — in flight`
    : `Goal loop: ${goal} — wall: ${wall}`;
}

// --- Silence when there is nothing owed --------------------------------------
if (items.length === 0 && !loopLine) process.exit(0);

// --- Backlog count (context only — never a reason to speak) ------------------
let queued = 0;
try {
  queued = fs.readdirSync(path.join(root, 'backlog')).filter((f) => f.endsWith('.md')).length;
} catch (_) { queued = 0; }

// --- Emit --------------------------------------------------------------------
const out = ['<forge-state>'];
if (items.length > 0) {
  out.push('Unfinished forge work (not sealed yet):');
  for (const it of items.slice(0, MAX_ITEMS)) out.push(it);
  if (items.length > MAX_ITEMS) {
    out.push(`  (+${items.length - MAX_ITEMS} more parked in ${disp}/executed/)`);
  }
}
if (loopLine) out.push(loopLine);
if (queued > 0) out.push(`Backlog: ${queued} plan(s) waiting.`);
out.push('');
out.push('You MUST surface this to the user in ONE line before starting any new work, and');
out.push('ask whether to close it first. `/forge:fg-next` derives and runs the owed step');
out.push('(verify / retro / seal). Do NOT auto-run or auto-seal anything.');
out.push('</forge-state>');

process.stdout.write(out.join('\n') + '\n');
process.exit(0);
