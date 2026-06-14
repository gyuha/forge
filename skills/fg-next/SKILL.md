---
name: fg-next
description: Derives the single next step of the forge loop (reusing fg-status's state machine) and actually runs it — it announces the step in one line then invokes that skill, rather than only reporting it (that is fg-status's job; fg-next acts and proceeds without waiting for a separate go-ahead). One-shot by default — it executes exactly one step and stops; the invoked skill's own handoff carries the loop forward from there. With the 'all' argument it instead drives backlog tasks to completion one after another until the backlog is empty, auto-progressing the linear mechanical steps (always auto-skipping retros) and halting at the conversational walls (failed/unverifiable UAT, a genuine fork, empty state). It writes nothing itself; every write happens inside the delegated skill. An on-demand orchestrator outside the loop — the entry point for cold re-entry ("I forget where I was — just do the next thing"). Use in contexts like 'forge next', '다음 단계', '이어서 해줘', '계속 진행', 'do the next step', 'fg-next all', 'forge next all', '다음 전부 진행'.
---

# fg-next — derive the next step, then act on it (outside the loop)

This is **not** a stage of the forge loop. It is the acting sibling of `fg-status`: where fg-status surveys `.forge/` and **reports** the single next step but deliberately never runs it, fg-next derives that same next step and **runs it** — it announces the step in one line and then actually invokes the skill, rather than stopping at the report. Its real value is **cold re-entry**: when you don't remember where a task stands, "forge next" figures out the one correct move and takes it.

By default it does **one step only** (one-shot). After that step, the invoked skill's own handoff carries the loop forward — so you rarely need fg-next twice in a row. (With the `all` argument it instead drives multiple steps to the wall — see "`all` mode" below.) It **writes nothing itself**: it reads state and delegates; every file write (plan/run/STATUS/backlog/done/retro/adr/quick) happens inside the skill it hands off to.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** The one-line next-step announcement (and any narrow fork question) is written in the user's language.

