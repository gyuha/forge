# Using forge in a team — merge policy and CI

forge began as a single-person loop tool, but branch isolation (ADR-0011) and deterministic scripts that run without AI (`forge-merge.sh`, `forge-doctor.sh`) make it workable for a team of 3–20 too. This document lays out the **merge conventions** a team should keep and **how to wire them into CI**.

## The boundary — forge does not own your git policy

Pin this down first: **forge's integration core (the deterministic scripts and the CI path) neither runs git nor enforces anything about it.** PR approval rules, branch protection, and merge timing belong to GitHub (or whatever host you use). All forge does is **reconcile the shared `.forge/` docs (ADRs, CONTEXT, retros, done history) when a branch is merged in**. In CI, `forge-merge.sh` does not run `git merge` — a human (or CI) merges first, and only then does forge integrate the forge state. (For local convenience the interactive `fg-merge <branch>` can run `git merge` for you, but that is **confined to the skill layer**; the core script and the CI path stay git-free — ADR `260717-10a`.)

Do not blur this boundary. Don't try to build a PR workflow on top of forge; leave git collaboration to git tooling.

## The merge ritual

When bringing branch work into the default branch, keep this order:

```
seal the task on the branch (fg-done)
   → git merge <branch>   (a human, or a PR merge)
   → integrate forge state:  locally, fg-merge (AI, conversational conflict resolution)
                             in CI, forge-merge.sh (AI-free, build fails on conflict)
   → commit the integration result
```

- **Seal on the branch first.** A branch's task is sealed with `fg-done` in that branch root (`.forge/branch/<branch>/`), which moves it into `done/`. Merging while work is still unfinished (active slot, `executed/`, a halted `loop.md`) is blocked by `forge-merge.sh` with an in-flight halt (exit 3).
- **`git merge` comes in without conflicts.** Branch forge state is namespaced under `.forge/branch/<branch>/`, a path the default branch does not have, so git brings the folder in as-is.
- **Then integrate.** `fg-merge <branch>` (locally) or `forge-merge.sh <branch>` (in CI) folds the branch root into `.forge/` — moving time-based ADR IDs as-is (only a same-second collision is resolved locally by taking the next letter, with no cascade renumber), moving retros, merging CONTEXT terms, remapping done/backlog task numbers, and then removing the branch folder.

## Conflict authority (who decides)

`forge-merge.sh` stops with a non-zero exit on a **structural conflict**, having moved nothing (gate-first, non-destructive):

| Conflict | exit | Who resolves it, and how |
|------|------|------------|
| In-flight branch state (unsealed work) | 3 | The **branch owner** seals / recovers / finishes the loop on the branch, then retries |
| CONTEXT term redefined (same term, different definition) | 4 | The **branch owner + a reviewer** agree on which definition is right, fix one of the two docs, then retry |
| An incoming NNNN colliding with a frozen target (legacy) | 4 | Resolved by hand (rare — nearly gone since the switch to time-based IDs) |
| **Semantic ADR contradiction** (an incoming decision clashes with an existing one) | — the script cannot catch it | **Human PR review** catches it. CI does not pretend to |

The principle: **the script blocks only mechanically decidable conflicts, and leaves judgments of meaning to a human (PR review).** A green CI gate does not mean "these decisions don't clash" — that is what the reviewer is for.

## The amendment path for shared (top-level) ADRs

A branch writes only into its own root (`.forge/branch/<branch>/adr/`). So to **amend, from a branch, a top-level ADR that already lives on the default branch**:

1. On the branch, record the amendment as a **new (branch) ADR or an amendment note**, in the branch root. Do not edit the existing top-level ADR file from the branch — that is what causes merge conflicts and double edits.
2. `fg-merge` integrates that branch ADR into the top level. Express its relationship to the original (amends, supersedes) by cross-referencing the ID in the new ADR's body.
3. For genuinely trivial edits like a typo fix, fixing it on the default branch directly is better — no need to go through a branch.

Because IDs are time-based (`YYMMDD-HHMMSS`, plus a letter only on a collision), an ADR minted on a branch is unique with no coordination, and its ID does not change during the merge, so cross-references never break (the one exception is a chance same-second collision — only then does a single letter get bumped).

## Ordering when merging several branches

When integrating several branches back to back:

- **One at a time**: run `fg-merge` (or `forge-merge.sh`) **immediately after** each `git merge`. Don't batch several merges and then try to integrate them all at once — integration is deterministic only when processed branch by branch, in sequence.
- **The order is the `git merge` order.** Task-number and ADR-ID remapping is computed against the target's state at integration time, so the branch integrated first gets the lower numbers (deterministic).
- If you forget to integrate (i.e. you ran `git merge` but never `fg-merge`), `.forge/branch/<branch>/` is left stranded on the default branch — `forge-doctor`'s **A8 check catches it as an "orphaned branch root — did you forget `fg-merge`?"**. Wire the doctor gate into CI and this mistake gets detected automatically.

## Wiring it into CI

`forge-merge.sh` and `forge-doctor.sh` work AI-free through exit codes, so they can serve as CI gates. A copy-paste example: [`examples/github-actions-forge-check.yml`](../examples/github-actions-forge-check.yml).

- **`forge-doctor.sh`** — the state and docs integrity gate. `exit 0` clean · `1` warnings · `2` errors. For a strict gate (not even warnings tolerated) fail on any non-zero; for a loose one, fail only on errors (≥ 2). It catches orphaned branch roots, version drift, broken STATUS files, duplicate ADR IDs, and the like.
- **`forge-merge.sh`** — integrates the branch's forge state. Run it after `git merge`; a conflict or unfinished work exits non-zero → build fail → the developer resolves it locally with `fg-merge` and re-pushes.

CI only **blocks** — integrating and fixing is a human's job. Semantic ADR contradictions in particular are business for outside CI (PR review).
