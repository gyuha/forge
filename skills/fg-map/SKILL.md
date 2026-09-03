---
name: fg-map
description: Maps the codebase with parallel subagents into structured documents under .forge/codebase/, so later grilling reads a map instead of re-exploring the code (cuts context rot). On-demand utility outside the loop. Use in contexts like "map the codebase", "analyze the codebase", "코드베이스 분석", "코드베이스 지도".
---

# fg-map — codebase mapping (loop-side utility)

This skill is **not a stage of the forge loop** (fg-ask → fg-run → fg-learn → fg-done). It is an **on-demand utility** that produces one kind of the loop's permanent-doc fuel: a structured map of the codebase under `.forge/codebase/`. fg-ask reads that map before grilling, so it no longer has to re-explore the whole codebase each session — that re-exploration is where context rot comes from. Run fg-map when the codebase has changed enough that the map is stale; it is not something every task triggers.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** All documents this skill generates for the user's project are written in the user's language. The document names and section headings below are canonical English names — keep the file names as-is (`STACK.md` etc.), but render the prose inside in the user's language.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Host contract**: mapping fans out to subagents, so it needs the host's `spawn_parallel` capability. Read [../../core/HOST.md](../../core/HOST.md) and [../../core/EXECUTION.md](../../core/EXECUTION.md), then check `hosts/<host>/capabilities.json`. When `spawn_parallel` is `false` or the host is unknown, **produce the same seven documents serially** — the map's contents, filenames, and `.forge/codebase/` location do not change with the host; only the delegation does.

**Forge root**: `.forge/codebase/` is a deliberate **global exemption** from branch-root resolution (see `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-run/FORGE-ROOT.md` / ADR-0011): fg-map always writes, and fg-ask always reads, the top-level `.forge/codebase/` on every branch — never `.forge/branch/<branch>/codebase/`. Reason — the map is shared reference fuel; a branch-local map would leave freshly created branches with no map and break fg-ask's read. So every `.forge/codebase/...` path below is the literal top-level path, not resolved.

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

1. **Update** — incremental refresh against the diff since the last mapping (all 7 documents, edited in place). This is the common path once a map exists: its cost is proportional to what changed, not to the size of the codebase. Procedure below.
2. **Refresh** — write from scratch: the whole codebase, or only the documents the user names (e.g. just `ARCHITECTURE.md` + `STRUCTURE.md` — then launch only the focuses that own those documents).
3. **Skip** — use the existing map as-is, do nothing.

If `.forge/codebase/` does not exist, create it lazily and proceed to the full 4-agent run.

### Update — the incremental procedure (mandatory steps)

The freshness stamp is not only a staleness signal; it is the **diff baseline** that makes a re-map cost what changed rather than what exists. Every numbered step here is **mandatory**, the same standing as the secret scan under "After the agents return" — do not skip one because the diff looks small.

1. **Eligibility precheck — before anything else.** Both must hold:
   - all 7 documents carry a `last_mapped_commit` stamp and they all name the same sha (`grep -h '^last_mapped_commit:' .forge/codebase/*.md | sort -u` returns exactly one). **Anchor the pattern to the line start** — the documents describe this very stamp mechanism in their prose, and an unanchored grep matches those sentences too, so it would report several "stamps" forever and never take the incremental path;
   - that sha is an ancestor of HEAD (`git merge-base --is-ancestor <stamp> HEAD`). A rebase, force-push, or shallow clone breaks this, and then the diff is a lie about what actually changed.

   If either fails, **do not ask** — fall back to a full Refresh and give the reason in one line ("the stamp is not an ancestor of HEAD (rebase detected) — remapping in full"). The fallback is the only possible answer, so asking the question is noise.
2. **Collect the changed files** — the union of committed and uncommitted change: `git diff --name-status <stamp>..HEAD` **∪** `git status --porcelain`. The union is not optional: the diff sees only commits while a full map reads the working tree, so without the second half an incremental update silently misses everything not yet committed — content a Refresh would have caught. **Drop `.forge/codebase/` itself from the resulting list** — the map is not part of the codebase it maps, and its own edits from the previous run would otherwise come back as changes to map.
3. **Capture the baseline sizes** — `wc -l .forge/codebase/*.md` before launching. The post-check compares against these.
4. **Launch the same 4 focus agents, under an in-place contract.** Each prompt carries the current HEAD sha, the changed-file list from step 2, and these instructions:
   - treat its existing documents as the baseline and **edit them in place — do not re-explore the codebase, do not rewrite from scratch**;
   - read only the changed files that bear on its focus, revise the sections they affect, and drop references to deleted files;
   - if nothing in the diff touches its focus, change no content and only update the stamp;
   - **escape hatch** — if the baseline has drifted so far from the code that patching it would be dishonest, rewrite that document in full and say so in the confirmation.

   Everything else about the agents is unchanged: direct write, confirmation only, the CONTEXT.md boundary, the stamp.

