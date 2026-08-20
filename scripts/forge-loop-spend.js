#!/usr/bin/env node
// forge-loop-spend.js — node fallback twin of forge-loop-spend.sh (ADR-0022).
//
// Behavior, stdout tokens, and exit codes are IDENTICAL to the bash primary;
// forge-loop-spend.parity.test.sh guards that. See the .sh header for the full
// contract and for what the number means (a safety bound over project-wide
// throughput, not a billed cost — ADR-0016 amended 2026-08-19 / 2026-08-20).
//
// The two twins reach the same total by DIFFERENT routes on purpose: bash strips
// `iterations[]` out of the raw line, this one parses the structure. Two twins
// sharing one parsing strategy make the SAME mistake and parity still goes green —
// which is exactly how a 1.928x over-count shipped. Different routes to one number
// make the parity test an actual cross-check (ADR-0022 amended 2026-08-20).
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const { resolveForgeRoot } = require('./resolve-forge-root.js');

function die(msg) {
  process.stderr.write(`forge-loop-spend: ${msg}\n`);
  process.exit(64);
}
function out(line, code) {
  process.stdout.write(line + '\n');
  process.exit(code);
}

// --- args ---------------------------------------------------------------------
let tdir = '';
let now = '';
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--transcripts') { if (++i >= argv.length) die('--transcripts needs a value'); tdir = argv[i]; }
  else if (a === '--now') { if (++i >= argv.length) die('--now needs a value'); now = argv[i]; }
  else die(`unknown arg: ${a}`);
}

const root = resolveForgeRoot().root;
const loopPath = path.join(root, 'loop.md');
if (!fs.existsSync(loopPath)) out('EMPTY no-loop-md', 2);

// Full millisecond precision (no flooring — see the .sh header).
if (!now) now = new Date().toISOString();

const loopText = fs.readFileSync(loopPath, 'utf8');
// `\r` tolerated so a CRLF-authored loop.md parses (5 sibling scripts do the same).
const field = (name) => {
  const m = loopText.match(new RegExp(`^${name}:[ \\t]*(.*)$`, 'm'));
  return m ? m[1].replace(/\r/g, '') : '';
};

// --- contract fields ----------------------------------------------------------
let capRaw = field('budget-tokens');
if (!capRaw) capRaw = 'none';
if (/^(none|None|NONE)(?![A-Za-z0-9])/.test(capRaw)) out('NONE no-budget-declared', 0);
// Leading token, trailing annotation tolerated (the template annotates inline, and
// rejecting the line would let the ceiling fail OPEN). Unparseable => BLOCKED.
const capTok = capRaw.match(/^[0-9]+/);
if (!capTok) out(`BLOCKED cap-unparseable (${capRaw})`, 5);
const cap = parseInt(capTok[0], 10);   // base 10 forced: `0100` is 100, not octal 64
if (!(cap > 0)) out(`BLOCKED cap-not-positive (${capRaw})`, 5);

const spentRaw = field('budget-spent');
const mPrev = spentRaw.match(/^([0-9]+)/);
const spentPrev = mPrev ? parseInt(mPrev[1], 10) : 0;
const mSince = spentRaw.match(/since:[ \t]*([^ \t]+)/);
let since = mSince ? mSince[1] : '';

// A present-but-unparseable `since:` (the template placeholder `{ISO}` is the real
// case) sorts above every timestamp, so the delta is silently 0 forever.
let baseline = false;
if (!since) { since = now; baseline = true; }
else if (!/^[0-9]{4}-[0-9]{2}-[0-9]{2}T/.test(since)) out(`BLOCKED since-unparseable (${since})`, 5);

// --- locate transcripts -------------------------------------------------------
// Session CWD with EVERY non-alphanumeric replaced by `-` (verified against real
// dirs; the git toplevel and a `/`-only substitution were both wrong).
if (!tdir) {
  const home = os.homedir();
  if (!home) out('BLOCKED transcripts-unreadable (HOME unset)', 5);
  let cwd;
  try { cwd = fs.realpathSync(process.cwd()); } catch (_) { cwd = process.cwd(); }
  tdir = path.join(home, '.claude', 'projects', cwd.replace(/[^A-Za-z0-9]/g, '-'));
}
// Checked BEFORE the baseline shortcut, so an unmeasurable ceiling surfaces at the
// start of a drive rather than several tasks in.
if (!fs.existsSync(tdir) || !fs.statSync(tdir).isDirectory()) {
  out(`BLOCKED transcripts-unreadable (${tdir})`, 5);
}

// --- sum the delta ------------------------------------------------------------
const FIELDS = ['input_tokens', 'cache_creation_input_tokens', 'cache_read_input_tokens', 'output_tokens'];

