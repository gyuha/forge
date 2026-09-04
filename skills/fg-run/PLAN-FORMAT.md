# plan.md format

> Produced by `fg-ask` transcribing the grilling agreement, and read by `fg-run` as the basis for execution decisions. This is not a machine schema but notes an LLM reads — keep the skeleton, but scale the length to the size of the work.

Documents are written in the user's language; the headings below are canonical English names — render them in the user's language. Consumers match sections by meaning and position, not exact strings.

## Template

```md
<!-- forge-slug: {task-slug} -->
<!-- task: N -->                       {assigned by fg-ask at creation — see Rules}
<!-- retro-hint: optional -->          {optional, omit by default — see Rules}
<!-- priority: high|medium|low -->     {optional, default medium — see Rules}
<!-- part: N/M -->                     {optional — only on a plan that is one part of a split task; see Splitting rule}
<!-- tdd: on|off -->                   {set by fg-ask, default from .forge/config.json — see Rules}
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
- **The `task: N` comment is a stable, monotonically-increasing task number** (like an issue number), assigned by fg-ask when the plan is created: `N = max(task numbers across all plans in .forge/backlog, the active slot, .forge/executed, and .forge/done) + 1`, or `1` if none exist. Like `forge-slug`, it stays on the plan through backlog → active slot → done, never changing. It is an **identifier for display and selection** (fg-status shows it; fg-run lets you pick a task by it) — it is **not** an ordering signal (ordering is `priority`/`part`). Plans created before this feature have no `task:` and show as `—`. Out of scope for the fg-quick lane.
- **The `tdd: on|off` comment records whether this task is built test-first.** fg-ask sets it at the start of grilling, defaulting to `tdd` in `.forge/config.json` (off if the file doesn't exist), and the user can override it for this task. When `on`, fg-run runs the plan test-first — each slice writes a failing test before the implementation and isn't done until that test passes. Omit it (or `off`) for the normal path. It is an execution-mode marker, not an ordering signal.
- **Every slice MUST have exactly one "observable completion criterion."** It is the yardstick fg-run uses to cross-check the result. This is the only thing that is mandatory; everything else is variable.
- **A small task may legitimately be a single slice.** Do not fill out the form ceremonially. Add a one-line verification method / artifact / dependency only when it is non-obvious (omit it otherwise).
- **The dependency notation is the basis for execution order.** If `(depends: S1)` is present, fg-run groups it into a serial wave; if absent, it is treated as parallelizable.
- **`retro-hint: optional` is an optional, non-binding hint (omit by default).** When fg-ask judges during grilling that a task is trivial enough that a retro will likely have nothing to fold into the docs, it may add a `<!-- retro-hint: optional -->` comment near the `forge-slug` line. It only changes which option fg-run leads with at its handoff — it does **not** force a skip. The actual skip decision is fg-run's, gated on the run's divergence (no skip offered when the result diverged significantly). Omitting the hint is the default and means "retro recommended."
- **`priority: high|medium|low` is an optional ordering marker (omit by default = `medium`).** When several plans wait in the backlog, fg-run sorts its selection menu (and the "Run all" sequence) by this marker: `high → medium → low`, ties broken by slug alphabetical. It only affects **display/run order** — it is never an auto-selection; the user still picks from the menu. Set it during fg-ask grilling when a task's importance is clear; otherwise omit it (treated as `medium`).
- **A Definition of Done that spans many sites must ENUMERATE the sites, not the kind of check.** "add the section to both docs" is a *kind*; the executor then verifies the sites it happened to think of and the rest silently keep the old state. Catalogue and count wording is the usual offender — a skill count lives in the manifests, the README bilingual pair, the docs pair AND its 6-column table, the landing page's per-language spans, CLAUDE.md, and the codebase map. Write the list, or write the command that would find them all (`grep -c … → 0`). Observed three times: `#115` raised it, `#118` shipped with three catalogue sites stale, `#119` found five more than its own plan named.
- **Every command a Definition of Done names must be runnable as written, and its pre-state accounted for.** The rule above tells you to "write the command that would find them all" — and that remedy is exactly where `#120`'s two DoD defects came from, so it needs three guards. **(a)** `→ N` (an exact count) is safe only when the slice owns that whole surface; otherwise pre-existing matches eat the budget and the check passes *before any work is done* — scope it to what the slice owns (`sed -n '/^## Credits/,$p' | grep -c …`) or write `≥1`. **(b)** `→ 0` (a forbidden string) is safe only when that string is never legitimate in that file — cross-check it against the plan's own **Non-goals**, because a plan that says "keep the historical mention" while forbidding that same string contradicts itself. **(c)** **A negative check fails open**: a broken command also prints `0`, so `0` is evidence only alongside proof that the command actually runs. Therefore **run each command once at authoring time** (fg-ask) and again at promotion (fg-run's `DoD baseline`), and give any already-passing item a one-line reason on its own line — a *regression guard* legitimately passes in advance, a *forward check* that already passes is mis-encoded. Observed: `#116` C6 (a check satisfiable only by out-of-scope work), `#120` DoD 4 (`→ 1` already met by a catalogue row before the slice ran) and DoD 6 (`→ 0` forbidding the very string its own Non-goals preserved). **(d)** **A DoD checks the artifact, never the primitive the artifact leans on.** When the thing being written is a contract that depends on an external tool's behaviour (git, a hook, an exit code, a shell builtin), **reproduce that behaviour once** — the DoD can be 7/7 green while the contract rests on a false assumption about the tool. Observed: `#131` passed all seven DoD items, and the real defect — that `git commit` exits `1` for *both* "nothing to commit" and "a hook refused", so the contract's two branches were indistinguishable — was caught only by a throwaway repro that no DoD item had asked for. This is the mirror of (c): (c) says do not exempt an expensive command that *is* in the DoD; (d) says the primitive may not be in the DoD at all. **(e)** **A DoD measures the artifact's behaviour, never a proxy for it.** A check that greps for the *string* an edit introduces asserts only that someone typed it; whether the artifact then *does* its job is a separate question, and the two come apart silently. This is the worst failure shape in this list because it is the only one that **passes while the work is still broken** — (a)-(d) mis-fire loudly (unsatisfiable, already-met, fails-open), (e) reports green. So when a slice edits a value some tool consumes (a glob pattern, a path, a matcher, a command string), the DoD must **resolve it the way that tool would** and assert the result, not assert that the text is present. Observed: `#133` DoD 4 (`grep -o '\.\./' skills/fg-help/SKILL.md | wc -l` -> `>=1`) passed at 1, while the pattern it was counting matched **zero** files through the Glob tool it was written for — the slice's whole purpose was unmet and every DoD item was green. The same plan's DoD 1 had the same shape, and its predecessor `#94` produced three defective criteria of kinds (a)-(c); the escalation from "criterion cannot be met" to "criterion is met and lies" is why this gets its own rule.
- **Transcription mapping from the grilling agreement** — refined terms → Source of truth Glossary terms, hard-to-reverse decisions → ADR links, agreed units of work → slices (+ completion criteria), what was decided not to do this time → Non-goals.

