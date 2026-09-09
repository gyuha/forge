# Codex execution adapter

Use Codex collaboration/subagent tools for independent slices. Spawn only
bounded tasks that can run independently, and keep dependent slices serial. If
collaboration tools are unavailable, execute serially.

Each spawn returns an agent ID and canonical task name immediately, before the
delegated turn finishes. After every spawn, record its returned handle in
`running.md`'s `workflow:` field before launching another agent; use a
comma-separated list when a parallel wave has several agents. Blocking-collect
means inspecting those agents with the host's agent-list operation and waiting
for mailbox/final-status updates until every recorded agent finishes. A later
fg-run in the same root thread first attempts the same list/wait collection;
only an absent or unknown recorded handle takes shared step 4a case 3
(unknown/uncollectable/error). Cancellation means interrupting every still-live
recorded agent, after which the shared skill records the aborted run before
deleting the marker.

The concrete delegation lifecycle and tool mapping are all this adapter owns.
Result-collection policy, integration, UAT, and every `.forge/` write stay with
the shared skill — see [../../core/EXECUTION.md](../../core/EXECUTION.md).
