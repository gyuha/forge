---
name: fg-statusline
description: Set up (or refresh) a Claude Code statusline that shows forge's current loop progress. It installs a self-contained bash fragment script that reads .forge/ and prints one compact line — the active task and its stage, a goal-loop indicator, or backlog count — then wires it into settings.json. Because Claude Code allows only ONE statusLine, it does NOT replace an existing one: it auto-wraps your current statusLine command so forge appears as an extra row below it (the original output is preserved). An on-demand setup utility outside the loop. Use in contexts like 'forge statusline', 'statusline 설정', '상태바', '상태 표시줄', 'add forge to statusline'.
---

# fg-statusline — set up the forge progress statusline (outside the loop)

This is **not** a stage of the forge loop. It is a one-time setup utility: it installs the forge statusline fragment script to a stable location and wires it into your Claude Code `settings.json`, so your terminal statusline shows where the forge loop currently stands. Re-run it any time to refresh the installed script after a forge update.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, confirmations, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.**

## Why a script (and why it can't be a plugin component)

Claude Code's statusLine is configured **only** in `settings.json` (`statusLine` key) — a plugin cannot register one — and the command runs as a **non-interactive shell command** that gets session JSON on stdin and prints text. It cannot call a forge skill. So forge ships a real `bash` script, `scripts/forge-statusline.sh`, that reads `.forge/` directly and prints one compact line. It is a deliberately **thin, display-only** reader: it shows the *current stage*, and does **not** reproduce fg-status's next-step priority machine (fg-status stays the single source of truth for "what to do next"). See `.forge/adr/0017-statusline-integration.md`.

Two facts shape the setup:

- **Only ONE statusLine exists, and there is no stacking.** If you already run another statusline, forge cannot be "added" alongside it — it must be **composed in**. This skill wraps your existing command so forge shows as an extra row.
- **Plugin install paths change on every update** (`~/.claude/plugins/cache/<hash>/`), and `${CLAUDE_PLUGIN_ROOT}` is **not** available to the statusLine shell. So the scripts must be **copied to stable paths** the settings can reference under the Claude config dir (`~/.claude/` by default). The fragment reads the current project's `.forge/` (from the session JSON's `cwd`, see below), so one global copy serves every project.
- **Reference the scripts by ABSOLUTE path in `settings.json`, never `~`.** The statusLine `command` is not guaranteed to undergo tilde expansion by the host, so a literal `~/.claude/...` can fail to resolve and silently blank the **entire** statusline (including any wrapped original). Resolve `$HOME` (or `$CLAUDE_CONFIG_DIR`) at setup time and write the full absolute path. This matches what working statuslines (claude-hud, powerline scripts) already do. See ADR-0017.

## What the fragment prints

