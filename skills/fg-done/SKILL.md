---
name: fg-done
description: Seals a finished task — confirms the retro, marks STATUS.md done, archives it, empties the active .forge state, and closes the loop (which blocks the same plan from re-running). `fg-done all` batch-seals every already-executed task at once (retros skipped, backlog untouched, verification gate intact). Use when a task's retro is done — '작업 완료', '봉인', '이거 마무리', '작업 정리', 'forge complete', 'fg-done all', '봉인 all', '모두 봉인'. (Note: 'forge cleanup' routes to fg-cleanup, not here.)
---

# fg-done — ④ Done (tidy-up / re-run guard)

**Host contract**: sealing and `.forge/` state transitions are host-neutral. Read [../../core/HOST.md](../../core/HOST.md) and use the active host's interaction adapter for confirmation; keep the deterministic seal scripts as the single implementation.

This is the last step of the forge loop — the ④ **done** stage that seals one loop. Its job is to **tidy up** the residue left by one loop (ask·plan → execute → retro → done): confirm the retro, mark the task's STATUS.md as done, archive it, empty the active state, and close the loop. The unit of cleanup is a single **task** — there is no notion of closing an epic or merging several tasks into one seal. (Even the `all` batch mode below seals each task into its own `done/` directory: it bulk-skips retros, it does not bundle tasks.) Because a task *is* one loop, you only need to tidy up that one loop cleanly.

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** All documents this skill generates for the user's project (plan, run notes, retros, CONTEXT.md entries, ADRs, handoff messages) are written in the user's language. Section headings defined in the format docs are canonical English names — when writing a document, render headings in the user's language; consumers match sections by meaning and position, not exact strings.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Forge root**: every `.forge/...` path below is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` (git-tracked) on any other branch. The seal script resolves this itself (shared resolver, ADR-0011); when you read state by hand for routing, resolve it per `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`).

This skill is self-contained and standalone. It depends on no external skills: it reads input from `.forge/` and writes output to `.forge/done/`.

## How it runs (script-backed seal — ADR-0030)

The **mechanical seal** — pre-checks, gate enforcement, STATUS close-out, atomic archive, emptying the source bucket — is done by a **deterministic script**, not by an LLM hand-running a dozen bash steps and reasoning the guards in tokens (that was slow, the same problem ADR-0020 fixed for fg-status). This skill **runs the script and routes on its exit code**; the script never routes. It is the **single seal primitive shared by all three seal paths** — interactive `fg-done`, `fg-done all`, and `fg-next all` (which reaches it by delegating to fg-done) — so all of them get the same fast, atomic seal.

Unlike fg-status's read-only survey script, this one **mutates/moves files**, so it is **gate-first, non-destructive-on-refuse**: it touches nothing until every pre-check and gate passes, then closes out STATUS in place and moves atomically. That safety is why the mechanical part is *better* as a script than as hand-bash (no partial states), and why it is guarded by `scripts/forge-done.test.sh` + `scripts/forge-done.parity.test.sh`.

Dual dispatch (ADR-0022): prefer bash, fall back to node.
- **Has bash**: `bash "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/forge-done.sh" [args]`
- **No bash** (e.g. PowerShell-blocked Windows): `node "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/forge-done.js" [args]` — identical behavior (exit codes, STATUS content, archive layout), guarded by the parity test.

