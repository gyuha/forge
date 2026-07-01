---
name: fg-statusline
description: Set up (or refresh) a Claude Code statusline that shows forge's current loop progress. It installs a self-contained bash fragment script that reads .forge/ and prints up to two compact lines — the active task's name with a colored ask/run/learn progress pipeline, and a backlog/awaiting-retro summary — then wires it into settings.json. Because Claude Code allows only ONE statusLine, it does NOT replace an existing one: it auto-wraps your current statusLine command so forge appears as extra rows below it (the original output is preserved). An on-demand setup utility outside the loop. Use in contexts like 'forge statusline', 'statusline 설정', '상태바', '상태 표시줄', 'add forge to statusline'.
---

# fg-statusline — set up the forge progress statusline (outside the loop)

This is **not** a stage of the forge loop. It is a one-time setup utility: it installs the forge statusline fragment script to a stable location and wires it into your Claude Code `settings.json`, so your terminal statusline shows where the forge loop currently stands. Re-run it any time to refresh the installed script after a forge update.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, confirmations, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.**

## Why a script (and why it can't be a plugin component)

Claude Code's statusLine is configured **only** in `settings.json` (`statusLine` key) — a plugin cannot register one — and the command runs as a **non-interactive shell command** that gets session JSON on stdin and prints text. It cannot call a forge skill. So forge ships a real `bash` script, `scripts/forge-statusline.sh`, that reads `.forge/` directly and prints up to two compact lines. It is a deliberately **thin, display-only** reader: it shows the *current stage* (as a colored ask/run/learn progress pipeline, not just a stage word), and does **not** reproduce fg-status's next-step priority machine (fg-status stays the single source of truth for "what to do next"). See `.forge/adr/0017-statusline-integration.md`.

Two facts shape the setup:

- **Only ONE statusLine exists, and there is no stacking.** If you already run another statusline, forge cannot be "added" alongside it — it must be **composed in**. This skill wraps your existing command so forge shows as an extra row.
- **Plugin install paths change on every update** (`~/.claude/plugins/cache/<hash>/`), and `${CLAUDE_PLUGIN_ROOT}` is **not** available to the statusLine shell. So the scripts must be **copied to stable paths** the settings can reference under the Claude config dir (`~/.claude/` by default). The fragment reads the current project's `.forge/` (from the session JSON's `cwd`, see below), so one global copy serves every project.
- **Reference the scripts by ABSOLUTE path in `settings.json`, never `~`.** The statusLine `command` is not guaranteed to undergo tilde expansion by the host, so a literal `~/.claude/...` can fail to resolve and silently blank the **entire** statusline (including any wrapped original). Resolve `$HOME` (or `$CLAUDE_CONFIG_DIR`) at setup time and write the full absolute path. This matches what working statuslines (claude-hud, powerline scripts) already do. See ADR-0017.

## What the fragment prints

The script reads the session JSON on stdin and resolves the project directory from its `cwd` (falling back to `workspace.current_dir`, then to `$PWD` when no JSON/cwd is piped — e.g. an interactive run), `cd`s there, and prints **up to two lines**, or nothing when idle. Resolving cwd from stdin (rather than assuming the shell's cwd is the project) is why it shows the right project even when the host runs the statusLine from elsewhere. Unlike the single-segment precedence design this replaced (ADR-0017's original mechanism — see its 2026-07-02 amendment), the two lines are **independent** — both show whenever they apply, neither hides the other:

```
Line 1 (active slot present):
  ⚒ [🔁 rN/cap ]<slug> | ✔ ask → ● run → ○ learn → ○ done | [flag]

Line 1 fallback (no active slot, but a goal loop is in flight):
  🔁 rN/cap

Line 2 (backlog and/or executed non-empty, independent of line 1):
  📋 N queued · 📝 M awaiting retro     (either half omitted when zero)

(nothing)   idle — active slot, executed, backlog, loop all empty
```

- **The ask/run/learn/done pipeline** always renders all four stages of the forge loop (the fourth, `done`, completes the visual picture — it does not correspond to a bucket this script ever actually sits at, see below): stages before the current one show `✔` (done, green), the current stage shows `●` (bold/cyan), stages after show `○` (dim). Since the active slot only ever exists at `run` or `learn` (a plan reaches `.forge/plan.md` only after promotion from the backlog — see fg-ask — and a sealed task moves to `.forge/done/` and stops appearing in line 1 entirely — see fg-done), `ask` renders done and `done` renders upcoming every time line 1 appears; that is expected, not a bug. The exact colors are an implementation detail tuned live in a real terminal, not a fixture concern — tests strip ANSI codes and assert on the visible text/symbols.
- **flag** (only at the `learn` stage) — `✓` verified yes · `⏳` verification pending · `✗` verified failed · (omitted) for `skipped`/`n/a`. Placed after the pipeline's closing `|`.
- **🔁 rN/cap** — present whenever `loop.md` exists (an fg-loop goal drive is in flight), showing its replan round / cap. Attached as a prefix on line 1 when an active slot exists; shown as its own prefix-less line when there is no active slot.
- Line 2 carries no `⚒` prefix — only line 1 (and its loop-only fallback) does.
- It resolves the branch-isolated forge root (ADR-0011): `.forge/` on the default branch, `.forge/branch/<branch>/` otherwise.

