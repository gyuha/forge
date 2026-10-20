# Follow-up ledger

> Single definition for `fg-run`, `fg-learn`, `fg-done`, `fg-ask`, and drives.
> A candidate is proposed future work, not an approved plan or a glossary/ADR promotion.

## Location and lifetime

Store candidates in `<resolved-forge-root>/followups.md`, resolving the root
through [../fg-run/FORGE-ROOT.md](../fg-run/FORGE-ROOT.md). Create it only when
there is a candidate. It survives sealing and is git-tracked: on the default
branch ensure `.gitignore` allows `!.forge/followups.md` after `.forge/*`; on
other branches the entire branch root is already tracked.

The ledger is branch-local, without the permanent-doc read overlay. Do not copy
main's ledger wholesale into a branch: its task numbers belong to a different
root. `fg-merge` integrates branch candidates and remaps source and taken task
references with the branch's task mapping. IDs, source slugs, and dates survive.

## Entry format

```md
# Follow-ups

<!-- followup: fu-012345abcdef | source: example-task | task: 7 | date: 2026-10-20 | status: open | taken: - -->
- Add a regression check for the remaining retry case.
  Evidence: the timeout branch remains uncovered in the sealed run.
```

The marker is one line, with exactly the shown field order and separators.
Field names and values are language-neutral; write the body in the user's
language. Each entry's body continues until the next marker or EOF. Therefore
candidate blocks in `run.md` or a retro MUST be the final section; never place
unrelated prose after them. Headings before the first marker are presentation
only and are never used to detect candidates.

- `followup`: immutable `fu-` plus 12 lowercase hexadecimal digits. Generate once
  (the `add` command can generate it), then reuse that ID in the run, retro,
  ledger, and plan provenance. Do not mint a new ID when copying a candidate.
- `source`: the originating plan's `forge-slug`, not the new task's slug.
  Unicode is allowed; whitespace, `|`, `<`, `>`, `/`, `\`, a leading dot, and
  `..` are forbidden so the token cannot become a path or marker delimiter.
- `task`: the originating plan's positive integer `task`, or `-` for a legacy
  plan without a number. Never guess a missing number.
- `date`: discovery date, `YYYY-MM-DD`; preserve it on updates. The parser checks
  the shape; the producer supplies the real discovery date.
- `status`: exactly `open`, `taken`, or `dismissed`.
- `taken`: a positive destination task number only when status is `taken`;
  otherwise `-`. It means planned, not executed or completed.

## Write and replay rules

Use `scripts/forge-followups.sh` (bash) or its `.js` twin (node fallback),
resolved from the loaded plugin root. They share these commands:

```sh
bash "$FORGE_PLUGIN_ROOT/scripts/forge-followups.sh" add --source example-task --task 7 --date 2026-10-20 --text 'Investigate the remaining retry case.'
bash "$FORGE_PLUGIN_ROOT/scripts/forge-followups.sh" collect --file "$ROOT/run.md"
bash "$FORGE_PLUGIN_ROOT/scripts/forge-followups.sh" take --id fu-012345abcdef --task 8
bash "$FORGE_PLUGIN_ROOT/scripts/forge-followups.sh" dismiss --id fu-012345abcdef
```

`add` accepts `--id` to reuse an existing ID. `collect` accepts repeated `--file`
arguments for marked run/retro material. `list` reads the canonical ledger.
Resolve `$ROOT` through FORGE-ROOT and `$FORGE_PLUGIN_ROOT` through `core/HOST.md`;
these example task numbers are not values to copy into a user's project.

Before writing, read existing entries and reuse the ID when the same candidate
from the same source is already present. Mechanical deduplication is by ID, not
fuzzy text similarity. Re-collecting an old `open` snapshot must never reopen a
`taken` or `dismissed` entry. Conflicting provenance is an error, not permission
to overwrite history. Do not auto-dismiss candidates because they are old.
Dismiss only on an explicit decision that the work is unwanted or superseded,
and retain a short reason in the body. A terminal entry remains in the ledger.

## Producer checkpoints

1. **fg-run:** record concrete unresolved future work at the end of `run.md`
   using these markers. Preserve IDs already present in task inputs; no
   candidates means no placeholder entry.
2. **fg-learn, including batch promotion:** before its handoff, persist every
   surfaced candidate in the ledger. Reuse run IDs in the retro's final section.
   Recording a candidate does not promote it into CONTEXT/ADR or start work.
3. **fg-done, every caller:** after confirming the target is sealable, inspect
   its plan/run and matching retro for concrete follow-up work, including
   legacy free-heading notes. Normalize newly identified candidates into marked
   blocks at the end of its run (or retro), preserving existing IDs. The seal
   script collects marked run/retro blocks after its verification/retro gates
   and before removing source files. Failed collection blocks sealing; do not
   report completion or discard the source.
4. **Skip/auto paths:** fg-ask auto-close, fg-loop (skip and auto retro),
   fg-next all, fg-run simple mode, and fg-done all use checkpoint 3 for each
   task. Skipping the retro never skips recording candidates.

The script parses explicit markers only. It cannot discover semantic candidates
under arbitrary old headings; that is the calling skill's bounded inspection
of the task being sealed. There is no automatic whole-history migration.

## Taking a candidate in fg-ask

When the user selects an open candidate, grill it normally. Write the new
backlog plan and its assigned task number first, adding
`<!-- followup-id: fu-012345abcdef -->` near its provenance markers. Only after
that write succeeds, run `take --id ID --task N`. If planning is abandoned,
leave the entry open. If the update fails, keep the plan and report/retry the
ledger update; do not create a second plan. On resume, match `followup-id` in
existing plans before allocating a new task.

For a split, link `taken` to the first part and list the remaining part numbers
in the body. For an already-taken candidate, show its linked task instead of
silently planning it again. Reopening dismissed work requires a new explicit
decision; keep the old record and create a new candidate with a reference to
it. Task completion and task dropping do not silently rewrite candidate state.
