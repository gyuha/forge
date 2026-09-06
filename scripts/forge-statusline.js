#!/usr/bin/env node
// forge-statusline.js — node twin of forge-statusline.sh (ADR-0022 dual dispatch).
//
// Prints forge progress fragment line(s), identical to forge-statusline.sh for
// the same state (guarded by forge-statusline.parity.test.sh). A display-only
// reader (ADR-0017; grouping + density added ADR-0029): it never reproduces
// fg-status's next-step machine.
//
// Segments are grouped as [ ... ] (dim brackets), groups joined by a space,
// segments inside a group joined by " <SEP> " (SEP = FORGE_SL_SEP, default "·";
// the full script passes "|"). Empty groups are omitted.
//
// Density (FORGE_SL_DENSITY, default "full"; full passes "compact"):
//   full    -> [🔁 rN/cap] [⚒ [#N ]slug · pipeline[ · flag]]   (line 1)
//              [📋 N queued · 📝 M awaiting retro[ · ♻️][ · 🧪]] (line 2)
//   compact -> [🔁 rN/cap] [⚒ [#N ]slug · pipeline[ · flag][ · 📋 N][ · ♻️][ · 🧪]]
//
// flag: ✓ yes · ⏳ pending · ✗ failed · (none) skipped/n/a. 🧪 = plan tdd:on;
// ♻️ = TOP-LEVEL config eco:true. Only lit indicators shown.
//
// Stage gating (ADR-0017 3rd amend): no plan/ask -> empty; ask.md -> ask; plan
// no run -> run; run + pending/failed -> run; run + yes/skipped/n/a -> learn.
'use strict';

const fs = require('fs');
const path = require('path');
const { resolveForgeRoot } = require('./resolve-forge-root.js');

const SEP = process.env.FORGE_SL_SEP || '·';
let DENSITY = process.env.FORGE_SL_DENSITY || 'full';
if (DENSITY !== 'compact') DENSITY = 'full';

// --- ANSI helpers (must match forge-statusline.sh's palette) -----------------
const DOT_DONE = '\x1b[32m';     // green — completed stage
const DOT_CUR = '\x1b[1;36m';    // bold cyan — current stage
const DOT_UPCOMING = '\x1b[2m';  // dim — upcoming stage
const DIM = '\x1b[2m';           // dim — brackets and separators
const RESET = '\x1b[0m';

const PREFIX = process.env.FORGE_SL_PREFIX || '⚒ ';

// grp(...parts) -> "[ a <SEP> b ]" (dim brackets/separators); empty parts dropped;
// nothing to show -> '' (no empty []).
function grp(...parts) {
  const kept = parts.filter((p) => p !== undefined && p !== null && p !== '');
  if (kept.length === 0) return '';
  const joined = kept.join(` ${DIM}${SEP}${RESET} `);
  return `${DIM}[${RESET}${joined}${DIM}]${RESET}`;
}

// buildPipeline('ask'|'run'|'learn') -> "✔ ask → ● run → ○ learn → ○ done" (colored)
function buildPipeline(stage) {
  const target = stage === 'learn' ? 2 : stage === 'run' ? 1 : 0;
  return ['ask', 'run', 'learn', 'done']
    .map((w, i) => {
      if (i < target) return `${DOT_DONE}✔ ${w}${RESET}`;
      if (i === target) return `${DOT_CUR}● ${w}${RESET}`;
      return `${DOT_UPCOMING}○ ${w}${RESET}`;
    })
    .join(' → ');
}

// --- cwd from session JSON (stdin), same as the .sh --------------------------
if (!process.stdin.isTTY) {
  let input = '';
  try { input = fs.readFileSync(0, 'utf8'); } catch (_) { input = ''; }
  if (input) {
    let cwd = '';
    try {
      const o = JSON.parse(input);
      cwd = o.cwd || (o.workspace && o.workspace.current_dir) || o.current_dir || '';
    } catch (_) {
      const m = input.match(/"cwd"\s*:\s*"([^"]*)"/) || input.match(/"current_dir"\s*:\s*"([^"]*)"/);
      cwd = m ? m[1] : '';
    }
    try { if (cwd && fs.statSync(cwd).isDirectory()) process.chdir(cwd); } catch (_) { /* keep cwd */ }
  }
}

const root = resolveForgeRoot().root;

const isDir = (p) => { try { return fs.statSync(p).isDirectory(); } catch (_) { return false; } };
const isFile = (p) => { try { return fs.statSync(p).isFile(); } catch (_) { return false; } };
const read = (p) => { try { return fs.readFileSync(p, 'utf8'); } catch (_) { return ''; } };

if (!isDir(root)) process.exit(0);

// --- Eco indicator (♻️): TOP-LEVEL .forge/config.json ------------------------
let eco = false;
const cfgTxt = read(path.join(root.replace(/(\.forge)[\/\\]branch[\/\\].*$/, '$1'), 'config.json'));
if (cfgTxt) {
  try { eco = JSON.parse(cfgTxt).eco === true; }
  catch (_) { eco = /"eco"\s*:\s*true/.test(cfgTxt); }
}

