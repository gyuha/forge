# Retro Log Format

> For `fg-learn` only. Retro logs are stored as per-session files at `docs/retro/YYYY-MM-DD-slug.md`.

Documents are written in the user's language; the headings below are canonical English names — render them in the user's language.

## Location and naming

- Path: `docs/retro/{YYYY-MM-DD}-{slug}.md`
- `slug` is a kebab-case identifier that makes the task recognizable at a glance (e.g. `settlement-payout-split`)
- If there are multiple tasks on the same day, the slug distinguishes them
- The `docs/retro/` directory is created lazily — only when the first retro is needed

## Template

```md
# {YYYY-MM-DD} — {one-line summary of the task}

## Plan vs actual
- What went as planned:
- Divergences:

## Learnings
- Do differently next time:

## Doc updates
- CONTEXT.md promotion: {term or none}
- ADR added: {ADR-NNNN or none}
```

## Rules

- **An uneventful session gets one line.** A retro is not a ritual. If everything went to plan and there was nothing to learn, record it briefly and move on.
- **Keep promotion discipline.** Do not push everything from a retro into CONTEXT.md/ADR. Every learning that doesn't clear the bar stays in this retro log — that is the reason this retro log exists.
- **"Do differently next time" and "Divergences" are fuel the next loop reads.** Failing to be promoted does not mean they're buried — the next task's fg-ask grilling and fg-execute workflow composition read these two fields from retros in the same area as a starting point. So write them concretely enough that the next task can use them directly (what diverged, why, and how to handle it next time) instead of vague impressions.
- **Avoid polluting CONTEXT.md.** Record implementation details in the retro log, but do not put them into the glossary (CONTEXT.md).
- **Decide what to promote together with the human.** Don't push automatically — propose and get confirmation.

## Promotion criteria (summary)

| Nature of the learning | Destination | Criterion |
| --- | --- | --- |
| New/changed domain term | `CONTEXT.md` | Only when it's a context-specific concept. Exclude general concepts and implementation details |
| A decision that is hard to reverse, puzzling without context, and a real tradeoff | `docs/adr/NNNN-slug.md` | Only when all three conditions are met |
| Process/session learning | `docs/retro/YYYY-MM-DD-slug.md` | If it's worth recording (= here, the retro log) |

For CONTEXT.md/ADR formats, see `../fg-ask/CONTEXT-FORMAT.md`/`../fg-ask/ADR-FORMAT.md`.