**Arguments** (the judgment this skill supplies to the mechanical seal):
- `--slug <slug>` — target a parked `executed/<slug>` or a half-sealed `done/*-<slug>`. Omit to seal the **active slot**.
- `--skip-retro "<reason>"` — record `retro: skipped (<reason>)`. **Passing this is the skip *decision*, which is judgment** — pass it only when the retro is deliberately skipped (a human's skip-and-seal on a low-divergence task, or an `fg-next all`/`fg-done all`/`fg-loop` drive). Without it, the script **requires** a retro file and refuses (exit 4) if none exists.
- `--docs-updated "<value>"` — the STATUS `docs updated:` field (which CONTEXT/ADR this loop touched — LLM knowledge). Default `none`; on the skip path it is usually `none` (promotion deferred to a later fg-learn).
- `--completed <YYYY-MM-DD>` — seal date; defaults to today (an arg so tests are deterministic).

**Resolve the target before invoking the script.** The script defaults only to the active slot; it does not choose among parked tasks:
- An explicit user `--slug <slug>` targets that parked/half-sealed task.
- If an active `plan.md` exists and no slug was requested, target the active slot. **active-slot target: omit `--slug`** — passing it is reserved for `executed/` or half-sealed `done/` targets.
- If the active slot is empty, collect parked `executed/<slug>` candidates that can be routed by this invocation. With **exactly one parked candidate**, target it with `--slug <slug>` automatically. With 2–4, ask which via `AskUserQuestion`; with 5+, print a numbered list and ask for the task number/slug/list number. Do not call the script with no slug and then report `EMPTY` while a parked target exists.
- If neither the active slot nor a parked target exists, run without `--slug` and route the script's exit 2 normally.

**Exit codes → routing (this is the skill's job):**

| Exit | Meaning | Route (see "Before starting" for the full rule) |
| --- | --- | --- |
| 0 | sealed OK (or a half-sealed dir completed idempotently) | relay + completion notice + map offer + close loop |
| 2 | nothing to seal (empty state / slug not found) | guide to `fg-ask` to start a new task |
| 3 | verify gate: `verified:` not sealable (pending/failed/missing) | **failed** → fix-and-re-run via `fg-run` (or re-grill `fg-ask`); **pending**, active slot → fg-run verification-only resume; **pending**, parked/legacy → run the cleanup-time UAT here, record `verified:`, re-invoke |
| 4 | retro gate: retro owed (no retro file, no `--skip-retro`) | run a retro with `fg-learn` first — or, if deliberately skipping, re-invoke with `--skip-retro` |
| 5 | duplicate: `done/<date>-<slug>/` already sealed | surface it, do not double-seal (confirm a separate cycle before any re-seal) |

The script emits language-neutral tokens (`SEALED …` / `GATE_VERIFY …` / `GATE_RETRO …` / `DUP …` / `EMPTY …`) — read the token to route; write the user-facing prose in the user's language.

## Before starting: the guards the script enforces (and how you route)

Sealing is hard to undo. The two guards below are **enforced deterministically by the script** (it refuses non-destructively), but the **routing on refusal is yours** — that is the judgment this skill adds. The loop order is run → verify → learn → done (ADR-0009): verification is checked before the retro.

**No-seal-without-verification guard (exit 3).** The task's `STATUS.md` `verified:` must be a **sealable** value: `yes (<evidence>)` (confirmed working, one-line evidence — the form fg-run records; ADR-0009) / `n/a (<reason>)` (nothing runnable) / `skipped (<reason>)` (a deliberate, auditable waiver — this **still seals**). The script refuses (exit 3) on `pending`, `failed`, or missing. Route by case:
- **`failed`** → the work is broken. **Never seal, never waive to `skipped`.** Route to **fg-run** (the single owner of unparking a failed task — it moves `executed/<slug>/{plan,run,STATUS}` back to the active slot when free, then fix-and-re-run; or re-grill via `fg-ask`). It returns for sealing only once a fresh re-run re-verifies it to `yes`/`n/a`.
- **`pending`/missing, active slot with `run.md`** → point to fg-run's **verification-only resume** (runs the UAT, writes `verified:`, no re-execution) before any retro.
- **`pending`/missing, a parked `executed/<slug>` or an older run predating the guard** → no reachable fg-run handoff, so **run the UAT here, now** against the plan's goal and record the outcome in STATUS. Sealable → re-invoke the script. If this cleanup-time UAT finds it broken, record `failed (<reason>)`, stop, and route to repair — do not waive it.

**No-seal-without-retro guard (exit 4).** For each task, either a retro `.forge/retro/*-<slug>.md` exists, **or** the seal is a deliberate skip (`--skip-retro`, which records `retro: skipped (<reason>)`; a STATUS already reading `retro: skipped` also satisfies it). The script refuses (exit 4) when a retro is owed and no `--skip-retro` was passed → route: "first run a retro with **fg-learn**" (or, if the user/orchestrator is deliberately skipping a low-divergence task, re-invoke with `--skip-retro "<reason>"`). Whether to skip is judgment — an `fg-next all`/`fg-done all`/`fg-loop` drive always skips (ADR-0010/0016/0023); an interactive seal skips only on a low-divergence task the user chose to skip.

**Empty / duplicate / half-sealed (exit 2 / 5 / 0).** The script also handles these deterministically: empty state or an unknown slug → exit 2 (guide to `fg-ask`); a `done/<date>-<slug>/` already at `status: done` → exit 5 (surface, don't double-seal); a half-sealed `done/` dir (files moved, STATUS not flipped) → it completes the flip idempotently and exits 0. You do not pre-scan for these — you run the script and route on the code.

```
fg-done (single task)
   │  decide: target (--slug or active slot) · skip retro? (--skip-retro) · docs (--docs-updated)
   ▼
run forge-done.sh (bash) | forge-done.js (no bash)
   ├── exit 0 ──▶ relay SEALED → completion notice → (map offer) → close loop
   ├── exit 2 ──▶ "no task in progress" → guide to fg-ask
   ├── exit 3 ──▶ failed → fg-run fix-and-re-run / fg-ask re-grill
   │              pending(active) → fg-run verify-only resume
   │              pending(parked/legacy) → cleanup-time UAT here → record verified → re-invoke
   ├── exit 4 ──▶ retro owed → fg-learn (or, deliberate skip → re-invoke with --skip-retro)
   └── exit 5 ──▶ already sealed → surface, don't double-seal
```

## Behavior

The script does the mechanical seal in one call (**close out STATUS in place → archive into `.forge/done/<date-slug>/` → empty the source bucket**, in that order so an interruption always leaves a recoverable source bucket). Your job around it:

**1) Decide the arguments (judgment), then run the script.** Resolve the target with the rule above (active slot → no `--slug`; parked/half-sealed → `--slug`; active empty with multiple parked tasks → select one first), decide whether the retro is being skipped (`--skip-retro "<reason>"` — see the retro guard), and fill `--docs-updated "<value>"` with the CONTEXT/ADR this loop touched (default `none`). Then invoke the script via dual dispatch (bash, else node). Do **not** hand-move files or hand-edit STATUS — the script owns that.

The script writes the closed-out `STATUS.md` in this fixed shape (documented here as the script's output contract — keep in sync with the script if it changes, per ADR-0020's consequence):

```md
# STATUS — {task title}
slug: {slug}
status: done
executed: {YYYY-MM-DD}
completed: {YYYY-MM-DD}
verified: yes (<evidence>)   # preserved from fg-run; or skipped/n/a
retro: .forge/retro/{YYMMDD-HHMMSS}-{slug}.md   # or: skipped (<reason>)
reviewed: .forge/review.md   # only when an adversarial review left one (ADR-0018); omitted otherwise
docs updated: {CONTEXT.md terms / ADR-NNNN / none}   # from --docs-updated
```

`STATUS.md` is the machine-readable completion marker that travels with the task files — fg-run reads `done/*/STATUS.md` (`status: done`) to summarize finished work. For reference, on the default branch the volatile loop state (including `done/`) is gitignored — only permanent docs are tracked via the whitelist; on a non-default branch the branch root is tracked whole (ADR-0011). The persistent trace cleanup leaves is not `.forge/done/` but the retro and the docs that task updated.

**2) Route on the exit code (judgment).** Exit 0 → continue to the notice below. Non-zero → route per the table / "Before starting" above and stop (no destructive action happened — the script refused before moving anything). **Whichever exit you land on — 0 and every non-zero refusal alike — close with the handoff table**, filled from that exit's routing; see "Wrap-up" below.

**3) Completion notice.** After a successful seal, summarize at a glance what was finished, which persistent docs were updated (retro, ADR, CONTEXT), and where the archive landed (`.forge/done/<date-slug>/`). Make the wrap-up explicit so the user recognizes one loop is done. If `git status` shows the permanent docs this loop touched (`.forge/retro/`, `.forge/adr/`, `CONTEXT.md` — or the branch root on a non-default branch) still uncommitted, add a one-line reminder to commit them — a reminder only; never run git yourself (the same restraint as fg-merge).

