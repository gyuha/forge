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
- **Plugin install paths change on every update** (`~/.claude/plugins/cache/<hash>/`), and `${CLAUDE_PLUGIN_ROOT}` is **not** available to the statusLine shell. So the script must be **copied to a stable path** the settings can reference — `~/.claude/forge-statusline.sh`. The fragment is generic (it reads the current project's `.forge/` by cwd), so one global copy serves every project.

## What the fragment prints

The script (run from a project directory) prints a single line, or nothing when idle. Precedence — one segment only:

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

Run these steps in conversation (the skill runs in the main session, so it can read files, show diffs, and ask for confirmation). Resolve the script source from `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline.sh` (available here, in the skill context — *not* in the statusLine shell later).

### 1. Install the fragment script to a stable path

Copy `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline.sh` → `~/.claude/forge-statusline.sh` and `chmod +x` it. This is also exactly what a **refresh** does — re-running the skill after a forge update re-copies the latest script. (Do this every run, idempotently.)

### 2. Find the settings file and the existing statusLine

Decide which `settings.json` to edit. Prefer the file that **already** defines a `statusLine` (check project `.claude/settings.json` first, then user `~/.claude/settings.json`). If neither has one, default to user `~/.claude/settings.json` (create it if missing, preserving any existing keys). Read its current `statusLine` value, if any.

Branch on what you find:

- **No existing `statusLine`** → set forge as the sole statusline directly:
  ```json
  "statusLine": { "type": "command", "command": "~/.claude/forge-statusline.sh" }
  ```
  Confirm the one-line change with the user, then write it.

- **An existing `statusLine.command` that is NOT already a forge wrapper** → this is the auto-wrap case (below). Preserve it.

- **An existing forge wrapper** (its command points to `~/.claude/forge-statusline-wrapper.sh`, or otherwise references `forge-statusline`) → already wired. Do **not** wrap again (guard against double-wrapping). Step 1 already refreshed the fragment; just report that it's up to date and stop.

### 3. Auto-wrap the existing statusLine

Generate a wrapper script `~/.claude/forge-statusline-wrapper.sh` that feeds the session JSON (stdin) to the **original** command, prints its output, then appends the forge fragment as a **separate row below** — only when the fragment is non-empty (so idle adds no blank row):

```bash
#!/usr/bin/env bash
# Generated by forge fg-statusline. Restore by setting statusLine.command back to:
# original: <ORIGINAL_COMMAND>
input=$(cat)
orig_out=$(printf '%s' "$input" | <ORIGINAL_COMMAND_INVOCATION>)
forge_out=$(bash "$HOME/.claude/forge-statusline.sh")
printf '%s\n' "$orig_out"
[ -n "$forge_out" ] && printf '%s\n' "$forge_out"
```

- `<ORIGINAL_COMMAND_INVOCATION>` — embed the user's original command so it still receives the JSON on stdin. If the original is a script path, invoke it directly (`/path/to/orig` or `bash /path/to/orig`); if it's an inline shell snippet, wrap it as `bash -c '<inline>'`. Keep the original verbatim in the `# original:` comment so the user can restore by hand.
- `chmod +x` the wrapper, then point settings.json at it:
  ```json
  "statusLine": { "type": "command", "command": "~/.claude/forge-statusline-wrapper.sh" }
  ```
- **Before writing**, show the user the before → after of `statusLine.command` (and the generated wrapper) and get explicit confirmation — this edits their settings. Preserve all other settings keys and keep the JSON valid.

Procedure flow:

```
copy fragment → ~/.claude/forge-statusline.sh (chmod +x)   [refresh: re-copy]
   ↓
locate settings.json + read existing statusLine
   ├── none                → set command = forge-statusline.sh        (confirm, write)
   ├── already forge-wrap  → refreshed in step 1; report & stop
   └── other command       → generate forge-statusline-wrapper.sh embedding the original
                              → show before/after → confirm → command = wrapper
```

## Notes & assumptions

- **cwd assumption.** The fragment reads `.forge/` relative to the statusLine shell's working directory, assuming it is the project directory (it does not parse the stdin JSON's `cwd`). If a host runs the statusLine from a different directory, the wrapper can be extended to extract `cwd` from the captured `$input` and `cd` into it before calling the fragment — note this to the user only if their statusline shows nothing in a known-active project.
- **Refresh on update.** Because the script is copied (not referenced in place), a forge plugin update does not change `~/.claude/forge-statusline.sh` automatically — re-run `fg-statusline` to refresh it. The fragment rarely changes, so this is infrequent.
- **Trust & disabling.** statusLine runs only in a trusted workspace and is suppressed if `disableAllHooks` is set — that is host behavior, not forge's.

## Handoff

State in one line what was done (installed / refreshed / already-wired) and that it takes effect on the next statusline refresh. There is no loop next-step — fg-statusline is a side utility. Mention how to restore (point at the `# original:` line in the wrapper) and that re-running refreshes the script.

## Document impact

- Writes **outside** the forge state tree: `~/.claude/forge-statusline.sh` (the fragment), optionally `~/.claude/forge-statusline-wrapper.sh` (the composition wrapper), and the `statusLine` key in the chosen `settings.json`. It touches **no** `.forge/` loop state (active slot, backlog, executed, done) and writes nothing git-tracked in the project.
