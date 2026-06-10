---
name: fg-tdd
description: Toggle forge's TDD mode on or off — a persistent project setting stored in .forge/config.json. `fg-tdd on` / `fg-tdd off` set it; with no argument it shows the current state. fg-ask asks "build this task TDD-style?" per task with this setting as the default answer, and fg-run runs test-first when the plan's tdd marker is on. An on-demand utility outside the loop. Use in contexts like 'forge tdd', 'tdd on', 'tdd off', 'TDD 켜', 'TDD 꺼', 'tdd 상태'.
---

# fg-tdd — toggle TDD mode (outside the loop)

This is **not** a stage of the forge loop. It is a tiny on-demand utility that flips one persistent project setting: whether forge defaults to **test-driven development**. It reads and writes **only** `.forge/config.json` — it never touches the active slot, backlog, executed, or done state.

**`.forge/config.json` is a deliberate global exemption from branch-root resolution** (see `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` / ADR-0011): it is always the top-level `.forge/config.json` on every branch, never `.forge/branch/<branch>/config.json`. Reason — it holds `defaultBranch`, which the root-resolution rule itself must read before it can resolve anything, and `tdd` is a project-wide setting. So fg-tdd writes the global path as-is; do not "fix" it to resolve the branch root.

**Language**: This skill file is authored in English, but always converse with the user in the user's language.

## What it does

- **`fg-tdd on`** → set `tdd: true` in `.forge/config.json`.
- **`fg-tdd off`** → set `tdd: false`.
- **`fg-tdd` (no argument)** → report the current state in one line (e.g. "TDD mode: on" / "off"). Do not change anything.

## The config file — `.forge/config.json`

A git-tracked JSON settings file (lazily created on first write; `.gitignore` whitelists `!.forge/config.json`). It holds forge's persistent project settings — `tdd` (the key this skill manages) and, optionally, `defaultBranch` (read by branch-root resolution; see FORGE-ROOT.md / ADR-0011). Example of the lazily-created default:

```json
{
  "tdd": false
}
```

- Default is `false` (off) — if the file doesn't exist, treat `tdd` as `false`.
- When writing, **preserve any other keys** already in the file (read → set `tdd` → write back); only change `tdd`. Keep the JSON valid.
- This is a **team-shared project default** (tracked in git): "this project develops TDD-style." An individual task can still override it — fg-ask asks per task and records the choice on the plan (`<!-- tdd: on|off -->`), defaulting to this setting.

## How the setting is used (for reference — not this skill's job)

- **fg-ask** reads `tdd` as the default when it asks, at the start of grilling, whether to build the task TDD-style, and records `<!-- tdd: on|off -->` on the plan.
- **fg-run** runs the plan test-first when its `tdd` marker is on (each slice: write a failing test → implement → make it pass).

fg-tdd only flips the default; it does not start any work.

## Handoff

After toggling, state the new value in one line and, if relevant, note that it takes effect on the **next** fg-ask (the default it offers) — tasks already planned keep the `tdd:` marker they were created with. There is no loop next-step; fg-tdd is a side utility.

## Document impact

- Creates/updates `.forge/config.json` (the `tdd` key only; git-tracked). Touches nothing else.
