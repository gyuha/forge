# Claude Code execution adapter

Build a Dynamic Workflow. Map independent slices to parallel `agent()` calls.
Use `agentType` when a compatible `.claude/agents/` card was loaded at session
start. Keep dependent slices serial and return every result to the primary
agent.

The launch tool returns a workflow **Task ID** (`w…`), not the workflow Run ID
(`wf_…`). Record that Task ID in `running.md`'s `workflow:` field immediately
after launch. Blocking-collect means calling `TaskOutput` with that Task ID and
`block: true`; while it is still running, repeat when the wait window expires,
and stop collecting only on completion or unknown/error. `/workflows` is the progress
surface. Cancellation means calling `TaskStop` with the same Task ID; the shared
skill then records the aborted run before deleting the marker.

The concrete delegation lifecycle and tool mapping are all this adapter owns.
Result-collection policy and integration, UAT, and every `.forge/` write stay
with the shared skill — see [../../core/EXECUTION.md](../../core/EXECUTION.md).
