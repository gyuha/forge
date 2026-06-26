---
name: fg-drop
description: Discards incomplete (not-yet-sealed) forge work you no longer want — backlog plans, the active slot, awaiting-retro tasks in executed/, or a halted goal loop. Presents the incomplete items with a per-item risk level (a checkbox dialog for ≤4 items, a numbered text list for ≥5), then a separate follow-up question to either hard-delete (default, no trace) or archive to .forge/dropped/<slug>/. A final confirmation gate guards the irreversible delete, and warns that for already-run work the changed code is NOT reverted. It removes forge state only — never touches git or your code. A halted goal loop can only be dropped whole; its member tasks are excluded from individual drop. An on-demand utility outside the loop (sealing a finished task is fg-done, not this — ADR-0021). Use in contexts like 'forge drop', 'fg-drop', '작업 버리기', '이 작업 취소', '계획 지워', '백로그 비워', 'drop task', 'discard plan'.
---

# fg-drop — discard incomplete work (outside the loop)

This is **not** a stage of the forge loop (fg-ask → fg-run → fg-learn → fg-done). It is an **on-demand utility** — like fg-cleanup, fg-merge, and fg-doctor — that lets you **discard incomplete work you no longer intend to do**: a backlog plan you abandoned, the active slot, a task parked in `executed/` awaiting retro, or a halted goal loop. forge had no way to do this short of a manual `rm`; fg-drop fills that gap (ADR-0021).

