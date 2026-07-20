# ADR Format

ADRs live in `.forge/adr/`. Each has a unique **ID** used as its filename prefix (`<id>-slug.md`) and its citation (`ADR-<id>`). Two ID formats coexist (see Numbering):

- **Time-based** (current) — `YYMMDD-HHMMSS` (2-digit year/month/day + 24-hour hour/minute/second from the wall clock), plus a lowercase serial letter **only on a same-second collision**, e.g. `260719-161701` (bare, the common case) or `260719-161701a` (a second ADR minted in the same second). Coordination-free: minted from the wall clock, so parallel branches never collide on a shared counter, and the ID is fixed at creation, so cross-references almost never need rewriting — the one exception is the rare same-second cross-branch clash (see Numbering).
- **Time-based, hour-granularity** (grandfathered) — an earlier variant, `YYMMDD-HH` + an **always-present** letter, e.g. `260716-14a`. The ADRs minted before the second-granularity switch keep these IDs, frozen (ADR `260719-161701`); no new ADR is minted this way.
- **Sequential `NNNN`** (grandfathered) — `0001`, `0002`, … The ADRs created before any time-based scheme keep their numbers, frozen; no new ADR is minted this way.

Create the `.forge/adr/` directory lazily — only when the first ADR is needed.

## Template

```md
---
author: {git config user.name at creation — the person who made the decision}
decided: {YYYY-MM-DD HH:MM}
---
# {Short title of the decision}

{1-3 sentences: what's the context, what did we decide, and why.}
```

That's it. An ADR can be a single paragraph. The value is in recording *that* a decision was made and *why* — not in filling out sections.

The `author`/`decided` frontmatter is the decision's **provenance** — who made it and when. It is filled at creation (`author` from `git config user.name`, `decided` = the date and time **to the minute**, e.g. `2026-07-19 16:17`) and travels in the file body, so it survives fg-merge moving/renaming the file — unlike git blame, which fg-merge's file moves and a PR squash/rebase can blur. Grandfathered `NNNN` ADRs predate this and simply have no such frontmatter (not backfilled); grandfathered hour-granularity ADRs may carry a date-only `decided`.

## Optional sections

Only include these when they add genuine value. Most ADRs won't need them.

- **Status** frontmatter (`proposed | accepted | deprecated | superseded by ADR-NNNN`) — useful when decisions are revisited
- **Considered Options** — only when the rejected alternatives are worth remembering
- **Consequences** — only when non-obvious downstream effects need to be called out

## Numbering (ID minting)

New ADRs use the **time-based ID**: `YYMMDD-HHMMSS` (2-digit year, month, day + 24-hour hour, minute, second from the wall clock at creation), plus a lowercase **serial letter only on a same-second collision**. Mint it so:

1. Compute the `YYMMDD-HHMMSS` prefix from the current time (local wall clock, 24-hour).
2. If no existing ADR ID has that exact prefix — **including `retired/`** — use it **bare** (no letter). This is the common case: second-granularity makes collisions rare, so a bare ID means "nothing else was minted this second."
3. On a same-second collision — a batch of ADRs minted within one second, or a cross-branch clash surfaced at merge — append the **next free lowercase letter** (`a`, then `b`, …) to the colliding ADR (the one already written stays as-is). There is no sequential cascade renumbering; the ID is stable from creation, so cross-references do not break — except in the rare same-second cross-branch clash, where only the bumped ADR's own citations need updating (one letter, not a cascade).

**Two grandfathered formats are frozen and coexist with the current one** — never renumbered, never reused: the hour-granularity time-based IDs (`YYMMDD-HH` + an always-present letter, e.g. `260716-14a`) and the sequential `NNNN`. Because IDs are minted from the clock rather than a global `max+1` counter, parallel branches mint non-colliding IDs without coordination. fg-merge integrates incoming ADRs by moving them as-is (bumping the letter only on the rare exact-second clash) rather than a cascade renumber — done by the deterministic `forge-merge.sh`/`.js` (which also lets CI integrate branches AI-free). Retired IDs (any format) are never reused (see fg-cleanup).

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
