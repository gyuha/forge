---
name: fg-learn
description: Batch promotion of deferred learnings, outside the loop — reviews sealed tasks whose retro was skipped or written unattended (fg-next all, fg-loop, simple, fg-done all), and with you promotes what clears the bar to CONTEXT.md, ADRs, evals (machine-checkable learnings as persistent tests) or a retro log. The per-task retro is no longer a loop stage — fg-done decides it at seal. Always conversational. Use for 'batch promotion', '일괄 승급', 'forge learn', '회고 모아서 정리', '미뤄둔 학습 정리'.
---

# fg-learn — batch promotion of deferred learnings (outside the loop)

**Host contract**: this skill's state transitions are host-neutral. Read [../../core/HOST.md](../../core/HOST.md) and use the active host's interaction adapter (`structured_choice`, falling back to a numbered text choice) for any user choice.

This is **not** a stage of the forge loop. The loop is ask → run → done, and the per-task retro happens inside the seal: fg-done decides whether a task left something to learn, writes the retro log when it did, and — when a human is present — asks once about promotions (ADR `261024-191024`). Seals that run without a human (`fg-next all`, `fg-loop`, `simple` mode, `fg-done all`, fg-ask's auto-close) cannot ask, so they skip the retro or write an auto retro and **defer promotion**. This skill is where those deferred promotions are finally judged, a batch at a time. The reason it exists is simple — a learning that never reaches the docs is re-learned the hard way; but pushing every learning into permanent docs pollutes them. So the core of this skill is **classification and promotion discipline**.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** All documents this skill generates for the user's project (plan, run notes, retros, CONTEXT.md entries, ADRs, handoff messages) are written in the user's language. Section headings defined in the format docs are canonical English names — when writing a document, render headings in the user's language; consumers match sections by meaning and position, not exact strings.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Evidence and candor**: every claim you make about code, state, or results — in a message or in a document you write (plan, run notes, retro, ADR) — carries its evidence in the same sentence (a `file:line`, a command and its output) or a label: **Measured** (you checked it this session), **Inferred** (reasoned from what you checked), **Guess** (a prediction or an unseen cause), rendered in the user's language. A label is not a license to skip a check — if a cheap check would settle it, run it; never hand the user a check you could run. Agreement is not the default: when asked whether to do something, invited to add scope, or shown an approach, give your real judgment first — the strongest objection, and "don't do it" when that is true. Change a recommendation only for a new fact or argument, never for repetition; the decision stays the user's — state the objection once, then follow their call without re-arguing or silently deviating. Output a deterministic script printed is already measured and needs no label.

**Forge root**: every `.forge/...` path below is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before reading or writing state (ADR-0011).

This review **always runs conversationally.** Deciding what is worth keeping and which doc it belongs in requires human judgment, so extracting it mechanically only breaks the discipline.

## When it applies (and when it does not)

- **Unsealed work is not this skill's.** A task in the active slot or `.forge/executed/` gets its retro decided when it is sealed — route it to **fg-done** (`/forge:fg-done`), which runs the retro judgment and the verification gate (ADR-0009) in order. If the task is still `verified: pending` or `failed`, fg-done routes it to fg-run first.
- **Candidates** = sealed tasks in `.forge/done/*/STATUS.md` that still carry the "promote later" promise:
  - **Auto retros not yet reviewed** — `retro:` is a path whose file's **first line** is `<!-- auto-retro: … -->`. An unattended seal wrote it, but nobody has judged what to promote. That marker line is the **only** discriminator — never a STATUS note, which is hand-written prose that may be missing or in another language. Use the retro as a starting draft rather than re-deriving from `run.md` alone.
  - **Unjudged skips** — `retro:` reads `skipped (...)` **without** the `judged:` prefix, and the line carries no `reviewed` note. Since ADR `261024-191024` the seal script writes every skip as `skipped (judged: <reason>)` — a seal-time judgment that there was nothing to learn, so not a candidate. A skip without `judged:` was written by the old drives' unconditional "promote later" rule, whatever its date (a same-day seal, a project that upgraded late, a merged branch), so it is still owed.
  - **Unapplied promotions** — a retro whose first line is `<!-- promotion-pending -->`: an interactive seal adopted promotions but did not finish applying them. Apply the recorded ones (they were already approved) and remove the marker.
  - **Unfilled retro field** — a sealed STATUS that still reads `retro: pending` (fg-doctor A3). Resolve it to the retro path or `skipped (judged: <reason>)`.
  - Exclude legacy tasks with no `retro:` field, and retro paths with neither an `auto-retro` nor a `promotion-pending` marker (already reviewed).
- **Entry is explicit only.** Run it when the user asks ("일괄 승급" / "batch promotion" / following a handoff that pointed here). Orchestrators never invoke it automatically.

## Behavior

### 1. Review one task at a time

List the candidates (newest first, with the reason each is a candidate), then review **each task separately and conversationally** — do not lump several into one review. Per task, read its archived `done/<date-slug>/run.md` and `plan.md` — including its `## Rulings` section, the soft decisions an unattended drive took on the human's behalf (`../fg-next/DRIVE.md` Part 4), and its `## Failed attempts` section, both worth confirming or overturning here — plus `review.md` when the archive has one (findings the human accepted but did not fix are exactly the kind of learning to fold in). Ask grounded in those records: did the plan match reality, which terms or assumptions broke, what to do differently next time. If nothing notable happened, say so in one line and move on — a review is not a ritual.

### 2. Classify learnings into four kinds

This table is the single definition of the destinations and their bars; fg-done's seal-time retro (`../fg-done/SKILL.md` step 0b) uses it too. Learnings that don't clear the promotion bar **all go to the retro log** — that's the reason the retro log exists.

| Nature of the learning | Destination | Promotion bar |
| --- | --- | --- |
| New/changed domain term | `CONTEXT.md` | Only if it's a context-specific concept. General concepts and implementation details are excluded |
| A decision that is hard to reverse, puzzling, and a real trade-off | `.forge/adr/<id>-slug.md` | Only when **all three** conditions are met |
| A mechanically checkable learning — a failure or trap that could recur (a structural trap, not a one-off mistake) | The project's own test suite as a persistent regression check (an "eval"); in a repo with no test suite, an equivalent executable landing spot (e.g. an fg-doctor check in forge's own repo) | Only when **all three** hold — mechanically checkable · recurrence plausible (structural, not one-off) · cheap to run (does not slow the suite/CI) |
| Process/session learning | `.forge/retro/YYMMDD-HHMMSS-slug.md` | If it's worth recording |

