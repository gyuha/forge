---
name: fg-debug
description: Conversational diagnosis for hard bugs and performance regressions, vendored from mattpocock/skills diagnosing-bugs. Build a red-capable loop, reproduce and minimise, rank hypotheses with the human, then instrument. Diagnosis only — an active verified failure returns to fg-run fix-and-re-run; an independent diagnosis routes a trivial fix to fg-quick or an approved non-trivial fix to a new plan. Always skipped in fg-next all / fg-loop. Use for 'debug this', 'diagnose', '디버깅해줘', '버그 잡아줘', '왜 안 되지', '왜 느리지'.
---

# fg-debug — bug diagnosis (outside the loop)

This is **not** a stage of the forge loop. It is an on-demand utility (like `fg-security` / `fg-adversarial-review`) that diagnoses a hard bug or performance regression down to its root cause, then feeds the diagnosis into the fix lane selected by invocation state.

**The methodology is not forge's.** It is [mattpocock/skills](https://github.com/mattpocock/skills) `diagnosing-bugs`, vendored here under MIT (see `LICENSE`): a phased diagnosis discipline — build a tight red-capable feedback loop, reproduce and minimise, generate 3–5 ranked falsifiable hypotheses, instrument one variable at a time. **Read [`DIAGNOSE.md`](./DIAGNOSE.md) and follow its Phases 1–4** — that file is the method's single definition and this skill never restates or forks it (the same file-reference convention as `../fg-security/AUDIT.md` and `../fg-config/ECO.md`). Do **not** edit `DIAGNOSE.md`, `scripts/hitl-loop.template.sh`, or `LICENSE`: they are kept byte-for-byte with upstream so a future diff stays cheap (only the entry file was renamed, `SKILL.md` → `DIAGNOSE.md`, to avoid forge's skill auto-discovery — the `../fg-security/AUDIT.md` precedent), and forge's own glue lives here instead. Rationale: `.forge/adr/260907-140655-fg-debug-vendored-diagnosis.md`.

**What forge adds** is exactly three things — everything else is upstream's:

1. the diagnosis **stops where `DIAGNOSE.md`'s Phase 5 begins** — the invocation state determines whether the result returns to the active task or enters an independent fix lane, and the fix is never applied here,
2. **no new `.forge/` state** — only sanitized fixtures or persistent checks may remain in the project's working tree; sensitive and temporary material does not,
3. a documented position in the unattended lanes (always skipped).

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, the ranked hypothesis list, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** `DIAGNOSE.md`'s procedure is followed as written; its *output to the user* is rendered in the user's language, and any backlog plan this skill produces is written in the user's language.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Forge root**: every `.forge/...` read or write below is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before inspecting the active slot or writing a fix plan (ADR-0011).

## Conversational, by construction

This skill runs **in-session, never inside a delegated workflow**. `DIAGNOSE.md`'s Phase 3 shows the ranked hypothesis list to the user *before* testing any of them — a live checkpoint that a delegated execution (which takes no user input mid-run) cannot honor. That is pillar 1 (grilling-class interaction stays conversational), and it is also why the unattended drives skip this skill entirely (see below). fg-run's `verified: failed` handoff may recommend coming here when the cause is unknown — that advisory line lives in `../fg-run/SKILL.md`, not here.

## Route by invocation state before diagnosis size

Before Phase 1, inspect the resolved active slot's `plan.md`, `run.md`, and `STATUS.md`. This classification outranks fix size:

1. **Active failure invocation** — an active slot at `verified: failed` means this diagnosis belongs to that existing task. Keep its plan/run/STATUS untouched. A confirmed diagnosis always returns the diagnosis package to fg-run's existing **fix-and-re-run** path, even when the fix is trivial; never create a backlog plan and never divert it to `fg-quick`. An inconclusive diagnosis leaves the failed task active while requesting the missing input described below.
2. **Independent invocation** — when no active `verified: failed` task owns the diagnosis, classify the confirmed fix by size after diagnosis: a typo-class, one-line, low-risk fix bails to `fg-quick`; a non-trivial fix may become a new backlog plan after human approval.

The **diagnosis package** contains the confirmed root cause, the minimized reproduction, the Phase 1 command and its persistence classification, rejected hypotheses, retained sanitized artifacts, and required cleanup. This gives either execution lane evidence without creating a second diagnostic ledger.

## Phase 1 artifacts — persistent, one-off, and sensitive

At the moment Phase 1 selects its red-capable command, **classify whether it is a persistent regression check or one-off diagnostic evidence**:

- A persistent check is a project-owned test or equivalent executable check intended to remain after sealing. Prefer a failing test at the correct seam.
- `curl`, trace, HITL, ad-hoc scripts, temporary instrumentation, and throwaway harness commands are one-off unless they actually invoke such a project-owned persistent check. Going red once does not make them an eval.

For a freshly generated fix plan, a one-off command requires either a separate work slice that converts the reproduction into a persistent check or the exemption prescribed by [`../fg-run/PLAN-FORMAT.md`](../fg-run/PLAN-FORMAT.md). PLAN-FORMAT is the single definition; do not copy its rule here. For an active failed task's in-place repair, carry the persistence classification and recommended regression check (or why it cannot be persisted) in the diagnosis package for fg-run's existing fix-and-re-run path; do not edit the already-run plan.

Only a **confirmed-sanitized fixture** and a **persistent test/check** may remain in the project's working tree. Original traces, HAR files, logs, authentication headers, personal data, or other possibly sensitive captures must be collected and inspected only in an OS-managed temporary location **outside the project's working tree**. Create no `.forge/debug/` or any other new `.forge/` state (ADR `260907-140655`, decision 3).

Before **every exit path** — confirmed, either inconclusive case, active-task return, generated-plan handoff, or `fg-quick` bail — delete raw captures, temporary instrumentation, and throwaway harnesses. The diagnosis package lists every sanitized artifact deliberately retained. The active repair scope, new fix plan, or `fg-quick` scope must own Phase 6 cleanup and verification for any retained sanitized fixture that is not meant to survive; persistent regression checks remain.

## The boundary — diagnosis ends where Phase 5 begins

Follow `DIAGNOSE.md` through Phase 4 (instrument) until one hypothesis is confirmed or further progress lacks evidence. Then **stop**. fg-debug never applies the fix, and never creates `run.md` / `STATUS.md` or edits the active slot — a fix applied here would bypass the loop's re-run guard, verification gate (ADR-0009), and eval promotion (ADR `260907-140655`, decision 2). Route by invocation state first, then outcome:

1. **Active failure + confirmed root cause** → return the diagnosis package to the existing fg-run fix-and-re-run path. This case wins even when the implementation change is trivial. The active slot remains the only task record.
2. **Active failure + inconclusive** → leave the task at `verified: failed`, clean up, and request the missing evidence below; re-invoke fg-debug when it arrives. Do not invent a fix and do not route around the occupied slot.
3. **Independent + inconclusive** → clean up and request the missing evidence below. No plan is written from an unconfirmed hypothesis.
4. **Independent + trivial confirmed fix** → **bail to `fg-quick`** and fix it there; its LOG line is the only task record. This is the already-approved lightweight lane (ADR-0003), not a new bypass. Hand its scope the diagnosis package and any safe Phase 6 cleanup.
5. **Independent + non-trivial confirmed fix** → on the human's approval (never automatically), write a new `.forge/backlog/<slug>-fix.md` (or a descriptive slug) carrying `<!-- generated-by: fg-debug -->` and a fresh **monotonic** `<!-- task: N -->` (scan all `task:` markers across backlog/active/executed/done, max+1 — same rule as `fg-adversarial-review`). The plan carries the diagnosis package, follows PLAN-FORMAT's fix-forward eval rule, and includes Phase 6 cleanup and its verification.

**Inconclusive has two evidence-based shapes.** If no feedback loop could be built, list the attempts and request environment access, a redacted artifact, or permission for temporary instrumentation. If a feedback loop exists but the root cause remains unconfirmed, preserve the red command and rejected hypotheses, then request the additional instrumentation, domain information, or reproduction environment needed to discriminate the remaining hypotheses. Both shapes clean temporary material, state the exact missing input, and tell the user how to re-invoke fg-debug.

## Unattended lanes — always skipped

`fg-next all` (ADR-0010) and `fg-loop` (ADR-0016) **never run this skill**, the same way they auto-skip the retro and `fg-adversarial-review`: ranking hypotheses with a human is conversational work, and an unattended drive cannot make that call. It is invoked deliberately, by a human.

```
fg-debug ("debug this" / "디버깅해줘")
   │
   ▼
classify invocation state
   ├─ active slot at verified: failed ─▶ active-failure lane (size never reroutes it)
   └─ otherwise                        ─▶ independent lane
   ▼
follow DIAGNOSE.md Phases 1–4 (upstream, unedited)
   feedback command → classify persistent vs one-off → reproduce + minimise
   → ranked hypotheses (shown to the user) → instrument
   │  sensitive captures = outside-working-tree temporary location
   ▼
result (clean raw captures + temporary instrumentation + throwaway harness on every exit):
   ├─ active + confirmed      ─▶ diagnosis package ─▶ existing fg-run fix-and-re-run
   ├─ active + inconclusive   ─▶ keep verified: failed ─▶ missing evidence ─▶ re-invoke fg-debug
   ├─ independent + trivial  ─▶ fg-quick (diagnosis + safe cleanup scope)
   ├─ independent + nontrivial ─▶ human approves ─▶ generated fix plan
   │                              (PLAN-FORMAT eval rule + safe cleanup slice) ─▶ fg-run
   └─ independent + inconclusive ─▶ missing evidence ─▶ re-invoke fg-debug
```

## Handoff

Render the **handoff table** per [`../fg-next/HANDOFF.md`](../fg-next/HANDOFF.md) — the single definition of its shape; never restate that layout here. Statement form, in the user's language, then **stop** (chaining is `fg-next`'s job — ADR-0015).

