---
name: fg-run
description: Runs a refined plan (.forge/plan.md, or a waiting plan in .forge/backlog/) as a Claude Code Dynamic Workflow — one unexecuted plan runs right away; several show a priority-sorted selection (with 'Run all'), then the chosen task is promoted into the active slot. Warns before re-running a plan that already ran. Use in contexts like 'forge run', 'forge execute', '계획 실행', '이거 워크플로우로 돌려줘'.
---

# fg-run — ② Execute (Dynamic Workflow)

The second turn of the forge loop. It takes the `.forge/plan.md` that fg-ask refined and applies it to real code/changes as a Claude Code Dynamic Workflow. This is the stage where large jobs — migrations, full audits, mass refactors — that need many subagents working in parallel run in the background, and their results are verified against the plan.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** All documents this skill generates for the user's project (plan, run notes, retros, CONTEXT.md entries, ADRs, handoff messages) are written in the user's language. Section headings defined in the format docs are canonical English names — when writing a document, render headings in the user's language; consumers match sections by meaning and position, not exact strings.

**Forge root**: every `.forge/...` path below is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per [FORGE-ROOT.md](./FORGE-ROOT.md) in this directory before reading or writing state (ADR-0011).

## Purpose

`.forge/plan.md` is the "source of truth." This skill enforces that source of truth through a workflow, and records where the plan and the actual results diverged in `.forge/run.md`. That note becomes the retro input for the next stage, fg-learn. The point is not to touch the plan itself again, but to run it as planned and record the divergences.

## Before starting: task selection and the re-run guard

A workflow spins up many subagents, so it burns a lot of tokens. Running the same plan twice by mistake is costly and has side effects (duplicate commits, duplicate migrations, etc.). So before entering execution, check the state first, and when the backlog holds several tasks, the user picks what to run.

**1) Check the active slot.** If `.forge/plan.md` (the active slot) already exists, there is a task in progress — skip the backlog and go straight to step 4 below (only one task is active at a time). If any `.forge/executed/*/STATUS.md` carries `verified: failed` while the slot is occupied, note it in one line — its recovery waits until the slot frees (see step 5). Step 4 first separates an **interrupted UAT** (verification-only resume, no re-execution) from a genuine **re-run** before doing anything destructive.

**2) If the active slot is empty, FIRST check for a parked failure, THEN scan the backlog.** Before counting backlog candidates, scan `.forge/executed/*/STATUS.md` for `verified: failed` — a parked task whose UAT failed and is awaiting repair (fg-status/fg-learn/fg-done all route such tasks here, and fg-run is the only stage that can recover them). **If one or more exists, surface it as the top recovery candidate ahead of any new backlog work** — a known-broken task shouldn't be stranded while new work starts. Offer to recover it now via the unpark procedure in step 5 (unpark → step 4's `verified: failed` branch → fix-and-re-run, or re-grill via fg-ask). Only when there is no failed parked task, or the user explicitly declines recovery to start something else, proceed to the backlog scan. Then gather unfinished candidates from `.forge/backlog/*.md` (= plans with no matching slug seal in `.forge/done/` — a seal is a `done/<date-slug>/STATUS.md` marker with `status: done`, written when fg-done archives the task). Before presenting anything, give the user a one-line status summary derived from the file layout: "done X (from `done/*/STATUS.md` with `status: done`) · awaiting retro Y (`executed/`, `status: executed`) · unexecuted Z (`backlog/`)" — so they see at a glance what has finished and what remains. Read each STATUS.md's `status` field to confirm the count (done = `done/*/STATUS.md` at `status: done`). Then, depending on the candidate count:

