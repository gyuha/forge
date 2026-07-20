---
name: fg-learn
description: After execution, classify learnings and promote them to CONTEXT.md, ADRs, and the retro log (.forge/retro), then surface the next inquiry. Always conversational; respects the promotion discipline. Use to record what you learned after a task — 'forge learn', '회고하자', '이번 작업 정리해줘'.
---

# fg-learn — ③ Retro (reflect into docs)

This is the third turn of the forge loop. It classifies the learnings gained during execution, routes them to the right doc, and surfaces the next inquiry. The reason to run a retro is simple — if you don't write down what you learned during execution right then, the next person (or future you) hits the same wall again. But if you push every learning into permanent docs, the docs get polluted with noise. So the core of this skill is **classification and promotion discipline**.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** All documents this skill generates for the user's project (plan, run notes, retros, CONTEXT.md entries, ADRs, handoff messages) are written in the user's language. Section headings defined in the format docs are canonical English names — when writing a document, render headings in the user's language; consumers match sections by meaning and position, not exact strings.

**Forge root**: every `.forge/...` path below is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before reading or writing state (ADR-0011).

This retro **always runs conversationally.** It does not auto-generate a retro draft via a workflow. Deciding what is worth learning and which doc each learning belongs in requires human judgment, so extracting it mechanically only breaks the discipline.

## Input

It reads `.forge/run.md` (the run record: plan vs actual) and `.forge/plan.md` (the plan = the source of truth for execution). You have to put these side by side to pinpoint "where did the plan and reality diverge."

If `.forge/review.md` exists (adversarial review findings left by `fg-adversarial-review` — ADR-0018), read it too as **retro-promotion input**: findings the human accepted but did not fix are exactly the kind of learning to fold into the retro (and, past the usual bar, possibly promote to an ADR or a CONTEXT term). The review is optional, so this file is often absent — skip silently when it is.

Also consult the completion markers **`.forge/done/*/STATUS.md`** before picking what to retro — a task whose slug already has a sealed STATUS.md (`status: done`) is out of scope (retroing it again would be a state error worth surfacing, not silently doing — **except through Batch promotion mode below, the one deliberate entry for sealed tasks**). The companion marker **`.forge/executed/<slug>/STATUS.md`** (`status: executed`), by contrast, confirms execution finished and the work is awaiting retro — exactly the candidates this step picks from.

Besides the active slot, **`.forge/executed/<slug>/`** (work parked by fg-run "Run all" that is awaiting retro, each carrying a `STATUS.md` with `status: executed`) is also an input — in this case plan/run are read **inside each `executed/<slug>/` directory**, not the active slot (when parked, the active slot is empty). Work whose retro is already done (a `.forge/retro/*-<slug>.md` exists) **or was intentionally skipped** (its `STATUS.md` carries `retro: skipped` — a trivial, low-divergence task fg-run let the user skip) is dropped from the candidates: a skipped task has already declared it has nothing to fold into the docs, so do not re-offer it here (a *sealed* `retro: skipped` task becomes reachable again only through Batch promotion mode below — never in this default path). Among the remaining candidates, if two or more remain, first ask "which work should we retro first," and retro **each work separately and conversationally** — do not lump multiple works into one retro. Each work's slug is taken from the `<!-- forge-slug: ... -->` comment on the first line of the plan and used verbatim in the retro filename (`.forge/retro/YYMMDD-HHMMSS-<slug>.md`) — fg-done judges retro completion by this slug.

