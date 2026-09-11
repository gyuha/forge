# Initial inquiry — pinning the goal contract (conversational, outside any workflow)

> Loaded by `fg-loop` **only when `.forge/loop.md` does not yet exist** — i.e. the first call for a new goal.
> Every resume (contract already on disk) skips this file entirely: it goes to `SKILL.md`'s **Resume preflight** first, and only then to the drive.
> Split out of `SKILL.md` for token efficiency on the resume path; **behavior is unchanged** from when it lived inline.
> **Section references**: `§N`, `step N`, and any "above" that names a section not present in this file all point to [`SKILL.md`](./SKILL.md)'s numbered sections — the numbering is unchanged by the split.

Conducted as a conversation in this session, one question at a time, reusing fg-ask's grilling method (`../fg-ask/SKILL.md`) — this is where the human judgment happens, up front. **Keep it lean** (see Autonomy contract above): ask only what pins the checks, the replan scope, and the cap; default everything else rather than grilling each sub-decision. It must produce two outputs before any driving starts:

1. **The goal contract → `.forge/loop.md`** (volatile state, owned by fg-loop; auto-gitignored on the default branch by the existing `.forge/*` pattern):

   ```md
   # LOOP — {one-line goal}
   started: {YYYY-MM-DD}
   replan-round: 0
   replan-cap: 3
   budget-tokens: {none | N}          {spend ceiling — raw token total; `none` bypasses the checks}
   budget-spent: 0 · since: {ISO}     {cumulative spend · the stamp the next delta measures from — written by forge-loop-spend}
   wall: {none | no-progress (C1) | cap-exhausted | unverifiable-uat (C2) | fork (<reason>) | tension (Cx↔Cy) | safety (<class>) | stalled-waiting (C2) | blocked-health (<capability>) | budget-exhausted}

   ## Stop-condition checks (ALL must pass)
   - [ ] C1. {agent-runnable check — a command + expected outcome, e.g. `grep -c X file` ≥ 1, tests green, JSON parses}
   - [ ] C2. {...}
         evidence: external   {optional — see "Externally-evidenced checks" below; omit by default}

   ## Check progress (updated after EVERY stop-condition run — drives the no-progress & tension walls & fg-status)
   - C1: fail ×2 · regressed: ×0 · last-evidence: "grep -c X file → 0 (unchanged since round 1)" · tried: fix-c1-1of1, fix-c1b-1of1
         reflection: "both attempts only touched the regex, but the input was empty to begin with → next, fix the input-generation path, not the parser"
   - C2: fail ×1 · regressed: ×1 · last-evidence: "tests → 41 passing (42 were green in round 2; the C1 fix broke one)"
         reflection: "widening C1's regex broke a C2 case (ping-pong) → the next fix-forward must satisfy C1 and C2 together"
   - C3: waiting ×1 · last-evidence: "gh run list → status=in_progress (CI has not finished)"   {externally-evidenced check — counted separately, see below}

   ## Authorized replan scope
   - {what fg-loop may auto-generate without re-grilling — fix-forward tasks directly traceable to a failing check above}
   - always-halt action classes (safety wall — default set, override/extend per loop): prod data mutation/deletion · deploy/release/publish · outbound external comms (email · messaging · third-party write APIs) · irreversible VCS/file destruction (force-push · history rewrite · mass deletion) · financial/payment · secret/permission change · privacy-data exposure
   - {other explicit exclusions, if discussed}

   ## Tasks
   - {slug of every plan this loop owns — the initial-inquiry plans now, each generated fix-forward plan appended at generation time}
   ```

   **Why the budget is TWO TOP-LEVEL FIELDS and not absorbed into that ledger (ADR-0016, amended 2026-08-19).** The discipline in [`SKILL.md`](./SKILL.md) §2 is *"do not mint a field when a natural home already exists"* — `waiting` is a **per-check** state, so the per-check ledger was its home and a new field would have been waste. Spend is a **drive-level** quantity that belongs to no check; forcing it into the ledger would require inventing "the tokens C1 consumed," which does not exist. Its structural twins are `replan-round`/`replan-cap` — an accumulator plus a ceiling, both already top-level — so it takes the same shape. Recomputing spend on demand instead of storing it was also rejected, but **not** for the reason first written here — and the correction matters, because the original claim was false (ADR-0016 amended 2026-08-20). `since:` advances to `now` on every call, so the next segment's first delta covers the interval since the last one, **including any unrelated work a human did in this repo between a wall and a resume**. Accumulating the delta and recomputing from `started` therefore bill the *same total*; the accumulator is merely incremental bookkeeping of it. Its real advantages are the ones to keep in mind: it avoids re-scanning every transcript on every call, and it survives transcript rotation or deletion. Unlike `started`, `since:` is stamped by the **script**, so the "skills can't read the clock" limit does not apply.

   - **Every check must be agent-runnable** (grep/test/build/JSON — same shapes as fg-run's aggressive UAT). If the user's goal can't be pinned to runnable checks, say so and either sharpen it together or route to the formal loop (fg-ask) — do **not** start a drive on a vague goal.
   - **Grill each check for *faithfulness*, not just runnability — the one part of the inquiry that is NOT lean (see the Autonomy contract).** A runnable check is still only a *proxy* for the goal; an unfaithful proxy lets the drive declare a false victory ("all checks pass → delete `loop.md` → done") with no human watching. Before pinning the check set, adversarially grill it through four lenses, one at a time, and rewrite/expand the checks until each holds:
     1. **Gameability (Goodhart)** — "could this pass while the goal is NOT achieved?" If yes, tighten it to assert *behavior/outcome*, not mere presence (not `grep -c func file ≥ 1`, but a test asserting `func` returns the expected value).
     2. **Completeness / regression-leak** — "could ALL checks pass while something important broke?" Add anti-regression checks (e.g. the existing suite stays green) so a fix-forward can't satisfy its target while breaking a sibling. These added checks feed the existing tension/regression machinery (§2/§3) directly — a regression becomes a visible check failure instead of a silent one.
     3. **Faithful vs. convenient proxy** — "is this measuring the real intent, or just what is easy to grep?" Replace a convenient proxy with a faithful one (or add the missing outcome check).
     4. **In-scope reachability** — "is each check achievable within the authorized replan scope?" A check satisfiable only by out-of-scope work will merely burn the cap and end at a fork wall — surface that as a fork **now** (§3's "fork early"), before driving.
     If the checks cannot be made faithful **and** in-scope-reachable, treat it the same as a non-runnable goal above — sharpen together or route to fg-ask; do **not** drive on unfaithful checks. The output of this grilling is simply a **hardened and expanded check set** in the `## Stop-condition checks` section above — no new `loop.md` field.
   - **Externally-evidenced checks — declare them here, or they can never wait (ADR-0016, 2026-08-09).** Some checks depend on evidence that arrives on someone else's clock (CI concluding, a deploy settling, an external metric landing). Such a check is *not yet judgeable*, and treating it as a failure is a misclassification with two costs: the drive burns `replan-round` generating fix-forward work for a problem that may not exist, and it eventually hands the user an `unverifiable-uat` wall for something **no human action can resolve**. Mark such a check `evidence: external` **during this inquiry** — it is a declaration, never inferred at runtime:
     - **Default is off.** A check with no `evidence: external` behaves exactly as before. Existing `loop.md` files and ordinary loops are unaffected.
     - **Classification is mechanical, with zero model discretion**: a declared-external check that is not passing is **always** `waiting`. There is no runtime judgment call, because a self-declared "this is just waiting" is precisely the alibi that would let an unattended drive dodge failure forever (the same Goodhart risk lens 1 guards against).
     - **The accepted cost — declared-external checks are excluded from automatic repair.** Since no predicate distinguishes "CI ran and is red" from "CI has not finished," the drive **never generates a fix-forward for a declared-external check** (§3). This is deliberate and conservative: it halts rather than mis-fixing. It is also a small loss in practice — a genuinely red CI or a failing external dependency is usually outside the authorized replan scope anyway, i.e. a fork wall.
     - **Declaring one is a judgment, so grill it once**: *"is this check waiting on someone else's clock, or is it just slow?"* Only genuine external evidence qualifies — marking an ordinary local check `evidence: external` disables its automatic repair for nothing.
   - **The replan scope is the user's pre-authorization** — the bound that makes auto-planning legitimate. Default scope when the user has no preference: "fix-forward tasks directly traceable to a failing stop-condition check, nothing else."
   - **`replan-cap`** defaults to **3** rounds; the user may set another value here.
   - **`budget-tokens` — the spend ceiling, asked in the SAME breath as the cap, never as a separate question (ADR-0016, amended 2026-08-19).** Extend the cap question rather than adding a fourth item to this lean inquiry: *"replan cap 3 rounds — and a token ceiling? (none is a valid answer)"*. **Invent no default**: `none` means the checks below are bypassed entirely and the drive behaves exactly as before. Asking it every drive is deliberate — a ceiling nobody ever switches on is a dead feature, and merging it into an existing question is what keeps §1 lean. Why a *second* axis at all: `replan-cap` bounds **rounds**, and a round is one task, so it says nothing about spend — one round can be a single `grep` or a workflow that re-sends a large context on every iteration. Cache-read tokens are precisely that compounding re-send, which is why the meter counts them (see §2).
   - **The `## Tasks` section is the loop's membership list** — the slugs of every plan this loop owns. Record the initial-inquiry plans here at creation, and append each generated fix-forward plan's slug at generation time (§3). The drive promotes **member slugs only**, so backlog plans grilled by fg-ask while the loop is halted at a wall are never swept into the unattended drive.

2. **The initial backlog** — decompose the goal into initial task plans and load them into `.forge/backlog/` in PLAN-FORMAT (`../fg-run/PLAN-FORMAT.md`), with `forge-slug`, monotonic `task:` numbers, and the usual markers. Apply fg-ask's collision and splitting rules, but preserve this lane's lean-autonomy contract: for TDD, **use the config default without asking** and record the resulting `<!-- tdd: on|off -->`; for a slug collision, take the deterministic next suffix. Do not reopen soft questions the autonomy contract already defaulted.

With `loop.md` and the initial backlog written, **return to [`SKILL.md`](./SKILL.md) §2** — the capability precheck, then the drive.
