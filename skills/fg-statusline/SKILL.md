---
name: fg-statusline
description: Set up (or refresh) a Claude Code statusline showing forge's loop progress, in one of two install modes. Method 1 (append) auto-wraps your existing statusLine so forge shows as extra rows below it (original preserved) — the thin forge-only fragment. Method 2 (merge) installs a forge-owned unified script that renders daleseo-style system info (model/effort/dir/git · Ctx/5h/7d usage bars · session elapsed) AND forge progress in one command. If you already have a statusline it asks which mode; if you have none it installs method 2; on Windows-with-an-existing-statusline it offers method 2 only (the wrapper is bash-only). An on-demand setup utility outside the loop. Use in contexts like 'forge statusline', 'statusline 설정', '상태바', '상태 표시줄', 'add forge to statusline'.
---

# fg-statusline — set up the forge progress statusline (outside the loop)

This is **not** a stage of the forge loop. It is a one-time setup utility: it installs forge's statusline scripts to a stable location and wires one into your Claude Code `settings.json`, so your terminal statusline shows where the forge loop currently stands. Re-run it any time to refresh the installed scripts after a forge update.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, confirmations, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.**

## The two install modes (ADR-0029)

forge can occupy the single statusLine in one of two ways. Both share the same thin forge fragment (`forge-statusline.sh`/`.js`) for the forge progress line(s); they differ in what else the statusLine shows and who owns the command.

- **Method 1 — append (wrap).** The base is a **third-party** statusline you already run (claude-hud, a powerline script, …). The generic wrapper (`forge-statusline-wrapper.sh`) runs your original command, then appends the forge fragment as a separate row below it (original output preserved). This is the original ADR-0017 design and is **unchanged** by ADR-0029 — the fragment stays a deliberately thin, forge-only reader that renders **no** system info.
- **Method 2 — merge (unified).** A single forge-owned command (`forge-statusline-full.sh`/`.js`) renders **daleseo-style system info** (model · reasoning effort · working dir · `⎇` git branch+status; then Ctx / 5h / 7d usage bars and a `⏱` session-elapsed segment) **and** the forge progress, in one script. Here forge itself is the whole statusLine — there is no third-party base to preserve (if method 2 replaces an existing statusLine, its original is still saved for restore).

**Which mode gets installed:** existing statusLine → ask the user 1 or 2; no statusLine → method 2 automatically; Windows **with** an existing statusLine → method 2 only (method 1's wrapper is bash-only). The mode is detected from the wired command's path (wrapper path = method 1, unified-script path = method 2) — **no new `config.json` key**. Re-running refreshes the current mode silently; switching modes is asked once.

## Why a script (and why it can't be a plugin component)

Claude Code's statusLine is configured **only** in `settings.json` (`statusLine` key) — a plugin cannot register one — and the command runs as a **non-interactive shell command** that gets session JSON on stdin and prints text. It cannot call a forge skill. So forge ships real scripts that read `.forge/` (and, in method 2, the session JSON) directly and print compact lines.

The **forge fragment** (`scripts/forge-statusline.sh`) is a deliberately **thin, display-only** reader: it shows the *current stage* (as a colored ask/run/learn progress pipeline, not just a stage word) plus a backlog/awaiting-retro summary, and does **not** reproduce fg-status's next-step priority machine (fg-status stays the single source of truth for "what to do next"). See `.forge/adr/0017-statusline-integration.md`. Both modes use this fragment for the forge line(s). The **merge-mode unified script** (`scripts/forge-statusline-full.sh`, method 2) additionally renders system info, but it **delegates** the forge line back to this same fragment (invoked as-is, with the fragment's default `⚒ ` prefix) rather than re-implementing the stage logic, and it likewise never reproduces fg-status's machine. See `.forge/adr/0029-fg-statusline-combined-daleseo-dual-mode.md`.

Two facts shape the setup:

- **Only ONE statusLine exists, and there is no stacking.** If you already run another statusline, forge cannot be "added" alongside it — either it is **composed in** (method 1: wrap your existing command so forge shows as an extra row) or forge **takes over** the whole line (method 2: the unified script; any existing command is preserved for restore). Which one is the mode decision above.
- **Plugin install paths change on every update** (`~/.claude/plugins/cache/<hash>/`), and `${CLAUDE_PLUGIN_ROOT}` is **not** available to the statusLine shell. So the scripts must be **copied to stable paths** the settings can reference under the Claude config dir (`~/.claude/` by default). The fragment reads the current project's `.forge/` (from the session JSON's `cwd`, see below), so one global copy serves every project.
- **Reference the scripts by ABSOLUTE path in `settings.json`, never `~`.** The statusLine `command` is not guaranteed to undergo tilde expansion by the host, so a literal `~/.claude/...` can fail to resolve and silently blank the **entire** statusline (including any wrapped original). Resolve `$HOME` (or `$CLAUDE_CONFIG_DIR`) at setup time and write the full absolute path. This matches what working statuslines (claude-hud, powerline scripts) already do. See ADR-0017.

## What the fragment prints (the forge line(s), both modes)

This is the forge fragment's own output. In **method 1** these are the rows appended below your wrapped original statusline. In **method 2** the merge script reuses this exact output verbatim as its forge line(s), default `⚒ ` prefix included (the `FORGE_SL_PREFIX` env var can still override the line-1 prefix, but the merge script no longer sets it).

The script reads the session JSON on stdin and resolves the project directory from its `cwd` (falling back to `workspace.current_dir`, then to `$PWD` when no JSON/cwd is piped — e.g. an interactive run), `cd`s there, and prints **up to two lines**, or nothing when idle. Resolving cwd from stdin (rather than assuming the shell's cwd is the project) is why it shows the right project even when the host runs the statusLine from elsewhere. Unlike the single-segment precedence design this replaced (ADR-0017's original mechanism — see its 2026-07-02 amendment), the two lines are **independent** — both show whenever they apply, neither hides the other:

```
Line 1 (active slot present):
  ⚒ [🔁 rN/cap ][#N ]<slug> · ✔ ask → ● run → ○ learn → ○ done[ · <flag>][ · Ⓣ Ⓔ]
  (the " · <flag>" and " · Ⓣ Ⓔ" tails appear only when lit — no trailing separator otherwise)

Line 1 (no active slot, but fg-ask is mid-grilling — ask.md marker present):
  ⚒ <working-slug> · ● ask → ○ run → ○ learn → ○ done[ · Ⓔ]

Line 1 fallback (no active slot, no ask.md, but a goal loop is in flight):
  🔁 rN/cap

Line 2 (backlog and/or executed non-empty, independent of line 1):
  📋 N queued · 📝 M awaiting retro     (either half omitted when zero)

(nothing)   idle — active slot, executed, backlog, ask.md, loop all empty
```

