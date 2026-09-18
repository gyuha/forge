# Pi interaction adapter

Ask in plain text, one question at a time. For a bounded choice, render a
numbered list and accept a stable identifier. Forge ships no Pi extension
providing a choice tool; never invent one or change the shared approval gates.

## Skill loading and commands

Pi packages discover the existing `skills/` directory. Keep the whole Forge
checkout installed so sibling `core/`, `hosts/`, and `scripts/` paths remain
available. No Pi-specific skill copies or package manifest are needed.
Use `/skill:fg-ask`, `/skill:fg-run`, etc.; retain arguments such as
`/skill:fg-next all`. When shared instructions name `/forge:fg-*`, render the
corresponding Pi command. Natural-language triggers remain available.

Pi supplies the loaded skill's file path/base directory. Resolve companion
files relative to that directory and the package root two parents above it;
see [../../core/HOST.md](../../core/HOST.md). Do not assume Claude or Codex root
variables are set. `plugin_root: false` records the absence of that native
variable/substitution contract, not an inability to read installed files.

## Capability boundary

All nine capabilities are `false` for this basic adapter. Pi's extension APIs
are not installed Forge integrations. In particular, do not use an extension
UI, subagent, session hook, project role, persistent status display or event
wake unless a future adapter actually implements and verifies it. Run the
shared workflow using its fallbacks. Support and installation are documented
in [../../docs/en/pi.md](../../docs/en/pi.md).
