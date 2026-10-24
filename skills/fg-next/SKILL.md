---
name: fg-next
description: Derives the single next step of the forge loop (reusing fg-status's state machine) and runs it — announces the step, then invokes that skill (fg-status reports; fg-next acts). One-shot by default; with the 'all' argument it drives the backlog to completion, sealing each task (fg-done decides its retro unattended) and halting at the walls (failed/unverifiable UAT, a genuine fork, empty state). The cold-re-entry entry point. Use in contexts like 'forge next', '다음 단계', '이어서 해줘', '계속 진행', 'fg-next all', '다음 전부 진행'.
---

# fg-next — derive the next step, then act on it (outside the loop)

This is **not** a stage of the forge loop. It is the acting sibling of `fg-status`: where fg-status surveys `.forge/` and **reports** the single next step but deliberately never runs it, fg-next derives that same next step and **runs it** — it announces the step in one line and then actually invokes the skill, rather than stopping at the report. Its real value is **cold re-entry**: when you don't remember where a task stands, "forge next" figures out the one correct move and takes it.

By default it does **one step only** (one-shot): one step = one skill invocation. After that step, the invoked skill's own handoff carries the loop forward — so you rarely need fg-next twice in a row. (With the `all` argument it instead drives multiple steps to the wall — see "`all` mode" below.) The old learn→done exception (ADR-0026) is gone: the retro is now decided inside the seal, so there is no second step to chain (ADR `261024-191024`). It **writes nothing itself**: it reads state and delegates; every file write (plan/run/STATUS/backlog/done/retro/adr/quick) happens inside the skill it hands off to.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** The one-line next-step announcement (and any narrow fork question) is written in the user's language.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Evidence and candor**: every claim you make about code, state, or results — in a message or in a document you write (plan, run notes, retro, ADR) — carries its evidence in the same sentence (a `file:line`, a command and its output) or a label: **Measured** (you checked it this session), **Inferred** (reasoned from what you checked), **Guess** (a prediction or an unseen cause), rendered in the user's language. A label is not a license to skip a check — if a cheap check would settle it, run it; never hand the user a check you could run. Agreement is not the default: when asked whether to do something, invited to add scope, or shown an approach, give your real judgment first — the strongest objection, and "don't do it" when that is true. Change a recommendation only for a new fact or argument, never for repetition; the decision stays the user's — state the objection once, then follow their call without re-arguing or silently deviating. Output a deterministic script printed is already measured and needs no label.

**Host contract**: `all`-mode driving depends on the host's `prevent_stop` capability, and the backlog selection menu on `structured_choice`. Read [../../core/HOST.md](../../core/HOST.md) and [../../core/INTERACTION.md](../../core/INTERACTION.md), then check `../../hosts/<host>/capabilities.json`. With `prevent_stop` `false`, `all` is **turn-bounded** — it drives as far as one turn allows and resumes on re-trigger ([`DRIVE.md`](./DRIVE.md) Part 2's honest fallback); say so at entry instead of implying continuous execution. With `structured_choice` `false`, present a numbered text list and take one stable identifier. **The state machine, the walls, and the one-shot semantics are host-neutral.**

