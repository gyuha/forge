# Forge host contract

Forge keeps workflow and `.forge/` state semantics in the shared `skills/` and
`scripts/` trees. Host adapters describe only how the active agent host asks,
delegates, loads project agents, continues a drive, and displays status.

## Select the adapter

1. Explicit host metadata wins.
2. `PLUGIN_ROOT` identifies Codex.
3. `CLAUDE_PLUGIN_ROOT` without Codex metadata identifies Claude Code.
4. Explicit host metadata is the **only** signal that identifies opencode.
5. If the host cannot be identified, use the sequential fallback: plain-text
   questions, no role-specific delegation, and no host UI mutation.

Codex may also provide `CLAUDE_PLUGIN_ROOT` for compatibility, so its presence
alone is not proof that the host is Claude Code. The mirror holds: `PLUGIN_ROOT`
is a generic name another tool may export, so its presence alone is not proof of
Codex either. When both signals are weak, prefer explicit host metadata; when
nothing is conclusive, take the sequential fallback rather than guessing — every
fallback path below is defined and safe.

opencode exports no environment variable that Forge can rely on being present in
every session, so rule 4 above deliberately gives it no environment signal — do
not infer opencode from the *absence* of the other two variables, which is the
sequential fallback's own condition and would silently upgrade an unknown host
into a named one. opencode also needs no Forge-specific packaging: it discovers
`SKILL.md` under `.opencode/skills/`, `.claude/skills/` and `.agents/skills/`,
so an install that already lives in `.claude/skills/` is loaded unchanged. Its
adapter currently declares every capability `false`, which is the observation
rule below applied literally, not a claim that opencode cannot do these things.

When a shell command needs the installed plugin root, normalize it locally:

```sh
FORGE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT:-}}"
```

The host's **own** variable comes first: `PLUGIN_ROOT` is a generic name another
tool may export (see above), so letting it win would let an unrelated tool
redirect a path that `CLAUDE_PLUGIN_ROOT` already resolves correctly. Adapter
*selection* still treats `PLUGIN_ROOT` as a Codex signal — that is a separate
question from *resolving a path*.

Two distinct mechanisms are at work, and confusing them is what makes the
precedence above look dangerous when it is not. A **shell-form hook command**
(no `args`) is handed to the shell verbatim, with `CLAUDE_PLUGIN_ROOT` set in
the hook process's *environment* — so the shell expands it, and inverting the
precedence is safe. Textual `${CLAUDE_PLUGIN_ROOT}` substitution is the
**skill-body** mechanism instead, and it replaces that exact literal token only
— which is why skill bodies keep `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}`
(inverting *there* would leave an unexpanded expression for the agent to read).
Do not "fix" one to match the other.

Skills should prefer paths relative to their own directory. They must not fork
the state model or maintain a second Codex-specific copy of a skill.

## Shared capabilities

| Capability | Meaning |
| --- | --- |
| `structured_choice` | Ask one bounded question; fall back to a numbered text choice. |
| `spawn_parallel` | Run bounded, independent work concurrently. |
| `spawn_role` | Delegate using a project-defined role when the host supports it. |
| `plugin_root` | Resolve files shipped by this plugin. |
| `session_start` | Surface unfinished Forge state at session entry. |
| `prevent_stop` | Continue only an explicitly active unattended drive. |
| `project_agents` | Load host-native project agent definitions. |
| `status_display` | Install or render host-native persistent status UI. |
| `event_wake` | Resume the conversation from an external event, with no user turn. |

The table above is the **single vocabulary**: `hosts/<host>/capabilities.json`
uses exactly these nine keys and nothing else, so a skill can name a capability
(`spawn_parallel`, `prevent_stop`, …) and look it up mechanically — and a skill
that names one declares the dependency in a `**Host contract**` paragraph next to
its `**Language**` rule (fg-doctor B20 keeps the two in step).

**A capability is `true` only when that host has been *observed* to provide it.**
Unverified defaults to `false`, because every capability has a defined fallback
(sequential execution, a numbered text list, a stated stop) and a fallback that
runs is always cheaper than a tool call that does not exist. Flipping a `false`
to `true` is an observation, not an assumption — and `docs/codex.md`'s support
table must be updated in the same change, since the two are the same claim in
two forms.

Read the matching adapter in `../hosts/claude/`, `../hosts/codex/` or
`../hosts/opencode/` (relative to this file) before using a host-specific
capability.
