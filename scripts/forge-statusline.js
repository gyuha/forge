#!/usr/bin/env node
// forge-statusline.js — node twin of forge-statusline.sh (ADR-0022 dual dispatch).
//
// Prints forge progress fragment line(s), identical to forge-statusline.sh for
// the same state (guarded by forge-statusline.parity.test.sh). node is the
// fallback for environments where bash cannot run the .sh — notably
// PowerShell-blocked Windows (the reason this twin exists, ADR-0022). A
// display-only reader (ADR-0017, amended 2026-07-02): it never reproduces
// fg-status's next-step machine.
//
// Output (each line shown independently — NOT precedence-hidden):
//   Line 1 (active slot present):
//     ⚒ [🔁 rN/cap ][#N ]<slug> · ✔ ask → ● run → ○ learn → ○ done[ · flag][ · Ⓣ Ⓔ]
//     (#N comes from the plan's `<!-- task: N -->` marker — omitted when the plan
//     has none; the " · flag" tail appears only when there is a flag; the trailing
//     indicator segment shows Ⓣ when the plan has `<!-- tdd: on -->` and Ⓔ when
//     the TOP-LEVEL .forge/config.json (branch-independent global, ADR-0011) has
//     "eco": true — space-separated when both are on, only the lit one otherwise,
//     and the whole segment omitted when neither is, so with no indicators the
//     line is unchanged and carries no trailing separator)
//   Line 1 (no active slot, but fg-ask is mid-grilling — ask.md marker present):
//     ⚒ <working-slug> · ● ask → ○ run → ○ learn → ○ done[ · Ⓔ]
//     (no #N/Ⓣ at the ask stage — no plan exists yet; Ⓔ still applies)
//   Line 1 fallback (no active slot, no ask.md, but a goal loop is in flight):
//     🔁 rN/cap   (never carries indicators)
//   Line 2 (backlog and/or executed non-empty, independent of line 1):
//     📋 N queued · 📝 M awaiting retro   (either half omitted when zero)
//
// The current stage is gated, not just file-existence-based (ADR-0017, 3rd
// amendment):
//   no plan.md, no ask.md                  -> line 1 empty (or loop-only fallback)
//   no plan.md, ask.md present             -> ask is current (fg-ask grilling; plan.md
//                                              wins over ask.md if both exist)
//   plan.md present, no run.md             -> run is current (only fg-run promotes into
//                                              the active slot, so this is fg-run's
//                                              territory, not fg-ask's)
//   run.md + verified: pending/failed      -> run is current (fg-learn's own retro gate
//                                              refuses these; it is still fg-run's territory)
//   run.md + verified: yes/skipped/n/a     -> learn is current (retro gate passed)
//
// Reads the session JSON on stdin (when piped) to find the project cwd, cd's
// there, then reads the resolved forge root relative to it.
'use strict';

const fs = require('fs');
const path = require('path');
const { resolveForgeRoot } = require('./resolve-forge-root.js');

// --- ANSI helpers (must match forge-statusline.sh's palette) -----------------
const DOT_DONE = '\x1b[32m';     // green — completed stage
const DOT_CUR = '\x1b[1;36m';    // bold cyan — current stage
const DOT_UPCOMING = '\x1b[2m';  // dim — upcoming stage
const RESET = '\x1b[0m';

// The line-1 prefix, default "⚒ ". The "merge" mode unified script
// (forge-statusline-full.js, ADR-0029) REUSES this stage-gating for its forge
// line, invoking it as-is (default "⚒ " — it no longer sets FORGE_SL_PREFIX).
const PREFIX = process.env.FORGE_SL_PREFIX || '⚒ ';

// buildPipeline('ask'|'run'|'learn') -> "✔ ask → ● run → ○ learn → ○ done" (colored)
// "done" is always upcoming here — the active slot never sits at "done" (a
// sealed task moves to .forge/done/ and stops appearing in line 1 entirely);
// it is shown purely to complete the visual picture of the full 4-stage loop.
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
    // JSON.parse so escaped paths decode correctly — a Windows cwd arrives as
    // "C:\\Users\\…" and a raw regex would keep the doubled backslash, so chdir
    // fails and the statusline blanks on the very platform this twin exists for
    // (ADR-0022 review). Fall back to a tolerant regex only if it isn't valid JSON.
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

