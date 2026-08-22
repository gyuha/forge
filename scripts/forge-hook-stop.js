#!/usr/bin/env node
// forge-hook-stop.js — node twin of forge-hook-stop.sh (ADR-0022 dual dispatch).
// Stop hook body: keeps an unattended forge drive going across turn boundaries
// without the harness `/goal` (ADR-0028 amended 2026-08-22).
//
// Read forge-hook-stop.sh's header for the WHY (it is the primary). The safety
// invariant is identical and non-negotiable: every failure and every ambiguous
// path allows stopping (exit 0); only a marker that exists AND is inside both
// bounds AND belongs to this session blocks (exit 2). The harness offers no loop
// protection for Stop hooks, so these bounds are the only runaway guard.
//
// DELIBERATELY IMPLEMENTED DIFFERENTLY from the bash twin: bash greps/seds the
// raw text, this parses structure (JSON.parse for the payload, a line map for the
// marker). Two twins sharing one parsing strategy share its bugs and parity goes
// green on a wrong answer — the failure ADR-0022's 2026-08-20 amendment records.
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const MAX_AGE = 1800;    // 30 min — clears a marker left by a dead session
const MAX_BLOCKED = 50;  // stops a drive re-deriving the same step

const allow = () => process.exit(0);   // the default verdict, used everywhere

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 && i + 1 < process.argv.length ? process.argv[i + 1] : null;
}

try {
  // --- clock -------------------------------------------------------------
  const nowRaw = arg('--now');
  const now = /^[0-9]+$/.test(String(nowRaw || ''))
    ? Number(nowRaw)
    : Math.floor(Date.now() / 1000);
  if (!Number.isFinite(now)) allow();

  // --- payload: structured parse, not a regex ----------------------------
  let sid = null;
  if (!process.stdin.isTTY) {
    let raw = '';
    try { raw = fs.readFileSync(0, 'utf8'); } catch { raw = ''; }
    try {
      const obj = JSON.parse(raw);
      if (obj && typeof obj.session_id === 'string' && obj.session_id) sid = obj.session_id;
    } catch { sid = null; }   // unparseable payload -> cannot prove ownership
  }
  if (!sid) allow();

  // --- forge root: reuse the shared resolver, silencing its detached-HEAD
  //     warning (any stderr here would become the exit-2 blocking message and
  //     would break the exit-0-is-silent contract).
  let root = '';
  try {
    root = execFileSync('bash', [path.join(__dirname, 'resolve-forge-root.sh')],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch { root = ''; }
  if (!root) allow();

  const marker = path.join(root, 'drive.md');
  let text;
  try { text = fs.readFileSync(marker, 'utf8'); } catch { allow(); }

  // --- marker: build a field map, then validate every field --------------
  const fields = new Map();
  for (const line of text.split('\n')) {
    const m = /^([A-Za-z-]+):[ \t]*(\S*)/.exec(line.replace(/\r/g, ''));
    if (m && !fields.has(m[1])) fields.set(m[1], m[2]);
  }
  const started = fields.get('started');
  const blocked = fields.get('blocked');
  const msession = fields.get('session');
  if (!/^[0-9]+$/.test(String(started || ''))) allow();
  if (!/^[0-9]+$/.test(String(blocked || ''))) allow();
  if (!msession) allow();
  if (msession !== sid) allow();                       // another session's drive
  if (now - Number(started) > MAX_AGE) allow();
  if (Number(blocked) >= MAX_BLOCKED) allow();

  // --- bump the counter BEFORE blocking; an unrecordable block would make the
  //     iteration bound unenforceable, so a write failure allows stopping.
  const next = Number(blocked) + 1;
  // [^\n]* not .* : in JS `\r` is NOT a line terminator for `.`, but it IS for
  // the `m` flag's `$`, so `.*$` would leave the original \r behind and the two
  // twins would write byte-different files (the exact defect the loop-spend
  // parity test caught).
  const updated = text.replace(/^blocked:[^\n]*/m, `blocked: ${next}`);
  const tmp = `${marker}.tmp.${process.pid}`;
  try {
    fs.writeFileSync(tmp, updated);
    fs.renameSync(tmp, marker);
  } catch {
    try { fs.unlinkSync(tmp); } catch { /* nothing to clean */ }
    allow();
  }

  process.stderr.write(
    `forge drive in progress (${next}/${MAX_BLOCKED} blocked stops). Do not stop: ` +
    `derive the next step via fg-status's state machine and continue the drive. ` +
    `Delete ${marker} when you reach the terminal state or a wall.\n`);
  process.exit(2);
} catch {
  allow();   // any unforeseen throw must still allow stopping
}
