# forge and Loop Engineering

> A review of whether to adopt Addy Osmani's [Loop Engineering](https://addyosmani.com/blog/loop-engineering/) (2026) in forge. Reviewed 2026-06-11 (forge v0.4.4) · status updated 2026-06-25 (second Loop Library audit — fg-loop's tension and safety walls added).
>
> **Conclusion: forge is an implementation of loop engineering.** Of the six primitives the post defines, forge already institutionalizes five — and every one of its warnings — in its own vocabulary. The single gap (Automations) has too little value in this repo, so we decided not to adopt it (see "What we did not adopt, and why" below).

## Answering the core thesis

Osmani's thesis is "replace the person typing prompts at an agent with a system — be a loop designer, not a prompt engineer." forge's answer: **automate the loop, but leave the irreducible judgment (grilling, the retro, confirming verification) to the human.** That is forge's two pillars, and it is the structural device that blocks the cognitive surrender Osmani warns about.

## Primitive mapping

| Loop Engineering concept | forge's implementation | Reference |
| --- | --- | --- |
| **Skills** — encode conventions and intent in SKILL.md, prevent intent debt | forge itself is 22 `fg-*` skills (the loop's four stages + 18 outside-the-loop utilities). Terms live in `CONTEXT.md`, decisions in ADRs, code context in the `.forge/codebase/` map — "docs are the loop's fuel, not its by-product" (pillar 2) *is* the defense against intent debt | README's two pillars, ADR-0001 |
| **State/Memory** — durable on-disk state outside the context window | The entire `.forge/` state contract: backlog → active slot (plan/run/STATUS) → executed/ → done/. "memory has to be on disk" implemented literally — every skill is invoked independently, yet the flow continues through files | README's shared state, FORGE-ROOT.md |
| **Worktrees** — isolating parallel agents | The branch-scoped forge root (`.forge/branch/<branch>/`) solves the same collision problem at the state level. git worktrees can be used alongside it; "worktrees alone are enough" was considered and rejected (it cannot resolve conflicts in tracked docs) | ADR-0011 |
| **Sub-agents** — maker/checker separation, no self-grading | fg-run's Dynamic Workflow (parallel execution) + the dedicated adversarial review skill **fg-adversarial-review** (assumes the result is wrong and fans six lenses out as parallel subagents) + fg-map's four-mapper fan-out. The separate trio (explorer/retro-analyzer/verifier) is **deliberately deferred** for lack of concrete pain — with the revisit bar written down | ADR-0007, ADR-0013, ADR-0018 |
| **`/goal`·`/loop`** — unattended resumption until a verifiable stop condition (forge gets this with no user action via its own `Stop` hook; `/goal` stays the fallback — ADR-0028) | The dedicated goal-loop skill **fg-loop** — pins a machine-verifiable stop condition into `.forge/loop.md` and drives unattended to convergence with bounded fix-forward replanning. `fg-next all` (drain the backlog, halt at the conversational walls) is the companion lane for a queue that has already been grilled | ADR-0016, ADR-0010 |
| **Automations** — scheduled discovery and triage → inbox | **None (the one gap).** Every forge loop is started by a human | — (see below) |
| **Plugins/Connectors** — wiring external tools via MCP | **None (deliberate).** File-based self-containment is a design principle — depending on an external tracker breaks portability | Skill editing conventions (no hard dependencies) |

## Institutionalizing the warnings — where forge is strongest

The warnings Osmani piles up in the back half of the post are not advice in forge; they are **gates**:

| Warning | How forge institutionalizes it |
| --- | --- |
| Token cost volatility | `fg-eco` — when on, caps delegated subagents at sonnet and adds the Eco laziness-first discipline (`ECO.md`), which cuts code and plan complexity too (ADR-0014, amended). Plus the estimate-cost-first principle (fg-run Constraints) |
| "A loop running unattended is a loop making mistakes unattended" | **no-seal-without-verification** — no seal unless a verification decision is recorded (ADR-0009). `failed` cannot be sealed by any waiver |
| Comprehension debt | The retro is the default (ADR-0002) — skipping is allowed only at low divergence, and auditably (`retro: skipped (<reason>)`). Learnings are promoted into permanent docs |
| Cognitive surrender | Pillar 1 — grilling and the retro are conversation outside the workflow. Even `fg-next all` halts and hands back to the human on a failed UAT, a genuine fork, or a costly judgment call |
| Orchestration tax | The active slot is always exactly one (one plan = one run = one seal) — the loop's width is sized to human review bandwidth |

## fg-loop's second hardening — the Loop Library audit (2026-06-25)

Beyond Osmani's post, we audited fg-loop again against the **shared guardrail DNA** of Forward Future's [Loop Library](https://signals.forwardfuture.ai/loop-library/) (69 loop recipes). Most of that DNA — machine-verifiable stop conditions · "the AI thinks it's done" is not a stop · no progress over two rounds · Reflexion · an evidence ledger · stateless resume · an independent machine checker — was already in place, so only two genuine gaps were borrowed (ADR-0016, 7th amendment):

- **The tension wall** — oscillation, where a fix-forward breaks a stop check that already passed, is now **detected mechanically** as a pass→fail regression in the ledger (`regressed: ×N`), halting early and reporting the conflicting pair before the cap is exhausted (lenient + one retry). It covers the blind spot where the existing no-progress wall (`×N`) missed the ping-pong — Loop Library #034 names oscillation as a first-class stop reason.
- **The safety wall** — even *inside* the authorized scope, an always-halt action class (irreversible/destructive/external; 7 by default) stops every fix-forward attempt (a generated backlog plan and a `verified: failed` in-place repair alike) **before** it is applied. It writes the approval-gate DNA running throughout the Loop Library into the contract itself (the in-scope-destructive gap the harness permission gate misses under broad permissions). The honest limit — that it is a best-effort self-classification — is recorded in the ADR.

Splitting out a budget (tokens/time, separate from the replan cap) and diversifying check states (proved/weak/contradicted) were rejected as YAGNI. Both walls arise only from *generated or in-place-repaired* fix-forwards, so they are **fg-loop-exclusive** (they do not apply to `fg-next all`).

## What we did not adopt, and why

- **Automations (scheduled triage).** Deferred for two reasons. ① The pillar-1 constraint — automation cannot grill (grilling is a conversation), so its output can only reach "a candidate inbox for fg-ask," never a plan. ② This repo is a Markdown plugin with no CI and no tests, so scheduled discovery would have almost nothing to turn up on a recurring basis. **Where this gap does carry value is a large codebase that uses forge** — when such a project needs it, we will grill it then, along the pattern "scheduled triage → load into a `.forge/` inbox → the human grills it with fg-ask."
- **Connectors (MCP integration).** forge's state is deliberately file-based and self-contained. Wiring in an issue tracker creates a hard dependency on one specific external tool and breaks portability (install into any repo).
- **The dedicated subagent trio (explorer/retro-analyzer/verifier).** Still deferred — ADR-0013's revisit bar (concrete, reproduced pain) is unmet, and this post's generalities are not the new evidence that clears it. (The demand for adversarial review was met separately from these three, by `fg-adversarial-review` — ADR-0018.)
