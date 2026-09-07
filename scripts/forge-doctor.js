#!/usr/bin/env node
// forge-doctor.js — node twin of forge-doctor.sh (ADR-0022 dual dispatch).
// Identical behavior to the .sh for the same state — same findings, same order,
// same stdout text, same exit code (guarded by forge-doctor.parity.test.sh).
// Read-only: writes/fixes nothing (fg-doctor contract, ADR-0019).
//
// Exit: 0 clean · 1 warnings only · 2 one or more errors.  See forge-doctor.sh header.
'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const scriptDir = __dirname;
let top = '';
try { top = cp.execSync('git rev-parse --show-toplevel', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim(); } catch (_) { top = ''; }
const repo = top || '.';
let root = '';
try { root = cp.execSync(`bash "${path.join(scriptDir, 'resolve-forge-root.sh')}"`, { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim(); } catch (_) { root = ''; }
if (!root) root = path.join(repo, '.forge');
let curBranch = '';
try { curBranch = cp.execSync('git rev-parse --abbrev-ref HEAD', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim(); } catch (_) { curBranch = ''; }

let errN = 0, warnN = 0, infoN = 0;
function finding(sev, check, p, hint) {
  if (sev === 'error') errN++; else if (sev === 'warning') warnN++; else if (sev === 'info') infoN++;
  process.stdout.write(`[${sev}] ${check} — ${p}\n   fix: ${hint}\n`);
}
const isDir = (p) => { try { return fs.statSync(p).isDirectory(); } catch (_) { return false; } };
const isFile = (p) => { try { return fs.statSync(p).isFile(); } catch (_) { return false; } };
const exists = (p) => { try { fs.statSync(p); return true; } catch (_) { return false; } };
const read = (p) => { try { return fs.readFileSync(p, 'utf8'); } catch (_) { return ''; } };
const ls = (d) => { try { return fs.readdirSync(d).sort(); } catch (_) { return []; } };
function field(f, name) { const m = read(f).match(new RegExp(`^[ \\t]*-?[ \\t]*${name}:[ \\t]*(\\S*)`, 'm')); return m ? m[1].replace(/\r/g, '') : ''; }
function hasField(f, name) { return isFile(f) && new RegExp(`^[ \\t]*-?[ \\t]*${name}:`, 'm').test(read(f)); }
function slugof(f) { const m = read(f).match(/forge-slug:[ \t]*(\S*)[ \t]*-->/); return m ? m[1].replace(/\r/g, '') : ''; }

// ---- Group A ----------------------------------------------------------------
if ((isFile(path.join(root, 'run.md')) || isFile(path.join(root, 'STATUS.md'))) && !isFile(path.join(root, 'plan.md'))) {
  finding('error', 'A1 active-slot orphan', `${root}/run.md|STATUS.md (no plan.md)`, 'an orphaned run/STATUS with no plan — seal via fg-done or discard via fg-drop');
}
// A1(b) the mirror case: a run happened but its companion marker was never written.
// A5 demands plan+run+STATUS for executed/<slug>; the active slot had no such arm,
// so a half-executed slot passed clean and was only caught by the session-start hook.
if (isFile(path.join(root, 'plan.md')) && isFile(path.join(root, 'run.md')) && !isFile(path.join(root, 'STATUS.md'))) {
  finding('warning', 'A1 active-slot incomplete', `${root} (plan.md+run.md present, STATUS.md missing)`, 'fg-run writes STATUS.md right after run.md — re-enter fg-run for its verification-only resume (it writes verified: without re-executing)');
}
function checkStatus(sf, ctx) {
  if (!isFile(sf)) return;
  const st = field(sf, 'status'), ver = field(sf, 'verified'), rt = field(sf, 'retro');
  if (st !== 'executed' && st !== 'done') finding('error', 'A2 STATUS.status', sf, `status must be executed|done (got '${st || '<missing>'}')`);
  if (ctx !== 'done-legacy') {
    if (!['yes', 'skipped', 'n/a', 'pending', 'failed'].includes(ver)) {
      if (!hasField(sf, 'verified')) {
        if (ctx === 'done') finding('warning', 'A2 STATUS.verified', sf, "legacy done may lack verified: — backfill 'n/a (legacy)' if editing");
        else finding('error', 'A2 STATUS.verified', sf, 'verified must be yes|skipped|n/a|pending|failed');
      }
    }
  }
  if (ctx === 'done' && st !== 'done') finding('error', 'A4 half-sealed done/', sf, 're-run fg-done to finish close-out (idempotent flip to status: done)');
  const dir = path.dirname(sf), slug = field(sf, 'slug');
  if (isFile(path.join(dir, 'plan.md'))) { const pslug = slugof(path.join(dir, 'plan.md'));
    if (pslug && slug && pslug !== slug) finding('error', 'A3 slug pairing', sf, `plan forge-slug (${pslug}) != STATUS slug (${slug})`);
  }
  if (/^(\.forge\/|\/)/.test(rt) || rt.startsWith(repo + '/')) {
    if (!isFile(rt) && !isFile(path.join(repo, rt))) finding('error', 'A3 dangling retro', sf, `retro: points to a missing file (${rt})`);
  } else if (rt === 'pending') {
    if (ctx === 'done') finding('warning', 'A3 retro pending in done/', sf, "seal left retro: unfilled — fg-learn then re-seal, or record 'skipped'");
  }
}
if (isFile(path.join(root, 'STATUS.md'))) checkStatus(path.join(root, 'STATUS.md'), 'active');
for (const d of ls(path.join(root, 'executed'))) {
  const dir = path.join(root, 'executed', d); if (!isDir(dir)) continue;
  for (const f of ['plan.md', 'run.md', 'STATUS.md']) if (!isFile(path.join(dir, f))) finding('warning', 'A5 executed/ incomplete', dir + '/', `missing ${f} (executed/<slug> needs plan+run+STATUS)`);
  if (field(path.join(dir, 'STATUS.md'), 'status') !== 'executed') finding('warning', 'A5 executed/ status', path.join(dir, 'STATUS.md'), 'executed/<slug> STATUS must read status: executed');
  checkStatus(path.join(dir, 'STATUS.md'), 'executed');
}
for (const d of ls(path.join(root, 'done'))) { const dir = path.join(root, 'done', d); if (!isDir(dir)) continue; checkStatus(path.join(dir, 'STATUS.md'), 'done'); }
// A6 backlog markers + task-number uniqueness
const nums = [];
function addNums(files) { for (const p of files) { if (!isFile(p)) continue; const m = read(p).match(/task:[ \t]*(\d+)/); if (m) nums.push(m[1]); } }
for (const f of ls(path.join(root, 'backlog'))) { const fp = path.join(root, 'backlog', f); if (!isFile(fp)) continue;
  if (!slugof(fp)) finding('warning', 'A6 backlog forge-slug', fp, 'add a first-line <!-- forge-slug: ... --> marker');
  if (!/task:[ \t]*\d/.test(read(fp))) finding('warning', 'A6 backlog task:', fp, 'add a <!-- task: N --> marker (fg-ask assigns it)');
}
const allPlans = [];
for (const f of ls(path.join(root, 'backlog'))) allPlans.push(path.join(root, 'backlog', f));
allPlans.push(path.join(root, 'plan.md'));
for (const d of ls(path.join(root, 'executed'))) allPlans.push(path.join(root, 'executed', d, 'plan.md'));
for (const d of ls(path.join(root, 'done'))) allPlans.push(path.join(root, 'done', d, 'plan.md'));
addNums(allPlans);
const seen = {}, dups = [];
for (const n of nums) { seen[n] = (seen[n] || 0) + 1; }
for (const n of Object.keys(seen).sort()) if (seen[n] > 1) dups.push(n);
if (dups.length) finding('error', 'A6 duplicate task number', dups.join(' ') + ' ', 'two plans share a task: number — breaks fg-run selection/fg-status; renumber one');
// A7 stale ask.md
if (isFile(path.join(root, 'ask.md'))) {
  const age = (Date.now() - fs.statSync(path.join(root, 'ask.md')).mtimeMs) / 86400000;
  if (age > 1) finding('warning', 'A7 stale ask.md', path.join(root, 'ask.md'), 'finish grilling with fg-ask (overwrites it) or discard via fg-drop');
}
// A9 stale drive.md — a drive that died without deleting its marker. Harmless
// (the Stop hook ignores a marker past its 30-min bound) but it means some drive
// exited without cleaning up, and the next reader deserves to know why nothing is
// continuing. Read-only: report, never delete (fg-doctor never auto-fixes).
if (isFile(path.join(root, 'drive.md'))) {
  let started = '';
  for (const line of read(path.join(root, 'drive.md')).split(/\r?\n/)) {
    const m = line.match(/^started:[ \t]*([0-9]*)/);
    if (m) { started = m[1]; break; }
  }
  if (started === '') {
    finding('warning', 'A9 unparseable drive.md', path.join(root, 'drive.md'), "a drive marker with no valid 'started:' \u2014 delete it (the Stop hook ignores it, so nothing is blocked)");
  } else if (Math.floor(Date.now() / 1000) - Number(started) > 1800) {
    finding('warning', 'A9 stale drive.md', path.join(root, 'drive.md'), 'a drive exited without deleting its marker (past the 30-min bound, so it blocks nothing) \u2014 delete it');
  }
}
// A8 orphaned branch root
const brDir = path.join(repo, '.forge', 'branch');
if (isDir(brDir)) {
  const roots = [];
  for (const a of ls(brDir)) { const pa = path.join(brDir, a); if (isDir(pa)) { roots.push([a, pa]); for (const b of ls(pa)) { const pb = path.join(pa, b); if (isDir(pb)) roots.push([a + '/' + b, pb]); } } }
  for (const [bn, d] of roots) {
    if (bn === curBranch) continue;
    for (const m of ['adr', 'retro', 'done', 'backlog', 'CONTEXT.md', 'plan.md', 'loop.md']) {
      if (exists(path.join(d, m))) { finding('warning', 'A8 orphaned branch root', d + '/', `branch forge state present on this branch — did you forget 'fg-merge ${bn}' after git merge?`); break; }
    }
  }
}

// ---- Group B ----------------------------------------------------------------
const PJ = path.join(repo, '.claude-plugin', 'plugin.json'), MP = path.join(repo, '.claude-plugin', 'marketplace.json'), CJ = path.join(repo, '.codex-plugin', 'plugin.json');
const jvers = (f) => (read(f).match(/"version"[ \t]*:[ \t]*"([^"]*)"/g) || []).map((s) => s.match(/"([^"]*)"[ \t]*$/) ? s.replace(/.*"version"[ \t]*:[ \t]*"([^"]*)".*/, '$1') : '');
if (isFile(PJ) && isFile(MP)) {
  const pv = jvers(PJ)[0] || '', mv = jvers(MP);
  const cv = isFile(CJ) ? (jvers(CJ)[0] || '') : pv;
  if (!(pv === (mv[0] || '') && pv === (mv[1] || '') && pv === cv)) finding('error', 'B8 manifest version drift', `${PJ}|${MP}|${CJ}`, `sync all 4: Claude=${pv} metadata=${mv[0] || ''} marketplace=${mv[1] || ''} Codex=${cv}`);
}
if (isFile(PJ) && isFile(MP)) {
  try { JSON.parse(read(PJ)); JSON.parse(read(MP)); if (isFile(CJ)) JSON.parse(read(CJ)); } catch (_) { finding('error', 'B9 manifest JSON invalid', `${PJ}|${MP}|${CJ}`, 'fix the JSON syntax (install breaks otherwise)'); }
}
for (const s of ls(path.join(repo, 'skills'))) { const sf = path.join(repo, 'skills', s, 'SKILL.md'); if (!isFile(sf)) continue;
  if (!/^name:/m.test(read(sf))) finding('error', 'B10 skill missing name:', sf, "add a frontmatter 'name:' (else not auto-discovered)");
}
const CM = path.join(repo, 'CLAUDE.md');
if (isFile(CM)) { const cm = read(CM);
  for (const s of ls(path.join(repo, 'skills'))) { const sf = path.join(repo, 'skills', s, 'SKILL.md'); if (!isFile(sf)) continue;
    const nm = (read(sf).match(/^name:[ \t]*(.*)$/m) || [, ''])[1].replace(/\r/g, '').trim(); if (!nm) continue;
    if (!cm.includes(nm)) finding('warning', 'B12 CLAUDE.md skill-list', nm, "skill on disk but absent from CLAUDE.md's skill list — add an entry");
  }
}
const RE = path.join(repo, 'README.md'), RK = path.join(repo, 'README.ko.md');
if (isFile(RE) && isFile(RK)) {
  const ce = (read(RE).match(/\| ?`fg-/g) || []).length, ck = (read(RK).match(/\| ?`fg-/g) || []).length;
  if (ce !== ck) finding('warning', 'B13 README bilingual drift', `${RE}|${RK}`, `skill-row counts differ (en=${ce} ko=${ck}) — sync the pair`);
}
const ADRD = path.join(root, 'adr');
if (isDir(ADRD)) {
  // time-ID uniqueness across BOTH granularities (grandfathered YYMMDD-HH+letter,
  // and current YYMMDD-HHMMSS[+letter] — ADR 260719-161701); globs mutually exclusive by digit count
  // scan active adr/ AND adr/retired/ — a retired time-id is frozen/never reused,
  // so an active<->retired duplicate is an error (mirrors the NNNN gap scan below,
  // which already includes retired/).
  const collectTids = (d) => ls(d)
    .filter((f) => /^\d{6}-\d{2}[a-z]+-.*\.md$/.test(f) || /^\d{6}-\d{6}[a-z]?-.*\.md$/.test(f))
    .map((f) => (f.match(/^(\d{6}-\d{2}[a-z]+)-/) || f.match(/^(\d{6}-\d{6}[a-z]?)-/))[1]);
  const tids = [...collectTids(ADRD), ...collectTids(path.join(ADRD, 'retired'))];
  const tseen = {}, tdups = [];
  for (const t of tids) tseen[t] = (tseen[t] || 0) + 1;
  for (const t of Object.keys(tseen).sort()) if (tseen[t] > 1) tdups.push(t);
  if (tdups.length) finding('error', 'B14 duplicate time-ID', tdups.join(' ') + ' ', 'two ADRs share a time-based id — bump one to the next free letter');
  const nnSet = new Set();
  for (const f of ls(ADRD)) { const m = f.match(/^(\d{4})-.*\.md$/); if (m) nnSet.add(m[1]); }
  for (const f of ls(path.join(ADRD, 'retired'))) { const m = f.match(/^(\d{4})-.*\.md$/); if (m) nnSet.add(m[1]); }
  const nn = [...nnSet].sort();
  let prev = '';
  for (const n of nn) {
    if (prev) { const exp = String(parseInt(prev, 10) + 1).padStart(4, '0');
      if (n !== exp && parseInt(n, 10) > parseInt(prev, 10)) finding('warning', 'B14 NNNN gap', `ADR-${prev}→ADR-${n}`, 'gap in the grandfathered NNNN set with no retired/ entry — confirm intentional');
    }
    prev = n;
  }
}
for (const f of ls(path.join(repo, 'scripts'))) {
  if (!f.endsWith('.sh') || f.endsWith('.test.sh') || f.endsWith('.parity.test.sh') || f.endsWith('-wrapper.sh')) continue;
  const js = path.join(repo, 'scripts', f.replace(/\.sh$/, '.js'));
  if (!isFile(js)) finding('warning', 'B15 missing .js twin', path.join(repo, 'scripts', f), 'add the node twin (dual dispatch, ADR-0022)');
}
for (const f of ls(path.join(repo, 'scripts'))) {
  if (!f.endsWith('.js')) continue;
  const sh = path.join(repo, 'scripts', f.replace(/\.js$/, '.sh'));
  if (!isFile(sh)) finding('warning', 'B15 missing .sh twin', path.join(repo, 'scripts', f), 'add the bash primary (dual dispatch, ADR-0022)');
}
// B16 SKILL.md description length (trigger-core drift lint, ADR 260716-22a) — twin of .sh.
// [...desc].length counts Unicode codepoints, matching the .sh locale-independent count exactly.
const DESC_MAX = 600;
for (const s of ls(path.join(repo, 'skills'))) { const sf = path.join(repo, 'skills', s, 'SKILL.md'); if (!isFile(sf)) continue;
  // A YAML block scalar (`>`, `>-`, `|`, `|2-`, …) puts the value on the FOLLOWING
  // indented lines; a line-wise read saw only the indicator (`>-` = 2 chars) and every
  // length passed — fail-open. Folding joins each break with one character either way,
  // so a single-space join matches the .sh twin's count exactly.
  const lines = read(sf).split('\n');
  const di = lines.findIndex((l) => /^description:/.test(l));
  if (di < 0) continue;
  let desc = lines[di].replace(/^description:[ \t]*/, '').replace(/\r/g, '');
  if (/^[>|][-+]?[0-9]*$/.test(desc)) {
    const parts = [];
    for (let i = di + 1; i < lines.length; i++) {
      if (/^[^ \t]/.test(lines[i])) break;
      const t = lines[i].replace(/^[ \t]+/, '').replace(/\r/g, '');
      if (t) parts.push(t);
    }
    desc = parts.join(' ');
  }
  if (!desc) continue;
  const n = [...desc].length;
  if (n > DESC_MAX) finding('warning', 'B16 description length', `${sf} (${n} chars > ${DESC_MAX})`, 'trim the SKILL.md frontmatter description toward the trigger core — it drives /fg menu readability (ADR 260716-22a)');
}

// B17 always-on explanation discipline present (drift guard, ADR 260824-134246) — twin of .sh.
// Compares the CANONICAL BODY from explaining-forge.rule.txt (single definition, never
// hardcoded here), by containment so fg-ask's superset variant needs no exception. warning,
// not error, per skills/fg-doctor/SKILL.md's rubric. Scoped to the forge plugin repo via the
// TOP-LEVEL manifest name; jname is line-bounded ([ \t], like jvers) so a nested
// `"author": {"name": "forge"}` cannot trigger it and the bash twin agrees on every shape.
const jname = (f) => { const m = read(f).match(/"name"[ \t]*:[ \t]*"([^"]*)"/); return m ? m[1] : ''; };
const RULE_FILE = path.join(scriptDir, 'explaining-forge.rule.txt');
if (isFile(PJ) && jname(PJ) === 'forge' && isFile(RULE_FILE)) {
  const rule = read(RULE_FILE).replace(/\n+$/, '');
  for (const s of ls(path.join(repo, 'skills'))) { const sf = path.join(repo, 'skills', s, 'SKILL.md'); if (!isFile(sf)) continue;
    if (!read(sf).includes(rule)) finding('warning', 'B17 missing Explaining forge rule', sf, "the canonical **Explaining forge** paragraph is absent or altered — copy it verbatim from scripts/explaining-forge.rule.txt next to this skill's **Language** rule (ADR 260824-134246)");
  }
}

// B18 fg-debug contract coherence (ADR 260907-140655) — twin of .sh. This
// checks independent semantic signals across HANDOFF, CONTEXT, and fg-debug;
// it deliberately does not make a second canonical paragraph out of the test.
if (isFile(PJ) && jname(PJ) === 'forge') {
  const handoff = path.join(repo, 'skills', 'fg-next', 'HANDOFF.md');
  const context = path.join(repo, '.forge', 'CONTEXT.md');
  const debugSkill = path.join(repo, 'skills', 'fg-debug', 'SKILL.md');
  let appliesN = '', wiredN = '';
  if (isFile(handoff)) {
    const h = read(handoff);
    appliesN = (h.match(/^\*\*Applies \((\d+)\)\*\*/m) || [, ''])[1];
    const section = (h.match(/^\*\*Applies \(\d+\)\*\*[\s\S]*?(?=^\*\*Does NOT apply)/m) || [''])[0];
    wiredN = String(new Set((section.match(/`fg-[a-z0-9-]+`/g) || [])).size);
    if (!appliesN || appliesN !== wiredN) finding('warning', 'B18 handoff applies count', `${handoff} (declared=${appliesN || 'missing'} enumerated=${wiredN || '0'})`, 'make the Applies declaration equal the unique backtick-enumerated fg-* skills in that section');
    const excludedN = (h.match(/^\*\*Does NOT apply \((\d+)\)\*\*/m) || [, ''])[1];
    const excludedStart = h.search(/^\*\*Does NOT apply \(\d+\)\*\*/m);
    let excludedSection = excludedStart >= 0 ? h.slice(excludedStart) : '';
    const nextH2 = excludedSection.search(/\n## /);
    if (nextH2 >= 0) excludedSection = excludedSection.slice(0, nextH2);
    const excludedWiredN = String(new Set((excludedSection.match(/`fg-[a-z0-9-]+`/g) || [])).size);
    if (!excludedN || excludedN !== excludedWiredN) finding('warning', 'B18 handoff excluded count', `${handoff} (declared=${excludedN || 'missing'} enumerated=${excludedWiredN || '0'})`, 'make the Does NOT apply declaration equal the unique backtick-enumerated fg-* skills in that section');
  }
  if (isFile(context) && wiredN) {
    const c = read(context);
    const marker = '**핸드오프 표 (handoff table)**:';
    let section = c.includes(marker) ? c.slice(c.indexOf(marker) + marker.length) : '';
    const nextTerm = section.search(/\n\*\*[^*\n]+\*\*:/);
    if (nextTerm >= 0) section = section.slice(0, nextTerm);
    const contextN = (section.match(/적용 지점[^0-9]*(\d+)곳/) || [, ''])[1];
    if (!contextN || contextN !== wiredN) finding('warning', 'B18 CONTEXT handoff count', `${context} (declared=${contextN || 'missing'} enumerated=${wiredN})`, "sync the handoff-table glossary count with HANDOFF.md's unique Applies enumeration");
  }
  if (isFile(debugSkill)) {
    const debugText = read(debugSkill);
    const h2Section = (prefix) => {
      const lines = debugText.split(/\r?\n/);
      const start = lines.findIndex((line) => line.startsWith(`## ${prefix}`));
      if (start < 0) return '';
      const end = lines.findIndex((line, i) => i > start && line.startsWith('## '));
      return lines.slice(start + 1, end < 0 ? lines.length : end).join(' ').replace(/\s+/g, ' ');
    };
    const route = h2Section('Route by invocation state');
    const artifacts = h2Section('Phase 1 artifacts');
    const boundary = h2Section('The boundary');
    if (!(/verified:[ \t]*failed/i.test(route) && /fix-and-re-run/i.test(route))) finding('warning', 'B18 fg-debug active-failure route', debugSkill, "state that an active verified: failed diagnosis returns to fg-run's existing fix-and-re-run path");
    const classifies = /classif(y|ies|ication)|determin(e|es|ing)\s+whether|decid(e|es|ing)\s+whether|separately/i.test(artifacts);
    if (!(classifies && /persistent/i.test(artifacts) && /one-off|one off|throwaway|curl|trace|HITL/i.test(artifacts) && /PLAN-FORMAT/i.test(artifacts) && !/fix-forward eval rule by construction/i.test(artifacts))) finding('warning', 'B18 fg-debug persistent eval', debugSkill, 'classify Phase 1 commands as persistent or one-off, defer to PLAN-FORMAT, and do not overclaim automatic eval compliance');
    if (!(/(all|every)[ -]*(exit|termination|outcome)/i.test(artifacts) && /delete|remove|clean(ed|s|ing|up)?|cleanup/i.test(artifacts) && /capture|trace|HAR|log|instrumentation|harness|artifact/i.test(artifacts))) finding('warning', 'B18 fg-debug cleanup', debugSkill, 'require raw captures, temporary instrumentation, and throwaway harnesses to be removed on every exit path');
    if (!(/(feedback|reproduction)[ -]*loop.{0,100}(exist(s)?|built|available|working|established)/i.test(boundary) && /(root[ -]*cause|cause).{0,100}(unconfirmed|not confirmed|remains unknown|not established)/i.test(boundary))) finding('warning', 'B18 fg-debug inconclusive route', debugSkill, 'define an inconclusive exit for an existing feedback loop whose root cause remains unconfirmed');
  }
}

process.stdout.write(`\n🩺 forge-doctor — ${errN} errors, ${warnN} warnings, ${infoN} info\n`);
process.exit(errN > 0 ? 2 : warnN > 0 ? 1 : 0);