**Forge root**: every `.forge/...` path below (and fg-status's state machine it reuses) is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before deriving or acting (ADR-0011).

## How it works

### 1. Derive the next step (do not reimplement)

Perform the survey and the next-step derivation **exactly as `fg-status` does** — fg-status's "Deriving the next step (state machine)" section is the single source of truth for this logic (run → verify → done priority, the retro decided inside the seal, the `verified: failed`/`pending` branches, parked-`executed/` recovery, the empty-state case). Read it and follow it:

`${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-status/SKILL.md` (or the skill-relative path `../fg-status/SKILL.md`)

Do **not** duplicate or paraphrase that state machine here — if the loop changes, only fg-status's copy should move. fg-next adds only the **act** on top of fg-status's **derive**.

### 2. Announce, then proceed — actually invoke the skill

**The whole point of fg-next is to act, not merely report.** Reporting the next step and stopping is `fg-status`'s job — if fg-next only tells you where you are and waits, it has failed. So once you've derived the step: state it in one line (`Next: <skill> — proceeding.`, rendered in the user's language), then **invoke that skill via the Skill tool in the same turn.** Do **not** stop and wait for a separate "go ahead" — proceed.

- **fg-run / fg-done** (the loop's mechanical stages) → invoke the skill now to run that step. **When the step is `fg-done`, it is a seal delegated by fg-next — a human is still in the conversation, so it is an *interactive* seal for fg-done's retro judgment (it may ask its one promotion question), but keep the seal notice terse: never the explicit-single-seal summary chapter (ADR-0032) — that summary is for a human's bare `/fg-done` only.** When `eco` is on, "terse" means **one row** of the batch eco summary table rather than a prose notice — the rule and its shape live in [DRIVE.md](./DRIVE.md) Part 1 and `../fg-config/ECO.md`; do not restate them here.
- **fg-ask** (the conversational stage) → invoke the skill now to **enter that conversation**; fg-next does not conduct the grilling itself, but it does open it (the skill is interactive, so the human engages inside it — that is not fg-next stalling).

Then **stop** — one step, no chaining (one-shot).

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
   │             └── fg-run / fg-done / fg-ask ──▶ STOP (one-shot)
   └── no  ──▶ fork             ──▶ ask which option (needed choice) ──▶ invoke the chosen skill
              multiple backlog  ──▶ invoke fg-run (its menu makes the pick)
              everything empty  ──▶ invoke fg-ask to start a new task
```

## `all` mode — drive to the wall (multi-step momentum)

When invoked with the `all` argument (`fg-next all`), fg-next does **not** stop after one step: it promotes and runs backlog tasks in turn until the backlog is empty, auto-progressing the linear mechanical steps and halting only at the conversational walls (ADR-0010). The default `fg-next` (no arg) is unchanged — still one-shot.

**When — and only when — the `all` argument is given, read [`ALL-MODE.md`](./ALL-MODE.md) (skill-relative `./ALL-MODE.md`) and follow it.** It owns the whole batch procedure: the `loop.md` yield rule, the wall set, the per-task drive, `driveCommit`, and the batch handoff. It is split into that file — loaded only when `all` is actually invoked — for token efficiency on the common one-shot path; **behavior is unchanged** from when it lived inline (the same arrangement as `../fg-run/RUN-ALL.md`).

## Handoff

fg-next's handoff **is** the step it invoked — once it delegates, the invoked skill's own next-flow handoff takes over (fg-run ends in its statement-form handoff — ADR-0015 amended 2026-06-15, the old 4-way menu dropped; fg-run points to fg-done, and so on). fg-next adds nothing after that and does not re-derive or chain. If the user wants the following step too, they say "forge next" again (or follow the skill's own handoff prompt).

**One table per step — never two for the same step.** Its shape is defined once in [`./HANDOFF.md`](./HANDOFF.md); never restate that layout. A delegated skill cannot detect its caller, so **who renders is fg-next's decision to enforce: instruct each step you invoke whether to render its table.**

- **One-shot** → the invoked step renders its own table (a human is reading it) and fg-next adds nothing after it. fg-next's one-line announcements (`Next: … — proceeding`) are announcements, not handoffs.
- **`all` mode** → **no delegated table reaches the user.** Instruct every step you invoke not to render, and render one table yourself for **fg-next's own step**: the wall it halted at, or the drive's completion (empty state). This is the same active suppression fg-next already applies to the delegated seal summary (ADR-0032), and it is what [DRIVE.md](./DRIVE.md) Part 1 requires — a relayed `Next step` row from a delegated step *is* the "keeps telling me to run the next skill, never seals" stall, and a table reads as an instruction, so relaying one is worse than relaying the prose was.

fg-next proceeds by default — it does not wait for permission. Only if the user explicitly says "just tell me, don't act" (or similar) do you fall back to fg-status behavior: state the next step and its trigger as the handoff table (`./HANDOFF.md`, as fg-status fills it), write nothing, and stop.

## Document impact

- **None directly.** fg-next itself creates and modifies nothing — it reads `.forge/` to derive the step and delegates the action. Any document change is made by the skill it invokes (fg-run/fg-done/fg-ask), under that skill's own rules.
