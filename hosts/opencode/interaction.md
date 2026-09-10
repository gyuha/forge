# opencode interaction adapter

Ask in plain text. opencode exposes no bounded-choice input facility that Forge
has observed, so render a numbered list and ask for one stable identifier —
never invent a tool name and never widen a confirmation gate.

## Why every capability is `false`

`capabilities.json` declares all nine keys `false`. That is not a claim that
opencode lacks these abilities; it is the [core contract](../../core/HOST.md)
applied literally — a capability is `true` only when that host has been
*observed* to provide it, and every `false` has a defined fallback that is
cheaper than a tool call that does not exist.

Two of the nine are documented upstream but not yet observed running Forge, so
they are the first candidates to flip once someone verifies them:

| Capability | Upstream evidence | What is still missing |
| --- | --- | --- |
| `spawn_parallel` | The built-in `@general` subagent is described as running multiple units of work in parallel. | An observed Forge slice delegated and collected through it. |
| `spawn_role` | Custom agents live in `.opencode/agents/<role>.md` and primary agents pick them by `description`. | An observed `agentType`-equivalent dispatch from an execution wave. |

Flipping one is an observation, not an assumption, and it travels with a
`docs/opencode.md` support-table update in the same change.

## Skill loading

Forge needs no opencode-specific packaging: opencode discovers `SKILL.md` under
`.opencode/skills/`, `.claude/skills/` and `.agents/skills/` (project, walking up
to the git worktree) plus the matching `~/.config/opencode/`, `~/.claude/` and
`~/.agents/` locations. A Forge install that already lives in `.claude/skills/`
is therefore loaded as-is. Because `plugin_root` is `false`, skills must resolve
companion files by a path relative to their own directory rather than a plugin
root variable.