The first three stage names (`ask`/`run`/`learn`) mirror `skills/fg-status/SKILL.md`'s task table bucket→stage mapping (backlog → ask, active plan-only → run, run.md present/`executed/` → learn) — this is the **thin display twin**, now with the earlier stages of the pipeline shown alongside the current one instead of a single stage word. `done` is a fourth, decorative-only stage appended for the visual — it has no corresponding bucket in fg-status's table (a sealed task leaves the tracked buckets entirely) and never becomes the current (`●`) stage in this script. If the `ask`/`run`/`learn` bucket→stage mapping ever changes, update both the script and fg-status together.

## Setup procedure

Run these steps in conversation (the skill runs in the main session, so it can read files, show diffs, and ask for confirmation). The script sources live at `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline.sh` (the fragment) and `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline-wrapper.sh` (the composition wrapper) — both available here, in the skill context, *not* in the statusLine shell later. Let `CFG` be the Claude config dir (`$CLAUDE_CONFIG_DIR` if set, else `$HOME/.claude`); resolve it to an **absolute path** now, because every `settings.json` reference must be absolute (no `~`).

### 1. Install the scripts to stable paths

Copy both scripts and `chmod +x` them (idempotent — a **refresh** after a forge update is just re-running this):

- `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline.sh` → `<CFG>/forge-statusline.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline-wrapper.sh` → `<CFG>/forge-statusline-wrapper.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline.js` → `<CFG>/forge-statusline.js` **and** `${CLAUDE_PLUGIN_ROOT}/scripts/resolve-forge-root.js` → `<CFG>/resolve-forge-root.js` — the node fallback (ADR-0022) and the resolver it `require`s (must sit next to it). Needed only for the Windows / no-bash path below; harmless to always copy.

Both `.sh` are generic (no per-install substitution) — the wrapper finds the fragment and the preserved original **in its own install directory**, resolved at runtime from the wrapper's own script path (`BASH_SOURCE`), **not** from `$CLAUDE_CONFIG_DIR`. The statusLine process may not export that env var, and depending on it would silently blank the whole statusline in a custom config-dir setup (ADR-0017). Since the companions are copied next to the wrapper (all three land in `CFG`), one global copy of each serves every project.

#### Cross-platform: Windows / no-bash (node fallback — ADR-0022)

The fragment ships in two forms — `forge-statusline.sh` (bash, primary) and `forge-statusline.js` (node, identical output, guarded by `scripts/forge-statusline.parity.test.sh`).

**Resolve `STATUSLINE_CMD` ONCE here, then use that single value in every wiring/refresh step below** — do NOT hardcode `.sh` in the later steps (a sequential reader would otherwise install an unrunnable bash command on a no-bash host and re-installing would just repeat the same broken wiring).

**Decide by the HOST OS the statusLine will run under — NOT by whether bash is on this install session's PATH.** The skill runs via the Bash tool, which *always* has bash, so a PATH probe here would pick `.sh` on every platform and the Windows node fallback would never be selected (ADR-0022 review). The statusLine command runs later in the host's *system shell* (on Windows: cmd/PowerShell — which may lack bash entirely or have PowerShell blocked), a different environment from this install session. So detect the OS (`uname -s`: `Darwin`/`Linux` → Unix; `MINGW*`/`MSYS*`/`CYGWIN*`, or no `uname` with a Windows environment → Windows):

- **Unix (Darwin / Linux, incl. WSL)** → `STATUSLINE_CMD = <CFG>/forge-statusline.sh`
- **Windows** → `STATUSLINE_CMD = node <CFG>/forge-statusline.js` — node always runs on Windows and dodges a blocked/absent PowerShell; do **not** assume the Windows system shell has bash even when Git Bash exists for the Bash tool. (`<CFG>/resolve-forge-root.js` must sit beside `forge-statusline.js` — see the copy list.)

State the detected OS and the chosen `STATUSLINE_CMD` to the user when you wire it, so the choice is auditable.

