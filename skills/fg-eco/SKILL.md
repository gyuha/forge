---
name: fg-eco
description: Toggle forge's eco mode on or off — a persistent project setting in .forge/config.json that caps the model tier of fg-run's delegated subagents (Dynamic Workflow execution agents) at sonnet, so the top-tier session model isn't spent on delegated grunt work. `fg-eco on` / `fg-eco off` toggle it directly; with no argument it shows the current state and offers an on/off choice. It does NOT (and cannot) switch the main session's model — design (fg-ask) and done (fg-done) run in the main session on whatever model the user picked (ADR-0014). An on-demand utility outside the loop. Use in contexts like 'forge eco', 'eco on', 'eco off', '에코 모드', '경제 모드'.
---

# fg-eco — toggle eco mode (outside the loop)

This is **not** a stage of the forge loop. It is a tiny on-demand utility that flips one persistent project setting: whether forge runs **delegated subagent work on a cheaper model tier**. It reads and writes **only** `.forge/config.json` — it never touches the active slot, backlog, executed, or done state.

**What eco mode is (and is not).** A skill cannot switch the current session's model — `/model` is a user-only interactive command, so the main-session stages (fg-ask grilling, fg-done sealing) always run on whatever model the user picked. What *can* be controlled is the model of **delegated subagents**: when eco is on, fg-run **caps its Dynamic Workflow / execution subagents at `sonnet`**. The resulting structure is two tiers: **strong = the main session (design — the user's model choice), normal = delegated execution.** See `.forge/adr/0014-fg-eco-subagent-model-tiering.md` for why this is the implementable half of "per-stage model switching" and what was deliberately left out (fg-map mappers, a haiku tier, advisory prompts).

**Cap, not a set.** Eco only ever lowers: if the session model is already `sonnet` or lighter, delegated agents inherit it unchanged (a savings mode must never raise cost). And an **explicit user model instruction always wins** over eco — eco is a default, not an override of the human.

**`.forge/config.json` is a deliberate global exemption from branch-root resolution** (see `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` / ADR-0011): always read/write the top-level `.forge/config.json` on every branch, never `.forge/branch/<branch>/config.json`.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.**

## What it does

- **`fg-eco on`** → set `eco: true` in `.forge/config.json`.
- **`fg-eco off`** → set `eco: false`.
- **`fg-eco` (no argument)** → report the current state in one line (e.g. "eco mode: off — delegated agents inherit the session model"), then offer the choice via `AskUserQuestion`: turn it on / turn it off / leave as is. Apply only what the user picks.

## The config file — `.forge/config.json`

A git-tracked JSON settings file (lazily created on first write; `.gitignore` whitelists `!.forge/config.json`). If the file doesn't exist, treat `eco` as `false` and create the file on first toggle:

```json
{
  "eco": false
}
```

- Default is `false` (off) — full session-model inheritance everywhere.
- When writing, **preserve any other keys** already in the file (read → set `eco` → write back; the same rule fg-tdd follows for `tdd`). Keep the JSON valid.
- This is a **team-shared project default** (tracked in git): "this project runs delegated work economically."

## How the setting is used (for reference — not this skill's job)

- **fg-run** reads `eco` from the top-level `.forge/config.json` when building a Dynamic Workflow: if `true`, it caps the workflow/execution subagents' model at `sonnet` (lower only, never raise; explicit user model instructions win). See fg-run §1.
- **fg-map is out of scope** — its mappers write the codebase map that fuels fg-ask grilling, and degrading map quality degrades design quality (ADR-0014).

fg-eco only flips the default; it does not start any work.

## Handoff

After toggling, state the new value in one line and note it takes effect on the **next** fg-run workflow build — nothing already running changes. There is no loop next-step; fg-eco is a side utility.

## Document impact

- Creates/updates `.forge/config.json` (the `eco` key only; git-tracked). Touches nothing else.
