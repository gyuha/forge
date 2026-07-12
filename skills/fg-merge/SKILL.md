---
name: fg-merge
description: Integrates a non-default branch's forge content (`.forge/branch/<branch>/`) into the default-branch `.forge/` after a git merge — renumbering incoming ADRs and task numbers, moving retros, merging CONTEXT.md glossary terms, folding in done/backlog history, then removing the branch folder. Mechanical parts run automatically; genuine conflicts (a term redefined, an incoming ADR that contradicts one added on the default branch) halt and ask the human. It does NOT run git — you `git merge` first, then run fg-merge. An on-demand utility outside the loop. Use in contexts like 'forge merge', 'fg-merge <branch>', '브랜치 통합', '브랜치 forge 합쳐줘'.
---

# fg-merge — integrate a branch's forge content into `.forge/` (outside the loop)

This is **not** a stage of the forge loop. It is the integration step for branch isolation (ADR-0011): when a feature branch has been run with its forge state under `.forge/branch/<branch>/` (a git-tracked, namespaced mini-root — see `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md`), fg-merge folds that branch's permanent forge docs into the default-branch `.forge/`.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** The integration summary and any conflict question are written in the user's language.

## Precondition: git merge first, fg-merge second

fg-merge does **not** run git — that is a non-goal. The expected order (ADR-0011):

1. You finish and seal the branch's loop (its `done/` lives under `.forge/branch/<branch>/done/`).
2. **You** `git merge <branch>` into the default branch. Because `.forge/branch/<branch>/` is namespaced, git brings the whole folder in **without conflict** (the default branch had no such path).
3. **Then** run `fg-merge <branch>` on the default branch. It reads `.forge/branch/<branch>/` and integrates its permanent docs into the top-level `.forge/`.

