---
name: fg-loop
description: Goal-driven momentum loop with bounded replan (ADR-0016). An initial conversational inquiry pins a machine-verifiable stop condition, a pre-authorized fix-forward replan scope, and a replan cap (default 3 rounds) into .forge/loop.md, then loads the initial backlog and drives tasks run → UAT → auto-skip retro → seal until the stop-condition checks pass — auto-generating fix-forward tasks for failing checks within the cap. Halts at the walls (unverifiable UAT, genuine design fork, cap exhausted, no progress) and hands back to the human. An on-demand orchestrator outside the loop. Use in contexts like 'forge loop', '루프 시작', '조건 충족까지 반복', 'goal loop'.
---

# fg-loop — goal-driven loop with bounded replan (outside the loop)

This is **not** a stage of the forge loop. It is a goal-driven orchestrator: one upfront conversational inquiry fixes a **machine-verifiable stop condition**, then fg-loop drives whole task loops (run → verify → auto-skip retro → seal) **until the stop-condition checks pass** — including, within explicit bounds, generating its own fix-forward tasks when checks fail. It is the third lane next to the formal loop (retro conversation included) and `fg-next all` (drain the human-grilled backlog, halt at empty): fg-loop converges on a goal instead of merely draining a queue. Rationale and the three bounds: `.forge/adr/0016-fg-loop-goal-driven-bounded-replan.md`.

**This deliberately relaxes pillar #1 within bounds** (the precedent is fg-quick relaxing pillar #2 for trivial work — ADR-0003): fg-loop may create plans without a per-plan grilling conversation, but **only** inside the replan scope the user pre-authorized during the initial inquiry, and **never** past the cap or the walls. "The AI thinks it's done" is **not** a stop condition — only the recorded checks are.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — inquiry questions, status lines, halt reports, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** Documents it writes into the user's project (loop.md, generated plans) are written in the user's language.

**Forge root**: every `.forge/...` path below is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before reading or writing state (ADR-0011).

## 1. Initial inquiry (conversational — outside any workflow)

Conducted as a conversation in this session, one question at a time, reusing fg-ask's grilling method (`../fg-ask/SKILL.md`) — this is where the human judgment happens, up front. It must produce two outputs before any driving starts:

1. **The goal contract → `.forge/loop.md`** (volatile state, owned by fg-loop; auto-gitignored on the default branch by the existing `.forge/*` pattern):

   ```md
   # LOOP — {one-line goal}
   started: {YYYY-MM-DD}
   replan-round: 0
   replan-cap: 3

   ## Stop-condition checks (ALL must pass)
   - [ ] C1. {agent-runnable check — a command + expected outcome, e.g. `grep -c X file` ≥ 1, tests green, JSON parses}
   - [ ] C2. {...}

   ## Authorized replan scope
   - {what fg-loop may auto-generate without re-grilling — fix-forward tasks directly traceable to a failing check above}
   - {explicit exclusions, if discussed}

   ## Tasks
   - {slug of every plan this loop owns — the initial-inquiry plans now, each generated fix-forward plan appended at generation time}
   ```

   - **Every check must be agent-runnable** (grep/test/build/JSON — same shapes as fg-run's aggressive UAT). If the user's goal can't be pinned to runnable checks, say so and either sharpen it together or route to the formal loop (fg-ask) — do **not** start a drive on a vague goal.
   - **The replan scope is the user's pre-authorization** — the bound that makes auto-planning legitimate. Default scope when the user has no preference: "fix-forward tasks directly traceable to a failing stop-condition check, nothing else."
   - **`replan-cap`** defaults to **3** rounds; the user may set another value here.
   - **The `## Tasks` section is the loop's membership list** — the slugs of every plan this loop owns. Record the initial-inquiry plans here at creation, and append each generated fix-forward plan's slug at generation time (§3). The drive promotes **member slugs only**, so backlog plans grilled by fg-ask while the loop is halted at a wall are never swept into the unattended drive.

2. **The initial backlog** — decompose the goal into initial task plans and load them into `.forge/backlog/` in PLAN-FORMAT (`../fg-run/PLAN-FORMAT.md`), with `forge-slug`, monotonic `task:` numbers, and the usual markers, exactly as fg-ask would. (TDD question, slug-collision check, and splitting rules all apply as in fg-ask.)

If a `.forge/loop.md` already exists when fg-loop is invoked, this is a **resume**: skip the inquiry, report the loop's state (goal · round/cap · check status), and re-enter the drive below — under the same `## Tasks` membership filter (non-member backlog plans accumulated while the loop was halted stay untouched; report them in one line). A pre-membership `loop.md` with no `## Tasks` section gets one added at resume (ask the user once which backlog slugs belong to the loop — don't guess). Resume is stateless — same pattern as `fg-next all`.

## 2. The drive

