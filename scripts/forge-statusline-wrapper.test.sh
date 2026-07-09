#!/usr/bin/env bash
# Tests for forge-statusline-wrapper.sh — the composition wrapper that runs the
# user's original statusline, then appends the forge fragment as a row below.
#
# The wrapper resolves its companion files (forge-statusline-orig.sh and
# forge-statusline.sh) from its OWN install directory (BASH_SOURCE), NOT from
# $CLAUDE_CONFIG_DIR — so each case installs all three into a fake config dir and
# runs the wrapper from there, with NO CLAUDE_CONFIG_DIR exported (proving the
# resolution does not depend on that env var). See ADR-0017.
#
# Run:  bash scripts/forge-statusline-wrapper.test.sh
# Exit: 0 if all pass, 1 otherwise.

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
WRAPPER="$DIR/forge-statusline-wrapper.sh"
FRAGMENT="$DIR/forge-statusline.sh"

pass=0
fail=0
assert() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf '  FAIL %s\n       expected: [%s]\n       actual:   [%s]\n' "$1" "$2" "$3"
  fi
}

mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgslw.XXXXXX"; }
write() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }
strip_ansi() { sed -E $'s/\x1b\\[[0-9;]*m//g'; }

# Build a fake install dir: the wrapper + the real fragment + a stub original
# statusline, all in ONE directory (the real install model). The stub proves the
# original is preserved AND that it receives stdin (it echoes a byte count).
setup_install() {
  mkdir -p "$1"
  cp "$WRAPPER" "$1/forge-statusline-wrapper.sh"
  cp "$FRAGMENT" "$1/forge-statusline.sh"
  cat > "$1/forge-statusline-orig.sh" <<'STUB'
#!/usr/bin/env bash
n=$(cat | wc -c | tr -d ' ')
printf 'ORIG-LINE(%s)\n' "$n"
STUB
}

# Run the installed wrapper from cwd $3 with JSON $2 on stdin (ANSI stripped —
# the exact color values are a live-tuned implementation detail, not a fixture
# concern; see .forge/adr/0017-statusline-integration.md's 2026-07-02 amendment).
# CRITICAL: no CLAUDE_CONFIG_DIR is set — the wrapper must find its companions
# from its own location ($1), not from any env var.
run_wrapper() { ( cd "$3" && unset CLAUDE_CONFIG_DIR; printf '%s' "$2" | bash "$1/forge-statusline-wrapper.sh" ) | strip_ansi; }

# --- Case: active forge -> ORIG line first, forge row appended below ----------
# State lives in project dir; wrapper invoked from an unrelated dir; JSON cwd
# points at the project. Proves: original preserved + forge appended + cwd
# re-fed to the fragment (it reads the project's .forge, not the wrapper's cwd).
h=$(mktmp); setup_install "$h"
proj=$(mktmp); other=$(mktmp)
write "$proj/.forge/plan.md" "<!-- forge-slug: w-task -->"
json="{\"cwd\":\"$proj\",\"model\":{\"display_name\":\"x\"}}"
out="$(run_wrapper "$h" "$json" "$other")"
# first line is the original; second line is the forge fragment
first="$(printf '%s\n' "$out" | sed -n '1{s/(.*//;p;}')"
second="$(printf '%s\n' "$out" | sed -n '2p')"
assert "wrapper-active-orig-first" "ORIG-LINE" "$first"
assert "wrapper-active-forge-row"  "[⚒ w-task · ✔ ask → ● run → ○ learn → ○ done]" "$second"
rm -rf "$h" "$proj" "$other"

# --- Case: idle forge -> only the ORIG line, no blank extra row --------------
h=$(mktmp); setup_install "$h"
proj=$(mktmp); other=$(mktmp)
mkdir -p "$proj/.forge/backlog"   # .forge exists but empty -> fragment prints nothing
json="{\"cwd\":\"$proj\"}"
out="$(run_wrapper "$h" "$json" "$other")"
linecount="$(printf '%s\n' "$out" | grep -c .)"
firstkind="$(printf '%s\n' "$out" | sed -n '1{s/(.*//;p;}')"
assert "wrapper-idle-single-line" "1" "$linecount"
assert "wrapper-idle-is-orig"     "ORIG-LINE" "$firstkind"
rm -rf "$h" "$proj" "$other"

# --- Case: original receives the session JSON on stdin -----------------------
# The stub echoes the byte count it read; assert it is non-zero (got the JSON).
h=$(mktmp); setup_install "$h"
proj=$(mktmp); other=$(mktmp)
mkdir -p "$proj/.forge"
json="{\"cwd\":\"$proj\",\"model\":{\"display_name\":\"sonnet\"}}"
out="$(run_wrapper "$h" "$json" "$other")"
nbytes="$(printf '%s\n' "$out" | sed -n '1{s/.*(\([0-9]*\)).*/\1/;p;}')"
if [ -n "$nbytes" ] && [ "$nbytes" -gt 0 ] 2>/dev/null; then ok=yes; else ok=no; fi
assert "wrapper-feeds-stdin-to-orig" "yes" "$ok"
rm -rf "$h" "$proj" "$other"

# --- Regression: custom install dir, NO CLAUDE_CONFIG_DIR ---------------------
# The wrapper is installed at a non-standard path and run with CLAUDE_CONFIG_DIR
# unset. It must still resolve its companions from its own dir and compose the
# output — not blank everything. (This is the Codex finding: runtime dependence
# on $CLAUDE_CONFIG_DIR blanked the whole statusline in custom-config setups.)
custom=$(mktmp)/cfg-XXX; mkdir -p "$custom"; setup_install "$custom"
proj=$(mktmp); other=$(mktmp)
write "$proj/.forge/plan.md" "<!-- forge-slug: reg-task -->"
json="{\"cwd\":\"$proj\",\"model\":{\"display_name\":\"x\"}}"
out="$(run_wrapper "$custom" "$json" "$other")"
first="$(printf '%s\n' "$out" | sed -n '1{s/(.*//;p;}')"
second="$(printf '%s\n' "$out" | sed -n '2p')"
assert "wrapper-customdir-orig-preserved" "ORIG-LINE" "$first"
assert "wrapper-customdir-forge-row"      "[⚒ reg-task · ✔ ask → ● run → ○ learn → ○ done]" "$second"
rm -rf "$custom" "$proj" "$other"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
