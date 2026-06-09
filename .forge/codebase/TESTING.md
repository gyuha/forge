---
last_mapped_commit: 41c10d7cb477eddab9b7d0f1aa8bd23bbcf34d98
mapped_date: 2026-06-09
---

# Testing

**There is no unit-test framework.** No `package.json`, Makefile, or CI. The artifacts are Markdown (`SKILL.md`, `*-FORMAT.md`) and JSON (manifests), so "testing" means structural validation plus behavioral dogfooding by installing and triggering the skills.

## Validation Commands

- **Manifest JSON validity** (run after editing either manifest — broken JSON means install failure):
  ```bash
  node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
  ```
- **Skill auto-discovery check** — every `skills/*/SKILL.md` must have a frontmatter `name:` or it won't be discovered:
  ```bash
  awk '/^name:/' skills/*/SKILL.md
  ```
- **Remote release verification** (after deploy; `/plugin` commands themselves are interactive and not agent-runnable) — confirm the three version fields landed on remote `main`:
  ```bash
  curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json
  ```

## Behavioral / Install Testing

- The only real runtime test is **installing the plugin and triggering a skill**: `/plugin marketplace add gyuha/forge` (or a local path), then `/plugin install forge@forge`. Install pulls the GitHub default branch (`main`), so a change must be pushed to `main` before it can be install-tested.
- `/plugin install` and `/plugin marketplace update` are **interactive** — an agent cannot run them; the user runs them directly. An agent can only verify the install *preconditions* (remote version fields + frontmatter `name:` presence, above).

## Verification Gate for Instruction-Skills (ADR-0009)

- The loop order is run → verify → learn → done. `fg-run`'s handoff performs UAT against the plan's goal and records STATUS `verified:` — sealable values are `yes` / `skipped (reason)` / `n/a (reason)`; blocking values are `pending` (not yet verified) / `failed (reason)` (verified but broken). `fg-done` checks the verification gate **before** the retro gate and won't seal on a non-sealable value.
- Because these skills are **instruction documents with no executable runtime**, there is often nothing to "run" — UAT frequently lands `verified: n/a`. Pre-ADR-0009 sealed tasks were backfilled with `verified: n/a (legacy pre-ADR-0009)`.
- A genuine end-to-end behavioral test was done by **sandbox dogfood** for the fg-merge lifecycle — see `.forge/done/2026-06-09-fg-merge-lifecycle-e2e/` (driving the branch-isolated state through an actual merge-and-integrate cycle rather than asserting in prose).

## Retro Gate (ADR-0002)

- Retro is the default. `fg-run`'s handoff offers "retro / skip" only when plan↔actual divergence (in `.forge/run.md`) is none or minimal; choosing skip records `retro: skipped (reason)` in STATUS.md with no retro file. `fg-done`'s seal guard accepts either a retro file **or** `retro: skipped`. High divergence is never offered a skip. (`fg-next all` is the exception: it always auto-skips retros regardless of divergence — ADR-0010.)
