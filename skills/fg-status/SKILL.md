---
name: fg-status
description: A read-only status reporter for the forge loop. Surveys .forge/ and prints where every task stands — the active slot, the backlog of unexecuted ASKs, work awaiting retro, sealed/done history, and quick-lane entries — then derives and shows the single next step you need (with its trigger). It writes nothing and never auto-runs the next step; it only reports. An on-demand utility outside the loop. Use in contexts like 'forge status', '상태', '어디까지 했지', '진행 상황', 'where am I'.
---

# fg-status — read-only status reporter (outside the loop)

This is **not** a stage of the forge loop. It is a read-only dashboard: run it any time to see what has been worked on and what to do next. It **writes nothing** — no plan/run/STATUS/backlog/done/retro/adr/quick is ever created or modified — and it **never auto-runs** the next step; it only reports and points.

**Language**: This skill file is authored in English, but always converse with the user in the user's language. The status report and the next-step line are written in the user's language.

## What it surveys

Read these from `.forge/` (skip silently what doesn't exist):

- **Active slot** — `.forge/plan.md`, `.forge/run.md`, `.forge/STATUS.md` (read its `status:` and `retro:` fields). This is the one task currently in flight.
- **Backlog** — `.forge/backlog/*.md` (unexecuted ASKs produced by fg-ask). Read each plan's title (first `#` line) and `forge-slug`.
- **Awaiting retro** — `.forge/executed/<slug>/` (parked by fg-run "Run all", each with `STATUS.md` at `status: executed`).
- **Done (history)** — `.forge/done/*/STATUS.md` (`status: done`; note each one's `retro:` = path or `skipped`).
- **Quick lane** — `.forge/quick/LOG.md` (entries written by fg-quick).
- **Supporting (counts only)** — `.forge/retro/` and `.forge/adr/` file counts.

## What it prints

Report in the user's language (the section labels below are canonical English — render them in the user's language). Show **in-flight detail, history in summary**:

- **Active slot** — task title · slug · has run.md? · STATUS `status`/`retro`. (Or "none".)
- **Backlog** — list each unexecuted ASK (title · slug). (Or "none".)
- **Awaiting retro (executed/)** — list each parked task. (Or "none".)
- **Done** — count + the most recent few (date-slug · `retro: done`/`skipped`). Summary, not a full dump.
- **Quick lane (quick/LOG)** — count + the most recent few entries. Summary.
- **👉 Next step** — the single next step and how to trigger it (see below).

Keep it scannable. Don't paste full file contents — titles, slugs, and one-line states only.

### Task table

Render the tasks as a compact table with these five columns (column headers are canonical English — render them in the user's language):

```
No. | Date | Task | Stage | Retro
```

- **No.** — the task's **stable task number**, read from its `<!-- task: N -->` marker (assigned by fg-ask at creation; see PLAN-FORMAT.md). It never changes across buckets, so the same task shows the same number everywhere. A plan created before this feature has no marker — show `—`. This is the number fg-run accepts for selection ("run #7"). It is an identifier, not a position — the table's row order is still set by `priority`/`part`/recency, but the No. value is the fixed task number, not a row index.
- **Date** — the task's date. For `done/`, the directory's `YYYY-MM-DD`. For active/executed, the STATUS `executed:` date. For a fresh backlog item, `—`.
- **Task** — the task slug (or its one-line title).
- **Stage (current stage only — not the full pipeline)** — the single stage the task currently sits at, mapped from its bucket:

  | Bucket | Stage |
  | --- | --- |
  | `backlog/` (planned, unexecuted) | `ask` |
  | active slot, `plan.md` only (no run.md) | `run` |
  | active slot `run.md` present (retro pending) / `executed/` | `learn` |
  | `done/` (sealed) | `done` |

- **Retro (O/X)** — from the STATUS `retro:` field: a retro path (retro done) → `O`; `skipped` → `X`; anything else (pending / not yet reached) → `—`.

Example (No. is the stable `task:` number; `—` for plans created before task numbering):

```
No. | Date       | Task                  | Stage | Retro
#3  | 2026-06-06 | add-export-button     | run   | —
#2  | 2026-06-06 | refactor-auth         | done  | O
—   | 2026-06-04 | optional-retro-skip   | done  | X
```

The table derives purely from file location + the STATUS `retro:` field (same read as everything else — still read-only). Keep the active slot / backlog / executed sections scannable too; the five columns are the shared shape.

## Deriving the next step (state machine)

Determine the one next step from the file layout, in this priority order:

1. **Active `run.md` exists** (a plan has run):
   - `STATUS.md` `retro: pending` → **fg-learn** (retro), or skip → fg-cleanup. Trigger: "forge learn" / `/forge:fg-learn`.
   - a matching `.forge/retro/*-<slug>.md` exists, **or** `STATUS.md` `retro: skipped` (not yet sealed) → **fg-cleanup**. Trigger: "forge cleanup" / `/forge:fg-cleanup`.
2. **Active `plan.md` exists but no `run.md`** → **fg-run** (execute). Trigger: "forge run" / `/forge:fg-run`.
3. **Active slot empty, but `executed/` has parked tasks** → **fg-learn** (retro the awaiting ones). Trigger: "forge learn".
4. **Active slot empty, but `backlog/` has unexecuted plans** → **fg-run** (it promotes from the backlog), or **fg-ask** to refine first. Trigger: "forge run" / "계획 실행".
5. **Everything empty (active + backlog + executed)** → no work in progress → **fg-ask** to start a new task. Trigger: "forge ask" / "새 작업 시작".

State the next step as a one-liner: `👉 Next: <skill> — <trigger>` (rendered in the user's language). You **may ask** whether to continue into it, but do not invoke it automatically — fg-status's job is to inform, not to act.

## Handoff

There is no loop handoff — fg-status is self-contained and read-only. End with the `👉 Next` line so the user knows where they stand. If they want to act on it, they trigger the named skill themselves (or you ask once, then invoke only on agreement).

## Document impact

- **None.** fg-status creates and modifies nothing. It is pure read-only reporting.
