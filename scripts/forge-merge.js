#!/usr/bin/env node
// forge-merge.js — node twin of forge-merge.sh (ADR-0022 dual dispatch).
// Identical behavior to the .sh for the same input state — exit codes AND the
// resulting .forge/ tree (guarded by forge-merge.parity.test.sh). node is the
// fallback where bash can't run the .sh (PowerShell-blocked Windows).
//
// See forge-merge.sh's header for the full contract (gate-first, non-destructive
// on refuse; exit codes 0/2/3/4/6).
'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

// --- args --------------------------------------------------------------------
let branchArg = '', completed = '';
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--completed') completed = argv[++i] || '';
  else if (a[0] === '-') { process.stderr.write(`forge-merge: unknown arg: ${a}\n`); process.exit(64); }
  else branchArg = a;
}
if (!completed) {
  const d = new Date();
  completed = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
const die = (msg, code) => { process.stdout.write(msg + '\n'); process.exit(code); };
const log = (msg) => process.stdout.write(msg + '\n');

// --- resolve top-level forge root (integration target is always top-level) ----
let top = '';
try { top = cp.execSync('git rev-parse --show-toplevel', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim(); } catch (_) { top = ''; }
const prefix = top ? top + '/' : '';
const TARGET = prefix + '.forge';
const BRANCHES_DIR = path.join(TARGET, 'branch');

const isDir = (p) => { try { return fs.statSync(p).isDirectory(); } catch (_) { return false; } };
const exists = (p) => { try { fs.statSync(p); return true; } catch (_) { return false; } };
const read = (p) => { try { return fs.readFileSync(p, 'utf8'); } catch (_) { return ''; } };
const ls = (dir) => { try { return fs.readdirSync(dir).sort(); } catch (_) { return []; } };

// --- resolve which branch root to integrate ----------------------------------
function isLeafRoot(p) {
  for (const m of ['adr', 'retro', 'done', 'backlog', 'dropped']) if (isDir(path.join(p, m))) return true;
  for (const m of ['CONTEXT.md', 'plan.md', 'run.md', 'STATUS.md', 'loop.md']) if (exists(path.join(p, m))) return true;
  return false;
}
function findLeafRoots() {
  const out = [];
  if (!isDir(BRANCHES_DIR)) return out;
  for (const a of ls(BRANCHES_DIR)) {
    const pa = path.join(BRANCHES_DIR, a);
    if (!isDir(pa)) continue;
    if (isLeafRoot(pa)) out.push(pa);
    for (const b of ls(pa)) { const pb = path.join(pa, b); if (isDir(pb) && isLeafRoot(pb)) out.push(pb); }
  }
  return out;
}
let SRC;
if (branchArg) {
  SRC = path.join(BRANCHES_DIR, branchArg);
  if (!(isDir(SRC) && isLeafRoot(SRC))) die(`EMPTY no-branch-root branch=${branchArg}`, 2);
} else {
  const roots = findLeafRoots();
  if (roots.length === 0) die('EMPTY nothing-to-integrate', 2);
  else if (roots.length === 1) SRC = roots[0];
  else { log('AMBIGUOUS several-branch-roots:'); roots.forEach((r) => log(r)); process.exit(6); }
}

// --- helpers -----------------------------------------------------------------
const slugof = (f) => { const m = read(f).match(/forge-slug:[ \t]*(\S*)[ \t]*-->/); return m ? m[1].replace(/\r/g, '') : ''; };
const taskof = (f) => { const m = read(f).match(/task:[ \t]*(\d+)/); return m ? m[1] : ''; };
const isTimebased = (bn) => /^\d{6}-\d{2}[a-z]+-/.test(bn) || /^\d{6}-\d{6}[a-z]?-/.test(bn);
const isNnnn = (bn) => /^\d{4}-/.test(bn);
function ctxTerms(f) {
  if (!exists(f)) return [];
  return read(f).split('\n').filter((l) => l.startsWith('## ')).map((l) => l.slice(3));
}
function ctxBodyLines(f, term) {
  const lines = read(f).split('\n'); const out = []; let inSec = false;
  for (const l of lines) {
    if (l === `## ${term}`) { inSec = true; continue; }
    if (l.startsWith('## ')) { if (inSec) break; continue; }
    if (inSec) out.push(l);
  }
  // command-substitution in the .sh strips trailing blank lines; mirror that for
  // the redefinition comparison by trimming trailing empties.
  while (out.length && out[out.length - 1] === '') out.pop();
  return out;
}

// --- GATE 1: in-flight branch state ------------------------------------------
let inflight = '';
if (exists(path.join(SRC, 'plan.md'))) inflight = 'active-slot(plan.md)';
if (!inflight && isDir(path.join(SRC, 'executed')) && ls(path.join(SRC, 'executed')).length) inflight = 'executed/';
if (!inflight && exists(path.join(SRC, 'loop.md'))) inflight = 'loop.md(goal contract)';
if (!inflight && exists(path.join(SRC, 'quick', 'LOG.md'))) {
  if (/^(- )?(result|결과)[ \t]*:[ \t]*pending/im.test(read(path.join(SRC, 'quick', 'LOG.md')))) inflight = 'quick(pending)';
}
if (inflight) die(`GATE_INFLIGHT ${inflight} branch=${SRC} — seal/recover/resume on the branch first`, 3);

// --- GATE 2: CONTEXT term redefinition ---------------------------------------
const srcCtx = path.join(SRC, 'CONTEXT.md'), tgtCtx = path.join(TARGET, 'CONTEXT.md');
if (exists(srcCtx) && exists(tgtCtx)) {
  const tgtTerms = ctxTerms(tgtCtx);
  for (const term of ctxTerms(srcCtx)) {
    if (!tgtTerms.includes(term)) continue;
    const sb = ctxBodyLines(srcCtx, term).join('\n'), tb = ctxBodyLines(tgtCtx, term).join('\n');
    if (sb !== tb) die(`GATE_CONFLICT context-term-redefinition term=[${term}] — human resolves`, 4);
  }
}

// --- GATE 3: incoming NNNN colliding with a frozen target --------------------
const srcAdr = path.join(SRC, 'adr');
if (isDir(srcAdr)) {
  for (const bn of ls(srcAdr)) {
    if (!bn.endsWith('.md') || !isNnnn(bn)) continue;
    const num = bn.match(/^(\d{4})-/)[1];
    const hit = (dir) => ls(dir).some((f) => f.startsWith(num + '-'));
    if (hit(path.join(TARGET, 'adr')) || hit(path.join(TARGET, 'adr', 'retired'))) {
      die(`GATE_CONFLICT incoming-NNNN-collides ADR-${num} (frozen target) — human resolves (no cascade renumber)`, 4);
    }
  }
}

// =============================================================================
// MUTATION PHASE
// =============================================================================
const MOVED = [];
const BUMPS = [];
const mkdirp = (p) => fs.mkdirSync(p, { recursive: true });
const mv = (src, dest) => fs.renameSync(src, dest);

function nextFreeLetter(dir, base) {
  const used = new Set();
  for (const f of ls(dir)) { const m = f.match(new RegExp('^' + base + '([a-z]+)-')); if (m) used.add(m[1]); }
  for (const c of 'abcdefghijklmnopqrstuvwxyz') if (!used.has(c)) return c;
  return 'aa';
}
function integrateAdrs() {
  if (!isDir(srcAdr)) return;
  mkdirp(path.join(TARGET, 'adr'));
  for (const bn of ls(srcAdr)) {
    const f = path.join(srcAdr, bn);
    if (!fs.statSync(f).isFile()) continue;
    if (isTimebased(bn)) {
      let id, rest, base;
      if (/^\d{6}-\d{6}[a-z]?-/.test(bn)) {                 // second-granularity (current)
        id = bn.match(/^(\d{6}-\d{6}[a-z]?)-/)[1];
        rest = bn.replace(/^\d{6}-\d{6}[a-z]?-/, '');
        base = id.replace(/(\d{6}-\d{6})[a-z]?/, '$1');
      } else {                                              // hour-granularity (grandfathered)
        id = bn.match(/^(\d{6}-\d{2}[a-z]+)-/)[1];
        rest = bn.replace(/^\d{6}-\d{2}[a-z]+-/, '');
        base = id.replace(/(\d{6}-\d{2})[a-z]+/, '$1');
      }
      const collide = exists(path.join(TARGET, 'adr', bn)) || ls(path.join(TARGET, 'adr')).some((x) => x.startsWith(id + '-'));
      if (collide) {
        const letter = nextFreeLetter(path.join(TARGET, 'adr'), base);
        const newid = base + letter, dest = path.join(TARGET, 'adr', `${newid}-${rest}`);
        log(`  adr collision: ${id} -> ${newid}`);
        BUMPS.push([id, newid]); mv(f, dest); MOVED.push(dest);
      } else { const dest = path.join(TARGET, 'adr', bn); mv(f, dest); MOVED.push(dest); }
    } else {
      const dest = path.join(TARGET, 'adr', bn); mv(f, dest); MOVED.push(dest); // NNNN collision gated out
    }
  }
  const srcRet = path.join(srcAdr, 'retired');
  if (isDir(srcRet)) {
    mkdirp(path.join(TARGET, 'adr', 'retired'));
    for (const bn of ls(srcRet)) { const f = path.join(srcRet, bn); if (fs.statSync(f).isFile()) mv(f, path.join(TARGET, 'adr', 'retired', bn)); }
  }
}
function integrateRetros() {
  const dir = path.join(SRC, 'retro'); if (!isDir(dir)) return;
  mkdirp(path.join(TARGET, 'retro'));
  for (const bn of ls(dir)) {
    const f = path.join(dir, bn); if (!fs.statSync(f).isFile()) continue;
    let dest = path.join(TARGET, 'retro', bn);
    if (exists(dest)) dest = path.join(TARGET, 'retro', bn.replace(/\.md$/, '-2.md'));
    mv(f, dest); MOVED.push(dest);
  }
}
function integrateContext() {
  if (!exists(srcCtx)) return;
  if (!exists(tgtCtx)) { fs.copyFileSync(srcCtx, tgtCtx); MOVED.push(tgtCtx); return; }
  const tgtTerms = ctxTerms(tgtCtx);
  for (const term of ctxTerms(srcCtx)) {
    if (tgtTerms.includes(term)) continue;
    const body = ctxBodyLines(srcCtx, term).map((l) => l + '\n').join('');
    fs.appendFileSync(tgtCtx, `\n## ${term}\n` + body);
  }
  MOVED.push(tgtCtx);
}
function integrateDoneAndBacklog() {
  let tmax = 0;
  const targPlans = [];
  for (const p of ls(path.join(TARGET, 'backlog'))) targPlans.push(path.join(TARGET, 'backlog', p));
  if (exists(path.join(TARGET, 'plan.md'))) targPlans.push(path.join(TARGET, 'plan.md'));
  for (const d of ls(path.join(TARGET, 'executed'))) targPlans.push(path.join(TARGET, 'executed', d, 'plan.md'));
  for (const d of ls(path.join(TARGET, 'done'))) targPlans.push(path.join(TARGET, 'done', d, 'plan.md'));
  for (const p of targPlans) { const n = parseInt(taskof(p), 10); if (n > tmax) tmax = n; }
  // incoming: done/*/plan.md then backlog/*.md, sorted by (oldn, path)
  const incoming = [];
  for (const d of ls(path.join(SRC, 'done'))) { const p = path.join(SRC, 'done', d, 'plan.md'); if (exists(p)) incoming.push(p); }
  for (const p of ls(path.join(SRC, 'backlog'))) { const fp = path.join(SRC, 'backlog', p); if (exists(fp)) incoming.push(fp); }
  incoming.sort((a, b) => { const na = parseInt(taskof(a) || '0', 10), nb = parseInt(taskof(b) || '0', 10); return na - nb || (a < b ? -1 : a > b ? 1 : 0); });
  for (const p of incoming) { tmax += 1; fs.writeFileSync(p, read(p).replace(/task:(\s*)\d+/, `task:$1${tmax}`)); }
  // fold done/
  if (isDir(path.join(SRC, 'done'))) {
    mkdirp(path.join(TARGET, 'done'));
    for (const bn of ls(path.join(SRC, 'done'))) {
      const d = path.join(SRC, 'done', bn); if (!isDir(d)) continue;
      let dest = path.join(TARGET, 'done', bn);
      if (exists(dest)) dest = path.join(TARGET, 'done', bn + '-2');
      mv(d, dest); MOVED.push(dest);
    }
  }
  // fold backlog/
  if (isDir(path.join(SRC, 'backlog'))) {
    mkdirp(path.join(TARGET, 'backlog'));
    for (const bn of ls(path.join(SRC, 'backlog'))) {
      const f = path.join(SRC, 'backlog', bn); if (!fs.statSync(f).isFile()) continue;
      let dest = path.join(TARGET, 'backlog', bn);
      if (exists(dest)) {
        dest = path.join(TARGET, 'backlog', bn.replace(/\.md$/, '-2.md'));
        const s = slugof(f);
        if (s) fs.writeFileSync(f, read(f).replace(new RegExp(`forge-slug:[ \\t]*${s}`), `forge-slug: ${s}-2`));
      }
      mv(f, dest); MOVED.push(dest);
    }
  }
}
function integrateDropped() {
  const dir = path.join(SRC, 'dropped'); if (!isDir(dir)) return;
  mkdirp(path.join(TARGET, 'dropped'));
  for (const bn of ls(dir)) {
    const d = path.join(dir, bn); if (!isDir(d)) continue;
    let dest = path.join(TARGET, 'dropped', bn);
    if (exists(dest)) dest = path.join(TARGET, 'dropped', bn + '-2');
    mv(d, dest);
  }
}
function rewriteBumpedCrossrefs() {
  if (!BUMPS.length) return;
  for (const [oldid, newid] of BUMPS) {
    for (const target of MOVED) {
      if (!exists(target) || !fs.statSync(target).isFile()) continue;
      const t = read(target).split(`ADR-${oldid}`).join(`ADR-${newid}`).split(`${oldid}-`).join(`${newid}-`);
      fs.writeFileSync(target, t);
    }
  }
  if (top) {
    let changed = '';
    try { changed = cp.execSync('git diff --name-only ORIG_HEAD..HEAD', { cwd: top, stdio: ['ignore', 'pipe', 'ignore'] }).toString(); } catch (_) { changed = ''; }
    for (const [oldid, newid] of BUMPS) {
      for (const pf of changed.split('\n')) {
        if (!pf || pf.startsWith('.forge/')) continue;
        const full = path.join(top, pf);
        if (exists(full) && fs.statSync(full).isFile() && read(full).includes(`ADR-${oldid}`)) log(`  WARN external ref ADR-${oldid} in ${pf} (now ${newid}) — rewrite by hand`);
      }
    }
  }
}
function removeBranchFolder() {
  fs.rmSync(SRC, { recursive: true, force: true });
  const parent = path.dirname(SRC);
  if (parent !== BRANCHES_DIR && isDir(parent) && ls(parent).length === 0) { try { fs.rmdirSync(parent); } catch (_) {} }
}

integrateAdrs();
integrateRetros();
integrateContext();
integrateDoneAndBacklog();
integrateDropped();
rewriteBumpedCrossrefs();
removeBranchFolder();

die(`SEALED integrated branch=${SRC} target=${TARGET}`, 0);
