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
  # The capability vocabulary is NOT restated here — copy the real core/HOST.md so the
  # fixture's 8 keys can never drift from the canonical table the scripts parse.
  mkdir -p "$d/core"; cp "$HERE/../core/HOST.md" "$d/core/HOST.md"
  local caps; caps="$(caps_json "$d/core/HOST.md")"
  for h in claude codex; do
    printf 'x\n' > "$d/hosts/$h/interaction.md"
    printf 'x\n' > "$d/hosts/$h/execution.md"
    printf '%s\n' "$caps" > "$d/hosts/$h/capabilities.json"
  done
  printf '%s' "$d"
}

# Build a valid all-true capabilities.json from HOST.md's table (bash only, no node).
caps_json() {
  local out="" k
  for k in $(grep -oE '^\| `[a-z_]+`' "$1" | sed -E 's/^\| `([a-z_]+)`/\1/'); do
    out="${out:+$out,}\"$k\":true"
  done
  printf '{%s}' "$out"
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

# --- capability vocabulary validation (the hole this check was added to close) ---
# Before it existed, capabilities.json could be reduced to one key or replaced with
# "not json" and BOTH twins still exited 0. These cases pin that shut.
H="$(mkrepo 9.9.9 9.9.9 ./skills/)"; printf '{"structured_choice":true,"bogus_key":true}\n' > "$H/hosts/codex/capabilities.json"
assert_parity "capabilities unknown key" "$H" "unknown keys: bogus_key"
I="$(mkrepo 9.9.9 9.9.9 ./skills/)"; printf '{"structured_choice":true}\n' > "$I/hosts/codex/capabilities.json"
assert_parity "capabilities missing keys" "$I" "missing keys: spawn_parallel"
J="$(mkrepo 9.9.9 9.9.9 ./skills/)"; printf 'not json\n' > "$J/hosts/codex/capabilities.json"
assert_parity "capabilities broken JSON" "$J" "must be a flat object of boolean values"
K="$(mkrepo 9.9.9 9.9.9 ./skills/)"
sed -i.bak 's/"prevent_stop":true/"prevent_stop":"maybe"/' "$K/hosts/codex/capabilities.json" && rm -f "$K/hosts/codex/capabilities.json.bak"
assert_parity "capabilities non-boolean" "$K" "must be a flat object of boolean values"
L="$(mkrepo 9.9.9 9.9.9 ./skills/)"; rm "$L/core/HOST.md"
assert_parity "HOST.md vocabulary gone" "$L" "cannot derive the capability vocabulary"
M="$(mkrepo 9.9.9 9.9.9 ./skills/)"; printf '{"structured_choice":true,"zzz":true}\n' > "$M/hosts/claude/capabilities.json"
assert_parity "claude host checked too" "$M" "hosts/claude/capabilities.json"

rm -f /tmp/rc.sh.err /tmp/rc.js.err
[ "$fails" -eq 0 ] && { echo "RELEASE-CHECK PARITY OK"; exit 0; }
echo "RELEASE-CHECK PARITY FAILED ($fails)"; exit 1