// --- Eco indicator source (Ⓔ): TOP-LEVEL .forge/config.json -------------------
// Branch-independent global exception (ADR-0011) — the same top-level cfg
// resolveForgeRoot reads for defaultBranch, so strip any /branch/<branch> tail
// off the resolved root. fg-eco owns the key; this only reads it. JSON.parse
// first, tolerant regex fallback for a malformed-but-greppable config (parity
// with the .sh twin's sed read — ADR-0022).
let eco = false;
const cfgTxt = read(path.join(root.replace(/(\.forge)[\/\\]branch[\/\\].*$/, '$1'), 'config.json'));
if (cfgTxt) {
  try { eco = JSON.parse(cfgTxt).eco === true; }
  catch (_) { eco = /"eco"\s*:\s*true/.test(cfgTxt); }
}

// --- Loop indicator -----------------------------------------------------------
let loopIndicator = '';
const loopPath = path.join(root, 'loop.md');
if (isFile(loopPath)) {
  const txt = read(loopPath);
  const rnd = (txt.match(/replan-round\s*:\s*([0-9]+)/) || [])[1];
  const cap = (txt.match(/replan-cap\s*:\s*([0-9]+)/) || [])[1];
  if (rnd && cap) loopIndicator = `🔁 r${rnd}/${cap}`;
}

// --- Line 1: active slot, or the loop-only fallback ---------------------------
let line1 = '';
const planPath = path.join(root, 'plan.md');
if (isFile(planPath)) {
  const planTxt = read(planPath);
  const slug = (planTxt.match(/forge-slug:[\t ]*(\S*)[\t ]*-->/) || [])[1] || 'plan';
  // #N from the plan's `<!-- task: N -->` marker (marker-anchored, same style as
  // the forge-slug parse above) — omitted when the plan carries no marker.
  const taskN = (planTxt.match(/<!--[\t ]*task:[\t ]*([0-9]+)[\t ]*-->/) || [])[1] || '';
  // Ⓣ only for an explicit `<!-- tdd: on -->` marker ("tdd: off" must not light up).
  const tdd = /<!--[\t ]*tdd:[\t ]*on[\t ]*-->/.test(planTxt);
  let stage, flag = '';
  if (isFile(path.join(root, 'run.md'))) {
    const st = path.join(root, 'STATUS.md');
    let v = '';
    if (isFile(st)) v = (read(st).match(/^verified:[\t ]*([A-Za-z/]+)/m) || [])[1] || '';
    // verified not yet sealable (pending/failed/missing) -> still fg-run's territory
    // (fg-learn's own retro gate refuses these); sealable -> retro gate passed, learn is current.
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
  const pipeline = buildPipeline(stage);
  const prefixBit = loopIndicator ? `${loopIndicator} ` : '';
  const numBit = taskN ? `#${taskN} ` : '';
  // Trailing indicator segment " · Ⓣ Ⓔ" — space-separated, only the lit ones,
  // whole segment omitted when neither is on (no trailing separator otherwise).
  const indicators = [tdd ? 'Ⓣ' : '', eco ? 'Ⓔ' : ''].filter(Boolean).join(' ');
  line1 = `${PREFIX}${prefixBit}${numBit}${slug} · ${pipeline}${flag ? ` · ${flag}` : ''}${indicators ? ` · ${indicators}` : ''}`;
} else if (isFile(path.join(root, 'ask.md'))) {
  const workingSlug = (read(path.join(root, 'ask.md')).match(/forge-ask:[\t ]*(\S*)[\t ]*-->/) || [])[1] || 'ask';
  const pipeline = buildPipeline('ask');
  // No #N/Ⓣ at the ask stage (no plan yet); Ⓔ still applies to the ask line.
  line1 = `${PREFIX}${workingSlug} · ${pipeline}${eco ? ' · Ⓔ' : ''}`;
} else if (loopIndicator) {
  line1 = loopIndicator;
}

// --- Line 2: pending summary (backlog + executed), independent of line 1 -----
const execDir = path.join(root, 'executed');
const backlogDir = path.join(root, 'backlog');
const awaitN = isDir(execDir) ? fs.readdirSync(execDir).filter((f) => isDir(path.join(execDir, f))).length : 0;
const queuedN = isDir(backlogDir) ? fs.readdirSync(backlogDir).filter((f) => f.endsWith('.md')).length : 0;

const parts = [];
if (queuedN > 0) parts.push(`📋 ${queuedN} queued`);
if (awaitN > 0) parts.push(`📝 ${awaitN} awaiting retro`);
const line2 = parts.join(' · ');

// --- Emit ----------------------------------------------------------------------
const lines = [line1, line2].filter(Boolean);
if (lines.length === 0) process.exit(0);
process.stdout.write(lines.join('\n') + '\n');
