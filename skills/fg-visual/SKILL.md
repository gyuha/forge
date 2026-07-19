---
name: fg-visual
description: Opens a browser-based visual companion in any conversation — a local zero-dependency server shows mockups, diagrams, and visual A/B options you push as HTML, and records the user's clicks as events you read back; `fg-visual stop` shuts it down. During fg-ask grilling the companion is offered automatically just-in-time (this skill is the standalone entry point). On-demand utility outside the loop. Use in contexts like 'forge visual', 'visual companion', '시각적으로 보여줘', '목업 보여줘', '브라우저로 보여줘', '화면으로 비교해줘'.
---

# fg-visual — visual companion (outside the loop)

This is **not** a stage of the forge loop. It is an on-demand utility that opens a **browser tab next to the conversation** for content that is better *seen* than read — UI mockups, layout comparisons, architecture diagrams — and collects the user's clicks as structured events. The answer channel stays the terminal conversation; the browser only *shows*.

The engine is vendored from obra/superpowers v6.1.1 (MIT, Copyright (c) 2025 Jesse Vincent — see [LICENSE](./LICENSE)): a zero-dependency Node server (`scripts/server.cjs`) with session-key auth, path sandboxing, restart/reconnect survival, and a 4-hour idle shutdown. forge modifications: session files under `.forge/visual/`, superpowers branding/telemetry removed (the server makes no remote requests). Rationale and alternatives: ADR `260719-224442-vendor-superpowers-visual-companion`.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — status lines, URLs, prompts, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** Screen content (HTML you push) is also written in the user's language.

## What it does

- **`fg-visual` (no argument)** → start a companion session for this conversation: read [`VISUAL.md`](./VISUAL.md) (the full operating guide — when to use the browser vs the terminal, screen authoring, the event loop), start the server, and share the keyed URL. Then push screens as the conversation calls for them.
- **`fg-visual stop`** → stop the running session's server (mockups persist in `.forge/visual/` for later reference).

```
fg-visual (no arg)
   → read VISUAL.md
   → scripts/start-server.sh --project-dir <repo root> --open
   → share the full keyed URL
   → loop: push screen → user looks/clicks → read state_dir/events + terminal reply
fg-visual stop
   → find the session under .forge/visual/ (state/server-info present, no server-stopped)
   → scripts/stop-server.sh <session_dir>
```

## Behavior

1. **Read [`VISUAL.md`](./VISUAL.md) before the first screen.** It is the single operating guide (progressive disclosure — loaded only when the companion actually runs): the browser-vs-terminal test, session start/restart, fragment authoring, CSS classes, the events format, the waiting-screen unload, and cleanup. Follow it; do not improvise a parallel workflow here.
2. **Start with `--project-dir` = the repo root and `--open`.** Sessions land under the **top-level `.forge/visual/<session>/`** — a deliberate global location on every branch (like `.forge/config.json` / `.forge/codebase/`, never the branch root: a branch root is git-tracked whole, and mockup HTML must not end up in commits). It is volatile display state, excluded by forge's standard `.gitignore` policy (`.forge/*` with no `visual/` whitelist).
3. **Per-question judgment still applies.** Having the companion open does not mean every exchange goes through it — use the browser only when the content itself is visual (the test in VISUAL.md). Push a waiting screen when the conversation returns to the terminal.
4. **Stop when the visual discussion is done** — on `fg-visual stop`, or proactively when the session's purpose is served. The 4-hour idle timeout is the backstop for forgotten servers, not the normal exit.

## Relationship to fg-ask (the main consumer)

fg-ask offers the companion **automatically, just-in-time** during grilling — the first time a question would be clearer shown than told — and drives it by reading this directory's files directly (`VISUAL.md`, `scripts/`); it does **not** invoke this skill (the same file-reference pattern as `fg-eco/ECO.md` and `fg-run/FORGE-ROOT.md`). Within fg-ask, the server stops at Output time (plan written → companion's job done). The offer discipline lives in fg-ask's Forge integration section; this skill is the **standalone** entry for every other conversation.

## Constraints

- **The keyed URL is the whole access model.** Always hand the user the complete `url` from the server JSON, `?key=` included — a bare `host:port` gets a 403 by design.
- **This skill writes no loop state** — it never touches the active slot, backlog, executed, done, or the permanent docs. Its only writes are session files under `.forge/visual/` (or `/tmp` without `--project-dir`).
- The vendored `scripts/` keep their upstream form (bash launcher + node server) — they are deliberately outside forge's bash+node twin convention for mechanical scripts (ADR-0022); see the vendoring ADR.

## Document impact

- Creates `.forge/visual/<session>/{content,state}/` session files (volatile, gitignored; top-level on every branch). Nothing else.
