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

if (!isDir(root) && process.argv[2] !== '--json') {
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
// Normalize a STATUS field token before deciding on it — see the .sh twin.
const norm = (v) => (String(v || '').toLowerCase().match(/^[a-z/]*/) || [''])[0];
function vsym(v) {
  switch (norm(v)) {
    case 'yes': return 'O';
    case 'skipped': case 'n/a': return '~';
    case 'failed': return 'x';
    default: return '-';
  }
}
// EXACT match, not a `*-<slug>.md` suffix glob — see the .sh twin's comment.
const RETRO_PREFIX = /^(\d{6}-\d{6}[a-z]?|\d{4}-\d{2}-\d{2})$/;
function retroFileExists(slug) {
  const dir = path.join(root, 'retro');
  if (!isDir(dir)) return false;
  const suffix = `-${slug}.md`;
  return fs.readdirSync(dir)
    .some((f) => f.endsWith(suffix) && RETRO_PREFIX.test(f.slice(0, -suffix.length)));
}
function rsym(r, slug) {
  const n = norm(r);
  if (n === 'skipped') return 'X';
  if (n === '' || n === 'pending') return retroFileExists(slug) ? 'O' : '-';
  return 'O'; // a retro path
}

const lsMd = (dir) => (isDir(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.md')).sort() : []);
const subDirs = (dir) => (isDir(dir)
  ? fs.readdirSync(dir).filter((f) => isDir(path.join(dir, f))).sort()
  : []);

// JSON is a survey API, deliberately not a second next-step state machine.
function emitJson() {
  const full = (file, key) => {
    const m = read(file).replace(/\r\n/g, '\n').match(new RegExp(`^[\\t ]*-?[\\t ]*${key}:[\\t ]*([^\\n]*)`, 'm'));
    return m && m[1].trim() ? m[1].trim() : null;
  };
  const title = (file) => { const m = read(file).match(/^# ([^\n]*)/m); return m ? m[1].trim() || null : null; };
  const content = (file) => read(file).replace(/\r\n/g, '\n').replace(/\n+$/, '');
  const byteOrder = (a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b));
  const tasks = [];
  function task(location, dir, plan) {
    const st = path.join(dir, 'STATUS.md');
    const name = path.basename(dir);
    const fallback = location === 'active' ? 'plan' : location === 'backlog' ? path.basename(plan, '.md') : name.replace(/^(\d{6}-\d{6}[a-z]?|\d{4}-\d{2}-\d{2})-/, '');
    tasks.push({location, path: plan, slug: slugof(plan) || full(st, 'slug') || fallback,
      task: taskof(plan) ? Number(taskof(plan)) : null, title: title(plan),
      status: full(st, 'status'), verified: full(st, 'verified'), retro: full(st, 'retro'),
      executed: full(st, 'executed'), completed: full(st, 'completed'),
      hasRun: location !== 'backlog' && isFile(path.join(dir, 'run.md')), generatedByLoop: !!looptag(plan)});
  }
  if (isFile(path.join(root, 'plan.md'))) task('active', root, path.join(root, 'plan.md'));
  for (const f of lsMd(path.join(root, 'backlog')).sort(byteOrder)) task('backlog', path.join(root, 'backlog'), path.join(root, 'backlog', f));
  for (const location of ['executed', 'done']) for (const d of subDirs(path.join(root, location)).sort(byteOrder)) {
    const dir = path.join(root, location, d); task(location, dir, path.join(dir, 'plan.md'));
  }
  const loopFile = path.join(root, 'loop.md');
  const loop = isFile(loopFile) ? {path: loopFile, goal: (title(loopFile) || '').replace(/^LOOP — /, '') || null,
    wall: full(loopFile, 'wall'), replanRound: full(loopFile, 'replan-round'), replanCap: full(loopFile, 'replan-cap'),
    budgetTokens: full(loopFile, 'budget-tokens'), budgetSpent: full(loopFile, 'budget-spent'), retro: full(loopFile, 'retro'), content: content(loopFile)} : null;
  const runningFile = path.join(root, 'running.md');
  const running = isFile(runningFile) ? {path: runningFile, content: content(runningFile)} : null;
  const ledger = path.join(root, 'followups.md');
  let ledgerStat;
  try { ledgerStat = fs.lstatSync(ledger); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  if (ledgerStat && !ledgerStat.isFile()) throw Error('ledger is not a regular file');
  const followups = ledgerStat ? require('./forge-followups.js').parse(fs.readFileSync(ledger, 'utf8')).map(e => ({...e, task: e.task === '-' ? null : Number(e.task), taken: e.taken === '-' ? null : Number(e.taken)})) : [];
  const counts = {};
  for (const location of ['active', 'backlog', 'executed', 'done']) counts[location] = tasks.filter(t => t.location === location).length;
  counts.quick = read(path.join(root, 'quick', 'LOG.md')).split('\n').filter(l => /^## /.test(l)).length;
  counts.retro = lsMd(path.join(root, 'retro')).length;
  counts.adr = lsMd(isDir(path.join(root, 'adr')) ? path.join(root, 'adr') : '.forge/adr').length;
  counts.followups = Object.fromEntries(['open', 'taken', 'dismissed'].map(s => [s, followups.filter(f => f.status === s).length]));
  process.stdout.write(JSON.stringify({schemaVersion: 1, root, exists: isDir(root), tasks, running, loop, counts, followups}) + '\n');
}
if (process.argv[2] === '--json') {
  try { emitJson(); } catch (error) { process.stderr.write(`forge-status: ${error.message}\n`); process.exit(1); }
  process.exit(0);
}

// The monitor and human-readable CLI share the same state survey.
const { surveyForge } = require("./forge-status-query.js");
const { rows, footer } = surveyForge(root);

// --- Emit table (replicate the .sh `LC_ALL=C awk` aligner) ------------------
// Pad by UTF-8 BYTE length, not String.length: the bash twin aligns with
// `LC_ALL=C awk` whose length() counts bytes, so a multibyte (e.g. Hangul) slug
// would otherwise pad differently here and break sh↔js parity (ADR-0022 review).
// Exception, mirrored in the .sh: the 3-byte "✔" on sealed rows counts as one column.
const blen = (s) => Buffer.byteLength(s || '', 'utf8') - 2 * ((s || '').split('✔').length - 1);
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

process.stdout.write('\n' + footer + '\n');
