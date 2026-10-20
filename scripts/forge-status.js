#!/usr/bin/env node
// forge-status.js — node twin of forge-status.sh (ADR-0022 dual dispatch).
//
// Must produce output identical to forge-status.sh for the same .forge state,
// in both full and --table modes (guarded by forge-status.parity.test.sh).
// node is the fallback when bash is unavailable (e.g. PowerShell-blocked
// Windows where the .sh cannot run); bash stays the primary path.
//
// Why this exists (ADR-0020): the deterministic survey + 6-column table is a
// script so fg-status need not have an LLM re-derive it; the next-step priority
// machine stays in fg-status's prose (this script never derives the next step).
//
// Usage:  node forge-status.js [--table]
"use strict";

const fs = require("fs");
const path = require("path");
const { resolveForgeRoot } = require("./resolve-forge-root.js");

const tableOnly = process.argv[2] === "--table";

// --- Resolve forge root via the shared resolver (ADR-0011 / ADR-0022) --------
const root = resolveForgeRoot().root;

const { surveyForge } = require("./forge-status-query.js");
const { exists, rows, footer } = surveyForge(root);
if (!exists) {
  process.stdout.write(
    `No forge state (no ${root}/). Start a task with fg-ask.\n`,
  );
  process.exit(0);
}
// --- Emit table (replicate the .sh `LC_ALL=C awk` aligner) ------------------
// Pad by UTF-8 BYTE length, not String.length: the bash twin aligns with
// `LC_ALL=C awk` whose length() counts bytes, so a multibyte (e.g. Hangul) slug
// would otherwise pad differently here and break sh↔js parity (ADR-0022 review).
const blen = (s) => Buffer.byteLength(s || "", "utf8");
const padBytes = (s, w) => (s || "") + " ".repeat(Math.max(0, w - blen(s)));
const header = ["No.", "Date", "Task", "Stage", "Verify", "Retro"];
const all = [header, ...rows];
const ncol = header.length;
const width = [];
for (let c = 0; c < ncol; c++) {
  width[c] = Math.max(...all.map((r) => blen(r[c])));
}
const lines = all.map((r) =>
  r
    .map((cell, c) => padBytes(cell, width[c]))
    .join("  ")
    .replace(/\s+$/, ""),
);
process.stdout.write(lines.join("\n") + "\n");

if (tableOnly) process.exit(0);

// --- Footer (counts + loop), full mode only ---------------------------------
process.stdout.write("\n" + footer + "\n");