- **0** — There is no plan to execute. Point to fg-ask and stop (the stage that defines the task, grills it, and produces a plan), closing with the handoff table (see "Early-exit handoffs" below). Do not guess a plan into existence and run it.
- **1** — **No menu, no confirmation question: promote and run it right away.** Announce in one line what is being run ("Running the only unexecuted plan from fg-ask: <title>") and proceed — the orchestration-script approval in step 2 of the main body still gates the actual workflow, so this skips only the redundant pre-confirmation.
- **2 or more** — Present a priority-sorted selection, framed as "these are the plans fg-ask produced that haven't run yet — which one shall I execute?". **Sort every candidate first**: read each plan's `<!-- priority: high|medium|low -->` marker (see PLAN-FORMAT.md) and order them `high → medium → low`; a plan with no marker is treated as `medium`; ties within the same priority use numeric `part: N/M` order, then slug alphabetical. Show each unfinished plan as `#<task> [<priority>] <title>` (stable `task:` number, or `#—`; include the one-line goal + slice count), with "Run all (N sequential)" last. The selection UI depends on count because `AskUserQuestion` accepts at most four options:
  - **2–3 plans** → use `AskUserQuestion`; the plan options plus the final "Run all" option total at most four.
  - **4 or more plans** → print a numbered text list in the same order, append `all — Run all (N sequential)`, and ask the user to type a stable task number, slug, list number, or `all`. Do not truncate candidates to fit the dialog.
  This is ordering only — there is **no auto-selection**; the user still picks. A direct reference such as "run #7" matches the plans' `task:` markers. The `#<task>` number is a stable identifier for selection, not the sort key. Keep the selection in conversation, outside the workflow.

**Part-plans (split tasks).** If plans carry a `<!-- part: N/M -->` marker (a big task fg-ask split into an ordered series — see PLAN-FORMAT.md), append `(part N/M)` to their label and keep them in sequence order (ordered by the numeric N in their `part: N/M` markers — slug alphabetical misorders 10+ parts). Recommend completing them one at a time, in order, each as its own full `execute → learn → done` loop. This is a **soft order** — do not block a later part because an earlier one isn't sealed; the user may still pick any item.

**3) Promotion and ADR check.** Move (promote) the chosen backlog file to `.forge/plan.md` — from this point it is in the normal starting state of "active plan present, no run," and joins the main body below. Right before starting, check that the `.forge/adr/NNNN-*` referenced by the plan's "Source of truth" actually exists — if not, it is a stale-plan signal, so warn and ask once: "shall I supplement it via fg-ask, or proceed as is?" (this does not block). Then **run the plan's DoD commands once to take a `DoD baseline`** — the pre-state at the moment execution starts. If it disagrees with the pre-state the plan recorded (fg-ask ran the same commands at authoring time — see PLAN-FORMAT.md's runnable-DoD rule), warn in one line and proceed: **do not block**, because another session may legitimately have done part of the work already (the same non-blocking discipline as the ADR check). A *forward* check that already passes here is the thing to look at before building the workflow.

**4) Re-run guard — but first, the verification-resume check.** **If `.forge/run.md` already exists**, the plan has run once. Before treating this as a re-run, read STATUS `verified:`, because the two cases need opposite handling:

- **`verified: pending` or missing** → the run finished but its handoff UAT was never completed (e.g. the session ended before verification). This is **not a re-run** — take the **verification-only resume**: read `plan.md`/`run.md`/`STATUS.md`, run the UAT against the plan's goal (see "Verify before handing off (UAT)"), write the outcome into STATUS `verified:`. **Then branch on that outcome**: a sealable result (`yes`/`skipped`/`n/a`) hands off to fg-learn; a `failed` result stops here and routes to fix-and-re-run or re-grill (it must **never** reach fg-learn). **Do not rebuild or re-execute the workflow** during the resume itself — no new subagents, no duplicate commits/migrations/side effects. Close with the handoff table for whichever outcome occurred (see "Early-exit handoffs" below).
- **`verified: failed`** → the UAT already ran and found the result broken. This is **not** a confirmation re-run: either apply a fix and then deliberately re-run (a genuine re-run — write a fresh `run.md` and re-verify), or re-grill via fg-ask to rework the plan. Do not silently re-execute, and do not treat it as an interrupted UAT to merely re-confirm. Close with the handoff table naming that route (see "Early-exit handoffs" below).
- **`verified:` is a sealable value** (`yes`/`skipped`/`n/a`) → the run was already verified, so this is a genuine duplicate-run request. Announce the duplicate run and get user confirmation. Distinguish whether the user wants to "continue/retry" or merely wants to see the results. Do not overwrite without confirmation. However, **if this is a re-run after plan.md was updated through an fg-ask re-grilling, this warning is the normal path** — once the user approves, proceed with the updated plan and write a fresh `run.md`.

