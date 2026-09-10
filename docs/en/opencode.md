# Using forge with opencode

forge is structured so Claude Code, Codex, and opencode consume the **same `skills/` and `.forge/` state**. Workflow rules are not duplicated three times; only host-specific interaction and subagent execution live in `hosts/` adapters.

## Install and invoke

opencode needs no forge-specific manifest — there is no third manifest matching `.claude-plugin`/`.codex-plugin`, and skills load by `SKILL.md` discovery alone. But **forge has to sit on one of those discovery paths.** opencode scans only `.opencode/skills/`, `.claude/skills/`, and `.agents/skills/` (project — walking up to the git worktree), plus `~/.config/opencode/skills/`, `~/.claude/skills/`, and `~/.agents/skills/` (global).

**A forge installed with `/plugin install` is not on that list.** Plugins land in a plugin cache at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/skills/`, and only Claude Code's plugin loader knows that path. If your other skills show up in opencode but forge does not, this is why — one symlink fixes it.

### Linking it

```bash
git clone https://github.com/gyuha/forge.git ~/.forge
mkdir -p ~/.config/opencode/skills
ln -s ~/.forge/skills/* ~/.config/opencode/skills/
```

Check it, then **restart opencode** — skills load at session start, so an already-open session will not pick them up.

```bash
ls ~/.config/opencode/skills/ | wc -l   # should match forge's skill count
```

Updating is a single `git pull`, because the links point straight at the clone.

Three cautions:

- **Do not link the plugin cache directly.** The cache path pins a version (`.../forge/0.8.3/`) and old version directories are not removed, so after an upgrade the link does not break — it silently keeps pointing at the old forge.
- **`~/.claude/skills/` is not recommended** — Claude Code may discover both the plugin copy and this one. To scope forge to a single repo, link into that repo's `.opencode/skills/` instead of the global path.
- **The clone is independent of the Claude Code plugin** — the two hosts can see different forge versions, so keep them in step by `git pull`-ing the clone and running `/plugin marketplace update` for the plugin.

Invocation is by skill name. Natural-language triggers are shared across all three hosts.

| Purpose | Claude Code | Codex | opencode |
| --- | --- | --- | --- |
| Start planning | `/forge:fg-ask` | `$fg-ask` | invoke the `fg-ask` skill |
| Execute a plan | `/forge:fg-run` | `$fg-run` | invoke the `fg-run` skill |
| Run the next step | `/forge:fg-next` | `$fg-next` | invoke the `fg-next` skill |
| Inspect status | `/forge:fg-status` | `$fg-status` | invoke the `fg-status` skill |
| Check integrity | `/forge:fg-doctor` | `$fg-doctor` | invoke the `fg-doctor` skill |

## Shared core and adapters

```text
.claude-plugin/plugin.json ─┐
                            ├─▶ skills/ + scripts/ ─▶ same .forge/ state
.codex-plugin/plugin.json ──┤
                            │
 (opencode: no manifest — ──┘
  discovers .claude/skills/)
                                  │
                                  ├─ hosts/claude/
                                  ├─ hosts/codex/
                                  └─ hosts/opencode/
```

- `core/HOST.md`: host detection and capability selection
- `core/INTERACTION.md`: shared question, choice, and confirmation contract
- `core/EXECUTION.md`: shared serial/parallel execution and result collection contract
- `hosts/opencode/`: opencode plain-text input and serial execution behavior

**opencode has no host-identification signal.** It exports no environment variable Forge can rely on being present in every session, so `core/HOST.md`'s selection rules identify opencode by **explicit host metadata only**. Do not infer opencode from the *absence* of the other two variables (`CLAUDE_PLUGIN_ROOT`, `PLUGIN_ROOT`) — that absence is the sequential fallback's own condition, and inferring from it would silently promote an unknown host into a named one.

## Current support

| Capability | opencode status | Notes |
| --- | --- | --- |
| Core loop (`fg-ask` → `fg-run` → `fg-learn` → `fg-done`) | Supported | Same state transitions, verification, and sealing rules |
| State utilities (`fg-status`, `fg-doctor`, `fg-quick`, `fg-config`) | Supported | Shared deterministic scripts and skills |
| Structured choice menus (`structured_choice`) | Unverified | Falls back to a numbered text list — correct on any host |
| Parallel independent work (`spawn_parallel`) | Unverified | Upstream docs describe the built-in `@general` subagent running multiple units of work in parallel, but **no observation exists** of a forge slice delegated and collected through it. Serial for now — first flip candidate |
| Role-specific delegation (`spawn_role`) | Unverified | Custom agents in `.opencode/agents/<role>.md` are documented as being picked by a primary agent from their `description`, but unobserved — falls back to the default subagent. Second flip candidate |
| Plugin file path resolution (`plugin_root`) | Unverified | No plugin-root variable can be relied on; skills resolve companion files by a path relative to their own directory |
| SessionStart notice (`session_start`) | Unverified | No unsealed-tail injection — call `fg-status` yourself when entering a session |
| `fg-next all` and `fg-loop` unattended drive (`prevent_stop`) | Unsupported | No mechanism carries a drive across a turn boundary, so it is **turn-bounded**: it runs as far as one turn allows, keeps its state files, and resumes statelessly on re-trigger |
| `fg-agents` project roles (`project_agents`) | Unsupported | Generation is centered on `.claude/agents/`; opencode materialization is follow-up work |
| `fg-statusline` (`status_display`) | Unsupported | Call `fg-status` directly |
| `fg-showme` confirm-click wake (`event_wake`) | Unsupported | After confirming on screen, send anything in the terminal to resume |
| `fg-loop`'s `budget-tokens` ceiling | Unsupported | The meter reads Claude Code's transcript files. On opencode declare `budget-tokens: none`, or point it at the host's location with `--transcripts DIR` (otherwise the drive halts at `blocked-health` — fail-closed) |

This table is a **declaration**, not prose — the same claim lives in machine-readable form as the nine keys of `hosts/opencode/capabilities.json`, and the two are always updated together. `npm run release:check` enforces that **all nine keys are named in this table** (the status wording itself is human-reviewed). **A capability is `true` only when that host has been *observed* to provide it; unverified defaults to `false`** — which is why all nine opencode keys are currently `false`. That is not a claim that opencode cannot do these things; it is the observation rule applied literally, and every `false` has a defined fallback (`core/HOST.md`).

## Resume across hosts

Forge state lives in the repository's `.forge/`, not in a host. You can plan in Claude Code and continue with `fg-status` or `fg-next` in opencode, or execute in opencode and retro/seal in Claude Code. All three hosts must point at the same branch and working tree.

## Release check

```bash
npm run release:check
```

This checks the four manifest versions, the shared `skills/` path, the default hook file, and **every host adapter that actually exists under `hosts/`** — the host list is not hardcoded, so `hosts/opencode/` is checked automatically.
