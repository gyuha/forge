---
name: fg-merge
description: Integrates a non-default branch's forge content (`.forge/branch/<branch>/`) into the default-branch `.forge/` after a git merge — renumbering the branch's ADRs to the next free numbers (rewriting cross-references), moving retros, merging CONTEXT.md glossary terms, folding in done/ history, then removing the branch folder. Mechanical parts run automatically; genuine conflicts (a term redefined, an incoming ADR that contradicts one added on the default branch) halt and ask the human. It does NOT run git — you `git merge` first, then run fg-merge. An on-demand utility outside the loop. Use in contexts like 'forge merge', 'fg-merge <branch>', '브랜치 통합', '브랜치 forge 합쳐줘'.
---

# fg-merge — integrate a branch's forge content into `.forge/` (outside the loop)

This is **not** a stage of the forge loop. It is the integration step for branch isolation (ADR-0011): when a feature branch has been run with its forge state under `.forge/branch/<branch>/` (a git-tracked, namespaced mini-root — see `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md`), fg-merge folds that branch's permanent forge docs into the default-branch `.forge/`.

**Language**: This skill file is authored in English, but always converse with the user in the user's language. The integration summary and any conflict question are written in the user's language.

## Precondition: git merge first, fg-merge second

fg-merge does **not** run git — that is a non-goal. The expected order (ADR-0011):

1. You finish and seal the branch's loop (its `done/` lives under `.forge/branch/<branch>/done/`).
2. **You** `git merge <branch>` into the default branch. Because `.forge/branch/<branch>/` is namespaced, git brings the whole folder in **without conflict** (the default branch had no such path).
3. **Then** run `fg-merge <branch>` on the default branch. It reads `.forge/branch/<branch>/` and integrates its permanent docs into the top-level `.forge/`.

If `.forge/branch/<branch>/` is not present on the default branch (e.g. you haven't merged yet, or the name is wrong), stop and say so — there is nothing to integrate.

## What it integrates (and what it does not)

Resolve nothing here — fg-merge always reads the literal `.forge/branch/<branch>/` (source) and writes the literal top-level `.forge/` (target). It integrates the branch root's **permanent docs**:

- **ADRs** (`.forge/branch/<branch>/adr/*`) → renumbered into `.forge/adr/` (see the procedure below).
- **Retros** (`.forge/branch/<branch>/retro/*`) → moved into `.forge/retro/`; on a filename (`YYYY-MM-DD-slug`) collision, disambiguate with a `-2` suffix.
- **CONTEXT.md** (`.forge/branch/<branch>/CONTEXT.md`) → glossary terms merged **term-by-term** into `.forge/CONTEXT.md` (append new terms; a term defined in both is a conflict — see the gate).
- **done/ history** (`.forge/branch/<branch>/done/*`) → moved into `.forge/done/` (local archive record; disambiguate dir names on collision).

**Create each target directory lazily.** If `.forge/adr/`, `.forge/retro/`, or `.forge/done/` does not yet exist on the default branch (e.g. a fresh repo whose first sealed/decided work happened on the branch), create it on the way in — its absence is not an error, just the lazy-creation convention. (Verified by the fg-merge lifecycle e2e test: a target missing `done/` would otherwise drop the folded history.)

**Not integrated** (the two global exemptions of ADR-0011 — they were never branch-local): **`.forge/config.json`** and **`.forge/codebase/`**. Leave them untouched; they already live at the top level.

**Volatile loop state** under the branch root (`plan.md`/`run.md`/`STATUS.md`/`backlog/`/`executed/`) is throwaway — a sealed branch has already moved its work into `done/`. If unsealed volatile state remains (an in-flight task on the branch), **halt and warn**: the branch loop should be sealed (or its plan moved back to the backlog) before integrating, not silently discarded.

## ADR renumbering procedure

ADR numbers are assigned at creation as `max+1` per root, so a branch and the default branch can independently mint the same number. fg-merge resolves this deterministically at integration:

1. Find the highest existing ADR number in the **target** `.forge/adr/` (e.g. `0011`).
2. Take the branch's incoming ADRs **in ascending order of their current number** and assign them the next free numbers in sequence (`0012`, `0013`, …). Renaming preserves order so references read naturally.
3. For each renamed ADR, rewrite every **`ADR-NNNN`** (and `NNNN-slug` filename) reference to its new number — **both** inside the ADR's own body **and** in every other doc that points at it: other ADRs, the moved retros, `CONTEXT.md`, and any `done/` plan/run notes being folded in. A reference left pointing at the old number is a silent breakage.
4. After renumbering, grep the integrated set for stale `ADR-<oldnumber>` references and report any that remain.

> **Warn loudly if cross-reference rewriting is incomplete.** The whole value of deferring numbering to merge time is lost if a renamed ADR is still referenced by its old number somewhere. Surface unresolved references rather than sealing silently.

## Mechanical-auto, conversational-on-conflict

Run the safe mechanical parts automatically: renumber ADRs, move retros, append non-conflicting CONTEXT terms, fold in done/, and (last) remove the branch folder. **Stop and ask the human only at a genuine conflict** — this is a merge-time mini fg-learn, not an autonomous rewrite:

- **CONTEXT term redefinition** — the same glossary term is defined differently in the branch's CONTEXT.md and the target's. Don't pick silently; show both and ask which wins (or how to reconcile).
- **Decision contradiction** — an incoming branch ADR contradicts an ADR added on the default branch in parallel. Surface both and ask whether the incoming one supersedes, is superseded, or both stand with a note.

Everything non-conflicting proceeds without a question.

## Finish: remove the branch folder

Once integration is confirmed, delete `.forge/branch/<branch>/` so the branch root does not linger as a duplicate of what now lives in `.forge/`. Then summarize what was integrated (N ADRs renumbered to which numbers, retros moved, terms merged, done entries folded) in the user's language.

```
fg-merge <branch>   (run AFTER `git merge <branch>` on the default branch)
   │
   ▼
.forge/branch/<branch>/ present?  ── no ──▶ stop ("nothing to integrate — git merge first?")
   │ yes
   ▼
Unsealed volatile state in the branch root?  ── yes ──▶ halt, warn (seal the branch loop first)
   │ no
   ▼
Auto (mechanical): renumber ADRs (+rewrite all cross-refs) · move retros · append non-conflicting CONTEXT terms · fold done/
   │
   ├── genuine conflict (term redefined · ADR contradiction) ──▶ HALT, show both, ask the human ──▶ apply choice
   │
   ▼
Remove .forge/branch/<branch>/  →  summarize integration (in the user's language)
```

## Document impact

- Writes into the target `.forge/adr/`, `.forge/retro/`, `.forge/CONTEXT.md`, `.forge/done/` (the integrated permanent docs).
- Removes `.forge/branch/<branch>/` after integration.
- Does **not** touch `.forge/config.json` or `.forge/codebase/` (global exemptions), and does **not** run git.
