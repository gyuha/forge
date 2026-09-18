# Pi execution adapter

Execute dependent and independent work slices serially in the current session
using Pi's built-in read, bash, edit and write tools. Forge basic support does
not install extensions or provide subagent tools. Read project instructions
normally; do not treat `.claude/agents/` cards as registered Pi agents.

There is no resumable delegation handle: keep `running.md`'s `workflow:` field
`pending` while executing. Blocking-collect is a no-op for work completed in
the same turn. If a later run finds only this in-flight marker, take shared
fg-run recovery case 3 (unknown/uncollectable); never silently restart it.
Cancellation stops current work, then the shared skill records the aborted
run before deleting the marker.

The shared [execution contract](../../core/EXECUTION.md) owns selection,
promotion, integration, verification, result collection policy and all Forge
state. The caller's project remains the working directory even when executing
scripts by absolute paths from an installed Forge package.

`prevent_stop` and `event_wake` are false: `fg-loop` and `fg-next all` continue
within the current turn, retain their shared state when interrupted, and
resume on `/skill:fg-loop` or `/skill:fg-next all`. Do not install Claude Stop
hooks, fabricate `/goal` support, or promise automatic continuation in Pi.
Numeric loop token budgets require an actually compatible meter; the existing
Claude transcript meter is not evidence of Pi usage. Preserve the shared
blocked-health outcome if a requested ceiling cannot be measured.
