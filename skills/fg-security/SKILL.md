---
name: fg-security
description: Domain-specialised security audit of a codebase, outside the forge loop — a vendored multi-phase methodology (recon → parallel attack-class hunting → independent validation → machine-readable findings) whose findings, past a severity gate and your approval, become fix-forward backlog plans. Artefacts stay OUTSIDE the repo (upstream's ~/security-audit-skill/) so a vulnerability list has no path into a commit at all. Always skipped in fg-next all / fg-loop. Use in contexts like 'forge security', 'fg-security', '보안 감사', '취약점 찾아줘', 'security audit'.
---

# fg-security — security audit (outside the loop)

This is **not** a stage of the forge loop. It is an on-demand utility (like `fg-map` / `fg-adversarial-review`) that audits a **whole codebase** for exploitable vulnerabilities and feeds what matters back into the loop as ordinary backlog work.

**The methodology is not forge's.** It is [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill), vendored here under MIT (see `LICENSE`): a six-phase, multi-agent audit with attack-class playbooks, independent verification, and a machine-readable findings schema. **Read [`AUDIT.md`](./AUDIT.md) and follow it** — that file is the audit's single definition and this skill never restates or forks it (the same file-reference convention as `../fg-eco/ECO.md` and `../fg-visual/VISUAL.md`). Do **not** edit `AUDIT.md` or its eleven sibling files: they are kept byte-for-byte with upstream so a future diff stays cheap, and forge's own glue lives here instead. Rationale: `.forge/adr/260820-215004-fg-security-vendored-audit.md`.

**What forge adds** is exactly three things — everything else is upstream's:

1. findings are routed into the forge loop instead of stopping at a report,
2. findings past a **severity gate** become **fix-forward backlog plans** on your approval,
3. a documented position in the unattended lanes (always skipped).

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, findings summaries, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** `AUDIT.md`'s procedure is followed as written; its *output to the user* is rendered in the user's language, and any backlog plan this skill produces is written in the user's language.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Not a gate.** Like `fg-adversarial-review` (ADR-0018), this never blocks a seal: the seal gates stay `verified:` and the retro. An audit is something you choose to run.

## Where the audit writes — outside the repo, by construction

**Do not override `AUDIT.md`'s output-directory step.** Use upstream's default: `~/security-audit-skill/<repo-name>/run-<N>/`. Everything upstream names goes there unchanged — `architecture.md`, `REPORT.md`, `FINDINGS-DETAIL.md`, `findings.json` — and its multi-run behaviour is preserved (read prior runs' `findings.json` to skip known findings and target gaps).

**The reason is the whole point of this skill, so do not "improve" it back into the repo.** An audit report is a list of exploitable vulnerabilities. A path **inside** the repo can never be made safe *by construction* — it is safe only if that repo's `.gitignore` happens to exclude it, and forge **never writes a `.gitignore` into a user's project**. An earlier version of this skill wrote to `.forge/security/` and asserted "no `.gitignore` change is needed"; that was true only in forge's *own* repo, and false in exactly the repos this skill is for (ADR `260820-215004`, amended 2026-08-20). A path **outside** the repo has no commit path at all.

Two traps that produced that mistake — both worth naming so they are not repeated:

- **A "global exemption" (ADR-0011) is about branch namespacing, NOT about git-tracking.** Two of the existing exemptions (`!.forge/codebase/`, `!.forge/config.json`) are global *and tracked*. Reading the two as one concept is what turned a conditional assumption into an unconditional guarantee.
- **`.gitignore` tracks a non-default branch's forge root whole** (`!.forge/branch/`), so anything under the branch-aware root is committed on a branch regardless.

**The accepted cost, stated plainly:** artefacts live outside the repo, so they do not travel with a clone and a teammate cannot read them — and being in a home directory, they are easy to forget. Mitigate the second by **always naming the exact run path in the handoff**, never just "the report". This is the same trade upstream already made; forge does not second-guess it.

## Severity gate — which findings become forge work

Upstream produces severity-ranked findings. Present them, then convert **only** past this gate, and **only** with the human's approval (never automatically — ADR-0018's discipline):

| Severity | What happens |
| --- | --- |
| CRITICAL · HIGH | Offer a backlog plan each — **grouped when several share one code path or one fix** |
| MEDIUM | Offer, but **recommend grouping** by file / data flow |
| LOW · INFO | Stays in the report only — **no plan** |

This is the same promotion bar forge applies everywhere (retro promotion, the ADR three-condition gate, CONTEXT.md terms): promote everything and the things that matter get buried. It is also what keeps a real audit — 5 to 20 findings — from flooding the backlog and making the one-active-slot discipline meaningless.

Each approved plan is an ordinary backlog plan per [`../fg-run/PLAN-FORMAT.md`](../fg-run/PLAN-FORMAT.md), carrying:

- `<!-- generated-by: fg-security -->` for provenance (same shape as `generated-by: fg-adversarial-review`),
- the next monotonic `<!-- task: N -->` (scan `backlog/`, the active slot, `executed/`, `done/`; ADR-0005),
- a **Definition of Done of "the vulnerability no longer reproduces"**, phrased so it can be checked *without* the exploit being written down: "re-run this finding's reproduction per the report; it no longer triggers". That is what lets fg-run's UAT reach a sealable `verified:` (ADR-0009) instead of a vague "looks fixed".

**Never copy the exploit into the plan (ADR `260820-215004`, amended 2026-08-20).** Reference the finding by **run and index only** — `~/security-audit-skill/<repo>/run-3/` finding 2 — and never inline the data flow, the payload, or the reproduction commands from `FINDINGS-DETAIL.md`. Once the report itself lives outside the repo, **a generated plan is the only in-repo carrier of vulnerability detail left**, and on a non-default branch `backlog/` is git-tracked whole (`!.forge/branch/`) — so an inlined repro would be committed while the report it came from is not. Describing the *fix* ("validate `X` before `Y` at `file:line`") is not an exploit recipe; describing the *attack* is. The cost is that the plan is no longer self-contained — fg-run's UAT must open the report to know what to re-run — and that is the intended trade: self-containment is convenience, disclosure is irreversible.

Then `fg-run` picks them up like any other plan. Do not run the fixes here.

## Unattended lanes — always skipped

`fg-next all` (ADR-0010) and `fg-loop` (ADR-0016) **never run this audit**, the same way they auto-skip the retro: judging which findings are real and which deserve a fix is human work, and an unattended drive cannot make that call. It is invoked deliberately, by a human.

```
fg-security
   │
   ▼
follow AUDIT.md (upstream, unedited) — recon → parallel attack-class hunting → validation → report
   │  output dir = upstream default ~/security-audit-skill/<repo>/run-<N>/  (OUTSIDE the repo — no commit path exists)
   ▼
present severity-ranked findings
   │
   ├─ CRITICAL/HIGH ─▶ offer plan(s), grouped by shared fix ──┐
   ├─ MEDIUM        ─▶ offer, recommend grouping ─────────────┤─▶ human approves ─▶ backlog plan(s)
   └─ LOW/INFO      ─▶ report only, no plan                   │   (generated-by · monotonic task · DoD = no longer reproduces)
                                                              ▼
                                                      fg-run runs them
```

## Handoff

Render the **handoff table** per [`../fg-next/HANDOFF.md`](../fg-next/HANDOFF.md) — the single definition of its shape; never restate that layout here. Statement form, in the user's language, then **stop** (chaining is `fg-next`'s job — ADR-0015).

