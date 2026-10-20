# Status JSON API (schema version 1)

Run `bash scripts/forge-status.sh --json` or `node scripts/forge-status.js --json`
from the target project (or a subdirectory). Both return the same JSON value.
This read-only API resolves the same branch-scoped forge root as the text view.
It never decides or executes the next step; the state machine in SKILL.md remains
its single definition. Text and `--table` output are unchanged.

Successful stdout is exactly one JSON object plus a newline, including when no
forge directory exists. Failures return nonzero, with diagnostics on stderr and
no JSON stdout (including malformed follow-up markers). No dependencies are added
to the bash path: bash, git and standard Unix utilities suffice; Node is optional.
Consumers must check the exit status before parsing and tolerate new object keys.

## Object fields

| Field | Type | Meaning |
| --- | --- | --- |
| `schemaVersion` | integer | `1`; incompatible changes require a new version |
| `root` | string | Resolved forge root; absolute in a Git repository, `.forge` in a non-Git working directory |
| `exists` | boolean | Whether the resolved root directory exists |
| `tasks` | array of task objects | All active, backlog, executed and done tasks, including history beyond the text view's latest five |
| `running` | object or null | `{path, content}` for `running.md`; null if absent |
| `loop` | object or null | Loop contract described below; null if absent |
| `counts` | object | Integer `active`, `backlog`, `executed`, `done`, `quick`, `retro`, `adr`; `followups` contains integer `open`, `taken`, `dismissed` counts |
| `followups` | array of follow-up objects | Parsed resolved-root `followups.md`, in ledger order; empty if absent |

Tasks are grouped active → backlog → executed → done, with each directory in
lexicographic filename order. This is a survey order, not a scheduling order.
Paths use the same root representation as `root`. An empty state has empty arrays,
null `running`/`loop`, and zero counts (shared ADR fallback may still contribute).
Quick counts `## ` headings; retro/ADR count Markdown files. ADR uses the existing
text view's resolved-root directory, falling back to `.forge/adr` when absent.

## Task objects

| Field | Type | Meaning |
| --- | --- | --- |
| `location` | string | `active`, `backlog`, `executed`, or `done` |
| `path` | string | Plan path, also for legacy archived directories missing a plan |
| `slug` | string | Plan marker, then STATUS slug, then filename/directory fallback (`plan` for active) |
| `task` | integer or null | Stable task number; null if marker absent |
| `title` | string or null | First level-one plan heading; null if absent |
| `status`, `verified`, `retro`, `executed`, `completed` | string or null | Full STATUS field value including reasons, trimmed at its edges; null if empty/missing |
| `hasRun` | boolean | Whether that task has `run.md`; always false for backlog |
| `generatedByLoop` | boolean | Whether the plan carries the `generated-by: fg-loop` marker |

No display glyphs replace raw values; a pending retro with an existing retro file
still has its actual `retro` value. Consumers must not infer readiness from glyphs
or from `hasRun` alone. Counts do not filter by STATUS values.

## Loop and running objects

`loop` has `path`, `goal` (first level-one heading minus `LOOP — `), `wall`,
`replanRound`, `replanCap`, `budgetTokens`, `budgetSpent`, `retro`, and `content`.
All fields except `path`/`content` are nullable strings: numeric-looking fields
remain strings so annotations, unknown values, and `none` survive verbatim.
`wall: none` is the string `"none"`, not null. Missing fields are null.
`budgetSpent` includes its `since:` annotation. `content` contains the entire
contract, preserving the stop checks, authorized scope, task membership and check
progress ledger; clients need not reconstruct it from separate filesystem reads.
`running` similarly preserves the host-specific running marker as `content`.
Both content strings normalize CRLF to LF and omit trailing newlines.

## Follow-up objects

Each entry has string `id`, `source`, `date`, `status`, `body`; nullable integer
`task` and `taken`. Marker `-` becomes null. `status` is `open`, `taken`, or
`dismissed`; `taken` identifies the destination task only for the taken state.
`body` preserves Markdown, normalized line endings, with outer whitespace trimmed.
The shared follow-up parser validates markers before output; its canonical format
is defined in [FOLLOWUPS-FORMAT.md](../fg-learn/FOLLOWUPS-FORMAT.md).
