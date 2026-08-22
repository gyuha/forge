---
name: fg-next
description: Derives the single next step of the forge loop (reusing fg-status's state machine) and runs it — announces the step, then invokes that skill (fg-status reports; fg-next acts). One-shot by default; with the 'all' argument it drives the backlog to completion, auto-skipping retros and halting at the walls (failed/unverifiable UAT, a genuine fork, empty state). The cold-re-entry entry point. Use in contexts like 'forge next', '다음 단계', '이어서 해줘', '계속 진행', 'fg-next all', '다음 전부 진행'.
---

# fg-next — derive the next step, then act on it (outside the loop)

This is **not** a stage of the forge loop. It is the acting sibling of `fg-status`: where fg-status surveys `.forge/` and **reports** the single next step but deliberately never runs it, fg-next derives that same next step and **runs it** — it announces the step in one line and then actually invokes the skill, rather than stopping at the report. Its real value is **cold re-entry**: when you don't remember where a task stands, "forge next" figures out the one correct move and takes it.

By default it does **one step only** (one-shot). After that step, the invoked skill's own handoff carries the loop forward — so you rarely need fg-next twice in a row. **One exception:** when that step is a retro (fg-learn) and it concludes normally (no re-grill recommended), fg-next continues in the same call through to sealing (fg-done) — see "Learn → done follow-through" below (ADR-0026). (With the `all` argument it instead drives multiple steps to the wall — see "`all` mode" below.) It **writes nothing itself**: it reads state and delegates; every file write (plan/run/STATUS/backlog/done/retro/adr/quick) happens inside the skill it hands off to.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** The one-line next-step announcement (and any narrow fork question) is written in the user's language.

**Forge root**: every `.forge/...` path below (and fg-status's state machine it reuses) is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before deriving or acting (ADR-0011).

## How it works

### 1. Derive the next step (do not reimplement)

Perform the survey and the next-step derivation **exactly as `fg-status` does** — fg-status's "Deriving the next step (state machine)" section is the single source of truth for this logic (run → verify → learn → done priority, the `verified: failed`/`pending` branches, parked-`executed/` recovery, the empty-state case). Read it and follow it:

`${CLAUDE_PLUGIN_ROOT}/skills/fg-status/SKILL.md` (or the skill-relative path `../fg-status/SKILL.md`)

Do **not** duplicate or paraphrase that state machine here — if the loop changes, only fg-status's copy should move. fg-next adds only the **act** on top of fg-status's **derive**.

### 2. Announce, then proceed — actually invoke the skill

**The whole point of fg-next is to act, not merely report.** Reporting the next step and stopping is `fg-status`'s job — if fg-next only tells you where you are and waits, it has failed. So once you've derived the step: state it in one line (`Next: <skill> — proceeding.`, rendered in the user's language), then **invoke that skill via the Skill tool in the same turn.** Do **not** stop and wait for a separate "go ahead" — proceed.

- **fg-run / fg-done** (mechanical stages) → invoke the skill now to run that step. **When the step is `fg-done` (a seal delegated by fg-next — e.g. the retro was already satisfied in a prior turn, so the derived next step is fg-done directly, not via the autochain below), keep the seal terse: it is an orchestrator-delegated seal, so fg-done must **not** render the explicit-single-seal summary chapter (ADR-0032) — that summary is for a human's bare `/fg-done` only.** When `eco` is on, "terse" means **one row** of the batch eco summary table rather than a prose notice — the rule and its shape live in [DRIVE.md](./DRIVE.md) Part 1 and `../fg-eco/ECO.md`; do not restate them here.
- **fg-ask / fg-learn** (conversational stages) → invoke the skill now to **enter that conversation**; fg-next does not conduct the grilling/retro itself, but it does open it (the skill is interactive, so the human engages inside it — that is not fg-next stalling). **`all` mode is the exception for a derived `fg-learn` retro step: it does NOT invoke or announce fg-learn — it auto-skips the retro and seals (see "`all` mode" below). Invoking or announcing "run fg-learn" inside an `all` drive is the "keeps telling me to run fg-learn, never seals" bug.**

Then **stop** — one step, no chaining (one-shot), with **one exception** — see "Learn → done follow-through" right below.

### Learn → done follow-through (the one exception to one-shot)

When the step just invoked was **fg-learn** (a retro), don't stop at "the invoked skill handles its own handoff" as usual. Instead, watch how that retro concluded:

- **The retro concluded normally** (it did *not* recommend re-grilling via fg-ask — the only off-ramp fg-learn's own handoff has) → **continue in the same call**: derive the next step again (it will now be `fg-done` for this same task) and invoke it too, exactly as in section 2 above — announce it in one line ("the retro concluded normally — continuing through to fg-done", in the user's language), then invoke, no separate confirmation. If `.forge/executed/` still has other tasks awaiting retro, mention the remaining count in **one line** alongside fg-done's own completion notice — this does not block sealing the task just retro'd. **The fg-done seal reached this way is a *delegated* seal — keep it terse (fg-done's completion notice), never the explicit-single-seal summary chapter (ADR-0032); the summary is for a human's bare `/fg-done` only, and here the retro conversation just happened, so a summary would duplicate it.** With `eco` on, that terse notice is one table row instead of prose ([DRIVE.md](./DRIVE.md) Part 1) — still never the summary chapter.
- **The retro recommended re-grilling** (high divergence) → **stop here**, same as every other one-shot step. Do not invoke fg-done — the task needs fg-ask rework, not a seal.

This is the **only** place fg-next chains two skill invocations in one no-arg call — every other step (run, done, ask) still stops after one invocation. The reasoning: once a retro concludes without a re-grill recommendation, fg-done's own guards (verification + retro) are already guaranteed to pass — there is no fork left to ask about, so stopping here would just cost the user a second "forge next" for no decision gained. `fg-learn`/`fg-done` themselves are unchanged — invoking `/forge:fg-learn` (or "forge learn") directly still states "next: fg-done" and stops, per their own statement-form handoff. `fg-next all` is unaffected — it already unconditionally skips the retro conversation and seals within its own drive loop. See `.forge/adr/0026-fg-next-learn-done-autochain.md`.

**Re-run safety does not require a confirmation gate here** — it is already guaranteed by the skills fg-next invokes: fg-run's re-run guard refuses to re-run a plan that already has a `run.md`, and fg-done only seals (and empties active state) when the guards pass. fg-next therefore proceeds without a separate stop. The only times it pauses are when the step genuinely needs human input it cannot supply (section 3) — that is missing information, not a confirmation gate.

### 3. Stay shallow — delegate ambiguity to the named skill

fg-next proceeds on its own for a single unambiguous step (section 2). It pauses **only** when the step genuinely needs human input it cannot supply — and even then it does the most it can, then asks the narrow question:

- **Fork** (e.g. `verified: failed` → fg-run fix-and-re-run **or** fg-ask re-grill) → fg-next can't pick a consequential branch for you. Present the two options and ask which; on the answer, invoke the chosen skill. (This is a needed choice, not a "shall I proceed?" gate.)
- **Multiple unexecuted backlog plans** → don't choose for them. Just **invoke fg-run** — its own priority-sorted selection menu makes the pick. (fg-next still proceeds; fg-run owns the menu.)
- **Everything empty** (active slot + backlog + `executed/` all empty) → there is no step to continue, and a new task's content is the user's to supply. State "no work in progress" and invoke **fg-ask** to start one (fg-ask asks what to work on). fg-next never invents a task.

```
forge next
   │
   ▼
Derive next step  ── follow fg-status's "Deriving the next step" state machine (reference, not reimplemented)
   │
   ▼
Single unambiguous step?
   ├── yes ──▶ announce in one line ──▶ INVOKE the skill now
   │             ├── fg-run / fg-done / fg-ask ──▶ STOP (one-shot)
   │             └── fg-learn ──▶ retro concludes:
   │                                 ├── recommends re-grill ──▶ STOP (one-shot, as usual)
   │                                 └── concludes normally ──▶ derive again (now fg-done) ──▶ announce ──▶ INVOKE fg-done ──▶ STOP
   │                                     (the one exception — ADR-0026)
   └── no  ──▶ fork             ──▶ ask which option (needed choice) ──▶ invoke the chosen skill
              multiple backlog  ──▶ invoke fg-run (its menu makes the pick)
              everything empty  ──▶ invoke fg-ask to start a new task
```

## `all` mode — drive to the wall (multi-step momentum)

When invoked with the `all` argument (`fg-next all`, or "forge next all" / "다음 전부 진행"), fg-next does **not** stop after one step. It drives the loop forward — **promoting and running backlog tasks in turn until the backlog is empty** — auto-progressing the linear mechanical steps with their recommended answer, and **halting at the conversational walls** to hand back to the human. It is the momentum mode (see `.forge/adr/0010-fg-next-all-momentum-mode.md`); the default `fg-next` (no arg) is unchanged — still one-shot per task, with only the one learn→done exception above (ADR-0026), never a multi-task drive.

**If `.forge/loop.md` exists, all-mode does not drive.** A goal loop is in flight (or halted at a wall), and the state machine's step 0 already routes the next step to resuming fg-loop — which runs its own drive over its own member tasks. Driving all-mode in parallel would double-promote backlog work; so announce in one line that a goal loop owns the drive and delegate to fg-loop (the same announce-then-invoke as the one-shot path), instead of starting the all-mode sweep.

**This is not unattended full-automation.** Pillar #1 holds: all-mode never *conducts* a grilling or a retro conversation autonomously. It automates only the non-conversational decisions and stops the moment a step genuinely needs a human.

### Entry: the `/goal` paste is the primary path (it doubles as the confirmation)

Before driving, snapshot the **entire current drive set**, not just new backlog work: show the active slot and `executed/` tasks first (including each `verified:` state and that sealable tasks will have their retro auto-skipped and be sealed), then **freeze** the backlog order (priority `high → medium → low`, no marker = `medium`, ties by part/slug — same sort as fg-run's menu). A failed/unverifiable active or parked task is shown as the wall where the drive will halt, not as a seal target. This one list is the user's informed view of every task the invocation may mutate; omitting already-executed work would auto-waive its retro without disclosure. Then present the **paste-ready `/goal` line as the primary path to unattended operation** (built from fg-next all's stop-allowed set below — see "Unattended to completion"), and make the two ways forward explicit: **paste that `/goal` line to run unattended, or reply "go" (or just proceed) to drive step-at-a-time**. Either one is the single upfront go-ahead that preserves the re-run-prevention discipline (same one-gate pattern as fg-run "Run all") — the deliberate `/goal` paste (or the "go") *is* the confirmation, so there is no separate double gate. After that, drive without per-step confirmation.

**Write the drive marker at entry — this is what makes the drive continue without `/goal` (ADR-0028 amended 2026-08-22).** Right after the go-ahead, write `<forge-root>/drive.md`:

```
# DRIVE — unattended drive in progress
started: {epoch seconds}          # epoch, not ISO: `date -d` (GNU) vs `date -j -f` (BSD) is a portability trap
blocked: 0                        # bumped by the Stop hook, never by you
session: {this session's id}      # so this drive never blocks another session's turn
```

forge ships a **`Stop` hook** (`hooks/hooks.json` → `scripts/forge-hook-stop.sh`/`.js`) that, while this marker exists and is inside its bounds, returns `exit 2` and so **prevents the turn from ending** — the same mechanism `/goal` uses, but shipped by the plugin so no user action is needed. `/goal` remains a **fallback** (see [DRIVE.md](./DRIVE.md) Part 2).

**Deleting the marker is how you say "I may stop now" — the hook never judges walls.** Delete `<forge-root>/drive.md` at **every** exit from the drive, without exception:

- all four halt conditions below (`verified: failed` · unverifiable UAT · a genuine fork · empty state),
- the normal terminal state (the backlog drained — this is halt condition 4),
- and **before yielding for anything a human must physically do**, above all a **workflow script approval**: the approval is not a Stop event, but if the model does end the turn while waiting, a live marker would block it and the drive would spin against a gate only the human can open.

The marker is bounded (30 min · 50 blocked stops) so a session that dies mid-drive cannot wedge the next one, and every failure path in the hook allows stopping. Those bounds are the **only** runaway guard — the harness provides no loop protection for Stop hooks — so treat a forgotten deletion as a real defect, not a cosmetic one.

### The drive loop

**Continue within the turn — do not yield on a delegated skill's stated stop (see [DRIVE.md](./DRIVE.md) Part 1).** fg-run/fg-done end in statement-form handoffs (ADR-0015) that state the next step and stop; those are written for a human caller, but in a drive **the orchestrator is the caller**, so the moment a delegated step completes, immediately derive the next step and act — sealing one task is **not** a stopping point, and you do **not** end the turn between task loops. The only legitimate ends of a turn are empty state (halt condition 4) and a wall. (No repeat-menu risk: the drive advances on changing state — sealed task leaves the slot, next is promoted — so unlike the ADR-0015 menu bug it never loops on unchanged state.)

Repeat: derive the next step (**via fg-status's state machine, exactly as in section 1 — never reimplemented**), then act:

**Translate the derived step into the `all`-mode action — do not act on the literal step name.** The state machine is mode-agnostic, so on a retro-owed task (executed · `verified:` sealable · retro pending) it derives the literal step **`fg-learn`**. In `all` mode you must **NOT** invoke fg-learn and must **NOT** announce "run fg-learn" to the user — that is one-shot `fg-next`'s behavior, and doing it in a drive is the "keeps telling me to run fg-learn, never seals" bug this mode exists to prevent (re-issuing the drive on the unchanged learn-stage state just repeats it). A derived `fg-learn` maps to **auto-skip the retro and seal** — go straight to the done stage with the retro skipped (the "Linear mechanical step" below). **This override beats §2's "invoke the conversational skill" rule for the retro step.** (Same when a delegated fg-run's statement-form handoff *states* "next: fg-learn" — do not relay it; continue to skip + seal, per [DRIVE.md](./DRIVE.md) Part 1.)

- **Linear mechanical step** → auto-progress with the recommended answer: run a plan, record an `n/a`/auto-verified `yes` outcome, **always auto-skip the retro** (record `retro: skipped (fg-next all auto-drive — learnings stay in run.md, promotion deferred to a later fg-learn)`, written in the user's language; the learnings stay in the archived run.md and promotion is deferred to a later human fg-learn — **the write itself happens inside the delegated done stage**: fg-done records the `retro: skipped` into STATUS as it closes out the seal — now by passing `--skip-retro` to the deterministic seal script `forge-done.sh`/`.js` (ADR-0030), so it stays consistent with "fg-next writes nothing itself"; ADR-0015 amended), run the done stage to seal, promote the next backlog task. No question asked. (The optional adversarial review — `fg-adversarial-review`, ADR-0018 — is **never** run in a drive: it needs a human to judge which findings are real and worth fixing, so all-mode skips it the same way it skips the retro.)
- **Halt condition** → stop the drive, report where it stopped, why, and the trigger to resume. Resume is **stateless**: the human resolves the wall, then re-issues `fg-next all` to keep draining.

### Halt conditions (hand back to the human)

Stop the drive and report at any of these — everything else auto-progresses:

1. **`verified: failed`** — the UAT found the result broken. Never auto fix-and-re-run (infinite-loop / unintended-change / waiver risk; ADR-0009) — halt.
2. **UAT can't reach a sealable value** — verify is attempted **aggressively** (run whatever tests/grep/build the agent can and record `yes (<evidence>)` or `n/a`), but if it can't reach a sealable value (`pending`), halt rather than seal unverified.
3. **A genuine fork** — e.g. `failed` → fix-and-re-run *or* re-grill. Don't auto-pick a consequential branch → halt.
4. **Empty state** — active slot + backlog + `executed/` all empty. There's no step to continue; a new task needs human-supplied content (fg-ask grilling) → halt (this is the normal terminal state — "all done").

**A retro is never a halt in all-mode** — it is *always* auto-skipped (recorded as `retro: skipped`, see the drive loop), regardless of divergence. The "always skip retro / halt only at high-divergence" policy was tried and removed: forge-meta work is almost all high-divergence, so halting on it stalled the drive on nearly every task and erased the value of "keep going" — learnings are preserved in the archived run.md and promoted later by a human fg-learn (ADR-0010, amended 2026-06-08). The default one-shot `fg-next` is unchanged — when its single next step is a retro, it opens fg-learn for the human to conduct conversationally; only `all` mode auto-skips.

```
fg-next all
   │
   ▼
Freeze backlog order, show it once, get ONE go-ahead
   │
   ▼
┌─▶ Derive next step (fg-status state machine)
│      │
│      ├── linear mechanical (run · n/a/auto-yes verify · retro skip [always] · done · promote next) ──▶ auto-progress ─┐
│      └── halt condition (failed · unverifiable · genuine fork · empty) ──▶ STOP, report, await human
│                                                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Unattended to completion — pairing with `/goal`

Crossing a genuine turn boundary (a background workflow running async, a script approval, or the model yielding despite the within-turn discipline above) needs the harness `/goal`. The **mechanism** — a session-scoped Stop hook; the **"a skill cannot set `/goal` itself"** constraint; the **phrasing rule**; and the **honest no-`/goal` fallback** (without it, one cycle then the turn ends — expected, re-issue `fg-next all` to resume) — all live in [DRIVE.md](./DRIVE.md) Part 2, shared with fg-loop. Read it; the `/goal` pairing is the operating premise of an unattended `all` drive, not an optional aside.

**fg-next all's stop-allowed set** (fill DRIVE.md's phrasing rule with *these* walls — not fg-loop's): (1) **empty state** — backlog + active slot + `executed/` all empty (done); or (2) a **human-needed wall** — `verified: failed`, an unverifiable UAT (can't reach a sealable value), a genuine fork, or a workflow script approval. Everything else (run · verify-pass · auto-skip retro · seal · promote next) keeps going. Recommended paste-ready shape (render in the user's language):

> *"Keep running `fg-next all` until there is nothing left to auto-progress. Stopping is allowed only when: (1) the backlog, active slot, and executed/ are all empty (done); or (2) it hits a point that needs me — `verified: failed`, an unverifiable UAT, a genuine fork, or a workflow script approval. Everything else — keep going, don't stop."*

The four halt conditions still halt, and the no-arg `fg-next` is unchanged — still one-shot per task (learn→done follow-through aside, ADR-0026).

### Relationship to fg-run "Run all"

fg-run's "Run all" is **execute-only** — it runs the backlog, UAT-verifies, parks each task in `executed/`, and **stops at the retro** (retro is conversational). `fg-next all` is the **superset**: it drives through verify → retro-skip (always) → done → promote-next, sealing tasks as it goes, and only halts at the walls above. They coexist; pick Run all for a batch execute, `fg-next all` to drive whole loops to completion.

## Handoff

fg-next's handoff **is** the step it invoked — once it delegates, the invoked skill's own next-flow handoff takes over (fg-run ends in its statement-form handoff — ADR-0015 amended 2026-06-15, the old 4-way menu dropped; fg-learn points to fg-done, and so on). fg-next adds nothing after that and does not re-derive or chain — **except** the one learn→done follow-through above (ADR-0026), where fg-next itself re-derives once and invokes fg-done in the same call. Outside that one case, if the user wants the following step too, they say "forge next" again (or follow the skill's own handoff prompt).

**One table per step — never two for the same step.** Its shape is defined once in [`./HANDOFF.md`](./HANDOFF.md); never restate that layout. A delegated skill cannot detect its caller, so **who renders is fg-next's decision to enforce: instruct each step you invoke whether to render its table.**

- **One-shot** → the invoked step renders its own table (a human is reading it) and fg-next adds nothing after it. fg-next's one-line announcements (`Next: … — proceeding`) are announcements, not handoffs.
- **One-shot learn→done chain (ADR-0026)** → **only the last step renders.** Instruct fg-learn not to render; fg-done's table is the one table for the chain. Otherwise fg-learn states `Next step: fg-done · How to start: /forge:fg-done`, fg-next seals immediately after, and the user is left holding a live trigger for work already done — typing that trigger would hit fg-done on empty state.
- **`all` mode** → **no delegated table reaches the user.** Instruct every step you invoke not to render, and render one table yourself for **fg-next's own step**: the wall it halted at, or the drive's completion (empty state). This is the same active suppression fg-next already applies to the delegated seal summary (ADR-0032), and it is what [DRIVE.md](./DRIVE.md) Part 1 requires — a relayed `Next step: fg-learn` row *is* the "keeps telling me to run fg-learn, never seals" stall, and a table reads as an instruction, so relaying one is worse than relaying the prose was.

fg-next proceeds by default — it does not wait for permission. Only if the user explicitly says "just tell me, don't act" (or similar) do you fall back to fg-status behavior: state the next step and its trigger as the handoff table (`./HANDOFF.md`, as fg-status fills it), write nothing, and stop.

## Document impact

- **None directly.** fg-next itself creates and modifies nothing — it reads `.forge/` to derive the step and delegates the action. Any document change is made by the skill it invokes (fg-run/fg-learn/fg-done/fg-ask), under that skill's own rules.
