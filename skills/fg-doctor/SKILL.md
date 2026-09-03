---
name: fg-doctor
description: A read-only integrity health check for forge — a deterministic script (forge-doctor.sh/.js) surveys the .forge/ state contract and docs/manifests and reports inconsistencies with severity + fix hints, exiting 0/1/2 so it doubles as an AI-free CI gate. Catches orphaned/broken state, half-sealed done/, an un-integrated branch root, version drift, README bilingual drift, ADR-ID issues, missing script twins. Writes nothing, never auto-fixes (fg-status: where am I; fg-doctor: is the state healthy). Use in contexts like 'forge doctor', '무결성 검사', '상태 점검', 'health check', 'check forge state'.
---

# fg-doctor — state & docs integrity health check (outside the loop)

This is **not** a stage of the forge loop. It is an on-demand, **read-only** utility (like fg-status / fg-map) that answers a different question than fg-status: fg-status reports *"where am I"* (progress + the next step), fg-doctor reports *"is the state healthy"* (integrity violations). It is forge's answer to the harness-engineering `init.sh` health check (ADR-0019) — forge's state contract is hand-edited Markdown, so it can silently break, and nothing else actively verifies it.

It **writes nothing** and **never auto-fixes** — it surveys, classifies each finding by severity, and prints an *actionable fix hint* per finding. The actual fix is the human's to make (via fg-quick / fg-ask). It **never auto-runs** — no other skill invokes it; you run it on demand.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — the relayed report, and the closing line — in the user's language (detect it from the user's own messages), never mirroring this file's English.** The script's finding tokens are language-neutral; render the report in the user's language.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

## How it runs (script-backed survey — ADR-0020 / ADR-0022)

The mechanical survey — walking the `.forge/` state contract and the docs/manifests, classifying each finding, computing the severity — is done by a **deterministic script**, not by an LLM re-reading everything and hand-reasoning each check in tokens (that was slow and drift-prone; the same problem ADR-0020 fixed for fg-status). This skill **runs the script and relays its report** in the user's language; it does not re-survey.

The script exists so the check **also works AI-free as a CI gate** (see "CI usage"): a pipeline runs `forge-doctor.sh` and fails the build on a non-zero exit. Like fg-status's survey it is **read-only** — it mutates nothing (fg-doctor's contract, ADR-0019). Guarded by `scripts/forge-doctor.test.sh` + `scripts/forge-doctor.parity.test.sh`.

Dual dispatch (ADR-0022): prefer bash, fall back to node.
- **Has bash**: `bash "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/forge-doctor.sh"`
- **No bash** (e.g. PowerShell-blocked Windows): `node "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/forge-doctor.js"` — identical findings/severity/exit (guarded by the parity test).

**Output**: one `[severity] check — path\n   fix: hint` line per finding, then a verdict line `🩺 forge-doctor — N errors, M warnings, K info`. **Exit code**: `0` clean · `1` warnings only · `2` one or more errors.

**Route on the exit code / relay:**
- **exit 0** → relay the clean bill of health in one line (do not manufacture findings).
- **exit 1 / 2** → relay the findings grouped by severity, each with its path and fix hint, in the user's language. Then **state** that fg-doctor changed nothing and that fixes are the human's to make — trivial ones via **fg-quick**, larger ones via **fg-ask**. Do **not** auto-fix or auto-invoke either (the same read-only restraint as fg-status).

## What the script checks (its contract — keep in sync if the script changes, per ADR-0020)

The two sections below **document the script's checks** so the contract is legible; the script is the source of truth for how they run. It resolves the forge root per FORGE-ROOT.md (ADR-0011) and applies it per group (Group A = the resolved branch root; Group B ADR check = the read overlay across top-level + branch root; other Group B = repo-root files). It **ignores `.forge/dropped/`** (fg-drop's archive — out of the active contract, ADR-0021) and accepts both STATUS field forms (`field:` and the legacy `- field:`).