**Wrapping requires bash.** The original-statusline-preservation wrapper (`forge-statusline-wrapper.sh`) is bash-only, so the auto-wrap branch (step 3) only applies when bash is available. On a pure-no-bash host you can only wire forge as the **sole** statusline (the node `STATUSLINE_CMD`); **wrapping an existing** statusline cross-platform without bash is not yet supported — a node wrapper is deferred (follow-up). If a no-bash host already has a non-forge statusLine, say so and stop rather than clobbering it.

### 2. Find the settings file and the existing statusLine

Decide which `settings.json` to edit. Prefer the file that **already** defines a `statusLine` (check project `.claude/settings.json` first, then user `~/.claude/settings.json`). If neither has one, default to user `~/.claude/settings.json` (create it if missing, preserving any existing keys). Read its current `statusLine` value, if any.

Branch on what you find:

- **No existing `statusLine`** → set forge as the sole statusline directly, using the **`STATUSLINE_CMD` resolved above** by **absolute path** (the fragment reads cwd from the session JSON on stdin, so it works as the sole command):
  ```json
  "statusLine": { "type": "command", "command": "<STATUSLINE_CMD>" }
  ```
  (`<STATUSLINE_CMD>` = `<CFG>/forge-statusline.sh` when bash is present, else `node <CFG>/forge-statusline.js`; `<CFG>` resolved absolute, e.g. `/Users/you/.claude/...`.) Confirm the one-line change with the user, then write it.

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
copy fragment(.sh+.js) + wrapper + resolve-forge-root.js → <CFG>/  (chmod +x, absolute)  [refresh: re-copy]
   ↓
resolve STATUSLINE_CMD once by HOST OS (uname -s):  Unix(Darwin/Linux/WSL) → <CFG>/forge-statusline.sh  ·  Windows → node <CFG>/forge-statusline.js
   ↓
locate settings.json + read existing statusLine
   ├── none                → set command = <STATUSLINE_CMD> (absolute)   (confirm, write)
   ├── already forge-wrap  → refreshed in step 1; fix ~→absolute if needed; report & stop
   └── other command       → [bash only] write original verbatim into <CFG>/forge-statusline-orig.sh
                              → show before/after → confirm → command = <CFG>/forge-statusline-wrapper.sh
                              [no bash: cannot wrap — report & stop, don't clobber]
```

## Notes & assumptions

- **cwd resolution.** The fragment resolves the project directory from the session JSON's `cwd` (then `workspace.current_dir`, then `$PWD`) and `cd`s there before reading `.forge/`, so it shows the right project even when the host runs the statusLine from a different directory. In the wrapper case, the wrapper feeds the same JSON to the fragment on stdin so this resolution still applies. It stays jq-free (defensive `sed` extraction) — the one place the fragment parses JSON.
- **Refresh on update.** Because the scripts are copied (not referenced in place), a forge plugin update does not change the installed copies automatically — re-run `fg-statusline` to refresh **all** of them: `forge-statusline.sh`, the node fallback `forge-statusline.js` + its `resolve-forge-root.js`, and `forge-statusline-wrapper.sh` (the full step-1 copy list). They rarely change, so this is infrequent.
- **Takes effect on restart.** Claude Code loads the `statusLine` config at session start — after setup, fully quit and relaunch Claude Code before judging whether it works. A `~`-path command that silently failed is the classic "nothing shows" cause; this setup writes absolute paths to avoid it.
- **Trust & disabling.** statusLine runs only in a trusted workspace and is suppressed if `disableAllHooks` is set — that is host behavior, not forge's.

## Handoff

State in one line what was done (installed / refreshed / already-wired) and that it takes effect **after a full Claude Code restart** (the config loads at session start). There is no loop next-step — fg-statusline is a side utility. Mention how to restore (set `statusLine.command` back to the command preserved in `<CFG>/forge-statusline-orig.sh`) and that re-running refreshes the scripts.

## Document impact

- Writes **outside** the forge state tree, under the Claude config dir (`<CFG>` = `$CLAUDE_CONFIG_DIR` or `~/.claude`): `<CFG>/forge-statusline.sh` (the bash fragment) plus the node fallback `<CFG>/forge-statusline.js` + `<CFG>/resolve-forge-root.js`, and `<CFG>/forge-statusline-wrapper.sh` (the composition wrapper) — all copied; when wrapping, `<CFG>/forge-statusline-orig.sh` (the preserved original command); and the `statusLine` key (an **absolute-path** `STATUSLINE_CMD`) in the chosen `settings.json`. It touches **no** `.forge/` loop state (active slot, backlog, executed, done) and writes nothing git-tracked in the project.