**Forge root**: every `.forge/...` path below (and fg-status's state machine it reuses) is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before deriving or acting (ADR-0011).

## How it works

### 1. Derive the next step (do not reimplement)

Perform the survey and the next-step derivation **exactly as `fg-status` does** — fg-status's "Deriving the next step (state machine)" section is the single source of truth for this logic (run → verify → learn → done priority, the `verified: failed`/`pending` branches, parked-`executed/` recovery, the empty-state case). Read it and follow it:

`${CLAUDE_PLUGIN_ROOT}/skills/fg-status/SKILL.md` (or the skill-relative path `../fg-status/SKILL.md`)

Do **not** duplicate or paraphrase that state machine here — if the loop changes, only fg-status's copy should move. fg-next adds only the **act** on top of fg-status's **derive**.

### 2. Announce, then proceed — actually invoke the skill

**The whole point of fg-next is to act, not merely report.** Reporting the next step and stopping is `fg-status`'s job — if fg-next only tells you where you are and waits, it has failed. So once you've derived the step: state it in one line (`다음은 <skill>입니다 — 진행합니다.`, in the user's language), then **invoke that skill via the Skill tool in the same turn.** Do **not** stop and wait for a separate "go ahead" — proceed.

- **fg-run / fg-done** (mechanical stages) → invoke the skill now to run that step.
- **fg-ask / fg-learn** (conversational stages) → invoke the skill now to **enter that conversation**; fg-next does not conduct the grilling/retro itself, but it does open it (the skill is interactive, so the human engages inside it — that is not fg-next stalling).

Then **stop** — one step, no chaining (one-shot). The invoked skill handles its own handoff.

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
   ├── yes ──▶ announce in one line ──▶ INVOKE the skill now (fg-run/fg-done run it; fg-ask/fg-learn open the conversation) ──▶ STOP (one-shot)
   └── no  ──▶ fork             ──▶ ask which option (needed choice) ──▶ invoke the chosen skill
              multiple backlog  ──▶ invoke fg-run (its menu makes the pick)
              everything empty  ──▶ invoke fg-ask to start a new task
```

## `all` mode — drive to the wall (multi-step momentum)

When invoked with the `all` argument (`fg-next all`, or "forge next all" / "다음 전부 진행"), fg-next does **not** stop after one step. It drives the loop forward — **promoting and running backlog tasks in turn until the backlog is empty** — auto-progressing the linear mechanical steps with their recommended answer, and **halting at the conversational walls** to hand back to the human. It is the momentum mode (see `.forge/adr/0010-fg-next-all-momentum-mode.md`); the default `fg-next` (no arg) is unchanged — still one-shot (announce → invoke one step → stop).

**If `.forge/loop.md` exists, all-mode does not drive.** A goal loop is in flight (or halted at a wall), and the state machine's step 0 already routes the next step to resuming fg-loop — which runs its own drive over its own member tasks. Driving all-mode in parallel would double-promote backlog work; so announce in one line that a goal loop owns the drive and delegate to fg-loop (the same announce-then-invoke as the one-shot path), instead of starting the all-mode sweep.

**This is not unattended full-automation.** Pillar #1 holds: all-mode never *conducts* a grilling or a retro conversation autonomously. It automates only the non-conversational decisions and stops the moment a step genuinely needs a human.

### Entry: one confirmation, then unattended

Before driving, snapshot and **freeze** the current backlog order (priority `high → medium → low`, no marker = `medium`, ties by slug — same sort as fg-run's menu) and show it once, with a one-line note of what will auto-run and where it will halt. Get a single go-ahead. After that, drive without per-step confirmation — this one upfront gate is what preserves the re-run-prevention discipline (same pattern as fg-run "Run all" step 1).

### The drive loop

Repeat: derive the next step (**via fg-status's state machine, exactly as in section 1 — never reimplemented**), then act:

- **Linear mechanical step** → auto-progress with the recommended answer: run a plan, record an `n/a`/auto-verified `yes` outcome, **always auto-skip the retro** (record `retro: skipped (fg-next all 자동 진행 — 학습은 run.md, 승급은 추후 fg-learn)`; the learnings stay in the archived run.md and promotion is deferred to a later human fg-learn — **the write itself happens inside the delegated done stage**: fg-done records the `retro: skipped` into STATUS via its cleanup-time skip path as it closes out the seal, consistent with "fg-next writes nothing itself"; ADR-0015 amended), run the done stage to seal, promote the next backlog task. No question asked. (The optional adversarial review — `fg-adversarial-review`, ADR-0018 — is **never** run in a drive: it needs a human to judge which findings are real and worth fixing, so all-mode skips it the same way it skips the retro.)
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

`fg-next all` already drives task→task until a wall or empty state, but a genuine turn boundary mid-drive — most often an **fg-run workflow script approval**, or any pause — ends the turn, and normally you'd re-issue `fg-next all` to resume. To run **fully unattended until the backlog is empty**, pair it with the harness's `/goal` (a session-scoped Stop hook that blocks stopping until its condition holds): set the goal, then run `fg-next all`, and the drive auto-resumes across turn boundaries until there is nothing left to auto-progress.

- **This skill cannot set `/goal` itself** — `/goal` is a harness slash command the **user** types; a skill has no tool to engage it. So this is a usage pattern you invoke, not something `fg-next all` turns on automatically.
- **Phrase the goal condition as "when may I stop", and make it release at the walls.** The Stop hook keeps the drive going until its condition is met, so the condition must describe the *stopping* points — which are exactly two: (1) **empty state** (active slot + backlog + `executed/` all empty — the run is complete), or (2) a **human-needed wall**: `verified: failed`, an unverifiable UAT (can't reach a sealable value), a genuine fork, **or an fg-run workflow script approval**. Recommended wording (write it in the user's language):

  > *"Keep running `fg-next all` until there is nothing left to auto-progress. Stopping is allowed only when: (1) the backlog, active slot, and executed/ are all empty (done); or (2) it hits a point that needs me — `verified: failed`, an unverifiable UAT, a genuine fork, or a workflow script approval. Everything else (run · verify-pass · auto-skip retro · seal · promote next) — keep going, don't stop."*

- **Do NOT phrase it as "until the backlog is empty" alone.** That makes the hook block stopping *even at a safety wall*, forcing the drive past gates it must hand to a human — auto fix-and-re-run, sealing unverified work, auto-picking a fork. Those are exactly what ADR-0009 / ADR-0010 forbid. The condition must let the agent stop at a wall; the human resolves it, then re-issues `fg-next all` (the goal, still active, resumes the drive).
- **Safety walls and the default one-shot are unchanged.** `/goal` only automates the *stateless resume* a human would otherwise type by hand; it changes none of fg-next's logic. The four halt conditions still halt, and the no-arg `fg-next` is still one-shot.

### Relationship to fg-run "Run all"

fg-run's "Run all" is **execute-only** — it runs the backlog, UAT-verifies, parks each task in `executed/`, and **stops at the retro** (retro is conversational). `fg-next all` is the **superset**: it drives through verify → retro-skip (always) → done → promote-next, sealing tasks as it goes, and only halts at the walls above. They coexist; pick Run all for a batch execute, `fg-next all` to drive whole loops to completion.

## Handoff

fg-next's handoff **is** the step it invoked — once it delegates, the invoked skill's own next-flow handoff takes over (fg-run ends in its 4-way handoff menu — ADR-0015 amended; fg-learn points to fg-done, and so on). fg-next adds nothing after that; it does not re-derive or chain. If the user wants the following step too, they say "forge next" again (or follow the skill's own handoff prompt).

fg-next proceeds by default — it does not wait for permission. Only if the user explicitly says "just tell me, don't act" (or similar) do you fall back to fg-status behavior: state the next step and its trigger, write nothing, and stop.

## Document impact

- **None directly.** fg-next itself creates and modifies nothing — it reads `.forge/` to derive the step and delegates the action. Any document change is made by the skill it invokes (fg-run/fg-learn/fg-done/fg-ask), under that skill's own rules.