**Verification gate (run → verify → learn).** Before retroing a candidate, read its `STATUS.md` `verified:` field. A retro folds learnings into permanent docs, so retroing work that was never confirmed to achieve its goal risks promoting conclusions drawn from a broken result. The field gates the retro:
- **`pending` or missing** → the UAT never happened. **Do not run the normal retro yet** — route by location: an **active-slot** task (`run.md` present) goes back to **fg-run's verification-only resume** (it runs the UAT and sets `verified:` without re-executing the workflow); a **parked `executed/<slug>` task or an older run predating the gate** has no reachable fg-run handoff (active slot empty), so guide the user to confirm the UAT now (the same recovery fg-done offers) and record the outcome in its STATUS before retroing.
- **`failed`** → the UAT ran and the result is broken. **Do not retro it** — there is no stable result to fold into docs. Route to **fg-run**, which is the single owner of unparking a failed task: for a parked `executed/<slug>` task it moves the files back to the active slot before fix-and-re-run (fg-learn does not move them itself — fg-run executes only from the active slot, so it unparks the files first; see fg-run's "Failed parked-task recovery"), or re-grill via fg-ask. The task returns for retro only once a fresh run re-verifies to a sealable value.
- **`yes` / `skipped (<reason>)` / `n/a (<reason>)`** → proceed with the retro. `skipped`/`n/a` are recorded verification decisions and do not block it.

If the input files are missing, point to the prior step. If `run.md` is missing (and `executed/` is also empty), execution hasn't finished yet, so tell them to run `fg-run` first. If even `plan.md` is missing, guide them through the order `fg-ask` → `fg-run`. If the active `.forge/` is empty, it means there's no work in progress, so recommend opening new work with `fg-ask` first — unless the user asked for batch promotion (below), which reads `done/`, not the active state.

## Batch promotion mode (deferred retros of auto-skipped tasks)

The orchestrators that auto-skip retros — `fg-next all` (ADR-0010) and `fg-loop` (ADR-0016), plus fg-run's own skip path — all promise "learnings stay in the archived run.md; a human promotes them later in one fg-learn batch." **This mode is that promised receiving end.** It deliberately bypasses the two exclusions above (sealed = state error; `retro: skipped` = do not re-offer), which keep guarding the default path.

- **Entry is explicit only.** Enter when the user asks for it ("일괄 승급" / "batch promotion" / following an auto-skip handoff that pointed here). Never enter it implicitly, and orchestrators never invoke it automatically.
- **Candidates** = sealed tasks in `.forge/done/*/STATUS.md` whose `retro:` reads `skipped (...)` — the set that carries the "promote later" promise. Exclude legacy tasks with no `retro:` field and tasks already retro'd (a path in `retro:` or a matching `.forge/retro/*-<slug>.md`).
- **Per task**, read its archived `done/<date-slug>/run.md` (and plan.md) and review conversationally, one task at a time — the same retro questions and classification discipline as the normal path (sections 1–3 below apply unchanged).
- **Write a retro file only where a learning clears the promotion bar** (`.forge/retro/YYMMDD-HHMMSS-<slug>.md`, slug pairing intact). "Reviewed, nothing worth promoting" is a normal, file-less outcome — do not manufacture retro files for every skipped task (restraint discipline).
- **When a retro file is written, correct that task's sealed STATUS** `retro:` field from `skipped (...)` to the retro path plus a late-promotion note, e.g. `retro: .forge/retro/2026-06-12-<slug>.md (일괄 승급 2026-06-15)` — so fg-status's table reflects reality. Seal immutability lives in `status: done`, which is never touched. Tasks reviewed without promotion keep their `retro: skipped` as is.

## Behavior

### 1. Ask retro questions

Work through the following with the human. Don't dump it all at once — draw it out in conversation.

- Did the plan match reality? Ask grounded in the divergence points in `run.md`.
- Which terms/assumptions broke? Were there concepts that newly appeared or shifted meaning during execution.
- What to do differently next time? Among process, tooling, and order of approach, what would you change.

If nothing notable happened, things went per plan, and there's nothing learned, don't stretch it out. A retro is not a ritual. Record it in one line and move on.

### 2. Classify learnings into three kinds

Split what you learned into three branches by nature and route each to its doc. Learnings that don't clear the promotion bar **all go to the retro log** — that's the reason the retro log exists.

| Nature of the learning | Destination | Promotion bar |
| --- | --- | --- |
| New/changed domain term | `CONTEXT.md` | Only if it's a context-specific concept. General concepts and implementation details are excluded |
| A decision that is hard to reverse, puzzling, and a real trade-off | `.forge/adr/NNNN-slug.md` | Only when **all three** conditions are met |
| Process/session learning | `.forge/retro/YYMMDD-HHMMSS-slug.md` | If it's worth recording |

### 3. Respect the promotion discipline

Don't push everything that came out of the retro into `CONTEXT.md` or an ADR. The reason is clear — `CONTEXT.md` is a glossary, and if implementation details and one-off noise get mixed in, the next reader stops trusting it. The same goes for ADRs: if you record even trivial decisions, the truly important ones get buried.

So learnings that don't clear the bar go to the retro log without hesitation. And **the judgment of what to promote is not made automatically.** Reflect into `CONTEXT.md`/ADR only after presenting candidates and getting the human's confirmation.

### 4. Write the docs

- The retro log always lands in `.forge/retro/YYMMDD-HHMMSS-slug.md` (one file per retro'd task, lazily created). For the format, read [RETRO-FORMAT.md](./RETRO-FORMAT.md) in the same directory as this skill and follow it.
- If you promote a term, reflect it into `CONTEXT.md`. Follow the format in `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/CONTEXT-FORMAT.md` (skill-relative path `../fg-ask/CONTEXT-FORMAT.md`).
- If you promote a decision, add `.forge/adr/NNNN-slug.md`. Follow the format in `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/ADR-FORMAT.md` (`../fg-ask/ADR-FORMAT.md`).

In the "Doc updates" field of the retro log, record what was promoted to where (or none) to leave traceability.

The following diagram shows the learning classification and re-grilling branch at a glance.

```
Read run.md · plan.md (active slot or executed/<slug>/)
   │
   ▼
Diverged a lot from the plan?
   │ yes ──▶ Guide fg-ask re-grilling (recommended before wrapping up)
   │ no
   ▼
Retro questions (conversational)
   ▼
Classify each learning (promote only past the bar, after human confirmation):
   • domain-specific term ──▶ CONTEXT.md
   • hard-to-reverse · puzzling · trade-off (all three) ──▶ new ADR
   • everything else ──▶ no promotion
   ▼
.forge/retro/ retro log   (every learning lands here, promoted or not)
   ▼
Guide fg-done + surface follow-up candidates
```

## Next-flow guidance (handoff)

When the retro is done, deliver the following at the end in natural conversational tone. Don't print a fixed template mechanically — speak as if pointing out what you just did.

- **What you just did** — you left a retro at `.forge/retro/...`, and summarize in one line what was promoted to `CONTEXT.md`/ADR (or that nothing was promoted).
- **Next step** — it's time to tidy up this work. Guide them that they can seal the work with `fg-done`, and if any follow-up work candidates surfaced during the retro, present them too. But if more retro-awaiting work remains in `.forge/executed/`, recommend **retroing the next work first** over sealing — it's better to batch retros while memory is fresh.
- **How to start** — **state** it and stop; do **not** ask "shall I seal now?" or auto-invoke fg-done (chaining is `fg-next`'s job — ADR-0015). Next is fg-done to seal; give the trigger — "작업 완료" / "봉인" / `/forge:fg-done`, or `fg-next`.

Exception — if execution diverged a lot from the plan, guide them that it's better to re-grill with `fg-ask` before going straight to wrapping up. Sealing while the plan and the actual are too far apart blurs the starting point of the next work.

## Doc impact

- Creates `.forge/retro/YYMMDD-HHMMSS-slug.md` (always, lazy).
- When the promotion conditions are met, updates `CONTEXT.md` / adds `.forge/adr/NNNN-slug.md` (after human confirmation).
- **Does NOT touch the STATUS.md `retro:` field on in-flight tasks** — it stays `pending` until fg-done fills in the retro path at seal time; retro completion is judged by the retro file's existence (slug match), not by the STATUS field (see fg-status's state machine and fg-done's close-out). The STATUS writes this skill may make are: the `verified:` field of a parked/legacy task during the verification-gate recovery, and — **in Batch promotion mode only** — correcting a *sealed* task's `retro: skipped` to the late-written retro path (never `status:`).
- On the default branch the volatile loop state is gitignored; the retro/ADR/CONTEXT docs this skill writes are git-tracked via the `.gitignore` whitelist, and a non-default branch root is tracked whole (ADR-0011).
