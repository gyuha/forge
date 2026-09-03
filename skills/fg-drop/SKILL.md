---
name: fg-drop
description: Discards incomplete (not-yet-sealed) forge work you no longer want — backlog plans, the active slot, awaiting-retro tasks, or a halted goal loop. Presents the items with a per-item risk level, then hard-delete (default) or archive to .forge/dropped/, behind a confirmation gate (already-run code is NOT reverted). Removes forge state only — never git or your code. Outside the loop (sealing a task is fg-done). Use in contexts like 'forge drop', 'fg-drop', '작업 버리기', '계획 지워', '백로그 비워', 'discard plan'.
---

# fg-drop — discard incomplete work (outside the loop)

This is **not** a stage of the forge loop (fg-ask → fg-run → fg-learn → fg-done). It is an **on-demand utility** — like fg-cleanup, fg-merge, and fg-doctor — that lets you **discard incomplete work you no longer intend to do**: a backlog plan you abandoned, the active slot, a task parked in `executed/` awaiting retro, or a halted goal loop. forge had no way to do this short of a manual `rm`; fg-drop fills that gap (ADR-0021).

Note the contrast with its neighbors: **fg-done** *completes* a task and seals it (the opposite intent — finishing, not abandoning); **fg-cleanup** retires *ADRs* (a decision, not a task); **fg-status**/**fg-doctor** are read-only and cannot host a destructive action. fg-drop is the one place that abandons a not-yet-sealed task.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — the item list, risk labels, the disposal question, the confirmation summary, and the closing line — in the user's language (detect it from the user's own messages), never mirroring this file's English.**

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Forge root**: every `.forge/...` path below is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before reading, deleting, or archiving any state (ADR-0011). The two global exemptions (`.forge/config.json`, `.forge/codebase/`) are never drop targets.

## What is droppable (and what is not)

Drop targets are **incomplete** work = anything not sealed in `done/`. Scan the resolved forge root and gather candidates from these buckets, each carrying a **risk level**:

| Bucket | What it is | Risk |
| --- | --- | --- |
| `ask.md` | an in-progress fg-ask grilling session (its working-slug marker) | **low** — display-only marker; nothing has run, dropping it just abandons an unfinished conversation |
| `backlog/<slug>.md` | a queued plan that has **not run** | **low** — volatile & gitignored; deleting loses nothing in git |
| active slot `plan.md` **with no** `run.md` | promoted but not yet run | **low** — same as a backlog plan |
| active slot **with** `run.md` (+`STATUS.md`, +`review.md`) | **already executed**, awaiting verify/retro/seal | **high** — the code already changed; dropping removes only forge tracking |
| `executed/<slug>/` | parked after "Run all", awaiting retro | **high** — already executed, same warning |
| `loop.md` (halted goal loop) | an fg-loop drive stopped at a wall | **high** — abandons the whole goal loop |

**Excluded — never drop targets:** `done/` (sealed work — that is "completed", not incomplete; un-completing a sealed task is a different operation, out of scope), `quick/LOG.md` (an append-only log, not a task), and the two global exemptions above.

**Goal-loop rule (loop.md present).** If `loop.md` exists, surface it as a **single** droppable item (`goal loop: <one-line goal>`, risk high) — dropping it abandons the whole loop. "Whole" means `loop.md` **and all member tasks' incomplete forge state**: member plans in `backlog/`, a member in the active slot, and member directories in `executed/`. Sealed member history in `done/` remains immutable, and non-member work is untouched. The tasks listed in its `## Tasks` membership section are **excluded from individual drop** while `loop.md` exists: drop the loop whole, or finish it via fg-loop first. This avoids leaving orphan member tasks behind or having to re-synchronize membership after a partial removal. Non-member plans (e.g. ones fg-ask stacked while the loop was halted) remain individually droppable as usual.

## Behavior — scan, pick, choose disposal, confirm, execute

### 1. Scan and present the incomplete items (hybrid dialog)

Gather all droppable candidates (above). If there are **none**, say so in one line ("no incomplete work to drop") and stop. Otherwise present them with their risk level, choosing the presentation by count — because `AskUserQuestion` caps options at 4:

- **exactly 1 item** → use a two-choice `AskUserQuestion`: **"Drop this item"** / "Cancel". A one-option dialog is invalid, and a multi-select adds no value.
- **2–4 items** → an `AskUserQuestion` **multi-select** checkbox dialog, one option per item. Label each `[<risk>] #<task> <title>` (use the plan's `task:` number when present); include the risk in the label so it is visible per item.
- **5 or more items** → print a **numbered text list** (each line: number, `[<risk>]`, slug/title, bucket), then ask the user to type which to drop — e.g. `2,4,5` or `all`. This sidesteps the 4-option cap.

For **high-risk** items (anything with a `run.md`, or the goal loop), make the risk unmistakable in the listing — they are already-run work or a whole loop.

### 2. Choose disposal — a separate follow-up question

After the items are chosen, ask **one** follow-up question (do not fold it into the item selection — mixing a modifier into the item checkboxes is ambiguous): how to dispose of the selected items, batch-wide:

- **Delete (default)** — hard delete, no trace.
- **Archive** — move each selected item to `.forge/dropped/<slug>/` instead of deleting (preserves it for later archaeology). Create `dropped/` lazily on first archive.

One choice applies to **all** selected items (batch-level).

### 3. Final confirmation gate (guards the irreversible delete)

Show a summary — "the following will be **[deleted / archived]**: …" listing each selected item — and require an **explicit confirmation** ("yes") before acting. If any selected item is **high-risk (has a `run.md`)**, add a one-line warning to the summary: **"⚠ already-changed code is NOT reverted — fg-drop removes forge tracking only."** Only on explicit confirmation proceed; otherwise abort and change nothing.

### 4. Execute

For each confirmed item:

- **`ask.md`** — remove (or move) the single file.
- **Active slot** — remove (or move to `dropped/<slug>/`) `plan.md` + `run.md` + `STATUS.md`, plus `review.md` if present (the same companion set fg-done archives — ADR-0018). After this the active slot is empty.
- **`backlog/<slug>.md`** — remove (or move) the single file.
- **`executed/<slug>/`** — remove (or move) the whole directory.
- **`loop.md` goal-loop item** — read its `## Tasks` membership, then remove (or archive together) `loop.md` **plus all member tasks' incomplete state** from `backlog/`, the active slot, and `executed/`. Leave `done/` history and every non-member task untouched. When archiving, place the contract and member state under one `.forge/dropped/<loop-slug>/` tree so the abandoned goal remains reconstructable.

**Disposal semantics.** Hard delete is a plain removal. On the **default branch** these are volatile, gitignored files, so nothing is lost in git (the permanent fuel from grilling — CONTEXT.md, ADRs — already landed and is untouched). On a **non-default branch** the forge root `.forge/branch/<branch>/` is git-tracked whole (ADR-0011), so deleting a tracked file there shows up as an **unstaged deletion in `git status`** — recoverable via `git restore` until committed. fg-drop still does not run git (see Constraints); on a branch the removal is simply a tracked-file change the user then commits or restores. Archive moves the files under `.forge/dropped/<slug>/`: it is gitignored on the default branch, but under a non-default branch root it is **tracked with the rest of the branch root** and is later preserved by fg-merge. `dropped/` has no automatic reaper; it is cleaned manually.

```
fg-drop (outside the loop)
   │
   ▼
Resolve forge root (ADR-0011)
   ▼
Scan buckets: ask.md · backlog · active slot · executed/ · loop.md   (exclude done/, quick/, loop members while loop.md present)
   │ none ──▶ "no incomplete work to drop" → stop
   ▼
Present items with risk level:  1 → Drop this item | Cancel · 2–4 → checkbox multi-select · 5+ → numbered text list ("2,4,5" / "all")
   ▼
Disposal question (separate):  Delete (default, no trace)  |  Archive → .forge/dropped/<slug>/
   ▼
Confirmation gate: summary + explicit "yes"   (high-risk run.md present → "⚠ changed code is NOT reverted"; non-default branch → "⚠ tracked files — deletion shows in git status")
   │ no ──▶ abort, change nothing
   ▼
Execute per item (ask.md · active slot = plan+run+STATUS+review · backlog file · executed/ dir · goal loop = loop.md + all incomplete member state)
   ▼
Report what was dropped/archived → end
```

## Constraints

- **forge state only — never git, never your code.** fg-drop deletes/moves `.forge/` state and nothing else. It does **not** revert commits or working-tree changes (the same principle as fg-merge's git-free integration core — note fg-merge does have an opt-in `git merge` mode via `fg-merge <branch>`, but fg-drop never touches git at all). If the user wants already-changed code reverted, that is theirs to do via git — say so when it is relevant. (On a **non-default branch** the dropped `.forge/branch/<branch>/` files are themselves git-tracked — ADR-0011 — so the deletion appears as an unstaged change; fg-drop still does not run git, the user commits or `git restore`s it.)
- **No auto-run, no chaining.** Like fg-status/fg-doctor/fg-cleanup, fg-drop runs only on demand; it does not invoke other skills and nothing invokes it.
- **Loop members are not individually droppable** while `loop.md` exists — drop the loop whole, which includes all member tasks' incomplete state while preserving `done/` and non-members (the membership-resync logic is deliberately not built).
- **Confirmation is mandatory** before any destructive action — there is no "drop without confirming" path.

## Document impact

- **Removes** (default) or **moves to `.forge/dropped/<slug>/`** (archive) the selected incomplete state: `ask.md`, a `backlog/<slug>.md`, the active slot (`plan.md`/`run.md`/`STATUS.md`/`review.md`), an `executed/<slug>/` directory, or a whole goal loop (`loop.md` + all member tasks' incomplete backlog/active/executed state).
- Creates `.forge/dropped/` lazily only when archive is chosen. It is gitignored on the default branch; under a non-default branch's fully tracked root it is tracked and later preserved by fg-merge. `fg-doctor` tolerates it (does not flag its contents as orphans) and `fg-status` ignores it (abandoned work, not progress) — ADR-0021.
- Touches no permanent docs (CONTEXT.md, ADRs, retros) and no `done/` history.
