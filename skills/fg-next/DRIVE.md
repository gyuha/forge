# Unattended drive discipline (shared)

> Single definition of how an **unattended multi-step drive** keeps going — within one turn, and across turn boundaries. Shared by `fg-next` (`all` mode) and `fg-loop` so the discipline lives in one place, not two drifting copies (same "single definition, referenced, no copy-paste" pattern as `FORGE-ROOT.md`). Each lane keeps its **own** halt/wall set and entry framing; this file owns only what they genuinely share.

A drive delegates each step to fg-run / fg-done / fg-learn and repeats until it either reaches its terminal state or hits a wall. Two independent things make "repeat" actually happen: continuing **within** a turn (Part 1) and crossing a genuine turn **boundary** (Part 2). They are separate mechanisms with separate guarantees — do not conflate them.

## Part 1 — Continue within the turn (best-effort)

The skills a drive delegates to (fg-run, fg-done) end in **statement-form handoffs** (ADR-0015): they *state* the next step and **stop**. That stop is written for a **human** caller who will read it and decide. **In a drive, the orchestrator is the caller — so do NOT treat a delegated skill's stated stop as a turn boundary.** The moment a delegated step completes, immediately re-derive the next step (via fg-status's state machine — never reimplemented) and act on it: seal → derive/promote next → act, without ending the turn.

