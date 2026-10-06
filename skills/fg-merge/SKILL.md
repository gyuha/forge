---
name: fg-merge
description: "Integrates a branch's forge content (.forge/branch/<branch>/) into .forge/. Three modes: `fg-merge` integrates only; `fg-merge <branch>` (on the default branch) runs `git merge <branch>` first, stopping on conflict; `fg-merge to [<target>]` (from a feature branch) commits, checks out the default branch, merges, integrates, and commits the integration — one confirmation, never pushes. A deterministic git-free script (forge-merge.sh/.js) does the integration, usable AI-free in CI. Use in contexts like 'forge merge', 'fg-merge <branch>', 'fg-merge to main', '브랜치 통합', '머지하고 통합', '메인으로 머지'."
---

# fg-merge — integrate a branch's forge content into `.forge/` (outside the loop)

This is **not** a stage of the forge loop. It is the integration step for branch isolation (ADR-0011): when a feature branch has been run with its forge state under `.forge/branch/<branch>/` (a git-tracked, namespaced mini-root — see [../fg-run/FORGE-ROOT.md](../fg-run/FORGE-ROOT.md)), fg-merge folds that branch's permanent forge docs into the default-branch `.forge/`.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** The integration summary and any conflict question are written in the user's language.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

## Three modes: integrate-only, merge-and-integrate, and `to`

fg-merge has three modes, chosen by the argument (ADR `260717-10a`, ADR `261006-102435`):

- **`fg-merge` (no argument) — integrate only.** The default-branch `.forge/` already has the branch root `.forge/branch/<branch>/` present (you ran `git merge <branch>` yourself, or CI did). fg-merge just integrates it. This is the original behavior, and the **only** mode CI uses.
- **`fg-merge <branch>` — merge, then integrate.** For convenience, the skill runs **`git merge <branch>` for you first**, then integrates that branch's root. This runs **only on the default branch** (the integration target is the top-level `.forge/`).
- **`fg-merge to [<target>]` — ship the current branch.** Run **from the feature branch** when its work is finished: the skill commits your work, checks out the default branch, merges the feature branch, integrates its forge root, and commits the integration. The literal keyword `to` fixes the direction, so this mode never collides with the two above (it means "send this branch *to* the target", where `fg-merge <branch>` means "pull `<branch>` into where I stand"). See "The `to` mode" below.

**Every git operation runs in this skill (a Bash step), never in the core script.** The deterministic `forge-merge.sh`/`.js` that does the integration **never runs git** — that is what keeps it usable AI-free in CI (CI does its own merge, then calls the script). Only the interactive skill runs git — `git merge` in the `<branch>` mode, and commit/checkout/merge in the `to` mode. This is the bounded relaxation of ADR-0011's "fg-merge does not run git" (ADR `260717-10a`, extended by ADR `261006-102435`); the core script's git-abstinence is unchanged.

### The merge step (only when a `<branch>` argument is given)

Before integrating, run `git merge <branch>` and route on the result:

- **Clean merge (or fast-forward)** → git makes its merge commit; the branch root is now in the tree → proceed to integrate.
- **"Already up to date"** → `<branch>` was merged already → skip straight to integrate (smart routing).
- **Merge conflict** → **leave the conflict in place and STOP — do not integrate.** The tree is mid-merge, and integration must never run on a dirty/conflicted tree. Tell the human (in their language): resolve the conflicts, `git commit` the merge, then run `fg-merge` (no argument) to integrate. Do **not** `git merge --abort` — that discards their merge and forces a redo.
- **`<branch>` is not a valid git ref** (e.g. the branch was deleted after a PR merge) **but `.forge/branch/<branch>/` is present** → the work is already merged; skip the git step and integrate that root, noting the branch ref is gone (smart routing).
- **Neither a mergeable ref nor a present branch root** → error: nothing to merge or integrate.
- **Not on the default branch** → stop: merge-and-integrate targets the top-level `.forge/`, so it runs only on the default branch.

In this mode fg-merge does **not** commit the integration and does **not** push — exactly as in integrate-only mode (only the `to` mode below commits). `git merge` makes its own merge commit; the integration changes are left uncommitted for you to review and commit (see the handoff).

If `.forge/branch/<branch>/` is not present on the default branch after the merge step (or in integrate-only mode with no root at all), the script reports nothing to integrate (exit 2).

### The `to` mode — ship the current branch (`fg-merge to [<target>]`)

Run from the **feature branch** whose work is done. The point is the sequence you would otherwise type by hand — commit, checkout, merge, `fg-merge`, commit — as one command, without ever leaving the default branch half-merged with unfinished forge state on it.

