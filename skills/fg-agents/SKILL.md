---
name: fg-agents
description: Generates a project's domain agents — conversational grilling derives the recurring roles, then writes standard Claude Code subagent cards to .claude/agents/<role>.md (each `description` carrying a "when to use" so fg-run can dispatch a matching role as agentType). Cards load only at session start, so RESTART the session after generating them before fg-run can use them. On-demand utility outside the loop. Use in contexts like 'forge agents', '도메인 에이전트 만들어', '에이전트 팀 구성', 'create project agents', 'domain agents', 'agent roles'.
---

# fg-agents — generate project domain agents (outside the loop)

This is **not** a stage of the forge loop (fg-ask → fg-run → fg-learn → fg-done). It is an **on-demand utility** — like fg-map, fg-cleanup, and fg-merge — that produces project assets the loop can later use: standard Claude Code subagent definitions under `.claude/agents/<role>.md`. fg-run (extended per ADR-0024) discovers those cards and dispatches a slice through the matching role via the workflow `agent()` call's `agentType`. fg-agents only **creates** the cards by grilling the project's domain; calling them is fg-run's job, and is entirely graceful — a project with no domain agents runs exactly as before.

**These agents are the user project's, not forge's.** fg-agents writes them into the *project's* `.claude/agents/`; it does not add agents to the forge plugin (ADR-0013 stands — see ADR-0024 for why this is non-conflicting). The roles are whatever this project's work needs, derived by grilling, not a fixed forge-supplied set.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — grilling questions, the proposed-role list, confirmations, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** The generated `.claude/agents/<role>.md` cards are likewise written in the user's language, except the frontmatter `name` field (a kebab-case identifier, ASCII).

**Forge root**: fg-agents *reads* forge fuel but writes its output to the project's `.claude/agents/` (a Claude Code location, not a `.forge/` path — never resolved). The fuel it reads: `.forge/codebase/` is a global exemption (always the top-level path on every branch — see `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` / ADR-0011), while `.forge/CONTEXT.md` resolves to the branch root. Both reads are optional (see below).

## The session-restart fact (read this first — ADR-0024)

A project's `.claude/agents/` is read **once, at session start**. A card written to a file mid-session is **not** dynamically picked up — fg-run cannot dispatch it until the session restarts. So the operating flow is deliberately three-step:

```
fg-agents creates the cards  →  RESTART the session  →  fg-run dispatches a role as agentType
```

This is not a limitation to apologize for in the handoff — it is the contract. State it plainly: the cards exist on disk now, but they take effect only after a restart, and the restart is a one-time project-setup cost (every fg-run afterward uses them). Do not claim a card is "ready to use this session," and do not attempt a same-session end-to-end call — it will not find the card.

## Behavior — grill the domain, propose roles, the human approves

Role generation is **conversational and human-approved**, never an autonomous fan-out. Which roles a project actually needs is a domain judgment; manufacturing a generic squad ("backend-dev", "tester", "reviewer") that doesn't fit the project is exactly the over-engineering this skill must avoid. So fg-agents grills, *proposes* with rationale, and the human picks — the same restraint as fg-cleanup ("don't manufacture retirements") and fg-map ("offer, never auto-run").

