# plan.md format

> Produced by `fg-ask` transcribing the grilling agreement, and read by `fg-execute` as the basis for execution decisions. This is not a machine schema but notes an LLM reads — keep the skeleton, but scale the length to the size of the work.

Documents are written in the user's language; the headings below are canonical English names — render them in the user's language. Consumers match sections by meaning and position, not exact strings.

## Template

```md
<!-- forge-slug: {task-slug} -->
# {one-line task title}

## Goal / Non-goals
- Goal: {what this one loop achieves — 1-3 lines}
- Non-goals: {what is explicitly NOT done this time. May be empty, but writing it keeps the workflow from drifting out of scope}

## Source of truth
- Glossary terms: {related terms} in .forge/CONTEXT.md, or "none"
- Related ADRs: .forge/adr/NNNN-*, or "none"
- Definition of Done: {the observable state at which the whole task can be called "done"}

## Work slices
- [ ] S1. {what is done} — completion criterion: {observable condition}
- [ ] S2. {what is done} — completion criterion: {...} (depends: S1)
```

## Rules

- **The `forge-slug` comment on the first line is the persistent identifier.** It is the kebab-case of the task title (e.g. `settlement-payout-split`, with `-2` on collision). Even when the plan file moves from the backlog (`.forge/backlog/<slug>.md`) into the active slot (`.forge/plan.md`), this comment stays, so the retro (`.forge/retro/*-<slug>.md`) and the sealing (`.forge/done/<date-slug>/`) pair up by the same slug.
- **Every slice MUST have exactly one "observable completion criterion."** It is the yardstick fg-execute uses to cross-check the result. This is the only thing that is mandatory; everything else is variable.
- **A small task may legitimately be a single slice.** Do not fill out the form ceremonially. Add a one-line verification method / artifact / dependency only when it is non-obvious (omit it otherwise).
- **The dependency notation is the basis for execution order.** If `(depends: S1)` is present, fg-execute groups it into a serial wave; if absent, it is treated as parallelizable.
- **Transcription mapping from the grilling agreement** — refined terms → Source of truth Glossary terms, hard-to-reverse decisions → ADR links, agreed units of work → slices (+ completion criteria), what was decided not to do this time → Non-goals.

## Splitting rule (a plan is never split)

**If you feel the urge to split it, that is a signal the work was two tasks.** The state contract that one plan.md = one run.md = one sealing (fg-cleanup) is invariant. Do not split a plan into phases run sequentially and accumulated into run.md — that is incompatible with fg-execute's re-run guard (a duplicate warning when run.md already exists).

```
Can this plan be run end-to-end in one workflow?
├── Yes (no human check needed mid-run, or only serial dependencies between slices)
│     → No split. Compose waves via dependency notation and run it in one pass.
└── No — a human check / decision must intervene before the next step can proceed
      → That check point is the task boundary.
        Narrow the plan to everything before that point, complete and seal one loop (execute→learn→cleanup),
        and open a new fg-ask for the rest as a fg-cleanup follow-up.
```

We do not distinguish "simple go-ahead approval" from "major decision branch" — a Dynamic Workflow cannot take human input at runtime, so either way it must stop, and a stop is a task boundary.

**The backlog (`.forge/backlog/`) is storage for multiple plans, not the splitting of one plan.** Each backlog plan is a separate task that runs its own independent loop (execute→retro→seal). There is no syntax for noting dependencies between plans — if the dependency is strong, it should have been a single plan in the first place (see the splitting rule above).