`Just did` is the one-line verdict: the confirmed root cause (or that none was reached), the Phase 1 command and whether it is persistent or one-off, and the cleanup outcome. Fill the rest from the **first matching case**:

- **Active failure + confirmed root cause** → `Next step` = fg-run's existing fix-and-re-run path for this active task; `How to start` = `/forge:fg-run`; omit `Alternative`. Never point to a new plan or `fg-quick` here.
- **Active failure + inconclusive** → `Next step` = provide the stated missing evidence, then re-invoke fg-debug while the failed task remains active; omit `Alternative`.
- **Independent + inconclusive** → `Next step` = provide the stated missing evidence, then re-invoke fg-debug; omit `Alternative`.
- **Independent + trivial fix completed through fg-quick** → `Next step` = nothing is owed — state that plainly; omit `Alternative`.
- **Independent + approved fix plan created** → `Next step` = `fg-run`, to promote and run the generated plan — note that the active slot must be free (an occupied slot finishes first); `How to start` = `/forge:fg-run`; omit `Alternative`.

The rejected hypotheses and the attempted loop constructions are list-shaped, so they go **below** the table as bullets (HANDOFF.md's rule) — never compressed into a cell.

## Document impact

- Reads the active slot to classify the invocation, but never edits `plan.md`, `run.md`, `STATUS.md`, `executed/`, or `done/`. An active failure returns a conversational diagnosis package to fg-run's existing fix-and-re-run path.
- On the human's approval for an independent non-trivial fix, creates `.forge/backlog/<slug>-fix.md` (`<!-- generated-by: fg-debug -->`, monotonic `task:`) — picked up by `fg-run`.
- May leave only a confirmed-sanitized fixture or persistent test/check in the project's working tree. Raw sensitive captures live outside it temporarily; raw captures, temporary instrumentation, and throwaway harnesses are removed on every exit. Any retained safe artifact that should not survive is assigned to the active repair, generated plan, or `fg-quick` Phase 6 cleanup scope.
- Creates no diagnostic `.forge/` state. It is not a loop stage.
- Does not modify the vendored `DIAGNOSE.md`, `scripts/hitl-loop.template.sh`, or `LICENSE`.

## Credits

The diagnosis methodology is vendored from [mattpocock/skills](https://github.com/mattpocock/skills) `diagnosing-bugs` (MIT, see `LICENSE`) — byte-for-byte, entry file renamed only (`SKILL.md` → `DIAGNOSE.md`).
