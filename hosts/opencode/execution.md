# opencode execution adapter

Execute serially. `spawn_parallel` is `false` for this host (see
[interaction.md](./interaction.md) for why), so run each work slice in order in
the current turn, preserving every state transition and verification gate
exactly as the shared skill defines them.

Serial execution has no host handle to record, so `running.md`'s `workflow:`
field stays `pending` for the whole in-flight window. A later `fg-run` that finds
that marker therefore takes the shared step 4a case 3 (unknown/uncollectable)
and asks the human before rebuilding — the conservative branch, and the correct
one while nothing resumable exists. Blocking-collect is a no-op because the work
finished inside the same turn; cancellation is stopping the current turn, after
which the shared skill records the aborted run before deleting the marker.

When `spawn_parallel` is later observed and flipped to `true`, this file gains
the delegation lifecycle (launch, recorded handle, blocking-collect,
cancellation) and nothing else changes: result-collection policy, integration,
UAT and every `.forge/` write stay with the shared skill — see
[../../core/EXECUTION.md](../../core/EXECUTION.md).

There is no unattended-drive mechanism here (`prevent_stop` is `false`), so
`fg-next all` and `fg-loop` are turn-bounded on opencode: they run as far as one
turn allows, keep their state files, and resume statelessly on re-trigger.
