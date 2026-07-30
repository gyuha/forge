---
name: fg-eco
description: Toggle forge's eco mode on/off — when on: caps fg-run subagents at sonnet, activates the embedded Eco laziness-first discipline (ECO.md — code simplicity + terse output) in fg-run subagents, fg-ask grilling, and the current session, and replaces task-end handoffs (fg-run, fg-done, batch/unattended paths) with a compact summary table. Does NOT switch the main session's model. `fg-eco on`/`off`; no arg shows state. On-demand utility outside the loop. Use in contexts like 'forge eco', 'eco on', 'eco off', '에코 모드', '경제 모드', 'lazy mode', '요약 표'.
---

# fg-eco — toggle eco mode (outside the loop)

This is **not** a stage of the forge loop. It is a tiny on-demand utility that flips one persistent project setting: whether forge runs **delegated subagent work on a cheaper model tier**. It reads and writes **only** `.forge/config.json` — it never touches the active slot, backlog, executed, or done state.

**What eco mode is (and is not).** A skill cannot switch the current session's model — `/model` is a user-only interactive command, so the main-session stages (fg-ask grilling, fg-done sealing) always run on whatever model the user picked. What *can* be controlled is the behavior of the **forge loop itself** plus the **code-simplicity and terse-communication discipline** applied throughout. The discipline is the **Eco laziness-first spec embedded as the sibling [`ECO.md`](./ECO.md)** — it has no standalone skill and no toggle of its own; turning eco on is its only activation. When eco is on, these behaviors activate:

1. **fg-run model cap** — caps Dynamic Workflow / execution subagents at `sonnet` (only ever lowers, never raises; explicit user model instruction wins).
2. **fg-run Eco injection** — prepends the full [`ECO.md`](./ECO.md) (laziness-first ladder + terse-communication output rules) to each subagent's prompt.
3. **fg-ask YAGNI lens** — fg-ask applies the [Eco](./ECO.md) YAGNI lens to every slice discussion during grilling — no separate question, just sharpened grilling.
4. **Current-session adoption (state-driven).** Whenever the main session **observes `eco: true`**, read [`ECO.md`](./ECO.md) and adopt its discipline — especially the terse-communication output rules — for your own main-session prose for the rest of the conversation; on `eco: false`, drop it. This is **state-driven, not toggle-gated**: it activates not only on an explicit `fg-eco on`, but also when `fg-eco` (no arg) reports or leaves the state **on**, and when any main-session skill reads `eco: true` while working — fg-run building/handing off (including the direct, non-workflow execution path) and fg-ask's own handoff prose (fg-ask's grilling questions stay clear per ECO.md's boundary). Behaviors 1–3 drive the **subagent** cap/injection and the grilling lens from config; **only this behavior puts the main session's own output under the discipline**, so it must fire on every main-session eco-read, not just the toggle. **Unavoidable limit:** a brand-new session where `eco` is already true but no forge skill has run yet cannot self-adopt — a skill runs only when invoked and there is no session-start hook; the first eco-reading skill picks it up.

5. **Task-end summary table.** At the points where a task *ends* — fg-run's single-task handoff, fg-done's explicit single seal, and the batch/unattended paths (Run all, `fg-done all`, `fg-next` delegated seals, `fg-next all`, fg-loop) — the prose handoff is **replaced** (never appended to) by the compact **eco summary table** defined in [`ECO.md`](./ECO.md). This is the *structural* counterpart to behavior 4's *stylistic* compression, added because style advice alone proved insufficient in practice — a missing table is visible, unfollowed prose advice is not. It rides behavior 4's channel (the main session reading `eco: true`), so the same "fires on every main-session eco-read" rule applies. Execution-time narration is untouched; only endings are reshaped. See `.forge/adr/260730-230321-eco-summary-table.md`.

Together these tier the loop as "strong = main session (design + grilling), efficient = delegated execution" and keep the whole loop lazy-first. See `.forge/adr/0014-fg-eco-subagent-model-tiering.md` for the full rationale.

**Cap, not a set.** Eco only ever lowers: if the session model is already `sonnet` or lighter, delegated agents inherit it unchanged (a savings mode must never raise cost). And an **explicit user model instruction always wins** over eco — eco is a default, not an override of the human.

**`.forge/config.json` is a deliberate global exemption from branch-root resolution** (see `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` / ADR-0011): always read/write the top-level `.forge/config.json` on every branch, never `.forge/branch/<branch>/config.json`.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.**

## What it does

- **`fg-eco on`** → set `eco: true` in `.forge/config.json`, then read the sibling [`ECO.md`](./ECO.md) and adopt its discipline for the rest of this session (behavior 4 above).
- **`fg-eco off`** → set `eco: false`; stop applying the Eco discipline in this session.
- **`fg-eco` (no argument)** → report the current state in one line (e.g. "eco mode: off — delegated agents inherit the session model"), then offer the choice via `AskUserQuestion`: turn it on / turn it off / leave as is. Apply only what the user picks. **If the resulting state is on** — it was already on and the user leaves it, or they turn it on — adopt [`ECO.md`](./ECO.md) for this session now (behavior 4); finding eco already on must not silently skip adoption.

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

- **fg-ask** reads `eco` from the top-level `.forge/config.json` at grilling start: if `true`, applies the [Eco](./ECO.md) YAGNI lens to every slice discussion (no separate question) **and adopts ECO.md's output discipline for its own non-grilling prose (handoff/reporting)** — grilling questions stay clear per the boundary (behavior 4). See fg-ask Forge integration.
- **fg-run** reads `eco` from the top-level `.forge/config.json`: if `true`, for delegated subagents it (1) caps them at `sonnet` and (2) prepends the full [`ECO.md`](./ECO.md) to each subagent's prompt, **and the main session running fg-run adopts ECO.md's output discipline for its own execution/reporting prose** — the only carrier on the direct, non-workflow path where there are no subagents (behavior 4). Its single-task handoff is also **replaced** by the eco summary table (behavior 5). See fg-run §1 and its "Next-flow handoff".
- **fg-done** reads `eco` from the top-level `.forge/config.json`: if `true`, the explicit-single-seal summary is rendered in the [eco summary table](./ECO.md) shape rather than bullet prose (behavior 5) — rendering only; the material, the seal script, and the verification/retro gates are untouched. See fg-done's seal-summary block.
- **fg-next** (and **fg-loop**, which inherits its drive discipline) reads `eco` from the top-level `.forge/config.json`: if `true`, each delegated seal in a drive is reported as **one row** of the batch [eco summary table](./ECO.md) instead of a per-task prose notice (behavior 5) — the single-seal summary chapter stays forbidden in a drive either way. The rule lives in `${CLAUDE_PLUGIN_ROOT}/skills/fg-next/DRIVE.md` Part 1; fg-run's "Run all" and `fg-done all` carry the same batch row shape.
- **fg-map is out of scope** — its mappers write the codebase map that fuels fg-ask grilling, and degrading map quality degrades design quality (ADR-0014).

fg-eco only flips the default; it does not start any work.

## Handoff

After toggling, state the new value in one line. The config-driven effects land on the **next** fg-run workflow build and the next fg-ask grilling — nothing already running changes. When you turned eco **on**, also note that you've adopted the Eco discipline for the current session from now on. There is no loop next-step; fg-eco is a side utility.

## Document impact

- Creates/updates `.forge/config.json` (the `eco` key only; git-tracked). Touches nothing else.
