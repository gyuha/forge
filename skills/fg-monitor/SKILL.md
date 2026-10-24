---
name: fg-monitor
description: "Read-only live web dashboard for the current project, branch, and Claude Code session, including main and subagent observations. Outside the loop. fg-monitor on starts; fg-monitor off stops; on --host 0.0.0.0 explicitly allows network access. First launch asks whether to delete or keep activity summaries and saves monitorRetention; change later with fg-config. Requires Node 22+ and Claude Code. Use for 'forge monitor', '모니터링', '대시보드', '작업 상태 화면'."
---

# fg-monitor — current-session dashboard (outside the loop)

**Language**: Write every user-facing message and question in the user's language.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Evidence and candor**: every claim you make about code, state, or results — in a message or in a document you write (plan, run notes, retro, ADR) — carries its evidence in the same sentence (a `file:line`, a command and its output) or a label: **Measured** (you checked it this session), **Inferred** (reasoned from what you checked), **Guess** (a prediction or an unseen cause), rendered in the user's language. A label is not a license to skip a check — if a cheap check would settle it, run it; never hand the user a check you could run. Agreement is not the default: when asked whether to do something, invited to add scope, or shown an approach, give your real judgment first — the strongest objection, and "don't do it" when that is true. Change a recommendation only for a new fact or argument, never for repetition; the decision stays the user's — state the objection once, then follow their call without re-arguing or silently deviating. Output a deterministic script printed is already measured and needs no label.

**Host contract**: Read [../../core/HOST.md](../../core/HOST.md) and the active host adapter before execution. The first-launch question uses `structured_choice`, falling back to a numbered text question. This version collects live sessions only in Claude Code. On Codex, opencode, Pi, or an unknown host, explain that live collection and automatic shutdown are unsupported and stop; do not fabricate Claude identity or present another host as supported.

**Forge root**: Read [../fg-run/FORGE-ROOT.md](../fg-run/FORGE-ROOT.md). Task state follows the resolved branch root. `.forge/config.json` and runtime `.forge/monitor/` always remain at the project top level. The monitor fixes the actual project path, branch, forge root and session when started.

## Execute

Resolve the installed plugin root through HOST.md (including the loaded skill path fallback); verify `scripts/forge-monitor.js` exists. Keep cwd at the user's project. Require Node 22+ and the actual inherited `CLAUDE_CODE_SESSION_ID` and live `CLAUDE_PID`; never supply a guessed parent shell PID, a stale session ID, or another session's identity. Missing ownership is an error, not a reason to claim automatic cleanup. Hooks load at session start: after installing or updating this plugin, begin a fresh Claude session. Exec-form hooks were observed on Claude Code 2.1.303; older Claude versions have not been verified.

Run Node directly, with the absolute installed script path and separate arguments (no bash or PowerShell requirement):

- `node <plugin>/scripts/forge-monitor.js on` — default loopback `127.0.0.1`, available port.
- `node <plugin>/scripts/forge-monitor.js on --host 0.0.0.0` — explicitly requested external access only.
- An optional `--port N` selects a port; an occupied port reports an error.
- `node <plugin>/scripts/forge-monitor.js off` — only this caller's monitor, idempotent.

Read the JSON result. On `needs-configuration`, ask **once**: delete this session's observation records when it ends, or keep activity summaries for later viewing? Do not choose for the user. On their answer run `node <plugin>/scripts/forge-monitor.js config delete` or `config keep`, then retry the same `on` arguments. This preserves other `.forge/config.json` keys. Existing valid `monitorRetention` is reused without asking. Invalid JSON must be repaired explicitly, never overwritten or silently treated as delete.

On `started` or `already-running`, return the actual `url`/`urls` with access key intact. Never present `0.0.0.0` as a destination. Open the returned local URL with the host's browser-opening facility when available, best-effort; failure to open does not invalidate the URL. Do not open a different browser or change binding merely because no local opener is available. Repeat on reuses the existing server; if requested binding differs, report the error and give `off` then the requested `on` sequence instead of silently ignoring it. On `stopped`/already stopped, state the result. Report nonzero errors honestly; do not declare a server started without a returned URL.

## Settings, observations and shutdown

`/fg-config monitorRetention delete|keep` changes the project default for the **next launch** only. The running server keeps its launch policy; changing keep to delete never bulk-deletes earlier archives. Retained summaries appear under monitor history for the same project and branch, separate from live state. Browser views are read-only: no execute, cancel, configuration or delete action.

The A layout has a top stage flow, project/view navigation, and task/agent panels. Agent activity is evidence, not task verification: a tool error is not terminal agent failure, and missing observations appear as unknown. Full prompts, conversations and tool input/output are not collected for display.

`Stop` means a turn ended and leaves the monitor alive. `SessionEnd` requests shutdown; owner-process death is checked as a fallback. Idle but live Claude remains monitored. `/clear` ends the old session's monitor; the new identity is not automatically attached and needs its own `on`. Normal session end targets 2 seconds; process death targets 10 seconds. Do not claim those guarantees on a host whose identity cannot be verified.

Shutdown removes temporary credentials/PIDs for either retention policy. Delete removes this run's summaries only; keep retains summaries, never existing forge plan/run/done state. `.forge/monitor/` is self-ignored, session-isolated runtime data. No handoff table or loop transition: report the URL or shutdown result and stop. `fg-showme` remains a separate design companion with a separate lifetime.