**5) Failed parked-task recovery (unpark).** fg-run is the **single owner** of returning a `failed` task to execution, because it is the only stage that runs work — fg-learn and fg-done both *block* `failed`, and fg-run otherwise reaches only the active slot/backlog, never `executed/`. So if a parked `.forge/executed/<slug>/STATUS.md` carries `verified: failed` (a task whose cleanup-time or learn-time recovery UAT recorded `failed` — Run-all itself never parks a failed task; it leaves it in the active slot, see RUN-ALL.md), **unpark it before working on it** — but only when the active slot is free. If the slot is occupied, do not unpark: tell the user the parked failed task waits in `executed/` until the active task's loop finishes (verify → learn → seal via fg-done), after which re-entering fg-run with an empty slot surfaces it automatically as the top recovery candidate (step 2) — close that report with the handoff table (see "Early-exit handoffs" below). When the slot is free, move `executed/<slug>/{plan,run,STATUS}` → `.forge/{plan,run,STATUS}.md`, then enter step 4 above (its `verified: failed` branch routes to fix-and-re-run, or re-grill via fg-ask). This is the documented exit from a parked failure; fg-learn/fg-done/fg-status point here for it.

**Early-exit handoffs.** Every branch above that ends the turn **without** handing off to the retro — 0 candidates, the verification-only resume, `verified: failed`, a blocked unpark, a duplicate run the user cancels — closes by **rendering the handoff table**, whose shape is defined once in [`../fg-next/HANDOFF.md`](../fg-next/HANDOFF.md) (or `${CLAUDE_PLUGIN_ROOT}/skills/fg-next/HANDOFF.md`); reference it, never restate the layout here. Fill the cells from that branch's own routing, render it in the user's language, and keep it **statement form** — it is text output, never an `AskUserQuestion`, and `Alternative` states that another route exists rather than asking which to take (ADR-0015). The step-2 selection of a backlog task (2+ candidates) is **not** a handoff — it is a deliberately retained menu and keeps its `AskUserQuestion`. Where the cells genuinely differ:

- **0 candidates (step 2) · cancelled duplicate run (step 4)** — nothing is in progress, so `Next step` is fg-ask (define the task, grill it, produce a plan); there is no second route, so omit `Alternative`.
- **Verification-only resume (step 4) — one table per outcome, never one table covering both.** On a **sealable** outcome (`yes`/`skipped`/`n/a`): `Just did` = the interrupted UAT was completed and `verified:` recorded (nothing was re-executed), `Next step` = fg-learn, and the divergence rule in "Next-flow handoff" fills `Alternative` unchanged. On a **`failed`** outcome: `Next step` = fix-and-re-run via fg-run, `Alternative` = re-grill via fg-ask — and **no cell may name fg-learn or sealing** (ADR-0009: `failed` never reaches the retro).
- **`verified: failed` found by the re-run guard (step 4)** — the same table as the resume's `failed` outcome.
- **Blocked unpark (step 5)** — informational, so the table must not instruct the user to do the thing that is blocked: `Just did` = a parked `failed` task was found in `executed/` and waits until the slot frees, `Next step` = finish the **active** task's loop (which step that is — verify, retro, or seal — comes from fg-status's state machine, per HANDOFF.md's material table), `Alternative` = re-enter fg-run once the slot is empty, where the parked task surfaces as the top recovery candidate.

