#!/usr/bin/env node
// forge-statusline-full.js — node twin of forge-statusline-full.sh (ADR-0022 dual
// dispatch; "merge" mode / method 2, ADR-0029). Emits identical line(s) to the
// .sh for the same state (guarded by forge-statusline-full.parity.test.sh). node
// is the fallback where bash can't run the .sh (PowerShell-blocked Windows).
//
// Layout (see the .sh header for the full spec):
//   Line 1: <model> · <effort> · <dir> · ⎇ <branch [↑ahead] [↓behind] [+staged] [!modified] [?untracked]>
//   Line 2: Ctx <bar> N% [· 5h <bar> N% (~H)] [· 7d <bar> N% (~H)] [· ⏱ (D)]
//   Line 3/4: forge progress — DELEGATED to forge-statusline.js (default '⚒ ' prefix).
//
// System JSON is read with JSON.parse (the nested rate_limits/context_window
// leaves the .sh must parent-anchor by hand are trivial here). Time via
// FORGE_SL_NOW (epoch s) or Date.now(). Colors stripped in tests (ADR-0017).
'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

// --- colors (live-tuned; stripped in tests) ----------------------------------
const C = {
  green: '\x1b[32m', yellow: '\x1b[33m', red: '\x1b[31m',
  model: '\x1b[1;36m', dir: '\x1b[36m', git: '\x1b[35m', reset: '\x1b[0m',
};
function effColor(l) {
  return l === 'low' ? C.green : l === 'medium' ? C.dir
    : l === 'high' ? C.yellow : l === 'max' ? C.red : C.reset;
}

// --- read session JSON on stdin ----------------------------------------------
let input = '';
if (!process.stdin.isTTY) { try { input = fs.readFileSync(0, 'utf8'); } catch (_) { input = ''; } }
let data = {};
try { data = JSON.parse(input); } catch (_) { data = {}; }

const now = process.env.FORGE_SL_NOW ? Number(process.env.FORGE_SL_NOW) : Math.floor(Date.now() / 1000);

function floorInt(v) {
  if (v === null || v === undefined || v === '') return 0;
  const n = Math.floor(Number(v));
  return Number.isFinite(n) ? n : 0;
}
function bar(p) {
  let filled = Math.floor((p + 5) / 10);
  if (filled > 10) filled = 10; if (filled < 0) filled = 0;
  const col = p >= 90 ? C.red : p >= 70 ? C.yellow : C.green;
  return `${col}${'█'.repeat(filled)}${'░'.repeat(10 - filled)}${C.reset} ${p}%`;
}
function humanize(s) {
  if (s < 0) s = 0;
  if (s > 86400) return `${Math.floor(s / 86400)}d ${Math.floor((s % 86400) / 3600)}h`;
  const m = Math.floor(s / 60);
  return m < 60 ? `${m}m` : `${Math.floor(m / 60)}h ${m % 60}m`;
}

// --- cwd resolution (same as the fragment) -----------------------------------
if (input) {
  const cwd = data.cwd || (data.workspace && data.workspace.current_dir) || data.current_dir || '';
  try { if (cwd && fs.statSync(cwd).isDirectory()) process.chdir(cwd); } catch (_) { /* keep cwd */ }
}

// --- Line 1: model · effort · dir · ⎇ git ------------------------------------
const model = (data.model && data.model.display_name) || '';
const effort = (data.effort && data.effort.level) || '';
const dir = path.basename(process.cwd());

const seg1 = [];
if (model) seg1.push(`${C.model}${model}${C.reset}`);
if (effort) seg1.push(`${effColor(effort)}${effort}${C.reset}`);
seg1.push(`${C.dir}${dir}${C.reset}`);

let branch = '';
try {
  branch = execFileSync('git', ['rev-parse', '--abbrev-ref', 'HEAD'], { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
} catch (_) { branch = ''; }
if (branch && branch !== 'HEAD') {
  const cnt = (args) => {
    try { return execFileSync('git', args, { stdio: ['ignore', 'pipe', 'ignore'] }).toString().split('\n').filter(Boolean).length; }
    catch (_) { return 0; }
  };
  const st = cnt(['diff', '--cached', '--name-only']);
  const md = cnt(['diff', '--name-only']);
  const ut = cnt(['ls-files', '--others', '--exclude-standard']);
  let g = `⎇ ${branch}`;
  // ahead/behind vs upstream: left-right count emits "<behind>\t<ahead>"
  // (left = upstream-only, right = HEAD-only). No upstream -> command fails
  // (stderr suppressed) -> ↑↓ omitted entirely.
  let ab = '';
  try {
    ab = execFileSync('git', ['rev-list', '--left-right', '--count', '@{upstream}...HEAD'], { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
  } catch (_) { ab = ''; }
  if (ab) {
    const parts = ab.split(/\s+/);
    const behind = Number(parts[0]) || 0;
    const ahead = Number(parts[1]) || 0;
    if (ahead > 0) g += ` ↑${ahead}`;
    if (behind > 0) g += ` ↓${behind}`;
  }
  if (st > 0) g += ` +${st}`;
  if (md > 0) g += ` !${md}`;
  if (ut > 0) g += ` ?${ut}`;
  seg1.push(`${C.git}${g}${C.reset}`);
}
const line1 = seg1.join(' · ');

// --- Line 2: Ctx · 5h · 7d · ⏱ ------------------------------------------------
const ctx = floorInt(data.context_window && data.context_window.used_percentage);
const seg2 = [`Ctx ${bar(ctx)}`];

const rl = data.rate_limits || {};
if (rl.five_hour) {
  seg2.push(`5h ${bar(floorInt(rl.five_hour.used_percentage))} (~${humanize(floorInt(rl.five_hour.resets_at) - now)})`);
}
if (rl.seven_day) {
  seg2.push(`7d ${bar(floorInt(rl.seven_day.used_percentage))} (~${humanize(floorInt(rl.seven_day.resets_at) - now)})`);
}
// ⏱ session elapsed: cost.total_duration_ms floored to seconds, humanized.
// Omitted when cost/total_duration_ms is absent; an explicit 0 renders "⏱ (0m)".
if (data.cost && data.cost.total_duration_ms != null) {
  seg2.push(`⏱ (${humanize(Math.floor(floorInt(data.cost.total_duration_ms) / 1000))})`);
}
const line2 = seg2.join(' · ');

// --- Line 3/4: forge progress, DELEGATED to the fragment (default '⚒ ' prefix) --
let forgeOut = '';
try {
  forgeOut = execFileSync('node', [path.join(__dirname, 'forge-statusline.js')], {
    input,
    stdio: ['pipe', 'pipe', 'ignore'],
  }).toString().replace(/\n$/, '');
} catch (_) { forgeOut = ''; }

// --- Emit: system lines always; forge lines only when non-empty --------------
const out = [line1, line2];
if (forgeOut) out.push(forgeOut);
process.stdout.write(out.join('\n') + '\n');
