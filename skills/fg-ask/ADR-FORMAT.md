# ADR Format

ADRs live in `.forge/adr/`. Each has a unique **ID** used as its filename prefix (`<id>-slug.md`) and its citation (`ADR-<id>`). Two ID formats coexist (see Numbering):

- **Time-based** (current) — `YYMMDD-HH` + a lowercase sequence letter, e.g. `260716-14a`. Coordination-free: minted from the wall clock, so parallel branches never collide on a shared counter, and the ID is fixed at creation, so cross-references almost never need rewriting — the one exception is the rare same-hour cross-branch clash (see Numbering).
- **Sequential `NNNN`** (grandfathered) — `0001`, `0002`, … The ADRs created before the time-based scheme keep their numbers, frozen; no new ADR is minted this way.

Create the `.forge/adr/` directory lazily — only when the first ADR is needed.

## Template

```md
---
author: {git config user.name at creation — the person who made the decision}
decided: {YYYY-MM-DD}
---
# {Short title of the decision}

{1-3 sentences: what's the context, what did we decide, and why.}
```

That's it. An ADR can be a single paragraph. The value is in recording *that* a decision was made and *why* — not in filling out sections.

The `author`/`decided` frontmatter is the decision's **provenance** — who made it and when. It is filled at creation (`author` from `git config user.name`, `decided` = that day) and travels in the file body, so it survives fg-merge moving/renaming the file — unlike git blame, which fg-merge's file moves and a PR squash/rebase can blur. Grandfathered `NNNN` ADRs predate this and simply have no such frontmatter (not backfilled).

## Optional sections

Only include these when they add genuine value. Most ADRs won't need them.

- **Status** frontmatter (`proposed | accepted | deprecated | superseded by ADR-NNNN`) — useful when decisions are revisited
- **Considered Options** — only when the rejected alternatives are worth remembering
- **Consequences** — only when non-obvious downstream effects need to be called out

## Numbering (ID minting)

New ADRs use the **time-based ID**: `YYMMDD-HH` (2-digit year, month, day, hour from the wall clock at creation) plus a lowercase **sequence letter**. Mint it so:

1. Compute the `YYMMDD-HH` prefix from the current time.
2. Scan every existing ADR ID **for that same hour** — **including `retired/`** — and assign the next free letter (`a` if none, else `b`, `c`, …; roll to `aa` past 26, not expected). The letter is **always present**, even for the only ADR that hour, because same-hour ADRs are common.
3. On any collision with an existing ID — a batch of ADRs written in the same hour, or a cross-branch clash surfaced at merge — the rule is the same: **take the next free letter**. There is no sequential cascade renumbering; the ID is stable from creation, so cross-references do not break — except in the rare same-hour cross-branch clash, where only the bumped ADR's own citations need updating (one letter, not a cascade).

**Grandfathered `NNNN` ADRs are frozen** — never renumbered, never reused — and the two formats coexist. Because IDs are minted from the clock rather than a global `max+1` counter, parallel branches mint non-colliding IDs without coordination. fg-merge integrates incoming ADRs by moving them as-is (bumping the letter only on the rare exact-hour clash) rather than a cascade renumber — done by the deterministic `forge-merge.sh`/`.js` (which also lets CI integrate branches AI-free). Retired IDs (either format) are never reused (see fg-cleanup).

## When to offer an ADR

All three of these must be true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will look at the code and wonder "why on earth did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If a decision is easy to reverse, skip it — you'll just reverse it. If it's not surprising, nobody will wonder why. If there was no real alternative, there's nothing to record beyond "we did the obvious thing."

### What qualifies

- **Architectural shape.** "We're using a monorepo." "The write model is event-sourced, the read model is projected into Postgres."
- **Integration patterns between contexts.** "Ordering and Billing communicate via domain events, not synchronous HTTP."
- **Technology choices that carry lock-in.** Database, message bus, auth provider, deployment target. Not every library — just the ones that would take a quarter to swap out.
- **Boundary and scope decisions.** "Customer data is owned by the Customer context; other contexts reference it by ID only." The explicit no-s are as valuable as the yes-s.
- **Deliberate deviations from the obvious path.** "We're using manual SQL instead of an ORM because X." Anything where a reasonable reader would assume the opposite. These stop the next engineer from "fixing" something that was deliberate.
- **Constraints not visible in the code.** "We can't use AWS because of compliance requirements." "Response times must be under 200ms because of the partner API contract."
- **Rejected alternatives when the rejection is non-obvious.** If you considered GraphQL and picked REST for subtle reasons, record it — otherwise someone will suggest GraphQL again in six months.