Drive one task loop at a time, reusing `fg-next all`'s machinery **by reference** (`../fg-next/SKILL.md` "all mode" — do not duplicate its rules here): promote the next backlog task **listed in `loop.md`'s `## Tasks` section** (membership filter — a backlog plan not on the list is **not** the loop's to run: leave it untouched and mention it in one status line; it belongs to the formal loop), execute it via fg-run, attempt the UAT aggressively, **always auto-skip the retro** (recorded by the done stage as `retro: skipped (fg-loop 자동 진행 — 학습은 run.md, 승급은 추후 fg-learn)` — same write-attribution as fg-next all), seal via fg-done, and continue. All per-task writes happen inside the delegated skills; fg-loop itself writes only `loop.md` and the plans it generates (see §3) — this is the one deliberate difference from fg-next, which writes nothing.

**After each seal, and whenever the backlog empties, run the stop-condition checks** and update their boxes in `loop.md`:

- **All checks pass** → the goal is met. Report a summary (tasks sealed, rounds used, check evidence), **delete `loop.md`**, and stop. The loop is closed.
- **Backlog still has tasks** → keep driving.
- **Backlog empty, some checks fail** → enter a replan round (§3) if bounds allow; otherwise halt at the wall.

## 3. Bounded replan (the relaxed gate — ADR-0016)

Two situations produce new work without a human conversation, both bounded by `loop.md`:

- **A task's UAT comes back `verified: failed`** — in fg-next all this is a hard wall; **in fg-loop it is the automated case**: generate a fix-forward task directly traceable to the failing check, leave the failed task to fg-run's normal failed-handling (fix-and-re-run → fresh run.md → re-verify), and continue. Never seal a `failed` result — ADR-0009 is untouched.
- **Backlog empty + stop-condition checks failing** — increment `replan-round` in `loop.md`; if it now exceeds `replan-cap`, halt (wall). Otherwise generate fix-forward task(s), one per failing check cluster, **strictly inside the authorized replan scope**.

Every generated plan is a normal plan: PLAN-FORMAT, `forge-slug`, next monotonic `task:` number (ADR-0005), plus a `<!-- generated-by: fg-loop -->` marker so fg-status and the audit trail show its origin (fg-status renders it as a `(loop)` origin tag) — and **append its slug to `loop.md`'s `## Tasks` section at generation time** (membership, §1/§2). A generated plan whose need turns out to exceed the authorized scope is **not** generated — that is a wall (genuine fork), not a judgment call to make alone.

**No-progress early abort:** if the **same check** fails after **2 consecutive** fix-forward attempts with no observable progress, stop before the cap — repeating a failing approach unattended is exactly the failure mode Osmani warns about. Report what was tried and halt.

## 4. Walls and termination

Halt the drive, report where/why/how-to-resume (in the user's language), at any of:

1. **Unverifiable UAT** — a check or task verification can't reach a sealable value (`pending`); never seal unverified (ADR-0009).
2. **Genuine design fork** — including a needed fix that exceeds the authorized replan scope. Consequential branches are the human's.
3. **Replan cap exhausted** (`replan-round` > `replan-cap`).
4. **No progress** — same check failing twice consecutively with no change.

On a wall, `loop.md` stays on disk (fg-status reports it); the human resolves the wall — possibly re-grilling via fg-ask or widening the scope/cap by editing the inquiry's answers in a short conversation — then re-triggers `fg-loop` to resume. On goal-met termination, `loop.md` is deleted and a final summary is the handoff (statement form — point to fg-learn for a later batch promotion of the archived run.md learnings, per ADR-0010's deferred-promotion model).

```
fg-loop
   │
   ▼
loop.md exists? ── yes ──▶ resume: report state ──▶ drive
   │ no
   ▼
Initial inquiry (conversation): machine-verifiable checks + replan scope + cap → loop.md, initial plans → backlog/
   │
   ▼
┌─▶ promote next task ─▶ run ─▶ UAT ─▶ auto-skip retro ─▶ seal ─▶ run stop-condition checks
│        │ verified: failed ─▶ generate fix-forward (in scope, in cap) ─▶ fix-and-re-run ─┐
│        │                                                                                  │
│   all checks pass ──▶ report summary, DELETE loop.md, stop (goal met)                    │
│   backlog has tasks ──────────────────────────────────────────────────────────────────◀─┘
│   backlog empty + checks failing ──▶ replan-round +1 ≤ cap? ── yes ─▶ generate fix-forward plans ─┐
│                                          │ no                                                      │
│                                          ▼                                                          │
│                                       WALL: halt, report, await human                              │
└─────────────────────────────────────────────────────────────────────────────────────────────────◀─┘
   (walls anywhere: unverifiable UAT · genuine fork / out-of-scope fix · cap exhausted · no progress ×2)
```

### Unattended across turn boundaries — pairing with `/goal`

A turn boundary mid-drive (most often an fg-run workflow script approval) ends the turn; to run unattended across boundaries, pair with the harness `/goal`, exactly as documented in `../fg-next/SKILL.md` ("Unattended to completion — pairing with /goal") — **a skill cannot set `/goal` itself**; the user types it. Phrase the condition as "stop only when the stop-condition checks all pass, OR a wall is hit" — never "until the checks pass" alone, which would force the drive past the safety walls.

### Relationship to the other lanes

- **`fg-next all`** drains the human-grilled backlog and halts at empty state and at `verified: failed`; it never creates work. fg-loop is the goal-converging superset: it re-checks a goal at empty state and may generate bounded fix-forward work, and `failed` is its automated case.
- **The formal loop / one-shot `fg-next`** keep the retro conversation; fg-loop always auto-skips retros (learnings preserved in archived run.md, promoted later by a human fg-learn).

## Handoff

The terminal report **is** the handoff — state what was sealed, the check evidence, and (on goal-met) that `loop.md` was removed; on a wall, state the wall, what was tried, and that re-triggering `fg-loop` resumes after the human resolves it. Statement form — no "shall I continue?" (ADR-0015). Mention `fg-learn` as the later batch-promotion path for the auto-skipped retros.

## Document impact

- Creates/updates/deletes `.forge/loop.md` — the goal contract (volatile, owned by fg-loop; deleted on goal-met termination, kept on a wall).
- Creates `.forge/backlog/*.md` plans — at the initial inquiry (as fg-ask would) and as `<!-- generated-by: fg-loop -->` fix-forward plans during bounded replan.
- Everything else (plan promotion, run.md, STATUS, seal, done/ archive) happens **inside the delegated skills** (fg-run/fg-done), under their own rules — including the `retro: skipped` record written by the done stage.