The script reads the session JSON on stdin and resolves the project directory from its `cwd` (falling back to `workspace.current_dir`, then to `$PWD` when no JSON/cwd is piped — e.g. an interactive run), `cd`s there, and prints a single line, or nothing when idle. Resolving cwd from stdin (rather than assuming the shell's cwd is the project) is why it shows the right project even when the host runs the statusLine from elsewhere. Precedence — one segment only:

```
⚒ [🔁 rN/cap ] <slug>:<stage> [flag]    active slot   (stage: run | learn)
⚒ [🔁 rN/cap ] 📝 N awaiting retro        parked in executed/
⚒ [🔁 rN/cap ] 📋 N queued                backlog only
⚒ 🔁 rN/cap                               goal loop in flight, no work to show
(nothing)                                 idle — active slot, executed, backlog all empty
```

- **stage** — `run` (plan promoted, not yet run) or `learn` (run.md present, retro pending), mapped from the bucket exactly as fg-status's task table does.
- **flag** (only at `learn`) — `✓` verified yes · `⏳` verification pending · `✗` verified failed · (omitted) for `skipped`/`n/a`.
- **🔁 rN/cap** — present whenever `loop.md` exists (an fg-loop goal drive is in flight), showing its replan round / cap.
- It resolves the branch-isolated forge root (ADR-0011): `.forge/` on the default branch, `.forge/branch/<branch>/` otherwise.

This stage mapping is the **thin display twin** of `skills/fg-status/SKILL.md`'s task table. If that bucket→stage mapping ever changes, update both the script and fg-status together.

## Setup procedure

Run these steps in conversation (the skill runs in the main session, so it can read files, show diffs, and ask for confirmation). The script sources live at `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline.sh` (the fragment) and `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline-wrapper.sh` (the composition wrapper) — both available here, in the skill context, *not* in the statusLine shell later. Let `CFG` be the Claude config dir (`$CLAUDE_CONFIG_DIR` if set, else `$HOME/.claude`); resolve it to an **absolute path** now, because every `settings.json` reference must be absolute (no `~`).

### 1. Install the scripts to stable paths

Copy both scripts and `chmod +x` them (idempotent — a **refresh** after a forge update is just re-running this):

- `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline.sh` → `<CFG>/forge-statusline.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline-wrapper.sh` → `<CFG>/forge-statusline-wrapper.sh`

Both are generic (no per-install substitution) — the wrapper finds the fragment and the preserved original **in its own install directory**, resolved at runtime from the wrapper's own script path (`BASH_SOURCE`), **not** from `$CLAUDE_CONFIG_DIR`. The statusLine process may not export that env var, and depending on it would silently blank the whole statusline in a custom config-dir setup (ADR-0017). Since the companions are copied next to the wrapper (all three land in `CFG`), one global copy of each serves every project.

### 2. Find the settings file and the existing statusLine

Decide which `settings.json` to edit. Prefer the file that **already** defines a `statusLine` (check project `.claude/settings.json` first, then user `~/.claude/settings.json`). If neither has one, default to user `~/.claude/settings.json` (create it if missing, preserving any existing keys). Read its current `statusLine` value, if any.

Branch on what you find:

- **No existing `statusLine`** → set forge as the sole statusline directly, by **absolute path** (the fragment reads cwd from the session JSON on stdin, so it works as the sole command):
  ```json
  "statusLine": { "type": "command", "command": "<CFG>/forge-statusline.sh" }
  ```
  (`<CFG>` resolved, e.g. `/Users/you/.claude/forge-statusline.sh`.) Confirm the one-line change with the user, then write it.

- **An existing `statusLine.command` that is NOT already a forge wrapper** → this is the auto-wrap case (below). Preserve it.

- **An existing forge wrapper** (its command references `forge-statusline-wrapper.sh` / `forge-statusline`) → already wired. Do **not** wrap again (guard against double-wrapping). Step 1 already refreshed the scripts; if the command still uses a `~` path, rewrite it to the absolute path (the one fix worth applying), then report it's up to date and stop.

### 3. Auto-wrap the existing statusLine

The wrapper script is already installed (step 1) and is **generic** — it runs whatever command is preserved in `<CFG>/forge-statusline-orig.sh`, then appends the forge fragment as a separate row below (only when non-empty, so idle adds no blank row), feeding the same session JSON to both so each resolves cwd identically. So wrapping is just two writes:

1. **Preserve the original command** into `<CFG>/forge-statusline-orig.sh` so the wrapper can invoke it. Write the user's current `statusLine.command` verbatim into a small script — this sidesteps all quote-escaping (the original may contain nested quotes):
   ```bash
   #!/usr/bin/env bash
   # Your original (pre-forge) statusline command, preserved verbatim by fg-statusline.
   <ORIGINAL_COMMAND>
   ```
   `<ORIGINAL_COMMAND>` is the original command exactly as it appeared in `settings.json` (it already receives the session JSON on stdin, since the wrapper pipes stdin into this file). `chmod +x` it.
2. **Point settings.json at the wrapper, by absolute path:**
   ```json
   "statusLine": { "type": "command", "command": "<CFG>/forge-statusline-wrapper.sh" }
   ```

**Before writing**, show the user the before → after of `statusLine.command` and the preserved original, and get explicit confirmation — this edits their settings. Preserve all other settings keys and keep the JSON valid.

Procedure flow:

```
copy fragment + wrapper → <CFG>/  (chmod +x, absolute paths)   [refresh: re-copy both]
   ↓
locate settings.json + read existing statusLine
   ├── none                → set command = <CFG>/forge-statusline.sh (absolute)   (confirm, write)
   ├── already forge-wrap  → refreshed in step 1; fix ~→absolute if needed; report & stop
   └── other command       → write original verbatim into <CFG>/forge-statusline-orig.sh
                              → show before/after → confirm → command = <CFG>/forge-statusline-wrapper.sh
```

## Notes & assumptions

- **cwd resolution.** The fragment resolves the project directory from the session JSON's `cwd` (then `workspace.current_dir`, then `$PWD`) and `cd`s there before reading `.forge/`, so it shows the right project even when the host runs the statusLine from a different directory. In the wrapper case, the wrapper feeds the same JSON to the fragment on stdin so this resolution still applies. It stays jq-free (defensive `sed` extraction) — the one place the fragment parses JSON.
- **Refresh on update.** Because the scripts are copied (not referenced in place), a forge plugin update does not change `<CFG>/forge-statusline.sh` / `forge-statusline-wrapper.sh` automatically — re-run `fg-statusline` to refresh them. They rarely change, so this is infrequent.
- **Takes effect on restart.** Claude Code loads the `statusLine` config at session start — after setup, fully quit and relaunch Claude Code before judging whether it works. A `~`-path command that silently failed is the classic "nothing shows" cause; this setup writes absolute paths to avoid it.
- **Trust & disabling.** statusLine runs only in a trusted workspace and is suppressed if `disableAllHooks` is set — that is host behavior, not forge's.

## Handoff

State in one line what was done (installed / refreshed / already-wired) and that it takes effect **after a full Claude Code restart** (the config loads at session start). There is no loop next-step — fg-statusline is a side utility. Mention how to restore (set `statusLine.command` back to the command preserved in `<CFG>/forge-statusline-orig.sh`) and that re-running refreshes the scripts.

## Document impact

- Writes **outside** the forge state tree, under the Claude config dir (`<CFG>` = `$CLAUDE_CONFIG_DIR` or `~/.claude`): `<CFG>/forge-statusline.sh` (the fragment, copied) and `<CFG>/forge-statusline-wrapper.sh` (the composition wrapper, copied); when wrapping, `<CFG>/forge-statusline-orig.sh` (the preserved original command); and the `statusLine` key (an **absolute-path** command) in the chosen `settings.json`. It touches **no** `.forge/` loop state (active slot, backlog, executed, done) and writes nothing git-tracked in the project.
