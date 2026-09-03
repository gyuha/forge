#!/usr/bin/env bash
# Parity test (ADR-0022): release-check.sh and release-check.js MUST produce
# identical stdout, stderr and exit code for the same repo fixture. Both resolve
# the repo from their own location, so each fixture is a throwaway repo with the
# two scripts copied into its scripts/ dir.
#
# `set -euo pipefail`: a failed mktemp / fixture build ABORTS rather than letting
# "both produced nothing, so they're equal" pass as PARITY OK. Every case also
# asserts a sentinel substring, so a script that silently did nothing is a
# mismatch, not a pass.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
fails=0

mkrepo() { # $1=version-claude $2=version-codex $3=skills-field
  local d; d="$(mktemp -d)"
  mkdir -p "$d/scripts" "$d/.claude-plugin" "$d/.codex-plugin" "$d/hooks" \
           "$d/hosts/claude" "$d/hosts/codex"
  cp "$HERE/release-check.sh" "$HERE/release-check.js" "$d/scripts/"
  printf '{"name":"forge","version":"%s"}\n' "$1" > "$d/.claude-plugin/plugin.json"
  printf '{"metadata":{"version":"%s"},"plugins":[{"version":"%s"}]}\n' "$1" "$1" \
    > "$d/.claude-plugin/marketplace.json"
  printf '{"name":"forge","version":"%s","skills":"%s"}\n' "$2" "$3" \
    > "$d/.codex-plugin/plugin.json"
  printf '{}\n' > "$d/hooks/hooks.json"
  for h in claude codex; do
    for f in interaction.md execution.md capabilities.json; do printf 'x\n' > "$d/hosts/$h/$f"; done
  done
  printf '%s' "$d"
}

assert_parity() { # $1=desc $2=repo $3=must-contain
  local desc="$1" d="$2" must="$3" o_sh o_js e_sh e_js r_sh r_js
  o_sh="$(bash "$d/scripts/release-check.sh" 2>/tmp/rc.sh.err)" && r_sh=0 || r_sh=$?
  e_sh="$(cat /tmp/rc.sh.err)"
  o_js="$(node "$d/scripts/release-check.js" 2>/tmp/rc.js.err)" && r_js=0 || r_js=$?
  e_js="$(cat /tmp/rc.js.err)"
  if [ "$o_sh" != "$o_js" ] || [ "$e_sh" != "$e_js" ] || [ "$r_sh" != "$r_js" ]; then
    echo "FAIL - $desc (sh≠js)"
    diff <(printf 'rc=%s\n%s\n%s\n' "$r_sh" "$o_sh" "$e_sh") \
         <(printf 'rc=%s\n%s\n%s\n' "$r_js" "$o_js" "$e_js") || true
    fails=$((fails+1)); rm -rf "$d"; return
  fi
  if ! printf '%s%s' "$o_sh" "$e_sh" | grep -qF -- "$must"; then
    echo "FAIL - $desc (equal but missing sentinel '$must' — scripts likely didn't run)"
    fails=$((fails+1)); rm -rf "$d"; return
  fi
  echo "ok   - $desc (rc=$r_sh)"
  rm -rf "$d"
}

A="$(mkrepo 9.9.9 9.9.9 ./skills/)";  assert_parity "all in sync"          "$A" "ok (forge 9.9.9"
B="$(mkrepo 9.9.9 9.9.8 ./skills/)";  assert_parity "version drift"        "$B" "manifest version drift"
C="$(mkrepo 9.9.9 9.9.9 ./elsewhere/)"; assert_parity "wrong skills field" "$C" "must point to ./skills/"
D="$(mkrepo 9.9.9 9.9.9 ./skills/)"; rm "$D/hooks/hooks.json"
assert_parity "missing hooks.json" "$D" "missing default Codex hook file"
E="$(mkrepo 9.9.9 9.9.9 ./skills/)"; rm "$E/hosts/codex/execution.md"
assert_parity "missing host adapter" "$E" "missing host adapter: hosts/codex/execution.md"
F="$(mkrepo 9.9.9 9.9.9 ./skills/)"; rm "$F/.codex-plugin/plugin.json"
assert_parity "missing manifest" "$F" "missing manifest: .codex-plugin/plugin.json"
G="$(mkrepo 9.9.9 9.9.8 ./elsewhere/)"; rm "$G/hooks/hooks.json"
assert_parity "multiple violations, same order" "$G" "manifest version drift"

rm -f /tmp/rc.sh.err /tmp/rc.js.err
[ "$fails" -eq 0 ] && { echo "RELEASE-CHECK PARITY OK"; exit 0; }
echo "RELEASE-CHECK PARITY FAILED ($fails)"; exit 1