Note the contrast with its neighbors: **fg-done** *completes* a task and seals it (the opposite intent — finishing, not abandoning); **fg-cleanup** retires *ADRs* (a decision, not a task); **fg-status**/**fg-doctor** are read-only and cannot host a destructive action. fg-drop is the one place that abandons a not-yet-sealed task.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — the item list, risk labels, the disposal question, the confirmation summary, and the closing line — in the user's language (detect it from the user's own messages), never mirroring this file's English.**

**Forge root**: every `.forge/...` path below is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before reading, deleting, or archiving any state (ADR-0011). The two global exemptions (`.forge/config.json`, `.forge/codebase/`) are never drop targets.

## What is droppable (and what is not)

Drop targets are **incomplete** work = anything not sealed in `done/`. Scan the resolved forge root and gather candidates from these buckets, each carrying a **risk level**:

| Bucket | What it is | Risk |
| --- | --- | --- |
| `backlog/<slug>.md` | a queued plan that has **not run** | **low** — volatile & gitignored; deleting loses nothing in git |
| active slot `plan.md` **with no** `run.md` | promoted but not yet run | **low** — same as a backlog plan |
| active slot **with** `run.md` (+`STATUS.md`, +`review.md`) | **already executed**, awaiting verify/retro/seal | **high** — the code already changed; dropping removes only forge tracking |
| `executed/<slug>/` | parked after "Run all", awaiting retro | **high** — already executed, same warning |
| `loop.md` (halted goal loop) | an fg-loop drive stopped at a wall | **high** — abandons the whole goal loop |

**Excluded — never drop targets:** `done/` (sealed work — that is "completed", not incomplete; un-completing a sealed task is a different operation, out of scope), `quick/LOG.md` (an append-only log, not a task), and the two global exemptions above.

**Goal-loop rule (loop.md present).** If `loop.md` exists, surface it as a **single** droppable item (`goal loop: <one-line goal>`, risk high) — dropping it abandons the whole loop. The tasks listed in its `## Tasks` membership section are **excluded from individual drop** while `loop.md` exists: drop the loop whole, or finish/abandon it via fg-loop first. This avoids having to re-synchronize `loop.md`'s membership list when a member is removed. Non-member plans (e.g. ones fg-ask stacked while the loop was halted) remain individually droppable as usual.

## Behavior — scan, pick, choose disposal, confirm, execute

### 1. Scan and present the incomplete items (hybrid dialog)

Gather all droppable candidates (above). If there are **none**, say so in one line ("no incomplete work to drop") and stop. Otherwise present them with their risk level, choosing the presentation by count — because `AskUserQuestion` caps options at 4:

- **≤ 4 items** → an `AskUserQuestion` **multi-select** checkbox dialog, one option per item. Label each `[<risk>] #<task> <title>` (use the plan's `task:` number when present); include the risk in the label so it is visible per item.
- **≥ 5 items** → print a **numbered text list** (each line: number, `[<risk>]`, slug/title, bucket), then ask the user to type which to drop — e.g. `2,4,5` or `all`. This sidesteps the 4-option cap.

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

- **Active slot** — remove (or move to `dropped/<slug>/`) `plan.md` + `run.md` + `STATUS.md`, plus `review.md` if present (the same companion set fg-done archives — ADR-0018). After this the active slot is empty.
- **`backlog/<slug>.md`** — remove (or move) the single file.
- **`executed/<slug>/`** — remove (or move) the whole directory.
- **`loop.md`** — remove (or move) it, abandoning the goal loop.

**Disposal semantics.** Hard delete is a plain removal. On the **default branch** these are volatile, gitignored files, so nothing is lost in git (the permanent fuel from grilling — CONTEXT.md, ADRs — already landed and is untouched). On a **non-default branch** the forge root `.forge/branch/<branch>/` is git-tracked whole (ADR-0011), so deleting a tracked file there shows up as an **unstaged deletion in `git status`** — recoverable via `git restore` until committed. fg-drop still does not run git (see Constraints); on a branch the removal is simply a tracked-file change the user then commits or restores. Archive moves the files under `.forge/dropped/<slug>/`, which is itself volatile (gitignored under the `.forge/*` default-exclude — no whitelist entry). `dropped/` has no automatic reaper; it is cleaned manually (re-running fg-drop can also target/empty it if you later expose its contents — keep that simple).

```
fg-drop (outside the loop)
   │
   ▼
Resolve forge root (ADR-0011)
   ▼
Scan buckets: backlog · active slot · executed/ · loop.md   (exclude done/, quick/, loop members while loop.md present)
   │ none ──▶ "no incomplete work to drop" → stop
   ▼
Present items with risk level:  ≤4 → checkbox multi-select · ≥5 → numbered text list ("2,4,5" / "all")
   ▼
Disposal question (separate):  Delete (default, no trace)  |  Archive → .forge/dropped/<slug>/
   ▼
Confirmation gate: summary + explicit "yes"   (high-risk run.md present → "⚠ changed code is NOT reverted"; non-default branch → "⚠ tracked files — deletion shows in git status")
   │ no ──▶ abort, change nothing
   ▼
Execute per item (active slot = plan+run+STATUS+review · backlog file · executed/ dir · loop.md)
   ▼
Report what was dropped/archived → end
```

## Constraints

- **forge state only — never git, never your code.** fg-drop deletes/moves `.forge/` state and nothing else. It does **not** revert commits or working-tree changes (the same principle as fg-merge not running git). If the user wants already-changed code reverted, that is theirs to do via git — say so when it is relevant. (On a **non-default branch** the dropped `.forge/branch/<branch>/` files are themselves git-tracked — ADR-0011 — so the deletion appears as an unstaged change; fg-drop still does not run git, the user commits or `git restore`s it.)
- **No auto-run, no chaining.** Like fg-status/fg-doctor/fg-cleanup, fg-drop runs only on demand; it does not invoke other skills and nothing invokes it.
- **Loop members are not individually droppable** while `loop.md` exists — drop the loop whole (the membership-resync logic is deliberately not built).
- **Confirmation is mandatory** before any destructive action — there is no "drop without confirming" path.

## Document impact

- **Removes** (default) or **moves to `.forge/dropped/<slug>/`** (archive) the selected incomplete state: a `backlog/<slug>.md`, the active slot (`plan.md`/`run.md`/`STATUS.md`/`review.md`), an `executed/<slug>/` directory, or `loop.md`.
- Creates `.forge/dropped/` lazily only when archive is chosen. `dropped/` is volatile (gitignored — no whitelist entry); `fg-doctor` tolerates it (does not flag its contents as orphans) and `fg-status` ignores it (abandoned work, not progress) — ADR-0021.
- Touches no permanent docs (CONTEXT.md, ADRs, retros) and no `done/` history.
