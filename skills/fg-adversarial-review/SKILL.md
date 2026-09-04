---
name: fg-adversarial-review
description: Optional adversarial review between fg-run and fg-learn — a reviewer assumes the result is WRONG and hunts for evidence across six lenses (failure points, hidden assumptions, misread requirements, security/perf/data-loss, unexpected misuse, weak decisions), fanning out as parallel subagents; fix-needed findings become a fix-forward plan on your approval. Outside the loop, never a seal gate, always skipped in fg-next all / fg-loop. Use in contexts like 'adversarial review', '적대적 리뷰', '이 결과 공격적으로 검토', '허점 찾아줘', 'red team this'.
---

# fg-adversarial-review — optional adversarial review (outside the loop)

This is **not** a stage of the forge loop. It is an on-demand utility (like fg-map / fg-status) that sits **between fg-run and fg-learn**: after a plan has run and its UAT has set `verified:`, you may optionally run an adversarial review **before** the retro. The 4-stage loop shape (ask → run → learn → done) is unchanged — this is a side utility, not a fifth stage (ADR-0007 rejected a formal stage here; ADR-0018 reintroduces it as an outside-the-loop option instead).

Its stance is deliberately hostile: the reviewer takes the position of the **attacker, the contrarian, the user who triggers failure**, and starts from **"assume this result is wrong, and find the evidence."** It is not a quality pat-down (that is ADR-0007's automatic code review inside the fg-run workflow); it is a deep, skeptical attempt to *break* the work.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, findings, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** All documents this skill generates for the user's project (the review notes, any fix-forward plan, handoff messages) are written in the user's language.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Host contract**: the six lenses fan out in parallel, so this skill needs the host's `spawn_parallel` capability. Read [../../core/HOST.md](../../core/HOST.md) and [../../core/EXECUTION.md](../../core/EXECUTION.md), then check `../../hosts/<host>/capabilities.json`. When `spawn_parallel` is `false` or the host is unknown, **run all six lenses serially** — the lens set, the `.forge/review.md` record, the human-approval gate, and the non-gating rule are unchanged; only the delegation is.

**Forge root**: every `.forge/...` path below is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before reading or writing state (ADR-0011).

## When to run

Run it after fg-run has executed a plan — i.e. the **active slot** holds a `run.md` — when you want a hostile second look before sealing. It is **purely optional** — skipping it never blocks the seal (the seal gates are `verified:` and the retro, never `reviewed:`).

**The review targets the active slot only.** This keeps findings storage unambiguous: they always belong to the one task in the active slot. A task parked in `executed/<slug>/` (Run-all work awaiting retro) is **not** a review target, and **fg-run cannot unpark a sealable parked task** — its unpark path is deliberately limited to `verified: failed` recovery. Therefore run this review before choosing Run all / before the task parks. If it is already parked and sealable, finish its retro/seal; this skill does not invent a temporary unpark path. (Supporting per-task `executed/<slug>/review.md` storage was considered and rejected — it would add fg-learn/fg-done branching for a rare case; ADR-0018.)

If there is no `run.md` in the active slot, there is nothing to review — say so in one line and point to fg-run — do not invent a review target.

## Inputs (what it reviews)

Read these as the review target:

- **`.forge/plan.md`** — the intent, requirements, and design (the standard the work is judged against).
- **`.forge/run.md`** — plan-vs-actual divergences (where the executor already noticed friction).
- **The current working-tree changes** — `git diff` (tracked) **plus untracked files**. forge does not force commits, so right after fg-run the work is usually uncommitted; this diff is the actual artifact to attack. (If the work was already committed, fall back to the most recent commit(s) for this task, or the plan's work scope.)
- **Source of truth** — `.forge/CONTEXT.md` and the plan's referenced `.forge/adr/*` — the basis for judging "misread requirements" (a finding that the work contradicts a documented term or decision is far stronger than a vague worry).

## The six lenses

Each lens is an independent angle of attack. They are the dimensions of the fan-out below — one (or more) subagent per lens, each blind to the others so it surfaces what a single pass would miss:

1. **Where it fails** — if this design fails, where? Construct concrete failure scenarios.
2. **Hidden assumptions** — what did the author take for granted (environment, inputs, ordering, scale)?
3. **Misread requirements** — does the result diverge from what the plan / CONTEXT / ADRs actually asked for?
4. **Security · performance · data loss** — exploitable input, injection, unbounded cost, destructive or irreversible operations.
5. **Unexpected misuse** — what happens when a user uses it in a way nobody intended?
6. **Weak / unverified decisions** — which choices rest on thin or untested grounds?

The default posture for every lens: **assume the artifact is wrong and produce the evidence.** A lens that finds nothing real reports "no finding" — do not manufacture findings to fill a quota (restraint discipline, same as the retro promotion bar).

## Behavior

### 1. Gather inputs and build the adversarial workflow

Collect the inputs above, then build a **Dynamic Workflow** that fans the six lenses out as parallel subagents. Adversarial review needs no human input mid-run (it is analysis, not grilling — so it does **not** violate pillar #1), which is exactly why a workflow fits: independent lenses in parallel are more thorough than one sequential pass (the Workflow tool's `dimensions → find → adversarially-verify` pattern).

- **Compose with the workflow's own subagents** (core `Agent`/`Workflow`) — **no external hard dependency.** If a review capability (e.g. a `code-review` skill, or specialized reviewer subagents) is available you may lean on it as optional reinforcement, but never hard-depend on one (ADR-0007 portability principle).
- **Per lens**, the subagent attacks the artifact from that angle and returns structured findings: `{lens, title, severity (critical/major/minor), evidence, where (file:line), suggested fix, fix-needed (bool)}`.
- **Optionally add an adversarial-verify pass** — a second wave of skeptics that tries to *refute* each surfaced finding, so plausible-but-wrong findings are dropped before they reach the human (the Workflow adversarial-verify pattern). Scale this to how thorough the user asked for.
- **Get script approval first** (same as fg-run), then run it in the background; observe with `/workflows`.

### 2. Record findings to .forge/review.md

When the workflow finishes, write the consolidated findings to **`.forge/review.md`** (volatile, in the active slot next to plan.md/run.md — written in the user's language). Carry the plan's `<!-- forge-slug: <slug> -->` on the first line so it pairs with the task. Structure: a one-line verdict (N findings, M fix-needed, by severity), then the findings grouped by lens with severity / evidence / where / suggested fix each. This file travels with the task: fg-done archives it into `done/<date-slug>/` at seal, and fg-learn reads it as retro-promotion input.

Also record a `reviewed:` marker in the active-slot `.forge/STATUS.md` — **for the record only, never a seal gate**: `reviewed: .forge/review.md (N findings, M→fix-forward)` (or `reviewed: skipped (<reason>)` if the review was deliberately abandoned). Do not touch `verified:` or `retro:` — those remain the only gates.

### 3. Handoff — present findings, route fixes

Because the workflow can't take human input mid-run, the judgment happens here, conversationally. Present the findings and let the human decide each fix-needed one. Route by nature (reusing the existing fix loop — ADR-0009 routing, but driven from review findings):

- **Code-level defects** (security, performance, bugs in the implementation) → a **fix-forward** plan: on the human's approval, write a new `.forge/backlog/<slug>-fix.md` (or a descriptive slug) carrying `<!-- generated-by: fg-adversarial-review -->` and a fresh **monotonic** `<!-- task: N -->` (scan all `task:` markers across backlog/active/executed/done, max+1 — same rule as fg-ask / fg-loop fix-forward, ADR-0016). The original reviewed task still occupies the active slot, so **seal the original task first** (`fg-learn` → `fg-done`) and only then invoke `fg-run` for the fix-forward backlog plan. Calling fg-run first would hit the original task's duplicate-run guard instead of promoting the fix.
- **Design / requirement defects** (the plan itself was wrong, a requirement was misread) → this is not a code fix; point to **fg-ask** to re-grill the plan. A fix-forward plan can't paper over a wrong premise.
- **Accepted / minor** → no action; the findings stay in `.forge/review.md` and feed the retro (fg-learn promotes anything worth keeping).

**Plan generation is human-approved, never automatic** — the workflow outputs findings; turning a finding into a backlog plan happens here, after the human confirms (forge's human-confirmation discipline). Do not auto-create fix-forward plans without sign-off.

### 4. Then point back to the loop

The adversarial review is done; the loop resumes where it was. State (do not ask) the next step as the **handoff table** per [`../fg-next/HANDOFF.md`](../fg-next/HANDOFF.md) — the single definition of its shape; never restate that layout here. It closes §3's conversation: the routing above is the judgment, this table is where it lands.

`Just did` is the same whatever the verdict was: the one-line verdict (N findings, M fix-needed, by severity), that they are recorded in `.forge/review.md`, and that `reviewed:` was noted in STATUS — record-only, never a seal gate.

**§3's routing decides the remaining rows — as a precedence rule, never a hard-coded next step** (HANDOFF.md, "A conditional next step needs a precedence rule, never a hard-coded row"). Let the **first matching case** fill `Next step` / `How to start`, with its runner-up as `Alternative`:

1. **§3 routed a design / requirement defect to a re-grill** (the plan itself was wrong, a requirement was misread) → `Next step` = **`fg-ask`**, to re-grill the plan; `How to start` = `/forge:fg-ask`; `Alternative` = settling the original task first (`fg-learn` → `fg-done`), then re-grilling. This case wins even when code findings were raised too — the premise is settled before what was built on it. Retro-and-seal is **never** `Next step` here: that cell would hand the user a live trigger for sealing the very task whose plan this review just found wrong.
2. **Fix-needed code defects only** (§3's fix-forward route, whether or not a plan was approved) → `Next step` = the original task, still at "verified, un-retro'd" — **`fg-learn`** to retro (the findings are now retro fuel), then **`fg-done`** to seal and free the active slot **for the fix-forward run**; `How to start` = `/forge:fg-learn`; omit `Alternative`. `fg-run` is deliberately not this cell: the original still holds the active slot, so calling it first hits that task's duplicate-run guard (§3) — the fix-forward's turn is stated below the table instead.
3. **Nothing needs a fix** (findings accepted / minor, or none at all) → `Next step` = **`fg-learn`** to retro, then **`fg-done`** to seal; `How to start` = `/forge:fg-learn`; omit `Alternative`.

**When a fix-forward plan was created**, add one line **below** the table: it waits safely in the backlog and `fg-run` promotes it **after the original seal**. State that order explicitly — original retro/seal first, fix-forward run second — and keep it out of `Next step`, which names the immediate step only (calling fg-run first hits the original task's duplicate-run guard, §3).

Do not chain into the next skill yourself (chaining is `fg-next`'s job — ADR-0015); state the trigger and stop.

```
fg-adversarial-review
   │
   ▼
active-slot run.md present?
   │ no  ──▶ "nothing to review" → point to fg-run (parked sealable tasks are unsupported here; review before parking) → stop
   │ yes
   ▼
Gather inputs (plan · run.md · git diff+untracked · CONTEXT/ADR)
   ▼
Build Dynamic Workflow: 6 lenses fan out in parallel (+ optional adversarial-verify)
   ▼  (script approval → background run)
Consolidate findings → .forge/review.md  (+ STATUS reviewed:, record-only)
   ▼
Handoff (conversational — workflow took no human input mid-run):
   • code defect      ──▶ (human approves) new fix-forward backlog plan (generated-by marker, monotonic task)
   • design/req defect ──▶ point to fg-ask (re-grill — a wrong premise can't be patched)
   • accepted/minor   ──▶ stays in review.md → retro fuel
   ▼
Point back (first matching case): design/req defect ──▶ fg-ask (re-grill; seal-first is the Alternative)
                                  otherwise          ──▶ original task → fg-learn → fg-done (free slot) → then fix-forward → fg-run
                                  (state triggers, don't chain)
```

## Automatic mode — always skipped

`fg-next all` (ADR-0010) and `fg-loop` (ADR-0016) drive tasks unattended and **never run this review** — they skip it the same way they auto-skip the retro. The reason: an adversarial review's value is the human judging which findings are real and which deserve a fix, and an unattended drive cannot make that call. So the drives go straight `run → verify → (auto-skip retro) → seal`, and the review remains a thing a human invokes deliberately on a task they want to scrutinize.

## Portability

The review is composed from the workflow's own `Agent`/`Workflow` subagents, so it has **no external hard dependency** — it works in any environment that runs forge. External review skills, if present, are optional reinforcement only (ADR-0007 principle). Never block the review on a specific external skill being installed.

## Document impact

- Creates `.forge/review.md` — consolidated adversarial findings (volatile, active slot; archived into `done/<date-slug>/` by fg-done at seal, read by fg-learn as retro fuel). Lazy creation.
- Records `reviewed:` in the active-slot `.forge/STATUS.md` — **record-only, not a seal gate** (the gates stay `verified:` and the retro).
- On the human's approval, creates a fix-forward `.forge/backlog/<slug>-fix.md` (`<!-- generated-by: fg-adversarial-review -->`, monotonic `task:`) — picked up by fg-run.
- Does **not** modify `.forge/plan.md` or `.forge/run.md` (the review reads them; it does not rewrite the task's record).
- On the default branch the volatile files (`review.md`, STATUS, backlog plan) are gitignored; on a non-default branch the branch root is tracked whole (ADR-0011).
