---
name: fg-ask
description: Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decisions crystallise. Use when user wants to stress-test a plan against their project's language and documented decisions. The entry point of the forge loop and its plan-grilling stage — use in contexts like "start a new task", "start with forge", "let's work on this", '새 작업 시작', 'forge로 시작', '이거 작업하자', '계획 다듬자', '이 계획 그릴링해줘'. Once an agreed plan is loaded into .forge/backlog/<slug>.md, fg-execute picks it up and runs it. Always conducted as a conversation in this session (outside any workflow).
---

<what-to-do>

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing.

If a question can be answered by exploring the codebase, explore the codebase instead.

</what-to-do>

<supporting-info>

## Domain awareness

During codebase exploration, also look for existing documentation:

### File structure

Most repos have a single context:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `CONTEXT-MAP.md` exists at the root, the repo has multiple contexts. The map points to where each one lives:

```
/
├── CONTEXT-MAP.md
├── docs/
│   └── adr/                          ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   └── docs/adr/                 ← context-specific decisions
│   └── billing/
│       ├── CONTEXT.md
│       └── docs/adr/
```

Create files lazily — only when you have something to write. If no `CONTEXT.md` exists, create one when the first term is resolved. If no `docs/adr/` exists, create it when the first ADR is needed.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up — capture them as they happen. Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).

`CONTEXT.md` should be totally devoid of implementation details. Do not treat `CONTEXT.md` as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [ADR-FORMAT.md](./ADR-FORMAT.md).

</supporting-info>

---

## Forge integration (minimal)

The original text ends above. What follows is the minimal glue that keeps the forge loop unbroken; the grilling method itself follows the original text above.

- **Language**: This skill file is authored in English, but always converse with the user in the user's language. All documents this skill generates for the user's project (plan, run notes, retros, CONTEXT.md entries, ADRs, handoff messages) are written in the user's language. Section headings defined in the format docs are canonical English names — when writing a document, render headings in the user's language; consumers match sections by meaning and position, not exact strings.
- **Before starting: feed back the latest retros.** If `docs/retro/` exists, read it as a starting point for grilling — pull each retro's "Do differently next time" and "Divergences" into your opening questions (which past traps could recur this time, which assumptions broke). **Selection rule (when retros have piled up):** first take those in the same area as this task (overlapping slug stem / domain terms), then up to the most recent 3–5. Don't read all of them. Retros are reference fuel for sharpening the plan, not a source of truth — the plan's source of truth comes only from CONTEXT.md and ADRs. If there are no retros or none are relevant, skip silently.
- **Before starting: check for existing work.** Before entering grilling, look at the active slot (`.forge/plan.md`) and the backlog (`.forge/backlog/`) for an existing plan, and consult the completion markers `.forge/done/*/STATUS.md` for what has already been sealed — if the requested work matches an already-completed slug, surface it ("a task with this slug was sealed on {date}") so the user knowingly starts a new cycle, and pick a non-colliding slug for the new plan. If this request is a **re-grilling** (refining an existing plan), update that file (slot or backlog). If it is a **new task**, proceed as is — the new plan stacks in the backlog and coexists with existing work. But do not overwrite the active slot's `plan.md` without confirmation — silently changing the plan of a task that already has a `run.md` would pollute fg-learn's "Plan vs actual" comparison.
- **Output.** Once grilling reaches a shared understanding, write the agreed plan to `.forge/backlog/<slug>.md` (slug = kebab-case of the task title, `-2` on collision; the directory is created lazily). Embed a `<!-- forge-slug: <slug> -->` comment on the plan's first line — a persistent identifier that lets retro and sealing pair up by the same slug even after the plan moves to the active slot. The format follows the skeleton in [PLAN-FORMAT.md](../fg-execute/PLAN-FORMAT.md) (or `${CLAUDE_PLUGIN_ROOT}/skills/fg-execute/PLAN-FORMAT.md`) — sharpened terms → source-of-truth glossary, hard-to-reverse decisions → ADR links, agreed units of work → slices (+ observable completion criterion), things decided not to do this time → non-goals. If you spot a point that needs human confirmation midway, narrow the plan up to there — leave the rest as a separate task in the backlog (see PLAN-FORMAT.md for the splitting rule).
- **Handoff.** After arranging the plan in the backlog, naturally point to `fg-execute` as the next step — fg-execute picks a task from the backlog (a selection menu if there are several, with "Run all" at the end), promotes it to the active slot, and runs it. Ask whether the task is big enough to run as a Dynamic Workflow or small enough to handle directly, to decide the execution mode. **Ask whether to continue straight into execution, and if the user agrees, invoke the `fg-execute` skill right there to continue.** If they want to do it later, tell them the trigger — saying "forge execute" / "계획 실행", or `/forge:fg-execute`.
- **Volatile state.** `.forge/` is gitignored working state, so it is not tracked or committed.
