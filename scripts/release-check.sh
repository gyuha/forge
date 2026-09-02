#!/usr/bin/env bash
# release:check — pre-release gate (bash primary; node twin: release-check.js, ADR-0022).
# Verifies the 4 manifest versions are in sync, the Codex manifest points at the
# shared skills tree, the default hook file exists, and both host adapters are complete.
# Exit 0 = ok, 1 = at least one violation (errors on stderr, one per line).
set -u

repo="$(cd "$(dirname "$0")/.." && pwd)"
CJ="$repo/.codex-plugin/plugin.json"
PJ="$repo/.claude-plugin/plugin.json"
MP="$repo/.claude-plugin/marketplace.json"

errors=()
# extract every "version" value in document order (same reader as forge-doctor's B8)
jver() { grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" | sed -E 's/.*"([^"]*)"$/\1/'; }
jstr() { grep -oE "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$1" | sed -E 's/.*"([^"]*)"$/\1/' | head -1; }

for f in "$PJ" "$MP" "$CJ"; do
  [ -f "$f" ] || { printf 'release:check: missing manifest: %s\n' "${f#$repo/}" >&2; exit 1; }
done

pv="$(jver "$PJ" | head -1)"; m1="$(jver "$MP" | head -1)"; m2="$(jver "$MP" | sed -n 2p)"; cv="$(jver "$CJ" | head -1)"
{ [ "$pv" = "$m1" ] && [ "$pv" = "$m2" ] && [ "$pv" = "$cv" ]; } ||
  errors+=("manifest version drift: $pv / $m1 / $m2 / $cv")
[ "$(jstr "$CJ" skills)" = "./skills/" ] || errors+=("Codex manifest must point to ./skills/")
[ -f "$repo/hooks/hooks.json" ] || errors+=("missing default Codex hook file: hooks/hooks.json")
for host in claude codex; do
  for file in interaction.md execution.md capabilities.json; do
    [ -f "$repo/hosts/$host/$file" ] || errors+=("missing host adapter: hosts/$host/$file")
  done
done

if [ ${#errors[@]} -gt 0 ]; then
  for e in "${errors[@]}"; do printf 'release:check: %s\n' "$e" >&2; done
  exit 1
fi
printf 'release:check: ok (forge %s, shared skills + Claude/Codex adapters)\n' "$pv"