function walk(dir, acc) {
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (_) { return acc; }
  for (const e of ents) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, acc);
    else if (e.isFile() && e.name.endsWith('.jsonl')) acc.push(p);
  }
  return acc;
}

let delta = 0;
if (!baseline) {
  for (const f of walk(tdir, []).sort()) {
    let text;
    try { text = fs.readFileSync(f, 'utf8'); } catch (_) { continue; }
    for (const line of text.split('\n')) {
      if (line.indexOf('"usage"') === -1) continue;
      let obj;
      try { obj = JSON.parse(line); } catch (_) { continue; }
      if (!obj || typeof obj !== 'object') continue;
      if (typeof obj.timestamp !== 'string' || obj.timestamp <= since) continue;
      // Only this entry's own message.usage. `toolUseResult.usage` is a subagent
      // figure echoed into the parent transcript and already counted from that
      // subagent's own file; `usage.iterations[]` mirrors the same four fields.
      // Reading the structure excludes both without any pattern surgery.
      const u = obj.message && obj.message.usage;
      if (!u || typeof u !== 'object') continue;
      for (const fl of FIELDS) {
        const v = u[fl];
        if (typeof v === 'number' && Number.isFinite(v)) delta += v;
      }
    }
  }
}

const spent = spentPrev + delta;
let remaining = cap - spent;
if (remaining < 0) remaining = 0;

// --- write the ledger back ----------------------------------------------------
// First occurrence only (bash used to replace every matching line via a global sed).
// `[^\n]*`, NOT `.*$`: in JS regex `\r` is a LINE TERMINATOR, so `.` will not match
// it and `$` (multiline) stops before it — the rewritten line would keep the original
// `\r` while awk, which splits records on `\n` only, drops it. Same visible text,
// different bytes, and the parity diff caught exactly that.
let next;
if (/^budget-spent:/m.test(loopText)) {
  next = loopText.replace(/^budget-spent:[^\n]*/m, `budget-spent: ${spent} · since: ${now}`);
} else {
  next = loopText.replace(/^budget-tokens:[^\n]*/m, `budget-tokens: ${cap}\nbudget-spent: ${spent} · since: ${now}`);
}
try { fs.writeFileSync(loopPath, next); } catch (_) { out('BLOCKED ledger-write-failed', 5); }

// --- judge --------------------------------------------------------------------
if (spent >= cap) out(`EXHAUSTED spent=${spent} cap=${cap}`, 3);

// Pre-flight: refuse to START a task the remaining budget probably cannot cover.
// Observed per-task average = spend / member tasks already sealed; the first task has
// no average and always starts (worst-case overshoot bounded at one task).
// Anchor with (?:^|\n) rather than the `m` flag: with `m`, `$` in the lookahead
// matches EVERY line end and the lazy capture stopped after the first member
// (bash read all of them) — that divergence flipped pre-flight between the twins.
// Dropping `m` without re-anchoring is the opposite bug: `^` then means
// start-of-string only, so the section never matches at all.
const sec = loopText.match(/(?:^|\n)## Tasks[^\n]*\n([\s\S]*?)(?=\n## |$)/);
const members = sec
  ? sec[1].split('\n').map((l) => {
      const m = l.replace(/\r/g, '').match(/^[ \t]*-[ \t]*(.*)$/);
      if (!m) return '';
      return m[1].replace(/^\[[ xX]\][ \t]*/, '').replace(/^`/, '').replace(/`.*$/, '').split(/[ \t]/)[0];
    }).filter((x) => x && !x.startsWith('##'))
  : [];

let sealed = 0;
let doneDirs;
try { doneDirs = fs.readdirSync(path.join(root, 'done')); } catch (_) { doneDirs = []; }
for (const m of members) {
  for (const d of doneDirs) {
    const st = path.join(root, 'done', d, 'STATUS.md');
    let txt;
    try { txt = fs.readFileSync(st, 'utf8'); } catch (_) { continue; }
    // Exact STATUS `slug:` match — the old `*-<slug>` glob also matched
    // `2026-08-19-fix-alpha` for member `alpha`, inflating sealed and lowering avg.
    const sm = txt.match(/^slug:[ \t]*(.*)$/m);
    if (!sm || sm[1].replace(/\r/g, '').trim() !== m) continue;
    if (/^status: done/m.test(txt)) sealed++;
    break;
  }
}
if (sealed > 0) {
  const avg = Math.floor(spent / sealed);
  if (remaining < avg) out(`PREFLIGHT-HALT spent=${spent} cap=${cap} avg=${avg} remaining=${remaining}`, 4);
}

out(`OK spent=${spent} cap=${cap} remaining=${remaining}`, 0);
