#!/usr/bin/env node
// forge-status.js — node twin of forge-status.sh (ADR-0022 dual dispatch).
//
// Must produce output identical to forge-status.sh for the same .forge state,
// in both full and --table modes (guarded by forge-status.parity.test.sh).
// node is the fallback when bash is unavailable (e.g. PowerShell-blocked
// Windows where the .sh cannot run); bash stays the primary path.
//
// Why this exists (ADR-0020): the deterministic survey + 6-column table is a
// script so fg-status need not have an LLM re-derive it; the next-step priority
// machine stays in fg-status's prose (this script never derives the next step).
//
// Usage:  node forge-status.js [--table]
'use strict';

const fs = require('fs');
const path = require('path');
const { resolveForgeRoot } = require('./resolve-forge-root.js');

const DONE_ROWS = 5;
const tableOnly = process.argv[2] === '--table';

// --- Resolve forge root via the shared resolver (ADR-0011 / ADR-0022) --------
const root = resolveForgeRoot().root;

const isDir = (p) => { try { return fs.statSync(p).isDirectory(); } catch (_) { return false; } };
const isFile = (p) => { try { return fs.statSync(p).isFile(); } catch (_) { return false; } };
const read = (p) => { try { return fs.readFileSync(p, 'utf8'); } catch (_) { return ''; } };

if (!isDir(root)) {
  process.stdout.write(`No forge state (no ${root}/). Start a task with fg-ask.\n`);
  process.exit(0);
}

// --- Field extractors (accept both `field:` and `- field:` forms) -----------
function field(file, name) {
  if (!isFile(file)) return '';
  const re = new RegExp(`^[\\t ]*-?[\\t ]*${name}:[\\t ]*(\\S*)`, 'm');
  const m = read(file).match(re);
  return m ? m[1] : '';
}
function slugof(file) {
  const m = read(file).match(/forge-slug:[\t ]*(\S*)[\t ]*-->/);
  return m ? m[1] : '';
}
function taskof(file) {
  const m = read(file).match(/task:[\t ]*([0-9]+)/);
  return m ? m[1] : '';
}
function looptag(file) {
  return /generated-by:[\t ]*fg-loop/.test(read(file)) ? ' (loop)' : '';
}
function vsym(v) {
  switch (v) {
    case 'yes': return 'O';
    case 'skipped': case 'n/a': return '~';
    case 'failed': return 'x';
    default: return '-';
  }
}
function retroFileExists(slug) {
  const dir = path.join(root, 'retro');
  if (!isDir(dir)) return false;
  return fs.readdirSync(dir).some((f) => f.endsWith(`-${slug}.md`));
}
function rsym(r, slug) {
  if (r === 'skipped') return 'X';
  if (r === '' || r === 'pending') return retroFileExists(slug) ? 'O' : '-';
  return 'O'; // a retro path
}