**Seal summary — explicit single seal only (ADR-0032).** This is part of the step-3 completion notice: on an **explicit, single `/fg-done`** it **replaces** the terse notice above (render the docs/archive facts once, in the summary's meta line — but still append step 3's git-commit reminder if tracked docs are uncommitted). "Explicit single seal" = a bare human `/fg-done` (with or without `--slug`), *not* `all` mode, and *not* a seal delegated by an orchestrated/unattended drive (`fg-next` one-shot — whether it reached fg-done via the learn→done autochain or derived fg-done directly — `fg-next all`, `fg-loop`). In those delegated/batch cases keep the terse notice; **no summary**. Render a **seal summary** reconstructing "what this task set out to do, and what was actually done" from: `plan.md`/`run.md`/`STATUS.md` in the sealed archive (use the `dest=<path>` the script emitted in its `SEALED` token — do **not** reconstruct `<date-slug>`, which can differ from the retro's date), and the **retro at the path in STATUS's `retro:` field** (it lives in `.forge/retro/`, **not** the archive — the script records its path but never moves it). Map: `plan.md` → requirements (Goal + Source-of-truth: Related ADRs / Definition of Done), `run.md` → what was done + divergences, `STATUS.md` → verified/docs, the retro → learnings. Write it in the user's language, **on screen only** — do **not** persist it to a file (the archived plan/run + the retro already are the durable trace). The seal script is untouched; this is judgment-layer prose, not mechanical seal work (ADR-0031). Shape (render headings in the user's language; scale length to the work):

