---
name: issue-triage
description: Review the open GitHub issues of the current repo and triage them — classify, summarize, and score each one's fix-worthiness against the project's own docs — then print a ranked report so you can decide which to act on. Read-only: it fetches via the `gh` CLI and writes nothing (no files, no labels, no comments). It never fixes, comments, closes, or opens PRs — judgment and the fix stay with you. Use when you want to review/triage GitHub issues or decide which are worth fixing, in contexts like 'issue triage', 'triage issues', 'which issues to fix', 'review open issues', '이슈 트리아지', '이슈 검토', 'gh 이슈 정리', '어떤 이슈 고칠지'.
---

# issue-triage — read-only GitHub issue triage reporter

A small **local project skill** (lives in `.claude/skills/`, not part of the forge `fg-*` plugin and not shipped to plugin installers). Run it on demand to look over the repo's open GitHub issues and get a ranked, reasoned triage — then *you* pick what's worth doing and hand it to the normal workflow (`fg-ask` → forge loop, or fix it directly).

**It is read-only.** It fetches issues through `gh` and prints a report. It **writes nothing** — no files, no GitHub labels/comments, no issue state changes, no PRs. It does **not** decide "this will be fixed" and it does **not** fix anything: the fix-worthiness call and the fix itself are yours (the same human-judgment boundary forge keeps).

**Language**: respond in the user's language (detect it from their messages) — this file is authored in English, but the report and any prompt you show are written in the user's language.

## Prerequisite — `gh`

This skill needs the GitHub CLI, authenticated for the current repo.

- Check once at the start: `gh auth status` (and that the cwd is a GitHub repo — `gh repo view --json nameWithOwner -q .nameWithOwner`).
- If `gh` is missing or not authenticated, **stop with one line** of guidance — e.g. "issue-triage needs the GitHub CLI: install `gh` and run `gh auth login`, then re-run." Do not try to work around it. (This skill is the only thing that needs `gh`; its absence blocks nothing else.)

## What it does

### 1. Fetch the open issues

- `gh issue list --state open --limit 50 --json number,title,labels,author,createdAt,updatedAt,comments` for the list.
- For each issue you'll actually triage, pull the body and discussion: `gh issue view <number> --json title,body,labels,comments`.
- Keep it to **open** issues — closed ones are out of the queue (GitHub's open/closed state *is* the queue; there is no local inbox).

### 2. Read the project's own bar

Before scoring, skim what the project already decided, so triage is measured against *this* project, not generic taste:

- `.forge/CONTEXT.md` (domain glossary, if present) — does the issue's language match the project's?
- `.forge/adr/*.md` (architecture decisions, if present) — does the request align with or contradict a recorded decision? An issue asking for something an ADR explicitly rejected is low-worth (cite the ADR).
- `README` / `CLAUDE.md` — scope and conventions.

If none exist, triage on general engineering judgment and say so.

### 3. Triage each issue

For each open issue, judge:

- **Classification** — `bug` / `feature` / `question` / `docs` / `noise` (spam, off-topic, duplicate).
- **Summary** — one line: what is actually being asked.
- **Fix-worthiness** — a score `high` / `medium` / `low` **with a one-line reason** grounded in: is it a real, reproducible problem? does it align with project scope/ADRs (or fight them)? is there enough information to act? Severity × clarity × alignment.
- **Effort** — rough `S` / `M` / `L`.
- **Recommendation** — one of: `→ fix (worth grilling)` / `→ needs info (ask the reporter)` / `→ wontfix (reason)` / `→ already in flight`.

**Lightly filter what's already handled.** Skip or mark issues whose work already exists in forge state — match the issue number or its slug against `.forge/backlog/*.md`, `.forge/plan.md`, and `.forge/done/*/` (e.g. an issue referenced by a sealed task). Mark these `→ already in flight` rather than re-triaging from scratch.

### 4. Print the ranked report

Sort by fix-worthiness (`high → medium → low`), then print a compact table (in the user's language):

```
#   | Class   | Worth  | Effort | Issue (title)                    | Recommendation
#42 | bug     | high   | S      | crash on empty config            | → fix (worth grilling)
#39 | feature | medium | M      | add --json output                | → needs info (use case?)
#31 | feature | low    | L      | plugin marketplace mirror        | → wontfix (contradicts ADR-0011)
#28 | question| —      | —      | how to install on Windows?       | → answer in thread (no code)
```

Under the table, give a 2–3 line synthesis: how many are genuinely worth fixing now, any recurring theme, and the single one you'd start with — but make clear **the call is the user's**.

### 5. Hand off (you don't act)

Close with: the user picks a worthy issue and starts the real work — for this repo that's **`fg-ask`** (grill it into a plan, seeding the grilling with the issue number/summary), then the forge loop runs and seals it; for a trivial change, fix it directly. issue-triage stops here — it has only reported.

## What it does NOT do

- No writing of any kind — no files, no `.forge/` state, no GitHub labels/comments/edits/closes, no PRs.
- No auto-fixing and no auto-deciding "this gets fixed" — that judgment is the user's.
- No scheduling/polling/webhooks — it runs only when you invoke it.
- GitHub only (via `gh`); no other tracker.
