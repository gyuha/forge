# Handoff table — the shared shape every next-step handoff renders

This is the **single definition** of forge's handoff table. Thirteen skills reference this file; none of them restate the layout — the same no-copying rule that [`DRIVE.md`](./DRIVE.md) in this directory and [`../fg-run/FORGE-ROOT.md`](../fg-run/FORGE-ROOT.md) already carry.

**Why it exists.** The next-step guidance used to be prose, and it got lost between the sentences around it — the reported pain was **findability, not length** ("it's buried in the text, I can't find it"). Length was already handled, behind the `eco` gate (ADR `260730-230321`). A table fixes position: it is a shape, so where the next step lives never moves. Rationale and the seven rejected alternatives: `.forge/adr/260805-231104-handoff-table.md`.

## The shape

The row labels below are **canonical English names**, the same convention as [`../fg-run/PLAN-FORMAT.md`](../fg-run/PLAN-FORMAT.md) and [`../fg-learn/RETRO-FORMAT.md`](../fg-learn/RETRO-FORMAT.md): every skill's body refers to a cell by its canonical name, and every skill **renders it in the user's language**. See "Language" below for what translates and what does not.

```
| Item         | Detail                                  |
|--------------|-----------------------------------------|
| Just did     | {what this skill just did, one line}    |
| Next step    | {the next skill and its role}           |
| How to start | {the trigger — phrase and/or /command}  |
| Alternative  | {the other route, or omit the row}      |
```

- **The header row is mandatory.** GitHub-flavored markdown does not render a table without a header **and** delimiter row — a header line plus `|---|---|` is a render condition, not decoration. Drop it and the user sees pipes.
- **One line per cell.** A cell that grows past a line is the original problem coming back.
- **`Alternative` is omitted when there is no real alternative.** An empty or `—` row is noise; this table exists to make the next step findable, so a row carrying nothing works against it.
- **No prose *introducing* the table, and the table is the last thing on screen.** Do not write a sentence that announces or paraphrases the handoff before rendering it — anything the reader needs before deciding goes into `Just did`. This is **not** a ban on everything above it: a skill's own body legitimately precedes it (fg-status's status report and diagnostic layer, fg-done's seal summary, the eco summary table at task-end). Those are the skill's output, not prose introducing the handoff. The rule is: nothing between them and the table, and nothing after it.

## Language — what translates, what does not

forge's convention (CLAUDE.md, "스킬 편집 규약"): skill bodies and format documents are **written in English**, while everything a skill **puts on the user's screen follows the user's language**. This table is screen output, so it is translated at render time — and the labels above are canonical names for *referring* to a cell, never strings to copy verbatim.

| Element | Rendered as | Why |
| --- | --- | --- |
| Row labels (`Item` · `Detail` · `Just did` · `Next step` · `How to start` · `Alternative`) | **the user's language** | They are prose the user reads. A Korean session sees `방금 한 것`; an English one sees `Just did`. |
| File paths, directory names, `.forge/` state fields (`verified:`, `retro:`), `/commands` | **verbatim, never translated** | They are typed or looked up literally. A translated path is a broken path. |
| Natural-language trigger phrases in `How to start` | **the user's language, chosen from the skill's own `description`** | Each `fg-*` skill registers its triggers in **both** languages (e.g. fg-run: `'forge run'`, `'계획 실행'`). Handing an English-speaking user `"계획 실행"` gives them a cell they cannot act on. |

So `How to start` is assembled, not copied: take the target skill's `/command` verbatim, and pick the natural-language trigger matching the user's language from that skill's `description`. **A skill's body must not hard-code trigger phrases in one language** — it names the skill and its `/command`, and the language-matching phrase is selected at render time.

Rendered in a Korean session, the shape above comes out as:

```
| 항목        | 내용                          |
|-------------|-------------------------------|
| 방금 한 것  | 그릴링 종료 · 계획 적재 (#108) |
| 다음 단계   | fg-run (실행)                 |
| 시작하는 법 | "계획 실행" / /forge:fg-run    |
```

### List-shaped content goes below the table

Some skills must emit a list, and a list does not fit a cell — cramming paths in with `·` separators wraps the column and breaks it, and paths are verbatim-preserved (`../fg-eco/ECO.md`, "Terse communication"), so they cannot be shortened. Put the list **below** the table as bullets:

```
| 항목        | 내용                          |
|-------------|-------------------------------|
| 방금 한 것  | 그릴링 종료 · 계획 적재 (#108) |
| 다음 단계   | fg-run (실행)                 |
| 시작하는 법 | "계획 실행" / /forge:fg-run    |

검토할 문서:
· .forge/backlog/<slug>.md
· .forge/CONTEXT.md
```

