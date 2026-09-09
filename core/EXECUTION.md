# Execution contract

The shared skill owns selection, promotion, dependency classification, result
collection policy and integration, UAT, and `.forge/run.md`. The host adapter
owns the concrete delegation lifecycle and tool mapping: launch,
blocking-collect, cancellation, and any resumable execution handle.

- Dependent slices run serially.
- Independent, bounded slices may run concurrently.
- The primary agent remains responsible for integration and state writes.
- If delegation is unavailable, execute serially without changing semantics.