```
fg-run start
   │
   ▼
Active slot (.forge/plan.md) present?
   │ yes ──▶ run.md present?
   │            │ no  ──▶ Normal start: build the workflow
   │            │ yes ──▶ read STATUS verified:  (re-run guard, step 4)
   │                        • pending/missing ──▶ Verification-only resume (run UAT, set verified, NO re-execution)
   │                        │                       └─ UAT outcome:  sealable (yes/skipped/n/a) ──▶ hand off to fg-learn
   │                        │                                        failed ──▶ fix-and-re-run / re-grill (never fg-learn)
   │                        • failed ──▶ fix-and-re-run, or re-grill via fg-ask (no silent re-exec)
   │                        • sealable (yes/skipped/n/a) ──▶ Duplicate-run warning
   │                                                           └─ approved ──▶ build workflow │ cancel ──▶ stop, point to fg-ask
   │ no  ──▶ executed/ has a verified: failed task?  (step 2, before backlog)
   │            │ yes ──▶ Unpark to active slot ──▶ step 4 failed branch (fix-and-re-run / re-grill)
   │            │ no (or user declines) ──▶ Scan .forge/backlog/ → candidate count:
   │                                          • 0  ──▶ stop, point to fg-ask
   │                                          • 1  ──▶ promote backlog→plan.md (+ verify ADR exists) ──▶ build workflow
   │                                          • 2–3 ──▶ AskUserQuestion (plans + final Run all, ≤4 options)
   │                                          • 4+  ──▶ numbered text list (task/slug/list number/all)
   │                                                     └─ single choice ──▶ build workflow │ Run all ──▶ Run-all procedure (RUN-ALL.md)
```

## Behavior

### 1. Start the workflow

Right before starting, if `.forge/retro/` exists, pick **only the most recent 3–5** retros **from the same area as this plan's slug (overlapping slug stem/domain)** and skim their "Do differently next time" and "Divergences" (same selection rule as fg-ask — do not read them all) — so the same traps (e.g. "this migration breaks if run in parallel") are folded into slice decomposition, wave layout, and cost estimation up front. If there are no relevant retros, skip this. Retros are only a **reference** for building the workflow, not the source of truth for cross-verification (the source of truth is plan/CONTEXT.md/ADR, unchanged — see section 3 below).

Prompt Claude to build a Dynamic Workflow. Put the `workflow` keyword in the prompt, or raise effort to `ultracode`. Do not improvise the tasks to run — the **"Work slices" list in `.forge/plan.md` is the primary unit of work** (format: [PLAN-FORMAT.md](./PLAN-FORMAT.md)). It is fine for the workflow to split slices finer for execution convenience, but it must not drop a slice or trespass on the plan's "Non-goals." Where a dependency is noted (`depends: S1`), bundle into a serial wave; where there is none, bundle as parallelizable, and write the orchestration script accordingly. If the slices section is missing entirely (only a goal, no work decomposition), do not invent one and run it — point to fg-ask.

**TDD mode.** If the active plan carries `<!-- tdd: on -->` (set by fg-ask from `.forge/config.json`; see PLAN-FORMAT.md), compose the workflow **test-first**: for each work slice, write a failing test that pins its completion criterion **before** the implementation, then implement until that test passes — and treat "the slice's test exists and passes" as part of its completion criterion in §3. Describe this test-first discipline in the orchestration script yourself; if a TDD capability is available (e.g. a `superpowers:test-driven-development` skill) you may lean on it, but never hard-depend on one. If `tdd` is `off` or absent, run normally — no behavior change.

**Eco mode (delegated-agent efficiency).** Read `eco` from the **top-level** `.forge/config.json` (a global exemption — never the branch root; treat as `off` if the file or key is absent). If `true`, two behaviors activate for all workflow/execution subagents: **(1) model cap** — cap the subagent model at `sonnet` (e.g. `model: sonnet` on agent calls): only ever lowers, never raises; explicit user model instruction wins; **(2) Eco code-simplicity injection** — prepend the full contents of [`../fg-eco/ECO.md`](../fg-eco/ECO.md) to each subagent's prompt. Together these tier the loop as "strong = main session (design + grilling), efficient = delegated execution." **Beyond the subagents, when `eco` is `true` the main session running this skill also adopts ECO.md's output discipline for its own execution/reporting/handoff prose** (behavior 4 in fg-eco) — this is the only carrier on the **direct-execution path** (a small task handled here without a workflow), where there are no subagents to receive the injection. Toggle via the `fg-eco` utility; rationale in `.forge/adr/0014-fg-eco-subagent-model-tiering.md`. If `eco` is `false` or absent, no behavior change.

