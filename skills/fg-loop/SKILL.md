---
name: fg-loop
description: Goal-driven momentum loop with bounded replan (ADR-0016). An initial conversational inquiry pins a machine-verifiable stop condition, a pre-authorized fix-forward replan scope, and a replan cap (default 3 rounds) into .forge/loop.md, then loads the initial backlog and drives tasks unattended (run → UAT → auto-skip retro → seal) — auto-selecting the recommended/default at every soft decision point and never pausing to ask the user — until the stop-condition checks pass, auto-generating fix-forward tasks for failing checks within the cap. Halts only at the walls (unverifiable UAT, genuine design fork, cap exhausted, no progress) and hands back to the human. An on-demand orchestrator outside the loop. Use in contexts like 'forge loop', '루프 시작', '조건 충족까지 반복', 'goal loop'.
---

# fg-loop — goal-driven loop with bounded replan (outside the loop)

This is **not** a stage of the forge loop. It is a goal-driven orchestrator: one upfront conversational inquiry fixes a **machine-verifiable stop condition**, then fg-loop drives whole task loops (run → verify → auto-skip retro → seal) **until the stop-condition checks pass** — including, within explicit bounds, generating its own fix-forward tasks when checks fail. It is the third lane next to the formal loop (retro conversation included) and `fg-next all` (drain the human-grilled backlog, halt at empty): fg-loop converges on a goal instead of merely draining a queue. Rationale and the three bounds: `.forge/adr/0016-fg-loop-goal-driven-bounded-replan.md`.

**This deliberately relaxes pillar #1 within bounds** (the precedent is fg-quick relaxing pillar #2 for trivial work — ADR-0003): fg-loop may create plans without a per-plan grilling conversation, but **only** inside the replan scope the user pre-authorized during the initial inquiry, and **never** past the cap or the walls. "The AI thinks it's done" is **not** a stop condition — only the recorded checks are.

## Autonomy contract — the whole point of this lane (ADR-0016 rev. 2026-06-13)

