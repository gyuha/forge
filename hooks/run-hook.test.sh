#!/usr/bin/env bash
# Tests for the forge hook wiring: hooks/hooks.json (static contract) and
# hooks/run-hook.cmd (the polyglot dispatcher). ADR 260727-201031.
#
# What would break silently without this: a typo in hooks.json's command or
# matcher disables the hook with no error anywhere (Claude Code just never fires
# it), and a wrapper that exits non-zero would fail session start.
#
# Run:  bash hooks/run-hook.test.sh
# Exit: 0 if all pass, 1 otherwise.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
WRAPPER="$HERE/run-hook.cmd"
HOOKS_JSON="$HERE/hooks.json"
pass=0; fail=0

mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgwrap.XXXXXX"; }
assert()      { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s\n       expected: [%s]\n       actual:   [%s]\n' "$1" "$2" "$3"; fi; }
assert_grep() { if printf '%s' "$2" | grep -qF -- "$3"; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s (missing: %s)\n       actual: [%s]\n' "$1" "$3" "$2"; fi; }

# --- hooks.json: valid JSON --------------------------------------------------
if node -e "JSON.parse(require('fs').readFileSync('$HOOKS_JSON','utf8'))" 2>/dev/null; then
  pass=$((pass+1))
else
  fail=$((fail+1)); printf '  FAIL hooks.json is not valid JSON\n'
fi

# --- hooks.json: the contract fields ----------------------------------------
JSON_DUMP="$(cat "$HOOKS_JSON")"
assert_grep "hooks.json-event"    "$JSON_DUMP" '"SessionStart"'
assert_grep "hooks.json-matcher" "$JSON_DUMP" 'startup|resume|clear|compact'
assert_grep "hooks.json-command" "$JSON_DUMP" '/hooks/run-hook.cmd\" session-start'
assert_grep "hooks.json-codex-root" "$JSON_DUMP" '${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}'
assert_grep "hooks.json-sync"     "$JSON_DUMP" '"async": false'

# --- wrapper: MUST be executable (the bug this test exists for) -------------
# Claude Code does not run `bash <wrapper>` — it hands the command string to
# /bin/sh, which executes the FILE. Without the exec bit that fails with
# "Permission denied" and the hook silently never fires, while a test that calls
# `bash "$WRAPPER"` still passes. So assert the bit, and assert the real
# invocation shape below. (superpowers ships its wrapper 755 for the same reason.)
if [ -x "$WRAPPER" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL wrapper-exec-bit (chmod +x %s)\n' "$WRAPPER"; fi

# --- wrapper: production invocation shape (/bin/sh runs the file directly) ---
t=$(mktmp); mkdir -p "$t/.forge"
printf '<!-- forge-slug: prod-call -->\n<!-- task: 99 -->\n# T\n' > "$t/.forge/plan.md"
printf 'run\n' > "$t/.forge/run.md"
printf 'slug: prod-call\nstatus: executed\nverified: yes (t)\nretro: pending\n' > "$t/.forge/STATUS.md"
OUT="$( cd "$t" && /bin/sh -c "\"$WRAPPER\" session-start" 2>/dev/null )"; RC=$?
assert      "wrapper-sh-direct-rc0"  0 "$RC"
assert_grep "wrapper-sh-direct-block" "$OUT" '`prod-call`'
rm -rf "$t"

# --- wrapper: dispatches to the hook body, debt state -> block --------------
t=$(mktmp); mkdir -p "$t/.forge"
printf '<!-- forge-slug: wrapped-task -->\n<!-- task: 77 -->\n# T\n' > "$t/.forge/plan.md"
printf 'run\n' > "$t/.forge/run.md"
printf 'slug: wrapped-task\nstatus: executed\nverified: yes (t)\nretro: pending\n' > "$t/.forge/STATUS.md"
OUT="$( cd "$t" && bash "$WRAPPER" session-start 2>/dev/null )"; RC=$?
assert      "wrapper-rc0" 0 "$RC"
assert_grep "wrapper-block" "$OUT" "<forge-state>"
assert_grep "wrapper-slug"  "$OUT" '`wrapped-task`'
rm -rf "$t"

# --- wrapper: clean state -> silence, exit 0 --------------------------------
t=$(mktmp); mkdir -p "$t/.forge/backlog"
OUT="$( cd "$t" && bash "$WRAPPER" session-start 2>/dev/null )"; RC=$?
assert "wrapper-clean-silent" "" "$OUT"
assert "wrapper-clean-rc0" 0 "$RC"
rm -rf "$t"

# --- wrapper: unknown hook name -> silence, exit 0 (graceful) --------------
t=$(mktmp)
OUT="$( cd "$t" && bash "$WRAPPER" no-such-hook 2>/dev/null )"; RC=$?
assert "wrapper-unknown-silent" "" "$OUT"
assert "wrapper-unknown-rc0" 0 "$RC"
rm -rf "$t"

# --- wrapper: no argument -> silence, exit 0 -------------------------------
t=$(mktmp)
OUT="$( cd "$t" && bash "$WRAPPER" 2>/dev/null )"; RC=$?
assert "wrapper-noarg-silent" "" "$OUT"
assert "wrapper-noarg-rc0" 0 "$RC"
rm -rf "$t"

# --- wrapper: CLAUDE_PROJECT_DIR wins over cwd -----------------------------
# Claude Code hands hooks the project dir; the bodies read state from cwd, so the
# wrapper must anchor there rather than trusting whatever cwd it inherited.
t=$(mktmp); mkdir -p "$t/.forge"
printf '<!-- forge-slug: anchored-task -->\n<!-- task: 79 -->\n# T\n' > "$t/.forge/plan.md"
printf 'run\n' > "$t/.forge/run.md"
printf 'slug: anchored-task\nstatus: executed\nverified: yes (t)\nretro: pending\n' > "$t/.forge/STATUS.md"
elsewhere=$(mktmp)   # cwd with no forge state at all
OUT="$( cd "$elsewhere" && CLAUDE_PROJECT_DIR="$t" bash "$WRAPPER" session-start 2>/dev/null )"; RC=$?
assert      "wrapper-projectdir-rc0" 0 "$RC"
assert_grep "wrapper-projectdir-anchored" "$OUT" '`anchored-task`'
rm -rf "$t" "$elsewhere"

# --- wrapper: node-only path (bash hidden) -> .js twin still answers -------
# Simulates a Windows-ish box with node but no bash: run the wrapper with `sh`
# and a PATH that has node but no bash, and point it at the twin directly.
t=$(mktmp); mkdir -p "$t/.forge"
printf '<!-- forge-slug: node-path -->\n<!-- task: 78 -->\n# T\n' > "$t/.forge/plan.md"
printf 'run\n' > "$t/.forge/run.md"
printf 'slug: node-path\nstatus: executed\nverified: yes (t)\nretro: pending\n' > "$t/.forge/STATUS.md"
OUT="$( cd "$t" && node "$HERE/../scripts/forge-hook-session-start.js" 2>/dev/null )"; RC=$?
assert      "node-twin-rc0" 0 "$RC"
assert_grep "node-twin-block" "$OUT" '`node-path`'
rm -rf "$t"

printf '\nrun-hook wiring: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