**Domain agents (project `.claude/agents/`).** If the project has domain agents under `.claude/agents/` (e.g. produced by the `fg-agents` utility), the workflow may run a slice through the matching one instead of the default subagent: pass `agentType: '<role>'` on the `agent()` call, picking the role whose card `description` ("when to use") fits the slice. This is graceful and optional — **if there are no domain agents, run exactly as before** (default workflow subagents; no behavior change); if a project would clearly benefit from a specialized role and has none, you may note in **one line** that `fg-agents` can generate them (then the session must restart before they're dispatchable — fact 1 below) — a pointer, never a dependency. Two hard facts (ADR-0024): **(1) only agents loaded at session start are dispatchable** — `.claude/agents/` is read once at startup, so a card created mid-session (e.g. by `fg-agents` just now) is NOT pickable until the session restarts; build against the agents present at this session's start, and if a needed card was just generated, tell the user to restart before it can be used. **(2) the agents are the user project's**, not forge's — fg-run only opens the call path, it does not define or require them (ADR-0013 non-conflict). **Eco interaction**: when `eco` is on, an `agentType` call is still capped at `sonnet` and still gets the ECO.md prepend like any delegated subagent — **except** when the role card declares its own `model:`, which is an explicit user choice and wins (eco only ever lowers). The existing script-approval gate (§2) is the safety net against dispatching an unrelated agent — the user sees "built the workflow with these agents, approve?".

### 2. Script approval → parallel execution

Once the orchestration script is ready, **get user approval first**. After approval, run it as background parallel subagents while this session keeps responding and receives progress. Observe progress with `/workflows`.

### 3. Cross-verify against the plan

`.forge/plan.md`, `CONTEXT.md`, and the ADRs in `.forge/adr/` are the source of truth. The workflow cross-verifies its output against this source of truth — it **judges each slice's "completion criterion" against the actual output** for satisfaction, rather than stopping at "it ran." This **plan-verification always runs** — it answers "did we build what the plan said," not "is the built code good." When the plan is in **TDD mode** (`tdd: on`), each slice's completion judgment additionally requires that its test exists and passes (see §1).

**Conditional code review (quality, not just spec).** For changes touching **risky areas (auth, data mutations, public API/contracts, migrations) or sizable** ones, add a **review phase** after implementation (before recording `run.md`); **skip trivial/low-risk changes** (same restraint as retro-skip). Compose it with the **workflow's own adversarial-verify subagents** (core `Agent`/`Workflow`, no external hard-dependency); fix real findings in-run and re-verify, and record any remaining critical findings in `run.md` as a divergence (it runs autonomously — no human input mid-run — surfacing at the handoff for fg-learn / re-grilling). Rationale + full procedure: `.forge/adr/0007-fg-run-conditional-code-review.md`.

### 4. Record divergences in run.md, then mark execution complete

When execution finishes, note "the divergences between plan and reality" in `.forge/run.md`. Write down what went as planned, what missed, the on-the-spot decisions made along the way, and where it got stuck. This is the raw material for the fg-learn retro.

**Record one line per work slice.** Alongside the prose, `run.md` MUST carry a per-slice result line keyed to the plan's `## Work slices` — the slice id, whether it landed, and the divergence in a few words:

```
- S1 {what it did} — ✅ as planned
- S2 {what it did} — ⚠ {the divergence, a few words}
```

This is **not** an eco-only concern: record it whether or not `eco` is on. It is the **material guarantee** for anything downstream that reports per-slice results — fg-done's seal summary already instructs "result per slice" (ADR-0032), and eco's summary table renders the slice rows (`../fg-eco/ECO.md`), but a later seal may happen in a **different session** where free prose is all that remains. Without these lines a reader would have to invent results, which is exactly the "instruction prose out of step with the actual contract" failure a retro already caught (`.forge/retro/2026-07-06-fg-done-seal-summary.md`). Keep the lines short — the prose below them carries the reasoning.

**Also record each DoD item's `baseline → after` values.** The baseline taken at promotion (step 3) paired with the value after execution is what makes the UAT's evidence checkable rather than asserted — `2 → 1` says more than `1`, and ADR-0009's seal gate rests on exactly that evidence. One line per DoD item, and for an item that was already passing at baseline, say so (an unchanged regression guard is the expected result, not a missing check).

Right after writing `run.md`, write a companion `STATUS.md` (in the user's language) to mark the run as executed — it travels alongside the plan/run files as a status marker, not a second ledger (the source of truth for state is still file location). In the single-task path, write it to `.forge/STATUS.md` (the active slot, next to plan.md/run.md). Content:

```
# STATUS — {title}
slug: {slug}
status: executed
executed: {YYYY-MM-DD}
verified: pending
retro: pending
```

The `retro:` field tracks the retro state of this task: `pending` at execution time, later either the retro path (`.forge/retro/YYMMDD-HHMMSS-<slug>.md`, filled by fg-done when sealing a retro'd task) or `skipped (<reason>)` when the retro was intentionally skipped (see the handoff below). fg-learn reads `status: executed` to confirm a parked task is awaiting retro, and skips a task already marked `retro: skipped`; fg-done later flips `status` to `done` and archives plan/run/STATUS together, accepting either a retro file or `retro: skipped` as satisfying its no-seal-without-retro guard. (The "Run all" path writes this STATUS to the active slot during execution+UAT too, then moves it into the per-task `executed/<slug>/` folder only on a sealable outcome — see that section.)

Flow: build the workflow → approve the script → background parallel execution → cross-verify against the plan → record `.forge/run.md` → write `.forge/STATUS.md` (status: executed) → **run the handoff UAT and set `verified:`** (see "Verify before handing off") → only then offer fg-learn

## "Run all" — execute-only batch

If the user picks "Run all" from the selection menu, **read [`RUN-ALL.md`](./RUN-ALL.md) (skill-relative `./RUN-ALL.md`) and follow it** — the execute-only batch procedure: confirm/freeze the order → per-task sequential execute → UAT → park sealable into `executed/` / leave `failed` in the active slot → fail-stop → batch handoff. It is split into that file — loaded only when "Run all" is actually chosen — for token efficiency on the common path; **behavior is unchanged** from when it lived inline. Run all is **execute-only** (it stops at the retro, parking each task in `executed/`); for the momentum superset that also drives verify → retro-skip → seal → promote-next, see `fg-next all` (`../fg-next/SKILL.md` / ADR-0010).

## Constraints

- **If a mid-run sign-off is needed**, that is a signal the task was actually two — split it into separate **tasks** (finish and seal everything up to the checkpoint as one loop, and open a new fg-ask for the rest as an fg-done follow-up). A Dynamic Workflow cannot take human input mid-runtime. Do not split one plan into phases and accumulate them into `run.md` — that conflicts with the re-run guard. Determine the split per the split rules in [PLAN-FORMAT.md](./PLAN-FORMAT.md).
- **Estimate cost first.** For a big job, trial a small slice to gauge token cost before scaling to the whole. If the scale is small enough for a single agent, skip the workflow and just handle it directly — that is cheaper and faster.
- **If the job will recur**, save the execution script as a `/command` (slash command) for reuse.
- **Eco mode activates two delegated-agent behaviors.** When `.forge/config.json` `eco` is on, workflow/execution subagents are capped at `sonnet` **and** receive Eco code-simplicity instructions (see §1) — it never changes this session's model, never raises a tier, and yields to an explicit user model instruction.
- Environment requirements: research preview · Claude Code v2.1.154+ · paid plan.

## Verify before handing off (UAT)

After execution and before pointing to fg-learn, **verify the result actually works** — plan-verification (§3) confirmed "we built what the plan said"; this confirms "it actually achieves the goal." The Dynamic Workflow can't take human input mid-run, but this handoff is conversational, so do the UAT here: against the plan's **goal / Definition of Done**, show what to check and ask the human to confirm it works (or report what's off). Record the outcome in the active-slot `.forge/STATUS.md` `verified:` (the "Run all" path also writes to the active-slot STATUS during UAT, then moves plan/run/STATUS to `.forge/executed/<slug>/` only on a sealable outcome — see that section):

Sealable outcomes:
- **`yes (<evidence>)`** — confirmed working, carrying a **one-line piece of evidence for how** it was confirmed — the command run / the output observed (e.g. `yes (npm test → 42 passing)`), the same shape as the `n/a`/`skipped` reason. Don't lean on "the human said so" alone; record what was actually checked. In **TDD mode** the passing slice tests *are* that one-line evidence (e.g. `yes (slice tests green)`) — no separate manual check needed. Keep it to one line — lightweight evidence, not a full command-output dump.
- **`skipped (<reason>)`** — verifiable but the user chose to skip (a deliberate, auditable waiver).
- **`n/a (<reason>)`** — nothing runnable to verify (e.g. a docs-only change — many of forge's own tasks).

Non-sealing outcome:
- **`failed (<reason>)`** — the UAT ran and the result does **not** achieve the goal. This is distinct from `pending` (which means the UAT never happened): `failed` records that verification was done and the work is broken. Write it so the state is durable and recovery is unambiguous — do not leave it as `pending` (that would look like an interrupted handoff) and do not paper over it with a `skipped` waiver. A `failed` task does not go to fg-learn or seal; route it to a fix-in-follow-up (then re-run → fresh `run.md` → re-verify) or re-grill via fg-ask. **A known-`failed` result has no waiver that seals it** — do not convert it to `skipped` to slip it through. It becomes sealable only when a fresh fix-and-re-run re-verifies it to `yes` or `n/a`.

fg-done will not seal unless `verified:` is one of the **sealable** outcomes (`yes`/`skipped`/`n/a`) — `pending` and `failed` both block (no-seal-without-verification guard).

## Next-flow handoff

When execution finishes, **render the handoff table** — its shape is defined once in [`../fg-next/HANDOFF.md`](../fg-next/HANDOFF.md) (or `${CLAUDE_PLUGIN_ROOT}/skills/fg-next/HANDOFF.md`); reference it, never restate the layout here. Render it in the user's language. Everything below is either a gate that must clear **before** you render it, or the material its cells carry.

**0. Verify first (mandatory gate).** Before offering the retro — i.e. before the table is rendered at all — complete the UAT above and record `verified:` (`yes`/`skipped`/`n/a`) in STATUS. **Do not route to fg-learn while `verified:` is still `pending`** — the loop order is run → verify → learn → done. Only once `verified:` is set do you proceed below.

**Eco: the eco summary table replaces the recap, not the handoff table.** If `eco` is `true` in the **top-level** `.forge/config.json` (the same read as §1), **replace** the what-just-happened material below with the single-task **eco summary table** — its shape is defined once in [`../fg-eco/ECO.md`](../fg-eco/ECO.md) (section "eco summary table"); reference it, do not restate the layout here. Nothing that material conveys may be dropped in the fold: the `verified:` value goes in the header (ADR-0009 — it is what tells the reader whether this can be sealed), the plan's Goal into `▸ Request`, and the per-slice results from `run.md`'s slice lines (§4) into `▸ Done`. The handoff table still follows it — how the two combine is HANDOFF.md's "Interaction with eco" (follow it; do not restate it here), which is what keeps the next step in the same place whether eco is on or off. Either way it stays **statement form**: no menu, no `AskUserQuestion`, no "shall I proceed?" — ADR-0015's 2026-06-15 amendment governs the tables exactly as it governed the prose. If `eco` is `false` or absent, the material below fills the handoff table unchanged.

**What I just did** — one line on what the workflow changed, and that the plan-vs-actual divergences were written to `.forge/run.md`.

**Optional adversarial review (before the retro).** As a one-line pointer **below the table** (a cell stays one line, and this is not a menu option), mention that if the user wants a hostile second look before sealing, they can run an adversarial review — `fg-adversarial-review` (outside the loop, never required): it assumes the result is wrong and hunts for evidence across six lenses, and any fix-needed finding becomes a fix-forward plan to run again. This is a one-line statement-form pointer, not a menu option (ADR-0015 amended 2026-06-15 — the fg-run handoff is now statement form), and `fg-next all`/`fg-loop` always skip it. See ADR-0018.

**The next step (statement form — no menu, no question; ADR-0015 amended 2026-06-15).** Like every other loop handoff, fg-run just **states** where things stand and stops — the table is text output, **never** an `AskUserQuestion` menu. (The menu re-triggered on the unchanged active-slot state — `executed`+`verified: sealable`+`retro: pending`+unsealed — and looped; statement form removes that whole failure mode. See ADR-0015's 2026-06-15 amendment.) The default next step is the **retro** — `fg-learn`; after it, `fg-done` seals. The triggers are `/forge:fg-learn`, plus `fg-next` (one-shot — runs the stated next step) or `fg-next all` (drives to the wall) to carry on in one move.

Then **stop** — do not ask "shall I proceed?" and do not auto-invoke fg-learn/fg-done (chaining is `fg-next`'s job — ADR-0015). The retro is still conducted conversationally by fg-learn when the user triggers it; "retro then seal in one go" is now done by `fg-next`, not an inline menu option.

**Divergence shapes the `Alternative` cell** — and, in the low-divergence case only, which route wins `Next step`. Read the plan-vs-actual divergence in `run.md` and take the **first case that applies**:

1. **High divergence** → `Next step` stays the retro, and `Alternative` is the **re-grill recommendation** (`fg-ask` before sealing); **omit the skip-and-seal alternative entirely** — plan and actual too far apart is exactly when there is something to learn (ADR-0002 gates the skip on divergence). This case **outranks `retro-hint: optional`**: the hint is fg-ask's pre-run guess and non-binding (PLAN-FORMAT.md), while divergence is evidence from the run that actually happened, so a hinted plan that diverged badly still leads with the retro.
2. **Low/negligible divergence (plan ≈ actual) and the plan carries `<!-- retro-hint: optional -->`** (fg-ask flagged it likely-trivial; see PLAN-FORMAT.md) → skip-and-seal **wins `Next step`**, displacing the default retro stated above: record `retro: skipped (<one-line reason>)` then seal with `fg-done` (the retro-skip guard, ADR-0002), `How to start` its trigger (`/forge:fg-done`), and `Alternative` = the retro (`fg-learn`). The hint changes **which case wins**, never the row order — the rows are fixed, so "lead with it" would be a no-op (HANDOFF.md). Both routes are still on screen and neither is auto-invoked, so the skip stays the human's choice (ADR-0002).
3. **Low/negligible divergence, no hint** → `Next step` stays the retro and `Alternative` is skipping it and sealing in one go — that path records `retro: skipped (<one-line reason>)` then `fg-done` (ADR-0002).

**Under fg-next.** fg-run cannot detect its caller, so it just **states** the next step and fg-next (as orchestrator) acts on it. `fg-next all` drives through automatically (auto-skip retro → seal, ADR-0010); one-shot `fg-next` runs the stated next step (one step, then hands back). For an odd job that crept in mid-run, point the user to handle it directly rather than cramming it into the workflow.

## Document impact

- Creates `.forge/run.md` — the note of plan-vs-actual divergences (retro input). Lazy creation.
- Creates `.forge/STATUS.md` (`status: executed`) right after `run.md` — a companion marker fg-learn/fg-done read; fg-done later flips it to `status: done` and archives it with plan/run.
- On backlog promotion, moves `.forge/backlog/<slug>.md` → `.forge/plan.md`. On "Run all" (procedure in `RUN-ALL.md`), creates per-task `.forge/executed/<slug>/{plan,run,STATUS}.md` (awaiting retro).
- (Optional) a saved workflow `/command` if the job recurs.
- Does not modify the `.forge/plan.md` it reads as input (the plan is fg-ask's property).

Format reference: when you need to handle permanent docs, read `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/CONTEXT-FORMAT.md`, `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/ADR-FORMAT.md` (plugin environment), or the same files at the skill-relative path `../fg-ask/` to match the format. The source of the format docs is the single fg-ask copy; this skill does not copy them itself.
