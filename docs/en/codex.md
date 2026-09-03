# Using forge with Codex

forge is structured so Claude Code and Codex consume the **same `skills/` and `.forge/` state**. Workflow rules are not duplicated; only host-specific interaction and subagent execution live in `hosts/` adapters.

## Install and invoke

The repository includes `.codex-plugin/plugin.json`. Add the repository to a local Codex Marketplace, install the plugin, and start a new task so its skills reload. Plugin hooks are not trusted merely because the plugin is installed; review and trust them before enabling them.

| Purpose | Claude Code | Codex |
| --- | --- | --- |
| Start planning | `/forge:fg-ask` | `$fg-ask` |
| Execute a plan | `/forge:fg-run` | `$fg-run` |
| Run the next step | `/forge:fg-next` | `$fg-next` |
| Inspect status | `/forge:fg-status` | `$fg-status` |
| Check integrity | `/forge:fg-doctor` | `$fg-doctor` |

Natural-language triggers are shared too. For example, “start a new task with forge” can select `fg-ask`.

## Shared core and adapters

```text
.claude-plugin/plugin.json ─┐
                            ├─▶ skills/ + scripts/ ─▶ same .forge/ state
.codex-plugin/plugin.json ──┘
                                  │
                                  ├─ hosts/claude/
                                  └─ hosts/codex/
```

- `core/HOST.md`: host detection and capability selection
- `core/INTERACTION.md`: shared question, choice, and confirmation contract
- `core/EXECUTION.md`: shared serial/parallel execution and result collection contract
- `hosts/codex/`: Codex input and collaboration/subagent behavior
- `hosts/claude/`: Claude Code `AskUserQuestion` and Dynamic Workflow behavior

Script paths prefer `PLUGIN_ROOT` and fall back to `CLAUDE_PLUGIN_ROOT`, so both hosts execute the same deterministic scripts.

## Current support

| Capability | Codex status | Notes |
| --- | --- | --- |
| Core loop (`fg-ask` → `fg-run` → `fg-learn` → `fg-done`) | Supported | Same state transitions, verification, and sealing rules |
| State utilities (`fg-status`, `fg-doctor`, `fg-quick`, `fg-tdd`) | Supported | Shared scripts and skills |
| Parallel independent work | Supported | Serial fallback when Codex collaboration/subagent tools are unavailable |
| SessionStart notice | Supported | Default `hooks/hooks.json` discovery; the user must review and trust hooks |
| `fg-next all` and `fg-loop` unattended drive | Limited | Supervised use is recommended until Stop-hook re-entry parity is proven |
| `fg-agents` project roles | Limited | Generation is still centered on `.claude/agents/`; Codex materialization is follow-up work |
| Structured choice menus | Unverified | Falls back to a numbered text list — correct on any host |
| `fg-statusline` | Unsupported | Use `$fg-status` in Codex |

This table is a **declaration**, not prose — the same claim lives in machine-readable form as the eight keys of `hosts/codex/capabilities.json`, and the two are always updated together. **A capability is `true` only when that host has been *observed* to provide it; unverified defaults to `false`** — every capability has a defined fallback (serial execution, a numbered list, a stated stop), and a fallback that runs is always cheaper than a tool call that does not exist. Flipping a `false` to `true` is an observation, not an assumption (`core/HOST.md`).

## Resume across hosts

Forge state lives in the repository's `.forge/`, not in a host. You can plan in Claude Code and continue with `$fg-status` or `$fg-next` in Codex, or execute in Codex and retro/seal in Claude Code. Both hosts must point at the same branch and working tree.

## Release check

```bash
npm run release:check
```

This checks Claude/Codex manifest versions, the shared `skills/` path, the default hook file, and both host adapters. When the Codex manifest exists, `fg-doctor` also checks all four version locations for drift.
