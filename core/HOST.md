# Forge host contract

Forge keeps workflow and `.forge/` state semantics in the shared `skills/` and
`scripts/` trees. Host adapters describe only how the active agent host asks,
delegates, loads project agents, continues a drive, and displays status.

## Select the adapter

1. Explicit host metadata wins.
2. `PLUGIN_ROOT` identifies Codex.
3. `CLAUDE_PLUGIN_ROOT` without Codex metadata identifies Claude Code.
4. If the host cannot be identified, use the sequential fallback: plain-text
   questions, no role-specific delegation, and no host UI mutation.

Codex may also provide `CLAUDE_PLUGIN_ROOT` for compatibility, so its presence
alone is not proof that the host is Claude Code. The mirror holds: `PLUGIN_ROOT`
is a generic name another tool may export, so its presence alone is not proof of
Codex either. When both signals are weak, prefer explicit host metadata; when
nothing is conclusive, take the sequential fallback rather than guessing — every
fallback path below is defined and safe.

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

The table above is the **single vocabulary**: `hosts/<host>/capabilities.json`
uses exactly these eight keys and nothing else, so a skill can name a capability
(`spawn_parallel`, `prevent_stop`, …) and look it up mechanically.

**A capability is `true` only when that host has been *observed* to provide it.**
Unverified defaults to `false`, because every capability has a defined fallback
(sequential execution, a numbered text list, a stated stop) and a fallback that
runs is always cheaper than a tool call that does not exist. Flipping a `false`
to `true` is an observation, not an assumption — and `docs/codex.md`'s support
table must be updated in the same change, since the two are the same claim in
two forms.

Read the matching adapter in `../hosts/claude/` or `../hosts/codex/` (relative to this file) before using a
host-specific capability.
