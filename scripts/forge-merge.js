#!/usr/bin/env node
// forge-merge.js — node twin of forge-merge.sh (ADR-0022 dual dispatch).
// Identical behavior to the .sh for the same input state — exit codes AND the
// resulting .forge/ tree (guarded by forge-merge.parity.test.sh). node is the
// fallback where bash can't run the .sh (PowerShell-blocked Windows).
//
// See forge-merge.sh's header for the full contract (gate-first, non-destructive
// on refuse; exit codes 0/2/3/4/6; `--gate-only` judges the in-flight gate only).
'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

// --- args --------------------------------------------------------------------
let branchArg = '', completed = '', gateOnly = false;
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--completed') completed = argv[++i] || '';
  else if (a === '--gate-only') gateOnly = true;
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
  for (const m of ['CONTEXT.md', 'plan.md', 'run.md', 'STATUS.md', 'loop.md', 'followups.md']) if (exists(path.join(p, m))) return true;
  return false;
}
function findLeafRoots() {
  const out = [];
  if (!isDir(BRANCHES_DIR)) return out;
  function visit(parent) {
    for (const name of ls(parent)) {
      if (name.startsWith('.')) continue;
      const child = path.join(parent, name);
      if (!isDir(child) || fs.lstatSync(child).isSymbolicLink()) continue;
      if (isLeafRoot(child)) out.push(child); else visit(child);
    }
  }
  visit(BRANCHES_DIR);
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
// CONTEXT.md units — see the .sh twin: a TERM is a `**Name**:` entry, `## X` is
// an optional GROUP subheading, not a term. `indexOf` on the remainder finds the
// FIRST `**:` so the name is non-greedy, matching awk's index().
function ctxName(l) {
  if (!l.startsWith('**')) return '';
  const i = l.slice(2).indexOf('**:');
  return i > 0 ? l.slice(2, 2 + i) : '';
}
function ctxTerms(f) {
  if (!exists(f)) return [];
  return read(f).split('\n').map(ctxName).filter((n) => n !== '');
}
function ctxHeadings(f) {
  if (!exists(f)) return [];
  return read(f).split('\n').filter((l) => l.startsWith('## ')).map((l) => l.slice(3));
}
function ctxGroup(f, term) {
  let g = '';
  for (const l of read(f).split('\n')) {
    if (l.startsWith('## ')) { g = l.slice(3); continue; }
    if (ctxName(l) === term && term !== '') return g;
  }
  return '';
}
function ctxBodyLines(f, term) {
  const lines = read(f).split('\n'); const out = []; let inSec = false;
  for (const l of lines) {
    const n = ctxName(l);
    if (n !== '') { if (inSec) break; if (n === term) inSec = true; continue; }
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
if (gateOnly) die(`GATE_OK branch=${SRC}`, 0);

// --- GATE 2: CONTEXT term redefinition ---------------------------------------
const srcCtx = path.join(SRC, 'CONTEXT.md'), tgtCtx = path.join(TARGET, 'CONTEXT.md');
if (exists(srcCtx) && exists(tgtCtx)) {
  // Unrecognized shape: headings but no `**Term**:` entries — merging would
  // silently do nothing, worse than the false conflict this replaces.
  if (ctxTerms(srcCtx).length === 0 && ctxHeadings(srcCtx).length > 0) {
    die('GATE_CONFLICT context-unrecognized-shape (headings but no `**Term**:` entries) — human resolves', 4);
  }
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

// Plan reference rewrites before touching either tree. Unresolved legacy task
// references remain unchanged; only actual incoming plans establish a mapping.
function planTaskRemap() {
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
  const assignments = [], mapping = new Map();
  for (const p of incoming) {
    tmax += 1;
    const old = taskof(p);
    if (old && mapping.has(old)) die('GATE_CONFLICT duplicate-incoming-task — human resolves', 4);
    if (old) mapping.set(old, String(tmax));
    assignments.push([p, tmax]);
  }
  return { assignments, mapping };
}
const taskRemap = planTaskRemap();
const followupPattern = /^<!-- followup: (fu-[a-f0-9]{12}) \| source: ([^\s|<>/\\]+) \| task: ([1-9][0-9]*|-) \| date: ([0-9]{4}-[0-9]{2}-[0-9]{2}) \| status: (open|taken|dismissed) \| taken: ([1-9][0-9]*|-) -->$/;
function parseFollowups(file, mapping) {
  if (!exists(file)) return { header: '', entries: [] };
  if (!fs.lstatSync(file).isFile()) die('GATE_CONFLICT invalid-followups-file — human resolves', 4);
  const lines = fs.readFileSync(file, 'utf8').replace(/\r/g, '').split('\n');
  const entries = []; let header = [], current = null;
  for (const line of lines) {
    if (line.includes('<!-- followup:')) {
      const m = line.match(followupPattern);
      if (!m || m[2].startsWith('.') || m[2].includes('..') || (m[5] === 'taken') !== (m[6] !== '-')) die('GATE_CONFLICT invalid-followups — human resolves', 4);
      const task = mapping.get(m[3]) || m[3], taken = mapping.get(m[6]) || m[6];
      current = { id: m[1], lines: [`<!-- followup: ${m[1]} | source: ${m[2]} | task: ${task} | date: ${m[4]} | status: ${m[5]} | taken: ${taken} -->`] };
      entries.push(current);
    } else if (current) current.lines.push(line); else header.push(line);
  }
  const trim = (a) => { while (a.length && a[a.length - 1] === '') a.pop(); return a.join('\n'); };
  const seen = new Set();
  for (const e of entries) {
    if (seen.has(e.id)) die('GATE_CONFLICT duplicate-followup-id — human resolves', 4);
    if (!e.lines.slice(1).join('\n').trim()) die('GATE_CONFLICT empty-followup-body — human resolves', 4);
    seen.add(e.id); e.block = trim(e.lines);
  }
  return { header: trim(header), entries };
}
let mergedFollowups = null;
if (exists(path.join(SRC, 'followups.md'))) {
  const target = parseFollowups(path.join(TARGET, 'followups.md'), new Map());
  const source = parseFollowups(path.join(SRC, 'followups.md'), taskRemap.mapping);
  const entries = target.entries.slice(), known = new Map(entries.map(e => [e.id, e.block]));
  for (const e of source.entries) {
    if (known.has(e.id)) {
      if (known.get(e.id) !== e.block) die('GATE_CONFLICT followup-id-conflict — human resolves', 4);
    } else { entries.push(e); known.set(e.id, e.block); }
  }
  mergedFollowups = [target.header || source.header || '# Follow-ups', ...entries.map(e => e.block)].join('\n\n') + '\n';
}

// Archived snapshots must remain replayable against the remapped ledger. Validate
// every candidate-bearing source first, then rewrite only marker reference fields.
const snapshotRewrites = [];
const snapshots = ls(path.join(SRC, 'retro')).filter(n => n.endsWith('.md')).map(n => path.join(SRC, 'retro', n));
for (const d of ls(path.join(SRC, 'done'))) snapshots.push(path.join(SRC, 'done', d, 'run.md'));
for (const file of snapshots) {
  if (!exists(file)) continue;
  const raw = fs.readFileSync(file, 'utf8');
  if (!raw.includes('<!-- followup:')) continue;
  parseFollowups(file, taskRemap.mapping);
  const updated = raw.replace(/^<!-- followup: .* -->\r?$/gm, line => line
    .replace(/ \| task: ([1-9][0-9]*|-) /, (_, n) => ` | task: ${taskRemap.mapping.get(n) || n} `)
    .replace(/ \| taken: ([1-9][0-9]*|-) /, (_, n) => ` | taken: ${taskRemap.mapping.get(n) || n} `));
  snapshotRewrites.push([file, updated]);
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
  const re = new RegExp('^' + base + '([a-z]+)-');
  // scan BOTH the active adr/ and adr/retired/ — a retired id is frozen and must
  // never be reused, so a bumped letter must skip letters taken in either place.
  const scan = (d) => { for (const f of ls(d)) { const m = f.match(re); if (m) used.add(m[1]); } };
  scan(dir); scan(path.join(dir, 'retired'));
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
      // collision against active adr/ AND adr/retired/ (retired ids are frozen, never reused)
      const inDir = (d) => exists(path.join(d, bn)) || ls(d).some((x) => x.startsWith(id + '-'));
      const collide = inDir(path.join(TARGET, 'adr')) || inDir(path.join(TARGET, 'adr', 'retired'));
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
// Insert block lines into $file at the end of group `grp`'s section (before the
// next `## `), or append at EOF — adding the heading when the group is new.
function ctxInsert(file, grp, blk) {
  const raw = read(file);
  const trailingNL = raw.endsWith('\n');
  const lines = raw.split('\n');
  if (trailingNL) lines.pop();
  const gi = grp ? lines.indexOf(`## ${grp}`) : -1;
  if (gi >= 0) {
    let end = lines.length;
    for (let i = gi + 1; i < lines.length; i++) if (lines[i].startsWith('## ')) { end = i; break; }
    lines.splice(end, 0, ...blk);
  } else {
    if (grp) lines.push('', `## ${grp}`);
    lines.push(...blk);
  }
  fs.writeFileSync(file, lines.join('\n') + '\n');
}
function integrateContext() {
  if (!exists(srcCtx)) return;
  if (!exists(tgtCtx)) { fs.copyFileSync(srcCtx, tgtCtx); MOVED.push(tgtCtx); return; }
  for (const term of ctxTerms(srcCtx)) {
    if (ctxTerms(tgtCtx).includes(term)) continue;   // identical body — gated
    const blk = [''].concat([`**${term}**:`], ctxBodyLines(srcCtx, term));
    ctxInsert(tgtCtx, ctxGroup(srcCtx, term), blk);
  }
  MOVED.push(tgtCtx);
}
function integrateDoneAndBacklog() {
  for (const [p, n] of taskRemap.assignments) fs.writeFileSync(p, read(p).replace(/task:(\s*)\d+/, `task:$1${n}`));
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

for (const [file, content] of snapshotRewrites) fs.writeFileSync(file, content);
integrateAdrs();
integrateRetros();
integrateContext();
integrateDoneAndBacklog();
integrateDropped();
if (mergedFollowups !== null) fs.writeFileSync(path.join(TARGET, 'followups.md'), mergedFollowups);
rewriteBumpedCrossrefs();
removeBranchFolder();

die(`SEALED integrated branch=${SRC} target=${TARGET}`, 0);
