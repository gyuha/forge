# Using forge with Pi

[Pi](https://pi.dev/) loads forge's same 22 skills and uses the same repository `.forge/` state as the other hosts. Basic support provides conversational planning, sequential execution, verification, and sealing. It requires no Pi extension.

## Install and invoke

Register a local checkout containing the Pi support changes. Pi discovers the package's conventional `skills/` directory; no separate Pi manifest or skill copies are needed.

```bash
git clone https://github.com/gyuha/forge.git ~/.forge
pi install "$HOME/.forge"
```

If you already have a checkout, pass its absolute path instead. `pi install` registers a local path without copying it, so keep the checkout in place and update it with `git pull`. Add `-l` to install for the current project instead of globally. Start a fresh Pi session after installation.

| Purpose | Pi command |
| --- | --- |
| Start planning | `/skill:fg-ask` |
| Execute a plan | `/skill:fg-run` |
| Record learnings | `/skill:fg-learn` |
| Seal a task | `/skill:fg-done` |
| Inspect status | `/skill:fg-status` |
| Execute the next step | `/skill:fg-next` |
| Drive the backlog | `/skill:fg-next all` |
| Start a goal loop | `/skill:fg-loop <goal>` |

Natural-language triggers also work. In shared examples, translate `/forge:fg-name` to `/skill:fg-name` on Pi, preserving arguments. A Claude Code plugin installation alone does not register forge with Pi.

## Host and file resolution

The Pi adapter is selected from explicit session identity. If the session does not identify its host, say “The current host is Pi” when invoking forge. The presence of a `pi` executable or the absence of another host's variables is not host identity; an unknown host keeps the generic sequential fallback.

Pi supplies the loaded skill's file path. Forge resolves companions, `core/`, `hosts/`, and `scripts/` from that path; the installation root is two directories above the skill directory containing `skills/fg-name/SKILL.md`. Keep the whole checkout: copying only `SKILL.md` loses these dependencies. The installation root is separate from the working project's `.forge/` state. No `PLUGIN_ROOT` or `CLAUDE_PLUGIN_ROOT` variable is required or assumed.

## Current support

| Capability | Pi status | Behavior |
| --- | --- | --- |
| Core loop and state utilities | Supported | Shared skills, verification gates, and deterministic scripts |
| Structured menus (`structured_choice`) | `false` | Numbered choices in conversation |
| Parallel delegation (`spawn_parallel`) | `false` | Execute independent work sequentially |
| Role delegation (`spawn_role`) | `false` | Apply role guidance in the current agent |
| Plugin root variable (`plugin_root`) | `false` | Resolve files relative to the loaded skill path |
| SessionStart notice (`session_start`) | `false` | Invoke `/skill:fg-status` when entering a session |
| Cross-turn continuation (`prevent_stop`) | `false` | `fg-next all` and `fg-loop` are turn-bounded; state remains and a new invocation resumes |
| Project agent cards (`project_agents`) | `false` | No Pi-native materialization of `fg-agents` cards |
| Persistent statusline (`status_display`) | `false` | Invoke `/skill:fg-status` |
| Browser event wake (`event_wake`) | `false` | After confirming in `fg-showme`, send a message to resume |
| `fg-loop` token ceiling | Unsupported | Use `budget-tokens: none`; the existing Claude transcript meter does not measure Pi sessions |

The nine flags match `hosts/pi/capabilities.json`. They conservatively describe this basic adapter, not everything a third-party Pi extension might implement. No extension is installed to add hooks, subagents, or automatic resumption. A requested numeric token ceiling must stop at `blocked-health` if it cannot be measured; it must not be silently ignored.

## Verification and resuming

To repeat the check with Pi installed, run `node scripts/pi-host.test.mjs`. Set `FORGE_PI_PACKAGE_ROOT` for an SDK at another location. The check uses a temporary installation without model calls or changes to user settings.

Resource loading is checked with Pi 0.85.1's actual loader, including all 22 skill names and companion paths. This verifies discovery and file resolution, not an authenticated model's end-to-end execution of every skill. `npm run release:check` validates the adapter files, the nine capability keys, and their documentation alongside the existing hosts.

State belongs to the working repository and branch. You can plan on another host, then invoke `/skill:fg-status` or `/skill:fg-next` in Pi on the same working tree. After a turn-bounded drive stops, invoke `/skill:fg-loop` again for its saved goal, or `/skill:fg-next all` for the backlog.
