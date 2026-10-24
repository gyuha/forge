#!/usr/bin/env node
// forge-plan-lint.js — node twin of forge-plan-lint.sh (ADR-0022 dual dispatch).
// Same checks, same output lines, same exit code; see the .sh header for the
// rationale and the code table. Parity: scripts/forge-plan-lint.parity.test.sh.
// Dependencies: Node built-ins only.
'use strict';
const fs = require('fs');

const f = process.argv[2] || '';
if (!f) { console.log('forge-plan-lint: usage: forge-plan-lint.sh <plan-file>'); process.exit(2); }
let text;
try { if (!fs.statSync(f).isFile()) throw new Error(); text = fs.readFileSync(f, 'utf8'); }
catch { console.log(`forge-plan-lint: cannot read ${f}`); process.exit(2); }

let errors = 0, warnings = 0;
const err = (c, d) => { console.log(`ERROR ${c} ${d}`); errors++; };
const warn = (c, d) => { console.log(`WARN ${c} ${d}`); warnings++; };

const lines = text.split('\n').map(l => l.replace(/\r$/, ''));
if (lines.length && lines[lines.length - 1] === '') lines.pop();

const markerRe = /^<!-- ([a-z-]+): (.*) -->\s*$/;
// A slice line: list item (checkbox and **bold** optional) or a ##–#### heading starting with S<n> (see the .sh).
const sliceRe = /^\s*(- (\[[ xX]\] )?(\*\*)?|#{2,4} )(S[0-9]+)([.:)]|\*\*|\s|$)/;

// E1 — forge-slug on the first line
if (!/^<!-- forge-slug: \S.* -->\s*$/.test(lines[0] || '')) err('E1', 'first line must be <!-- forge-slug: <slug> -->');

const slices = new Set(); const deps = []; const evals = []; const listItems = [], headItems = [];
let hasTask = false, generated = false, playbook = '', pbs = 0; const pins = [];
for (const l of lines) {
  const s = sliceRe.exec(l);
  if (s) {
    const d = /\(depends: ([^)]*)\)/.exec(l);
    // Headings are kept apart — see the .sh twin.
    (/^\s*#/.test(l) ? headItems : listItems).push([s[4], d ? d[1] : '']);
    continue;
  }
  const m = markerRe.exec(l);
  if (!m) continue;
  const [, key, val] = m;
  if (key === 'task') { hasTask = true; if (!/^[0-9]+$/.test(val)) err('E5', `task: ${val}`); }
  else if (key === 'tdd') { if (!['on', 'off'].includes(val)) err('E5', `tdd: ${val}`); }
  else if (key === 'priority') { if (!['high', 'medium', 'low'].includes(val)) err('E5', `priority: ${val}`); }
  else if (key === 'part') {
    const p = /^([0-9]+)\/([0-9]+)$/.exec(val);
    if (!p) err('E5', `part: ${val}`);
    else { const n = parseInt(p[1], 10), mm = parseInt(p[2], 10); if (!(n >= 1 && n <= mm)) err('E5', `part: ${val}`); }
  }
  else if (key === 'generated-by') generated = true;
  else if (key === 'eval') evals.push(val);
  else if (key === 'playbook') { pbs++; if (['bug-fix', 'refactor'].includes(val)) playbook = val; else err('E5', `playbook: ${val}`); }
  else if (key === 'pin') pins.push(val);
}
if (pbs > 1) err('E5', `playbook: one per plan (${pbs} markers)`);

// `none — <reason>`: true when text follows `none` past one separator (— / - / :).
const noneReason = (v) => {
  let r = v.slice(4).replace(/^\s+/, '');
  if (r.startsWith('—')) r = r.slice(1); else if (r.startsWith('-') || r.startsWith(':')) r = r.slice(1);
  return r.replace(/^\s+/, '') !== '';
};

// Slices = list items; heading-form slices count only when there are no list items.
for (const [id, dep] of (listItems.length ? listItems : headItems)) {
  if (slices.has(id)) err('E3', id); else slices.add(id);
  if (dep) deps.push([id, dep]);
}
if (slices.size === 0) err('E2', "no '- [ ] S<n>.' slice");

// E4 — every depends reference must exist
for (const [from, rest] of deps) for (const ref of rest.match(/S[0-9]+/g) || []) if (!slices.has(ref)) err('E4', `${from}->${ref}`);

// E6/E7 — fix-forward eval marker (PLAN-FORMAT.md fix-forward eval rule)
for (const v of evals) {
  if (v.startsWith('none')) {
    if (!noneReason(v)) err('E7', 'eval: none needs a reason');
  } else if (/^S[0-9]+(\s*,\s*S[0-9]+)*$/.test(v)) {
    for (const ref of v.match(/S[0-9]+/g)) if (!slices.has(ref)) err('E7', `eval: ${ref} is not a slice`);
  } else err('E7', `eval: ${v}`);
}
if ((generated || playbook === 'bug-fix') && evals.length === 0) err('E6', 'fix-forward plan (generated-by) or bug-fix playbook needs <!-- eval: S<n> --> or <!-- eval: none — <reason> -->');

// E8/E9 — playbooks (see the .sh twin)
let pinOk = '';
for (const v of pins) {
  if (v.startsWith('none')) { if (!noneReason(v)) err('E8', 'pin: none needs a reason'); }
  else if (/^S[0-9]+$/.test(v)) { if (slices.has(v)) pinOk = v; else err('E8', `pin: ${v} is not a slice`); }
  else err('E8', `pin: ${v}`);
}
if (playbook === 'refactor') {
  if (pins.length === 0) err('E8', 'refactor playbook needs <!-- pin: S<n> --> or <!-- pin: none — <reason> -->');
  else if (pins.length === 1 && pinOk) {
    const reached = new Set([pinOk]); let changed = true;
    while (changed) {
      changed = false;
      for (const [from, rest] of deps) {
        if (reached.has(from)) continue;
        if ((rest.match(/S[0-9]+/g) || []).some((r) => reached.has(r))) { reached.add(from); changed = true; }
      }
    }
    for (const id of slices) if (!reached.has(id)) err('E9', `${id} does not depend on pin ${pinOk}`);
  }
}

if (!hasTask) warn('W1', 'no <!-- task: N --> marker');

console.log(`forge-plan-lint: ${errors} errors, ${warnings} warnings`);
process.exit(errors === 0 ? 0 : 1);