**Preconditions (stop before touching anything):**
- **The target must be the default branch** (`defaultBranch` in the top-level `.forge/config.json`, else `main` — resolve per `../fg-run/FORGE-ROOT.md`). Omitted target = the default branch. Any other target → stop and say why: integration folds into the top-level `.forge/`, which only the default branch owns, so a forge root would have nowhere to go.
- **The current branch must not be the default branch.** If it is → stop: "already on `<target>` — to pull a branch in, use `fg-merge <branch>`".
- **Gate pre-check.** Run the integration script with `--gate-only` against the current branch's root — `bash "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/forge-merge.sh" <feature> --gate-only` (no bash → `node …/forge-merge.js <feature> --gate-only`). It judges only the in-flight gate and moves nothing:
  - exit 3 (`GATE_INFLIGHT`) → **stop here, nothing changed.** Unfinished forge work (an active plan, `executed/`, a `loop.md`, a pending quick) must be finished on the branch first — point to fg-done / fg-run / fg-loop.
  - exit 2 (`EMPTY`) → the branch has no forge root. Not a blocker: continue, and say steps 4–5 will be skipped.
  - exit 0 (`GATE_OK`) → continue.
  This is why the gate runs **before** step 1: run at step 4, an in-flight refusal would come after the merge commit already landed on the default branch, recoverable only with `git reset`. A genuine conflict (exit 4) is **not** pre-checked — it needs the up-to-date target `.forge/`, which the feature branch does not have — so it can still surface at step 4, exactly as in the `<branch>` mode.

