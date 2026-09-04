# Codex execution adapter

Use Codex collaboration/subagent tools for independent slices. Spawn only
bounded tasks that can run independently, and keep dependent slices serial. If
collaboration tools are unavailable, execute serially.

Delegation is all this adapter owns. Result integration, UAT, and every
`.forge/` write stay with the shared skill — see [../../core/EXECUTION.md](../../core/EXECUTION.md).
