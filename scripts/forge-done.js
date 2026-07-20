#!/usr/bin/env node
// forge-done.js — node twin of forge-done.sh (ADR-0022 dual dispatch; ADR-0030).
// Identical behavior to the .sh for the same state — exit codes, STATUS close-out
// content, and archive layout (guarded by forge-done.parity.test.sh). node is the
// fallback where bash can't run the .sh (PowerShell-blocked Windows).
//
// See forge-done.sh's header for the full contract (gate-first, non-destructive
// on refuse; exit codes 0/2/3/4/5).
'use strict';

const fs = require('fs');
const path = require('path');
const { resolveForgeRoot } = require('./resolve-forge-root.js');

// --- args --------------------------------------------------------------------
let slugArg = '', skipRetro = '', skipGiven = false, docs = 'none', completed = '', sealedId = '';
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  switch (argv[i]) {
    case '--slug': slugArg = argv[++i] || ''; break;
    case '--skip-retro': skipRetro = argv[++i] || ''; skipGiven = true; break;
    case '--docs-updated': docs = argv[++i] || 'none'; break;
    case '--completed': completed = argv[++i] || ''; break;
    case '--sealed-id': sealedId = argv[++i] || ''; break;
    default: process.stderr.write(`forge-done: unknown arg: ${argv[i]}\n`); process.exit(64);
  }
}
if (!completed) {
  const d = new Date();
  completed = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
if (!sealedId) {
  const d = new Date(); const p = (n) => String(n).padStart(2, '0');
  sealedId = `${String(d.getFullYear()).slice(-2)}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}
// --sealed-id is spliced into the done/ dir path, so it MUST be a bare YYMMDD-HHMMSS
// (the serial letter, if any, is appended by this script on collision). A malformed
// value (separators, .., slashes) could escape done/ — reject it BEFORE any mutation.
if (!/^\d{6}-\d{6}$/.test(sealedId)) {
  process.stderr.write(`forge-done: invalid --sealed-id (need bare YYMMDD-HHMMSS): ${sealedId}\n`);
  process.exit(64);
}

const die = (msg, code) => { process.stdout.write(msg + '\n'); process.exit(code); };

// --- resolve forge root (ADR-0011) -------------------------------------------
let root = '.forge';
try { root = resolveForgeRoot().root || '.forge'; } catch (_) { root = '.forge'; }
const isDir = (p) => { try { return fs.statSync(p).isDirectory(); } catch (_) { return false; } };
const isFile = (p) => { try { return fs.statSync(p).isFile(); } catch (_) { return false; } };
const read = (p) => { try { return fs.readFileSync(p, 'utf8'); } catch (_) { return ''; } };
if (!isDir(root)) die(`EMPTY no-forge-state (${root} missing)`, 2);

// --- field extractors (match the .sh: `field:` / `- field:`, strip CR) --------
function field(file, name) {
  const m = read(file).match(new RegExp(`^[ \\t]*-?[ \\t]*${name}:[ \\t]*(\\S*)`, 'm'));
  return m ? m[1].replace(/\r/g, '') : '';
}
function fullfield(file, name) {
  const m = read(file).match(new RegExp(`^[ \\t]*-?[ \\t]*${name}:[ \\t]*(.*)$`, 'm'));
  return m ? m[1].replace(/\r/g, '') : '';
}
function slugof(file) {
  const m = read(file).match(/forge-slug:[ \t]*(\S*)[ \t]*-->/);
  return m ? m[1].replace(/\r/g, '') : '';
}

// write a closed-out STATUS.md (status: done), preserving title/slug/executed/verified
function closeOutStatus(sf, slug, retroOut, reviewed) {
  let title = (read(sf).split('\n')[0] || '');
  if (!title.startsWith('#')) title = `# STATUS — ${slug}`;
  let execDate = field(sf, 'executed') || completed;
  let verified = fullfield(sf, 'verified') || 'n/a';
  let out = `${title}\n`
    + `slug: ${slug}\n`
    + `status: done\n`
    + `executed: ${execDate}\n`
    + `completed: ${completed}\n`
    + `verified: ${verified}\n`
    + `retro: ${retroOut}\n`;
  if (reviewed) out += `reviewed: ${reviewed}\n`;
  out += `docs updated: ${docs}\n`;
  fs.writeFileSync(sf, out);
}

// find retro file *-<slug>.md under root/retro
function findRetro(slug) {
  const dir = path.join(root, 'retro');
  if (!isDir(dir)) return '';
  const hit = fs.readdirSync(dir).filter((f) => f.endsWith(`-${slug}.md`)).sort()[0];
  return hit ? path.join(dir, hit) : '';
}

// --- determine target slug ---------------------------------------------------
let slug = slugArg;
if (!slug && isFile(path.join(root, 'plan.md'))) slug = slugof(path.join(root, 'plan.md'));
if (!slug) die('EMPTY no-task-to-seal (no --slug and no active plan)', 2);
// slug is the OTHER half spliced into DEST (done/<sealed-id>-<slug>/). --sealed-id is
// already format-checked; guard slug too so the final path can't escape done/. Reject a
// path-separator, .., or leading-dot slug BEFORE the dup scan and any mutation (gate-first).
if (/[/\\]/.test(slug) || slug.includes('..') || slug.startsWith('.')) {
  process.stderr.write(`forge-done: invalid slug (path traversal): ${slug}\n`);
  process.exit(64);
}

// --- duplicate / half-sealed check (two-format aware: grandfathered
//     YYYY-MM-DD-slug, or YYMMDD-HHMMSS[letter]-slug) ------------------------
const doneDir = path.join(root, 'done');
if (isDir(doneDir)) {
  for (const name of fs.readdirSync(doneDir).sort()) {
    const d = path.join(doneDir, name);
    if (!isDir(d)) continue;
    const mOld = /^.{4}-.{2}-.{2}-(.*)$/.exec(name);
    const mNew = /^.{6}-.{6}[a-z]?-(.*)$/.exec(name);
    const rest = mOld ? mOld[1] : (mNew ? mNew[1] : name);
    if (rest !== slug) continue;
    const sf = path.join(d, 'STATUS.md');
    if (field(sf, 'status') === 'done') die(`DUP already-sealed slug=${slug} at ${d}/`, 5);
    closeOutStatus(sf, slug, fullfield(sf, 'retro'), '');
    die(`SEALED half-sealed-completed ${d}/`, 0);
  }
}

// --- locate the source bucket ------------------------------------------------
let MODE, D, P, R, S, V;
const execPath = path.join(root, 'executed', slug);
if (isDir(execPath)) {
  MODE = 'executed'; D = execPath;
  P = path.join(D, 'plan.md'); R = path.join(D, 'run.md'); S = path.join(D, 'STATUS.md'); V = path.join(D, 'review.md');
} else if (isFile(path.join(root, 'plan.md')) && slugof(path.join(root, 'plan.md')) === slug) {
  MODE = 'active'; D = root;
  P = path.join(root, 'plan.md'); R = path.join(root, 'run.md'); S = path.join(root, 'STATUS.md'); V = path.join(root, 'review.md');
} else {
  die(`EMPTY slug-not-found slug=${slug}`, 2);
}

// --- GATE 1: verification ----------------------------------------------------
const vtok = field(S, 'verified');
if (vtok !== 'yes' && vtok !== 'skipped' && vtok !== 'n/a') {
  die(`GATE_VERIFY not-sealable verified=[${fullfield(S, 'verified')}] slug=${slug}`, 3);
}

// --- GATE 2: retro done-or-skipped -------------------------------------------
let retroOut = '';
if (skipGiven) {
  retroOut = `skipped (${skipRetro})`;
} else {
  const rf = findRetro(slug);
  if (rf) retroOut = rf;
  else if (/^skipped/.test(fullfield(S, 'retro'))) retroOut = fullfield(S, 'retro');
  else die(`GATE_RETRO retro-owed slug=${slug}`, 4);
}

// --- SEAL (mutation only past this point) ------------------------------------
const reviewed = isFile(V) ? V : '';
closeOutStatus(S, slug, retroOut, reviewed);
// archive into done/<sealed-id>-<slug>/ (YYMMDD-HHMMSS; serial letter only on a
// same-second same-slug collision — rare, the dup scan already caught prior seals)
let DEST = path.join(root, 'done', `${sealedId}-${slug}`);
if (fs.existsSync(DEST)) {
  for (const c of 'abcdefghijklmnopqrstuvwxyz') {
    const alt = path.join(root, 'done', `${sealedId}${c}-${slug}`);
    if (!fs.existsSync(alt)) { DEST = alt; break; }
  }
}
fs.mkdirSync(DEST, { recursive: true });
const move = (src) => { if (isFile(src)) fs.renameSync(src, path.join(DEST, path.basename(src))); };
move(P); move(R); move(S); move(V);
if (MODE === 'executed') fs.rmSync(D, { recursive: true, force: true });

die(`SEALED slug=${slug} dest=${DEST}`, 0);
