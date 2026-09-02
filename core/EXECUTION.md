# Execution contract

The shared skill owns selection, promotion, dependency classification, result
collection, UAT, and `.forge/run.md`. The host adapter owns only delegation.

- Dependent slices run serially.
- Independent, bounded slices may run concurrently.
- The primary agent remains responsible for integration and state writes.
- If delegation is unavailable, execute serially without changing semantics.
