---
name: fg-config
description: Unified settings surface for forge — every key in .forge/config.json: `simple` (auto-seal — fg-run verifies then seals in the same turn, retro auto-skipped), `eco` (sonnet-capped subagents + ECO.md discipline), `tdd` (test-first default), `driveCommit`/`driveCommitMessage`, `defaultBranch`. Replaces fg-eco/fg-tdd. `fg-config` (no arg) shows all and offers changes via a menu; `fg-config <key> <value>` sets one directly. Outside the loop. Use in contexts like 'forge config', '설정', 'simple mode', '심플 모드', 'eco on', 'eco off', '에코 모드', 'tdd on', 'tdd off', 'TDD 켜', 'TDD 꺼'.
---

# fg-config — forge's settings surface (outside the loop)

This is **not** a stage of the forge loop. It is the **single entry point for every persistent project setting** in `.forge/config.json`. It reads and writes **only** that file — it never touches the active slot, backlog, executed, or done state, and it never starts any work. It replaces the former single-key toggle skills `fg-eco` and `fg-tdd` (ADR `260905-212045`): one settings surface beats one skill per key once the keys multiply.

**`.forge/config.json` is a deliberate global exemption from branch-root resolution** (see `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-run/FORGE-ROOT.md` / ADR-0011): always read/write the top-level `.forge/config.json` on every branch, never `.forge/branch/<branch>/config.json`. Reason — it holds `defaultBranch`, which the root-resolution rule itself must read before it can resolve anything, and the other keys are project-wide settings.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.**

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

## What it does

- **`fg-config` (no argument)** → render the current value of every key below as a small table (key · value · one-line meaning), then **offer changes interactively** via the host's `structured_choice` (e.g. `AskUserQuestion`, multi-select): toggle options for the boolean keys (`simple` · `eco` · `tdd`) plus a "leave as is" option; the auto-provided free-text entry ("Other") is the route for the value-typed keys (`driveCommit true`, `driveCommitMessage <template>`, `defaultBranch <name>` — each still validated against its contract below, `defaultBranch` keeping its confirm-first warning). Apply exactly what the user picks — a picked boolean flips and saves, "leave as is" changes nothing. This menu is a deliberately retained selection (the same family as fg-run's backlog menu), **not** a loop handoff — ADR-0015's statement-form rule governs handoffs, not settings menus. When `structured_choice` is `false` or the host is unknown, print the table and accept one typed `<key> <value>` instead.
- **`fg-config <key>`** → report that key's current value and its one-line meaning. Change nothing.
- **`fg-config <key> <value>`** → validate the value against the key's contract below, write it (read → set the one key → write back, **preserving all other keys**; keep the JSON valid; create the file lazily on first write), and state the new value in one line. Unknown key → list the valid keys and stop; invalid value → state the contract and stop.
- Bare toggle phrasings route here: "eco on" = `fg-config eco true`, "TDD 꺼" = `fg-config tdd false`, "simple on" = `fg-config simple true`, and so on.

## The keys and their contracts

| Key | Type / default | Meaning |
|---|---|---|
| `simple` | boolean, default `false` | Auto-seal mode — see below |
| `eco` | boolean, default `false` | Economical delegated execution — see below |
| `tdd` | boolean, default `false` | Test-first default for new tasks — see below |
| `driveCommit` | **strict boolean**, default `false` | Per-task local commit in unattended drives |
| `driveCommitMessage` | string, optional | Template for that commit message |
| `defaultBranch` | string, default `main` | The branch whose forge root is the top-level `.forge/` |

### `simple` — auto-seal mode (ADR `260905-212045`)

