---
name: fg-merge
description: Integrates a non-default branch's forge content (`.forge/branch/<branch>/`) into the default-branch `.forge/` after a git merge — the mechanical integration runs as a deterministic script (forge-merge.sh/.js) so it also works AI-free in CI, renumbering nothing: incoming time-based ADR IDs move as-is (an exact-ID clash takes the next free letter, no cascade), retros move, CONTEXT.md terms merge, done/backlog fold with one task-number remap, dropped/ moves, then the branch folder is removed. Genuine conflicts (a term redefined, an incoming NNNN colliding with a frozen ID) halt with a non-zero exit for a human; semantic ADR contradictions are left to PR review. It does NOT run git — you `git merge` first, then run fg-merge. An on-demand utility outside the loop. Use in contexts like 'forge merge', 'fg-merge <branch>', '브랜치 통합', '브랜치 forge 합쳐줘'.
---

# fg-merge — integrate a branch's forge content into `.forge/` (outside the loop)

This is **not** a stage of the forge loop. It is the integration step for branch isolation (ADR-0011): when a feature branch has been run with its forge state under `.forge/branch/<branch>/` (a git-tracked, namespaced mini-root — see `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md`), fg-merge folds that branch's permanent forge docs into the default-branch `.forge/`.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** The integration summary and any conflict question are written in the user's language.

## Precondition: git merge first, fg-merge second

fg-merge does **not** run git — that is a non-goal. The expected order (ADR-0011):

1. You finish and seal the branch's loop (its `done/` lives under `.forge/branch/<branch>/done/`).
2. **You** `git merge <branch>` into the default branch. Because `.forge/branch/<branch>/` is namespaced, git brings the whole folder in **without conflict** (the default branch had no such path).
3. **Then** run `fg-merge <branch>` on the default branch. It reads `.forge/branch/<branch>/` and integrates its permanent docs into the top-level `.forge/`.

