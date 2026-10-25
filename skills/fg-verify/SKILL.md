---
name: fg-verify
description: Builds (or refreshes) a project-local verification skill, verify-<app>, that drives your app the way a user does — launch, health check, drive a feature, capture evidence, clean up — plus a feature map of the journeys it can prove. It does NOT run a verification; it makes the tool fg-run's UAT later uses. First run creates and proves it; later runs re-check the map or add a skill for another surface. Outside the loop; skipped in fg-next all / fg-loop. Use in contexts like 'fg-verify', 'forge verify', '검증 스킬 만들어', '검증 스킬 갱신', 'verification skill'.
---

# fg-verify — build a verification skill (outside the loop)

This is **not** a stage of the forge loop (fg-ask → fg-run → fg-done). It is an **on-demand utility** — like fg-map and fg-agents — that produces a project asset the loop later uses: a **verification skill** (`verify-<app>`), a project-local skill that launches the user's app, drives it the way a user does, and captures evidence that a behavior works. fg-run's UAT is otherwise "show the human what to check and ask"; with a verification skill in place, the evidence can come from actually driving the app (ADR `261025-090138`).

**This command builds the tool; it does not verify anything.** Running a verification is the UAT's job. One command covers both lifetimes of the tool: **create** when the project has none, **update** when it already has one (the same shape as fg-map's "write, or Update an existing map").

**Adapted, not vendored.** The method is adapted from pstack's `create-verification-skill` and `maintain-verification-skill` (`cursor/plugins`, MIT, Copyright (c) 2026 Lauren Tan — see [`LICENSE`](./LICENSE)) and rewritten here for forge: the location, the single command, and "no PR" are forge decisions. Only the feature-map example under [`references/feature-map-example/`](./references/feature-map-example/) is kept byte-for-byte with upstream — it is the **single definition of the feature-map format**; never edit it, and never restate its contract here.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, reports, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** The generated skill and its feature files are written in the user's language, except frontmatter keys, file names, commands, selectors, and paths, which stay verbatim.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Evidence and candor**: every claim you make about code, state, or results — in a message or in a document you write (plan, run notes, retro, ADR) — carries its evidence in the same sentence (a `file:line`, a command and its output) or a label: **Measured** (you checked it this session), **Inferred** (reasoned from what you checked), **Guess** (a prediction or an unseen cause), rendered in the user's language. A label is not a license to skip a check — if a cheap check would settle it, run it; never hand the user a check you could run. Agreement is not the default: when asked whether to do something, invited to add scope, or shown an approach, give your real judgment first — the strongest objection, and "don't do it" when that is true. Change a recommendation only for a new fact or argument, never for repetition; the decision stays the user's — state the objection once, then follow their call without re-arguing or silently deviating. Output a deterministic script printed is already measured and needs no label.

**Host contract**: update mode's source wave fans out one reader per feature, so it needs the host's `spawn_parallel` capability. Read [../../core/HOST.md](../../core/HOST.md) and [../../core/EXECUTION.md](../../core/EXECUTION.md), then check `../../hosts/<host>/capabilities.json`. When `spawn_parallel` is `false` or the host is unknown, **read the features serially** — the outcomes, the edit scope, and the live pass do not change; only the delegation does. Driving the app is never delegated: one coordinator owns every live drive.

**Forge root**: the generated skill lives in the project's `.claude/skills/` (a host skill location, never resolved). Evidence lives in the **top-level** `.forge/verify/` on every branch — a global exemption like `.forge/showme/` (see `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-run/FORGE-ROOT.md` / ADR-0011), because the branch root is git-tracked on a non-default branch and evidence must have no path into a commit.

## Where things go

- **The skill** — `.claude/skills/verify-<app>/` (`SKILL.md`, `features/`, any helper scripts), one copy only. Claude Code and opencode read `.claude/skills/`; Codex does not, so on Codex also create the relative symlink `.codex/skills/verify-<app>` → `../../.claude/skills/verify-<app>` — never a second copy (two copies drift). Pi's project-skill path is unverified, so Pi is out of scope. The skill is a **project asset**: it is committed, so teammates and CI share the same verification path.
- **The evidence** — under the top-level `.forge/verify/`, one fresh directory per drive, with a self-ignoring `.gitignore`. The layout and the self-ignore rule are defined once in `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-run/FORGE-ROOT.md` (the `.forge/verify/` exemption) — follow it; this command's proof runs use `<run>` = `fg-verify`.
- **Several surfaces** — one verification skill per primary surface. When any `verify-*` exists, ask which: update one of the existing skills (list them), or **create a new one for another surface** — never assume update just because a skill exists.

## Who reads the skill, and when a restart matters

