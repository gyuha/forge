# Codex execution adapter

Use Codex collaboration/subagent tools for independent slices. Spawn only
bounded tasks that can run independently, keep dependent slices serial, and
have the primary agent collect results, integrate edits, run UAT, and write
`.forge/run.md`. If collaboration tools are unavailable, execute serially.
