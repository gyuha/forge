---
name: fg-showme
description: Opens a browser-based visual companion in any conversation — a local zero-dependency server shows mockups, diagrams, and visual A/B options you push as HTML, and takes the user's answers back as events: a click settles a choice, a screen can carry a text box, and a confirmed choice wakes you with no terminal turn. `fg-showme stop` shuts it down. fg-ask offers it just-in-time during grilling (this skill is the standalone entry). On-demand utility outside the loop. Use in contexts like 'forge showme', 'forge visual', 'visual companion', '시각적으로 보여줘', '목업 보여줘', '브라우저로 보여줘', '화면으로 비교해줘'.
---

# fg-showme — visual companion (outside the loop)

This is **not** a stage of the forge loop. It is an on-demand utility that opens a **browser tab next to the conversation** for content that is better *seen* than read — UI mockups, layout comparisons, architecture diagrams — and takes the user's answers back as structured events — a click settles a choice question, and a screen may carry a text input (ADR `260730-224259`). It is a display surface **and a secondary answer channel**: read both channels and merge them, asking one line only when they genuinely contradict. A **confirmed** selection can now wake you directly, no terminal turn required (the wake watch, armed at session start — ADR `260805-005436`); an unconfirmed, exploratory click still wakes nothing. Pillar #1 stays intact either way — not because only the terminal can resume you, but because the browser is never a runtime input to a Dynamic Workflow, and grilling stays a one-question-at-a-time conversation outside any workflow regardless of what wakes it.

The engine is vendored from obra/superpowers v6.1.1 and re-checked against **v6.3.0** — the five engine files differ only by forge's own modifications, and upstream shipped no visual-companion change in v6.2.0 or v6.3.0, so there is nothing to port (MIT, Copyright (c) 2025 Jesse Vincent — see [LICENSE](./LICENSE)): a zero-dependency Node server (`scripts/server.cjs`) with session-key auth, path sandboxing, restart/reconnect survival, and a 4-hour idle shutdown. forge modifications: session files under `.forge/showme/`, superpowers branding/telemetry removed (the server makes no remote requests). Rationale and alternatives: ADR `260719-224442-vendor-superpowers-visual-companion`.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — status lines, URLs, prompts, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** Screen content (HTML you push) is also written in the user's language.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

## What it does

- **`fg-showme` (no argument)** → start a companion session for this conversation: read [`VISUAL.md`](./VISUAL.md) (the full operating guide — when to use the browser vs the terminal, screen authoring, the event loop), start the server, **arm the wake watch** (a persistent `Monitor` on the events file, so a confirmed click can wake you with no terminal turn), and share the keyed URL. Then push screens as the conversation calls for them.
- **`fg-showme stop`** → stop the running session's server **and its wake watch** (`TaskStop`) — the session directory is deleted with it, and when the last session goes, the whole `.forge/showme/` goes too (nothing left to review or commit; copy a mockup out first if the user wants to keep it).

```
fg-showme (no arg)
   → read VISUAL.md
   → scripts/start-server.sh --project-dir <repo root> --open
   → arm the wake watch (Monitor, persistent)
   → share the full keyed URL
   → loop: push screen → user looks/clicks/confirms → confirmed click (or submitted text) wakes you, or read state_dir/events + terminal reply
fg-showme stop
   → find the session under .forge/showme/ (state/server-info present, no server-stopped)
   → scripts/stop-server.sh <session_dir>
   → TaskStop the wake watch
```

## Behavior