The loop never invokes `verify-<app>` as a skill: fg-run's UAT **reads its files** (`SKILL.md`, the named `features/<feature>.md`) and follows them, exactly as this command's own proof run does. So the loop can use a verification skill **in the same session** it was created — no restart. A restart matters only to call `verify-<app>` directly as a skill by name, because skills load once, at session start (ADR-0024, measured for skill bodies too). Say this in the handoff in one line; do not tell the user a restart is required before the UAT can use it.

## Mode

```
fg-verify
   │
   ▼
.claude/skills/verify-*/ present?
   │ no  ──▶ Create: interview the repo → generate → seed the feature map → prove → offer commit
   │ yes ──▶ ask: update which existing skill, or create one for a new surface?
   │            ├─ update <one> ──▶ Update: index hygiene → source wave → reconcile → live pass → triage → outcome
   │            └─ new surface  ──▶ Create (as above)
   ▼
handoff (the UAT can use it right away)
```

## Create

**1. Interview the repo, not the user.** Answer from the codebase and ask only what you cannot observe:

- **Surface** — what a user actually touches: web UI, CLI/TUI, desktop app, API, mobile app, library. Pick the primary one and note the rest.
- **Run** — how the app starts locally, preferring the repo's own documented dev command; ports, env vars, seed data, auth.
- **Drive** — how an agent can operate it programmatically: existing harnesses first (Playwright/Cypress specs, expect scripts, PTY helpers, curl-able endpoints, a debug port), then a generic recipe (browser/CDP for web and Electron, a tmux/PTY harness for CLI/TUI, plain HTTP for services).
- **Observe** — what evidence can be captured: screenshots, terminal transcripts, response bodies, logs, exit codes, stored state.
- **Isolate** — whether two instances can run side by side. If not, the generated skill says so and refuses to drive an instance it did not start.

If the checkout does not build or start as-is, report it precisely and stop, or fix it only with the user's agreement — a skill written against a broken base teaches wrong steps. An irrelevant missing asset that blocks startup may be created by the generated skill as clearly marked verification scaffolding, removed in cleanup.

**2. Generate the skill.** Write `.claude/skills/verify-<app>/SKILL.md` with frontmatter (`name: verify-<app>` and a `description` naming the app, the surface, and when to reach for it — without frontmatter it never registers). Every section is grounded in what the interview found; no placeholders survive:

- **Launch** — the exact command, and how to tell it is *usable* (a process answering is not ready while its init still runs), reaching a usable state from an empty data directory, with teardown. For a short-lived CLI/TUI: build once, then each drive in its own isolated PTY or tmux session.
- **Doctor** — one read-only check that answers "is this instance worth driving?": process up, right build, port owned by this run, auth valid. Run first whenever anything looks off.
- **Drive** — the harness recipe with real selectors and commands from this repo. Prefer stable handles (ARIA names, data attributes, prompt strings, routes) over coordinates and tab order.
- **Evidence** — what to capture and where: a fresh `.forge/verify/<run>/<YYMMDD-HHMMSS>/` per drive (FORGE-ROOT.md; see above), with `<run>` supplied by the caller. Proof standards: exercise the real user path, not internal setters or test-only endpoints; capture the action *and* the resulting state; verify side effects (files written, rows inserted, messages sent) alongside what is visible; mocks only where a production boundary already isolates the external system. When the safe path is a dry-run, observe what it actually skips rather than trusting its name.
- **Cleanup** — tear down only what this run started (never kill by process name); remove instances and scratch state, never the evidence.
- **Helpers** — every shipped script is executable and its invocation is shown in the skill body.

**3. Seed the feature map.** Create `.claude/skills/verify-<app>/features/README.md` plus one file per user-facing feature — the top 3–5 to start, found from routes, commands, menus, or docs — in exactly the shape of `references/feature-map-example/` (the index, then one file per feature). The example defines the **shape** (the index, the four H2 sections, the driving conventions); its `artifacts/…` evidence paths are upstream's illustration only — a generated map writes evidence under `.forge/verify/` per FORGE-ROOT.md, never to a repo-relative directory a `git add -A` would stage. If seed data lacks a precondition a journey needs, the journey reports a failure and the reason goes in that feature's gotchas; **never weaken a journey to make it pass**. A proof that drives one convenient entry point is incomplete when the map lists others.

**4. Prove it before handing it over.** Follow the generated instructions end to end once: launch, doctor, drive **one** mapped feature, capture evidence into a fresh `.forge/verify/fg-verify/<YYMMDD-HHMMSS>/`, clean up — then confirm the evidence still exists there. A cleanup that eats the proof fails this step. Fix what fails and run the generated cleanup after every failed attempt so nothing strands processes or ports. An unexecuted generated skill is a draft, not a deliverable. If you proved it in a stand-in (a container for a fresh VM, a local stack for a remote one), list every setup step the stand-in did that the real target will not; those stay unverified.