If `.forge/branch/<branch>/` is not present on the default branch (e.g. you haven't merged yet, or the name is wrong), the script reports nothing to integrate (exit 2).

## How it runs (script-backed integration)

The **mechanical integration** — resolving the branch root, moving ADRs (time-based IDs; an exact-ID clash takes the next free letter, no cascade renumber), folding retros/done/backlog, merging CONTEXT terms, remapping task numbers, rewriting bumped cross-references, removing the branch folder — is done by a **deterministic script**, not by an LLM hand-running a dozen `mv`/`sed` steps and reasoning the conflict guards in tokens (the same problem ADR-0020 fixed for fg-status and ADR-0030 for fg-done). This skill **runs the script and routes on its exit code**; the **judgment** (deciding a genuine semantic conflict, the conflict conversation, the handoff) stays here.

The script exists so the integration **also works AI-free in CI** (see "CI usage" below): a pipeline can run `forge-merge.sh` after a merge, and a non-zero exit fails the build so a human resolves it locally. Like forge-done.sh it is **gate-first, non-destructive-on-refuse**: it detects blocking conditions and exits non-zero **before moving anything**. Guarded by `scripts/forge-merge.test.sh` + `scripts/forge-merge.parity.test.sh`.

Dual dispatch (ADR-0022): prefer bash, fall back to node.
- **Has bash**: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/forge-merge.sh" [<branch>]`
- **No bash** (e.g. PowerShell-blocked Windows): `node "${CLAUDE_PLUGIN_ROOT}/scripts/forge-merge.js" [<branch>]` — identical behavior (exit codes, resulting `.forge/` tree), guarded by the parity test.

**Argument**: `<branch>` names the branch root explicitly. Omit it to let the script resolve — exactly one leaf root → that one; several → it exits 6 with the list, and you ask the user which, then re-invoke with that branch.

**Exit codes → routing (this is the skill's job):**

| Exit | Meaning | Route |
| --- | --- | --- |
| 0 | integrated OK (branch folder removed) | relay the integration summary + commit reminder |
| 2 | nothing to integrate (no branch root / named branch absent / empty) | say so; remind "git merge first, then fg-merge" |
| 3 | in-flight branch state (active slot · executed/ · pending quick · loop.md) | tell the human to seal/recover/resume **on the branch** first (fg-done / fg-run / fg-loop), then re-run |
| 4 | genuine conflict needs a human | resolve it conversationally, then re-run (see below) |
| 6 | ambiguous (several branch roots, no `<branch>`) | list them, ask which, re-invoke with that branch |

The script emits language-neutral tokens (`SEALED …` / `EMPTY …` / `GATE_INFLIGHT …` / `GATE_CONFLICT …` / `AMBIGUOUS …`) — read the token to route; write the user-facing prose in the user's language.

## What the script integrates (and what it does not)

It integrates the branch root's **permanent docs** into the top-level `.forge/`:

- **ADRs** (`adr/*`) — **time-based IDs (`YYMMDD-HH`+letter, ADR-FORMAT.md) move as-is**; an exact-ID collision with the target takes the **next free letter** (no cascade renumber — the #77 scheme), and the bumped ADR's cross-references are rewritten inside the moved incoming docs. `retired/` moves as-is.
- **Retros** (`retro/*`) — moved; `-2` suffix on a filename collision.
- **CONTEXT.md** — glossary terms merged **term-by-term** (new terms appended; a term identical in both is a no-op).
- **done/ + backlog/** — folded, with **one monotonic task-number remap** built across both incoming buckets against the target's markers (so history and runnable backlog stay unique).
- **dropped/** — moved (never blocks integration — dropped work was deliberately abandoned).

Then it **removes `.forge/branch/<branch>/`** (and prunes an empty slashed parent, e.g. `.forge/branch/feature/`).

**Warn-only, never rewritten**: after re-lettering a bumped ADR (its collision bump), the script greps the merge-changed **non-`.forge/` project files** (`git diff --name-only ORIG_HEAD..HEAD`, best-effort) for citations of the bumped ID by its old value and **warns** — outside `.forge/` an `ADR-<id>` citation can't be safely disambiguated, so the human rewrites it.

**Not integrated** (the two global exemptions of ADR-0011 — never branch-local): **`.forge/config.json`** and **`.forge/codebase/`**.

## The conflicts the script detects (exit 3 / 4) — and the one it cannot

**Gate-first**: the script checks these before any mutation, so a refusal leaves the tree untouched.

- **In-flight branch state (exit 3)** — a `plan.md` (active slot), a non-empty `executed/`, a `loop.md` (unfinished goal contract), or a `quick/LOG.md` whose latest result still reads `pending`. A sealed branch has moved its work into `done/`; unfinished state must be resolved **on the branch** first (fg-done to seal, fg-run to recover a failed task, fg-loop to finish/abandon a goal loop) — never silently discarded. Route the human there, then re-run.
- **Genuine conflict (exit 4)** — two mechanically-detectable cases: (a) a **CONTEXT term redefined** differently in the branch and the target; (b) an incoming **grandfathered NNNN ADR colliding with a frozen target NNNN** (the letter rule only resolves time-based IDs; a NNNN clash has no cascade to fall back on by design). Show both sides and let the human reconcile (edit the branch's doc, or the target's), then re-run. Since the script is gate-first, nothing was moved.
- **The one it cannot detect — semantic ADR contradiction.** "This incoming ADR contradicts a decision the default branch made in parallel" is a *meaning* judgment; a script cannot see it, and it does **not** halt on it. This is deliberate: in CI it is caught by human **PR review**; locally you can eyeball the incoming ADRs during this handoff. Do not pretend the script screens for it.

## CI usage (AI-free)

Because the mechanical integration is a deterministic script with a clean exit-code contract, a CI job can run it after a merge with no AI:

```
bash scripts/forge-merge.sh "$BRANCH"   # exit 0 = integrated; non-zero = a human is needed
```

A non-zero exit **fails the build**: exit 3 (in-flight) / 4 (conflict) / 6 (ambiguous) all mean "resolve locally with `fg-merge`, then re-push." CI never auto-resolves a semantic conflict — that is the human/PR-review boundary above. (The example workflow that wires this as a gate lives in the `team-ci-workflow-merge-policy-docs` task.)

## Behavior

**1) Decide the argument (judgment), then run the script.** Resolve `<branch>` (explicit arg, or let the script enumerate and route its exit 6), then invoke via dual dispatch (bash, else node). Do **not** hand-move files or hand-`sed` IDs — the script owns that.

**2) Route on the exit code (judgment).** Exit 0 → the integration summary below. Non-zero → route per the table / conflict section above and stop (nothing was moved — the script refused before mutating).

**3) On a genuine conflict (exit 4), resolve conversationally — a merge-time mini fg-learn.** Show the two sides (the redefined term's two bodies, or the colliding NNNN and what occupies it), ask the human how to reconcile, apply their choice to the branch/target doc, then **re-run the script**. Plan/doc edits are human-approved — never auto-pick a term's winning definition.

**4) On success (exit 0), summarize + remind to commit.** Relay what the script integrated (N ADRs, any letter bumps, retros moved, terms merged, done/backlog folded with the task-number remap, dropped preserved, branch folder removed) in the user's language, then remind the user to **commit the integration result** (the moved docs — any collision-bumped ADR re-lettered — plus the branch-folder deletion) — fg-merge does not run git, so until committed it exists only in the working tree. If the script printed any `WARN external ref …` lines, surface them: those are non-`.forge/` citations of a bumped ADR the human must rewrite by hand.

```
fg-merge [<branch>]   (run AFTER `git merge <branch>` on the default branch)
   │  decide <branch> (explicit, or let the script resolve)
   ▼
run forge-merge.sh (bash) | forge-merge.js (no bash)
   ├── exit 0 ──▶ relay integration summary → remind to commit (+ surface WARN external refs)
   ├── exit 2 ──▶ "nothing to integrate — git merge first?"
   ├── exit 3 ──▶ in-flight on the branch → seal/recover/resume there (fg-done/fg-run/fg-loop) → re-run
   ├── exit 4 ──▶ genuine conflict → show both sides, human reconciles → re-run
   └── exit 6 ──▶ several branch roots → ask which → re-invoke with that branch
```

## Document impact

- Writes into the target `.forge/adr/`, `.forge/retro/`, `.forge/CONTEXT.md`, `.forge/done/`, `.forge/backlog/`, `.forge/dropped/` (the integrated docs), and removes `.forge/branch/<branch>/` — all done by the script.
- Does **not** touch `.forge/config.json` or `.forge/codebase/` (global exemptions), and does **not** run git (except a best-effort read-only `git diff` for the warn-only external-ref grep).
- The mechanical integration is `scripts/forge-merge.sh` / `.js` — this skill invokes it and routes; it does not hand-move files.

For the ADR/CONTEXT formats, read `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/ADR-FORMAT.md` / `CONTEXT-FORMAT.md` (skill-relative `../fg-ask/`) — do not copy them here.