**Nine wired sites emit below-table lists** — do not compress any of them into a cell: `fg-ask` (documents this grilling created), `fg-learn` (follow-up candidates), `fg-doctor` (findings: severity · path · fix hint), `fg-loop` (per-check evidence at a wall, and the passing evidence on goal-met), `fg-agents` (the cards written), `fg-agenda` (what changed in the agenda), `fg-adversarial-review` (fix-forward ordering), `fg-run` (the adversarial-review pointer), `fg-done` (the git-commit reminder). Two of these — fg-doctor's fix hints and fg-loop's evidence — are the reason the rule exists: squeezing them into one line destroys the only actionable content the skill produced.

## A conditional next step needs a precedence rule, never a hard-coded row

**This is the failure mode this shape invites, and it has been found repeatedly.** Prose could hedge — "seal it, but if the run diverged a lot, re-grill first". A fixed cell cannot: whoever writes the wiring picks one branch, the other becomes an `Alternative` that may be omitted, and the table ends up **telling the user to do the thing the skill just advised against**. Worse, `How to start` then ships a working trigger for it.

So when a skill's next step depends on state, **write the branch rule and let it fill the cells** — do not name one outcome in the row and leave the other in a sentence:

```
Read the state → first matching case wins → that case fills Next step + How to start
                                          → the runner-up, if any, is Alternative
```

`../fg-run/SKILL.md` ("Divergence shapes the `Alternative` cell") and `../fg-learn/SKILL.md` ("Divergence shapes the cells", a 3-case precedence) are the worked examples. Three further rules:

- **Never assert in a cell what is only sometimes true.** `Just did` is the usual offender — "the active state is now empty" is false the moment one task was set aside. If a path can make the sentence false, branch it or drop the claim.
- **Order is fixed, so "lead with X" is not an instruction.** The rows are always `Just did · Next step · How to start · Alternative`. A hint that a route should be *preferred* must change **which case wins**, not the row order — otherwise it is a no-op.
- **Do not give one fact two owners.** If another block already renders something (a seal summary, an eco chapter), the table references or omits it. Two renderings of the same fact is the duplication these shapes exist to remove.

## THE TABLE IS NOT A MENU

This is load-bearing, not a caveat. ADR-0015 (amended 2026-06-15) abolished fg-run's four-option `AskUserQuestion` handoff because it **re-triggered on unchanged active-slot state and looped**: the state that produced the menu (`executed` + `verified:` sealable + `retro: pending` + unsealed) persists after the answer, and there was no "already shown" marker, so re-evaluating the handoff showed the same menu again. Retro `.forge/retro/2026-06-15-fg-run-handoff-statement-form.md` names the root cause an idempotency defect and concludes a statement-form handoff is **structurally idempotent — it has no notion of re-presenting**.

So, without exception:

- **Never render this table via `AskUserQuestion`.** It is text output.
- **The `Alternative` row is not a question.** It states that another route exists; it does not ask which one to take.
- **State and stop.** No "shall I proceed?", no auto-invoking the next skill — chaining is `fg-next`'s job (ADR-0015).

**Consistency across all thirteen points IS the idempotency guarantee.** That same retro's second lesson: fg-run being the one convenience exception was the only repeatable point in the loop. An exception "just here" re-opens the failure mode, so do not make one.

## Where it applies

**Applies (13)** — every point that has a real next step to name:

| Group | Skills |
| --- | --- |
| Loop stages | `fg-ask` · `fg-run` · `fg-learn` · `fg-done` |
| Outside-the-loop, with a next step | `fg-status` · `fg-next` · `fg-loop` · `fg-quick` · `fg-map` · `fg-doctor` · `fg-agenda` · `fg-adversarial-review` · `fg-agents` |

**Does NOT apply (7)** — leave their prose as it is:

| Skills | Why |
| --- | --- |
| `fg-tdd` · `fg-eco` · `fg-statusline` | Toggles and setup: there is nothing to point at, and their one-line body is already shorter than any table |
| `fg-cleanup` · `fg-drop` · `fg-visual` | They emit no next-step guidance at all — there is nothing to reshape |
| `fg-merge` | Excluded on a narrower rationale: what it emits are **git-state recovery instructions** ("resolve the conflicts, `git commit`, then run `fg-merge`"), not a loop handoff. It is the weakest line in this split — if the recovery instruction should be a table, wire it; do not defend the exclusion by claiming the file is silent, because it is not |

Applying it everywhere was considered and rejected: a toggle would render three rows of `—`, so a table meant to make the next step findable would instead pad the output with rows carrying no information.

## Unattended drives — the delegated skill renders NO table

