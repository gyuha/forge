---
last_mapped_commit: 41c10d7cb477eddab9b7d0f1aa8bd23bbcf34d98
mapped_date: 2026-06-09
---

# Authoring Conventions

This repo has no application code — "conventions" here are about **authoring skills and docs** (Markdown + JSON), not code style. The deliverables are `SKILL.md`, `*-FORMAT.md`, the two manifests, and the bilingual READMEs.

## Language Policy

- **Skill bodies (`SKILL.md`) and format docs (`*-FORMAT.md`) are written in English.** This covers `skills/*/SKILL.md`, `skills/fg-ask/CONTEXT-FORMAT.md`, `skills/fg-ask/ADR-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-run/FORGE-ROOT.md`, and `skills/fg-learn/RETRO-FORMAT.md`. Parts copied verbatim from grill-with-docs stay English verbatim.
- **A skill's user-facing output follows the user's language.** Each `SKILL.md` must carry an explicit "respond in the user's language" instruction. This applies to everything a skill emits at runtime: questions, status reports, handoff messages, and all generated artifacts (`.forge/plan.md`, `.forge/run.md`, `.forge/retro/*`, `.forge/CONTEXT.md`, `.forge/adr/*`).
- **Generated artifacts render canonical section titles in the user's language.** Format docs define English titles (e.g. "Source of truth", "Work slices", "Plan vs actual"); when a skill writes the artifact it translates the title into the user's language. Consumer skills (`fg-run`, `fg-learn`, etc.) recognize sections by meaning and position, not by literal string.

## Flow Diagrams: Text, Not Mermaid

- Inside `SKILL.md`, flows / state transitions / branches are written as **text flow diagrams** (`A → B → C`; branches via indentation, arrows, and condition labels), **never Mermaid**. Skill bodies are agent instructions parsed without rendering, so Mermaid blocks would hurt diff/grep/diagnosis. Text flow diagrams here are English (skill bodies are English).
- This rule is scoped to skill docs only — it does not constrain artifacts generated into the user's project.

## Handoff & Conversation Style

- Each skill ends with a **natural conversational handoff** ("what I just did / next step / how to start"), not a rigid template dump.
- Handoff messages are written in the user's language even though the skill body is English.

## Documentation Boundary

- `.forge/CONTEXT.md` (or root `CONTEXT-MAP.md` for multi-context) is a **domain glossary** — terms only, no implementation detail. `fg-ask` updates it inline during grilling.
- `.forge/codebase/*.md` (the seven fg-map maps, this file among them) describe structure/conventions/etc., not domain terms — keep domain definitions out of these.

## Promotion Restraint

- ADRs and glossary terms are promoted **only past the bar**. An ADR requires all three: hard to reverse / puzzling without context / a genuine tradeoff. Not every learning from a retro becomes a persistent doc; the rest land in `.forge/retro/`.
- ADR files are `.forge/adr/NNNN-slug.md` with monotonic numbers (currently 0001–0013). Numbers are never reused. `fg-cleanup` retires (not deletes) stale/superseded ADRs to `.forge/adr/retired/<NNNN>-slug.md` with a supersede/retire marking; numbers stay fixed. (The `retired/` dir is created lazily — none exists yet.)

## Manifests: Two Descriptions, Two Roles

The two manifests (`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`) both carry human-read descriptions, and they are not interchangeable:

- `marketplace.json` `metadata.description` is the **one-line loop tagline** (ask·plan → execute → retro → done). Outside-the-loop utilities (fg-map et al.) are deliberately kept out of it so the loop definition stays sharp.
- `plugins[].description` (and `plugin.json` `description`) is the **full skill listing** — outside-the-loop skills belong here. Version lives in three places that must stay in sync: `plugin.json` `version`, `marketplace.json` `metadata.version`, and `plugins[0].version` (all `0.4.1` at this commit).
- Skills are auto-discovered from `skills/<dir>/SKILL.md`; the **skill identifier is the frontmatter `name`, not the directory name** (they happen to match today — eleven skills: fg-ask, fg-cleanup, fg-done, fg-learn, fg-map, fg-merge, fg-next, fg-quick, fg-run, fg-status, fg-tdd). `plugin.json` omits a `skills` field since discovery is automatic.

## README Bilingual Sync

- `README.md` (English) and `README.ko.md` (Korean) are a **translation pair**. Editing one requires the same change to the other in the same commit; editing only one desyncs them.

## Single-Source Format Docs

- Each format definition exists once, in its owning skill's directory, and other skills reference it via `${CLAUDE_PLUGIN_ROOT}/skills/<owner>/<file>` (relative `../fg-ask/` etc.) rather than copying. `skills/fg-run/PLAN-FORMAT.md` is owned by the consumer side even though `fg-ask` produces plans, because the `fg-ask` directory is verbatim grill-with-docs territory. The root `references/` directory has been abolished.

## Deploy Procedure ("배포")

When the user types **"배포"**, run in order: write `CHANGELOG.md` (Keep-a-Changelog short form, new version section on top; lazy-created if absent) → bump version in the three places above (default patch; "배포 minor"/"배포 major" override) → validate manifest JSON (the node one-liner in TESTING.md) → `chore(release): vX.Y.Z` commit and push to `main` (install pulls `main`, so push is part of the release).

- Don't fold unrelated working-tree changes into the release commit — stop and confirm first.
- If uncommitted changes *are* the release content (0 commits but feature work staged), commit that as a separate `feat` first, then run the release (release commit carries only CHANGELOG + version bump). This is the repo's normal flow.
