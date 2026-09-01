# forge

![forge](./docs/icon-sm.png)

> An agent-engineering workflow plugin for Claude Code — one task through a single cycle of **ask·plan → execute → retro → done**.
> A loop-style workflow plugin built from twenty-two `fg-`-prefixed Claude Code skills — four that form the loop, plus eighteen utilities outside it.

[한국어](./README.ko.md)

The full docs below are also published as a docs site — sidebar navigation, search, dark mode — at **[gyuha.com/forge/docs/en](https://gyuha.com/forge/docs/en/)** (Korean: [gyuha.com/forge/docs](https://gyuha.com/forge/docs/)).

Planning happens as grill-with-docs-style conversational grilling, execution runs as a Claude Code Dynamic Workflow, the retro feeds learnings back into project docs (`CONTEXT.md` · ADRs · retro log), and the done step tidies up the cycle's leftovers — seals the task so the same task never runs twice.

## Quick start — you mostly only need three

Twenty-two skills look like a lot, but day to day you drive with **three**:

```
/fg-ask   →   /fg-run   →   /fg-next
 (plan)       (execute)     (auto-continue: verify → retro/seal)
```

- **`/fg-ask`** — start *every* task here. It grills the plan with you, one question at a time.
- **`/fg-run`** — runs the plan.
- **`/fg-next`** — does the *one next step* for you (verify → retro or seal). Run it again to keep moving.

**Even shorter** — plan once, then let it drive itself to completion:

```
/fg-ask   →   /fg-next all     (execute → verify → seal, looped until it needs you)
```

When you lose track: **`/fg-status`** just *shows* where you are; **`/fg-next`** just *does* the next thing. Tiny one-off change (typo, version bump)? **`/fg-quick`**. To ship the result: type **`배포` (deploy)**.

Everything else in the catalog below is optional scaffolding — reach for it only when a specific need comes up. If you remember just one line: **`/fg-ask` then keep calling `/fg-next` (or `/fg-next all`).**

## Choosing a lane — observe, assist, then run unattended

The three driving skills form a **trust ladder** — the same graduated-autonomy idea as loop engineering's L1→L2→L3 rollout (report → assisted → unattended). Start low, move up as you trust the loop on a given task:

- **L1 — observe (`/fg-status`)**: read-only. It just *shows* where every task stands and the single next step. Nothing runs. Use it to see the board before deciding.
- **L2 — assisted (`/fg-next`)**: does the *one* next step and stops. You stay in the seat between steps — review, then call it again. Best when you want to watch each transition.
- **L3 — unattended (`/fg-loop` or `/fg-next all`)**: drives whole task loops to completion. `/fg-next all` drains a human-grilled backlog until it's empty; `/fg-loop` converges on a machine-verifiable goal, generating bounded fix-forward work along the way. Both halt at the walls (failed/unverifiable verification, a genuine fork, no progress; `/fg-loop` additionally at a check-tension oscillation, a safety/irreversible action, a stalled wait, or a check command that cannot execute) and hand back with full context. `/fg-loop` also distinguishes **waiting** on external evidence (CI, a deploy) from failure — it asks nothing of you and simply resumes on the next trigger. Optionally (`driveCommit` in `.forge/config.json`, **off by default**) each seal also leaves a local commit, so an unattended run has a rollback point per task — commit only, never push; a refused commit is a wall.
  - **Running L3 unattended needs no user action — forge ships its own `Stop` hook** ([ADR-0028](./.forge/adr/0028-unattended-drive-continuation-and-goal-pairing.md), amended 2026-08-22). A turn ends when the model stops calling tools, and the only mechanism that can prevent that is a Stop hook — which is why `/goal` used to be required. Now the drive writes a `drive.md` marker at entry and forge's own hook returns `exit 2` while it lives, so the drive crosses turn boundaries (a background workflow finishing, a pause) on its own until it's done or hits a wall. **Deleting that marker is how the drive says "I may stop"** — it is deleted at every wall, at the terminal state, and before any pause only you can end (a workflow script approval always needs you). Two bounds — **30 minutes** and **50 blocked stops** — keep a drive that died or looped from wedging the session, and every failure path in the hook allows stopping. `/goal` remains as the **fallback**: hooks load at session start, so a session that predates installing or updating forge has none, and there the old behavior holds (one cycle, then re-issue the trigger).

Rule of thumb: grill the plan with `/fg-ask` first — that human judgment is L1 and is never automated — then pick the lowest lane you're comfortable with. `/fg-loop` is L3 for a goal you can pin to runnable checks (`grep`/test/build); `/fg-next all` is L3 for a queue you've already grilled.

## Which one holds the work — `fg-ask`, `fg-loop`, `fg-agenda`

Three skills hold work that outlives a single step, and they are easy to confuse because **all three open with a conversation**. What differs is *what that conversation pins down*:

> **`fg-agenda` sits upstream of the plan · `fg-ask` makes the plan · `fg-loop` drives past it.**

| Axis | `fg-ask` | `fg-loop` | `fg-agenda` |
| --- | --- | --- | --- |
| Position | loop stage ① | outside — L3 unattended drive | outside — planning utility |
| What the opening conversation pins down | work slices + completion criteria | **machine-verifiable** stop checks + replan cap | a destination + the open questions |
| File it holds | `backlog/<slug>.md` | `loop.md` | `agenda.md` |
| Who answers | you, every question | nobody — it runs unattended | you, every question (the agent only *finds* them) |
| Done when | an executable plan exists | every check passes (machine verdict) | nothing is left to decide (judgment) |
| When it can't proceed | asks you the next question | halts at a wall, hands back with context | writes it into fog and moves on |
| Lifespan | one session | many sessions — deletes `loop.md` on goal met | many sessions — deletes `agenda.md` when empty |

**The selection test — what can you produce right now?**

- I can name the work slices, even roughly → **`fg-ask`**. This is the default; the other two are exceptions.
- I can express "done" as commands that pass or fail → **`fg-loop`**.
- I can do neither, and the honest answer to *"what first?"* is *"I don't even know what has to be decided"* → **`fg-agenda`**.

They chain rather than compete — an agenda resolves one question at a time by grilling, and the moment a decision makes something buildable it leaves for the backlog:

```
fg-agenda ──one question──▶ (fg-ask's grilling) ──▶ a line under "Decided"
    └──a decision became buildable──▶ fg-ask ──▶ backlog ──▶ fg-run ──▶ …
                                                    └── or let fg-loop / fg-next all drive it
```

`fg-agenda` defers to `fg-ask` on its own: if the breadth-first pass surfaces **no fog**, it writes no agenda and points at `fg-ask` — so reach for it only when the way genuinely isn't visible yet. And `fg-loop` is the mirror image of `fg-agenda`: unattended with a machine stop condition, versus human-answered with a judgment one. That is why they are two skills and not one.

## Use cases — typical flows

Reach for the right sequence by situation. The everyday and unattended rows point back to the sections above rather than repeating them.

| Situation | Flow |
| --- | --- |
| **First-time setup** (new project/codebase) | `fg-map` (map the code) → `fg-agents` (generate domain agents — **restart the session** so they load, [ADR-0024](./.forge/adr/0024-fg-agents-and-domain-agent-execution.md)) → `fg-ask` (first task) → the loop |
| **Everyday task** | `fg-ask → fg-run → fg-next` — see *Quick start* above |
| **Tiny one-off** (typo, version bump) | `fg-quick` — grills lightly, runs directly, no formal artifacts |
| **Unattended to done** | a grilled queue: `fg-ask` ×N → `fg-next all` · a machine-verifiable goal: `fg-loop` — see *Choosing a lane* (L3) |
| **Re-entry / health** | *where am I*: `fg-status` (shows) / `fg-next` (does the next step) · *is the state healthy*: `fg-doctor` |
| **Wrap-up / ship** | (optional hostile review: `fg-adversarial-review`) → `fg-learn` (retro) → `fg-done` (seal) → type `배포` (deploy) |
| **Security check** (whole codebase) | `fg-security` (audit) → approve severity-gated findings → `fg-run` (fix-forward plans) → re-audit (upstream recommends repeat runs) |
| **Maintenance** | retire stale ADRs `fg-cleanup` · integrate a merged branch `fg-merge` · discard incomplete work `fg-drop` · toggles `fg-tdd`/`fg-eco` · statusline `fg-statusline` |
| **Team use** (branches + CI) | seal on the branch → `git merge` → `fg-merge` (or `fg-merge <branch>` to do both; `forge-merge.sh` in CI) · `forge-doctor` as an AI-free CI gate — see **[docs/team-workflow.md](./docs/team-workflow.md)** |

First-time setup is the one sequence *Quick start* skips: on a fresh project, map the code and (optionally) generate domain agents **before** your first `fg-ask` — `fg-agents` cards load only at session start, so restart once after generating them (ADR-0024).

## Skill catalog

The four loop stages, then the eighteen utilities outside the loop:

| Skill | Stage | One-line role |
| --- | --- | --- |
| `fg-ask` | ① Ask·plan | grill-with-docs verbatim — grills the plan against domain, terms, and decisions |
| `fg-run` | ② Execute | Runs the plan as a Dynamic Workflow (one plan runs immediately, several show a priority-sorted selection) |
| `fg-learn` | ③ Retro | Promotes learnings to docs, surfaces the next inquiry |
| `fg-done` | ④ Done | Tidies up the cycle — confirms retro, closes `STATUS.md`, archives, clears active state, seals; the mechanical seal runs as a deterministic script (`forge-done.sh`/`.js`) shared by every seal path ([ADR-0030](./.forge/adr/0030-fg-done-deterministic-seal-script.md)). `all` mode batch-seals every already-executed task (retros skipped, backlog untouched, verification gate intact) |
| `fg-map` | Utility | Maps the codebase into `.forge/codebase/` so grilling reads a map instead of re-exploring |
| `fg-quick` | Utility | Lightweight lane for trivial tasks — grills lightly, runs directly with no formal artifacts |
| `fg-status` | Utility | Read-only — surveys `.forge/` and prints where every task stands plus the single next step |
| `fg-next` | Utility | Derives the single next step (via fg-status's state machine) and runs it; `all` mode drives to the wall |
| `fg-loop` | Utility | Goal-driven loop with bounded replan — drives run → UAT → seal until machine-verifiable checks pass. Both unattended lanes can leave a **per-task rollback commit** (opt-in `driveCommit`, off by default; commit only, never push) |
| `fg-tdd` | Utility | Toggles persistent TDD mode in `.forge/config.json` |
| `fg-eco` | Utility | Toggles eco mode — when on, caps delegated workflow subagents at `sonnet`, activates the embedded Eco laziness-first discipline (`ECO.md` — code simplicity + terse-communication output): injected into fg-run subagents, woven into fg-ask grilling as a YAGNI lens, adopted by the session — **and replaces task-end handoffs with a compact summary table** (fg-run's handoff, fg-done's single seal, batch/unattended paths); execution-time narration is untouched |
| `fg-merge` | Utility | After a `git merge`, folds a branch's `.forge/branch/<branch>/` into `.forge/` — or `fg-merge <branch>` runs that `git merge` for you (interactive, default branch). Script-backed (`forge-merge.sh`/`.js`), usable AI-free in CI |
| `fg-cleanup` | Utility | Retires stale/superseded ADRs out of the active set into `.forge/adr/retired/` |
| `fg-statusline` | Utility | Shows forge's loop progress in your statusline — method 1 (append) wraps your existing one as an extra row, or method 2 (merge) installs a unified script with daleseo-style system info + forge progress |
| `fg-adversarial-review` | Utility | Optional hostile second look between fg-run and fg-learn — six lenses, fix-forward findings |
| `fg-doctor` | Utility | Read-only integrity check of the `.forge/` state contract and docs/manifest sync — script-backed, usable as an AI-free CI gate |
| `fg-help` | Utility | Read-only usage help — `/fg-help` prints an overview of every forge skill grouped by loop stage + outside-the-loop utilities, `/fg-help <command>` a 4-line detail; reads each skill's own `description` as the single source, LLM-rendered in your language (no script twin) |
| `fg-drop` | Utility | Discards incomplete work (backlog/active/executed/halted loop) — risk-labeled list, hard-delete or archive to `.forge/dropped/` |
| `fg-agents` | Utility | Generates project domain agents (`.claude/agents/<role>.md`) by conversational grilling — fg-run dispatches a matching role as `agentType` after a session restart |
| `fg-showme` | Utility | Browser-based visual companion (vendored from superpowers, MIT) — a zero-dependency local server shows HTML the agent pushes (mockups, diagrams, visual A/B options) and takes your answers back as events. **It fires for explanations too, not only questions** — when a structural explanation (a branching flow, state transitions, a multi-axis comparison) outgrows a text flow diagram (`A → B → C`), it is offered as well; if the text diagram carries it, the answer stays in the terminal — a required confirm button on choice screens wakes you directly with no terminal turn, exploratory clicks don't; offered just-in-time once during fg-ask grilling (a decline stands), `fg-showme stop` shuts it down. Its frame renders in the Anthropic/Claude design system documented at the repo root in `DESIGN.md` (cream canvas + coral accent + serif display), so every screen an agent pushes inherits it |
| `fg-agenda` | Utility | Decision queue for work still in fog — settles a destination with you, then surfaces what must be decided and keeps it in `.forge/agenda.md`, resolving one question at a time until the way is clear and then deleting itself; the agent finds the decisions, **you answer them**, and anything that becomes buildable leaves for the backlog |
| `fg-security` | Utility | Security audit of a codebase (methodology vendored from cloudflare/security-audit-skill, MIT) — multi-phase, multi-agent hunting by attack class; artefacts stay OUTSIDE the repo (upstream's `~/security-audit-skill/`) so a vulnerability list has no path into a commit at all, and findings past a severity gate become fix-forward backlog plans on your approval |

Per-skill detail — input/output/next, triggers, and the rationale ADRs — is in **[docs/skills.md](./docs/skills.md) (Korean)**. `fg-ask` is the loop's entry point (it triggers on "start with forge", "new task", "refine the plan"); the utilities are on-demand, each triggered by its own utterances.

## Overall flow

When one skill finishes, it **states** the way to the next as a fixed four-row **handoff table** — *what was just done · next step · how to start · alternative* — at each of the **13 points** that have a real next step (the other eight are toggles and utilities with nothing to point at, and keep their prose). The next step then sits in the same place every time instead of being buried mid-paragraph: the pain this fixes is **findability, not length** ([ADR `260805-231104`](./.forge/adr/260805-231104-handoff-table.md)). It is a different thing from the `eco` summary table, which answers *what was done*; this one answers *what comes next*, and it renders whether `eco` is on or off. **The statement form is unchanged** — the table is text output, never a menu: no "shall I continue?", and chaining into the next stage is still `fg-next`'s job ([ADR-0015](./.forge/adr/0015-fg-run-handoff-menu-others-stated.md), amended 2026-06-15 — fg-run's old four-way menu was dropped because it re-triggered on the unchanged active-slot state and looped). This holds for **every** handoff, including `fg-run`'s single-task end: default retro via `fg-learn`, skip+seal via `fg-done` only when divergence is low, re-grill via `fg-ask` when it is high — stated, then stop. After `fg-done` seals a task, the loop restarts at `fg-ask` only as a **new task** — the same task never runs again. Two utilities tend this fuel from outside the loop: `fg-map` writes the codebase map `fg-ask` reads, and `fg-cleanup` curates the ADR set `fg-ask` reads.

```
fg-ask ───▶ fg-run ───▶ fg-learn ───▶ fg-done
① ask/plan      ② execute       ③ retro       ④ done
(grilling·      (Dynamic WF)    (reflect      (seal·
 conversational)                 into docs)    re-run guard)
```

**How it phrases anything is a separate always-on rule.** Every skill carries an `**Explaining forge**` paragraph next to its language rule: gloss a forge-specific term the first time it appears in a message, put the purpose before the mechanism, and lead with the answer. It is **not** gated on `eco` — the installers who most need a gloss are the ones least likely to have turned eco on — and it governs **vocabulary** while `eco`'s terse rules govern **form**, so terseness never deletes a gloss. A `fg-doctor` check compares each skill's copy against a single canonical definition, so the rule cannot quietly drift out of one of them ([ADR `260824-134246`](./.forge/adr/260824-134246-explaining-forge-always-on.md)).

A detailed flow diagram (loop ↔ document artifacts) is in [docs/state-contract.md](./docs/state-contract.md) (Korean).

## Install

In a Claude Code session, add the GitHub marketplace, then install the plugin.

```
/plugin marketplace add gyuha/forge
/plugin install forge@forge
```

To install from a local clone instead (e.g. while developing), pass the path to the repo root:

```
/plugin marketplace add /path/to/forge
/plugin install forge@forge
```

Notes:

- The GitHub install pulls the repo's default branch (`main`) — to test a change via install, it must be pushed to `main` first.
- Skills are auto-discovered from `skills/<name>/SKILL.md`; no extra configuration is needed.
- To update later, run `/plugin marketplace update forge`, and to remove, `/plugin uninstall forge@forge`.

After installing, the loop starts in a Claude Code session by triggering `fg-ask`, or with an utterance like "start with forge".

## Shared state and directories

State is passed through files so the flow continues even when stages are invoked independently. A single `.forge/` directory holds everything — both the volatile loop state and the git-tracked permanent docs (the `.gitignore` excludes `.forge/` by default and whitelists only the permanent docs). The active slot is always exactly one — one `plan.md` = one `run.md` = one seal. On a non-default branch the whole forge root moves to `.forge/branch/<branch>/` (git-tracked) so parallel branches never collide ([ADR-0011](./.forge/adr/0011-branch-isolated-forge-root.md)).

The full directory layout, the `.gitignore` pattern, branch isolation, the retro-skip rule ([ADR-0002](./.forge/adr/0002-optional-retro-skip.md)), and the verification-before-seal gate ([ADR-0009](./.forge/adr/0009-verification-gate-before-seal.md)) are documented in **[docs/state-contract.md](./docs/state-contract.md) (Korean)**.

**And it is closed at the next question.** When you start a new task while a previous one sits unsealed, fg-ask's STEP 0 decides by how much judgment is left: none (verification is sealable and the retro is resolved, or only the retro is owed and the run barely diverged) → it **seals without asking**, reports one line, and keeps grilling in the same turn; judgment remains (high divergence, `verified: pending`/`failed`, a halted goal loop) → it asks, but **holds your request and returns to it** once the tail is closed — you never have to re-trigger fg-ask. Its reach is the active slot only; tasks parked in `executed/` are a deliberate wait, not part of the tail, so they are reported and left alone ([ADR 260727-201115](./.forge/adr/260727-201115-fg-ask-auto-close-sealable-tail.md)).

**Forgetting to seal is caught at session entry.** forge ships two hooks (`hooks/hooks.json`, installed with the plugin — no settings edit). The first, at `SessionStart`, checks for an **unsealed tail** — a task that ran but was never sealed, a task parked awaiting retro, or a halted goal loop — and, only then, injects a short notice so the agent tells you about it before starting new work. It never runs or seals on its own initiative before you answer — fg-ask's STEP 0 auto-close is the one approved exception — so the decision stays yours. A clean repo, or one with only a backlog waiting, gets nothing at all. The second, at `Stop`, is what lets an unattended drive cross turn boundaries without `/goal` — it blocks only while a drive's `drive.md` marker is live and inside its bounds, so a session that is not driving is untouched ([ADR-0028](./.forge/adr/0028-unattended-drive-continuation-and-goal-pairing.md)). Because hooks load at session start, a newly installed or edited hook applies from the **next** session ([ADR 260727-201031](./.forge/adr/260727-201031-forge-ships-session-start-hook.md)).

How git and branches are operated with forge — the git-abstinence model, the commit points, and a feature-branch walkthrough with git CLI — is in **[docs/git-workflow.md](./docs/git-workflow.md) (Korean)**.

## The two pillars

1. **Grilling (planning) is conversational, outside the Dynamic Workflow.** A Dynamic Workflow cannot take user input mid-run, so question-by-question grilling never goes inside a workflow.
2. **Docs are the loop's fuel, not its by-product.** Terms sharpened in planning become the standard for execution, and retro learnings become the starting point of the next plan.

## forge vs. other harnesses

| Axis | forge | GSD Core | GStack | Superpowers |
| --- | --- | --- | --- | --- |
| Pure file-based persistent state (no DB) | ✓ (`.forge/` markdown+JSON, git-tracked) | ✓ (`STATE.md`/`CONTEXT.md`) | △ (GBrain defaults to a DB — PGLite/Supabase/remote MCP) | △ (design docs saved to disk; no documented state contract) |
| Explicit restraint gate on doc promotion | ✓ (ADR only when irreversible + surprising + a real trade-off) | — | — | — |
| Retro learnings auto-feed the next planning session | ✓ | — | — | — |
| Evidence-first, multi-state verification gate before sealing | ✓ (5 states: yes/skipped/n-a/pending/failed, blocks sealing) | △ (has a Verify phase) | △ (`/qa`, `/canary`) | △ (`verification-before-completion` skill) |
| Seal blocks the same task from ever re-running | ✓ (`done/` archive) | — | — | — |
| Graduated autonomy (observe→assist→unattended) with automatic halt walls (incl. tension/oscillation detection) | ✓ | — | — | — |
| TDD as a per-project/per-task toggle (not all-or-nothing) | ✓ (config default + per-task override) | — | — | △ (TDD is mandatory, always on) |
| Generates project-specific domain agents on demand | ✓ (interview-driven, only roles that earn their place) | — | △ (25+ fixed built-in specialist skills) | — |
| Built-in cost-discipline mode (subagent model cap + simplicity discipline) | ✓ (eco mode) | — | △ (model benchmarking tool, different angle) | — |
| A dedicated security-audit skill | ✓ (`fg-security` — vendored cloudflare methodology; artefacts kept outside the repo) | — | ✓ (`/cso`) | — |
| Target platform breadth | Claude Code only | 10+ runtimes | 10 agents | 9+ agents |

Legend: ✓ explicitly supported · △ something similar exists but differs in form/rigor · — not found in public docs (not claimed absent)

### forge's strengths

- Docs are the loop's fuel, not a byproduct — ADRs are created only when all three gate conditions hold, which structurally prevents doc bloat.
- No seal without verification — pending/failed/skipped(reason)/n-a(reason) are honestly distinguished so an unverified task can never quietly become "done."
- Unattended automation still stops itself at human-defined walls (failed verification, an unresolvable fork, tension/oscillation ping-pong, safety-class actions, a stalled wait on external evidence, a check command blocked by a missing tool or credential).
- Sealing means the loop really ends — a sealed task is structurally blocked from ever re-running.
- Zero infrastructure — no DB, no server, no npm install; just `/plugin install`.
- Instead of a fixed roster of specialists, forge interviews the project to find which roles actually recur, and generates agent cards only for those.
- Honest trade-off: forge is Claude Code-only, the narrowest platform reach of the four. In exchange, it goes deep on Claude Code-native capabilities (Dynamic Workflow, AskUserQuestion, Skill chaining) instead of flattening them to a lowest common denominator.

### What forge doesn't do

- **Cross-model benchmarking** — GStack has it (`/codex`, `gstack-model-benchmark`), forge doesn't (deliberate: model choice is Claude Code's own domain, not forge's).
- **Browser automation, iOS QA, design generation** — GStack has these (`/browse`, `/ios-qa`, `/design-*`), forge doesn't (deliberate: forge stays scoped to the plan→execute→retro→done loop, not the whole SDLC).
- **Team-shared, searchable knowledge base across projects** — GStack's GBrain (Supabase-backed) does this; forge's `.forge/` is scoped to a single repo.
- **Always-on, unconditional TDD enforcement** — Superpowers deletes code written before tests; forge's TDD is an opt-in toggle a project can choose not to use.
- **Automatic per-task git worktree isolation** — Superpowers creates one automatically; forge isolates state per branch (ADR-0011) but doesn't automate worktree creation itself.
- **Scored quality gate on planning documents** — GStack's `/spec` blocks below a 7/10 Codex score; forge's ADR gate is qualitative (three conditions), not numeric.

## Credits

The grilling/documentation pattern of `fg-ask` (including the verbatim original) and `CONTEXT-FORMAT.md`/`ADR-FORMAT.md` are inherited from [grill-with-docs in mattpocock/skills](https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs).

The code-simplicity discipline used by **eco mode** (`fg-eco`) — the laziness-first decision ladder embedded in `skills/fg-eco/ECO.md` and injected into fg-run subagents / fg-ask grilling — is adapted from the [Ponytail skill by DietrichGebert](https://github.com/DietrichGebert/ponytail).

The terse-communication output rules in the same `ECO.md` — compressing execution/reporting prose to save context while keeping code/errors verbatim and leaving grilling questions and generated docs in full — are adapted from the [caveman skill by JuliusBrussee](https://github.com/JuliusBrussee/caveman).

The **always-on `**Explaining forge**` rule** carried by every `SKILL.md` — gloss a forge-specific term on first use, purpose before mechanism, lead with the answer — is adapted **in concept** from the [eli5 skill by dreambigou](https://github.com/dreambigou/eli5) (MIT). No code was vendored: only the vocabulary-calibration rules were taken, its audience tables were dropped (forge output has one reader), and it is deliberately **not** part of eco — the installers who most need a gloss are the ones least likely to have eco on. It governs **vocabulary** while `ECO.md`'s terse rules govern **form**, so terseness never deletes a gloss (ADR `260824-134246`).

The landing page (`docs/index.html`) was built with the **Visual Companion** of [Superpowers by Jesse Vincent (obra)](https://github.com/obra/superpowers/blob/main/skills/brainstorming/visual-companion.md) — its browser-preview design tool that lays out mockup, layout, and color options before the page is coded.

The **security-audit methodology** behind `fg-security` is [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill), **vendored** under MIT — its entry file plus nine attack-class playbooks, `report-schema.json` and `validate-findings.cjs` live in `skills/fg-security/`, with the licence copy at `skills/fg-security/LICENSE`. Only the entry file was renamed (`SKILL.md` → `AUDIT.md`, so it does not collide with forge's own skill-discovery path); the other eleven files are kept **byte-for-byte with upstream** so a future diff stays cheap. forge adds only the loop integration — a severity gate, fix-forward plans on approval, and keeping artefacts outside the repo.
