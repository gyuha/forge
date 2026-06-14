---
name: fg-done
description: Tidies up the residue of one loop — confirms the retro, marks STATUS.md done, archives the task, empties the active .forge state, and closes the loop. Use when you want to seal a finished task whose retro is already done, in contexts like '작업 완료', '봉인', '이거 마무리' (the old triggers '작업 정리' and 'forge complete' are still recognized as aliases; note 'forge cleanup' now routes to the separate ADR-retirement skill, not here). Emptying the active state is what blocks the same plan from re-running.
---

# fg-done — ④ Done (tidy-up / re-run guard)

This is the last step of the forge loop — the ④ **done** stage that seals one loop. Its job is to **tidy up** the residue left by one loop (ask·plan → execute → retro → done): confirm the retro, mark the task's STATUS.md as done, archive it, empty the active state, and close the loop. The unit of cleanup is a single **task** — there is no notion of closing an epic or bundling several tasks together. Because a task *is* one loop, you only need to tidy up that one loop cleanly.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** All documents this skill generates for the user's project (plan, run notes, retros, CONTEXT.md entries, ADRs, handoff messages) are written in the user's language. Section headings defined in the format docs are canonical English names — when writing a document, render headings in the user's language; consumers match sections by meaning and position, not exact strings.

**Forge root**: every `.forge/...` path below is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before reading or writing state (ADR-0011).

This skill is self-contained and standalone. It depends on no external skills: it reads input from `.forge/` and writes output to `.forge/done/`.

## Before starting: confirm the state is ready to tidy up

Sealing is cumbersome to undo, and once you empty the state, the trace of the active task moves into the archive. So before starting, look at two things.

First, check whether there is actually a task to tidy up. The targets are the **active slot** (`.forge/plan.md`/`run.md`) and the **awaiting-retro queue** (`.forge/executed/<slug>/` — the tasks parked by fg-run "Run all"). Stop **only when both are absent/empty** — note that "Run all" deliberately empties the active slot while leaving tasks in `executed/`, so an empty active slot alone does **not** mean "no work": parked tasks are still cleanup targets. Before declaring "no task in progress" when both are empty, also scan `.forge/done/*/` for a directory whose `STATUS.md` is missing or still reads `status: executed` — that is an earlier seal interrupted mid-way; finish its close-out now (the flip is idempotent) instead of reporting an empty state. When both are empty and no half-sealed directory exists, there is nothing to tidy up, so guide the user to start with `fg-ask` to begin a new task, and stop.

Also consult the existing completion markers `.forge/done/*/STATUS.md`: if a marker with the same slug already exists, this task has already been tidied up — surface it instead of double-sealing, and disambiguate the new archive directory name (`<date>-<slug>-2`) only when the user confirms it really is a separate cycle.