If `.forge/branch/<branch>/` is not present on the default branch (e.g. you haven't merged yet, or the name is wrong), stop and say so — there is nothing to integrate.

## Which branch to integrate (argument vs. no-argument)

`fg-merge <branch>` names the branch explicitly. When invoked with **no argument** (`fg-merge`), resolve the branch by enumerating the branch roots under `.forge/branch/`:

- **exactly one** → propose it ("integrate `.forge/branch/<branch>/`?") and proceed on confirmation.
- **several** → ask which one to integrate (list them); do not guess.
- **none** → there is nothing to integrate; say so and stop (same as the missing-folder case above).

A slashed branch name nests (`feature/x` → `.forge/branch/feature/x/`), so enumerate leaf roots (a directory that directly contains the forge docs), not the intermediate `feature/` grouping directory.

## What it integrates (and what it does not)

Resolve nothing here — fg-merge always reads the literal `.forge/branch/<branch>/` (source) and writes the literal top-level `.forge/` (target). It integrates the branch root's **permanent docs**:

- **ADRs** (`.forge/branch/<branch>/adr/*`) → renumbered into `.forge/adr/` (see the procedure below).
- **Retros** (`.forge/branch/<branch>/retro/*`) → moved into `.forge/retro/`; on a filename (`YYYY-MM-DD-slug`) collision, disambiguate with a `-2` suffix.
- **CONTEXT.md** (`.forge/branch/<branch>/CONTEXT.md`) → glossary terms merged **term-by-term** into `.forge/CONTEXT.md` (append new terms; a term defined in both is a conflict — see the gate).
- **done/ history** (`.forge/branch/<branch>/done/*`) → moved into `.forge/done/` (local archive record; disambiguate dir names on collision). Its archived `plan.md` participates in the shared incoming task-number remap below — moving it with the branch-local `task: N` unchanged can collide with a task independently created on the default branch.
- **Backlog plans** (`.forge/branch/<branch>/backlog/*.md`) → moved into the top-level `.forge/backlog/`; on a slug collision append `-2` (updating the `forge-slug` comment).
- **Incoming task numbers (`done/ and backlog`)** → before moving either bucket, build one complete **task-number map** for every incoming plan against all target-root markers (backlog/active slot/executed/done). Take incoming plans in ascending old `task: N` order (stable tie by bucket + slug), assign the next free target numbers, then rewrite each incoming plan's marker once. This preserves uniqueness across history as well as runnable backlog work; remapping only backlog plans would leave duplicate numbers in `done/`, breaking fg-status display and fg-doctor's uniqueness check.
- **dropped/ archive** (`.forge/branch/<branch>/dropped/*`) → moved into the top-level `.forge/dropped/` (the discarded-work archive fg-drop keeps; disambiguate dir names with `-2` on collision, create `.forge/dropped/` lazily if absent). This does **not** trigger the in-flight halt below — dropped work was deliberately abandoned, so it never blocks integration; it is **moved rather than silently deleted** with the branch folder so the archive survives the integration. (It stays volatile — the target `.forge/dropped/` is gitignored, same as any dropped archive; the move just preserves it in the working tree instead of destroying it.)

**Create each target directory lazily.** If `.forge/adr/`, `.forge/retro/`, or `.forge/done/` does not yet exist on the default branch (e.g. a fresh repo whose first sealed/decided work happened on the branch), create it on the way in — its absence is not an error, just the lazy-creation convention. (Verified by the fg-merge lifecycle e2e test: a target missing `done/` would otherwise drop the folded history.)

**Not integrated** (the two global exemptions of ADR-0011 — they were never branch-local): **`.forge/config.json`** and **`.forge/codebase/`**. Leave them untouched; they already live at the top level.

**In-flight loop state** under the branch root — the active slot (`plan.md`/`run.md`/`STATUS.md`) and `executed/` — must be resolved before integrating: a sealed branch has already moved its work into `done/`. If such in-flight state remains, **halt and warn**: seal the branch loop (fg-done) or recover the failed task (fg-run) on the branch first — never silently discard it. Backlog plans do **not** trigger the halt; they are folded into the target backlog per the list above. The quick-lane log (`quick/`) is a local convenience record, not loop fuel — it is removed with the branch folder; but an entry whose `Result:` line (rendered in the log's language, e.g. `결과:`) still reads `pending` counts as in-flight state for this same halt. **A `loop.md` in the branch root (an unfinished fg-loop goal contract — a goal-met loop would have deleted it) also counts as in-flight state for this halt**: resume the loop on the branch via fg-loop (drive it to goal-met, or deliberately abandon it by deleting `loop.md`) before integrating — silently removing the branch folder would discard the goal contract (check states, replan rounds) without a trace.

## ADR renumbering procedure

ADR numbers are assigned at creation as `max+1` per root, so a branch and the default branch can independently mint the same number. fg-merge resolves this deterministically at integration:

1. Find the highest existing ADR number in the **target** `.forge/adr/` — **including `retired/`** (retired numbers are never reused; assigning one to an incoming ADR would collide with a retired decision's citations) — e.g. `0011`.
2. Take the branch's incoming ADRs **in ascending order of their current number** and assign them the next free numbers in sequence (`0012`, `0013`, …). **Build the complete old→new map for ALL incoming ADRs first — rename and rewrite nothing until the whole map exists.**
3. Apply the map in **one simultaneous pass**, scoped to the **incoming branch docs only**: the incoming ADR bodies, the moved retros, the branch `CONTEXT.md` (before its terms are appended to the target), and the `done/` plan/run notes being folded in. Rewrite each **`ADR-NNNN`** (and `NNNN-slug` filename) reference via a unique placeholder first, then placeholders to final numbers — old and new ranges overlap (a branch's `0001` always collides with the target's), so a sequential in-place rewrite would cascade (`0001→0012` later re-hit by `0012→0023`). **Never rewrite target-side docs** — pre-existing `ADR-NNNN` references in the target's own ADRs and target `CONTEXT.md` point at the target's numbers and must stay untouched. A reference left pointing at the old number is a silent breakage.
4. After renumbering, grep the **moved incoming docs** for stale old-number references (the map's old side) and report any that remain.
5. **Also grep the non-`.forge/` project files this merge brought in** — the preceding `git merge` may have pulled in project docs/code (CLAUDE.md, README, `docs/`, source comments) that cite the branch's ADRs by their **old** numbers. Scope the grep to the merge-changed files (`git diff --name-only ORIG_HEAD..HEAD`, excluding `.forge/` paths), **not** the whole repo, so unrelated pre-existing citations don't surface as false positives. **Warn only — never rewrite these.** Outside `.forge/` an `ADR-NNNN` citation cannot be disambiguated: a branch's low incoming number always overlaps a target number, so the same `ADR-0003` string might mean "the branch ADR just renumbered" or "the target's own ADR-0003" — only a human knows which. Report each hit (file · line · old→new mapping) and leave the rewrite to the human.

> **Warn loudly if cross-reference rewriting is incomplete.** The whole value of deferring numbering to merge time is lost if a renamed ADR is still referenced by its old number somewhere. Surface unresolved references — both the auto-rewritten incoming docs (step 4) and the warn-only external project files (step 5) — rather than sealing silently.

## Mechanical-auto, conversational-on-conflict

Run the safe mechanical parts automatically: renumber ADRs, build and apply the incoming task-number map across done/ and backlog, move retros, append non-conflicting CONTEXT terms, fold in done/ and backlog plans, and (last) remove the branch folder. **Stop and ask the human only at a genuine conflict** — this is a merge-time mini fg-learn, not an autonomous rewrite:

- **CONTEXT term redefinition** — the same glossary term is defined differently in the branch's CONTEXT.md and the target's. Don't pick silently; show both and ask which wins (or how to reconcile).
- **Decision contradiction** — an incoming branch ADR contradicts an ADR added on the default branch in parallel. Surface both and ask whether the incoming one supersedes, is superseded, or both stand with a note.

Everything non-conflicting proceeds without a question.

## Finish: remove the branch folder

Once integration is confirmed, delete `.forge/branch/<branch>/` so the branch root does not linger as a duplicate of what now lives in `.forge/`. **For a slashed branch name (`feature/x`), also remove the now-empty parent directory (`.forge/branch/feature/`)** once nothing else remains under it — otherwise the empty grouping directory lingers as a phantom branch root that the no-argument enumeration above would trip over. Then summarize what was integrated (N ADRs renumbered to which numbers, retros moved, terms merged, done entries and backlog plans folded, dropped/ archive preserved) in the user's language — and remind the user to **commit the integration result** (the renumbered/moved docs plus the branch-folder deletion): fg-merge does not run git, so until committed the integration exists only in the working tree.

```
fg-merge [<branch>]   (run AFTER `git merge <branch>` on the default branch)
   │
   ▼
branch given?  ── no ──▶ enumerate leaf roots under .forge/branch/ ─ one ▶ propose · several ▶ ask which · none ▶ stop
   │ yes / resolved
   ▼
.forge/branch/<branch>/ present?  ── no ──▶ stop ("nothing to integrate — git merge first?")
   │ yes
   ▼
In-flight task in the branch root (active slot · executed/ · pending quick entry · `loop.md`)?  ── yes ──▶ halt, warn (seal/recover/resume-or-abandon on the branch first)
   │ no   (dropped/ does NOT halt — it is moved, not blocked)
   ▼
Auto (mechanical): renumber ADRs (map first, one pass, incoming docs only; then warn-only grep of merge-changed non-.forge/ files) · build/apply task-number map across incoming done/ + backlog · move retros · append non-conflicting CONTEXT terms · fold done/ · fold backlog plans · move dropped/ archive
   │
   ├── genuine conflict (term redefined · ADR contradiction) ──▶ HALT, show both, ask the human ──▶ apply choice
   │
   ▼
Remove .forge/branch/<branch>/ (+ empty slashed parent)  →  summarize integration (in the user's language)
```

## Document impact

- Writes into the target `.forge/adr/`, `.forge/retro/`, `.forge/CONTEXT.md`, `.forge/done/`, `.forge/backlog/`, `.forge/dropped/` (the integrated docs and preserved archive).
- Removes `.forge/branch/<branch>/` after integration (plus the empty slashed parent directory, if any).
- Does **not** touch `.forge/config.json` or `.forge/codebase/` (global exemptions), and does **not** run git.
