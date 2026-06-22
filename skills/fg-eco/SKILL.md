---
name: fg-eco
description: Toggle forge's eco mode on or off — activates loop-efficiency behaviors when on: (1) caps fg-run subagent model at sonnet, and (2) activates the embedded Eco laziness-first discipline (the sibling ECO.md) — prepended to fg-run subagents' prompts, woven into fg-ask grilling as a YAGNI lens, and adopted by the current session. `fg-eco on` / `fg-eco off` toggle directly; no arg shows current state. Does NOT switch the main session's model (ADR-0014). The Eco discipline lives only here (no standalone skill); eco is its only activation. An on-demand utility outside the loop. Use in contexts like 'forge eco', 'eco on', 'eco off', '에코 모드', '경제 모드', 'eco', 'lazy mode', '게으른 모드'.
---

# fg-eco — toggle eco mode (outside the loop)

This is **not** a stage of the forge loop. It is a tiny on-demand utility that flips one persistent project setting: whether forge runs **delegated subagent work on a cheaper model tier**. It reads and writes **only** `.forge/config.json` — it never touches the active slot, backlog, executed, or done state.

**What eco mode is (and is not).** A skill cannot switch the current session's model — `/model` is a user-only interactive command, so the main-session stages (fg-ask grilling, fg-done sealing) always run on whatever model the user picked. What *can* be controlled is the behavior of the **forge loop itself** plus the **code-simplicity discipline** applied throughout. The discipline is the **Eco laziness-first spec embedded as the sibling [`ECO.md`](./ECO.md)** — it has no standalone skill and no toggle of its own; turning eco on is its only activation. When eco is on, these behaviors activate:

1. **fg-run model cap** — caps Dynamic Workflow / execution subagents at `sonnet` (only ever lowers, never raises; explicit user model instruction wins).
2. **fg-run Eco injection** — prepends the full [`ECO.md`](./ECO.md) to each subagent's prompt.
3. **fg-ask YAGNI lens** — fg-ask applies the [Eco](./ECO.md) YAGNI lens to every slice discussion during grilling — no separate question, just sharpened grilling.
4. **Current-session adoption** — when you flip eco **on**, read [`ECO.md`](./ECO.md) and adopt its discipline for your own main-session work for the rest of this conversation (this is the only way a skill can "activate" Eco in-session — the config drives the durable cross-session effect via fg-ask/fg-run above; this turn-level adoption gives the immediate effect). Flipping eco **off** drops it again.

Together these tier the loop as "strong = main session (design + grilling), efficient = delegated execution" and keep the whole loop lazy-first. See `.forge/adr/0014-fg-eco-subagent-model-tiering.md` for the full rationale.

**Cap, not a set.** Eco only ever lowers: if the session model is already `sonnet` or lighter, delegated agents inherit it unchanged (a savings mode must never raise cost). And an **explicit user model instruction always wins** over eco — eco is a default, not an override of the human.

**`.forge/config.json` is a deliberate global exemption from branch-root resolution** (see `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` / ADR-0011): always read/write the top-level `.forge/config.json` on every branch, never `.forge/branch/<branch>/config.json`.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.**

## What it does

- **`fg-eco on`** → set `eco: true` in `.forge/config.json`, then read the sibling [`ECO.md`](./ECO.md) and adopt its discipline for the rest of this session (behavior 4 above).
- **`fg-eco off`** → set `eco: false`; stop applying the Eco discipline in this session.
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

- **fg-ask** reads `eco` from the top-level `.forge/config.json` at grilling start: if `true`, applies the [Eco](./ECO.md) YAGNI lens to every slice discussion (no separate question). See fg-ask Forge integration.
- **fg-run** reads `eco` from the top-level `.forge/config.json` when building a Dynamic Workflow: if `true`, (1) caps subagents at `sonnet` and (2) prepends the full [`ECO.md`](./ECO.md) to each subagent's prompt. See fg-run §1.
- **fg-map is out of scope** — its mappers write the codebase map that fuels fg-ask grilling, and degrading map quality degrades design quality (ADR-0014).

fg-eco only flips the default; it does not start any work.

## Handoff

After toggling, state the new value in one line. The config-driven effects land on the **next** fg-run workflow build and the next fg-ask grilling — nothing already running changes. When you turned eco **on**, also note that you've adopted the Eco discipline for the current session from now on. There is no loop next-step; fg-eco is a side utility.

## Document impact

- Creates/updates `.forge/config.json` (the `eco` key only; git-tracked). Touches nothing else.
