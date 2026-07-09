#!/usr/bin/env node
// forge-statusline-full.js — node twin of forge-statusline-full.sh (ADR-0022;
// "merge" mode / method 2, ADR-0029). Emits identical line(s) to the .sh for the
// same state (guarded by forge-statusline-full.parity.test.sh).
//
// Grouped [ ... ] layout with " | " intra-group separators (method 2 always uses
// "|"; the delegated fragment gets FORGE_SL_SEP="|"). Density is the positional
// arg argv[2] ("full" default / "compact"). See the .sh header for the full spec:
// full = system+session / usage bars / forge / queue (4 lines); compact = system
// + usage bars on one line + the fragment's single compact group (session group
// dropped). New fields: Context/<size>, dynamic emoji, gradient bars, $cost, ±lines.
//
// System JSON via JSON.parse. Time via FORGE_SL_NOW (epoch s) or Date.now().
// Colors stripped in tests (ADR-0017).
'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const DENSITY = process.argv[2] === 'compact' ? 'compact' : 'full';
const SEP = '|';

// --- colors (live-tuned; stripped in tests) ----------------------------------
const C = {
  model: '\x1b[35m', branch: '\x1b[36m', cost: '\x1b[33m',
  add: '\x1b[32m', del: '\x1b[31m', dim: '\x1b[2m', reset: '\x1b[0m',
};
function effColor(l) {
  return l === 'low' ? '\x1b[32m' : l === 'medium' ? '\x1b[36m'
    : l === 'high' ? '\x1b[33m' : l === 'max' ? '\x1b[31m' : C.reset;
}

// grp(...parts) -> "[ a | b ]" (dim brackets/separators); empty parts dropped.
function grp(...parts) {
  const kept = parts.filter((p) => p !== undefined && p !== null && p !== '');
  if (kept.length === 0) return '';
  return `${C.dim}[${C.reset}${kept.join(` ${C.dim}${SEP}${C.reset} `)}${C.dim}]${C.reset}`;
}
function joinGroups(...groups) { return groups.filter(Boolean).join(' '); }

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
function emoji(p) { return p >= 90 ? '🚨' : p >= 70 ? '🔥' : p >= 20 ? '⚡' : '🟢'; }
function gradCell(i) {
  let r, g, b;
  if (i < 5) { r = 40 + i * 36; g = 200; b = 90 - i * 10; }
  else { r = 220; g = 200 - (i - 5) * 38; b = 40; }
  return `\x1b[38;2;${r};${g};${b}m`;
}
function bar(p) {
  let filled = Math.floor((p + 5) / 10);
  if (filled > 10) filled = 10; if (filled < 0) filled = 0;
  let out = '';
  for (let i = 0; i < filled; i++) out += `${gradCell(i)}█`;
  for (let i = filled; i < 10; i++) out += `${C.dim}░`;
  return `${out}${C.reset} ${p}%`;
}
function humanize(s) {
  if (s < 0) s = 0;
  if (s > 86400) return `${Math.floor(s / 86400)}d ${Math.floor((s % 86400) / 3600)}h`;
  const m = Math.floor(s / 60);
  return m < 60 ? `${m}m` : `${Math.floor(m / 60)}h ${m % 60}m`;
}
function sizeLabel(s) {
  if (!s) return '';
  return s >= 1000000 ? `/${Math.floor(s / 1000000)}M` : `/${Math.floor((s + 500) / 1000)}K`;
}

// --- cwd resolution (same as the fragment) -----------------------------------
if (input) {
  const cwd = data.cwd || (data.workspace && data.workspace.current_dir) || data.current_dir || '';
  try { if (cwd && fs.statSync(cwd).isDirectory()) process.chdir(cwd); } catch (_) { /* keep cwd */ }
}

// --- System groups -----------------------------------------------------------
const model = (data.model && data.model.display_name) || '';
const effort = (data.effort && data.effort.level) || '';
const dir = path.basename(process.cwd());

const idParts = [];
if (model) idParts.push(`${C.model}${model}${C.reset}`);
if (effort) idParts.push(`${effColor(effort)}${effort}${C.reset}`);
const idGrp = grp(...idParts);

const locParts = [dir];
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
  locParts.push(`${C.branch}${g}${C.reset}`);
}
const locGrp = grp(...locParts);

// --- Usage-bars group --------------------------------------------------------
const cw = data.context_window || {};
const ctx = floorInt(cw.used_percentage);
const usageParts = [`${emoji(ctx)} Context${sizeLabel(floorInt(cw.context_window_size))} ${bar(ctx)}`];
const rl = data.rate_limits || {};
if (rl.five_hour) usageParts.push(`5h ${bar(floorInt(rl.five_hour.used_percentage))} (~${humanize(floorInt(rl.five_hour.resets_at) - now)})`);
if (rl.seven_day) usageParts.push(`7d ${bar(floorInt(rl.seven_day.used_percentage))} (~${humanize(floorInt(rl.seven_day.resets_at) - now)})`);
const usageGrp = grp(...usageParts);

// --- Session group (full only) -----------------------------------------------
const sessParts = [];
const cost = data.cost || null;
if (cost) {
  if (cost.total_duration_ms != null) sessParts.push(`⏱ (${humanize(Math.floor(floorInt(cost.total_duration_ms) / 1000))})`);
  if (cost.total_cost_usd != null) sessParts.push(`${C.cost}$${Number(cost.total_cost_usd).toFixed(2)}${C.reset}`);
  const la = floorInt(cost.total_lines_added);
  const lr = floorInt(cost.total_lines_removed);
  if (la > 0 || lr > 0) sessParts.push(`${C.add}+${la}${C.reset} ${C.del}−${lr}${C.reset}`);
}
const sessGrp = grp(...sessParts);

// --- forge lines, DELEGATED to the fragment (SEP=|, density passed) ----------
let forgeOut = '';
try {
  forgeOut = execFileSync('node', [path.join(__dirname, 'forge-statusline.js')], {
    input,
    stdio: ['pipe', 'pipe', 'ignore'],
    env: Object.assign({}, process.env, { FORGE_SL_SEP: SEP, FORGE_SL_DENSITY: DENSITY }),
  }).toString().replace(/\n$/, '');
} catch (_) { forgeOut = ''; }

// --- Emit --------------------------------------------------------------------
const out = [];
if (DENSITY === 'compact') {
  out.push(joinGroups(idGrp, locGrp, usageGrp));
  if (forgeOut) out.push(forgeOut);
} else {
  out.push(joinGroups(idGrp, locGrp, sessGrp));
  out.push(usageGrp);
  if (forgeOut) out.push(forgeOut);
}
process.stdout.write(out.join('\n') + '\n');
