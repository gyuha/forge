# forge

> A development loop that takes one task through a single cycle of **ask·plan → execute → retro → done**.
> A loop-style workflow plugin built from twelve `fg-`-prefixed Claude Code skills — four that form the loop, plus eight utilities outside it (`fg-map`, `fg-quick`, `fg-status`, `fg-next`, `fg-tdd`, `fg-eco`, `fg-merge`, `fg-cleanup`).

[한국어](./README.ko.md)

Planning happens as grill-with-docs-style conversational grilling, execution runs as a Claude Code Dynamic Workflow, the retro feeds learnings back into project docs (`CONTEXT.md` · ADRs · retro log), and the done step tidies up the cycle's leftovers — seals the task so the same task never runs twice.

## Skill catalog

| Skill | Stage | One-line role | Input | Output | Next |
| --- | --- | --- | --- | --- | --- |
| `fg-ask` | ① Ask·plan | grill-with-docs verbatim — grills the plan against domain, terms, and decisions | User request | `.forge/backlog/<slug>.md` + CONTEXT/ADR | `fg-run` |
| `fg-run` | ② Execute | Runs the plan as a Dynamic Workflow — one unexecuted plan runs immediately (no menu), several show a selection menu (last option "Run all") | `.forge/backlog/`, `plan.md` | Results + `.forge/run.md` + `STATUS.md` (or `executed/`) | `fg-learn` |
| `fg-learn` | ③ Retro | Promotes learnings to docs, surfaces the next inquiry | `.forge/run.md`, `plan.md`, `executed/` | `.forge/retro/*.md` + promotions | `fg-done` (re-grill via `fg-ask` if diverged) |
| `fg-done` | ④ Done | Tidies up the cycle — confirms retro, closes `STATUS.md` to done, archives, clears active state, closes the loop | `.forge/*` | `.forge/done/<date-slug>/` | `fg-ask` / end |
| `fg-map` | Utility (outside the loop) | Maps the codebase with parallel subagents into `.forge/codebase/` so grilling reads a map instead of re-exploring the code (cuts context rot) | Codebase | `.forge/codebase/*.md` (7 docs) | — (consumed by `fg-ask`) |
| `fg-quick` | Lightweight lane (outside the loop) | For trivial tasks — grills lightly, then runs directly with no formal artifacts (no ADR/plan/retro); bails to `fg-ask` if the task turns out non-trivial | User request | one entry in `.forge/quick/LOG.md` | — (self-contained) |
| `fg-status` | Reporter (outside the loop) | Read-only — surveys `.forge/` and prints where every task stands plus the single next step you need; writes nothing, never auto-runs | `.forge/*` (read-only) | printed report (no files) | — (suggests next step) |
| `fg-next` | Orchestrator (outside the loop) | Derives the single next step via fg-status's state machine and runs it — announces the step, then invokes the skill (not just reporting); one-shot; fg-status reports, fg-next acts | `.forge/*` (read-only itself) | none — delegates to the invoked skill | — (invokes the next skill) |
| `fg-tdd` | Toggle (outside the loop) | Turns persistent TDD mode on/off in `.forge/config.json` — `fg-ask` asks per task with this as the default answer; `fg-run` runs test-first when the plan's marker is on | `on`/`off`/(none) | `.forge/config.json` (`tdd`) | — (setting only) |
| `fg-eco` | Toggle (outside the loop) | Turns eco mode on/off in `.forge/config.json` — when on, `fg-run` caps its delegated workflow subagents at `sonnet` (lower only; the main session's model is untouched) | `on`/`off`/(none) | `.forge/config.json` (`eco`) | — (setting only) |
| `fg-merge` | Integrator (outside the loop) | After a `git merge`, folds a branch's `.forge/branch/<branch>/` into `.forge/` — renumbers ADRs (+cross-refs), merges CONTEXT terms, folds done history, removes the branch folder; halts on genuine conflicts. Does not run git | `.forge/branch/<branch>/` | integrated `.forge/` docs | — (integration step) |
| `fg-cleanup` | Retirer (outside the loop) | Retires stale/superseded ADRs out of the active set — proposes candidates with rationale, and on approval moves each to `.forge/adr/retired/<NNNN>-slug.md` with a supersede/retire marking; numbers unchanged, nothing deleted. fg-ask stops reading `retired/` as source of truth | `.forge/adr/*.md` | `.forge/adr/retired/*` | — (ADR upkeep) |

`fg-ask` is the entry point of the loop — it handles both inquiry/triage and grilling (the former separate `fg-plan` step is folded into `fg-ask`). It triggers on utterances like "start with forge", "new task", "let's work on this", "refine the plan". `fg-done` triggers on "작업 완료", "봉인", "이거 마무리" (and still recognizes the legacy "작업 정리" / "forge complete" as aliases). `fg-map` is **not a loop stage** — it is an on-demand utility you run when the codebase has changed enough that the map is stale; it triggers on "map the codebase", "analyze the codebase". `fg-quick` is **also outside the loop** — a lightweight lane for trivial tasks (typo fixes, small renames, version bumps): it still grills, but lightly, then runs the change directly with no formal artifacts (no ADR/plan/retro), recording one line to `.forge/quick/LOG.md`. If the task turns out non-trivial mid-grill, it bails to `fg-ask` (the full loop). It triggers on "forge quick", "quick task", "이거 빨리 해줘". `fg-status` is a **read-only reporter, also outside the loop** — run it any time to see where every task stands (active slot, backlog, awaiting-retro, done history, quick log) and the single next step you need; it writes nothing and never auto-runs. It triggers on "forge status", "where am I", "어디까지 했지". `fg-next` is the **acting sibling of fg-status, also outside the loop** — it derives the same single next step (reusing fg-status's state machine, not reimplementing it) but **runs it** — announcing the step in one line then invoking the skill, rather than only reporting it (it acts and proceeds, no separate go-ahead needed); it is one-shot (one step, then the invoked skill's own handoff carries on), writes nothing itself, and delegates every action to the named skill. It is the cold-re-entry entry point ("I forget where I was — just do the next thing"). With an **`all` mode** (`fg-next all`) it drives backlog tasks to completion one after another until the backlog is empty — auto-progressing the linear mechanical steps and **always auto-skipping retros** (regardless of divergence), halting only at the conversational walls (a failed/unverifiable UAT, a genuine fork, or empty state); it is the momentum superset of `fg-run`'s "Run all", extending it through verify→done ([ADR-0010](./.forge/adr/0010-fg-next-all-momentum-mode.md)). It triggers on "forge next", "다음 단계", "이어서 해줘", "fg-next all", "다음 전부 진행". `fg-tdd` is **also outside the loop** — a toggle for persistent TDD mode stored in `.forge/config.json` (`fg-tdd on|off`, no arg shows the state); `fg-ask` asks per task whether to build it TDD-style with this setting as the default answer, and `fg-run` runs test-first when the plan's tdd marker is on. It triggers on "forge tdd", "tdd on/off", "TDD 켜/꺼". `fg-eco` is **also outside the loop** — a toggle for eco mode stored in `.forge/config.json` (`fg-eco on|off`; no arg shows the state and offers the on/off choice). When on, `fg-run` caps its delegated Dynamic Workflow subagents at `sonnet` — lower only (never raising a tier), yielding to an explicit user model instruction, and never touching the main session's model: a skill cannot switch it, so design (fg-ask) and done (fg-done) stay on the user's chosen model, giving a two-tier structure of strong = main session, normal = delegated execution ([ADR-0014](./.forge/adr/0014-fg-eco-subagent-model-tiering.md)). `fg-map` is deliberately out of its scope (map quality is grilling fuel). It triggers on "forge eco", "eco on/off", "에코 모드". `fg-merge` is the **integration utility for branch isolation, also outside the loop** — once you've `git merge`d a feature branch, it folds that branch's `.forge/branch/<branch>/` into the default-branch `.forge/`: renumbering the branch's ADRs to the next free numbers (rewriting cross-references), merging CONTEXT terms, folding `done/` history, and removing the branch folder. Mechanical parts run automatically; it halts and asks only on a genuine conflict (a term redefined, an ADR contradiction), and it never runs git itself. It triggers on "forge merge", "fg-merge \<branch\>", "브랜치 통합" ([ADR-0011](./.forge/adr/0011-branch-isolated-forge-root.md)). `fg-cleanup` is the **ADR-retirement utility, also outside the loop** — it retires stale or superseded ADRs out of the active decision set: it proposes retirement candidates with rationale and, on your approval, moves each approved ADR to `.forge/adr/retired/<NNNN>-slug.md` with a one-line `Superseded by ADR-NNNN` / `Retired (reason)` marking. Numbers never change and are never reused; nothing is deleted (the *why* is preserved on disk), and `fg-ask` stops reading `retired/` as source of truth so retired decisions drop out of grilling fuel. Retirement is human-approved, never automatic; sealing a finished task is `fg-done`, not this. It triggers on "forge cleanup", "ADR 정리", "ADR 은퇴", "오래된 ADR 치워" ([ADR-0012](./.forge/adr/0012-fg-cleanup-renamed-to-fg-done-cleanup-retires-adrs.md)).

## Overall flow

When one skill finishes, it **states** the way to the next (what was done, what comes next, how to start) and stops — it does not ask "shall I continue?"; chaining into the next stage is `fg-next`'s job. The one exception is `fg-run`'s single-task end, which offers an explicit four-way choice — retro then seal (default) / retro only / finish now (skip + seal, low-divergence only) / stop here ([ADR-0015](./.forge/adr/0015-fg-run-handoff-menu-others-stated.md), amended 2026-06-11); the Run-all batch handoff states and stops as well. After `fg-done` seals a task, the loop restarts at `fg-ask` only as a **new task** — the same task never runs again. Two utilities tend this fuel from outside the loop: `fg-map` writes the codebase map `fg-ask` reads, and `fg-cleanup` curates the ADR set `fg-ask` reads — retiring stale decisions into `.forge/adr/retired/` (which `fg-ask` does not read) so grilling runs on a cleaner active set.

```
fg-ask ───▶ fg-run ───▶ fg-learn ───▶ fg-done
① ask/plan      ② execute       ③ retro       ④ done
(grilling·      (Dynamic WF)    (reflect      (seal·
 conversational)                 into docs)    re-run guard)
```

```mermaid
flowchart LR
    A[fg-ask<br/>① ask·plan·grilling] --> E[fg-run<br/>② execute·Dynamic WF]
    E --> L[fg-learn<br/>③ retro]
    L --> C[fg-done<br/>④ done·seal]
    E -.re-grilling if diverged.-> A
    L -.re-grilling.-> A
    C -->|new task| A
    A -.terms.-> CTX[(.forge/CONTEXT.md)]
    A -.major decisions.-> ADR[(.forge/adr/)]
    L -.promotion.-> CTX
    L -.promotion.-> ADR
    L -.session learnings.-> RETRO[(.forge/retro/)]
    C -.seal.-> DONE[(.forge/done/)]
    MAP[fg-map<br/>utility · outside loop] -.writes.-> CB[(.forge/codebase/)]
    CB -.read before grilling.-> A
    CLEAN[fg-cleanup<br/>utility · outside loop] -.retires stale.-> ADRRET[(.forge/adr/retired/)]
    ADR -.active set read before grilling.-> A
    style A fill:#e3f2fd
    style C fill:#ffe0b2
    style MAP fill:#e8f5e9
    style CLEAN fill:#e8f5e9
```

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

State is passed through files so the flow continues even when stages are invoked independently. A single `.forge/` directory holds everything — both the volatile loop state and the git-tracked permanent docs. The `.gitignore` excludes `.forge/` by default and whitelists only the permanent docs, so location is `.forge/` for all of it and the distinction is whether git tracks it.

```
repo/
├── CONTEXT-MAP.md             # only for multi-context repos (stays at root)
└── .forge/                    # all loop documents live here
    │                          # ── permanent docs (git-tracked via whitelist) ──
    ├── CONTEXT.md             # glossary (single-context)
    ├── adr/0001-*.md          # architecture decisions
    ├── adr/retired/           # retired/superseded ADRs (moved by fg-cleanup)
    ├── retro/YYYY-MM-DD-*.md  # retro log
    ├── codebase/*.md          # codebase map from fg-map
    ├── config.json            # project settings (tdd · eco · defaultBranch) — global, never branch-resolved
    │                          # ── volatile loop state (gitignored) ──
    ├── backlog/<slug>.md      # ① fg-ask grilling output — queue of unexecuted plans
    ├── plan.md                # active slot: source of truth for the current cycle (promoted from the backlog by fg-run)
    ├── run.md                 # ② fg-run output = plan vs actual
    ├── STATUS.md              # active slot: fg-run writes this on finish (status: executed, verified: pending, retro: pending) — verified becomes yes/skipped/n/a (sealable) or failed (blocks), retro becomes a path or "skipped"
    ├── executed/<slug>/       # awaiting retro after "Run all" (plan+run+STATUS, no retro yet)
    ├── done/<date-slug>/      # ④ fg-done seal archive (plan+run+STATUS, status: done)
    ├── quick/LOG.md           # fg-quick lane log (one line per quick task)
    └── branch/<branch>/       # non-default branches operate their WHOLE forge root here (git-tracked); fg-merge integrates it into .forge/ (ADR-0011)
```

On a non-default branch every `.forge/...` path above is resolved under `.forge/branch/<branch>/` instead (the default branch keeps using `.forge/` directly) — with two global exemptions that always stay at top-level `.forge/` on every branch: `.forge/config.json` (it holds `defaultBranch`, which the rule itself must read) and `.forge/codebase/` (the map is shared reference fuel). The resolution rule is defined once in `skills/fg-run/FORGE-ROOT.md` and referenced by every loop skill.

`.gitignore` pattern:

```gitignore
.forge/*
!.forge/CONTEXT.md
!.forge/adr/
!.forge/retro/
!.forge/codebase/
!.forge/config.json
!.forge/branch/        # non-default branch roots are tracked whole (ADR-0011)
```

- Each skill reads its input from `.forge/` and writes its output to `.forge/` (resolved per branch — see below). Even calling `fg-run` alone finds the backlog and active slot and continues.
- **Branch isolation ([ADR-0011](./.forge/adr/0011-branch-isolated-forge-root.md)).** On a non-default branch the whole forge root moves to `.forge/branch/<branch>/` (git-tracked), so parallel branches never collide on `.forge` state — ADR/task numbers, CONTEXT.md, and volatile state are all namespaced by branch. Reads of the permanent fuel (CONTEXT.md, ADRs, retros) overlay the top-level base docs (branch wins) so a fresh branch still grills on main's glossary and decisions; writes stay branch-rooted. After a `git merge`, `fg-merge` integrates the branch root into `.forge/` (renumbering ADRs, moving retros, merging CONTEXT terms, then removing the branch folder). The default branch is unchanged. The resolution rule lives once in `skills/fg-run/FORGE-ROOT.md`.
- If the backlog has several tasks, `fg-run` presents the unfinished list as a selection menu (last option: "Run all"). The active slot is always exactly one — one plan.md = one run.md = one seal.
- If an input file is missing, the skill points to the prior step.
- If the active slot, backlog, and awaiting-retro queue are all empty = no work in progress. `fg-run` does not run on an empty state (re-run guard). Completion is determined by `done/*/STATUS.md` (status: done).
- The retro can be **skipped** for a trivial, low-divergence task. fg-run offers it as an explicit choice at the handoff — never automatic, and never offered when the result diverged significantly from the plan (that is exactly when there is something to learn). Skipping records `retro: skipped` in STATUS.md, which fg-done accepts as satisfying its no-seal-without-retro guard; no retro file is written. Retro stays the default ([ADR-0002](./.forge/adr/0002-optional-retro-skip.md)).
- The work carries a **recorded verification decision before it can be sealed**. The loop order is run → verify → learn → done: right after execution, fg-run's conversational handoff runs a UAT against the plan's goal and records the outcome in STATUS.md `verified:` — `yes (evidence)` (confirmed working, carrying a one-line piece of evidence for *how* — the command run / output observed, e.g. `yes (npm test → 42 passing)`; in TDD mode the passing slice tests are that evidence), `n/a (reason)` (nothing runnable to verify, e.g. a docs-only change), or `skipped (reason)` (a deliberate, auditable waiver). Two states **block** sealing: `pending` (the UAT hasn't happened — initial value or an interrupted handoff) and `failed (reason)` (the UAT ran and the result doesn't achieve the goal — routes to fix-and-re-run or re-grill, never to seal). fg-done will not seal while `verified:` is a blocking value (the **no-seal-without-verification guard**), so nothing lands in `done/` without a recorded *sealable* decision. Note `skipped` **still seals** — it is an explicit waiver, not a confirmation (the same restraint as retro-skip); the gate's guarantee is "no silent omission," not "every task confirmed working" ([ADR-0009](./.forge/adr/0009-verification-gate-before-seal.md)). Tasks sealed before ADR-0009 predate the field and carry `verified: n/a (legacy pre-ADR-0009)`; a missing `verified:` in `done/` history means legacy data, not a gate failure.

## The two pillars

1. **Grilling (planning) is conversational, outside the Dynamic Workflow.** A Dynamic Workflow cannot take user input mid-run, so question-by-question grilling never goes inside a workflow.
2. **Docs are the loop's fuel, not its by-product.** Terms sharpened in planning become the standard for execution, and retro learnings become the starting point of the next plan.

## Credits

The grilling/documentation pattern of `fg-ask` (including the verbatim original) and `CONTEXT-FORMAT.md`/`ADR-FORMAT.md` are inherited from [grill-with-docs in mattpocock/skills](https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs).