Once the goal contract is pinned, the drive runs **unattended to completion**. It does **not** pause to ask the user for preferences or confirmations. At every *soft* decision point — one that carries a recommended or default option (a delegated skill's handoff menu, the TDD question, a slug-collision prompt, any "retro vs. skip" choice, "which task first") — **auto-select the recommended/default and proceed silently**; never turn such a choice into a question to the user. Retro is always auto-skipped (§2); where fg-run's single-task **statement-form** handoff states the skip-retro-and-seal option, the drive takes that path without prompting (ADR-0015 amended 2026-06-15 — the old four-option menu was dropped).

The drive's **only** legitimate stops are the four correctness walls (§4) and a workflow-script approval the harness physically requires to continue. **None of these is a "preference with a recommendation"**: each is a genuine block where proceeding alone would be *wrong*, not merely unconfirmed — a silently-sealed unverifiable UAT would violate ADR-0009; a genuine design fork is consequential and the human's to make. So "don't ask the user" and "halt at the walls" are **not** in tension — the walls are precisely the points where there is no recommendation to auto-pick.

Keep the **initial inquiry (§1) lean**: ask only what is needed to pin the machine-verifiable checks, the replan scope, and the cap. Take the documented defaults for everything else — TDD per `.forge/config.json`, the default replan scope, cap 3, auto-decompose into tasks — rather than grilling each sub-decision. The human judgment this lane preserves is *pinning the stop condition up front*, not approving each step toward it.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — inquiry questions, status lines, halt reports, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** Documents it writes into the user's project (loop.md, generated plans) are written in the user's language.

**Forge root**: every `.forge/...` path below is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. Resolve it per `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before reading or writing state (ADR-0011).

## 1. Initial inquiry (conversational — outside any workflow)

Conducted as a conversation in this session, one question at a time, reusing fg-ask's grilling method (`../fg-ask/SKILL.md`) — this is where the human judgment happens, up front. **Keep it lean** (see Autonomy contract above): ask only what pins the checks, the replan scope, and the cap; default everything else rather than grilling each sub-decision. It must produce two outputs before any driving starts:

1. **The goal contract → `.forge/loop.md`** (volatile state, owned by fg-loop; auto-gitignored on the default branch by the existing `.forge/*` pattern):

   ```md
   # LOOP — {one-line goal}
   started: {YYYY-MM-DD}
   replan-round: 0
   replan-cap: 3
   wall: {none | no-progress (C1) | cap-exhausted | unverifiable-uat (C2) | fork (<reason>) | tension (Cx↔Cy) | safety (<class>)}

   ## Stop-condition checks (ALL must pass)
   - [ ] C1. {agent-runnable check — a command + expected outcome, e.g. `grep -c X file` ≥ 1, tests green, JSON parses}
   - [ ] C2. {...}

   ## Check progress (updated after EVERY stop-condition run — drives the no-progress & tension walls & fg-status)
   - C1: fail ×2 · regressed: ×0 · last-evidence: "grep -c X file → 0 (unchanged since round 1)" · tried: fix-c1-1of1, fix-c1b-1of1
         reflection: "두 시도 모두 정규식만 손봤으나 입력이 애초에 비어 있었음 → 다음엔 파서가 아니라 입력 생성 경로를 고쳐야"
   - C2: fail ×1 · regressed: ×1 · last-evidence: "tests → 41 passing (round 2엔 42 green이었으나 C1 fix가 1건 깨뜨림)"
         reflection: "C1 정규식 확장이 C2 케이스를 깨뜨림(핑퐁) → 다음 fix-forward는 C1·C2를 동시에 만족시켜야"

   ## Authorized replan scope
   - {what fg-loop may auto-generate without re-grilling — fix-forward tasks directly traceable to a failing check above}
   - always-halt action classes (safety wall — default set, override/extend per loop): prod 데이터 변경/삭제 · 배포/릴리스/publish · 외부 발신 통신(메일·메시지·제3자 write API) · 비가역 VCS/파일 파괴(force-push·history rewrite·대량 삭제) · 금융/결제 · 시크릿/권한 변경 · 프라이버시 데이터 노출
   - {other explicit exclusions, if discussed}

   ## Tasks
   - {slug of every plan this loop owns — the initial-inquiry plans now, each generated fix-forward plan appended at generation time}
   ```

   The **`## Check progress` ledger and the `wall:` field are load-bearing, not decorative** — fg-loop is *stateless across resumes*, so without them a re-triggered drive cannot tell that a check already failed twice with no change, and would keep generating near-identical fix-forward tasks up to the cap (the "keeps proposing the same task with no progress" failure mode). After **every** stop-condition run, update each check's line: its result (`pass`/`fail`), the **consecutive no-progress count** (`×N` — increment when a check is still failing AND its evidence is unchanged from the prior round; reset to 0/“×1” on any observable change or pass), the **regression count** (`regressed: ×N` — increment each time this check flips from `pass` in the *previously-recorded* run to `fail` now; the signature of a fix-forward for one check breaking another, which the no-progress `×N` misses because the flip *is* an observable change that resets it), the `last-evidence` (the command output you actually observed), and append the `tried:` slug when a fix-forward was generated for it. The no-progress wall reads `×N ≥ 2`; the **tension wall** (§3/§4) reads regression recurrence; on any halt, set `wall:` to the precise cause so fg-status/resume report *why* (never a bare "resume fg-loop"). `started` is stamped by the human at creation (skills can't read the clock) or left as a literal placeholder.

   **Reflexion (ADR-0016, 2026-06-18 2차).** When a fix-forward attempt leaves a check still failing, also write a one-line **`reflection:`** under that check — *verbalize why the last approach didn't move the evidence and what to try **differently** next* (not a restatement of the failure; a changed direction). This is the working memory that makes the next fix-forward actually different rather than a re-run of the same idea (§3 reads it). It is **drive-local volatile state** — it lives in `loop.md`, is consumed during the drive, and dies when `loop.md` is deleted at goal-met; it is **not** a retro (permanent learning still promotes via run.md → human fg-learn, ADR-0010). First failure of a check has no reflection yet — write one only once there is a tried attempt to reflect on.

   - **Every check must be agent-runnable** (grep/test/build/JSON — same shapes as fg-run's aggressive UAT). If the user's goal can't be pinned to runnable checks, say so and either sharpen it together or route to the formal loop (fg-ask) — do **not** start a drive on a vague goal.
   - **The replan scope is the user's pre-authorization** — the bound that makes auto-planning legitimate. Default scope when the user has no preference: "fix-forward tasks directly traceable to a failing stop-condition check, nothing else."
   - **`replan-cap`** defaults to **3** rounds; the user may set another value here.
   - **The `## Tasks` section is the loop's membership list** — the slugs of every plan this loop owns. Record the initial-inquiry plans here at creation, and append each generated fix-forward plan's slug at generation time (§3). The drive promotes **member slugs only**, so backlog plans grilled by fg-ask while the loop is halted at a wall are never swept into the unattended drive.

2. **The initial backlog** — decompose the goal into initial task plans and load them into `.forge/backlog/` in PLAN-FORMAT (`../fg-run/PLAN-FORMAT.md`), with `forge-slug`, monotonic `task:` numbers, and the usual markers, exactly as fg-ask would. (TDD question, slug-collision check, and splitting rules all apply as in fg-ask.)

**Then, right before entering the drive, present the `/goal` pairing as this lane's operating premise** (the shared mechanism — within-turn continuation + the `/goal` cross-turn hook — is [DRIVE.md](../fg-next/DRIVE.md); §4 fills its phrasing rule with this loop's walls) — not buried in the section below (a documented pattern the user never sees is a promise with no receiver), and **not a soft "you may" aside** (that offer framing is exactly what users forget, so the drive stalls after one cycle). State it prominently as the **last thing before driving**, in the user's language: to run this drive unattended, **paste this `/goal` line now**; then print the paste-ready line built from this loop's walls (see "Unattended across turn boundaries" below for the phrasing rule — stop allowed only at goal-met or a wall, never "until the checks pass" alone). **A skill cannot set `/goal` itself** — the user must type it; that hard constraint is *why* this is presented as the expected step, not an optional footnote. **Be honest about the no-`/goal` fallback in the same breath:** without it the drive stops after a cycle — most often right after a delegated fg-run/fg-done handoff *states* its next step (ADR-0015) and the model yields the turn — and **that pause is expected, not a failure**; re-triggering `forge loop` resumes exactly where it left off (stateless resume below). So the choice is explicit, not hidden: paste `/goal` to run unattended, or re-trigger `forge loop` after each pause.

If a `.forge/loop.md` already exists when fg-loop is invoked, this is a **resume**: skip the inquiry, report the loop's state (goal · round/cap · check status), and re-enter the drive below — under the same `## Tasks` membership filter (non-member backlog plans accumulated while the loop was halted stay untouched; report them in one line). A pre-membership `loop.md` with no `## Tasks` section gets one added at resume (ask the user once which backlog slugs belong to the loop — don't guess). **Re-derive and re-print the paste-ready `/goal` line from §1 on every resume** (unless one is already active) — re-printing it each time is what structurally stops the user from forgetting to engage it; a resume after a resolved wall is exactly where unattended driving pays off again. (The line is *derived from this loop's walls*, not stored — so re-printing means re-deriving it here, no `loop.md` field needed.) Resume is stateless — same pattern as `fg-next all`.

## 2. The drive

Drive one task loop at a time, reusing `fg-next all`'s machinery **by reference** (`../fg-next/SKILL.md` "all mode" — do not duplicate its rules here): promote the next backlog task **listed in `loop.md`'s `## Tasks` section** (membership filter — a backlog plan not on the list is **not** the loop's to run: leave it untouched and mention it in one status line; it belongs to the formal loop), execute it via fg-run, attempt the UAT aggressively, **always auto-skip the retro** (recorded by the done stage as `retro: skipped (fg-loop 자동 진행 — 학습은 run.md, 승급은 추후 fg-learn)` — same write-attribution as fg-next all), seal via fg-done, and continue. All per-task writes happen inside the delegated skills; fg-loop itself writes only `loop.md` and the plans it generates (see §3) — this is the one deliberate difference from fg-next, which writes nothing.

**Do not end the turn between task loops (within-turn continuation — [DRIVE.md](../fg-next/DRIVE.md) Part 1).** Sealing one task is not a stopping point: after each seal, immediately run the stop-condition checks and continue — to the next member task, or into a replan round (§3). The only legitimate ends of a turn are **goal-met** (checks all pass) and **a wall** (§4). Skill text alone can't guarantee the model won't yield after a delegated handoff states its next step (DRIVE.md Part 1's honest limit); the reliable cross-turn enforcement is `/goal` (§4, and §1's operating premise) — without it the drive falls back to one-cycle-then-pause, which is expected, not a violation (re-trigger `forge loop` to resume).

**After each seal, and whenever the backlog empties, run the stop-condition checks** and update both their checkboxes AND the **`## Check progress` ledger** in `loop.md` (each check's result, its consecutive no-progress count `×N`, its regression count `regressed: ×N` — compare each freshly-run result against the result the ledger currently records; a `pass`→`fail` flip is a **regression event**, but **increment `regressed:` only when the just-sealed task was a generated fix-forward** (`generated-by: fg-loop`) — that is the tension signal (§3). A flip caused by a **human-grilled member task** during backlog drain is normal multi-task interference, **not** tension: record it in `last-evidence` (the check is now failing, which the remaining backlog or the eventual fix-forward addresses) but do **not** count it toward `regressed:`, and do **not** halt the drain — the `last-evidence` you observed, and any `tried:` slug). This persisted ledger is what makes the no-progress wall, the tension wall, and fg-status work across a stateless resume — update it every run:

- **All checks pass** → the goal is met. Report a summary (tasks sealed, rounds used, check evidence), **delete `loop.md`**, and stop. The loop is closed.
- **Backlog still has tasks** → keep driving.
- **Backlog empty, some checks fail** → enter a replan round (§3) if bounds allow; otherwise halt at the wall.

## 3. Bounded replan (the relaxed gate — ADR-0016)

Two situations produce new work without a human conversation, both bounded by `loop.md`:

- **A task's UAT comes back `verified: failed`** — in fg-next all this is a hard wall; **in fg-loop it is the automated case**: generate a fix-forward task directly traceable to the failing check — **but route it through the safety gate first, exactly like every other fix-forward generation (below): if it would require an always-halt action class, halt with `wall: safety` instead of generating it** — leave the failed task to fg-run's normal failed-handling (fix-and-re-run → fresh run.md → re-verify), and continue. Never seal a `failed` result — ADR-0009 is untouched. (This matters most here: `/goal` tells the drive not to stop on `verified: failed`, so without the gate an irreversible in-scope fix could auto-run.)
- **Backlog empty + stop-condition checks failing** — increment `replan-round` in `loop.md`; if it now exceeds `replan-cap`, halt (wall). Otherwise generate fix-forward task(s), one per failing check cluster, **strictly inside the authorized replan scope**.

**Feed Reflexion forward (ADR-0016 2026-06-18 2차).** Before generating a fix-forward for a failing check, **read that check's `tried:` slugs and `reflection:` from the `## Check progress` ledger first**, and make the new plan take a **different approach** — seeded by the reflection's "try differently", not a re-run of an already-tried idea. (First failure has no reflection → generate normally.) This applies to both replan-round generation and the `verified: failed` automated case above. If the reflection concludes the real fix needs work **outside the authorized replan scope**, do not generate — surface it as a **fork wall early** (§4), before burning the cap on in-scope variations that can't succeed.

**Tension wall — fix-forwards trading one check for another (ADR-0016 2026-06-25; scope corrected 2026-06-25 2차).** Tension is strictly a **fix-forward** phenomenon: it counts only regressions **attributable to a generated fix-forward** (`regressed: ×N`, which §2 increments only for `generated-by: fg-loop` work). A regression from a human-grilled member task during backlog drain is **not** tension — it is normal multi-task interference, and the drive keeps going (the remaining backlog / eventual fix-forward addresses the now-failing check). When a fix-forward for one check regresses another: **lenient + one retry** — on the **first** fix-forward-induced regression, generate the next fix-forward with a **hard constraint to satisfy BOTH** the target check and the regressed check (fed forward alongside Reflexion, not instead of it). If it regresses **again** — the same check's `regressed: ×N` reaches `×2`, **or** two distinct checks have each been regressed by fix-forwards at least once (a ping-pong) — the checks are in genuine tension that in-scope fix-forwards can't reconcile: halt with `wall: tension (Cx↔Cy)`, report the conflicting pair and their `last-evidence`, and hand the tradeoff to the human. This fires **before** cap exhaustion, so the human reads "C1↔C2 conflict" instead of a blunt "cap-exhausted". Detection is **mechanical** (the ledger's fix-forward-attributed pass→fail flip) — unlike the safety gate below, no judgment is involved.

Every generated plan is a normal plan: PLAN-FORMAT, `forge-slug`, next monotonic `task:` number (ADR-0005), plus a `<!-- generated-by: fg-loop -->` marker so fg-status and the audit trail show its origin (fg-status renders it as a `(loop)` origin tag) — and **append its slug to `loop.md`'s `## Tasks` section at generation time** (membership, §1/§2). A generated plan whose need turns out to exceed the authorized scope is **not** generated — that is a wall (genuine fork), not a judgment call to make alone.

**Safety wall — in-scope but irreversible (ADR-0016 2026-06-25; made universal 2026-06-25 2차).** This gate is a **mandatory precondition for *every* fix-forward generation — the backlog-empty replan case and the `verified: failed` automated case alike** (no generation path skips it). Even within the authorized scope, before generating+running any fix-forward, **classify its slices against the `always-halt action classes`** in `loop.md`'s Authorized replan scope (§1 — the default 7-class set, override/extend per loop). If any slice would take such an action — prod data mutation/deletion · deploy/release/publish · outbound external comms · irreversible VCS/file destruction · financial/payment · secret/permission change · privacy-data exposure — do **not** auto-generate+run it: halt with `wall: safety (<class>)` and hand the one-way door to the human. This is distinct from the fork wall: out-of-scope work is a fork, but an **in-scope yet destructive** action still halts (the gap the harness permission gate misses under broad permissions). **Honest limit**: this is a **best-effort self-classification** by the generating model, not a guaranteed interception (a Markdown plugin has no static analyzer to enforce it) — its value is that the halt is named in the contract and the `/goal` stop-allowed set, so the drive has an explicit instruction to stop rather than none.

**No-progress early abort:** if the **same check** fails after **2 consecutive** fix-forward attempts with no observable progress, stop before the cap — repeating a failing approach unattended is exactly the failure mode Osmani warns about. **Detect this from the persisted `## Check progress` ledger (`×N ≥ 2`), not from in-session memory** — fg-loop resumes statelessly, so a fresh resume must read the prior no-progress count from `loop.md` or it would never trip this wall and would keep re-proposing near-identical fix-forwards up to the cap. The threshold is unchanged, but with Reflexion forcing each attempt to differ (§3) this wall now means **"genuinely different approaches all failed to move the evidence"** — a stronger signal than "the same thing twice". Report what was tried (the `tried:` slugs, `last-evidence`, **and the `reflection:` lines** — so the human sees *what* was attempted and *why* it stalled) and halt.

## 4. Walls and termination

Halt the drive, report where/why/how-to-resume (in the user's language), at any of:

1. **Unverifiable UAT** — a check or task verification can't reach a sealable value (`pending`); never seal unverified (ADR-0009).
2. **Genuine design fork** — including a needed fix that exceeds the authorized replan scope. Consequential branches are the human's.
3. **Replan cap exhausted** (`replan-round` > `replan-cap`).
4. **No progress** — same check failing twice consecutively with no change.
5. **Tension** (§3) — fix-forwards keep trading one stop-condition check for another (a previously-passing check regresses, then regresses again after a satisfy-both retry, or two checks ping-pong). The checks conflict; the human decides the tradeoff. Fires before cap exhaustion.
6. **Safety** (§3) — a fix-forward would require an `always-halt action class` (irreversible/destructive/external; §1). Hand the one-way door to the human. Best-effort self-classification, not a guaranteed gate.

On a wall, **set `loop.md`'s `wall:` field to the precise cause** (`no-progress (C1)` / `cap-exhausted` / `unverifiable-uat (C2)` / `fork (<reason>)` / `tension (Cx↔Cy)` / `safety (<class>)`) so fg-status and the resume report *why* it stopped — never a bare "resume fg-loop". `loop.md` stays on disk (fg-status reports it); the human resolves the wall — possibly re-grilling via fg-ask or widening the scope/cap by editing the inquiry's answers in a short conversation — then re-triggers `fg-loop` to resume. On goal-met termination, `loop.md` is deleted and a final summary is the handoff (statement form — point to fg-learn for a later batch promotion of the archived run.md learnings, per ADR-0010's deferred-promotion model).

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
│        │ verified: failed ─▶ safety-class? ─ no ─▶ generate fix-forward (in scope, in cap) ─▶ fix-and-re-run ─┐
│        │                          │ yes ─▶ WALL: safety                                                       │
│   all checks pass ──▶ report summary, DELETE loop.md, stop (goal met)                    │
│   backlog has tasks ──────────────────────────────────────────────────────────────────◀─┘
│   backlog empty + checks failing ──▶ replan-round +1 ≤ cap? ── yes ─▶ safety-class? ─ no ─▶ generate fix-forward plans ─┐
│                                          │ no                              │ yes                                       │
│                                          ▼                                  ▼                                          │
│                                       WALL: halt, report, await human ◀── WALL: safety                                 │
└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────◀─┘
   (walls anywhere: unverifiable UAT · genuine fork / out-of-scope fix · cap exhausted · no progress ×2 · tension (regression ping-pong) · safety (irreversible action))
```

### Unattended across turn boundaries — pairing with `/goal`

A turn boundary mid-drive — an async workflow, a script approval, or the model yielding after a delegated handoff states its next step (ADR-0015) — ends the turn; crossing it unattended needs `/goal`. The **mechanism**, the **"a skill cannot set `/goal` itself"** constraint, the **phrasing rule**, and the **honest fallback** (without it, one cycle then pause — re-trigger `forge loop` to resume) all live in [DRIVE.md](../fg-next/DRIVE.md) Part 2, shared with fg-next; §1 presents the pairing as this drive's operating premise and re-prints the paste-ready line at every resume (re-derived from this loop's walls). **Enumerate the stop-allowed points from THIS loop's walls, not fg-next's**: goal-met (all checks pass) · unverifiable UAT (`pending`) · genuine fork / out-of-scope fix · replan cap exhausted · no progress ×2 · tension (regression ping-pong) · safety (irreversible action class) · a workflow script approval (human input is physically required). Do **not** list `verified: failed` as a stop point — in fg-loop it is the automated fix-forward case (§3), and a `/goal` that halts on it would undo exactly the wall-relaxation this skill exists for. Recommended paste-ready shape (render in the user's language):

> *"Keep driving fg-loop. Stopping is allowed only at: (1) goal-met — every stop-condition check passes; (2) a wall — unverifiable UAT, a genuine fork or out-of-scope fix, replan cap exhausted, no progress ×2, tension (checks ping-pong), or a safety/irreversible action; or (3) a workflow script approval. On `verified: failed`, do not stop — continue with fix-forward."*

### Relationship to the other lanes

- **`fg-next all`** drains the human-grilled backlog and halts at empty state and at `verified: failed`; it never creates work. fg-loop is the goal-converging superset: it re-checks a goal at empty state and may generate bounded fix-forward work, and `failed` is its automated case. **The tension and safety walls (§3/§4) are fg-loop-exclusive** — both arise only from *generated* fix-forwards, which fg-next all never produces, so they do not ripple into fg-next's wall set (the two lanes share only the `/goal` mechanism, not this wall pair).
- **The formal loop / one-shot `fg-next`** keep the retro conversation; fg-loop always auto-skips retros (learnings preserved in archived run.md, promoted later by a human fg-learn). The optional adversarial review (`fg-adversarial-review`, ADR-0018) is likewise **never** run in the drive — it needs a human to judge which findings are real and worth fixing.

**Where this sits in "loop engineering" terms (maker/checker · deployment levels).** This lane *is* the "recursive goal" of loop engineering — define a purpose; the AI iterates with sub-agents, verification, and external state until the goal is met or it hands off to you — pinned **stricter**: "the AI thinks it's done" is never a stop condition here, only the recorded machine-verifiable checks. The maker/checker split maps cleanly: fg-run's workflow sub-agents are the *maker*; the per-task UAT is a self-administered *checker*, **but the machine-verifiable stop-condition checks are the independent, objective checker** — a `grep`/test/build outcome is not subject to maker bias, so an over-optimistic UAT is caught when a stop check still fails and triggers a fix-forward (§3). That is why **no separate verifier sub-agent runs in the drive**: the mechanical checks already gate, and a redundant verifier would add complexity without closing a real hole. The three forge lanes are the L1→L2→L3 rollout (report → assisted → unattended) — fg-status (L1, observe) · fg-next (L2, assisted) · fg-loop / fg-next all (L3, unattended) — and `loop.md`'s Check-progress ledger + Reflexion is the durable memory/state spine that survives a stateless resume.

## Handoff

The terminal report **is** the handoff — state what was sealed, the check evidence, and (on goal-met) that `loop.md` was removed; on a wall, state the wall, what was tried, and that re-triggering `fg-loop` resumes after the human resolves it. Statement form — no "shall I continue?" (ADR-0015). Mention `fg-learn` as the later batch-promotion path for the auto-skipped retros.

## Document impact

- Creates/updates/deletes `.forge/loop.md` — the goal contract (volatile, owned by fg-loop; deleted on goal-met termination, kept on a wall).
- Creates `.forge/backlog/*.md` plans — at the initial inquiry (as fg-ask would) and as `<!-- generated-by: fg-loop -->` fix-forward plans during bounded replan.
- Everything else (plan promotion, run.md, STATUS, seal, done/ archive) happens **inside the delegated skills** (fg-run/fg-done), under their own rules — including the `retro: skipped` record written by the done stage.