```
✅ Sealed: {title} (#{task})

▸ Requirements
  · Goal: {plan Goal, one line}
  · Key decisions: {1-2 from Related ADRs / Definition of Done, if any}

▸ What was done
  · {3-5 lines from run.md — result per slice}
  · vs plan: {run.md divergences, or "as planned"}

▸ Retro                          ← only when a retro file exists (omit this whole chapter if retro: skipped)
  · Next time: {1-2 lines from the retro's "Do differently next time"}
  · Keep: {1 line from the retro's "Confirmed"/"What went as planned", if present}
  · Full: {the retro path from STATUS's `retro:` field}

▸ Verified {verified} · docs {docs updated} · retro {skipped (reason) — only if skipped} · archived {the dest= path from the SEALED token}
```

**Eco: render the same summary as a table.** If `eco` is `true` in the **top-level** `.forge/config.json` (a global exemption — never the branch root; treat as `off` when the file or key is absent), render the chapters above in the **eco summary table** shape instead of the bullet prose: the meta line folds into the header (title · `#task` · `verified` · divergence), `▸ What was done` becomes the slice table built from `run.md`'s per-slice lines (recorded by fg-run — see its SKILL §4), and the conditional Retro chapter keeps its existing rule below. The shape is defined once in [`../fg-eco/ECO.md`](../fg-eco/ECO.md) ("eco summary table") — reference it, never restate the layout here. **Only the rendering changes**: the material still comes from the archived `plan.md`/`run.md`/`STATUS.md` at the `dest=` path the script emitted plus the retro at STATUS's `retro:` path, and the gate below is untouched (this is still the explicit-single-seal path only — batch and delegated seals are covered separately). When `eco` is `false` or absent, render the prose shape above unchanged.

The **Retro chapter appears only when a retro file actually exists at STATUS's `retro:` path**; on `retro: skipped` (or a dangling path) omit the whole chapter and let the bottom meta line carry `retro: skipped (<reason>)`. **Gate:** the summary is for the **explicit single seal** only, per the definition above. fg-done cannot detect its caller (same limit as fg-run's handoff — ADR-0015), so the terseness of the delegated/batch paths is enforced from the orchestrator side: `fg-next`/`fg-loop` carry a matching "a delegated seal stays terse — no single-seal summary" rule in their own drive discipline (`all` mode also self-guards below), while a bare human-invoked single `/fg-done` (no `all`) renders the summary here. Note the enforcement is only cosmetic-on-forget (unlike ADR-0015's self-enforcing stop) — if a delegated path ever leaks the summary it is verbose, not broken. The rationale for the asymmetry (batch/drive favor momentum; after `fg-next`'s learn→done autochain the retro conversation just happened, so a summary would duplicate it) is ADR-0032.