## Update

**Edit scope**: only the verification skill's own directory (`SKILL.md`, `features/`, its helper scripts). Never edit product code here: a behavior the map describes that the app no longer does is either map drift (fix the map) or a product defect (report it — never paper over it in the map).

1. **Index hygiene** — read `features/README.md` and list its sibling files; fix missing, extra, duplicate, or dead entries.
2. **Source wave** — one read-only reader per feature file (parallel when `spawn_parallel`, else serial): explain from source how the feature works for a user, flag likely drift with `file:line` citations, and return one live-verification recipe. Readers never drive the app and never edit files.
3. **Reconcile** — every feature has a returned summary; merge overlapping recipes into as few app states as practical; spot-check cited drift; sweep recent changes for user-facing surfaces missing from the map, naming a concrete source path before calling one missing.
4. **Live pass** — required even when the source looks clean; the coordinator drives every feature at least once, following the skill's own launch model. Three invariants hold throughout: (1) never drive an instance not health-checked since it last surprised you — doctor before the first drive, after any failed drive, and reset or relaunch when doctor cannot see the problem; (2) evidence captured so far survives every cleanup, checked at its location, not assumed; (3) nothing a drive started outlives its usefulness. A doctor failure caused by skill drift is drift: fix it within the edit scope and retry once. A feature that cannot be reached is reported with the concrete prerequisite (auth, entitlement, OS, external state) and the route tried; if the map omits that prerequisite, that is drift. Re-drive every harness fix before keeping it.
5. **Triage** — wrong or missing user-facing description → fix the map; working behavior the harness cannot drive → fix the harness; app behavior actually broken → record it for the user, keep it out of the edits.
6. **Outcome** — say which: **clean** (full coverage, nothing to change), **changed** (proven corrections to the skill, re-read before reporting), or **blocked** (coverage could not finish or a fix could not be proven — say exactly what blocked it). forge opens no PR; changed files stay in the working tree for the commit offer below.

## After create or update

1. **Scan the skill for secrets** — the skill is committed. Grep its directory for common secret shapes (`sk-`, `sk_live_`, `ghp_`, `AKIA`, JWT-shaped `eyJ…`, `-----BEGIN … PRIVATE KEY`). A match stops here and goes to the user before anything else.
2. **Offer to commit, never auto-commit** — "verification skill written and scanned clean — commit `.claude/skills/verify-<app>/` (and the Codex symlink)?" If the working tree holds unrelated changes, say so and let the user choose what to stage. Evidence under `.forge/verify/` is never part of it.

## Unattended lanes — always skipped

`fg-next all` (ADR-0010) and `fg-loop` (ADR-0016) **never run this command**: *building* a verification skill installs dependencies, may repair the build, and may need the human for auth or environment values — none of which an unattended drive may decide. It is invoked deliberately, by a human. *Driving* an already-built skill during a UAT is a different act with its own limits, defined in fg-run's UAT section (a drive that needs a human, or whose side effects leave the instance it started, is not taken unattended).

## Handoff

Render the **handoff table** per [`../fg-next/HANDOFF.md`](../fg-next/HANDOFF.md) — the single definition of its shape; never restate that layout here. Statement form, in the user's language, then **stop** (chaining is `fg-next`'s job — ADR-0015).

`Just did` = the skill path, the mode, and the result: on create, which feature was proven and the evidence path; on update, the outcome (clean / changed / blocked) and the features covered. Fill the rest from the **first matching case**:

1. **Blocked, or the proof failed** → `Next step` = fixing what blocked it, named concretely (a broken build, a missing prerequisite), then `fg-verify` again; `How to start` = `/forge:fg-verify`; omit `Alternative`.
2. **Mid-loop** (the active slot, `.forge/executed/`, or the backlog holds work) → `Next step` = where they were, from fg-status's next-step state machine (not re-guessed here); `How to start` = that step's trigger, or `fg-next`; omit `Alternative`.
3. **Otherwise** → `Next step` = start a task with `fg-ask` — its Definition of Done can name a feature-map entry for the UAT to drive; `How to start` = `/forge:fg-ask`; omit `Alternative`.

Product defects found during an update are list-shaped, so they go **below** the table as bullets, one per defect with its feature and evidence path.

## Document impact

- Creates or edits `.claude/skills/verify-<app>/` (and, on Codex, the `.codex/skills/verify-<app>` symlink) — a project asset, committed only on the user's agreement.
- Writes evidence under the top-level `.forge/verify/` (layout and self-ignore: FORGE-ROOT.md) — never committed, never deleted automatically.
- Touches **no** loop state: never `plan.md`, `run.md`, `STATUS.md`, the backlog, `executed/`, or `done/`.
- Never edits the vendored `references/feature-map-example/` files.