**Eval size split.** When the eval is small (one or two tests, immediately writable and runnable green), write it **inline** — the same inline-update precedent as CONTEXT.md/ADR entries. When it needs infrastructure or touches several files, load it as a backlog plan via fg-ask instead. Newly authored fix-forward plans already carry this mechanically via PLAN-FORMAT.md's fix-forward eval rule (see [`../fg-run/PLAN-FORMAT.md`](../fg-run/PLAN-FORMAT.md)) — ADR `260906-171420`.

### 3. Respect the promotion discipline

Don't push everything into `CONTEXT.md` or an ADR. `CONTEXT.md` is a glossary; if implementation details and one-off noise get mixed in, the next reader stops trusting it. The same goes for ADRs: if trivial decisions are recorded, the important ones get buried. **The judgment of what to promote is never made automatically** — present candidates and promote only what the human confirms.

### 4. Write the docs and correct the sealed STATUS

- A retro log goes to `.forge/retro/YYMMDD-HHMMSS-<slug>.md` per [RETRO-FORMAT.md](./RETRO-FORMAT.md) — **only where a learning clears the bar**, or to replace an auto retro's "unreviewed" sections. "Reviewed, nothing worth promoting" is a normal, file-less outcome.
- Promoted terms follow `../fg-ask/CONTEXT-FORMAT.md`; promoted decisions follow `../fg-ask/ADR-FORMAT.md`.
- **Correct the sealed STATUS `retro:` line** so fg-status reflects reality: from `skipped (...)` to the new retro path plus a late-promotion note (e.g. `retro: .forge/retro/<file> (batch promotion 2026-10-24)`), or, for an auto retro, remove the `auto-retro` marker line from the retro file once reviewed — whether or not anything was promoted — and drop any informational note the seal left on the `retro:` line (ADR `261010-230950`). Seal immutability lives in `status: done`, which is never touched. A skip reviewed without promotion appends ` (reviewed <date>)` to its `retro:` line so it leaves the candidate list.
- Record in the retro's "Doc updates" field what was promoted to where (or none).

```
fg-learn (batch promotion)
   │
   ▼
Active slot / executed/ task?  ── yes ──▶ not this skill: route to fg-done (retro is decided at seal)
   │ no
   ▼
Collect candidates in done/: auto-retro or promotion-pending marker · skips without judged: (unreviewed) · retro: pending
   ▼
Per task, one at a time (conversational):
   read archived plan · run (Rulings, Failed attempts) · review · auto retro draft
   ▼
Classify (bar + human confirmation):
   • domain-specific term ──▶ CONTEXT.md
   • hard-to-reverse · puzzling · trade-off (all three) ──▶ new ADR
   • mechanically checkable · recurrence plausible · cheap (all three) ──▶ eval
   • everything else ──▶ retro log only, or nothing
   ▼
Correct the sealed STATUS retro: line / clear the auto-retro marker
   ▼
Persist follow-up candidates → handoff table
```

## Persist follow-up candidates

Before the handoff, record every concrete follow-up in `.forge/followups.md` using [FOLLOWUPS-FORMAT.md](./FOLLOWUPS-FORMAT.md). Read existing entries first and reuse IDs from the run or earlier retro. Put marked snapshots in the final section of the retro, then collect them into the ledger; replay must preserve taken/dismissed states. Candidates are proposals, so this does not bypass human confirmation. No candidates means no ledger creation.

## Handoff

When the batch is done, **render the handoff table** — its shape is defined once in [`../fg-next/HANDOFF.md`](../fg-next/HANDOFF.md); reference it, never restate the layout here. Render it in the user's language:

- **Just did** — how many sealed tasks were reviewed, and one line on what was promoted where (or that nothing was).
- **Next step** — candidates remain → reviewing the rest (`/forge:fg-learn`); otherwise a new task with fg-ask (`/forge:fg-ask`, or `fg-next`).
- **Follow-up candidates** — the entries just persisted, as bullets **below** the table with their IDs and ledger path.

Then **state it and stop**; the table is text output, never an `AskUserQuestion` (ADR-0015).

## Doc impact

- Creates `.forge/retro/YYMMDD-HHMMSS-slug.md` only where a learning clears the bar or an auto retro is reviewed.
- Creates/updates `.forge/followups.md` when candidates exist, per FOLLOWUPS-FORMAT; preserves terminal states on repeated reviews.
- When the promotion conditions are met, updates `CONTEXT.md` / adds `.forge/adr/<id>-slug.md` / writes an eval (after human confirmation).
- Corrects a sealed task's STATUS `retro:` line (never `status:`), marks reviewed skips, and removes a reviewed retro's `auto-retro` marker.
- Never touches the active slot, `executed/`, or the backlog — unsealed work belongs to fg-done.
