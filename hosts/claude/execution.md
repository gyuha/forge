# Claude Code execution adapter

Build a Dynamic Workflow. Map independent slices to parallel `agent()` calls.
Use `agentType` when a compatible `.claude/agents/` card was loaded at session
start. Keep dependent slices serial and return every result to the primary
agent for integration and `.forge/run.md` recording.
