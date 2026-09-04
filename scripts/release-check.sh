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

# Capability vocabulary — derived from core/HOST.md's table, never hardcoded here.
# That table is the single definition; a second copy in this script would be the
# very drift this check exists to prevent. The contract validated per host is
# "a flat object of boolean values" — checkable without a JSON parser, so the
# bash twin stays node-free (ADR-0022) and matches the .js twin exactly.
canonical=$(grep -oE '^\| `[a-z_]+`' "$repo/core/HOST.md" 2>/dev/null | sed -E 's/^\| `([a-z_]+)`/\1/')
if [ -z "$canonical" ]; then
  errors+=("cannot derive the capability vocabulary from core/HOST.md")
else
  for host in claude codex; do
    cap="$repo/hosts/$host/capabilities.json"
    [ -f "$cap" ] || continue   # already reported above
    compact=$(tr -d ' \t\n\r' < "$cap")
    if ! printf '%s' "$compact" | grep -qE '^\{("[a-z_]+":(true|false),)*"[a-z_]+":(true|false)\}$'; then
      errors+=("hosts/$host/capabilities.json must be a flat object of boolean values")
      continue
    fi
    keys=$(printf '%s' "$compact" | grep -oE '"[a-z_]+":' | sed -E 's/"([a-z_]+)":/\1/')
    missing=""; unknown=""
    for k in $canonical; do
      printf '%s\n' "$keys" | grep -qx "$k" || missing="${missing:+$missing, }$k"
    done
    for k in $keys; do
      printf '%s\n' "$canonical" | grep -qx "$k" || unknown="${unknown:+$unknown, }$k"
    done
    [ -n "$missing" ] && errors+=("hosts/$host/capabilities.json missing keys: $missing")
    [ -n "$unknown" ] && errors+=("hosts/$host/capabilities.json unknown keys: $unknown")
  done

  # docs/codex.md claims to be "the same declaration in two forms" as the Codex
  # capabilities.json. Enforce the part a machine can settle: every capability
  # key is NAMED in that table. The status wording itself stays human-reviewed —
  # this gate does not claim more than it checks.
  for doc in docs/codex.md docs/en/codex.md; do
    if [ ! -f "$repo/$doc" ]; then
      errors+=("$doc is missing (the Codex capability table has no home)")
      continue
    fi
    undocumented=""
    for k in $canonical; do
      grep -qF "\`$k\`" "$repo/$doc" || undocumented="${undocumented:+$undocumented, }$k"
    done
    [ -n "$undocumented" ] && errors+=("$doc does not name capability keys: $undocumented")
  done
fi

if [ ${#errors[@]} -gt 0 ]; then
  for e in "${errors[@]}"; do printf 'release:check: %s\n' "$e" >&2; done
  exit 1
fi
printf 'release:check: ok (forge %s, shared skills + Claude/Codex adapters)\n' "$pv"
