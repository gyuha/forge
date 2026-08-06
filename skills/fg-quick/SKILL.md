---
name: fg-quick
description: A lightweight lane outside the forge loop for trivial tasks (typo fixes, path tweaks, version bumps, small renames) — grills lightly, then runs the change directly with no formal artifacts (no ADR/plan/run/STATUS/retro). Bails to fg-ask if the task turns out non-trivial. Use in contexts like 'forge quick', '빠르게 처리', '이거 빨리 해줘', 'quick task'.
---

# fg-quick — lightweight lane (outside the loop)

This is **not** a stage of the forge loop. It is a side lane for genuinely small, low-risk tasks where the full loop (fg-ask → fg-run → fg-learn → fg-done, with its plan/ADR/run/STATUS/retro artifacts) is pure ceremony. fg-quick keeps the one pillar that makes forge forge — **grilling is conversational** — but deliberately drops the formal-artifact pillar for trivial work, recording a single line to a log instead. See `.forge/adr/0003-fg-quick-lightweight-lane.md` for the decision and its trade-off.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** The LOG entry and any handoff are written in the user's language.

**Forge root**: the `.forge/quick/LOG.md` path is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before logging (ADR-0011).

## What fg-quick is (and is not)

- **It still grills** — but lightly. A question or two at most, and only when the codebase can't answer it. It is a live conversation, never a workflow (Pillar 1 holds).
- **It produces no formal artifacts** — no ADR, no `.forge/backlog/` plan, no `.forge/plan.md` / `run.md` / `STATUS.md`, no retro. The only trace is one line in `.forge/quick/LOG.md`.
- **It is isolated from the main loop.** fg-quick never reads or writes the formal active slot (`.forge/plan.md` / `run.md` / `STATUS.md`), the backlog, or `.forge/done/`. A formal task can be mid-flight and a quick task runs independently in its own lane.
- **It is self-contained.** One invocation does grill → log → run → mark-done. There is no separate fg-done to call afterward (there is no plan/STATUS to seal).
- **Retro is skipped by definition.** Trivial tasks have nothing to fold into the docs. If something genuinely worth recording surfaces, that is the signal this was not a quick task — see the bail guard.

## Behavior

### 1. Light grilling

Clarify just enough to act safely. Prefer exploring the codebase over asking. Ask at most a question or two, one at a time, and only for things the code can't answer (intent, choice between two equally-valid options). Don't run the full grill-with-docs interrogation — this is the quick lane.

### 2. Bail guard — is this actually a quick task?

While clarifying, watch for signs the task is **not** trivial:

- a decision that is **hard to reverse**, or that a future reader would find surprising without context (i.e. ADR-worthy),
- **multiple work slices** or real architectural shape,
- anything touching **migrations, public contracts, auth, or data** in a non-obvious way.

If any appears, **stop and bail to `fg-ask`**: tell the user "this isn't a quick task — it deserves the full loop (grilling → plan → run → retro → done)," and point them to `fg-ask` (or offer to invoke it). Do not force a serious task through the quick lane — that is exactly what this guard prevents. Leave no quick-lane residue when you bail.

### 3. Record one line to the log

Before acting, append an entry to `.forge/quick/LOG.md` (create the directory and file lazily on first use). Keep it to a few lines, written in the user's language — the labels below are canonical English names; render them in the user's language (e.g. Korean `요청:`/`결정:`/`결과:`), matching the labels already used in the log:

```md
## {YYYY-MM-DD} — {one-line task title}
- Request: {what was asked, one line}
- Decision: {the key choice made during light grilling, or "—"}
- Result: pending
```

On the default branch, `.forge/quick/` is gitignored volatile state (the `.gitignore` whitelists only the permanent docs, which `quick/` is not); on a non-default branch it lives under the git-tracked `.forge/branch/<branch>/` root (ADR-0011). Either way the log is a local convenience record, not loop fuel.

### 4. Run it directly

The task is small by definition, so handle it directly in this session — no Dynamic Workflow, no subagents. Make the change, and verify it does what was asked (don't stop at "it ran").

### 5. Mark the result

Update the log entry's `Result:` line (rendered in the log's language, e.g. `결과:`) to `done` (or `failed: {one-line reason}`). On failure, don't pile on retries in the quick lane — surface it honestly and recommend handling it properly through `fg-ask` (the full loop), where the divergence can be grilled and recorded.

## Handoff

Close with the **handoff table** per [`../fg-next/HANDOFF.md`](../fg-next/HANDOFF.md) — the single definition of its shape; never restate that layout here. Statement form, in the user's language.

- `Just did` = one line on what you changed, and that it's logged in `.forge/quick/LOG.md`.
- **A larger follow-up surfaced** → `Next step` = `fg-ask`, to open it as a proper task; `How to start` = `/forge:fg-ask`.
- **No follow-up** → `Next step` = none: the quick lane is self-contained, so there is nothing to seal and no next stage; `How to start` = nothing to trigger — the task is closed.
- `Alternative` is omitted either way — the quick lane has no second route from here.

(The eco summary table does not apply to the quick lane, so this row set never changes with `eco`.)

## Document impact

- Appends one entry to `.forge/quick/LOG.md` (lazy creation; gitignored on the default branch, tracked under the branch root otherwise — ADR-0011).
- Creates **no** ADR, plan, run, STATUS, retro, or `done/` archive, and does not touch the main loop's active slot.