- **The ask/run/learn/done pipeline** always renders all four stages of the forge loop (the fourth, `done`, completes the visual picture — it never corresponds to a bucket this script actually sits at, see below): stages before the current one show `✔` (done, green), the current stage shows `●` (bold/cyan), stages after show `○` (dim). The current stage is **gated, not just file-existence-based** (ADR-0017, 3rd amendment 2026-07-03) — exactly one dot is lit at a time:
  - No `plan.md`, no `ask.md` → line 1 is empty (or the loop-only fallback below).
  - No `plan.md`, `ask.md` present → **`ask`** is current (fg-ask is mid-grilling, before anything has been promoted into the active slot). The `working-slug` is read from `ask.md`'s `<!-- forge-ask: ... -->` marker comment, defaulting to the literal string `ask` if the line is missing or unparseable. No flag is shown. **If both `plan.md` and `ask.md` exist, `plan.md` wins** — the active-slot pipeline above is rendered and `ask.md` is ignored for display, reflecting grilling on a *new* task while a different task sits promoted-but-not-run in the active slot.
  - `plan.md` present, no `run.md` → **`run`** is current. Only fg-run ever promotes a plan from the backlog into the active slot, so a promoted-but-unexecuted plan is already fg-run's territory, not fg-ask's — fg-ask has no path to quietly edit `plan.md` in place (a re-grill always goes through a fresh `backlog/` entry). This reverses the prior "ask is current here" reading from the 2026-07-02 2nd amendment (see ADR-0017's 2026-07-03 amendment).
  - `run.md` present, `STATUS.md` `verified:` **not yet sealable** (`pending`/`failed`/missing) → **`run`** is current. This holds even though `run.md` already exists, because fg-learn's own retro gate refuses these values and routes back to fg-run — it is still fg-run's territory (verification-only resume, or fix-and-re-run).
  - `run.md` present, `verified:` **sealable** (`yes`/`skipped`/`n/a`) → **`learn`** is current (the retro gate has passed).
  - `done` never becomes current here — a sealed task leaves `.forge/plan.md` entirely and stops appearing in line 1 (see fg-done); it is shown purely to complete the visual picture of the full 4-stage loop.

  The exact colors are an implementation detail tuned live in a real terminal, not a fixture concern — tests strip ANSI codes and assert on the visible text/symbols.
- **#N task number** — read from the active plan's `<!-- task: N -->` marker (marker-anchored parsing, same style as the `forge-slug` marker) and shown just before the slug. Omitted when the plan has no marker (older plans — graceful), and never shown on the `ask.md`-only line 1 (no plan exists yet at the ask stage).
- **flag** (present whenever `run.md` exists, regardless of whether `run` or `learn` is the current stage) — `✓` verified yes · `⏳` verification pending · `✗` verified failed · (omitted) for `skipped`/`n/a`. Appended as a ` · <flag>` tail after the pipeline; when there is no flag the pipeline is followed directly by the indicator segment, if any (no trailing separator either way). The `ask.md`-only line 1 never carries a flag.
- **Ⓣ Ⓔ mode indicators** — a ` · Ⓣ Ⓔ` segment at the very end of line 1, space-separated, showing only the lit ones. `Ⓣ` (U+24C9) lights when the active plan carries `<!-- tdd: on -->` — like `#N` it can never appear on the `ask.md`-only line. `Ⓔ` (U+24BA) lights when the **top-level** `.forge/config.json` has `"eco": true` (the branch-independent global exception — the same key fg-eco writes; this script only reads it) and applies to every state that renders a slug line, the `ask.md` line included. Neither indicator appears on the `🔁`-only fallback line or when idle. When no indicator is lit the output is byte-identical to the pre-indicator format (the no-trailing-separator rule holds).
- **🔁 rN/cap** — present whenever `loop.md` exists (an fg-loop goal drive is in flight), showing its replan round / cap. Attached as a prefix on line 1 when an active slot exists; shown as its own prefix-less line when there is no active slot and no `ask.md`.
- Line 2 carries no `⚒` prefix — only line 1 (and its loop-only fallback) does.
- It resolves the branch-isolated forge root (ADR-0011): `.forge/` on the default branch, `.forge/branch/<branch>/` otherwise.

The first three stage **names** (`ask`/`run`/`learn`) match `skills/fg-status/SKILL.md`'s task table bucket→stage mapping (backlog → ask, active plan-only → run, run.md present/`executed/` → learn), and as of the 2026-07-03 amendment this script's plan-only case now matches that mapping exactly (both read plan.md-with-no-run.md as `run`). One divergence remains, from the 2026-07-02 2nd amendment: fg-status's Stage column is purely file-existence-based for `run.md` (any `run.md` present → `learn`, full stop), while this fragment additionally reads `STATUS.md` `verified:` to decide whether `run` or `learn` is truly current (see above) — a `verified: failed`/`pending` task shows `run` as current here even though fg-status's table would still label its bucket `learn`. This is a deliberate refinement, not a bug: fg-status answers "which bucket is this task in," this fragment answers "where is a human's attention actually needed right now," and the two questions diverge exactly when a bucket's gate hasn't cleared yet. `done` is a fourth, decorative-only stage appended for the visual — it has no corresponding bucket in fg-status's table (a sealed task leaves the tracked buckets entirely) and never becomes the current (`●`) stage in this script. The `ask.md`-only line 1 has no counterpart in fg-status's table either — fg-status never reports on grilling-in-progress (there is no file for it to read until `backlog/` gets a row), so this is fg-statusline-only display state. If the `ask`/`run`/`learn` bucket **names** ever change, update both the script and fg-status together; the verified-gating refinement and the ask.md display case are local to this script.

## What the merge-mode script prints (method 2 only)

`forge-statusline-full.sh`/`.js` render a daleseo-style dashboard plus the forge line(s), reading everything from the session JSON on stdin (`used_percentage` appears in three places and `resets_at` in two, so the bash twin extracts each leaf from its **parent** object — never a first-match grab; the node twin uses `JSON.parse`). Layout — each line independent, and every field renders only when present (graceful omission):

```
Line 1: <model> · <effort> · <dir> · ⎇ <branch [↑ahead] [↓behind] [+staged] [!modified] [?untracked]>
Line 2: Ctx <bar> N% [· 5h <bar> N% (~H)] [· 7d <bar> N% (~H)] [· ⏱ (D)]
Line 3: ⚒ [#N ]<slug> · ✔ ask → ● run → ○ learn → ○ done[ · <flag>][ · Ⓣ Ⓔ]   (delegated to the fragment)
Line 4: 📋 N queued · 📝 M awaiting retro                                      (delegated to the fragment)
```

- **Line 1 (system):** `model.display_name`, `effort.level` (omitted on models without one), the working-dir basename, and — inside a git repo — the branch as `⎇ <branch>` with `↑N`/`↓N` ahead/behind counts vs the upstream (placed after the branch name, before the worktree counts; each omitted when zero, and the whole `↑↓` pair omitted when the branch has no upstream — stderr suppressed), then `+N`/`!N`/`?N` counts for staged / modified / untracked (each omitted when zero). Segments are joined by ` · `; missing segments drop out.
- **Line 2 (usage):** three 10-cell bars (`█`/`░`), labeled `Ctx` (context) / `5h` (5-hour usage) / `7d` (7-day usage). `context_window.used_percentage` is null at session start → treated as `0`; the two `rate_limits` windows exist **only** for Pro/Max after the first API response and each may be absent independently → that whole segment is omitted when its window is missing. `resets_at` is a **Unix epoch second**, humanized as a compact `~`-prefixed remainder — `(~Xm)` / `(~Xh Ym)` from `now`, or `(~Xd Yh)` when more than 24h remain (the weekly window's common case). Bar fill = `round(pct/10)`; threshold colors `<70` green / `70–89` yellow / `≥90` red (colors are live-tuned and stripped in tests — ADR-0017; the bar length and `%` text carry the same information). A final `⏱ (D)` segment shows the session's elapsed time — `cost.total_duration_ms` floored to seconds (`ms/1000`) and humanized by the same helper as the reset remainders (no separate format logic); the whole segment is omitted when `cost` or `total_duration_ms` is absent, and an explicit `0` renders `⏱ (0m)`.
- **Lines 3–4 (forge):** the fragment's output verbatim, with its default `⚒ ` prefix (the merge script sets no `FORGE_SL_PREFIX` override). When forge is **idle** the fragment emits nothing, so Line 3/4 vanish but the two system lines stay (system info is independent of forge state). All the stage-gating, flags, loop indicator, and branch-root resolution are exactly as documented in the fragment section above — because they *are* the fragment.

Both twins emit identical output (ANSI stripped), guarded by `scripts/forge-statusline-full.parity.test.sh`; behavior is pinned by `scripts/forge-statusline-full.test.sh`. Time is injectable via `FORGE_SL_NOW` (epoch s) so humanization is testable.

## Setup procedure

Run these steps in conversation (the skill runs in the main session, so it can read files, show diffs, and ask for confirmation). The script sources live under `${CLAUDE_PLUGIN_ROOT}/scripts/` — the fragment (`forge-statusline.sh`/`.js`), the method-1 wrapper (`forge-statusline-wrapper.sh`), and the method-2 unified script (`forge-statusline-full.sh`/`.js`) — all available here, in the skill context, *not* in the statusLine shell later. Let `CFG` be the Claude config dir (`$CLAUDE_CONFIG_DIR` if set, else `$HOME/.claude`); resolve it to an **absolute path** now, because every `settings.json` reference must be absolute (no `~`).

### 1. Install the scripts to stable paths

Copy all of these and `chmod +x` them (idempotent — a **refresh** after a forge update is just re-running this; copy the whole list regardless of the chosen mode, so a later mode switch needs no extra copy):

- `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline.sh` → `<CFG>/forge-statusline.sh` (the fragment, both modes)
- `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline-wrapper.sh` → `<CFG>/forge-statusline-wrapper.sh` (method 1)
- `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline-full.sh` → `<CFG>/forge-statusline-full.sh` (method 2, the unified script)
- `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline.js` → `<CFG>/forge-statusline.js`, `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline-full.js` → `<CFG>/forge-statusline-full.js`, **and** `${CLAUDE_PLUGIN_ROOT}/scripts/resolve-forge-root.js` → `<CFG>/resolve-forge-root.js` — the node fallbacks (ADR-0022) and the resolver they `require` (must sit next to them). Needed for the Windows / no-bash path below; harmless to always copy.

All the `.sh`/`.js` are generic (no per-install substitution) — the wrapper finds the fragment and the preserved original, and the unified script finds the fragment, **in their own install directory**, resolved at runtime from each script's own path (`BASH_SOURCE` / `__dirname`), **not** from `$CLAUDE_CONFIG_DIR`. The statusLine process may not export that env var, and depending on it would silently blank the whole statusline in a custom config-dir setup (ADR-0017). Since every companion is copied into `CFG` together, one global copy of each serves every project.

#### Cross-platform: resolving the wired command (node fallback — ADR-0022)

Both the fragment and the unified script ship in two forms — `.sh` (bash, primary) and `.js` (node, identical output, guarded by the parity tests). Only the **method-2** command varies by OS; **method 1's** command is always the wrapper (`<CFG>/forge-statusline-wrapper.sh`), which is bash-only.

**Resolve `STATUSLINE_CMD` (the method-2 / merge command) ONCE here, then use that single value wherever method 2 is wired/refreshed below** — do NOT hardcode `.sh` in the later steps (a sequential reader would otherwise install an unrunnable bash command on a no-bash host and re-installing would just repeat the same broken wiring).

**Decide by the HOST OS the statusLine will run under — NOT by whether bash is on this install session's PATH.** The skill runs via the Bash tool, which *always* has bash, so a PATH probe here would pick `.sh` on every platform and the Windows node fallback would never be selected (ADR-0022 review). The statusLine command runs later in the host's *system shell* (on Windows: cmd/PowerShell — which may lack bash entirely or have PowerShell blocked), a different environment from this install session. So detect the OS (`uname -s`: `Darwin`/`Linux` → Unix; `MINGW*`/`MSYS*`/`CYGWIN*`, or no `uname` with a Windows environment → Windows):

- **Unix (Darwin / Linux, incl. WSL)** → `STATUSLINE_CMD = <CFG>/forge-statusline-full.sh`
- **Windows** → `STATUSLINE_CMD = node <CFG>/forge-statusline-full.js` — node always runs on Windows and dodges a blocked/absent PowerShell; do **not** assume the Windows system shell has bash even when Git Bash exists for the Bash tool. (`<CFG>/forge-statusline.js` + `<CFG>/resolve-forge-root.js` must sit beside it — see the copy list.)

State the detected OS and the chosen `STATUSLINE_CMD` to the user when you wire it, so the choice is auditable.

**Wrapping requires bash; the merge script does not.** The method-1 wrapper (`forge-statusline-wrapper.sh`) is bash-only, so method 1 only applies when bash is available. This is why **Windows + an existing statusLine offers method 2 only** (the unified node script cleanly takes over) — wrapping an existing statusline cross-platform without bash is not yet supported (a node wrapper is deferred, follow-up). If method 2 replaces an existing command, preserve the original for restore (step 3b); on a no-bash host that already has a non-forge statusLine, if the user declines method 2, say so and stop rather than clobbering it.

### 2. Find the settings file and the existing statusLine

Decide which `settings.json` to edit. Prefer the file that **already** defines a `statusLine` (check project `.claude/settings.json` first, then user `~/.claude/settings.json`). If neither has one, default to user `~/.claude/settings.json` (create it if missing, preserving any existing keys). Read its current `statusLine` value, if any.

**Detect the current mode from the wired command's path:** it references `forge-statusline-wrapper.sh` → **method 1** already wired; it references `forge-statusline-full` → **method 2** already wired; anything else → a non-forge (third-party) command; nothing → no statusLine. Branch on that:

- **No existing `statusLine`** → install **method 2** automatically (no third-party base to preserve): wire the **`STATUSLINE_CMD` resolved above** by **absolute path** (the unified script reads cwd from the session JSON on stdin, so it works as the sole command):
  ```json
  "statusLine": { "type": "command", "command": "<STATUSLINE_CMD>" }
  ```
  (`<STATUSLINE_CMD>` = `<CFG>/forge-statusline-full.sh` on Unix, else `node <CFG>/forge-statusline-full.js`; `<CFG>` absolute, e.g. `/Users/you/.claude/...`.) Confirm the one-line change with the user, then write it.

- **An existing non-forge `statusLine.command`** → **ask the user which mode** (method 1 append vs method 2 merge) via `AskUserQuestion`, unless the host is **Windows** (offer method 2 only — the wrapper is bash-only; if they decline, stop without clobbering). Then:
  - **Method 1 (append)** → the auto-wrap case (step 3a). Preserve the original into the wrapper's orig file.
  - **Method 2 (merge)** → replace the command with `<STATUSLINE_CMD>`, but first **preserve the original** for restore (step 3b).

- **An existing forge wrapper** (command references `forge-statusline-wrapper.sh`) → **method 1 already wired**. Do **not** wrap again (guard against double-wrapping). Step 1 already refreshed the scripts; if the command still uses a `~` path, rewrite it to the absolute path (the one fix worth applying). Report it's up to date (offer switching to method 2 only if the user asks) and stop.

- **An existing forge unified script** (command references `forge-statusline-full`) → **method 2 already wired**. Step 1 already refreshed the scripts; fix a `~` path to absolute if needed, and on Unix↔Windows drift correct the `.sh`/`node .js` form to match the host. Report it's up to date and stop.

### 3a. Method 1 — auto-wrap the existing statusLine

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

### 3b. Method 2 — install the unified script (preserve any original)

The unified script is already installed (step 1). Wiring method 2 is a single settings write, plus a restore safeguard when it displaces an existing command:

1. **If method 2 is replacing an existing (non-forge) statusLine, preserve the original first** — write the displaced `statusLine.command` verbatim into `<CFG>/forge-statusline-orig.sh` (same file/format as method 1's preservation, sidestepping quote-escaping), so the user can restore it. When method 2 is installed with no prior statusLine, there is nothing to preserve — skip this.
2. **Point settings.json at the unified script, by absolute path:**
   ```json
   "statusLine": { "type": "command", "command": "<STATUSLINE_CMD>" }
   ```
   (`<STATUSLINE_CMD>` = `<CFG>/forge-statusline-full.sh` on Unix, else `node <CFG>/forge-statusline-full.js`.)

**Before writing**, show the user the before → after of `statusLine.command` (and, if displacing one, the preserved original) and get explicit confirmation — this replaces their statusLine. Preserve all other settings keys and keep the JSON valid. Because method 2 is destructive to an existing statusLine, always state the restore path (set `statusLine.command` back to what's in `<CFG>/forge-statusline-orig.sh`).

Procedure flow:

```
copy fragment(.sh+.js) + wrapper + full(.sh+.js) + resolve-forge-root.js → <CFG>/  (chmod +x, absolute)  [refresh: re-copy all]
   ↓
resolve STATUSLINE_CMD (merge cmd) once by HOST OS (uname -s):  Unix → <CFG>/forge-statusline-full.sh  ·  Windows → node <CFG>/forge-statusline-full.js
   ↓
locate settings.json + read existing statusLine → detect mode by command path
   ├── none                → method 2: command = <STATUSLINE_CMD> (absolute)   (confirm, write)
   ├── forge-wrapper       → method 1 already wired; refreshed in step 1; fix ~→absolute if needed; report & stop
   ├── forge-full          → method 2 already wired; refreshed in step 1; fix ~→absolute / OS .sh↔node .js if needed; report & stop
   └── other (third-party) → ask mode 1|2  (Windows: method 2 only; decline → stop, don't clobber)
                              ├── method 1 → write original verbatim → <CFG>/forge-statusline-orig.sh
                              │              → confirm → command = <CFG>/forge-statusline-wrapper.sh
                              └── method 2 → preserve original → <CFG>/forge-statusline-orig.sh
                                             → confirm → command = <STATUSLINE_CMD>  (state restore path)
```

## Notes & assumptions

- **cwd resolution.** The fragment resolves the project directory from the session JSON's `cwd` (then `workspace.current_dir`, then `$PWD`) and `cd`s there before reading `.forge/`, so it shows the right project even when the host runs the statusLine from a different directory. In the wrapper case, the wrapper feeds the same JSON to the fragment on stdin so this resolution still applies. It stays jq-free (defensive `sed` extraction) — the one place the fragment parses JSON.
- **Refresh on update.** Because the scripts are copied (not referenced in place), a forge plugin update does not change the installed copies automatically — re-run `fg-statusline` to refresh **all** of them: the fragment `forge-statusline.sh`/`.js`, the method-1 `forge-statusline-wrapper.sh`, the method-2 `forge-statusline-full.sh`/`.js`, and `resolve-forge-root.js` (the full step-1 copy list). Refresh copies the whole list regardless of the active mode, and re-running detects and silently refreshes whichever mode is wired (a mode switch is asked once). They rarely change, so this is infrequent.
- **Takes effect on restart.** Claude Code loads the `statusLine` config at session start — after setup, fully quit and relaunch Claude Code before judging whether it works. A `~`-path command that silently failed is the classic "nothing shows" cause; this setup writes absolute paths to avoid it.
- **Trust & disabling.** statusLine runs only in a trusted workspace and is suppressed if `disableAllHooks` is set — that is host behavior, not forge's.

## Handoff

State in one line what was done — which **mode** (method 1 append / method 2 merge), and whether it was installed / refreshed / already-wired — and that it takes effect **after a full Claude Code restart** (the config loads at session start). There is no loop next-step — fg-statusline is a side utility. When an original statusLine was preserved (method 1's wrap, or method 2 displacing an existing one), mention how to restore it (set `statusLine.command` back to the command preserved in `<CFG>/forge-statusline-orig.sh`), and that re-running refreshes the scripts (and can switch modes).

## Document impact

- Writes **outside** the forge state tree, under the Claude config dir (`<CFG>` = `$CLAUDE_CONFIG_DIR` or `~/.claude`): the fragment `<CFG>/forge-statusline.sh` + `.js`, the method-1 wrapper `<CFG>/forge-statusline-wrapper.sh`, the method-2 unified script `<CFG>/forge-statusline-full.sh` + `.js`, and `<CFG>/resolve-forge-root.js` — all copied; when an original statusLine is preserved (method 1's wrap, or method 2 displacing one), `<CFG>/forge-statusline-orig.sh` (the preserved original command); and the `statusLine` key (an **absolute-path** command — the wrapper for method 1, `STATUSLINE_CMD` for method 2) in the chosen `settings.json`. It touches **no** `.forge/` loop state (active slot, backlog, executed, done) and writes nothing git-tracked in the project.