1. **Read [`VISUAL.md`](./VISUAL.md) before the first screen.** It is the single operating guide (progressive disclosure — loaded only when the companion actually runs): the browser-vs-terminal test, session start/restart, fragment authoring, CSS classes, the events format, the waiting-screen unload, and cleanup. Follow it; do not improvise a parallel workflow here.
2. **Start with `--project-dir` = the repo root and `--open`.** Sessions land under the **top-level `.forge/showme/<session>/`** — a deliberate global location on every branch (like `.forge/config.json` / `.forge/codebase/`, never the branch root: a branch root is git-tracked whole, and mockup HTML must not end up in commits). It is volatile display state with **no path into git in any project**: `start-server.sh` writes a self-ignoring `.forge/showme/.gitignore` (a single `*`) on first use, so session artifacts stay out of the user's git even where forge's own `.gitignore` policy doesn't exist — forge never edits the user's own `.gitignore`; this self-ignore inside forge's state directory is the one exception (ADR `260719-224442`, amended 2026-09-02). The same start also sweeps dead sessions (stopped marker or dead PID) left by a crash or the idle timeout — live concurrent sessions and `.last-*` are untouched.
3. **Arm the wake watch right after the server starts, and put a confirm button on every choice screen.** A persistent `Monitor` watches the events file for a confirmed selection or a submitted text event only — an exploratory click never matches, so browsing alone never wakes you (VISUAL.md's Starting a Session and Confirm button sections have the exact command and markup; do not restate them here). If `Monitor` is unavailable, skip the watch and fall back to the pre-watch behavior.
4. **Per-screen judgment still applies, in both directions.** Having the companion open does not mean every exchange goes through it — use the browser when the content itself is visual, **or when a structural explanation (branching flow, state transitions, a multi-axis comparison) outgrows a text flow diagram**; if `A -> B -> C` carries it, stay in the terminal (the test in VISUAL.md). Push a waiting screen when the conversation returns to the terminal.
5. **Stop when the visual discussion is done** — on `fg-showme stop` (which also stops the wake watch), or proactively when the session's purpose is served. Stopping deletes the session directory (and, when it was the last one, all of `.forge/showme/`). The 4-hour idle timeout is the backstop for forgotten servers, not the normal exit — a directory it leaves behind is swept at the next start.

## Relationship to fg-ask (the main consumer)

fg-ask offers the companion **automatically, just-in-time** during grilling — the first time a question would be clearer shown than told — and drives it by reading this directory's files directly (`VISUAL.md`, `scripts/`); it does **not** invoke this skill (the same file-reference pattern as `fg-eco/ECO.md` and `fg-run/FORGE-ROOT.md`). Within fg-ask, the server stops at Output time (plan written → companion's job done). The offer discipline lives in fg-ask's Forge integration section; this skill is the **standalone** entry for every other conversation.

## Constraints

- **The keyed URL is the whole access model.** Always hand the user the complete `url` from the server JSON, `?key=` included — a bare `host:port` gets a 403 by design.
- **This skill writes no loop state** — it never touches the active slot, backlog, executed, done, or the permanent docs. Its only writes are session files under `.forge/showme/` (or `/tmp` without `--project-dir`).
- The vendored `scripts/` keep their upstream **form** — bash launcher, node server, and deliberately outside forge's bash+node twin convention for mechanical scripts (ADR-0022); see the vendoring ADR. They are **not kept byte-for-byte with upstream**: forge adjusted branding and theme at vendoring time (remote logo and telemetry removed — ADR `260719-224442` §1) and again when the frame was rethemed to the repo-root `DESIGN.md` palette. Each file's header records its own modifications, so upstream tracking stays a readable diff rather than a byte comparison. The confirm button is an inline `onclick` handler in the screen HTML you push, never a vendored-file edit.
- **`Monitor` is optional, never a hard dependency.** If it's unavailable, the companion runs exactly as before — no wake watch, the user presses 확정 (or submits an Ask input) and still sends a terminal turn to resume you. Same graceful pattern as a missing `fg-map`/eco/tdd.

## Document impact

- Creates `.forge/showme/<session>/{content,state}/` session files plus a self-ignoring `.forge/showme/.gitignore` (volatile, structurally kept out of the user's git; top-level on every branch). All of it is deleted again on stop — the session directory, and the whole `.forge/showme/` once the last session goes; dead sessions a crash or the idle timeout leaves are swept at the next start. The wake watch is a background `Monitor` task, not a file — it leaves nothing on disk and is stopped with `TaskStop` alongside the server. Nothing else.