`Just did` is the one-line verdict: how many findings by severity, and the exact run path the report landed in (`~/security-audit-skill/<repo>/run-<N>/` — name it in full; a home-directory path is easy to lose). Fill the rest from the **first matching case**:

- **Plans were approved** → `Next step` = `fg-run`, to run them; `How to start` = `/forge:fg-run`; omit `Alternative`.
- **Findings exist but none were converted** (all LOW/INFO, or the human declined) → `Next step` = nothing is owed; a new task starts with `fg-ask`; `How to start` = `/forge:fg-ask`; omit `Alternative`.
- **No findings** → same as above, and say plainly that a single run finds roughly half of what multiple runs do (upstream's own measurement), so re-running later is worthwhile — as a line **below** the table, not a cell.

The findings themselves are list-shaped, so they go **below** the table as bullets (HANDOFF.md's rule): one line per CRITICAL/HIGH/MEDIUM finding with its severity, location, and whether it became a plan. Never compress them into a cell.

## Document impact

- Creates `~/security-audit-skill/<repo-name>/run-<N>/` — `architecture.md`, `REPORT.md`, `FINDINGS-DETAIL.md`, `findings.json`. **Outside the repo and outside `.forge/`**, so no `.gitignore` rule is relied on and no commit path exists (ADR `260820-215004` amended 2026-08-20; the explicit exception to ADR-0001 is recorded there). forge writes **nothing** into the repo for an audit.
- On the human's approval, creates `.forge/backlog/<slug>.md` plans (`<!-- generated-by: fg-security -->`, monotonic `task:`) — picked up by `fg-run`.
- Touches **no** loop state: never `plan.md`, `run.md`, `STATUS.md`, `executed/`, or `done/`. It is not a stage.
- Does not modify the vendored `AUDIT.md` or its sibling files.