## Splitting rule (one plan is never split mid-run; a big task may become several plans)

**The state contract one plan.md = one run.md = one sealing (fg-done) is invariant.** Do not split a *single* plan into phases run sequentially and accumulated into one run.md — that is incompatible with fg-run's re-run guard (a duplicate warning when run.md already exists). Whatever you write as one plan must be runnable end-to-end in one workflow.

**This rule applies at refine time too, not only at first grilling.** When fg-ask adds a requirement to a *pending* plan (one in the backlog, or the active slot with no `run.md` yet — see fg-ask's "Refine a pending plan vs. new task"), the same judgment runs: fold a small cohesive addition into the plan, but if the addition makes the work large/decomposable, recommend splitting per the rules below; if it is an entirely different concern, it is a separate new plan, not a split.

There are **two reasons to split a big task into multiple plans** (each a separate, independently-sealable plan in the backlog):

1. **A mid-run human checkpoint** — a human check / decision must intervene before the next step can proceed. A Dynamic Workflow cannot take human input at runtime, so the check point is a task boundary. (We do not distinguish "simple go-ahead" from "major decision branch" — either way it must stop.)
2. **Size / decomposition** — the agreed work is large enough that it naturally breaks into chunks each of which is **independently shippable, verifiable, and sealable** on its own. Don't force such work into one giant plan. This is a judgment call (not a slice-count threshold): if each chunk can stand as its own complete `execute → learn → done` loop, make each chunk its own plan.

```
Does the agreed work split into chunks that are each independently shippable & sealable,
or does a human checkpoint sit mid-way?
├── No (one cohesive deliverable, runnable end-to-end in one workflow) → one plan.
└── Yes → multiple plans, one per chunk. Each is a full standalone loop.
```

### Part-plans and soft ordering

When you split by size into an ordered series, give each plan a **soft sequence hint**, not a hard dependency:

- Slug encodes order for readability: `<base>-1of3`, `<base>-2of3`, `<base>-3of3`. Sequence order comes from the numeric N in the `part: N/M` marker, not slug alphabetical (which misorders 10+ parts: `-10of12` sorts before `-2of12`).
- Add a `<!-- part: N/M -->` marker. fg-run shows part-plans in order, labels them `(part N/M)`, and recommends completing them one at a time in sequence — but it does **not** block a later part if an earlier one isn't sealed yet. The order is a recommendation, not a gate.
- **Each part-plan must still be independently sealable** — one part = one plan = one workflow = one run = one seal. The `part` marker changes display/recommendation order only.

**The backlog (`.forge/backlog/`) is storage for multiple plans.** Each backlog plan runs its own independent loop (execute→retro→seal). There is **no hard dependency** syntax between plans — `part: N/M` is a soft ordering hint only. If one chunk genuinely cannot stand alone (a true hard dependency), it was not a real split point — fold it back into the plan it depends on.
