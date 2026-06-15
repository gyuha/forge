---
name: fg-doctor
description: A read-only integrity health check for forge — surveys the `.forge/` state contract and the persistent docs/manifests, then reports inconsistencies with severity and an actionable fix hint for each. It catches what silently rots in hand-edited Markdown: orphaned run.md, broken/missing STATUS fields, slug-pairing mismatches (plan↔STATUS↔retro), half-sealed done/, manifest version drift across the 3 places, README bilingual drift, and skills missing from CLAUDE.md's list. It writes nothing and never auto-fixes — the fix is yours to make via fg-quick/fg-ask. An on-demand utility outside the loop (the harness `init.sh` health check applied to forge itself — ADR-0019). fg-status reports "where am I", fg-doctor reports "is the state healthy". Use in contexts like 'forge doctor', '무결성 검사', '상태 점검', 'forge 진단', 'health check', '정합성 확인', 'check forge state'.
---

# fg-doctor — state & docs integrity health check (outside the loop)

This is **not** a stage of the forge loop. It is an on-demand, **read-only** utility (like fg-status / fg-map) that answers a different question than fg-status: fg-status reports *"where am I"* (progress + the next step), fg-doctor reports *"is the state healthy"* (integrity violations). It is forge's answer to the harness-engineering `init.sh` health check (ADR-0019) — forge's state contract is hand-edited Markdown, so it can silently break, and nothing else actively verifies it.