**3a) Codebase map check (conditional — offer, never auto-run).** Check two cheap signals: **(a)** does `.forge/codebase/` exist? and **(b)** did this loop change project files the map describes — i.e. does `git status --short` show changes (modified *or* untracked) on paths **not** starting with `.forge/` (skills, `src/`, manifests, README, …)? If **both** are true, the map may be stale, so offer **once**, in the user's language: *"this task changed `<changed project files>` and a `.forge/codebase/` map exists — the map may be stale. Run `fg-map` now?"* On agreement, invoke `fg-map`; on decline, finish. **Offer, never auto-run** — fg-map fans out subagents and is on-demand (ADR-0006). If `.forge/codebase/` is absent, **or** the loop changed only `.forge/` docs, **say nothing and skip**.

**4) Close the loop.** A follow-up `fg-learn` left belongs in the table's `Next step` cell as a **new task** — not in a second sentence here (several candidates → bullets below the table, per HANDOFF.md's list rule). Nothing is asked at this point: no "shall I start it?", no auto-invoking fg-ask (chaining is `fg-next`'s job — ADR-0015). With no follow-up, the table still renders (a new task begins with fg-ask) and you finish there.

## `all` mode — batch seal-only (skip every remaining retro)

When invoked with the `all` argument (`fg-done all`, or "봉인 all" / "모두 봉인"), fg-done seals **every already-executed task at once**, auto-skipping each task's retro. It is the **seal-only counterpart to `fg-next all`**: where `fg-next all` also promotes and runs backlog tasks, `all` mode here **never promotes or runs anything** — it only tidies up work that has *already executed* (the active slot + the whole `.forge/executed/` queue). Rationale and boundary: `.forge/adr/0023-fg-done-all-batch-seal.md`.

It relaxes exactly **one** gate — the retro guard (via `--skip-retro` on every task) — and leaves everything else to the script's per-task enforcement:

- **Scope: seal-only.** Targets = the active slot + every `.forge/executed/<slug>/`. The backlog is **out of scope** — `all` never promotes/runs an unexecuted plan (that is `fg-next all`). Keep this sharp: if the user wants backlog work run too, point to `fg-next all`.
- **The verification gate (ADR-0009) is untouched.** `all` skips the retro, **not** verification — it just passes `--skip-retro` per task; the script still refuses (exit 3) any task whose `verified:` is not sealable. A `verified: failed` task is **never** sealed — set it aside and route to **fg-run**, keep sealing the others. A `pending`/missing task takes the **same cleanup-time UAT recovery as the single-task path** (run the UAT here; sealable → seal, else set aside).
- **The retro is auto-skipped unconditionally**, regardless of divergence — the same waiver `fg-next all`/`fg-loop` take (ADR-0010). Pass `--skip-retro "fg-done all — learnings stay in run.md, promotion deferred to a later fg-learn"` (in the user's language) so the skip is auditable and the learnings stay in the archived run.md for a later human fg-learn.
- **One upfront confirmation, then no per-task prompts.** Before sealing anything, list **once**: the tasks that will be sealed (each with its `verified:` value and "retro will be skipped") **and** the tasks set aside (failed → fg-run, unverifiable → still pending) — the deciding of this list is judgment (which tasks, what will happen), which is why it stays here and not in the script. Get a single go-ahead. After it, loop over the qualifying tasks, calling the script once per task: **for the active-slot target omit `--slug`; for each parked `executed/<slug>` target pass `--slug <slug>`**, and pass `--skip-retro "…"` to both. Passing `--slug` indiscriminately would make the active task look absent to the script. (Under `fg-next all`, the drive's upfront go-ahead already covers this — do not re-prompt; see fg-next's DRIVE.md.)
- **The unit is unchanged.** Each task is sealed into its own `.forge/done/<date-slug>/` by its own script call — `all` only skips retros in bulk, it does not bundle tasks.
- **The notice stays terse.** `all` emits the per-task completion notice + set-aside list only — **never** the explicit-single-seal summary chapter (the seal-summary block in step 3, ADR-0032). Batch sealing favors momentum, so a summary per task would be a wall of text.
  - **Eco: one row per task instead of the per-task notice.** If `eco` is `true` in the **top-level** `.forge/config.json`, **replace** the per-task notices with the batch shape of the **eco summary table** — one row per task — defined once in [`../fg-eco/ECO.md`](../fg-eco/ECO.md) (reference it; never restate the layout). **The single-seal summary chapter stays forbidden here**: a one-row table and a summary chapter are different things, and only the former is allowed in batch. Keep the set-aside list (failed → fg-run, unverifiable → still pending) — as rows or a line, whichever is shorter. The upfront one-time confirmation and the verification gate are untouched. When `eco` is `false` or absent, emit the terse notices above unchanged. See ADR-0032's 2026-07-31 amendment for why a shorter form is not a reversal of the no-summary rule.

```
fg-done all
   │  collect already-executed tasks (active slot + all executed/) ── none ──▶ run script once (empty → exit 2) → guide to fg-ask
   │  one or more
   ▼
per task — check verified (route failed→fg-run, pending→cleanup UAT) ; build the seal list + set-aside list
   ▼
show ONE confirmation (to-seal w/ retro:skipped · set-aside) → one go-ahead
   ▼
for each qualifying task: active slot → forge-done.sh --skip-retro "<reason>" ; executed/<slug> → forge-done.sh --slug <slug> --skip-retro "<reason>"
   ▼
completion notice (per-task summary + set-aside list)
```

## Wrap-up: every terminus ends in the handoff table

**Whichever exit you landed on — the successful seal (0) and each non-zero refusal alike — close with the handoff table**, filled from that exit's routing in the exit-code table above and "Before starting" (read them; do not re-derive the route here). Its shape is defined once in `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-next/HANDOFF.md` (skill-relative [`../fg-next/HANDOFF.md`](../fg-next/HANDOFF.md)); reference it, never restate the layout here. Render it in the user's language, **once per invocation** — in `all` mode at the end of the batch, never per task — and not at all when an unattended drive suppressed it (HANDOFF.md, "Unattended drives").

`Just did` is always what actually happened this turn, and it may **never assert what a path can falsify** (HANDOFF.md's rule of that name — "the active state is now empty" is exactly the sentence one set-aside task makes false). Fill it from the **first matching case**:

1. **A refusal (any non-zero exit)** → the script refused at that gate and **nothing was moved**.
2. **Exit 0 with at least one task set aside** (only `all` mode reaches this — a single `verified: failed` seal refuses at exit 3) → how many were sealed and how many set aside, and which. **Do not claim the active state is empty**: a set-aside task is still sitting in it, and the same plan therefore *can* run again — that is the point of routing it to fg-run.
3. **Exit 0 on the explicit single seal** → that the task was sealed and the active slot is free. The step-3 seal summary (ADR-0032) **already owns** the archive path and the docs-updated line, so this cell does not render them a second time (HANDOFF.md, "Do not give one fact two owners").
4. **Exit 0, everything else** (batch `all` with nothing set aside — the terse-notice paths, where no summary rendered) → the seal: archived into `.forge/done/<date-slug>/`, STATUS.md marked done, the active state now empty (so the same plan can never run again), plus the one-line summary of the docs this loop updated.

The other rows are filled per exit, branching where the routing branches:

- **exit 0** — `Next step` by the **first matching case**: **a task was set aside** (case 2 above) → recovering it with **fg-run** (`failed` → unpark + fix-and-re-run; still-`pending` → the verification-only resume), `How to start` `/forge:fg-run`, `Alternative` re-grilling with fg-ask — the sealed ones are done, so the only thing still owed is the one that did not seal; **a follow-up `fg-learn` left** → it starts as a **new task**; **otherwise** → simply that a new task begins with fg-ask. `How to start` for the latter two: `/forge:fg-ask`, or `fg-next`. Several follow-up candidates → bullets below the table. If the git-tracked docs this loop touched are still uncommitted, the commit reminder is one line **below** the table — **that is its single home** (HANDOFF.md counts fg-done's commit reminder among the below-table sites); step 3's "still append the reminder" means the seal summary does not swallow it, not that it is rendered in two places. Reminder only, never run git yourself; a cell stays one line.
- **exit 2** — nothing to seal. `Next step`: fg-ask, to start a new task; `How to start`: the same triggers; omit `Alternative`.
- **exit 3** — the verify gate, three sub-cases, so fill from the one you hit: **`failed`** → `Next step` fg-run (unpark + fix-and-re-run), `How to start` `/forge:fg-run`, `Alternative` re-grill with fg-ask; **`pending`, active slot** → fg-run's verification-only resume, same trigger, no `Alternative`; **`pending`, parked/legacy** → the cleanup-time UAT is yours to run first, so the table comes after it — sealable → `Next step` is re-invoking fg-done (`/forge:fg-done`); broken → you recorded `failed`, so render the `failed` case.
- **exit 4** — the retro gate, and the refusal you will hit most. `Next step`: fg-learn; `How to start`: `/forge:fg-learn`; `Alternative`: on a deliberate low-divergence skip, re-invoking with `--skip-retro "<reason>"`.
- **exit 5** — already sealed, nothing touched. `Next step`: nothing is owed for this task, so a new task with fg-ask; `Alternative`: a genuinely separate cycle, confirmed before any re-seal.

**State it and stop** — the table is text output, never an `AskUserQuestion`, and `Alternative` *states* that another route exists rather than asking which to take: do not ask "shall I start it?" and do not auto-invoke the skill you named (chaining is `fg-next`'s job — ADR-0015).

**Order on screen — the table is last (HANDOFF.md).** On an explicit single `/fg-done` the step-3 seal summary comes first (it replaces the terse notice; batch `all` and orchestrated/unattended seals keep the terse notice, no summary chapter — ADR-0032), then the step-3a **fg-map offer** when it applies, then the table. That offer is a real question, so it can never live in the table (the table is not a question and `Alternative` is not a menu) and nothing may follow the table — therefore **ask it before rendering the table**, never after, and never folded into a cell. On a non-zero exit nothing was sealed, so neither the summary nor the offer applies and the table stands alone. The summary looks back at the task just sealed; the table points at what comes next — do not render the summary twice. When `eco` is `true`, that summary is already the eco summary table (step 3); how the handoff table combines with it is HANDOFF.md's "Interaction with eco" — follow it, do not restate it here.

## Document impact

- `.forge/done/<date-slug>/` — archive of the sealed `plan.md`/`run.md` (+`review.md` if present) + the closed-out `STATUS.md` (`status: done`), written by the seal script (local; gitignored on the default branch, tracked under the branch root otherwise — ADR-0011). fg-run reads the `STATUS.md` markers to exclude finished work and summarize status.
- Active `.forge/` — emptied of `plan.md`/`run.md`/`STATUS.md` (by the script) so the next run finds no plan.
- Persistent docs (`.forge/retro/`, `.forge/adr/`, `CONTEXT.md`, etc.) are not newly created here — earlier steps already updated them.
- The seal itself is done by `scripts/forge-done.sh` / `.js` (ADR-0030) — this skill invokes it and routes; it does not hand-edit STATUS or hand-move files.

If you need the format for retro·ADR·CONTEXT, read the original format docs directly (don't copy per skill):
`${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-learn/RETRO-FORMAT.md`, `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-ask/ADR-FORMAT.md`, `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-ask/CONTEXT-FORMAT.md`
(relative paths from the skill directory: `../fg-learn/RETRO-FORMAT.md`, `../fg-ask/<file>`)