**Group A — state-contract integrity (`.forge/`):**
1. **A1 active-slot orphan** — a `run.md`/`STATUS.md` with no `plan.md` — **error**.
2. **A2 STATUS field validity** — `status` ∈ {executed, done}; `verified` ∈ {yes/skipped/n/a/pending/failed}; `retro` pending/skipped/path. Missing/invalid — **error** (active/executed), **warning** (legacy done may lack `verified:`).
3. **A3 slug pairing & retro consistency** — plan `forge-slug` == STATUS `slug`; a `retro:` path must point to an existing file (dangling — **error**); a `done/` reading `retro: pending` — **warning**.
4. **A4 half-sealed done/** — every `done/*/STATUS.md` reads `status: done`; else — **error**.
5. **A5 executed/ consistency** — each `executed/<slug>/` has plan+run+STATUS at `status: executed`; else — **warning**.
6. **A6 backlog markers & task-number uniqueness** — each backlog plan has `forge-slug`+`task:`; a duplicate `task:` across all plans — **error** (missing marker — **warning**).
7. **A7 stale ask.md** — `ask.md` older than 1 day — **warning**.
8. **A8 orphaned branch root (NEW)** — a `.forge/branch/<other>/` leaf root present on this branch — **warning**, hint: "did you forget `fg-merge <branch>` after the git merge?" This is the team safety net for the "merged but never integrated" silent data-loss gap.

**Group B — docs & manifest integrity (repo root / ADR overlay):**
- **B8 manifest version sync** (3 places) — **error**. **B9 manifest JSON validity** — **error**. **B10 skill `name:` frontmatter** — **error**. **B12 CLAUDE.md skill-list completeness** — **warning**. **B13 README bilingual skill-row parity** — **warning**. **B15 script twin parity** (`.sh`↔`.js`, excluding `*.test.sh`/`*.parity.test.sh`/`*-wrapper.sh`) — **warning**.
- **B14 ADR integrity — two-format aware.** Time-based IDs (`YYMMDD-HH`+letter, ADR-FORMAT.md) are **not** treated as `NNNN` gaps; NNNN contiguity is checked only over the grandfathered `NNNN` set (incl. `retired/`); and a **duplicate time-based ID** (two ADRs sharing the same `YYMMDD-HH`+letter) is flagged — **error** (gap in the NNNN set — **warning**). (Analogous to A6's task-number uniqueness; keeps the check honest on the repo that dogfooded the time-based scheme.)
- **B16 SKILL.md description length** — each `skills/*/SKILL.md` frontmatter `description` is measured in Unicode codepoints (locale-independent, matching the `/fg` menu's char cap and the `.js` twin) and flagged when it exceeds **600** — **warning**. The `description` is dual-use (`/fg` menu display + auto-invocation trigger, same char cap), so it must stay a terse trigger core; this lint guards that discipline from silently re-bloating (drift, not breakage → warning, per ADR 260716-22a).

- **B17 always-on `Explaining forge` rule** — every `skills/*/SKILL.md` must carry the canonical always-on explanation paragraph (gloss a forge term on first use · purpose before mechanism · lead with the answer). The canonical body has a single definition in `scripts/explaining-forge.rule.txt`, and the check requires it **verbatim by containment** — so a heading kept over a deleted, truncated, weakened or negated body fails, while a deliberate superset passes (`skills/fg-ask/SKILL.md` appends one sentence; no exception list needed). Flagged as **warning**, matching the rubric below and its prose-drift siblings B12/B13/B15/B16 — a missing style paragraph misleads, it does not break the release. **Scoped to the forge plugin repo itself** via the *top-level* manifest `name`, so a user project's own skills are never told to carry forge's internal rule (a nested `"author": {"name": "forge"}` does not trigger it). Rationale and why it is not part of `eco`: ADR `260824-134246`.

Severity: **error** = state/release actually broken (fix before continuing) · **warning** = drift that misleads but doesn't block · **info** = a note.

## CI usage (AI-free)

Because the survey is a deterministic script with a clean exit-code contract, a CI job runs it with no AI:

```
bash scripts/forge-doctor.sh   # exit 0 clean · 1 warnings · 2 errors
```

Wire the gate to your tolerance: fail on **non-zero** (strict — no warnings allowed) or on **`>= 2`** (block only on errors, allow warnings). It fixes nothing — a failing gate means a human resolves the reported findings locally (fg-quick/fg-ask), then re-pushes. (The example workflow that wires this lives in the `team-ci-workflow-merge-policy-docs` task.)

```
fg-doctor (read-only)
   │  run forge-doctor.sh (bash) | forge-doctor.js (no bash)
   ▼
exit 0 ──▶ relay clean bill of health
exit 1/2 ──▶ relay findings (severity · path · fix hint) → state fixes are the human's (fg-quick/fg-ask), auto-fix nothing
```

## Handoff

There is no loop handoff — fg-doctor is self-contained and read-only. Relay the verdict; when it names a next step (findings present), do it as the **handoff table** per [`../fg-next/HANDOFF.md`](../fg-next/HANDOFF.md) — the single definition of its shape; never restate that layout here. Statement form, in the user's language; do **not** auto-invoke anything or start fixing (the same restraint as fg-status).

- `Just did` = the verdict in one line: the exit code and its meaning (clean / N warnings / N errors).
- **Findings present** → the fix route is keyed to the findings **actually reported**, by the first case that applies:
  1. **Any non-trivial finding is in the report** (version drift across the three manifest locations, README bilingual drift, a half-sealed `done/`, an un-integrated branch root — anything needing a plan rather than a one-line edit) → `Next step` = `fg-ask` (the full loop), `How to start` = `/forge:fg-ask`; `Alternative` = `fg-quick` for the trivial findings in the same report.
  2. **Only trivial findings** (a stray path, a single field to correct) → `Next step` = `fg-quick`, `How to start` = `/forge:fg-quick`; `Alternative` = `fg-ask`, should one turn out non-trivial.

  Judge triviality per finding from the fix hint the script reported, and let the heaviest one decide. Neither route is auto-invoked (see Constraints).
- **Clean (exit 0)** → **render no table at all.** State the clean bill of health in one line and stop. There is no next step here, so a table would only carry rows saying "nothing to fix" / "nothing to trigger" — the information-free rows HANDOFF.md rules out, and the same reason it excludes the skills that have nothing to point at. Deriving where the user was in the loop instead is **not** this skill's job: fg-doctor reads health, not progress, and never runs fg-status's next-step state machine (fg-status: where am I; fg-doctor: is the state healthy).

The findings themselves are list-shaped, so they go **below** the table as bullets (HANDOFF.md, "List-shaped content goes below the table"): one line each carrying **severity · path · fix hint**, exactly as the script reported them. The table says *that* the state is unhealthy; these lines say *what* to fix, so they are never compressed into a cell or dropped.

## Constraints

- **Read-only.** Neither this skill nor the script writes anything — no `.forge/` state, no docs, no fixes. If you find yourself editing a file, you have left fg-doctor's job.
- **No auto-fix, no auto-run.** It reports; the human fixes on demand. No other skill invokes it.
- **No external hard-dependency.** The script uses core tools only (bash/coreutils/awk/sed/grep; node for the twin and the JSON-parse check).

## Document impact

- **None.** fg-doctor creates and modifies nothing. It is pure read-only integrity reporting; the survey is `scripts/forge-doctor.sh` / `.js` (ADR-0022 / 260716-16a).
