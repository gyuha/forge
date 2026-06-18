#!/usr/bin/env node
// forge-statusline.js — node twin of forge-statusline.sh (ADR-0022 dual dispatch).
//
// Prints a compact one-line forge progress fragment, identical to
// forge-statusline.sh for the same state (guarded by
// forge-statusline.parity.test.sh). node is the fallback for environments where
// bash cannot run the .sh — notably PowerShell-blocked Windows (the reason this
// twin exists, ADR-0022). A display-only reader (ADR-0017): it never reproduces
// fg-status's next-step machine.
//
// Reads the session JSON on stdin (when piped) to find the project cwd, cd's
// there, then reads the resolved forge root relative to it.
'use strict';

const fs = require('fs');
const path = require('path');
const { resolveForgeRoot } = require('./resolve-forge-root.js');

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

// --- Loop indicator (prefix) -------------------------------------------------
let loop = '';
const loopPath = path.join(root, 'loop.md');
if (isFile(loopPath)) {
  const txt = read(loopPath);
  const rnd = (txt.match(/replan-round\s*:\s*([0-9]+)/) || [])[1];
  const cap = (txt.match(/replan-cap\s*:\s*([0-9]+)/) || [])[1];
  if (rnd && cap) loop = `🔁 r${rnd}/${cap} `;
}

// --- Determine the single segment (active > executed > backlog) ---------------
let segment = '';
const planPath = path.join(root, 'plan.md');
if (isFile(planPath)) {
  let slug = (read(planPath).match(/forge-slug:[\t ]*(\S*)[\t ]*-->/) || [])[1] || 'plan';
  if (isFile(path.join(root, 'run.md'))) {
    let flag = ' ⏳';
    const st = path.join(root, 'STATUS.md');
    if (isFile(st)) {
      const v = (read(st).match(/^verified:[\t ]*([A-Za-z/]+)/m) || [])[1] || '';
      switch (v) {
        case 'yes': flag = ' ✓'; break;
        case 'failed': flag = ' ✗'; break;
        case 'pending': case '': flag = ' ⏳'; break;
        case 'skipped': case 'n/a': flag = ''; break;
        default: flag = ' ⏳';
      }
    }
    segment = `${slug}:learn${flag}`;
  } else {
    segment = `${slug}:run`;
  }
} else {
  const execDir = path.join(root, 'executed');
  const backlogDir = path.join(root, 'backlog');
  const execSub = isDir(execDir) ? fs.readdirSync(execDir).filter((f) => isDir(path.join(execDir, f))) : [];
  const backlogMd = isDir(backlogDir) ? fs.readdirSync(backlogDir).filter((f) => f.endsWith('.md')) : [];
  if (execSub.length > 0) {
    segment = `📝 ${execSub.length} awaiting retro`;
  } else if (backlogMd.length > 0) {
    segment = `📋 ${backlogMd.length} queued`;
  }
}

// --- Emit --------------------------------------------------------------------
if (!segment && !loop) process.exit(0);
let out = `⚒ ${loop}${segment}`;
out = out.replace(/\s+$/, '');
process.stdout.write(out + '\n');