const lsMd = (dir) => (isDir(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.md')).sort() : []);
const subDirs = (dir) => (isDir(dir)
  ? fs.readdirSync(dir).filter((f) => isDir(path.join(dir, f))).sort()
  : []);

// --- Collect rows -----------------------------------------------------------
const rows = [];
const addRow = (no, date, task, stage, v, r) => rows.push([no, date, task, stage, v, r]);

// Active slot
const planPath = path.join(root, 'plan.md');
if (isFile(planPath)) {
  let slug = slugof(planPath) || 'plan';
  let no = taskof(planPath); no = no ? `#${no}` : '-';
  const tag = looptag(planPath);
  const st = path.join(root, 'STATUS.md');
  if (isFile(path.join(root, 'run.md'))) {
    let date = field(st, 'executed') || '-';
    addRow(no, date, `${slug}${tag}`, 'learn', vsym(field(st, 'verified')), rsym(field(st, 'retro'), slug));
  } else {
    addRow(no, '-', `${slug}${tag}`, 'run', '-', '-');
  }
}

// Backlog — ordered by fg-run's selection contract: priority(high→med→low) →
// part N → slug (NOT filename glob order, which misorders priorities and 10+ parts
// vs how fg-run actually runs — ADR-0022 review). Mirrors the .sh `LC_ALL=C sort`.
const prioRank = (txt) => { const m = txt.match(/priority:[\t ]*([A-Za-z]+)/); const p = m ? m[1] : ''; return p === 'high' ? 0 : p === 'low' ? 2 : 1; };
const partPad = (txt) => { const m = txt.match(/part:[\t ]*([0-9]+)\//); return m ? String(m[1]).padStart(3, '0') : '000'; };
const backlogDir = path.join(root, 'backlog');
if (isDir(backlogDir)) {
  const entries = fs.readdirSync(backlogDir).filter((f) => f.endsWith('.md')).map((f) => {
    const fp = path.join(backlogDir, f);
    const txt = read(fp);
    const slug = slugof(fp) || path.basename(f, '.md');
    return { key: `${prioRank(txt)}\t${partPad(txt)}\t${slug}`, fp, slug };
  });
  entries.sort((a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
  for (const e of entries) {
    let no = taskof(e.fp); no = no ? `#${no}` : '-';
    addRow(no, '-', `${e.slug}${looptag(e.fp)}`, 'ask', '-', '-');
  }
}

// Awaiting retro (executed/)
for (const d of subDirs(path.join(root, 'executed'))) {
  const dir = path.join(root, 'executed', d);
  const p = path.join(dir, 'plan.md');
  const st = path.join(dir, 'STATUS.md');
  let slug = slugof(p) || d;
  let no = taskof(p); no = no ? `#${no}` : '-';
  let date = field(st, 'executed') || '-';
  addRow(no, date, `${slug}${looptag(p)}`, 'learn', vsym(field(st, 'verified')), rsym(field(st, 'retro'), slug));
}

// Done (most recent DONE_ROWS by directory name, which is date-prefixed)
let doneTotal = 0;
const doneRoot = path.join(root, 'done');
if (isDir(doneRoot)) {
  const dirs = subDirs(doneRoot);
  doneTotal = dirs.length;
  const recent = dirs.slice().sort().reverse().slice(0, DONE_ROWS);
  for (const name of recent) {
    const dir = path.join(doneRoot, name);
    const date = name.slice(0, 10);
    const p = path.join(dir, 'plan.md');
    const st = path.join(dir, 'STATUS.md');
    let slug = slugof(p) || name.slice(11);
    let no = taskof(p); no = no ? `#${no}` : '-';
    addRow(no, date, `${slug}${looptag(p)}`, 'done', vsym(field(st, 'verified')), rsym(field(st, 'retro'), slug));
  }
}

// --- Emit table (replicate the .sh `LC_ALL=C awk` aligner) ------------------
// Pad by UTF-8 BYTE length, not String.length: the bash twin aligns with
// `LC_ALL=C awk` whose length() counts bytes, so a multibyte (e.g. Hangul) slug
// would otherwise pad differently here and break sh↔js parity (ADR-0022 review).
const blen = (s) => Buffer.byteLength(s || '', 'utf8');
const padBytes = (s, w) => (s || '') + ' '.repeat(Math.max(0, w - blen(s)));
const header = ['No.', 'Date', 'Task', 'Stage', 'Verify', 'Retro'];
const all = [header, ...rows];
const ncol = header.length;
const width = [];
for (let c = 0; c < ncol; c++) {
  width[c] = Math.max(...all.map((r) => blen(r[c])));
}
const lines = all.map((r) =>
  r.map((cell, c) => padBytes(cell, width[c])).join('  ').replace(/\s+$/, ''));
process.stdout.write(lines.join('\n') + '\n');

if (tableOnly) process.exit(0);

// --- Footer (counts + loop), full mode only ---------------------------------
let quickN = 0;
const logPath = path.join(root, 'quick', 'LOG.md');
if (isFile(logPath)) {
  quickN = read(logPath).split('\n').filter((l) => /^## /.test(l)).length;
}
const retroN = lsMd(path.join(root, 'retro')).length;
let adrDir = path.join(root, 'adr');
if (!isDir(adrDir)) adrDir = '.forge/adr';
const adrN = lsMd(adrDir).length;

let footer = `done: ${doneTotal} · quick: ${quickN} · retro: ${retroN} · adr: ${adrN}`;
const loopPath = path.join(root, 'loop.md');
if (isFile(loopPath)) {
  const rnd = field(loopPath, 'replan-round');
  const cap = field(loopPath, 'replan-cap');
  if (rnd && cap) footer += ` · loop: r${rnd}/${cap}`;
}
process.stdout.write('\n' + footer + '\n');