It **writes nothing** and **never auto-fixes** — it surveys, classifies each finding by severity, and prints an *actionable fix hint* per finding. The actual fix is the human's to make (via fg-quick / fg-ask). It **never auto-runs** — no other skill invokes it; you run it on demand.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — the report, finding descriptions, fix hints, and the closing line — in the user's language (detect it from the user's own messages), never mirroring this file's English.** Section/severity labels below are canonical English names — render them in the user's language.

**Forge root**: resolve it per `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before reading state (ADR-0011), and apply the resolution **per check group** — they read different scopes:
- **Group A (volatile state)** reads the **resolved branch root only** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Volatile state (plan/run/STATUS/backlog/executed/done) is branch-local, so checking the other branch's slot would be wrong.
- **Group B permanent-doc checks (B13 ADR integrity)** must read the **FORGE-ROOT read overlay**: on a non-default branch the active doc set is top-level `.forge/adr/` **plus** `.forge/branch/<branch>/adr/` (branch wins on conflict — see FORGE-ROOT.md). Validating only the branch root would (a) miss a broken top-level ADR that branch skills actually read, and (b) falsely flag a branch ADR's cross-reference to a top-level ADR as dangling. So validate ADR numbers/cross-refs against the **combined** active set across both roots, plus `retired/` at both levels for numbering. The two global exemptions (`.forge/config.json`, `.forge/codebase/`) stay at the top-level `.forge/` on every branch.
- **Group B repo-root checks (B7–B12: manifests, README, CLAUDE.md, `skills/`)** are plain repo-root files, branch-independent.

## How it runs

Explore with read-only tools (Read, Grep, Glob, Bash) and report. Do **not** edit any file. Work through the two check groups below, collect findings, then print the report. Each check names what to read and what counts as a violation.

## Check group A — state-contract integrity (`.forge/`)

1. **Active-slot single & no orphans.** `.forge/plan.md` is 0 or 1 file. If `.forge/run.md` or `.forge/STATUS.md` exists, `.forge/plan.md` must also exist (an orphaned `run.md`/`STATUS.md` with no plan is a violation — **error**). Read the slot files' presence.
2. **STATUS field validity.** For every `STATUS.md` (active slot, `executed/<slug>/`, `done/<date-slug>/`): `status` ∈ {executed, done}; `verified` ∈ {`yes …`, `skipped …`, `n/a …`, `pending`, `failed …`}; `retro` is `pending`, a `skipped …`, or a retro path. A missing/unparseable required field is a violation — **error** for the active slot / `executed/`, **warning** for legacy `done/` (pre-ADR-0009 may lack `verified:`).
3. **Slug pairing & retro-field consistency.** The plan's first-line `<!-- forge-slug: <slug> -->` must match its `STATUS.md` `slug:`, and a retro (when one exists) must be named `retro/*-<slug>.md`. A mismatch across plan↔STATUS↔retro is a violation — **error** (it breaks fg-learn/fg-done pairing). Also check the `retro:` field against the actual retro file (this guards the "retro file ↔ STATUS field" rule that lives in three places — fg-status/fg-learn/fg-done — against drift):
   - **(a)** STATUS `retro:` is a retro **path** but that `.forge/retro/...` file does not exist → **error** (dangling pairing).
   - **(b)** a `done/<date-slug>/STATUS.md` reads `retro: pending` → **warning** (the seal's close-out left the field unfilled; `retro: skipped` is fine, a retro path is fine).
   - **(c)** in the **active slot / `executed/<slug>`**, a retro file exists for the slug while STATUS still reads `retro: pending` → **normal, not a violation** (pre-seal state — fg-done fills the field at seal time; do not flag it).
4. **Half-sealed done/.** Every `.forge/done/*/STATUS.md` must read `status: done`. A `done/` dir whose STATUS is missing or still `status: executed` is an interrupted seal — **error** (fg-done's pre-check re-enters it; flag it so the human knows).
5. **executed/ consistency.** Each `.forge/executed/<slug>/` holds `plan.md` + `run.md` + `STATUS.md` with `status: executed`. A missing file or wrong status is a violation — **warning**.
6. **Backlog markers & task-number uniqueness.** Each `.forge/backlog/*.md` carries a first-line `forge-slug` and a `task:` marker. Across **all** plans (backlog + active + executed + done), each `task:` number is unique. A missing marker or a duplicate number is a violation — **warning** (duplicate task number = **error**, it breaks fg-run selection / fg-status display).

## Check group B — docs & manifest integrity (repo root, git-tracked)

7. **Manifest version sync.** `.claude-plugin/plugin.json` `version` == `marketplace.json` `metadata.version` == `marketplace.json` `plugins[0].version`. Any mismatch — **error** (a broken release).
8. **Manifest JSON validity.** Both manifests parse as JSON (`node -e "...JSON.parse..."`). Parse failure — **error** (install breaks).
9. **Skill auto-discovery.** Every `skills/*/SKILL.md` has frontmatter `name:` (`awk '/^name:/'` over each). A missing `name` means the skill is not auto-discovered — **error**.
10. **Skill-count consistency.** The number of `skills/*/SKILL.md` matches the count word(s) in the manifest descriptions (e.g. "Fifteen … Eleven more sit outside the loop"). A drift — **warning**.
11. **CLAUDE.md skill-list completeness.** Every skill under `skills/` is mentioned in CLAUDE.md (the loop description or the "루프 밖 스킬 / outside-the-loop" list). A skill present on disk but absent from CLAUDE.md is a violation — **warning** (this is the check that catches the fg-statusline omission).
12. **README bilingual sync.** `README.md` and `README.ko.md` have matching skill rows / list entries (compare the skill table row counts and the skill names listed). A divergence — **warning**.
13. **ADR integrity.** ADR numbers in `.forge/adr/*.md` are contiguous, or any gap is explained by `.forge/adr/retired/` (a retired number is never reused — ADR-0012). Cross-references (`ADR-NNNN`) in active ADRs point to a number that exists (active or retired). A gap with no retired entry, or a dangling reference — **warning**. (On a non-default branch, evaluate this against the combined overlay ADR set — top-level + branch root — per the Forge-root note above, not the branch root alone; otherwise a branch ADR referencing a top-level one falsely reads as dangling.)

## Severity

- **error** — the state contract or a release is actually broken; the loop can stall or installs can fail. Fix before continuing.
- **warning** — drift or an inconsistency that will mislead a future reader/agent but does not block the loop right now.
- **info** — a note worth surfacing (e.g. "pending release: working tree has uncommitted changes past the last version bump").

## Report format

Print in the user's language. Lead with a one-line verdict, then group findings by severity, each with: the check, the offending path(s), and a one-line **actionable fix hint** (how to fix it — not an auto-fix). Close by stating that fg-doctor changed nothing and that fixes are made via fg-quick (trivial) or fg-ask (non-trivial). Example shape:

```
🩺 fg-doctor — N errors, M warnings, K info

[error] Half-sealed done/  — .forge/done/2026-06-10-foo/STATUS.md reads status: executed
   fix: re-run fg-done to finish its close-out (the flip is idempotent)
[warning] CLAUDE.md skill-list — fg-statusline is on disk but absent from the 루프 밖 스킬 list
   fix: add a fg-statusline entry to CLAUDE.md's outside-the-loop paragraph

(Nothing was changed. Fix trivial ones with fg-quick, larger ones with fg-ask.)
```

If everything passes, say so in one line (a clean bill of health) — do not manufacture findings.

```
fg-doctor (read-only)
   │
   ▼
Resolve forge root (ADR-0011)
   ▼
Group A: state-contract checks (active slot · STATUS fields · slug pairing · half-sealed · executed · backlog markers)
   ▼
Group B: docs/manifest checks (version sync · JSON · name frontmatter · skill count · CLAUDE.md list · README bilingual · ADR)
   ▼
Classify each finding (error / warning / info)
   ▼
Print report + per-finding actionable fix hint  (writes NOTHING, never auto-fixes)
```

## Handoff

There is no loop handoff — fg-doctor is self-contained and read-only. End with the verdict line. If there are findings, **state** that fixes are made via fg-quick (trivial) or fg-ask (non-trivial), and stop — do **not** auto-invoke either or start fixing (chaining/acting is the user's call; the same restraint as fg-status). If clean, just confirm the clean bill of health.

## Constraints

- **Read-only.** fg-doctor writes nothing — no `.forge/` state, no docs, no fixes. If you find yourself editing a file, you have left fg-doctor's job.
- **No auto-fix, no auto-run.** It reports; the human fixes on demand. No other skill invokes it.
- **No external hard-dependency.** Checks use core file-system tools (Read/Grep/Glob/Bash) only.

## Document impact

- **None.** fg-doctor creates and modifies nothing. It is pure read-only integrity reporting.