Next, confirm **the work was verified** (the **no-seal-without-verification guard**). This guard comes **before** the retro guard below, matching the loop order run → verify → learn → done. Both this guard and the retro guard are evaluated **per task** — when the active slot and `executed/` both hold tasks (e.g. after a Run-all fail-stop), check each task independently: a blocking value sets only that task aside, while tasks whose guards pass are still sealed in the same cleanup. Sealing with no verification decision at all lets a silently-unchecked task land in `done/`; the gate forces a *recorded* decision rather than silent omission. The task's `STATUS.md` `verified:` field must be one of the **sealable** values: `yes (<evidence>)` (confirmed working, carrying one-line evidence of how it was checked — the form fg-run records; see ADR-0009) / `n/a (<reason>)` (nothing runnable to verify) / `skipped (<reason>)` (a deliberate, auditable waiver — note this **still seals**: it is an explicit waiver, not a confirmation, the same restraint as retro-skip). fg-run records this at its handoff UAT — see ADR-0009. If `verified:` is a **blocking** value (`pending`, `failed`, or missing), do not seal yet — handle by case:
- **`pending` or missing, active slot with `run.md`** → point the user to fg-run's **verification-only resume** (it runs the UAT and writes `verified:` without re-executing the workflow). Do this before any retro.
- **`pending` or missing, a parked `executed/<slug>` task or an older run predating this guard** → there is no reachable fg-run handoff (the active slot is empty), so confirm it **here, now**: run the UAT against the plan's goal and record the outcome in the STATUS. If it passes, record a sealable value (`yes (<evidence>)` / `skipped (<reason>)` / `n/a (<reason>)`) and continue. **If this cleanup-time UAT finds the work broken, record `failed (<reason>)`, stop the cleanup, and route to repair** (fg-run fix-and-re-run or fg-ask re-grill) — do not seal and do not waive it to a sealable value. This is the recovery path for parked/older tasks, and it can land on `failed` just like the fg-run handoff.
- **`failed`** (whether the task arrived `failed`, or the cleanup-time UAT just above recorded `failed`) → the work is broken. **Never seal it, never waive it through** — do not convert it to `skipped`. Do not seal this task — set it aside and route it back to execution via **fg-run**, continuing to seal any other tasks whose guards pass. fg-run is the single owner of unparking a failed task (it moves `executed/<slug>/{plan,run,STATUS}` back to the active slot once that slot is free, then fix-and-re-run — see fg-run's "Failed parked-task recovery"; or re-grill via fg-ask). fg-done does not move it itself — it just hands off. It returns for sealing only once a fresh fix-and-re-run re-verifies it to a sealable value (`yes`/`n/a`).

Then, confirm **whether the retro is done or was intentionally skipped**, on a per-task basis. Tidying up without a retro means whatever was learned in that loop is lost forever — this is exactly why forge keeps the retro as a formal step of the loop. The decision rule is slug matching: for each task, the first line of the plan `<!-- forge-slug: <slug> -->` either must have a corresponding retro (`.forge/retro/*-<slug>.md`), **or** its `STATUS.md` must carry `retro: skipped` (the retro was deliberately skipped for a trivial, low-divergence task — see fg-run's handoff). Either one satisfies the guard. Do not tidy up a task that has neither; instead guide "first run a retro with `fg-learn`" — when there are several tasks in `executed/`, clean up only the ones whose retro is done or skipped and leave the rest. This is the **no-seal-without-retro guard**. If the user explicitly chooses to skip the retro here at cleanup time, record it the same way — set `retro: skipped (<one-line reason>)` in the STATUS.md as you close it out, so the skip is auditable rather than silent.

```
Active slot AND executed/ both empty? ── yes ──▶ half-sealed done/* (STATUS not closed out)? finish its close-out · else "No task in progress. Start fresh with fg-ask" → stop
        │ no (active slot or a parked executed/ task exists)
        ▼
Verified? (sealable = yes/skipped/n/a)
        │ pending/missing ──▶ active slot: "fg-run verification-only resume" · parked/legacy: "confirm UAT here, now" → stop or recover
        │ failed ──▶ "fix-and-re-run or re-grill via fg-ask — never seal a failed task" → stop
        │ sealable (yes/skipped/n/a recorded)
        ▼
Retro done or skipped? ── no ──▶ "First run a retro with fg-learn" → stop
        │ yes (retro file exists, or STATUS retro: skipped)
        ▼
   Proceed with sealing
```

## Behavior

Sealing proceeds in the order archive → empty → notify → close the loop. The order matters because if you empty the active state before the archive finishes, you lose the original you were going to move.

**1) Tidy up·archive.** **Close out the STATUS.md first, in place** — flip `status:` to `done` and fill its fields (next paragraph) while the task still sits in the active slot or `executed/<slug>/` — and only then move the files. An interruption then always leaves the task in a non-empty source bucket, which the pre-check above re-enters and the idempotent flip completes cleanly. Then move the task being tidied up into `.forge/done/<date-slug>/` — for the active slot, move `.forge/plan.md`/`run.md` (and `.forge/STATUS.md`, plus `.forge/review.md` if an adversarial review left one — ADR-0018); for the awaiting-retro queue, move the whole `.forge/executed/<slug>/` directory (which already carries its `STATUS.md`). The slug is taken from the `forge-slug` comment on the first line of the plan and paired with the retro file under the same rule (`YYYY-MM-DD-slug`). The unit of cleanup is still one task — when there are several tasks in `executed/`, clean up each into its own separate `done/` directory.

The status marker **`STATUS.md`** was already written by fg-run with `status: executed` (and `retro: pending`, or `retro: skipped (<reason>)` if the retro was skipped at the handoff). Cleanup does not create a new marker — it **closes out the existing one**: flip `status:` to `done` and fill in the `completed` / `verified` / `retro` / `docs updated` fields, then archive it alongside `plan.md`/`run.md`. The `verified:` field carries the UAT outcome fg-run recorded (`yes (<evidence>)` / `skipped (<reason>)` / `n/a (<reason>)`); the `retro:` field becomes the retro path when a retro was done, or stays `skipped (<reason>)` when it was skipped. (If the STATUS.md is missing — e.g. an older run that predates this lifecycle — create it now for backward compatibility.) The closed-out content is minimal and fixed (written in the user's language):

```md
# STATUS — {task title}
slug: {slug}
status: done
executed: {YYYY-MM-DD}
completed: {YYYY-MM-DD}
verified: yes (<evidence>)   # or: skipped (<reason>) / n/a (<reason>)
retro: .forge/retro/{YYYY-MM-DD}-{slug}.md   # or: skipped (<reason>)
docs updated: {CONTEXT.md terms / ADR-NNNN / none}
```

`STATUS.md` is the machine-readable completion marker that travels with the task files — fg-run reads `done/*/STATUS.md` (`status: done`) to summarize finished work in its start-up guidance.

For reference, on the default branch the volatile loop state (including `done/`) is gitignored — only the permanent docs are tracked via the whitelist; on a non-default branch the branch root is tracked whole (ADR-0011). The persistent trace cleanup leaves is not `.forge/done/` but the retro (`.forge/retro/`) and the persistent docs that task updated (`CONTEXT.md`, `.forge/adr/`, etc.). The archive is, at most, a local work record.

**2) Empty the active state.** By the time the archive move is done, the active `.forge/` should no longer have `plan.md`/`run.md`/`STATUS.md` — if any leftover copy or byproduct remains, delete it and confirm the active state is definitely empty. This is the **core mechanism of the re-run guard**. `fg-run` runs by treating `.forge/plan.md` as the source of truth; once that file is gone, it can no longer find a plan to run. In other words, it structurally prevents the accident of "a closed task accidentally running again."

**3) Completion notice.** Summarize at a glance what was finished, which persistent docs were updated (retro, ADR, CONTEXT, etc.), and where the archive was left. Make the wrap-up explicit so the user clearly recognizes that one loop is done. If `git status` shows the permanent docs this loop touched (`.forge/retro/`, `.forge/adr/`, `CONTEXT.md` — or the branch root on a non-default branch) still uncommitted, add a one-line reminder to commit them — a reminder only; never run git yourself (the same restraint as fg-merge).

