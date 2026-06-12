---
name: fg-status
description: A read-only status reporter for the forge loop. Surveys .forge/ and prints where every task stands — the active slot, the backlog of unexecuted ASKs, work awaiting retro, sealed/done history, and quick-lane entries — then derives and shows the single next step you need (with its trigger). It writes nothing and never auto-runs the next step; it only reports. An on-demand utility outside the loop. Use in contexts like 'forge status', '상태', '어디까지 했지', '진행 상황', 'where am I'.
---

# fg-status — read-only status reporter (outside the loop)

This is **not** a stage of the forge loop. It is a read-only dashboard: run it any time to see what has been worked on and what to do next. It **writes nothing** — no plan/run/STATUS/backlog/done/retro/adr/quick is ever created or modified — and it **never auto-runs** the next step; it only reports and points.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** The status report and the next-step line are written in the user's language.

**Forge root**: every `.forge/...` path below is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before reading state (ADR-0011). (fg-status only reports on the resolved root's branch; it does not survey other branches' roots.)

## What it surveys

Read these from `.forge/` (skip silently what doesn't exist):

- **Active slot** — `.forge/plan.md`, `.forge/run.md`, `.forge/STATUS.md` (read its `status:`, `verified:`, and `retro:` fields). This is the one task currently in flight.
- **Backlog** — `.forge/backlog/*.md` (unexecuted ASKs produced by fg-ask). Read each plan's title (first `#` line) and `forge-slug`.
- **Awaiting retro** — `.forge/executed/<slug>/` (parked by fg-run "Run all", each with `STATUS.md` at `status: executed`).
- **Done (history)** — `.forge/done/*/STATUS.md` (`status: done`; note each one's `retro:` = path or `skipped`).
- **Quick lane** — `.forge/quick/LOG.md` (entries written by fg-quick).
- **Goal loop** — `.forge/loop.md` (the goal contract written by fg-loop: one-line goal, `replan-round`/`replan-cap`, stop-condition check states).
- **Supporting (counts only)** — `.forge/retro/` and `.forge/adr/` file counts.

## What it prints

Report in the user's language (the section labels below are canonical English — render them in the user's language). Show **in-flight detail, history in summary**:

- **Active slot** — task title · slug · has run.md? · STATUS `status`/`verified`/`retro`. (Or "none".)
- **Backlog** — list each unexecuted ASK (title · slug). (Or "none".)
- **Awaiting retro (executed/)** — list each parked task. (Or "none".)
- **Done** — count + the most recent few (date-slug · `retro: done`/`skipped`). Summary, not a full dump.
- **Quick lane (quick/LOG)** — count + the most recent few entries. Summary.
- **Goal loop (loop.md)** — one line: goal · round N/cap · checks passing/failing. (Omit the section when no `loop.md` exists.)
- **👉 Next step** — the single next step and how to trigger it (see below).

Keep it scannable. Don't paste full file contents — titles, slugs, and one-line states only.

### Task table

Render the tasks as a compact table with these six columns (column headers are canonical English — render them in the user's language):

```
No. | Date | Task | Stage | Verify | Retro
```

- **No.** — the task's **stable task number**, read from its `<!-- task: N -->` marker (assigned by fg-ask at creation; see PLAN-FORMAT.md). It never changes across buckets, so the same task shows the same number everywhere. A plan created before this feature has no marker — show `—`. This is the number fg-run accepts for selection ("run #7"). It is an identifier, not a position — the table's row order is still set by `priority`/`part`/recency, but the No. value is the fixed task number, not a row index.
- **Date** — the task's date. For `done/`, the directory's `YYYY-MM-DD`. For active/executed, the STATUS `executed:` date. For a fresh backlog item, `—`.
- **Task** — the task slug (or its one-line title). If the plan carries a `<!-- generated-by: fg-loop -->` marker (a fix-forward plan fg-loop auto-generated — see `../fg-loop/SKILL.md` §3), append a `(loop)` origin tag after the slug so auto-generated work is distinguishable from human-grilled work at a glance.
- **Stage (current stage only — not the full pipeline)** — the single stage the task currently sits at, mapped from its bucket:

  | Bucket | Stage |
  | --- | --- |
  | `backlog/` (planned, unexecuted) | `ask` |
  | active slot, `plan.md` only (no run.md) | `run` |
  | active slot `run.md` present (retro pending) / `executed/` | `learn` |
  | `done/` (sealed) | `done` |

- **Verify (O/~/—/✗)** — from the STATUS `verified:` field: `yes` → `O`; `skipped`/`n/a` → `~` (sealable waiver / not-applicable, not a positive confirmation); `pending` / missing / not yet reached → `—`; `failed` → `✗` (UAT ran, result broken — blocks seal). A `—` on a task that already has a `run.md` means the UAT is still owed; a `✗` means it needs fixing or re-grilling (see the next-step machine below). On a sealed `done/` task a `—` means **legacy** (sealed before ADR-0009, no `verified:` field) — not an in-flight pending; render it `—` (or note "legacy") and don't treat it as a gate violation.
- **Retro (O/X)** — from the STATUS `retro:` field: a retro path (retro done) → `O`; **a matching `.forge/retro/*-<slug>.md` file exists while STATUS still reads `pending` (normal pre-seal state — fg-done fills the field at seal; see the next-step machine) → `O`**; `skipped` → `X`; anything else (pending with no retro file / not yet reached) → `—`.

Example (No. is the stable `task:` number; `—` for plans created before task numbering):

```
No. | Date       | Task                  | Stage | Verify | Retro
#3  | 2026-06-06 | add-export-button     | run   | —      | —
#2  | 2026-06-06 | refactor-auth         | done  | O      | O
—   | 2026-06-04 | optional-retro-skip   | done  | ~      | X
```

The table derives purely from file location + the STATUS `verified:`/`retro:` fields (same read as everything else — still read-only). Keep the active slot / backlog / executed sections scannable too; the six columns are the shared shape.

## Deriving the next step (state machine)

Determine the one next step from the file layout, in this priority order:

0. **`.forge/loop.md` exists** (a goal loop is in flight — fg-loop drives whole task loops itself) → the next step is resuming **fg-loop**, which re-derives per-task state internally and continues toward its stop condition (or reports the wall it halted at). Trigger: "forge loop" / `/forge:fg-loop`. Still report the underlying task states below for visibility.
1. **Active `run.md` exists** (a plan has run) — apply in this order (run → verify → learn → done, ADR-0009):
   - `STATUS.md` `verified: failed` → **the UAT ran and the result is broken** — fix it then re-run, or re-grill the plan. Routes to **fg-run** (fix-and-re-run) or fg-ask (re-grill), **not** fg-learn/fg-done. Trigger: "forge run" / `/forge:fg-run` (or "forge ask"). Highest priority — a failed result blocks both retro and seal.
   - `STATUS.md` `verified: pending` or missing → **verification is owed first** — the plan ran but its UAT was never completed. Re-entering fg-run takes its **verification-only resume** (it runs the UAT and writes `verified:` *without* re-executing the workflow — see fg-run step 4), which precedes retro. Trigger: "forge run" / `/forge:fg-run`. Do not route past this to fg-learn.
   - `verified:` sealable and (a matching `.forge/retro/*-<slug>.md` exists **or** `STATUS.md` `retro: skipped`), not yet sealed → **fg-done**. Trigger: "작업 완료" / "봉인" / `/forge:fg-done`. **Check this before the pending branch below**: after fg-learn writes the retro file, STATUS still reads `retro: pending` until fg-done closes it, so a present retro file means the task is ready to seal — not to retro again.
   - `verified:` sealable and `retro: pending` with **no** matching retro file (and not `skipped`) → **fg-learn** (retro), or skip → fg-done. Trigger: "forge learn" / `/forge:fg-learn`.
2. **Active `plan.md` exists but no `run.md`** → **fg-run** (execute). Trigger: "forge run" / `/forge:fg-run`.
3. **Active slot empty, but `executed/` has parked tasks** → branch each parked task on its `STATUS.md` `verified:` first (same precedence as the active slot — verify before retro):
   - `verified: failed` → **fix-and-re-run or re-grill**, **not** retro. Routes to **fg-run**, which unparks this `executed/<slug>` task into the active slot before fix-and-re-run (see fg-run's "Failed parked-task recovery"), or fg-ask re-grill. Trigger: "forge run" / "forge ask".
   - `verified: pending` or missing → **verification recovery**. Run all verifies each task before parking, so new tasks won't sit here; an older run predating the gate can. It has no active `run.md`, so fg-run's verification-only resume can't reach it — route by retro state: if its retro is still owed (`retro: pending`, no retro file) → **fg-learn**, whose verification gate confirms the UAT first and records it in STATUS before retroing (Trigger: "forge learn" / `/forge:fg-learn`); if the retro is done or `retro: skipped` → **fg-done**, which confirms the UAT at seal time (Trigger: "작업 완료" / `/forge:fg-done`). Flag this so the user isn't surprised by the guard.
   - `verified:` sealable (`yes`/`skipped`/`n/a`) → branch on retro state, same priority rule as the active-slot case: if a matching `.forge/retro/*-<slug>.md` exists **or** `STATUS.md` reads `retro: skipped` → **fg-done** (seal — STATUS stays `retro: pending` until fg-done closes it, so a present retro file means ready-to-seal, not retro-again). Trigger: "작업 완료" / `/forge:fg-done`. Else → **fg-learn** (retro the awaiting ones). Trigger: "forge learn".

   When several are parked, report each task's state; the single next step is the highest-priority unmet one (failed → pending → retro → seal).
4. **Active slot empty, but `backlog/` has unexecuted plans** → **fg-run** (it promotes from the backlog), or **fg-ask** to refine first. Trigger: "forge run" / "계획 실행".
5. **Everything empty (active + backlog + executed)** → no work in progress → **fg-ask** to start a new task. Trigger: "forge ask" / "새 작업 시작".

State the next step as a one-liner: `👉 Next: <skill> — <trigger>` (rendered in the user's language). Do **not** ask whether to proceed and do **not** invoke it — informing is fg-status's job; acting on the next step is `fg-next`'s (ADR-0015).

## Handoff

There is no loop handoff — fg-status is self-contained and read-only. End with the `👉 Next` line so the user knows where they stand. If they want to act on it, they trigger the named skill themselves — or run `fg-next`, the acting sibling, which derives that same next step and runs it right away — announcing it in one line, with no separate go-ahead.

## Document impact

- **None.** fg-status creates and modifies nothing. It is pure read-only reporting.