This grilling is **conducted in this session as a conversation, outside any Dynamic Workflow** (pillar #1 — a workflow cannot take human input mid-run, and deriving roles is a back-and-forth). Do not wrap the grilling in a workflow.

### 1. Read the fuel (graceful if absent)

Before grilling, read what the project already documents, so you grill against its real shape instead of re-discovering it:

- **`.forge/codebase/` map** (fg-map's output — `ARCHITECTURE.md`, `STRUCTURE.md`, `CONVENTIONS.md`, `STACK.md`, …) — the structural picture of the code.
- **`.forge/CONTEXT.md`** (domain glossary) — the project's own terms.
- **`.forge/adr/` — active ADRs** (the project's documented decisions, e.g. "event-sourced orders", "Postgres for the write model") — read the active `adr/*.md` only; **never `adr/retired/`** (ADRs the fg-cleanup utility retired — deliberately off the active grilling fuel, ADR-0012). On a non-default branch, apply the read overlay (branch root over the top-level `.forge/`, branch wins on conflict — FORGE-ROOT.md / ADR-0011). These ground the roles in what the project has already decided, so the cards aren't generic. **Fold relevant decisions in lightly**: a role whose slice touches an ADR's area should carry that constraint in its system-prompt body in prose (e.g. a migration role respects an event-sourcing ADR) — do **not** mechanically cite ADR numbers in every card (that bloats cards and couples them to numbering).

If none of these exist, **degrade gracefully**: explore the codebase directly with file tools (Read/Grep/Glob) enough to grill sensibly, or — for a thin/greenfield project — grill purely from what the user tells you. Never block on the map or ADRs being present; they are fuel, not a dependency. (If the map looks stale or absent and the project is non-trivial, you may mention `fg-map` as a one-line pointer — but do not require it.)

### 2. Grill: what recurring work would a specialized role serve?

Drive a focused conversation to surface the project's **recurring, separable kinds of work** — the seams where a dedicated agent earns its place. One question at a time, conversational. Useful angles:

- What kinds of task come up again and again here (e.g. writing migrations, reviewing API contracts, building UI components, auditing security)?
- Which of those have a distinct skill set, vocabulary, or set of files — enough that a focused agent would do better than a generalist?
- Where does the current generalist execution actually fall short, if anywhere? (No pain → maybe no role. YAGNI.)

The bar for a role is the same bar forge uses for any abstraction: it must earn its place against a real, recurring need. A project with no clear seams may warrant **zero** new agents — say so honestly rather than inventing roles.

**As each role surfaces, also note its character along two axes** — these become the card's `tools` / `model` / `effort` at write time (§4), *derived from the grilling you are already doing*, not asked as separate questions:

- **Access** — does the role only *read* (review, analysis, audit) or does it *write* (author, modify files)? Read-only roles get a restricted tool set; writers keep full access.
- **Reasoning weight** — is the work deep/high-stakes (careful review, design) or mechanical/repetitive? This informs `effort` (and, rarely, `model`).

Both fall straight out of "what recurring work does this role own?" — capture them as you go; don't turn them into extra interrogation.

### 3. Propose the role set, the human picks

Present the candidate roles, one line each, with rationale, the slice-of-work each would own, **and the two derived properties from §2** (access → `tools`; reasoning weight → `effort`, rarely `model`) so the human confirms or overrides all of them at the pick — e.g.:

- *"migration-author — owns DB schema changes and backfills; **read-write** (tools inherited), model/effort default; recurs every release, distinct safety rules (your call — adjust any)."*
- *"contract-reviewer — reviews API contracts for breaking changes; **read-only** (`Read, Grep, Glob, Bash`), effort high; recurs on every API change (your call)."*

The human approves any subset (possibly none) and may override any property. Only approved roles become cards.

### 4. Write each approved role to `.claude/agents/<role>.md`

For each approved role, write a standard Claude Code subagent definition. The format is YAML frontmatter + a system-prompt body:

```md
---
name: <role-kebab-case>
description: <what this role does AND when to use it — the "when to use" is load-bearing>
tools: Read, Grep, Glob, Bash        # read-only roles ONLY; OMIT for write roles (full inherit)
effort: high|low                     # only when reasoning weight is clearly high or low; omit otherwise
model: <tier>                        # rare — explicit user opt-in only; see the eco caveat below
---

<system prompt: who this agent is, what it owns, how it should work in this project,
 conventions to follow, and what to return.>
```

- **`name`** — kebab-case ASCII identifier; this is what fg-run passes as `agentType: '<role>'`. Must be unique under `.claude/agents/`.
- **`description` — include "when to use".** This is not decoration: fg-run's workflow builder auto-maps a plan's work slice to a role by reading these `description`s (ADR-0024 chose auto-mapping over a plan-side marker). A description that only says *what* the role is, without *when it applies*, can't be matched to a slice. Write both — e.g. *"Reviews database migrations for safety. Use when a slice touches schema changes, backfills, or data transformations."*
- **System-prompt body** — ground it in *this* project: its conventions (pull from `.forge/codebase/CONVENTIONS.md` / `CONTEXT.md` when present), the files the role owns, and what the agent should return. Keep it focused on the role's slice; don't restate forge's loop.
- **`tools` — least privilege (the ACI axis; ADR-0024 2026-07-20 amendment).** From the role's **access** character (§2): a **read-only role** (review, analysis, audit) gets the fixed safe set `tools: Read, Grep, Glob, Bash` — the same set ECC's reviewer uses, and every entry always resolves, so the card can't hit the **launch-fail trap** (a `tools` entry that resolves to no tool makes the subagent fail to launch). A **write role** (author/modify) **omits `tools`** entirely, inheriting all tools exactly as before. The goal is **preventing role drift, not a security boundary** (a read-only role can still write via `Bash` — accepted). **Never pin MCP tool names** in a card — they are environment-dependent, and a missing one launch-fails the whole card.
- **`model` is restrained, `effort` is free — an asymmetry (ADR-0024 amendment).** Pinning `model:` **defeats eco for that role**: eco only ever lowers and a card's own `model:` wins (the eco interaction above), so a generated `model:` silently overrides eco's `sonnet` cap on every dispatch. So set `model:` **only** on explicit user opt-in, for a role whose character clearly demands a fixed tier; **default is to omit** (inherit — eco cap preserved). `effort:`, by contrast, is **independent of eco's model cap** (it doesn't change the model), so set it freely from the role's **reasoning weight** (deep/high-stakes review → `high`, mechanical repetition → `low`); omit it when neither is clear.
- **Out of scope for card generation** — `skills` preload, `memory`, `maxTurns` are **not** set by fg-agents: no concrete recurring pain justifies them yet (the same "specific, reproduced pain" bar as ADR-0013). Add them by hand if a real need appears.

Don't overwrite an existing card silently — if `.claude/agents/<role>.md` already exists, surface it and confirm before replacing (re-running fg-agents after this amendment is how an older, over-permissioned card gets tightened to the least-privilege `tools` set).

```
forge agents
   │
   ▼
Read fuel: .forge/codebase/ map + .forge/CONTEXT.md + active .forge/adr/ (retired/ excluded)  ── absent ──▶ codebase: explore directly / grill from user · CONTEXT·ADR: skip gracefully (never blocks)
   │ present or explored
   ▼
Grill the domain (conversation, OUTSIDE any workflow) — what recurring, separable work earns a role?
   │
   ▼
Propose candidate roles with rationale (or honestly: "no clear seams — zero roles")
   │
   ▼
Human approves a subset (possibly none)
   │ none ──▶ report "no cards created" → end
   │ some
   ▼
Write each → .claude/agents/<role>.md  (frontmatter name + description-with-when-to-use + system prompt; confirm before overwrite)
   │
   ▼
Handoff: cards exist on disk → RESTART the session → then fg-run dispatches them as agentType (ADR-0024)
```

## Handoff

State, in the user's language and statement form (no "shall I…?"; chaining is fg-next's job — ADR-0015):

- **What was created** — which `.claude/agents/<role>.md` cards were written, one line each.
- **The restart, plainly** — the cards take effect only after a **session restart** (Claude Code loads `.claude/agents/` at session start). Until then fg-run cannot dispatch them. This is the contract, not a bug.
- **What happens after restart** — once restarted, fg-run discovers the cards and, when a plan's slice matches a role's "when to use," dispatches that slice through the role as `agentType` (graceful: slices with no matching role use the default subagent, exactly as before).
- **If these are project assets worth keeping** — they live in the project's `.claude/agents/` and are committed like any project file (not forge `.forge/` state). A one-line reminder to commit them is appropriate; never run git yourself.

Then stop.

## Document impact

- Creates/updates `.claude/agents/<role>.md` cards in the **user project** (not under `.forge/`, not forge plugin files). Lazy-creates `.claude/agents/` if absent.
- Touches **no** forge loop state (`plan/run/STATUS/backlog/executed/done`) and **no** persistent forge docs — it only *reads* `.forge/codebase/` and `.forge/CONTEXT.md` as optional fuel. This is a project-asset utility outside the loop.
- The call path that uses these cards lives in fg-run (ADR-0024); fg-agents does not modify fg-run.
