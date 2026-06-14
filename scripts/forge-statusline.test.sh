#!/usr/bin/env bash
# Fixture-based tests for forge-statusline.sh.
# Each case builds a throwaway .forge/ state in a temp dir, runs the script
# with that dir as cwd, and compares the single output line to an expectation.
#
# Run:  bash scripts/forge-statusline.test.sh
# Exit: 0 if all pass, 1 otherwise.

set -u

SCRIPT="$(cd "$(dirname "$0")" && pwd)/forge-statusline.sh"

pass=0
fail=0

# assert <name> <expected> <actual>
assert() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
    # printf '  ok   %s\n' "$1"
  else
    fail=$((fail + 1))
    printf '  FAIL %s\n       expected: [%s]\n       actual:   [%s]\n' "$1" "$2" "$3"
  fi
}

# Make a temp dir that is NOT a git repo (branch resolution falls back to .forge/).
mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgsl.XXXXXX"; }

# Run the script with the given dir as cwd, capture stdout (trailing newline stripped).
# No stdin (</dev/null) — exercises the "$PWD fallback" path when no session JSON is piped.
run_in() { ( cd "$1" && bash "$SCRIPT" </dev/null ); }

# Run from cwd $1 with JSON $2 piped on stdin — exercises the cwd-from-stdin path.
run_in_json() { ( cd "$1" && printf '%s' "$2" | bash "$SCRIPT" ); }

write() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }

# --- Case: no .forge at all -> empty -----------------------------------------
t=$(mktmp)
assert "no-forge-dir" "" "$(run_in "$t")"
rm -rf "$t"

# --- Case: idle (.forge exists, all empty) -> empty --------------------------
t=$(mktmp)
mkdir -p "$t/.forge/backlog" "$t/.forge/executed"
assert "idle-empty" "" "$(run_in "$t")"
rm -rf "$t"

# --- Case: active plan only (no run.md) -> run stage, no flag -----------------
t=$(mktmp)
write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"
assert "active-plan-only" "⚒ my-task:run" "$(run_in "$t")"
rm -rf "$t"

# --- Case: active plan + run + STATUS verified: pending -> learn, ⏳ ----------
t=$(mktmp)
write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"
write "$t/.forge/run.md" "run notes"
printf 'verified: pending\n' > "$t/.forge/STATUS.md"
assert "verified-pending" "⚒ my-task:learn ⏳" "$(run_in "$t")"
rm -rf "$t"

# --- Case: verified: yes -> learn, ✓ -----------------------------------------
t=$(mktmp)
write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"
write "$t/.forge/run.md" "run notes"
printf 'verified: yes (npm test → 42 passing)\n' > "$t/.forge/STATUS.md"
assert "verified-yes" "⚒ my-task:learn ✓" "$(run_in "$t")"
rm -rf "$t"

# --- Case: verified: failed -> learn, ✗ --------------------------------------
t=$(mktmp)
write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"
write "$t/.forge/run.md" "run notes"
printf 'verified: failed (UAT broke)\n' > "$t/.forge/STATUS.md"
assert "verified-failed" "⚒ my-task:learn ✗" "$(run_in "$t")"
rm -rf "$t"

# --- Case: verified: skipped -> learn, no flag -------------------------------
t=$(mktmp)
write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"
write "$t/.forge/run.md" "run notes"
printf 'verified: skipped (docs only)\n' > "$t/.forge/STATUS.md"
assert "verified-skipped" "⚒ my-task:learn" "$(run_in "$t")"
rm -rf "$t"

# --- Case: slug falls back to filename stem when no forge-slug comment --------
t=$(mktmp)
write "$t/.forge/plan.md" "# some title without slug comment"
assert "slug-fallback-filename" "⚒ plan:run" "$(run_in "$t")"
rm -rf "$t"

# --- Case: executed parked, no active -> awaiting retro ----------------------
t=$(mktmp)
mkdir -p "$t/.forge/executed/foo"
printf 'status: executed\n' > "$t/.forge/executed/foo/STATUS.md"
assert "executed-parked-1" "⚒ 📝 1 awaiting retro" "$(run_in "$t")"
rm -rf "$t"

# --- Case: backlog only -> queued count -------------------------------------
t=$(mktmp)
write "$t/.forge/backlog/a.md" "<!-- forge-slug: a -->"
write "$t/.forge/backlog/b.md" "<!-- forge-slug: b -->"
write "$t/.forge/backlog/c.md" "<!-- forge-slug: c -->"
assert "backlog-3" "⚒ 📋 3 queued" "$(run_in "$t")"
rm -rf "$t"