- **Sealing one task is not a stopping point.** After each seal, immediately derive and take the next step. The **only** legitimate ends of a turn are the drive's **terminal state** (nothing left to auto-progress) and a genuine **wall** — and each lane defines its own walls (fg-next all: `../fg-next/SKILL.md`; fg-loop: `../fg-loop/SKILL.md`). Pausing anywhere else is the "one cycle then stall" failure this discipline exists to prevent.
- **No re-run / repeat-menu risk.** This continuation advances on **changing** state — a sealed task leaves the active slot, the next is promoted — never on unchanged state. So it does **not** reintroduce the ADR-0015 repeat bug (that was an `AskUserQuestion` menu re-triggering on *unchanged* state; a drive has no such menu, and its state moves forward each step). The drive loop asks the user nothing between steps.
- **Do not relay a delegated skill's retro recommendation.** fg-run's (and fg-done's) statement-form handoff *states* "next: fg-learn (retro)" — written for a **human** caller who will read it and decide. **In a drive you must NOT surface that "run fg-learn" line to the user.** The moment the delegated step completes, apply the lane's retro policy (referenced above — fg-next all / fg-loop both auto-skip) and continue straight to skip-retro + seal. Relaying fg-run's "run fg-learn" handoff — so the user is told to retro manually and the drive stalls at the learn stage — is a primary way the "keeps telling me to run fg-learn, never seals" stall happens; it is the same leak as surfacing a delegated seal summary, and this discipline forbids both.
- **A delegated seal stays terse.** A seal reached inside a drive is a *delegated* seal — it uses fg-done's terse completion notice, **never** the explicit-single-seal summary chapter (ADR-0032). That summary is for a human's bare `/fg-done` only; in an unattended drive it would be a wall of text against the momentum this discipline exists to keep.
  - **Eco: terse becomes one row per task, not prose.** When `eco` is `true` in the **top-level** `.forge/config.json`, a drive reports each delegated seal as **one row** of the batch **eco summary table** — accumulated across the drive — instead of a per-task prose notice. The shape is defined once in [`../fg-eco/ECO.md`](../fg-eco/ECO.md); reference it, never restate the layout. **The summary chapter stays forbidden** — a row is not a chapter. This does not loosen the terseness rule above, it *implements* it: a row is shorter than the notice it replaces (ADR-0032's 2026-07-31 amendment). Both lanes (fg-next `all`, fg-loop) inherit this from here; neither restates it. When `eco` is `false` or absent, the terse prose notice above is unchanged.
- **Honest limit.** Skill text alone **cannot guarantee** the model won't yield the turn after a delegated handoff states its next step — the pull toward "natural completion" is real. This within-turn discipline **reduces** yields, and for a backlog of small / direct-execution tasks (no background workflow) it can drain the whole backlog in a single turn. But the **reliable** cross-turn guarantee is `/goal` (Part 2). Neither part claims "never stops" — Part 1 makes one turn go as far as it can; Part 2 makes the next turn resume automatically.

## Part 2 — Cross genuine turn boundaries: forge's own Stop hook (`/goal` is the fallback)

Some boundaries end the turn no matter how forceful Part 1 is: a background Dynamic Workflow running **async** (the turn ends; a task-notification resumes it later), a workflow **script approval** (the human is physically required), or the model simply yielding despite Part 1. Crossing these unattended needs a **Stop hook** — the one harness mechanism that can prevent a turn from ending. **forge now ships its own** (ADR-0028 amended 2026-08-22), so an unattended drive needs no user action; the harness `/goal` remains as the fallback.

- **The primary path: the drive writes a marker, forge's Stop hook blocks on it.** At entry the drive writes `<forge-root>/drive.md`; `hooks/hooks.json` dispatches the `Stop` event to `scripts/forge-hook-stop.sh`/`.js`, which returns **`exit 2`** — "prevent stopping, continue the conversation" — while that marker exists, is inside its bounds, and belongs to this session. **The shape of the marker and the full list of deletion points are defined once in each lane's SKILL.md** (fg-next `all` mode / fg-loop §2); this file owns only the mechanism.
- **Deleting the marker is how the drive says "I may stop now" — the hook never judges walls.** That split is deliberate: the hook stays dumb (marker present? inside bounds? mine?) instead of duplicating fg-status's state machine, because the riskiest thing forge ships should be the simplest. Consequently **every** drive exit must delete the marker — each wall, the terminal state, and any yield for something only a human can do (a script approval above all).
- **Two bounds, and they are the only runaway guard.** The marker carries `started:` (epoch) and `blocked:`; the hook releases at **30 minutes** or **50 blocked stops**, and on a session-id mismatch. They fix *different* failures — a session that dies mid-drive is cleared only by the age bound (the count survives a restart), while a drive re-deriving the same step is cut only by the count (the age bound would first burn 30 minutes). The harness offers **no** loop protection for Stop hooks (there is no `stop_hook_active`-style field), so forge carries this entirely.
- **Every failure path allows stopping.** No marker, bounds exceeded, another session's marker, an unparseable marker, a failed counter write, no usable clock, not a forge project → `exit 0`. This also composes with the harness's own semantics: `exit 0` proceeds and `exit 1` is a *non-blocking* error that also proceeds, so a crash in the hook degrades to "you may stop", never to a wedged session.
- **Consent is the `all` / `fg-loop` invocation itself — there is no toggle.** No config key, no toggle skill. `all` was already defined as "drive to the wall"; stopping after one cycle was a promise not kept, not the intent, so restoring it must not charge a toll. A drive that is not running writes no marker, so a session that never drives is untouched.
- **`/goal` is the fallback — state it when the hook cannot be relied on.** A skill still cannot set `/goal` itself (only the user types it), and the hook can be silently absent: it loads at **session start** (so a session that predates installing/updating forge has no hook — the same constraint as `.claude/agents/` cards, ADR-0024), the plugin may be disabled, or the harness may be older. Because that absence is silent by design, **when you have reason to think the hook is not live — most concretely, forge was just installed or updated in this session — present the paste-ready `/goal` line at drive entry** as before. Otherwise do not: printing it every time is noise once the hook does the work.
- **Phrase a `/goal` condition as "when may I stop," and make it release at the walls.** (Unchanged, and it applies to the fallback path.) The condition must name the **stopping** points: the drive's terminal state and each human-needed wall. **Enumerate the walls from the invoking lane's own set** — fg-next all and fg-loop differ; never copy the other lane's list. **Never phrase it as "until <terminal state>" alone** — that blocks stopping even at a safety wall, forcing the drive past a gate it must hand to a human (auto fix-and-re-run, sealing unverified work, auto-picking a fork — exactly what ADR-0009 / ADR-0010 / ADR-0016 forbid).
- **The honest fallback, stated plainly.** With neither the hook nor `/goal` live, the drive runs one cycle and the turn ends (most often right after a delegated handoff states its next step and the model yields, per Part 1's honest limit). **That pause is expected, not a failure**: re-issuing the drive trigger resumes statelessly, exactly where it left off.

```
drive entry
   │
   ▼
present frozen work ──▶ write <forge-root>/drive.md (primary path: forge's Stop hook)
   │                       └─ hook not live? (just installed/updated) ─▶ also offer the paste-ready /goal line (fallback)
   ▼
┌─▶ delegated step (run · verify · [lane's retro policy] · seal · derive next)
│      │ completed ──▶ DO NOT yield on the stated stop; derive next & continue (Part 1) ─┐
│      └─ genuine boundary (async workflow · script approval · yield despite Part 1) ──▶ turn would end;
│              Stop hook sees the marker ──▶ exit 2 blocks it, the drive continues (Part 2)
│              (bounds: 30 min · 50 blocked stops · other session ──▶ exit 0, stop allowed)
│      └─ wall (lane-defined) or terminal state ──▶ DELETE drive.md ──▶ STOP, report why, await human
└───────────────────────────────────────────────────────────────────────────────────────┘
```

## Part 3 — Per-task commit (opt-in): a rollback point the drive leaves behind

**Why.** When several tasks seal while nobody is watching, there is no per-task point to roll back to. Observed: a `fg-next all` drive sealed a task and made **no commit at all**, leaving 23 files uncommitted until an unrelated rule happened to commit them together. This is the **only** place forge touches git in a drive, and it is **off by default** — forge does not know your project's commit convention, branch policy, or what a pre-commit hook will reject. Rationale and the rejected alternatives (push, a tenth wall, an overloaded config key, inferred staging, every seal path): ADR `260901-213128`.

**Scope.** `fg-next all` and `fg-loop` only. Not the explicit single `/fg-done` (a human is present and a commit is one command), not `fg-done all` (it seals work executed days ago, so "changed by this task" is undefined), and not `fg-run` Run-all (it parks into `executed/`, it does not seal). **Commit only — a drive never pushes.** Rollback is complete at the local commit; pushing adds nothing to it and removes reversibility. A project that wants a push writes that in its own instructions, as this repo does.

**Config — two keys, read from the TOP-LEVEL `.forge/config.json`** (the same global-exemption path as `tdd` / `eco`, never the branch root):

- `driveCommit: true|false` — the toggle. **Strict boolean**, default `false`; anything other than `true` is off (the same parsing as `eco`, so a future script twin reads it the same way).
- `driveCommitMessage: "<template>"` — optional. Absent → the default format below. Placeholders are a **closed set of three**: `{title}` (the plan's `#` title), `{slug}` (its `forge-slug`), `{task}` (its `task:` number). An unknown placeholder → **fall back to the default format and warn in one line** (the default always works, so the safety net stays intact; a config typo must not halt a drive).

**Default message** — the plan's title plus the forge identifier, no prefix, **no body, no attribution**:

```
{title} (forge task #{task} · {slug})
```

No `chore(...)`-style prefix is assumed: forge does not know whether the project uses conventional commits. Where a project does enforce one, its commitlint rejects the commit and that routes to the wall below — the rejection is information. The identifier is what makes the rollback point findable later (`git log --grep '<slug>'`). Attribution lines are the project's convention, not the plugin's to stamp on every installer's history.

**Entry check — the drive decides ONCE, up front, whether it will commit at all.** At the same point the lane snapshots its drive set, run `git status --porcelain`:

- **empty** → commit per task for this drive. `git add -A` at each seal then **is** exactly "what this task changed", because nothing else was pending.
- **not empty** → **this drive makes no commits**; say so in one line alongside the snapshot ("the working tree has pre-existing changes, so this drive will not commit per task — clean the tree and re-run to get rollback points"). Never infer which files belong to the task: a plan's slices are prose, not a file list, and an inferred subset produces an **incomplete** rollback point, which is worse than none.

**At each seal, after the seal succeeds**, `git add -A` and commit. Two outcomes, and they are not the same thing.

**Tell them apart by ORDER, never by the message.** `git commit` exits `1` for *both* "nothing to commit" and "a hook refused" — measured — so exit code alone cannot classify, and parsing stdout/stderr text is brittle across git versions and locales. Instead: **`git add -A`, then check `git status --porcelain --untracked-files=all` for staged content; if there is none it is (a) and you never run `commit` at all. Only when something is staged do you commit, and then ANY failure is (b).** Misreading (b) as (a) is the one outcome this whole discipline exists to prevent — it would walk past a refused commit and seal anyway.


- **(a) nothing to commit** — the task changed no tracked file. This is a state, not a failure: **continue silently.** It can only happen on the default branch (a non-default branch root is git-tracked whole, so sealing itself changes tracked files — ADR-0011). This branch is also what makes a project-level commit rule (e.g. an issue-linked commit) compose without any special case: whichever commits first empties the tree, so the other becomes (a).
- **(b) the commit was refused** — a pre-commit hook rejected it, or the repo is mid-rebase/merge or on a detached HEAD. **Halt as a wall**, reported as the lane's existing `fork (<reason>)` — e.g. `fork (commit rejected — pre-commit hook)`. A refusal is the project saying "this change may not be committed", and the human chooses: fix the code, turn `driveCommit` off, or bypass the hook. No new wall is minted for this; `fork` already means "a consequential branch the drive must not pick" and both lanes already carry it. **Never continue past (b):** sealing empties the active slot, so committing nothing here would leave neither a rollback point nor forge state.

```
drive entry ──▶ git status --porcelain
   ├─ not empty ──▶ announce "no commits this drive" ──▶ drive normally, never commit
   └─ empty ──▶ per task:  seal ──▶ git add -A ──▶ anything staged?
                                      ├─ no  ──▶ (a) continue silently, never run commit
                                      └─ yes ──▶ commit
                                                  ├─ ok ──────▶ next task
                                                  └─ failed ──▶ (b) DELETE drive.md ──▶ wall: fork (commit rejected — <reason>)
```
