# `all` mode — drive to the wall (multi-step momentum)

> Loaded by `fg-next` **only when the `all` argument is actually given**. The one-shot path never reads this file.
> Split out of `SKILL.md` for token efficiency on the common path; **behavior is unchanged** from when it lived inline.

When invoked with the `all` argument (`fg-next all`, or "forge next all" / "다음 전부 진행"), fg-next does **not** stop after one step. It drives the loop forward — **promoting and running backlog tasks in turn until the backlog is empty** — auto-progressing the linear mechanical steps with their recommended answer, and **halting at the conversational walls** to hand back to the human. It is the momentum mode (see `.forge/adr/0010-fg-next-all-momentum-mode.md`); the default `fg-next` (no arg) is unchanged — still one-shot per task, with only the one learn→done exception described in [`SKILL.md`](./SKILL.md)'s "How it works" (ADR-0026), never a multi-task drive.

**If `.forge/loop.md` exists, all-mode does not start its own drive.** Follow fg-status step 0 in both one-shot and all-mode: an unresolved wall without new evidence or a resolving decision calls for the specific missing input, not automatic delegation. When a decision, relevant change, or explicit recheck request is present (or no wall is set), delegate to fg-loop's resume preflight, which owns contract updates and the membership-filtered drive. Do not mutate loop.md here or demand a second approval.

**This is not unattended full-automation.** Pillar #1 holds: all-mode never *conducts* a grilling or a retro conversation autonomously. It automates only the non-conversational decisions and stops the moment a step genuinely needs a human.

### Entry: disclose the drive set once