**3a) Codebase map check (conditional — offer, never auto-run).** After the notice, check two cheap signals: **(a)** does `.forge/codebase/` exist (the fg-map map that fg-ask reads as grilling fuel)? and **(b)** did this loop change project files the map describes — i.e. does `git status --short` show changes (modified *or* untracked) on paths **not** starting with `.forge/` (skills, `src/`, manifests, README, …)? If **both** are true, the map may now be stale, so offer **once**, in the user's language: *"이 작업이 `<changed project files>`를 바꿨고 `.forge/codebase/` 지도가 있습니다 — 지도가 stale할 수 있어요. 지금 `fg-map`을 돌릴까요?"* On agreement, invoke the `fg-map` skill; on decline, just finish. **This is an offer, never an auto-run** — fg-map fans out 4 subagents and is deliberately on-demand, so a human decides the cost (the same offer-not-auto restraint as deep-research, ADR-0006). If `.forge/codebase/` is absent, **or** the loop changed only `.forge/` docs (ADR/retro — not what the map describes), **say nothing and skip**. (The offer is a handoff pointer, not a dependency — fg-done still seals self-containedly. fg-map will stamp `last_mapped_commit=HEAD`, which may lag the still-uncommitted seal by one commit — harmless, since fg-ask's staleness warning only fires when the map is dozens of commits behind.)