**Inside `fg-next all` or `fg-loop`, a delegated skill does not render its handoff table at all.** The driver owns the user-facing report; it renders one table for its own step — the wall it halted at, or the drive's completion.

This is not a style preference. [`DRIVE.md`](./DRIVE.md) forbids relaying a delegated skill's next-step line to the user in a drive, because being told "run fg-learn" while the drive auto-skips the retro is **the primary way the "keeps telling me to run fg-learn, never seals" stall happens**. A table makes that worse than the prose did: a table reads as an instruction. So the drive exception is mandatory, and it applies to the whole table, not just the `Next step` row.

The delegated skill cannot detect its caller (the same limit ADR-0015 documented for fg-run's handoff), so **the driver suppresses it**: `fg-next` in `all` mode and `fg-loop` instruct the steps they invoke not to render, exactly as they already suppress the delegated seal summary (ADR-0032). One-shot `fg-next` is different — it runs a single step for a human who is reading, so that step's table is wanted; but when the one-shot chains learn→done (ADR-0026), **only the last step in the chain renders**, or the user gets a live trigger for something already done.

```
human invokes a skill directly      → that skill renders its table
fg-next (one-shot)                  → the invoked step renders; on a learn→done chain, only fg-done
fg-next all · fg-loop               → no delegated table; the driver renders at its wall / completion
```

## Interaction with eco — a role split, not a precedence rule

When `eco` is `true` in the **top-level** `.forge/config.json` (a global exemption — never the branch root; treat as off if the file or key is absent), the **human-facing** task-end points — `fg-run`'s handoff, `fg-done`'s explicit single seal, and `fg-run`'s Run-all batch end — already render the **eco summary table**, defined once in [`../fg-eco/ECO.md`](../fg-eco/ECO.md), section "eco summary table". Do not restate that layout here or there.

**Unattended drives are not in this list.** Inside `fg-next all` / `fg-loop` a delegated step renders nothing at all (see the section above), so there is no handoff table to combine there; the driver's own accumulated eco rows stand alone, per [`DRIVE.md`](./DRIVE.md). Run all is a human-facing batch end, **not** a drive — it stops at the retro — so it does render.

Two rows move, in opposite directions, so nothing is said twice:

- **Drop the handoff table's `Just did` row** (→ 3 rows) **at the single-task points only** — there, eco's `▸ Done` slice table already carries it in more detail. At a **batch** point (`fg-done all`, Run all) eco's batch shape is one row per task with no slice chapter, so it does **not** subsume `Just did`: keep that row there.
- **Drop the eco summary table's `▸ Next` line.** The handoff table owns the next step; rendering both puts the next step and its trigger on screen twice, which is the duplication this whole design exists to avoid. **This table is the single owner of the next step at every point, in both modes.**

```
eco off  →  4 rows (Just did · Next step · How to start · Alternative)
eco on   →  eco summary table WITHOUT ▸ Next, then 3 rows (Next step · How to start · Alternative)
```

**The payoff is the point**: the next-step portion looks identical whether eco is on or off. Findability must not vary by mode — if it did, the pain this table fixes would only be half fixed.

## Material — read it, never invent it

Every cell is filled from something that actually exists. These are specified, not conventional:

| Cell | Source |
| --- | --- |
| `Just did` | what the skill did this turn; at task-end, the per-slice lines in `run.md` (`../fg-run/SKILL.md` §4, "Record one line per work slice") |
| `Next step` | fg-status's next-step state machine (`../fg-status/SKILL.md`, "Deriving the next step") — the single derivation, not a re-guess |
| `How to start` | the target skill's `/command`, plus the trigger phrase matching the user's language from that skill's `description` (see "Language" above) |
| `Alternative` | the divergence-conditional route (e.g. low divergence → skip retro and seal, ADR-0002), when one genuinely applies |

At task-end the plan's `Goal` (`../fg-run/PLAN-FORMAT.md`, `## Goal / Non-goals`) and STATUS's `verified:` / `retro:` (`../fg-run/SKILL.md` §4) are the other specified fields. **Never write a result you cannot read** — if the material is missing, say so rather than filling the cell.

Flow: skill finishes → read material (run.md slice lines · STATUS · state machine) → render table (user's language) → list-shaped extras as bullets below → stop
   └── eco on at a task-end point → eco summary table (minus `▸ Next`) first, then the table minus `Just did`
   └── inside an unattended drive → render NO table; the driver reports (see "Unattended drives" above)

## Scope

This is **screen output only** — it is never written to a file, which is why it is not a `*-FORMAT.md` (that convention is for documents generated into the user's project). The state contract, the verification gate (ADR-0009), the seal script (ADR-0030), and the retro gate (ADR-0002) are all untouched; this is purely the output layer.
