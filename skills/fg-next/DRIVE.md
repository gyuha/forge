# Unattended drive discipline (shared)

> Single definition of how an **unattended multi-step drive** keeps going — within one turn, and across turn boundaries. Shared by `fg-next` (`all` mode) and `fg-loop` so the discipline lives in one place, not two drifting copies (same "single definition, referenced, no copy-paste" pattern as `FORGE-ROOT.md`). Each lane keeps its **own** halt/wall set and entry framing; this file owns only what they genuinely share.

A drive delegates each step to fg-run / fg-done / fg-learn and repeats until it either reaches its terminal state or hits a wall. Two independent things make "repeat" actually happen: continuing **within** a turn (Part 1) and crossing a genuine turn **boundary** (Part 2). They are separate mechanisms with separate guarantees — do not conflate them.

## Part 1 — Continue within the turn (best-effort)

The skills a drive delegates to (fg-run, fg-done) end in **statement-form handoffs** (ADR-0015): they *state* the next step and **stop**. That stop is written for a **human** caller who will read it and decide. **In a drive, the orchestrator is the caller — so do NOT treat a delegated skill's stated stop as a turn boundary.** The moment a delegated step completes, immediately re-derive the next step (via fg-status's state machine — never reimplemented) and act on it: seal → derive/promote next → act, without ending the turn.

- **Sealing one task is not a stopping point.** After each seal, immediately derive and take the next step. The **only** legitimate ends of a turn are the drive's **terminal state** (nothing left to auto-progress) and a genuine **wall** — and each lane defines its own walls (fg-next all: `../fg-next/SKILL.md`; fg-loop: `../fg-loop/SKILL.md`). Pausing anywhere else is the "one cycle then stall" failure this discipline exists to prevent.
- **No re-run / repeat-menu risk.** This continuation advances on **changing** state — a sealed task leaves the active slot, the next is promoted — never on unchanged state. So it does **not** reintroduce the ADR-0015 repeat bug (that was an `AskUserQuestion` menu re-triggering on *unchanged* state; a drive has no such menu, and its state moves forward each step). The drive loop asks the user nothing between steps.
- **A delegated seal stays terse.** A seal reached inside a drive is a *delegated* seal — it uses fg-done's terse completion notice, **never** the explicit-single-seal summary chapter (ADR-0032). That summary is for a human's bare `/fg-done` only; in an unattended drive it would be a wall of text against the momentum this discipline exists to keep.
- **Honest limit.** Skill text alone **cannot guarantee** the model won't yield the turn after a delegated handoff states its next step — the pull toward "natural completion" is real. This within-turn discipline **reduces** yields, and for a backlog of small / direct-execution tasks (no background workflow) it can drain the whole backlog in a single turn. But the **reliable** cross-turn guarantee is `/goal` (Part 2). Neither part claims "never stops" — Part 1 makes one turn go as far as it can; Part 2 makes the next turn resume automatically.

## Part 2 — Cross genuine turn boundaries: the `/goal` pairing

Some boundaries end the turn no matter how forceful Part 1 is: a background Dynamic Workflow running **async** (the turn ends; a task-notification resumes it later), a workflow **script approval** (the human is physically required), or the model simply yielding despite Part 1. Crossing these unattended needs the harness **`/goal`** — a session-scoped Stop hook that blocks the turn from ending until its condition holds, so the drive auto-resumes across boundaries.

- **A skill cannot set `/goal` itself.** `/goal` is a harness slash command only the **user** types; no tool engages it. So treat the `/goal` pairing as the drive's **operating premise, not an optional aside** (the "you may pair it" framing is exactly what users forget, so the drive stalls after one cycle): at drive entry, surface a **paste-ready `/goal …` line as the primary path** to unattended operation, and **re-print it at every resume** (a stateless re-issue — re-printing each time is what structurally stops the user from forgetting to engage it).
- **Phrase the condition as "when may I stop," and make it release at the walls.** The Stop hook keeps driving until its condition is met, so the condition must name the **stopping** points: (1) the drive's **terminal state**, and (2) each **human-needed wall**. **Enumerate the walls from the invoking lane's own set** — fg-next all and fg-loop have different walls; fill them in from the lane that is driving, do **not** copy the other lane's list. **Never phrase it as "until <terminal state>" alone** — that blocks stopping even at a safety wall, forcing the drive past a gate it must hand to a human (auto fix-and-re-run, sealing unverified work, auto-picking a fork — exactly what ADR-0009 / ADR-0010 / ADR-0016 forbid). The condition must let the agent stop at a wall; the human resolves it, then re-issues the drive trigger (the goal, still active, resumes it).
- **State the no-`/goal` fallback in the same breath — be honest, not silent.** Without `/goal` engaged, the drive runs one cycle and the turn ends (most often right after a delegated handoff states its next step and the model yields, per Part 1's honest limit). **That pause is expected, not a failure**: re-issuing the drive trigger resumes statelessly, exactly where it left off. So the choice is explicit, never hidden: paste the `/goal` line to run unattended, or re-trigger after each pause.

```
drive entry
   │
   ▼
present frozen work + paste-ready /goal line (primary path) ── user pastes /goal ─▶ unattended across boundaries
   │                                                        └─ user just proceeds ─▶ one cycle, then turn ends (re-trigger to resume)
   ▼
┌─▶ delegated step (run · verify · [lane's retro policy] · seal · derive next)
│      │ completed ──▶ DO NOT yield on the stated stop; derive next & continue (Part 1) ─┐
│      └─ genuine boundary (async workflow · script approval · yield despite Part 1) ──▶ turn ends; /goal resumes it (Part 2)
│      └─ wall (lane-defined) ──▶ STOP, report why, await human
└───────────────────────────────────────────────────────────────────────────────────────┘
```
