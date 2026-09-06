---
name: fg-help
description: A read-only usage-help reporter for forge — `/forge:fg-help` prints an overview of every fg-* skill grouped by the loop's four stages plus the outside-the-loop utilities, and `/forge:fg-help <command>` a short detail (what it does · when to use · trigger · next step) for one skill. Each skill's own SKILL.md `description` is the single source, rendered in the user's language. Writes nothing, never auto-runs. Outside the loop. Use in contexts like 'forge help', 'fg-help', '도움말', '사용법', 'how do I use forge', 'what commands are there', 'fg-help fg-run'.
---

# fg-help — forge usage help (read-only, outside the loop)

This is **not** a stage of the forge loop. It is an on-demand, **read-only** utility (like fg-status / fg-doctor) that answers yet another distinct question: fg-status reports *"where am I"* (progress + next step), fg-doctor reports *"is the state healthy"* (integrity), and fg-help reports *"how do I use these skills"* (usage docs). Read-only-ness is not why these are separate skills — the *question each answers* is (the same reasoning that keeps fg-status and fg-doctor apart). fg-help is that third question.

It **writes nothing** — no `.forge/` state, no files, no plan/backlog/done. It **never auto-runs**; you invoke it on demand. It does not participate in the active-slot / backlog / done contract.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — the overview, the per-command detail, and the closing line — in the user's language (detect it from the user's own messages), never mirroring this file's English.** This is the whole reason fg-help is LLM-executed and not a deterministic script (see "Why no script twin" below): each forge skill's `description` is authored in English, and fg-help renders it into the user's language at output time, exactly as every forge skill outputs in the user's language.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Forge root**: fg-help reads no `.forge/` state, so forge-root resolution does not apply here. It reads only the plugin's own skill files (below).

## The single source — each skill's own `description`

fg-help **never stores a copy** of any usage text. forge's top discipline is single-definition / no-copy-paste (`FORGE-ROOT.md`, `HANDOFF.md`, `DRIVE.md` are the precedents), and skill usage already has a single definition: the frontmatter `description` of each `skills/<name>/SKILL.md`, which by convention carries a human-readable summary **and** bilingual trigger phrases at the end (e.g. fg-status's `... Use in contexts like 'forge status', '상태', ...`). fg-help reads those at runtime; it adds no fifth synchronization surface, and a newly added skill shows up automatically with no edit to fg-help.

**Scope — forge `fg-*` skills only.** Glob the skill files and read each one's frontmatter (`name` + `description`). **Call Glob with the pattern `**/SKILL.md` and its `path` argument set to this skill's own parent directory** — the plugin's `skills/` directory, i.e. the parent of the base directory the host states for this skill at the top of this prompt. Two patterns look right and silently return **zero** files: a `${...}` one (Glob performs no shell parameter expansion, so it is matched literally) and a `../`-prefixed one (Glob resolves a non-absolute pattern against the **user's working directory**, never this skill's directory, and its globs never match upward). Anchoring `path` avoids both, and keeps the match inside the plugin. This file location is the deterministic boundary of "what is a forge skill" (the same auto-discovery convention the plugin uses). Do **not** include other plugins' skills loaded in the session (superpowers, codex, local `.claude/skills/` tools, etc.) — forge does not own or maintain their descriptions, so their help quality can't be guaranteed here; fg-help documents its own house only.

## Two modes

Mode is chosen by whether an argument was given.

```
/forge:fg-help              → overview  (all forge skills, grouped)
/forge:fg-help <command>    → detail    (one skill, 4-line usage)
/forge:fg-help <unknown>    → nearest-name suggestion, then fall back to the overview
```

### Overview (no argument)

Glob the skill files, read each `name` + `description`, and print a grouped overview **in the user's language**:

- **Group by the loop's four stages, then the outside-the-loop utilities** — the same organization CLAUDE.md and the README already use, so the user sees the structure they'll meet elsewhere. Lead with the loop `① fg-ask → ② fg-run → ③ fg-learn → ④ fg-done`, then an "outside the loop utilities" group for the rest (fg-status, fg-next, fg-loop, fg-map, fg-quick, fg-doctor, fg-agenda, fg-help itself, etc.).
- **Derive the grouping from each `description`, not a hard-coded list.** A skill's own description states whether it is a loop stage or an `outside the loop` utility (fg-status's says *"On-demand utility outside the loop."*). Read that phrase to place each skill, so the grouping needs no maintained classification table and a new skill lands in the right group automatically. If a description is ambiguous about placement, put it under the utilities group (the safe default) rather than guessing a loop position.
- For each skill show one line: its `name`, its trigger (`/forge:<name>`), and a one-phrase summary distilled from its description — not the whole description (that is what the detail mode is for).
- **fg-help includes itself** — the glob picks up its own SKILL.md, so it appears under the utilities group like any other. Do not special-case it out.
- Close with a single line pointing to the detail mode: *"각 명령의 상세는 `/forge:fg-help <명령>`"* (render in the user's language).

### Detail (`fg-help <command>`)

Resolve the argument **leniently**, then print a short usage detail for the matched skill in the user's language:

- **Lenient matching** — match the argument against, in order: the exact `name` (`fg-run`), the `fg-`-dropped short form (`run`), and the bilingual trigger phrases at the end of each `description` (`실행`, `계획 실행`). These triggers are already the single definition in each SKILL.md, so matching against them needs no new alias table. `/forge:fg-help 실행` should find fg-run.
- **The 4-line detail** — distill from the skill's `description` (and, only as needed, a light skim of its SKILL.md body) exactly four things: **what it does · when to use · trigger · next step (if any)**. **Do not dump the SKILL.md body** — it is an agent-facing instruction sheet running to hundreds of lines (fg-run's alone), which would bury the user rather than help. Keep it to those four points.
- **Unknown argument** — if nothing matches, do not error out: suggest the nearest skill name(s) by similarity ("`fg-rnu`? did you mean `fg-run`?") and then print the overview so the user still gets somewhere.

## Why no script twin (ADR)

forge's other read-only reporters — fg-status (ADR-0020), fg-doctor (ADR-0019), and the fg-done seal — are backed by deterministic `.sh`/`.js` script twins (ADR-0022) for speed and AI-free CI use. **fg-help deliberately has none**, because its core job is to render English source descriptions into the *user's language*, and a script cannot translate. So fg-help is LLM-executed: it globs the sources, then the model renders the grouped/localized output. The trade-off (script speed + byte-identical testability, lost; user-language rendering + zero copied text, gained) is recorded in `.forge/adr/` — see the fg-help ADR. A consequence: fg-help's output is not byte-identical across runs, so its correctness is checked by **structure** (every skill appears in the overview; `fg-help <command>` locates the named skill and shows its trigger + next step), not exact text.

## Cross-reference from fg-status

fg-status points a lost user here: when it reports the next step, it also notes in one line that *"사용법이 필요하면 `/forge:fg-help`"* (rendered in the user's language). fg-help does not point back into the loop — it is a documentation utility, not a loop stage.

## Handoff

fg-help renders **no handoff table** — it has no fixed next stage (a documentation utility, like fg-cleanup / fg-drop, which also keep plain prose). The overview already ends with the one-line pointer to the detail mode; the detail mode ends after its four lines. Nothing more is stated, and nothing is auto-invoked.

## Document impact

- **None.** fg-help creates and modifies nothing — it only reads `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/*/SKILL.md` and prints. Pure read-only reporting.
