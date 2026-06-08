---
name: fg-map
description: Maps the codebase with parallel subagents into structured documents under .forge/codebase/, so later grilling reads a map instead of re-exploring the code from scratch (cuts context rot). An on-demand utility outside the forge loop, not one of its stages. Use in contexts like "map the codebase", "analyze the codebase", "코드베이스 분석", "코드베이스 지도", "context rot 줄여줘". Run it when the codebase has changed enough that the existing map is stale.
---

# fg-map — codebase mapping (loop-side utility)

This skill is **not a stage of the forge loop** (fg-ask → fg-run → fg-learn → fg-done). It is an **on-demand utility** that produces one kind of the loop's permanent-doc fuel: a structured map of the codebase under `.forge/codebase/`. fg-ask reads that map before grilling, so it no longer has to re-explore the whole codebase each session — that re-exploration is where context rot comes from. Run fg-map when the codebase has changed enough that the map is stale; it is not something every task triggers.

**Language**: This skill file is authored in English, but always converse with the user in the user's language. All documents this skill generates for the user's project are written in the user's language. The document names and section headings below are canonical English names — keep the file names as-is (`STACK.md` etc.), but render the prose inside in the user's language.

**Forge root**: `.forge/codebase/` is a deliberate **global exemption** from branch-root resolution (see `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` / ADR-0011): fg-map always writes, and fg-ask always reads, the top-level `.forge/codebase/` on every branch — never `.forge/branch/<branch>/codebase/`. Reason — the map is shared reference fuel; a branch-local map would leave freshly created branches with no map and break fg-ask's read. So every `.forge/codebase/...` path below is the literal top-level path, not resolved.

## What it produces — `.forge/codebase/` (7 documents)

The map is split so that a consumer (fg-ask grilling, or a human) reads **only the document it needs**, not one giant file. That selective read is the whole point — merging everything into one or two files defeats the context-rot reduction. The 7 documents, grouped by the focus that writes them:

| Focus | Documents |
| --- | --- |
| tech | `STACK.md` (languages, runtime, frameworks, dependencies, configuration), `INTEGRATIONS.md` (external APIs, databases, auth providers, webhooks) |
| arch | `ARCHITECTURE.md` (pattern, layers, data flow, abstractions, entry points), `STRUCTURE.md` (directory layout, key locations, naming conventions) |
| quality | `CONVENTIONS.md` (code style, naming, patterns, error handling), `TESTING.md` (framework, structure, mocking, coverage) |
| concerns | `CONCERNS.md` (tech debt, bugs, security, performance, fragile areas) |

Always include actual file paths in backticks (e.g. `src/services/user.ts`) — these documents are reference material, so concrete paths matter more than prose.

### Boundary with CONTEXT.md (do not blur these)

forge already has a permanent doc named `CONTEXT.md`. It is a **domain glossary — terms only, no implementation detail**. `.forge/codebase/` is the exact opposite: **implementation facts only, no domain term definitions**. They are two separate ledgers. A mapper agent must never write domain term definitions into `.forge/codebase/`, and must never treat `CONTEXT.md` as a place for stack/architecture facts. If you find yourself defining what a domain term *means*, that belongs to fg-ask and `CONTEXT.md`, not here.

## How it runs — parallel subagents that write directly

The reason this is a separate utility (not a step inside fg-ask) is context rot: if one session reads the whole codebase to build the map, every byte of that exploration piles up in the session's context. So the work is fanned out to **4 parallel subagents**, one per focus, and **each subagent writes its own documents directly to `.forge/codebase/`**. This session receives only a confirmation (file paths + line counts) back — never the document contents. That is what keeps the orchestrator's context small.

Use the `Agent` tool with `run_in_background: true` to launch all four in one message. Do not read source files or write the documents yourself while the agents are running — that would duplicate their work and re-pollute this context (the exact thing the fan-out avoids).

### Before launching: check for an existing map