// --- Loop indicator -----------------------------------------------------------
let loopGrp = '';
const loopPath = path.join(root, 'loop.md');
if (isFile(loopPath)) {
  const txt = read(loopPath);
  const rnd = (txt.match(/replan-round\s*:\s*([0-9]+)/) || [])[1];
  const cap = (txt.match(/replan-cap\s*:\s*([0-9]+)/) || [])[1];
  if (rnd && cap) loopGrp = grp(`🔁 r${rnd}/${cap}`);
}

// --- Gather forge state ------------------------------------------------------
let forgeSeg = '';
let pipeline = '';
let flag = '';
let tdd = false;
let haveForge = false;

const planPath = path.join(root, 'plan.md');
if (isFile(planPath)) {
  haveForge = true;
  const planTxt = read(planPath);
  const slug = (planTxt.match(/forge-slug:[\t ]*(\S*)[\t ]*-->/) || [])[1] || 'plan';
  const taskN = (planTxt.match(/<!--[\t ]*task:[\t ]*([0-9]+)[\t ]*-->/) || [])[1] || '';
  tdd = /<!--[\t ]*tdd:[\t ]*on[\t ]*-->/.test(planTxt);
  let stage;
  if (isFile(path.join(root, 'run.md'))) {
    const st = path.join(root, 'STATUS.md');
    let v = '';
    // lowercased — see the .sh twin
    if (isFile(st)) v = ((read(st).match(/^verified:[\t ]*([A-Za-z/]+)/m) || [])[1] || '').toLowerCase();
    switch (v) {
      case 'yes': flag = '✓'; stage = 'learn'; break;
      case 'failed': flag = '✗'; stage = 'run'; break;
      case 'pending': case '': flag = '⏳'; stage = 'run'; break;
      case 'skipped': case 'n/a': flag = ''; stage = 'learn'; break;
      default: flag = '⏳'; stage = 'run';
    }
  } else {
    stage = 'run';
  }
  pipeline = buildPipeline(stage);
  const numBit = taskN ? `#${taskN} ` : '';
  forgeSeg = `${PREFIX}${numBit}${slug}`;
} else if (isFile(path.join(root, 'ask.md'))) {
  haveForge = true;
  const workingSlug = (read(path.join(root, 'ask.md')).match(/forge-ask:[\t ]*(\S*)[\t ]*-->/) || [])[1] || 'ask';
  pipeline = buildPipeline('ask');
  forgeSeg = `${PREFIX}${workingSlug}`;
}

// --- Queue counts ------------------------------------------------------------
const execDir = path.join(root, 'executed');
const backlogDir = path.join(root, 'backlog');
// `awaiting retro` counts only parks that CAN be retro'd — a `verified: failed`
// park is blocked from both retro and seal (fg-run recovery) and is tallied
// separately, the same split the SessionStart hook reports. See the .sh twin.
let awaitN = 0, failedN = 0;
if (isDir(execDir)) {
  for (const d of fs.readdirSync(execDir).filter((f) => isDir(path.join(execDir, f)))) {
    const pv = ((read(path.join(execDir, d, 'STATUS.md')).match(/^verified:[\t ]*([A-Za-z/]+)/m) || [])[1] || '').toLowerCase();
    if (pv === 'failed') failedN++; else awaitN++;
  }
}
const queuedN = isDir(backlogDir) ? fs.readdirSync(backlogDir).filter((f) => f.endsWith('.md')).length : 0;

// Mode indicators render only alongside real activity (an active task or a
// non-empty queue) — never on a fully idle repo or the loop-only fallback, so
// "nothing when idle" holds (ADR-0017). tdd already implies an active plan.
const modesAllowed = haveForge || queuedN > 0 || awaitN > 0 || failedN > 0;
const tddInd = modesAllowed && tdd ? '🧪' : '';
const ecoInd = modesAllowed && eco ? '♻️' : '';

// --- Assemble by density -----------------------------------------------------
const lines = [];
if (DENSITY === 'compact') {
  // Always ONE line (the full script splices it as its L2). Groups: [loop] then
  // either the active forge group (with 📋N count + modes folded in) or, with no
  // active task, a queue-count group. Awaiting-retro (📝) is dropped in compact.
  const countBit = queuedN > 0 ? `📋 ${queuedN}` : '';
  const mainGrp = haveForge
    ? grp(forgeSeg, pipeline, flag, countBit, ecoInd, tddInd)
    : grp(countBit, ecoInd, tddInd);
  const groups = [loopGrp, mainGrp].filter(Boolean);
  if (groups.length) lines.push(groups.join(' '));
} else {
  let line1 = '';
  if (haveForge) {
    const fg = grp(forgeSeg, pipeline, flag);
    line1 = (loopGrp ? `${loopGrp} ` : '') + fg;
  } else if (loopGrp) {
    line1 = loopGrp;
  }
  const queuedBit = queuedN > 0 ? `📋 ${queuedN} queued` : '';
  const awaitBit = awaitN > 0 ? `📝 ${awaitN} awaiting retro` : '';
  const failedBit = failedN > 0 ? `✗ ${failedN} failed` : '';
  const line2 = grp(queuedBit, awaitBit, failedBit, ecoInd, tddInd);
  if (line1) lines.push(line1);
  if (line2) lines.push(line2);
}

if (lines.length === 0) process.exit(0);
process.stdout.write(lines.join('\n') + '\n');