Before driving, snapshot the **entire current drive set**, not just new backlog work (and, when `driveCommit` is on, the working-tree state that decides whether this drive commits per task — [DRIVE.md](./DRIVE.md) Part 3): show the active slot and `executed/` tasks first (including each `verified:` state and that sealable tasks will have their retro auto-skipped and be sealed), then **freeze** the backlog order (priority `high → medium → low`, no marker = `medium`, ties by part/slug — same sort as fg-run's menu). A failed/unverifiable active or parked task is shown as the wall where the drive will halt, not as a seal target. This one list is the user's informed view of every task the invocation may mutate; omitting already-executed work would auto-waive its retro without disclosure. The invocation authorizes this disclosed drive; ask only if the snapshot exposes a genuine unresolved scope or safety decision. Continue without another generic go-ahead. Select the continuation mechanism and any `/goal` fallback under DRIVE.md Part 2; do not repeat that fallback after it has already been explained or while blocked.

**Write the drive marker at entry when `prevent_stop` is `true` — this is what makes the drive continue without `/goal` (ADR-0028 amended 2026-08-22).** The discriminator is the host capability: with `prevent_stop` `false` **or the host unknown**, do **not** write the marker and do not imply continuous execution — the drive is turn-bounded ([DRIVE.md](./DRIVE.md) Part 2, which owns this mechanism). Otherwise, right after the go-ahead, write `<forge-root>/drive.md`:

```
# DRIVE — unattended drive in progress
started: {epoch seconds}          # epoch, not ISO: `date -d` (GNU) vs `date -j -f` (BSD) is a portability trap
blocked: 0                        # bumped by the Stop hook, never by you
session: {this session's id}      # so this drive never blocks another session's turn
```

forge ships a **`Stop` hook** (`hooks/hooks.json` → `scripts/forge-hook-stop.sh`/`.js`) that, while this marker exists and is inside its bounds, returns `exit 2` and so **prevents the turn from ending** — the same mechanism `/goal` uses, but shipped by the plugin so no user action is needed. `/goal` remains a **fallback** (see [DRIVE.md](./DRIVE.md) Part 2).

**Deleting the marker is how you say "I may stop now" — the hook never judges walls.** Delete `<forge-root>/drive.md` at **every** exit from the drive, without exception:

- all five halt conditions below (`verified: failed` · unverifiable UAT · a genuine fork · empty state · an uncollectable in-flight marker),
- the normal terminal state (the backlog drained — this is halt condition 4),
- and **before yielding for anything a human must physically do**, above all a **workflow script approval**: the approval is not a Stop event, but if the model does end the turn while waiting, a live marker would block it and the drive would spin against a gate only the human can open.

The marker is bounded (30 min · 50 blocked stops) so a session that dies mid-drive cannot wedge the next one, and every failure path in the hook allows stopping. Those bounds are the **only** runaway guard — the harness provides no loop protection for Stop hooks — so treat a forgotten deletion as a real defect, not a cosmetic one.

### The drive loop

**Continue within the turn — do not yield on a delegated skill's stated stop (see [DRIVE.md](./DRIVE.md) Part 1).** fg-run/fg-done end in statement-form handoffs (ADR-0015) that state the next step and stop; those are written for a human caller, but in a drive **the orchestrator is the caller**, so the moment a delegated step completes, immediately derive the next step and act — sealing one task is **not** a stopping point, and you do **not** end the turn between task loops. The only legitimate ends of a turn are empty state (halt condition 4) and a wall. (No repeat-menu risk: the drive advances on changing state — sealed task leaves the slot, next is promoted — so unlike the ADR-0015 menu bug it never loops on unchanged state.)

Repeat: derive the next step (**via fg-status's state machine, exactly as in section 1 — never reimplemented**), then act:

**Translate the derived step into the `all`-mode action — do not act on the literal step name.** The state machine is mode-agnostic, so on a retro-owed task (executed · `verified:` sealable · retro pending) it derives the literal step **`fg-learn`**. In `all` mode you must **NOT** invoke fg-learn and must **NOT** announce "run fg-learn" to the user — that is one-shot `fg-next`'s behavior, and doing it in a drive is the "keeps telling me to run fg-learn, never seals" bug this mode exists to prevent (re-issuing the drive on the unchanged learn-stage state just repeats it). A derived `fg-learn` maps to **auto-skip the retro and seal** — go straight to the done stage with the retro skipped (the "Linear mechanical step" below). **This override beats §2's "invoke the conversational skill" rule for the retro step.** (Same when a delegated fg-run's statement-form handoff *states* "next: fg-learn" — do not relay it; continue to skip + seal, per [DRIVE.md](./DRIVE.md) Part 1.)

- **Linear mechanical step** → auto-progress with the recommended answer: run a plan, record an `n/a`/auto-verified `yes` outcome, **always auto-skip the retro** (record `retro: skipped (fg-next all auto-drive — learnings stay in run.md, promotion deferred to a later fg-learn)`, written in the user's language; the learnings stay in the archived run.md and promotion is deferred to a later human fg-learn — **the write itself happens inside the delegated done stage**: fg-done records the `retro: skipped` into STATUS as it closes out the seal — now by passing `--skip-retro` to the deterministic seal script `forge-done.sh`/`.js` (ADR-0030), so it stays consistent with "fg-next writes nothing itself"; ADR-0015 amended), run the done stage to seal, **then commit that task when `driveCommit` is on** (DRIVE.md Part 3 — nothing-to-commit continues silently, a refusal is the `fork` wall above), promote the next backlog task. No question asked. (The optional adversarial review — `fg-adversarial-review`, ADR-0018 — is **never** run in a drive: it needs a human to judge which findings are real and worth fixing, so all-mode skips it the same way it skips the retro.)
- **Halt condition** → stop the drive, report where it stopped, why, and the trigger to resume. Resume is **stateless**: the human resolves the wall, then re-issues `fg-next all` to keep draining.

### Halt conditions (hand back to the human)

Stop the drive and report at any of these — everything else auto-progresses:

1. **`verified: failed`** — the UAT found the result broken. Never auto fix-and-re-run (infinite-loop / unintended-change / waiver risk; ADR-0009) — halt.
2. **UAT can't reach a sealable value** — verify is attempted **aggressively** (run whatever tests/grep/build the agent can and record `yes (<evidence>)` or `n/a`), but if it can't reach a sealable value (`pending`), halt rather than seal unverified.
3. **A genuine fork** — e.g. `failed` → fix-and-re-run *or* re-grill. Don't auto-pick a consequential branch → halt.
4. **Empty state** — active slot + backlog + `executed/` all empty. There's no step to continue; a new task needs human-supplied content (fg-ask grilling) → halt (this is the normal terminal state — "all done").
5. **Unknown or uncollectable in-flight marker (fg-run 4a case 3)** — `running.md` belongs to the active task, but blocking-collect cannot identify or collect one or more recorded handles; this includes `workflow: pending`, an unavailable same-session handle, a collection error, and work that may still be running in another session. An orchestrator cannot answer fg-run's required confirmation on the human's behalf: delete `drive.md`, then stop at this human-needed wall.

**A retro is never a halt in all-mode** — it is *always* auto-skipped (recorded as `retro: skipped`, see the drive loop), regardless of divergence. The "always skip retro / halt only at high-divergence" policy was tried and removed: forge-meta work is almost all high-divergence, so halting on it stalled the drive on nearly every task and erased the value of "keep going" — learnings are preserved in the archived run.md and promoted later by a human fg-learn (ADR-0010, amended 2026-06-08). The default one-shot `fg-next` is unchanged — when its single next step is a retro, it opens fg-learn for the human to conduct conversationally; only `all` mode auto-skips.

```
fg-next all
   │
   ▼
Check loop ownership first; if this lane owns the drive, disclose its ordered set once (invocation authorizes it)
   │
   ▼
┌─▶ Derive next step (fg-status state machine)
│      │
│      ├── linear mechanical (run · n/a/auto-yes verify · retro skip [always] · done · promote next) ──▶ auto-progress ─┐
│      └── halt condition (failed · unverifiable · genuine fork · empty · unknown/uncollectable running.md) ──▶ DELETE drive.md ──▶ STOP, report, await human
│                                                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Unattended to completion — pairing with `/goal`

Cross-turn continuation, host capability checks, the conditional `/goal` fallback, and turn-bounded behavior are defined in [DRIVE.md](./DRIVE.md) Part 2. Read it and use the stop-allowed set below only when presenting that fallback; `/goal` never resolves a human-needed wall.

**fg-next all's stop-allowed set** (fill DRIVE.md's phrasing rule with *these* walls — not fg-loop's): (1) **empty state** — backlog + active slot + `executed/` all empty (done); or (2) a **human-needed wall** — `verified: failed`, an unverifiable UAT (can't reach a sealable value), a genuine fork (**this includes a refused per-task commit — reported as `fork (commit rejected — <reason>)`**, DRIVE.md Part 3), or a workflow script approval. Everything else (run · verify-pass · auto-skip retro · seal · promote next) keeps going. Recommended paste-ready shape (render in the user's language):

> *"Keep running `fg-next all` until there is nothing left to auto-progress. Stopping is allowed only when: (1) the backlog, active slot, and executed/ are all empty (done); or (2) it hits a point that needs me — `verified: failed`, an unverifiable UAT, a genuine fork, or a workflow script approval. Everything else — keep going, don't stop."*

The four halt conditions still halt, and the no-arg `fg-next` is unchanged — still one-shot per task (learn→done follow-through aside, ADR-0026).

### Relationship to fg-run "Run all"

fg-run's "Run all" is **execute-only** — it runs the backlog, UAT-verifies, parks each task in `executed/`, and **stops at the retro** (retro is conversational). `fg-next all` is the **superset**: it drives through verify → retro-skip (always) → done → promote-next, sealing tasks as it goes, and only halts at the walls above. They coexist; pick Run all for a batch execute, `fg-next all` to drive whole loops to completion.

