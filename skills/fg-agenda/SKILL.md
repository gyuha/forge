---
name: fg-agenda
description: A decision queue for foggy work — outside the forge loop. Settles the destination with you, grills breadth-first to surface what must be decided, and keeps it in .forge/agenda.md (destination · decided · open questions · fog · out of scope), resolving one question at a time via fg-ask until the way is clear, then deleting itself. The agent finds the decisions; you answer them. Use in contexts like 'forge agenda', '의제', '결정 대기열', '뭘 결정해야 하는지 정리해줘', '어디서 시작할지 모르겠다'.
---

# fg-agenda — decision queue (outside the loop)

This is **not** a stage of the forge loop (fg-ask → fg-run → fg-learn → fg-done). It is an **on-demand planning utility** — like fg-map and fg-loop — that gives forge a place for **a decision not yet made**. Everything forge produces today is a *build* artifact (`plan.md`'s Work slices) and an ADR records a decision **already made**, so work that is still in fog either gets forced into a prematurely-complete plan or its open decisions scatter across conversation and retro prose and vanish. fg-agenda keeps one file — a destination plus the open questions — and resolves them one at a time until the way is clear, then deletes itself.

**The agent's autonomy is in finding what must be decided; the human answers.** That split is the whole point of this skill, and it is structural here, not advice (see the Autonomy boundary and Prohibition 1).

**Why "agenda" — not "map", not "chart":** in forge, *map* already belongs to fg-map and `.forge/codebase/`, and reusing it would make two different things share one word in the same vocabulary. *Chart* was the first pick, since "charting" is the verb the source concept uses, but in the user's language 차트 reads as *a diagram* — and because a skill's `description` doubles as an auto-invocation trigger (ADR `260716-22a`), that name invites firing on "차트 만들어줘", which is fg-showme's space, not this skill's. *Agenda* is what this skill actually manages — the conversation's open decisions — so it is named after what it does.

The concepts — a destination with open tickets, fog, the frontier, and an explicit out-of-scope list — are adapted from the **Wayfinder** skill in `mattpocock/skills` (MIT). This is a **concept adaptation, not code vendoring**: no files were copied, and the mechanics are re-derived for forge's single-file, in-repo state (contrast fg-showme, which vendors actual upstream code with its LICENSE). forge's convention is to rename into its own vocabulary and credit the source in the document — the same way ECO.md is not called "caveman".

**Language**: This skill file is authored in English, but **you MUST write every message shown to the user — questions, status lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.** The documents it writes into the user's project (agenda.md and any ADR it produces) are written in the user's language, including the section headings.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Forge root**: every `.forge/...` path below is **relative to the resolved forge root** — `.forge/` on the default branch, `.forge/branch/<branch>/` on any other branch. `agenda.md` is branch-aware like `loop.md`, **not** a global exemption. Resolve it per `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/fg-run/FORGE-ROOT.md` (skill-relative `../fg-run/FORGE-ROOT.md`) before reading or writing it (ADR-0011).

## What it produces

- **`.forge/agenda.md`** — one file: the destination, what has been decided, what is still open, what is not yet sharp, and what was ruled out. Volatile state (gitignored on the default branch by the standard `.forge/*` policy; tracked whole on a branch root like the rest of that root).
- **One active agenda at a time**, mirroring forge's one-active-slot discipline. A second destination is a second agenda — finish or drop this one first.
- **When the way is clear — no open questions left — delete `agenda.md`.** Same as fg-loop deleting `loop.md` on goal-met. The durable trace is the **ADRs and backlog plans the agenda produced**; there is no agenda archive, and inventing one would just create a second graveyard of stale destinations.

## The two modes

Which mode you are in is decided by one thing: whether `.forge/agenda.md` already exists.

**Opening an agenda** (mode `open` — `fg-agenda` + a loose idea, no agenda yet) — this session **surfaces** decisions and resolves none of them:

1. **Settle the destination with the human first.** Ask it before anything else; the destination fixes the scope, and every later judgment ("is this out of scope?", "is this fog or a question?") is measured against it.
2. **Grill breadth-first.** Fan out across the whole space instead of going deep on one thread — the goal is coverage of *what must be decided*, not an answer to any one of them. **This step is what "the agent figures it out" actually means**, and it is the reason opening an agenda is worth a session.
3. **If no fog surfaces — do not create an agenda.** If the breadth-first pass turns up nothing that isn't already answerable, the way is already clear and the whole thing fits one session's work: say so plainly and point at fg-ask. An agenda with no fog in it is pure overhead.
4. **Write `agenda.md`** in the format below.
5. **Stop.** Opening an agenda is one session's work and resolves nothing. Do not slide into answering the questions you just found. **Say why you are stopping, not just that you are** — answering before the whole landscape is visible biases the answers (you narrow the scope on question one while question five, which would have changed it, is still unwritten). Without the reason on screen this reads as "it did half the job and told me to come back", which is exactly the repetition complaint that produced this rule. This is the one forced re-trigger in the skill, and it is paid for deliberately.

**Working the agenda** (mode `work` — `fg-agenda` with an agenda on disk) — resolve open questions **one at a time**, and by default **keep going until the user stops**:

**"One at a time" is about sequence, not about invocations.** Resolve one question, then open the next in the *same* conversation — the session ends when the user says so, or when `## Open questions` empties. This default matters: a session that stopped after every single question made the skill read as a treadmill (three invocations, three handoffs all pointing back at `fg-agenda`, while the open-question count went 5 → 6 → 7 → 8 — which is healthy early divergence, but nothing on screen said so). State how to stop **once**, in the first orientation block of the session; never re-ask it per question — "shall I continue?" at every turn is the pattern ADR-0015 removed, and here it would *increase* the sense of repetition rather than reduce it.

0. **Render the `orientation block`** — before *every* question, not only the first. It is the only orientation the user gets now that the session no longer ends after each question, and it is **derived entirely from `agenda.md`** — no new section, no new field (the same restraint Prohibition 2 applies to dependency edges, and the same call fg-loop made absorbing `waiting` into an existing ledger). Four values, canonical English name `orientation block`, rendered in the user's language:

   ```
   ▸ Agenda: {## Destination, one line}
     decided {N} · open {N} · fog {N}
     now: {the question being resolved}
   ```

   **This is not the handoff table.** The table renders once, at the end of the session (`../fg-next/HANDOFF.md`); the orientation block renders mid-conversation, before each question — so `HANDOFF.md` is untouched by it. On the session's first block only, append one line on how to stop.
   **Deliberate gap, so nobody "fixes" it by accident:** the block shows counts, not a *trajectory*. Whether `open 8` is shrinking or growing is not derivable — `agenda.md` keeps no history of the count — and persisting one would mean minting the section this skill refuses to mint. The dates on `## Decided` lines are the weak stand-in. Cross-session trajectory is a known, accepted blind spot.
1. **Read the agenda** and orient to `## Destination` before choosing anything.
2. **Choose one question.** If the user named one, that one. If not, **the agent picks** — the first line of `## Open questions` (the list is kept in answerable-now order, so the top line *is* the frontier).
3. **Resolve it by grilling** — fg-ask's method, by reference (see below). The **human** answers.
4. **Record the answer**: one line under `## Decided`, and delete the line from `## Open questions`. Write an ADR too **if** it clears the usual three-condition gate (hard to reverse · puzzling without context · a real tradeoff) — which is fg-ask's existing judgment, not a new one.
5. **Update the agenda**: add questions the answer newly surfaced, graduate fog that just became sharp into `## Open questions`, and move anything the answer revealed to be past the destination into `## Out of scope`.
6. **When a decision makes a build task specifiable, that is a backlog plan** — hand off to fg-ask to grill and load it, and drop the line from the agenda. The agenda does not carry buildable work (Prohibition 4).

```
fg-agenda <loose idea>                       agenda.md absent → OPENING
   │
   ▼
settle the DESTINATION with the human (first — it fixes scope)
   │
   ▼
grill BREADTH-FIRST across the space (fan out, never deep) → the open decisions
   │
   ├─ no fog surfaced ─▶ say so, point at fg-ask, write NO agenda ─▶ stop
   │
   ▼
write agenda.md (5 sections) ─▶ stop   (opening resolves nothing)


fg-agenda                                     agenda.md present → WORKING
   │
   ▼
read agenda.md ─▶ orient to ## Destination
   │
   ▼
choose ONE question: the user's pick, else the first line of ## Open questions
   │
   ▼
resolve by grilling (../fg-ask/SKILL.md) — the HUMAN answers
   │
   ▼
record: +1 line under ## Decided · delete from ## Open questions · ADR if the 3-condition gate clears
   │
   ▼
update the agenda: add newly-surfaced questions · graduate sharpened fog · move past-destination items to ## Out of scope
   │
   ├─ a decision made a build task specifiable ─▶ hand off to fg-ask (backlog plan) + drop the line
   │
   ▼
## Open questions now empty? ── yes ─▶ the way is clear: DELETE agenda.md, report
                              └─ no ─▶ next question in the SAME conversation (default) ─▶ user says stop ─▶ statement handoff
```

## The fog-vs-question test

An item belongs in `## Open questions` when **you can phrase the question precisely now** — **not** when you can answer it now. Those are different tests, and using the wrong one is how agendas rot:

- Sharp enough to phrase → **a question**, even if it is currently unanswerable (unanswerable-but-phrased is a normal, useful agenda line; ordering pushes it down, not out).
- Not phraseable yet → **`## Not yet sharp`**. It is still *inside* the destination — fog is scope you can see coming, not scope you rejected. That is what makes it different from `## Out of scope`.

## Format — `.forge/agenda.md`

Five sections, defined inline here (no separate `AGENDA-FORMAT.md` — the same call fg-loop makes for its `loop.md` template). The headings below are the **canonical names**; when writing an actual agenda, render them in the user's language.

```md
# AGENDA — {destination, one line}
started: {YYYY-MM-DD}

## Destination
{what reaching the end of this agenda looks like. One or two lines; every session orients to it before choosing a question}

## Decided
- {resolved question} — {the answer, one line} {link if it produced an ADR}

## Open questions
- {a decision answerable now, one line. Default resolver is fg-ask; name a different one on the line if needed}

## Not yet sharp
{fog — decisions you can see coming but cannot yet phrase as a question. In scope, just not sharp}

## Out of scope
- {consciously ruled past the destination + why. Never graduates}
```

`started` is stamped by the human at creation (skills can't read the clock) or left as a literal placeholder. `## Open questions` is kept in **answerable-now-first** order, which is why picking the top line needs no dependency bookkeeping (Prohibition 2).

## Autonomy boundary

Pillar #1 is untouched here: `agenda.md` manages **what the conversation must settle**, never the settling itself; the conversation still happens, one question at a time, outside any workflow.

| The agent does this on its own | The human does this |
| --- | --- |
| Surfacing the open decisions — breadth-first grilling | **Naming the destination** |
| Telling fog from a question (the test above) | **Every answer** |
| Ordering — answerable-now first | |
| Picking the next question when the user named none | |
| Graduating sharpened fog · ruling items out of scope | |

## Prohibitions

Each of these carries its reason, because a rule without its reason gets "cleaned up" by the next reader.

1. **The agent never answers its own question.** The source concept's own warning — *"a grilling agent that answers its own questions has broken this"* — is exactly forge's pillar #1. An agenda whose `## Decided` lines were written by the agent is not a decision queue; it is the agent's guesses wearing a decision's clothes. Surfacing the question is the agent's job; the answer is the human's.
2. **No dependency edges, no blocking.** Reading one file top-to-bottom **is** the frontier, so edges would add upkeep and nothing else — and a hard blocking graph locks the queue when one item stalls (the same reason ADR-0004 rejected forced sequencing for oversized tasks). Wayfinder needs native blocking because its tickets are separate issues that cannot see each other; a single file removes the need.
3. **No ticket-type taxonomy.** research / prototype / grilling / task are the names of *resolvers*, and forge already has the resolvers: conditional deep research (ADR-0006) · fg-showme · fg-ask · fg-quick. Adding a type field would be a second vocabulary for something already named. The default resolver is **fg-ask**; name another one only on the line that needs it.
4. **The agenda owns decisions, never build work.** The moment something is buildable it leaves the agenda and becomes an ordinary backlog plan (mode `work`, step 6). Without this line the agenda becomes a **second backlog**, and then fg-next / fg-run no longer know what to look at — the state contract's "one active slot, one backlog" stops meaning anything.

## Resolution reuses fg-ask's method — by reference, never by copying

The grilling method has a **single definition**: `../fg-ask/SKILL.md` (the verbatim grill-with-docs body — glossary challenge, sharpening fuzzy language, concrete scenarios, cross-referencing code, inline CONTEXT.md updates, sparing ADRs). Read it and follow it; do not restate or fork it here. This is the same single-definition convention as `FORGE-ROOT.md`, `ECO.md`, and the `*-FORMAT.md` docs.

Only the **output** differs. fg-ask's grilling ends in a backlog plan; an agenda question's grilling ends in **one line under `## Decided` plus a conditional ADR**. When the grilling instead reveals that the thing is now buildable, the output *is* a backlog plan — and that is precisely the point where fg-agenda hands off to fg-ask (mode `work`, step 6).

fg-agenda is deliberately **not** part of the fg-next / fg-status next-step chain: that chain is about the one task in flight, while an agenda is a parallel planning surface. fg-status reports a present agenda in one line and nothing more. Its sibling utility fg-loop is the mirror image — `loop.md` pins a **machine-verifiable** stop condition and drives **unattended**; `agenda.md` pins a **judgment** stop condition and is **human-in-the-loop** throughout. Same shape of contract file, opposite kind of stopping.

## Handoff

Render the **handoff table** per [`../fg-next/HANDOFF.md`](../fg-next/HANDOFF.md) — the single definition of its shape; never restate that layout here. Statement form, in the user's language — then **stop**. Never ask "shall I proceed?"; chaining is fg-next's job (ADR-0015).

The four cases differ only in what fills the cells:

- **No fog surfaced** → `Just did` = the way is already clear, so **no agenda was written**; `Next step` = `fg-ask`; `How to start` = `/forge:fg-ask`.
- **Agenda opened** (mode `open` done) → `Just did` = the destination, how many open questions and how much fog the agenda holds, **and that nothing was resolved this session** — opening an agenda resolves nothing, and that is its whole shape, so it belongs in the cell, not in a sentence a reader might skip; `Next step` = re-triggering `fg-agenda` works the top question; `How to start` = `/forge:fg-agenda`.
- **A question resolved** → this table renders when the **user stopped** the session (or the agenda cleared), not after every single question — the default is to keep going (see "Working the agenda"). So `Just did` = **how many questions were resolved this session** and what they decided, plus whether any produced an ADR; `Next step` = the next open question, worked the same way (`fg-agenda`) — or `fg-ask` when the resolution produced a specifiable build task, which then leaves the agenda; `How to start` = that skill's trigger. What changed in the agenda (new questions, graduated fog, out-of-scope moves) is list-shaped: put it **below** the table as bullets when there is more than one (HANDOFF.md, "List-shaped content goes below the table").
- **Agenda cleared** (open questions empty) → `Just did` = the way is clear and `agenda.md` was **deleted**, with the durable trace being the ADRs and backlog plans it produced; `Next step` = `fg-run` / `fg-next` for those plans; `How to start` = their triggers.

## Document impact

- Creates / updates / deletes **`.forge/agenda.md`** — the destination-and-questions file this skill owns (volatile; deleted when no open questions remain). Opening an agenda may legitimately create nothing at all (no fog → no agenda).
- May create an ADR under `.forge/adr/` when a resolved question clears the three-condition gate, and may update `.forge/CONTEXT.md` inline when grilling sharpens a term — both under fg-ask's existing rules and formats (`../fg-ask/ADR-FORMAT.md`, `../fg-ask/CONTEXT-FORMAT.md`), never a new format of its own.
- **Writes no loop state.** It never touches `plan.md`, `run.md`, `STATUS.md`, `backlog/`, `executed/`, or `done/`. A buildable decision becomes a backlog plan **through fg-ask**, which owns that write.