**4) Close the loop.** If `fg-learn` left a follow-up, **state** that it can start as a **new task** — do not ask "shall I start it?" or auto-invoke fg-ask (chaining is `fg-next`'s job — ADR-0015). This is not resuming the task you just closed — that task is sealed — but opening a new loop from `fg-ask`. If there is no follow-up, finish here.

```
Start sealing
   │
   ▼
Active slot AND executed/ both empty?
   │ yes ──▶ half-sealed done/*? finish close-out · else "No task in progress" → guide to fg-ask → stop
   │ no (active slot, or a parked executed/ task)
   ▼
Verified? (STATUS verified state)
   │ pending/missing ──▶ active: fg-run verification-only resume · parked/legacy: confirm UAT here → stop or recover
   │ failed ──▶ fix-and-re-run or re-grill via fg-ask (never seal a failed task) → stop
   │ sealable (yes/skipped/n/a)
   ▼
Retro done or skipped?
   │ no ──▶ guide to retro first with fg-learn → stop
   │ yes (retro file exists, or retro: skipped)
   ▼
Close out STATUS.md in place → archive → .forge/done/<date-slug>/
   ▼
Empty active .forge  (= block re-run)
   ▼
Completion notice (summary of updated docs)
   ▼
Codebase map stale?  (.forge/codebase/ exists AND non-.forge/ changes in git status)
   │ yes ──▶ OFFER fg-map (y → invoke fg-map · n → continue) — never auto-run
   │ no  ──▶ skip silently
   ▼
Follow-up exists?
   │ yes ──▶ propose starting fg-ask as a new task → end
   │ no  ──▶ end
```

## Wrap-up: guide the next flow

When cleanup is done, convey the following three things naturally, in a conversational tone. Don't mechanically stamp out a fixed template; speak so the user knows where they stand right now.

- **What you just did** — that you tidied up the task, archived it into `.forge/done/<date-slug>/` with STATUS.md marked done, and emptied the active state, plus a one-line summary of the docs this loop updated (retro, ADR, CONTEXT) — and, if those git-tracked docs are still uncommitted, a one-line reminder to commit them (reminder only, never run git yourself).
- **Next step** — make it clear that, since the active state is empty, the same plan will never run again. If `fg-learn` left a follow-up, let them know it can be started as a new task.
- **How to start** — if there is a follow-up, **state** that it can start as a new task and stop; do **not** ask "shall I start it?" or auto-invoke fg-ask (chaining is `fg-next`'s job — ADR-0015). Give the trigger — "forge ask" / "새 작업 시작" / `/forge:fg-ask`, or `fg-next`. If there is no follow-up, finish here.
- **Codebase map** — if this loop changed project files (non-`.forge/` paths) and `.forge/codebase/` exists, **offer** to refresh the map with `fg-map` so the next fg-ask grills against a current map (step 3a above). It is an **offer, not an auto-run**; if the map is absent or the loop only touched `.forge/` docs, skip it silently.

## Document impact

- `.forge/done/<date-slug>/` — archive of the tidied-up `plan.md`/`run.md` + the closed-out `STATUS.md` (`status: done`) completion marker (local; gitignored on the default branch, tracked under the branch root otherwise — ADR-0011). fg-run reads the `STATUS.md` markers to exclude finished work from its candidates and to summarize status.
- Active `.forge/` — emptied of `plan.md`/`run.md`/`STATUS.md` so the next run finds no plan.
- Persistent docs (`.forge/retro/`, `.forge/adr/`, `CONTEXT.md`, etc.) are not newly created in this step — the earlier steps already updated them.

If you need the format for retro·ADR·CONTEXT, read the original format docs directly (don't copy per skill):
`${CLAUDE_PLUGIN_ROOT}/skills/fg-learn/RETRO-FORMAT.md`, `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/ADR-FORMAT.md`, `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/CONTEXT-FORMAT.md`
(relative paths from the skill directory: `../fg-learn/RETRO-FORMAT.md`, `../fg-ask/<file>`)