**One confirmation, before step 1 — then no more questions.** Show, once (in the user's language):
- the files step 1 will commit (`git status --short`), with **untracked files listed separately** so an unintended file (`.env`, build output) is caught by a human before it is committed;
- the step-1 commit message — your draft from the diff, in conventional-commit form; the user may edit it;
- the direction `<feature> → <target>`;
- whether the local target is behind its remote-tracking branch — `git rev-list --count <target>..origin/<target>`, **no fetch** (omit the line when there is no `origin/<target>` ref). Behind → warn only, never block: merging into a stale target makes the later push fail, and it is better to know now.

Steps 3 onward are the hard-to-reverse ones, which is why the single confirmation sits before step 1 rather than between steps: a mid-flow question would leave the work half-done exactly where stopping is most awkward.

**The five steps** (stop at the first failure; never undo a finished step):

1. **Commit the work.** If `git status --porcelain` is empty, skip and say so. Otherwise `git add -A` and commit with the confirmed message. A refused commit (a hook) → stop on the feature branch, show the hook output.
2. **`git checkout <target>`.** Failure → stop on the feature branch (the step-1 commit stands).
3. **`git merge <feature>`.** "Already up to date" → continue. Conflict → **leave it in place and stop on the target**, exactly as the `<branch>` mode does: resolve, `git commit`, then run `fg-merge` (no argument) to integrate. Never `git merge --abort`.
4. **Integrate** — run the script with `<feature>` (no `--gate-only`) and route its exit code per the table below. Skipped when the pre-check returned exit 2. Exit 4 → the conflict conversation in "Behavior" step 3, then re-run.
5. **Commit the integration.** Only when step 4 exited 0 **and** `git status --porcelain` shows changes: `git add -A` and commit as `chore(forge): integrate <feature> forge records`.

**This is the one mode that commits** — the other two still leave the integration uncommitted. **It never pushes and never deletes the branch:** in this repo a push to the default branch *is* a release (installs pull `main`), and the release procedure puts the push after the CHANGELOG and version bump; a merge tool must not route around that. The handoff names `git push origin <target>` and `git branch -d <feature>` as next steps instead.

**Re-running is safe** — the same command resumes from where it stopped: step 1 skips when nothing is uncommitted, step 3 reports "Already up to date", and the script is gate-first. The one exception is a step-3 conflict: once it is resolved and committed you are on the target, so finish with `fg-merge` (no argument).

## How it runs (script-backed integration)

The **mechanical integration** — resolving the branch root, moving ADRs (time-based IDs; an exact-ID clash takes the next free letter, no cascade renumber), folding retros/done/backlog, merging CONTEXT terms, remapping task numbers, rewriting bumped cross-references, removing the branch folder — is done by a **deterministic script**, not by an LLM hand-running a dozen `mv`/`sed` steps and reasoning the conflict guards in tokens (the same problem ADR-0020 fixed for fg-status and ADR-0030 for fg-done). This skill **runs the script and routes on its exit code**; the **judgment** (deciding a genuine semantic conflict, the conflict conversation, the handoff) stays here.

The script exists so the integration **also works AI-free in CI** (see "CI usage" below): a pipeline can run `forge-merge.sh` after a merge, and a non-zero exit fails the build so a human resolves it locally. Like forge-done.sh it is **gate-first, non-destructive-on-refuse**: it detects blocking conditions and exits non-zero **before moving anything**. Guarded by `scripts/forge-merge.test.sh` + `scripts/forge-merge.parity.test.sh`.

Dual dispatch (ADR-0022): prefer bash, fall back to node.
- **Has bash**: `bash "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/forge-merge.sh" [<branch>]`
- **No bash** (e.g. PowerShell-blocked Windows): `node "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/forge-merge.js" [<branch>]` — identical behavior (exit codes, resulting `.forge/` tree), guarded by the parity test.

**Argument**: passing `<branch>` selects that branch root **and** triggers the merge step above (git merge → integrate). Omitting it means integrate-only, letting the script resolve the root — exactly one leaf root → that one; several → it exits 6 with the list, and you ask the user which, then re-invoke. (Because merge-and-integrate always names the branch, exit 6's ambiguity only arises in integrate-only mode.)

**Exit codes → routing (this is the skill's job):**

| Exit | Meaning | Route |
| --- | --- | --- |
| 0 | integrated OK (branch folder removed) | relay the integration summary + commit reminder |
| 2 | nothing to integrate (no branch root / named branch absent / empty) | say so; in integrate-only mode remind that `git merge` (or `fg-merge <branch>`) must bring the branch root in first |
| 3 | in-flight branch state (active slot · executed/ · pending quick · loop.md) | tell the human to seal/recover/resume **on the branch** first (fg-done / fg-run / fg-loop), then re-run |
| 4 | genuine conflict needs a human | resolve it conversationally, then re-run (see below) |
| 6 | ambiguous (several branch roots, no `<branch>`) | list them, ask which, re-invoke with that branch |

The script emits language-neutral tokens (`SEALED …` / `EMPTY …` / `GATE_INFLIGHT …` / `GATE_CONFLICT …` / `AMBIGUOUS …`) — read the token to route; write the user-facing prose in the user's language.

## What the script integrates (and what it does not)

It integrates the branch root's **permanent docs** into the top-level `.forge/`:

- **ADRs** (`adr/*`) — **time-based IDs (`YYMMDD-HHMMSS`, or grandfathered `YYMMDD-HH`+letter — ADR-FORMAT.md) move as-is**; an exact-ID collision with the target takes the **next free letter** (no cascade renumber — the #77 scheme), and the bumped ADR's cross-references are rewritten inside the moved incoming docs. `retired/` moves as-is.
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
- **Genuine conflict (exit 4)** — three mechanically-detectable cases: (a) a **CONTEXT term redefined** differently in the branch and the target (a *term* is a `**Name**:` entry — `## X` is a grouping subheading, so two glossaries sharing `## Language` is not a conflict); (b) an incoming **grandfathered NNNN ADR colliding with a frozen target NNNN** (the letter rule only resolves time-based IDs; a NNNN clash has no cascade to fall back on by design). (c) the branch's **CONTEXT.md is in an unrecognized shape** — `## ` headings but zero `**Term**:` entries — which the term-wise merge would silently skip, losing the incoming terms; stopping is safer than a no-op merge. Show both sides and let the human reconcile (edit the branch's doc, or the target's), then re-run. Since the script is gate-first, nothing was moved.
- **The one it cannot detect — semantic ADR contradiction.** "This incoming ADR contradicts a decision the default branch made in parallel" is a *meaning* judgment; a script cannot see it, and it does **not** halt on it. This is deliberate: in CI it is caught by human **PR review**; locally you can eyeball the incoming ADRs during this handoff. Do not pretend the script screens for it.

## CI usage (AI-free)

Because the mechanical integration is a deterministic script with a clean exit-code contract, a CI job can run it after a merge with no AI:

```
bash scripts/forge-merge.sh "$BRANCH"   # exit 0 = integrated; non-zero = a human is needed
```

A non-zero exit **fails the build**: exit 3 (in-flight) / 4 (conflict) / 6 (ambiguous) all mean "resolve locally with `fg-merge`, then re-push." CI never auto-resolves a semantic conflict — that is the human/PR-review boundary above. (The example workflow that wires this as a gate lives in the `team-ci-workflow-merge-policy-docs` task.)

## Behavior

**1) Decide the mode, then (if merging) run the merge step, then run the script.** If the argument starts with the keyword `to`, follow "The `to` mode" above end to end instead — its pre-check, confirmation, and five steps own the whole run, and its step 4 is the script call described here. If a `<branch>` argument was given, first run the **merge step** above — `git merge <branch>`, routing on clean / already-up-to-date / conflict / deleted-ref / not-default-branch. Only a clean or already-merged result proceeds; a **conflict stops here** (leave it in place, do not integrate) and a **not-default-branch stops here**. With no argument, skip straight to integrate-only. Then resolve the branch root (explicit, or let the script enumerate and route its exit 6) and invoke the integration via dual dispatch (bash, else node). Do **not** hand-move files or hand-`sed` IDs — the script owns the integration; you own only the `git merge` orchestration.

**2) Route on the exit code (judgment).** Exit 0 → the integration summary below. Non-zero → route per the table / conflict section above and stop (nothing was moved — the script refused before mutating).

**3) On a genuine conflict (exit 4), resolve conversationally — a merge-time mini fg-learn.** Show the two sides (the redefined term's two bodies, or the colliding NNNN and what occupies it), ask the human how to reconcile, apply their choice to the branch/target doc, then **re-run the script**. Plan/doc edits are human-approved — never auto-pick a term's winning definition.

**4) On success (exit 0), summarize + remind to commit.** Relay what the script integrated (N ADRs, any letter bumps, retros moved, terms merged, done/backlog folded with the task-number remap, dropped preserved, branch folder removed) in the user's language, then remind the user to **commit the integration result** (the moved docs — any collision-bumped ADR re-lettered — plus the branch-folder deletion). In the **`to`** mode the integration is already committed (step 5) — instead name the next steps: `git push origin <target>` and `git branch -d <feature>`, which fg-merge does not run. In **merge-and-integrate** mode, note that `git merge` already made its merge commit, but the **integration is still uncommitted** — that mode never commits the integration, so remind them to commit it (the merge commit + the integration land as two commits, or squash them by hand). If the script printed any `WARN external ref …` lines, surface them: those are non-`.forge/` citations of a bumped ADR the human must rewrite by hand.

```
fg-merge [<branch>] | fg-merge to [<target>]
   │
   ├── to [<target>] ─▶ (on the feature branch) target must be default · current must not be default
   │                      ▼
   │                   forge-merge --gate-only <feature>
   │                      ├── exit 3 ──▶ STOP, nothing changed → finish forge work on the branch
   │                      └── exit 0 / 2 ──▶ ONE confirmation (files · untracked · message · direction · behind?)
   │                                           ▼
   │                   1 commit (skip if clean) → 2 checkout <target> → 3 git merge <feature>
   │                      (conflict → leave in place, STOP → "resolve, commit, then fg-merge")
   │                                           ▼
   │                   4 integrate (script below; skipped if pre-check was exit 2) → 5 commit integration
   │                                           ▼
   │                   handoff: git push origin <target> · git branch -d <feature> (never run)
   │
   ├── no <branch> ──▶ integrate-only (branch root already merged in)
   │                      │  (let the script resolve the root; exit 6 if several)
   │                      ▼
   └── <branch> given ─▶ merge step (default branch only):  git merge <branch>
                            ├── clean / already up to date ──▶ integrate
                            ├── conflict ──▶ LEAVE in place, STOP → "resolve, commit, then fg-merge (no arg)"
                            ├── ref gone but branch root present ──▶ skip git, integrate + note
                            ├── nothing to merge/integrate ──▶ error
                            └── not on default branch ──▶ stop
                            ▼
run forge-merge.sh (bash) | forge-merge.js (no bash)   ← git-free integration, unchanged
   ├── exit 0 ──▶ relay integration summary → remind to commit (+ surface WARN external refs)
   ├── exit 2 ──▶ "nothing to integrate" (integrate-only: git merge / fg-merge <branch> first?)
   ├── exit 3 ──▶ in-flight on the branch → seal/recover/resume there (fg-done/fg-run/fg-loop) → re-run
   ├── exit 4 ──▶ genuine conflict → show both sides, human reconciles → re-run
   └── exit 6 ──▶ (integrate-only) several branch roots → ask which → re-invoke with that branch
```

## Document impact

- Writes into the target `.forge/adr/`, `.forge/retro/`, `.forge/CONTEXT.md`, `.forge/done/`, `.forge/backlog/`, `.forge/dropped/` (the integrated docs), and removes `.forge/branch/<branch>/` — all done by the script.
- Does **not** touch `.forge/config.json` or `.forge/codebase/` (global exemptions). The **core script** does **not** run git (except a best-effort read-only `git diff` for the warn-only external-ref grep). The **skill** runs `git merge` in merge-and-integrate mode (`fg-merge <branch>`, default branch) without committing the integration, and commit/checkout/merge/commit in the `to` mode (`fg-merge to [<target>]`, from a feature branch) — never the script, and **never a push** in any mode (ADR `260717-10a`, ADR `261006-102435`).
- The mechanical integration is `scripts/forge-merge.sh` / `.js` — this skill invokes it and routes; it does not hand-move files.

For the ADR/CONTEXT formats, read `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-ask/ADR-FORMAT.md` / `CONTEXT-FORMAT.md` (skill-relative `../fg-ask/`) — do not copy them here.