If `.forge/codebase/` already exists with documents, do not blindly overwrite. Show the user a short menu (in conversation, the user's language):

1. **Refresh** — delete the existing docs and remap the whole codebase from scratch.
2. **Update** — keep existing docs, remap only the documents the user names (e.g. just `ARCHITECTURE.md` + `STRUCTURE.md`). Launch only the focuses that own those documents.
3. **Skip** — use the existing map as-is, do nothing.

If `.forge/codebase/` does not exist, create it lazily and proceed to the full 4-agent run.

### Agent prompts (one per focus)

Launch the four with `Agent`, `run_in_background: true`. Each prompt instructs the agent to explore thoroughly, write its documents directly, and **return only a confirmation** (paths + line counts). Each agent's prompt must include today's date for any date placeholders and the frontmatter-stamp rule below.

- **Agent 1 — tech**: analyze the technology stack and external integrations. Write `.forge/codebase/STACK.md` and `.forge/codebase/INTEGRATIONS.md`.
- **Agent 2 — arch**: analyze architecture and directory structure. Write `.forge/codebase/ARCHITECTURE.md` and `.forge/codebase/STRUCTURE.md`.
- **Agent 3 — quality**: analyze coding conventions and testing patterns. Write `.forge/codebase/CONVENTIONS.md` and `.forge/codebase/TESTING.md`.
- **Agent 4 — concerns**: analyze tech debt, known issues, and risk areas. Write `.forge/codebase/CONCERNS.md`.

Tell each agent: explore only with file-system tools (Read, Grep, Glob, Bash); include real file paths in backticks; do not blur the CONTEXT.md boundary above (implementation facts only, no domain term definitions); return a confirmation listing the documents written and their line counts — nothing else.

### Freshness stamp — `last_mapped_commit`

Every document a mapper writes must carry YAML frontmatter stamping the commit it was mapped against:

```md
---
last_mapped_commit: <current HEAD sha>
mapped: <YYYY-MM-DD>
---
```

Get the sha once before launching (`git rev-parse HEAD`) and pass it into every agent prompt. This stamp is what lets fg-ask judge whether the map is stale — without it, a consumer cannot tell a fresh map from one that is hundreds of commits behind. This guards against "stale-docs rot," the other face of context rot.

## After the agents return

1. **Verify output.** Confirm the expected documents exist and none is empty (`ls`, `wc -l .forge/codebase/*.md`). Note any focus that failed; continue with what succeeded.
2. **Scan for secrets — mandatory.** `.forge/codebase/` is a **git-tracked permanent doc** (unlike volatile `.forge/`), so it will be committed. A mapper quoting a `.env` or config file can accidentally copy a key. Grep the generated docs for common secret patterns (e.g. `sk-`, `sk_live_`, `ghp_`, `AKIA`, JWT-shaped `eyJ...`, `-----BEGIN ... PRIVATE KEY`). If anything matches, **stop and surface it to the user for confirmation before going further** — do not commit past a suspected leak.
3. **Offer to commit (do not auto-commit).** forge has no stage that commits without user confirmation, and the working tree may hold unrelated changes. After the secret scan passes, ask: "Map written and scanned clean — commit it as `docs: map codebase`?" Commit only on agreement. If the working tree has unrelated changes, point that out and let the user decide what to stage.

Flow: check existing map (menu if present) → stamp HEAD sha → launch 4 agents (direct write, confirmation only) → verify output → scan for secrets → offer commit

## Handoff

When the map is written, convey in a conversational tone (not a stamped-out form): what was produced (the 7 documents under `.forge/codebase/`, stamped at the current commit), and that fg-ask will now read this map before grilling instead of re-exploring the code — so the next time you start a task with fg-ask, planning rides on the map. If the user is mid-loop, point them back to wherever they were; fg-map is a side utility, so there is no fixed "next stage."

## Constraints

- **Not a loop stage.** fg-map writes no `.forge/` state, promotes no plan, and seals nothing. It only produces `.forge/codebase/`. It does not participate in the active-slot / backlog / done contract.
- **Direct write, confirmation only.** The whole reason fg-map exists is to keep codebase exploration out of the orchestrating session's context. If you ever find yourself reading source files in this session to build the map, you have defeated the purpose — fan it out.
- **No `--paths` incremental mode, no sequential fallback.** Partial updates are handled by the Update menu (document-level). forge is Claude Code only, so the `Agent` tool is always available — there is no non-Agent fallback path to maintain.

## Document impact

- Creates/refreshes `.forge/codebase/*.md` (7 documents), each stamped with `last_mapped_commit`. Lazy creation of the directory.
- Does not touch `.forge/`, `CONTEXT.md`, or any ADR.
- (Optional) a commit `docs: map codebase`, only on user agreement after a clean secret scan.
