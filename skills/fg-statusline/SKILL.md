---
name: fg-statusline
description: Set up (or refresh) a Claude Code statusline showing forge's loop progress, in one of two modes — method 1 (append) wraps your existing statusLine as extra rows (original preserved); method 2 (merge) installs a forge-owned unified script with daleseo-style system info (model/dir/git/context/usage bars) + forge progress, with a compact/full density toggle. On-demand setup utility outside the loop. Use in contexts like 'forge statusline', 'statusline 설정', '상태바', '상태 표시줄', 'add forge to statusline'.
---

# fg-statusline — set up the forge progress statusline (outside the loop)

**Codex capability**: persistent statusline installation is not supported by this adapter. On Codex, do not edit settings; explain the limitation and direct the user to `$fg-status`. The remaining instructions apply only to Claude Code.

This is **not** a stage of the forge loop. It is a one-time setup utility: it installs forge's statusline scripts to a stable location and wires one into your Claude Code `settings.json`, so your terminal statusline shows where the forge loop currently stands. Re-run it any time to refresh the installed scripts after a forge update.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, confirmations, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.**

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

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
- **Plugin install paths change on every update** (`~/.claude/plugins/cache/<hash>/`), and `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}` is **not** available to the statusLine shell. So the scripts must be **copied to stable paths** the settings can reference under the Claude config dir (`~/.claude/` by default). The fragment reads the current project's `.forge/` (from the session JSON's `cwd`, see below), so one global copy serves every project.
- **Reference the scripts by ABSOLUTE path in `settings.json`, never `~`.** The statusLine `command` is not guaranteed to undergo tilde expansion by the host, so a literal `~/.claude/...` can fail to resolve and silently blank the **entire** statusline (including any wrapped original). Resolve `$HOME` (or `$CLAUDE_CONFIG_DIR`) at setup time and write the full absolute path. This matches what working statuslines (claude-hud, powerline scripts) already do. See ADR-0017.

## What the fragment prints (the forge line(s), both modes)

This is the forge fragment's own output. In **method 1** these are the rows appended below your wrapped original statusline. In **method 2** the merge script reuses this exact output verbatim as its forge line(s), default `⚒ ` prefix included (the `FORGE_SL_PREFIX` env var can still override the line-1 prefix, but the merge script no longer sets it).

The script reads the session JSON on stdin and resolves the project directory from its `cwd` (falling back to `workspace.current_dir`, then to `$PWD` when no JSON/cwd is piped — e.g. an interactive run), `cd`s there, and prints **up to two lines**, or nothing when idle. Resolving cwd from stdin (rather than assuming the shell's cwd is the project) is why it shows the right project even when the host runs the statusLine from elsewhere. Unlike the single-segment precedence design this replaced (ADR-0017's original mechanism — see its 2026-07-02 amendment), the two lines are **independent** — both show whenever they apply, neither hides the other:

Segments are grouped into bracketed semantic units `[ ... ]`; groups are joined by a single space, segments **inside** a group by ` <SEP> ` (SEP = `FORGE_SL_SEP`, default `·`; the merge script passes `|`). Brackets/separators are dim; the pipeline arrows `→` are not a separator. Empty groups are omitted. Output shape depends on `FORGE_SL_DENSITY` (`full` default, or `compact` when the merge script's compact mode passes it):

```
full density — up to two lines:
  Line 1: [🔁 rN/cap] [⚒ [#N ]<slug> · ✔ ask → ● run → ○ learn → ○ done[ · <flag>]]
          (the loop group appears only under a goal loop; the flag part only when run.md exists)
  Line 1 (ask.md, no active slot): [⚒ <working-slug> · ● ask → ○ run → ○ learn → ○ done]
  Line 1 (loop only, no slot/ask): [🔁 rN/cap]
  Line 2 (activity present): [📋 N queued · 📝 M awaiting retro[ · ♻️][ · 🧪]]
          (each part omitted when absent; the whole group omitted when idle)

compact density — a single line, forge + queue-count + modes folded into one group:
  [🔁 rN/cap] [⚒ [#N ]<slug> · ✔ ask → ● run → ○ learn → ○ done[ · <flag>][ · 📋 N][ · ♻️][ · 🧪]]

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
- **flag** (present whenever `run.md` exists, regardless of whether `run` or `learn` is the current stage) — `✓` verified yes · `⏳` verification pending · `✗` verified failed · (omitted) for `skipped`/`n/a`. It sits at the **end of the forge group** (`[⚒ #N slug · <pipeline> · <flag>]`), joined by the SEP. The `ask.md`-only forge group never carries a flag.
- **🧪 ♻️ mode indicators** — `🧪` lights when the active plan carries `<!-- tdd: on -->`; `♻️` lights when the **top-level** `.forge/config.json` has `"eco": true` (the branch-independent global exception — the same key fg-config writes; this script only reads it). Only the lit ones show. Placement is density-dependent (they replaced the earlier `Ⓣ`/`Ⓔ` circled-letters, ADR-0029): in **full** density they sit in the **line-2 queue group** (`[📋 N queued · 📝 M awaiting retro · ♻️ · 🧪]`); in **compact** they fold into the single forge group. They render **only alongside real activity** (an active task or a non-empty queue) — never on the `🔁`-only fallback or a fully idle repo, so "nothing when idle" holds. `🧪` requires an active plan, so it can never appear at the `ask.md` stage; `♻️` can (with activity).
- **🔁 rN/cap** — present whenever `loop.md` exists (an fg-loop goal drive is in flight), showing its replan round / cap, rendered as a **leading `[🔁 rN/cap]` group** before the forge group (both densities); shown as its own group alone when there is no active slot and no `ask.md`.
- Every rendered unit is a bracketed group; the `⚒ ` prefix lives inside the forge group's first segment (both lines/densities carry groups, not a bare prefix).
- It resolves the branch-isolated forge root (ADR-0011): `.forge/` on the default branch, `.forge/branch/<branch>/` otherwise.

The first three stage **names** (`ask`/`run`/`learn`) match `skills/fg-status/SKILL.md`'s task table bucket→stage mapping (backlog → ask, active plan-only → run, run.md present/`executed/` → learn), and as of the 2026-07-03 amendment this script's plan-only case now matches that mapping exactly (both read plan.md-with-no-run.md as `run`). One divergence remains, from the 2026-07-02 2nd amendment: fg-status's Stage column is purely file-existence-based for `run.md` (any `run.md` present → `learn`, full stop), while this fragment additionally reads `STATUS.md` `verified:` to decide whether `run` or `learn` is truly current (see above) — a `verified: failed`/`pending` task shows `run` as current here even though fg-status's table would still label its bucket `learn`. This is a deliberate refinement, not a bug: fg-status answers "which bucket is this task in," this fragment answers "where is a human's attention actually needed right now," and the two questions diverge exactly when a bucket's gate hasn't cleared yet. `done` is a fourth, decorative-only stage appended for the visual — it has no corresponding bucket in fg-status's table (a sealed task leaves the tracked buckets entirely) and never becomes the current (`●`) stage in this script. The `ask.md`-only line 1 has no counterpart in fg-status's table either — fg-status never reports on grilling-in-progress (there is no file for it to read until `backlog/` gets a row), so this is fg-statusline-only display state. If the `ask`/`run`/`learn` bucket **names** ever change, update both the script and fg-status together; the verified-gating refinement and the ask.md display case are local to this script.

## What the merge-mode script prints (method 2 only)

`forge-statusline-full.sh`/`.js` render a daleseo-style dashboard plus the forge line(s), reading everything from the session JSON on stdin (`used_percentage` appears in three places and `resets_at` in two, so the bash twin extracts each leaf from its **parent** object — never a first-match grab; the node twin uses `JSON.parse`). Method 2 always uses `|` as the intra-group separator (and passes `FORGE_SL_SEP=|` to the delegated fragment). **Density is the positional arg** (`$1`/`argv[2]`): `full` (default — 4 lines) or `compact` (2 lines); an unrecognized/absent value falls back to `full`. Every group/field renders only when present (graceful omission):

```
full density (4 lines):
  Line 1: [<model> | <effort>] [<dir> | ⎇ <branch [↑N ↓N] [+s !m ?u]>] [⏱ (D) | $X.XX | +A −R]
  Line 2: [<emoji> Context[/<size>] <bar> N% | 5h <bar> N% (~H) | 7d <bar> N% (~H)]
  Line 3: [⚒ [#N ]<slug> | <pipeline>[ | <flag>]]                    (delegated to the fragment)
  Line 4: [📋 N queued | 📝 M awaiting retro[ | ♻️][ | 🧪]]           (delegated to the fragment)

compact density (2 lines): system groups + the usage-bars group on ONE line, then the
fragment's single compact group; the session group (⏱/$/±lines) is dropped.
  Line 1: [<model> | <effort>] [<dir> | ⎇ …] [<emoji> Context[/<size>] <bar> N% | 5h … | 7d …]
  Line 2: [⚒ [#N ]<slug> | <pipeline>[ | <flag>][ | 📋 N][ | ♻️][ | 🧪]]
```

- **Line 1 (system) — two/three groups:** the **identity group** `[<model> | <effort>]` (`model.display_name` magenta, `effort.level` omitted on models without one — the group vanishes if both absent); the **location group** `[<dir> | ⎇ <branch …>]` (working-dir basename, plus — inside a git repo — the branch cyan as `⎇ <branch>` with `↑N`/`↓N` ahead/behind vs upstream placed before the `+N`/`!N`/`?N` staged/modified/untracked counts, each omitted when zero, the `↑↓` pair omitted with no upstream); and — **full density only** — the **session group** `[⏱ (D) | $X.XX | +A −R]` (`⏱` = `cost.total_duration_ms`→s humanized; `$` = `cost.total_cost_usd` yellow; `+A −R` = `cost.total_lines_added/removed` green/red, omitted when both 0), each part omitted when its source is absent, the group omitted when empty.
- **Line 2 (usage-bars group):** a dynamic emoji (`🟢`<20 · `⚡`20–69 · `🔥`70–89 · `🚨`≥90) prefixes `Context`; `context_window.context_window_size` attaches as `/1M` or `/NK` (omitted when absent). Three 10-cell bars (`█`/`░`) with a per-cell truecolor **gradient** (green→yellow→red), labeled `Context` / `5h` / `7d`. `used_percentage` null → `0`; the two `rate_limits` windows are Pro/Max-only (each may be absent → that segment omitted). `resets_at` (Unix epoch s) humanizes to `(~Xm)` / `(~Xh Ym)` / `(~Xd Yh)`. Bar fill = `round(pct/10)`; colors live-tuned and stripped in tests (ADR-0017; bar length + `%` carry the info).
- **Forge groups (delegated):** the fragment's output verbatim, invoked with `FORGE_SL_SEP=|` and `FORGE_SL_DENSITY=<the resolved density>` (default `⚒ ` prefix — no `FORGE_SL_PREFIX` override). In full density that is Line 3 (forge group) + Line 4 (queue+modes group); in compact it is the fragment's single folded group as Line 2. When forge is **idle** the fragment emits nothing, so those lines vanish but the system/usage groups stay. All stage-gating, flags, `🧪`/`♻️` indicators, loop indicator, and branch-root resolution are exactly as documented in the fragment section above — because they *are* the fragment.

Both twins emit identical output (ANSI stripped), guarded by `scripts/forge-statusline-full.parity.test.sh`; behavior is pinned by `scripts/forge-statusline-full.test.sh`. Time is injectable via `FORGE_SL_NOW` (epoch s) so humanization is testable.

## Setup procedure

Run these steps in conversation (the skill runs in the main session, so it can read files, show diffs, and ask for confirmation). The script sources live under `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/` — the fragment (`forge-statusline.sh`/`.js`), the method-1 wrapper (`forge-statusline-wrapper.sh`), and the method-2 unified script (`forge-statusline-full.sh`/`.js`) — all available here, in the skill context, *not* in the statusLine shell later. Let `CFG` be the Claude config dir (`$CLAUDE_CONFIG_DIR` if set, else `$HOME/.claude`); resolve it to an **absolute path** now, because every `settings.json` reference must be absolute (no `~`).

**Mandatory read-only preflight before any copy or chmod:** perform step 2 first — locate settings, read the existing command, detect the current mode/OS drift, and **read the existing `statusLine` before choosing density**. Decide whether this is a refresh, a mode switch, or a new install; obtain any confirmation the path requires. Only then perform step 1's writes and the final settings write. This prevents a declined install from overwriting stable scripts, and it is the only way a refresh can preserve the density already stored in the command.

### 1. Install the scripts to stable paths

Copy all of these and `chmod +x` them (idempotent — a **refresh** after a forge update is just re-running this; copy the whole list regardless of the chosen mode, so a later mode switch needs no extra copy):

- `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/forge-statusline.sh` → `<CFG>/forge-statusline.sh` (the fragment, both modes)
- `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/forge-statusline-wrapper.sh` → `<CFG>/forge-statusline-wrapper.sh` (method 1)
- `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/forge-statusline-full.sh` → `<CFG>/forge-statusline-full.sh` (method 2, the unified script)
- `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/forge-statusline.js` → `<CFG>/forge-statusline.js`, `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/forge-statusline-full.js` → `<CFG>/forge-statusline-full.js`, **and** `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/resolve-forge-root.js` → `<CFG>/resolve-forge-root.js` — the node fallbacks (ADR-0022) and the resolver they `require` (must sit next to them). Needed for the Windows / no-bash path below; harmless to always copy.

All the `.sh`/`.js` are generic (no per-install substitution) — the wrapper finds the fragment and the preserved original, and the unified script finds the fragment, **in their own install directory**, resolved at runtime from each script's own path (`BASH_SOURCE` / `__dirname`), **not** from `$CLAUDE_CONFIG_DIR`. The statusLine process may not export that env var, and depending on it would silently blank the whole statusline in a custom config-dir setup (ADR-0017). Since every companion is copied into `CFG` together, one global copy of each serves every project.

#### Cross-platform: resolving the wired command (node fallback — ADR-0022)

Both the fragment and the unified script ship in two forms — `.sh` (bash, primary) and `.js` (node, identical output, guarded by the parity tests). Only the **method-2** command varies by OS; **method 1's** command is always the wrapper (`<CFG>/forge-statusline-wrapper.sh`), which is bash-only.

**Resolve `STATUSLINE_CMD` (the method-2 / merge command) ONCE here, then use that single value wherever method 2 is wired/refreshed below** — do NOT hardcode `.sh` in the later steps (a sequential reader would otherwise install an unrunnable bash command on a no-bash host and re-installing would just repeat the same broken wiring).

**Decide by the HOST OS the statusLine will run under — NOT by whether bash is on this install session's PATH.** The skill runs via the Bash tool, which *always* has bash, so a PATH probe here would pick `.sh` on every platform and the Windows node fallback would never be selected (ADR-0022 review). The statusLine command runs later in the host's *system shell* (on Windows: cmd/PowerShell — which may lack bash entirely or have PowerShell blocked), a different environment from this install session. So detect the OS (`uname -s`: `Darwin`/`Linux` → Unix; `MINGW*`/`MSYS*`/`CYGWIN*`, or no `uname` with a Windows environment → Windows):

- **Unix (Darwin / Linux, incl. WSL)** → `STATUSLINE_CMD = <CFG>/forge-statusline-full.sh`
- **Windows** → `STATUSLINE_CMD = node <CFG>/forge-statusline-full.js` — node always runs on Windows and dodges a blocked/absent PowerShell; do **not** assume the Windows system shell has bash even when Git Bash exists for the Bash tool. (`<CFG>/forge-statusline.js` + `<CFG>/resolve-forge-root.js` must sit beside it — see the copy list.)

**Density (method 2 only): decide after the settings preflight, then append it to `STATUSLINE_CMD`.** Method 2 renders in `full` (4 lines — system + session / usage bars / forge / queue) or `compact` (2 lines — system + bars on one line, forge folded into a single group; the session group is dropped). For a new method-2 install or an explicit switch into method 2, ask once (default **`full`** — no arg); append the positional arg only for `compact`: `STATUSLINE_CMD = <CFG>/forge-statusline-full.sh compact` (Unix) / `node <CFG>/forge-statusline-full.js compact` (Windows). For an existing forge-full refresh, parse and preserve the current arg without asking or silently flipping it; re-ask only when the user requests a density change. Density is stored in the wired command itself — **no new `config.json` key** (ADR-0029). Method 1 has no density (the wrapper always appends the fragment's full-density output).

State the detected OS, the chosen density, and the resulting `STATUSLINE_CMD` to the user when you wire it, so the choice is auditable.

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

- **An existing forge wrapper** (command references `forge-statusline-wrapper.sh`) → **method 1 already wired**. Do **not** wrap again (guard against double-wrapping). On Unix, refresh after the preflight; if the command still uses a `~` path, rewrite it to the absolute path (the one settings fix worth applying), report it up to date, and stop. **An existing wrapper on Windows is OS drift, not a valid refresh**: method 1 is bash-only, so offer a two-choice decision — switch to method 2 (preserving the original for restore), or keep the existing wiring and stop without copying/rewriting. Never silently report the wrapper as working on Windows.

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
READ-ONLY preflight: locate settings.json + read existing statusLine → detect mode, density, and HOST OS drift
   ↓
confirm new install / mode switch where required (decline → no copies, no settings write)
   ↓
copy fragment(.sh+.js) + wrapper + full(.sh+.js) + resolve-forge-root.js → <CFG>/  (chmod +x, absolute)  [refresh: re-copy all]
   ↓
resolve STATUSLINE_CMD by HOST OS + preserved/chosen density: Unix → <CFG>/forge-statusline-full.sh [compact] · Windows → node <CFG>/forge-statusline-full.js [compact]
   ↓
apply the detected-mode branch
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