Flow: precheck (all stamped + ancestor) → changed files (diff ∪ porcelain) → baseline `wc -l` → 4 agents, in place → post-check
   └── precheck fails → full Refresh, one-line reason

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

Get the sha once before launching (`git rev-parse HEAD`) and pass it into every agent prompt. This stamp is also the baseline an incremental Update diffs against (see the Update procedure above). It is what lets fg-ask judge whether the map is stale — without it, a consumer cannot tell a fresh map from one that is hundreds of commits behind. This guards against "stale-docs rot," the other face of context rot.

## After the agents return

1. **Verify output.** Confirm the expected documents exist and none is empty (`ls`, `wc -l .forge/codebase/*.md`). Note any focus that failed; continue with what succeeded.
2. **Post-check an incremental Update — mandatory (Update path only).** Two checks:
   - all 7 documents now stamp the HEAD sha the run started from — an agent whose focus the diff never touched still bumps its stamp, so a stale one means that agent did not finish;
   - compare `wc -l` against the baseline captured before launching (step 3 of the Update procedure). Report the before→after counts, and if any document lost **more than ~30% of its lines, stop and surface it** — an in-place edit that shrinks a document that far is the signature of content silently dropped, and only the user can say whether the deletion was legitimate.
3. **Scan for secrets — mandatory.** `.forge/codebase/` is a **git-tracked permanent doc** (unlike volatile `.forge/`), so it will be committed. A mapper quoting a `.env` or config file can accidentally copy a key. Grep the generated docs for common secret patterns (e.g. `sk-`, `sk_live_`, `ghp_`, `AKIA`, JWT-shaped `eyJ...`, `-----BEGIN ... PRIVATE KEY`). If anything matches, **stop and surface it to the user for confirmation before going further** — do not commit past a suspected leak.
4. **Offer to commit (do not auto-commit).** forge has no stage that commits without user confirmation, and the working tree may hold unrelated changes. After the secret scan passes, ask: "Map written and scanned clean — commit it as `docs: map codebase`?" Commit only on agreement. If the working tree has unrelated changes, point that out and let the user decide what to stage.

Flow: check existing map (menu if present) → stamp HEAD sha → launch 4 agents (direct write, confirmation only) → verify output → post-check (Update only) → scan for secrets → offer commit

## Handoff

When the map is written — the fresh, Update, and Refresh paths — close with the **handoff table** per [`../fg-next/HANDOFF.md`](../fg-next/HANDOFF.md) — the single definition of its shape; never restate that layout here. Statement form, in the user's language. **The Skip path has no handoff and renders no table**: nothing was produced and nothing changed, so say in one line that the existing map was kept as-is, and stop.

- `Just did` = what was produced: the documents written under `.forge/codebase/`, stamped at the current commit (all 7 on a fresh run or an Update; on a document-scoped Refresh, only the ones named). On the Update path, say so and give the before→after line counts.
- **`Next step` / `How to start` are conditional — fg-map is a side utility with no fixed next stage, so they come from a precedence rule, never a fixed cell** (HANDOFF.md, "A conditional next step needs a precedence rule, never a hard-coded row"). Take the **first matching case**:
  1. **The user is mid-loop** (the active slot, `.forge/executed/`, or the backlog holds work) → `Next step` = **where they were**, taken from fg-status's next-step state machine, which is the single derivation and not a re-guess here (HANDOFF.md's Material rule) — with a populated active slot that is `fg-learn` / `fg-done`, **never fg-ask**, which would drop them into its STEP-0 unsealed-residue path instead. `How to start` = that step's own trigger, or `fg-next` to have it derived and run. `Alternative` = `fg-ask`, if they would rather start something new on the fresh map.
  2. **Not mid-loop** (no active slot, nothing awaiting retro, empty backlog) → `Next step` = **`fg-ask`** — it now reads this map before grilling instead of re-exploring the code, so the next task's planning rides on the map; `How to start` = `/forge:fg-ask`; omit `Alternative`.

## Constraints

- **Not a loop stage.** fg-map writes no `.forge/` state, promotes no plan, and seals nothing. It only produces `.forge/codebase/`. It does not participate in the active-slot / backlog / done contract.
- **Direct write, confirmation only.** The whole reason fg-map exists is to keep codebase exploration out of the orchestrating session's context. If you ever find yourself reading source files in this session to build the map, you have defeated the purpose — fan it out.
- **No user-specified path scope, no sequential fallback.** Incremental scope comes from the `last_mapped_commit` stamp, never from a user-supplied path list — there is no `--paths` flag: Update derives its own scope from the diff, and Refresh scopes by document, not by path. forge is Claude Code only, so the `Agent` tool is always available — there is no non-Agent fallback path to maintain.

## Document impact

- Creates/refreshes `.forge/codebase/*.md` (7 documents), or edits them in place on the incremental Update path, each stamped with `last_mapped_commit`. Lazy creation of the directory.
- Does not touch `.forge/`, `CONTEXT.md`, or any ADR.
- (Optional) a commit `docs: map codebase`, only on user agreement after a clean secret scan.
