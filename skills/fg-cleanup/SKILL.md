---
name: fg-cleanup
description: Retires stale or superseded ADRs out of the active decision set — proposes candidates with rationale, and on your approval moves each to .forge/adr/retired/ (IDs never reused, nothing deleted). fg-ask stops reading retired/ as source of truth, so retired decisions drop out of grilling fuel. On-demand utility outside the loop (sealing a task is fg-done, not this). Use in contexts like 'forge cleanup', 'ADR 정리', '오래된 ADR 치워'.
---

# fg-cleanup — retire stale ADRs (outside the loop)

This is **not** a stage of the forge loop (fg-ask → fg-run → fg-learn → fg-done). It is an **on-demand utility** — like fg-map and fg-merge — that tends the permanent-doc fuel: it retires ADRs that no longer apply so the active decision set in `.forge/adr/` stays current, while preserving the *why* of every past decision. Sealing a finished task (closing its STATUS, archiving, emptying the active slot) is **fg-done**, not this skill (see ADR-0012 for why the name moved here).

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** The candidate list, rationale, and any confirmation question are written in the user's language.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Forge root**: ADRs live under the resolved forge root — `.forge/adr/` on the default branch, `.forge/branch/<branch>/adr/` on any other branch. Resolve it per `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before reading or moving any ADR.

## First, confirm intent (avoid the muscle-memory trap)

The utterance `forge cleanup` used to seal a finished task — that job is now **fg-done**. So before doing anything, open with one line, in the user's language, so they aren't surprised: *"This is the ADR-retirement utility — it retires stale ADRs, it does not seal a task (use `fg-done` for that). Proceed?"* If they actually wanted to seal a task, point them to fg-done and stop.

## Behavior — propose candidates, the human approves (A+)

Retirement is **human-approved, never automatic**. Whether an ADR "no longer applies" is a meaning judgment; an LLM deciding it alone risks killing a live decision. So this skill only *proposes*, with evidence — the same restraint as fg-merge's "mechanical auto, genuine conflict asks the human."

1. **Scan the active ADRs.** Read every `.forge/adr/*.md` at the top level (not `retired/`). For each, look for retirement signals: another ADR that supersedes/contradicts it, a `Status: superseded by ADR-NNNN` already noted, or a decision the codebase has clearly moved past.
2. **Present candidates, one line each, with rationale.** e.g. *"ADR-0003 (fg-quick lane) — looks superseded by ADR-0009's verification gate? (your call)"*. Be honest when there are **no** clear candidates — "nothing looks retirable; these are an additive decision log" is a valid, common outcome (don't manufacture retirements).
3. **The human picks** which to retire (any subset, possibly none). Only approved ADRs are touched.

## Retiring an approved ADR

For each approved ADR:

- **Move it to `.forge/adr/retired/<NNNN>-slug.md`** — same filename, keep the directory under `adr/` (so the `!.forge/adr/` gitignore whitelist still tracks it; create `retired/` lazily on first retirement).
- **Add a one-line status marking at the top**: `Status: Superseded by ADR-NNNN` when there is a successor, or `Status: Retired (<reason>)` when the decision simply no longer applies (no successor required).
- **IDs never change and are never reused.** ADR-0003 stays `0003` even under `retired/`. New ADRs no longer mint from a `max+1` counter — they use **time-based IDs** (`YYMMDD-HH`+letter; see ADR-FORMAT.md), so there is no "gap" left behind by retirement; but a retired ID (whether a grandfathered `NNNN` or a time-based one) is **still never reused** — when minting a new letter for a given hour, the `retired/` scan must be included to avoid a collision. Reconciling a merge-time ID collision (next-free-letter, not a cascade renumber) is fg-merge's job for branch merges — a different situation — and is **not** done here.
- **Do not rewrite inbound cross-references.** Other docs cite ADRs by *ID* (`ADR-0003` or `ADR-260716-14a`), so moving the file to `retired/` does not break those citations — path rewriting (fg-merge style) would be over-engineering.

Retired ADRs drop out of fg-ask's grilling fuel: fg-ask reads only `.forge/adr/*.md` (top level) as source of truth and does **not** read `retired/`. The history stays on disk for archaeology ("why did we decide that back then?") — retirement is removal from the *active set*, not deletion.

```
forge cleanup
   │
   ▼
Confirm intent (this retires ADRs; sealing a task is fg-done) ── wanted to seal? ──▶ point to fg-done → stop
   │ proceed
   ▼
Scan .forge/adr/*.md (top level) → propose retirement candidates with rationale (or "none")
   │
   ▼
Human approves a subset (possibly none)
   │ none ──▶ report "nothing retired" → end
   │ some
   ▼
For each: move → .forge/adr/retired/<NNNN>-slug.md  +  top marking (Superseded by NNNN / Retired (reason))
   │ (numbers unchanged, not reused; no cross-ref rewrite; nothing deleted)
   ▼
Report what was retired and where → end
```

## Document impact

- Moves approved ADRs `.forge/adr/<NNNN>-slug.md` → `.forge/adr/retired/<NNNN>-slug.md` with a one-line status marking. Lazy-creates `retired/`.
- Creates/changes nothing else — no loop state (`plan/run/STATUS/backlog/done`) is touched. This is a permanent-doc utility, not a loop stage.
- `.forge/adr/` (including `retired/`) is git-tracked via the `!.forge/adr/` whitelist, so retirements are committed like any other ADR change.

For the ADR format, read `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/ADR-FORMAT.md` (skill-relative `../fg-ask/ADR-FORMAT.md`) — do not copy it here.