# --- Case: precedence active > executed > backlog ----------------------------
t=$(mktmp)
write "$t/.forge/plan.md" "<!-- forge-slug: active-one -->"
mkdir -p "$t/.forge/executed/foo"; printf 'status: executed\n' > "$t/.forge/executed/foo/STATUS.md"
write "$t/.forge/backlog/a.md" "<!-- forge-slug: a -->"
assert "precedence-active-wins" "⚒ active-one:run" "$(run_in "$t")"
rm -rf "$t"

# --- Case: loop.md active + active plan -> 🔁 prefix --------------------------
t=$(mktmp)
write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"
printf '# LOOP — reach green\nreplan-round: 2\nreplan-cap: 3\n' > "$t/.forge/loop.md"
assert "loop-prefix-active" "⚒ 🔁 r2/3 my-task:run" "$(run_in "$t")"
rm -rf "$t"

# --- Case: loop.md but idle -> show loop indicator alone ----------------------
t=$(mktmp)
mkdir -p "$t/.forge/backlog"
printf '# LOOP — reach green\nreplan-round: 0\nreplan-cap: 3\n' > "$t/.forge/loop.md"
assert "loop-idle" "⚒ 🔁 r0/3" "$(run_in "$t")"
rm -rf "$t"

# --- Case: branch root resolution (non-default branch) -----------------------
if command -v git >/dev/null 2>&1; then
  t=$(mktmp)
  ( cd "$t" && git init -q && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init ) 2>/dev/null
  default_branch="$(cd "$t" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
  ( cd "$t" && git checkout -q -b feature-x ) 2>/dev/null
  mkdir -p "$t/.forge"
  printf '{ "defaultBranch": "%s" }\n' "$default_branch" > "$t/.forge/config.json"
  # active plan lives under the branch root, NOT top-level .forge/
  mkdir -p "$t/.forge/branch/feature-x"
  write "$t/.forge/branch/feature-x/plan.md" "<!-- forge-slug: branch-task -->"
  assert "branch-root-resolution" "⚒ branch-task:run" "$(run_in "$t")"
  # a stray top-level plan must be ignored on a non-default branch
  write "$t/.forge/plan.md" "<!-- forge-slug: should-not-show -->"
  assert "branch-root-ignores-toplevel" "⚒ branch-task:run" "$(run_in "$t")"
  rm -rf "$t"
else
  printf '  skip git branch-root case (git not found)\n'
fi

# --- Case: cwd from stdin JSON ("cwd") redirects which .forge/ is read --------
# State lives in dir A; the script is invoked from an unrelated dir B with a
# session JSON whose "cwd" points at A. It must read A's state, not B's (empty).
a=$(mktmp); b=$(mktmp)
write "$a/.forge/plan.md" "<!-- forge-slug: cwd-task -->"
assert "stdin-cwd-redirects" "⚒ cwd-task:run" "$(run_in_json "$b" "{\"cwd\":\"$a\",\"model\":{\"display_name\":\"x\"}}")"
rm -rf "$a" "$b"

# --- Case: cwd falls back to workspace.current_dir when no top-level "cwd" -----
a=$(mktmp); b=$(mktmp)
write "$a/.forge/plan.md" "<!-- forge-slug: ws-task -->"
assert "stdin-workspace-current-dir" "⚒ ws-task:run" "$(run_in_json "$b" "{\"workspace\":{\"current_dir\":\"$a\"}}")"
rm -rf "$a" "$b"

# --- Case: stdin JSON without any cwd -> falls back to $PWD -------------------
a=$(mktmp)
write "$a/.forge/plan.md" "<!-- forge-slug: pwd-task -->"
assert "stdin-no-cwd-uses-pwd" "⚒ pwd-task:run" "$(run_in_json "$a" "{\"model\":{\"display_name\":\"x\"}}")"
rm -rf "$a"

# --- Case: stdin cwd points at a nonexistent dir -> falls back to $PWD --------
a=$(mktmp)
write "$a/.forge/plan.md" "<!-- forge-slug: missing-cwd -->"
assert "stdin-cwd-nonexistent-falls-back" "⚒ missing-cwd:run" "$(run_in_json "$a" "{\"cwd\":\"/no/such/dir/xyz123\"}")"
rm -rf "$a"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