When `true`, fg-run's task-end handoff chains straight through in the same turn: UAT (verification) → record `retro: skipped (simple mode)` (unconditional, regardless of divergence — the same relaxation family as fg-next all / fg-loop) → invoke the deterministic seal script (forge-done). The user experiences the loop as ask → run; internally verify and seal still happen. **The verification gate (ADR-0009) is inviolable**: on `verified: pending|failed` nothing is auto-sealed — fg-run stops and reports as it always did. Not a skip mode: skipping the seal would leave the active slot occupied and block the next run. fg-next / fg-next all / fg-loop already auto-seal, so `simple` changes nothing for them; fg-quick is outside the loop and unaffected.

### `eco` — economical delegated execution (ADR-0014)

A skill cannot switch the current session's model (`/model` is user-only), so the main-session stages always run on the user's model. What eco controls is the loop's delegated work plus the **code-simplicity and terse-communication discipline** — the Eco laziness-first spec embedded as the sibling [`ECO.md`](./ECO.md) (no standalone skill; this key is its only activation). When `true`:

1. **fg-run model cap** — Dynamic Workflow / execution subagents capped at `sonnet` (a cap, not a set: only ever lowers, never raises; an explicit user model instruction always wins).
2. **fg-run Eco injection** — the full [`ECO.md`](./ECO.md) is prepended to each subagent's prompt.
3. **fg-ask YAGNI lens** — grilling applies the [Eco](./ECO.md) YAGNI lens to every slice discussion (no separate question).
4. **Current-session adoption (state-driven)** — whenever the main session **observes `eco: true`** (this skill reporting/leaving it on, or any main-session skill reading it while working), read [`ECO.md`](./ECO.md) and adopt its output discipline for main-session prose; on `false`, drop it. Unavoidable limit: a brand-new session cannot self-adopt until the first eco-reading skill runs.
5. **Task-end summary table** — at the points where a task ends (fg-run's handoff, fg-done's explicit single seal, batch/unattended paths), the prose handoff is **replaced** by the compact eco summary table defined in [`ECO.md`](./ECO.md) (ADR `260730-230321`).

fg-map is out of scope — degrading map quality degrades design quality (ADR-0014).

### `tdd` — test-first default (ADR-0008)

A team-shared default, not a per-task lock: fg-ask reads it as the default when asking, at the start of grilling, whether to build the task test-first, and records `<!-- tdd: on|off -->` on the plan; fg-run runs a plan test-first when its marker is on. Toggling takes effect on the **next** fg-ask — already-planned tasks keep their marker.

### `driveCommit` / `driveCommitMessage` — unattended-drive commits

Single definition: `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-next/DRIVE.md` Part 3 (ADR `260901-213128`) — this skill only sets the values; it never restates the drive discipline. Contracts: `driveCommit` is a **strict boolean** (only JSON `true` activates it; anything else is off) — when on, an unattended drive (fg-next all / fg-loop) makes a **local commit per sealed task** (never a push; a refused commit is a `fork` wall). `driveCommitMessage` is an optional message template whose **only** substitutions are `{title}`, `{slug}`, `{task}` — warn if the user supplies any other placeholder.

### `defaultBranch` — branch-root anchor (ADR-0011)

Read by forge-root resolution (FORGE-ROOT.md) to decide which branch uses the top-level `.forge/` — every other branch gets `.forge/branch/<branch>/`. **Changing it re-points where all loop state is read and written**; warn before setting it that in-flight state under the old root does not move (integration is fg-merge's job), and set it only when the user confirms.

## The config file

Git-tracked JSON (lazily created on first write; `.gitignore` whitelists `!.forge/config.json`). A missing file or key means every boolean above is `false` and `defaultBranch` is `main`. It is a team-shared project default. Editing the file directly remains fine — this skill is a convenience surface, not a lock.

## Handoff

After a write, state the new value in one line and when it lands (config-driven effects apply to the **next** fg-ask grilling / fg-run build — nothing already running changes). If the resulting `eco` state is on, adopt [`ECO.md`](./ECO.md) for this session now (behavior 4) — finding it already on must not silently skip adoption. There is no loop next-step; fg-config is a side utility.

## Document impact

- Creates/updates `.forge/config.json` (git-tracked). Touches nothing else.
