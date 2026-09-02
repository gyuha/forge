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
alone is not proof that the host is Claude Code.

When a shell command needs the installed plugin root, normalize it locally:

```sh
FORGE_PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
```

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

Read the matching adapter in `hosts/claude/` or `hosts/codex/` before using a
host-specific capability.
