#!/usr/bin/env bash
# Fixture-based tests for forge-done.sh — the deterministic single-task seal
# primitive shared by fg-done / fg-done all / fg-next all (ADR-0030).
#
# It seals ONE already-executed task: pre-checks (empty / half-sealed / dup slug),
# gate enforcement (verified sealable + retro done-or-skipped → else NON-DESTRUCTIVE
# refuse with a non-zero exit, files untouched), STATUS close-out (status→done),
# atomic archive into done/<sealed-id>-<slug>/ (YYMMDD-HHMMSS; ADR 260719-161701 —
# grandfathered YYYY-MM-DD-slug dirs are still recognized), and emptying the source.
#
# Exit codes (the LLM routes on these):
#   0  sealed OK (or a half-sealed dir completed idempotently)
#   2  nothing to seal (empty state / slug not found)
#   3  verify gate: verified: is not sealable (pending/failed/missing) — no move
#   4  retro gate:  retro owed (no retro file and no --skip-retro) — no move
#   5  duplicate:   a done/<...>-<slug>/ already sealed (status: done) — no move
#
# Run:  bash scripts/forge-done.test.sh
# Exit: 0 if all pass, 1 otherwise.

set -u

SCRIPT="${FGDONE_IMPL:-$(cd "$(dirname "$0")" && pwd)/forge-done.sh}"
pass=0; fail=0
SID="260705-120000"   # injected sealed-id (YYMMDD-HHMMSS) for deterministic done-dir names

mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgdone.XXXXXX"; }

assert() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s\n    exp:[%s]\n    act:[%s]\n' "$1" "$2" "$3"; fi; }
assert_file() { if [ -e "$2" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s (missing: %s)\n' "$1" "$2"; fi; }
assert_nofile() { if [ ! -e "$2" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s (should NOT exist: %s)\n' "$1" "$2"; fi; }
assert_grep() { if grep -qF "$3" "$2" 2>/dev/null; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s (%s not in %s)\n' "$1" "$3" "$2"; fi; }

# run_done <cwd> [args...]  -> sets RC and OUT  (runner picked by impl extension)
run_done() {
  local wd="$1"; shift
  case "$SCRIPT" in
    *.js) OUT="$( cd "$wd" && node "$SCRIPT" "$@" 2>&1 )"; RC=$? ;;
    *)    OUT="$( cd "$wd" && bash "$SCRIPT" "$@" 2>&1 )"; RC=$? ;;
  esac
}

# seed an active-slot task: <dir> <slug> <verified-value> <retro-value>
seed_active() {
  mkdir -p "$1/.forge"
  printf '<!-- forge-slug: %s -->\n# T %s\n' "$2" "$2" > "$1/.forge/plan.md"
  printf 'run notes\n' > "$1/.forge/run.md"
  printf '# STATUS — %s\nslug: %s\nstatus: executed\nexecuted: 2026-07-01\nverified: %s\nretro: %s\n' \
    "$2" "$2" "$3" "$4" > "$1/.forge/STATUS.md"
}

# --- (a) empty state -> exit 2, nothing changed ------------------------------
t=$(mktmp); mkdir -p "$t/.forge"
run_done "$t" --completed 2026-07-05 --sealed-id "$SID"
assert "a-empty-rc2" 2 "$RC"
rm -rf "$t"

# --- (d) verify gate: pending/failed -> exit 3, NON-destructive ---------------
t=$(mktmp); seed_active "$t" "task-d1" "pending" "pending"
run_done "$t" --skip-retro "x" --completed 2026-07-05 --sealed-id "$SID"
assert "d1-pending-rc3" 3 "$RC"
assert_file "d1-plan-untouched" "$t/.forge/plan.md"
assert_nofile "d1-no-archive" "$t/.forge/done/$SID-task-d1"
rm -rf "$t"

t=$(mktmp); seed_active "$t" "task-d2" "failed (broke)" "pending"
run_done "$t" --skip-retro "x" --completed 2026-07-05 --sealed-id "$SID"
assert "d2-failed-rc3" 3 "$RC"
assert_file "d2-plan-untouched" "$t/.forge/plan.md"
rm -rf "$t"

# --- (e) retro gate: no retro file, no --skip-retro -> exit 4, non-destructive -
t=$(mktmp); seed_active "$t" "task-e" "yes (ok)" "pending"
run_done "$t" --completed 2026-07-05 --sealed-id "$SID"
assert "e-retro-owed-rc4" 4 "$RC"
assert_file "e-plan-untouched" "$t/.forge/plan.md"
rm -rf "$t"

# --- (f) normal seal: retro file present -> archived under YYMMDD-HHMMSS-slug --
t=$(mktmp); seed_active "$t" "task-f" "yes (npm test 42)" "pending"
mkdir -p "$t/.forge/retro"; printf '# retro\n' > "$t/.forge/retro/260701-090000-task-f.md"
run_done "$t" --completed 2026-07-05 --sealed-id "$SID"
assert "f-rc0" 0 "$RC"
assert_file "f-archived-plan" "$t/.forge/done/$SID-task-f/plan.md"
assert_file "f-archived-run" "$t/.forge/done/$SID-task-f/run.md"
assert_file "f-archived-status" "$t/.forge/done/$SID-task-f/STATUS.md"
assert_nofile "f-slot-plan-gone" "$t/.forge/plan.md"
assert_nofile "f-slot-run-gone" "$t/.forge/run.md"
assert_nofile "f-slot-status-gone" "$t/.forge/STATUS.md"
assert_grep "f-status-done" "$t/.forge/done/$SID-task-f/STATUS.md" "status: done"
assert_grep "f-completed-date-field" "$t/.forge/done/$SID-task-f/STATUS.md" "completed: 2026-07-05"
assert_grep "f-verified-preserved" "$t/.forge/done/$SID-task-f/STATUS.md" "verified: yes (npm test 42)"
assert_grep "f-retro-path" "$t/.forge/done/$SID-task-f/STATUS.md" "260701-090000-task-f.md"
rm -rf "$t"

# --- (f2) grandfathered retro filename (YYYY-MM-DD-slug) still paired ----------
t=$(mktmp); seed_active "$t" "task-f2" "yes (ok)" "pending"
mkdir -p "$t/.forge/retro"; printf '# retro\n' > "$t/.forge/retro/2026-07-01-task-f2.md"
run_done "$t" --completed 2026-07-05 --sealed-id "$SID"
assert "f2-rc0" 0 "$RC"
assert_grep "f2-old-retro-path" "$t/.forge/done/$SID-task-f2/STATUS.md" "2026-07-01-task-f2.md"
rm -rf "$t"

# --- (g) skip seal: --skip-retro records retro: skipped ----------------------
t=$(mktmp); seed_active "$t" "task-g" "yes (ok)" "pending"
run_done "$t" --skip-retro "fg-next all auto" --completed 2026-07-05 --sealed-id "$SID"
assert "g-rc0" 0 "$RC"
assert_grep "g-retro-skipped" "$t/.forge/done/$SID-task-g/STATUS.md" "retro: skipped (fg-next all auto)"
assert_grep "g-status-done" "$t/.forge/done/$SID-task-g/STATUS.md" "status: done"
rm -rf "$t"

# --- (h) --docs-updated arg (default none) -----------------------------------
t=$(mktmp); seed_active "$t" "task-h" "yes (ok)" "pending"
run_done "$t" --skip-retro "x" --docs-updated "ADR-0030; CONTEXT terms: none" --completed 2026-07-05 --sealed-id "$SID"
assert_grep "h-docs" "$t/.forge/done/$SID-task-h/STATUS.md" "docs updated: ADR-0030; CONTEXT terms: none"
rm -rf "$t"

t=$(mktmp); seed_active "$t" "task-h2" "yes (ok)" "pending"
run_done "$t" --skip-retro "x" --completed 2026-07-05 --sealed-id "$SID"
assert_grep "h2-docs-default-none" "$t/.forge/done/$SID-task-h2/STATUS.md" "docs updated: none"
rm -rf "$t"

# --- (i) review.md present -> moved with the task, reviewed: recorded ---------
t=$(mktmp); seed_active "$t" "task-i" "yes (ok)" "pending"
printf 'findings\n' > "$t/.forge/review.md"
run_done "$t" --skip-retro "x" --completed 2026-07-05 --sealed-id "$SID"
assert "i-rc0" 0 "$RC"
assert_file "i-review-archived" "$t/.forge/done/$SID-task-i/review.md"
assert_nofile "i-review-gone-from-slot" "$t/.forge/review.md"
assert_grep "i-reviewed-field" "$t/.forge/done/$SID-task-i/STATUS.md" "reviewed:"
rm -rf "$t"

# --- (j) executed/<slug> parked task (not the active slot) --------------------
t=$(mktmp); mkdir -p "$t/.forge/executed/task-j"
printf '<!-- forge-slug: task-j -->\n# T\n' > "$t/.forge/executed/task-j/plan.md"
printf 'run\n' > "$t/.forge/executed/task-j/run.md"
printf '# STATUS — J\nslug: task-j\nstatus: executed\nexecuted: 2026-07-03\nverified: yes (ok)\nretro: skipped (batch)\n' \
  > "$t/.forge/executed/task-j/STATUS.md"
run_done "$t" --slug task-j --completed 2026-07-05 --sealed-id "$SID"
assert "j-rc0" 0 "$RC"
assert_file "j-archived" "$t/.forge/done/$SID-task-j/plan.md"
assert_nofile "j-executed-dir-gone" "$t/.forge/executed/task-j"
assert_grep "j-status-done" "$t/.forge/done/$SID-task-j/STATUS.md" "status: done"
rm -rf "$t"

# --- (c) duplicate slug already sealed, GRANDFATHERED YYYY-MM-DD dir -> exit 5 -
t=$(mktmp); seed_active "$t" "task-c" "yes (ok)" "pending"
mkdir -p "$t/.forge/retro"; printf 'r\n' > "$t/.forge/retro/2026-07-01-task-c.md"
mkdir -p "$t/.forge/done/2026-07-01-task-c"
printf 'slug: task-c\nstatus: done\n' > "$t/.forge/done/2026-07-01-task-c/STATUS.md"
run_done "$t" --completed 2026-07-05 --sealed-id "$SID"
assert "c-dup-old-fmt-rc5" 5 "$RC"
assert_file "c-active-untouched" "$t/.forge/plan.md"
rm -rf "$t"

# --- (c2) duplicate slug already sealed, NEW YYMMDD-HHMMSS dir -> exit 5 -------
t=$(mktmp); seed_active "$t" "task-c2" "yes (ok)" "pending"
mkdir -p "$t/.forge/retro"; printf 'r\n' > "$t/.forge/retro/260701-090000-task-c2.md"
mkdir -p "$t/.forge/done/260701-090000-task-c2"
printf 'slug: task-c2\nstatus: done\n' > "$t/.forge/done/260701-090000-task-c2/STATUS.md"
run_done "$t" --completed 2026-07-05 --sealed-id "$SID"
assert "c2-dup-new-fmt-rc5" 5 "$RC"
assert_file "c2-active-untouched" "$t/.forge/plan.md"
rm -rf "$t"

# --- (b) half-sealed done/ (grandfathered YYYY-MM-DD dir) -> idempotent flip ---
t=$(mktmp); mkdir -p "$t/.forge/done/2026-07-02-task-b"
printf '# STATUS — B\nslug: task-b\nstatus: executed\nexecuted: 2026-07-02\nverified: yes (ok)\nretro: skipped (y)\n' \
  > "$t/.forge/done/2026-07-02-task-b/STATUS.md"
printf 'p\n' > "$t/.forge/done/2026-07-02-task-b/plan.md"
run_done "$t" --slug task-b --completed 2026-07-05 --sealed-id "$SID"
assert "b-halfsealed-rc0" 0 "$RC"
assert_grep "b-flipped-done" "$t/.forge/done/2026-07-02-task-b/STATUS.md" "status: done"
rm -rf "$t"

# --- (b2) half-sealed done/ (NEW YYMMDD-HHMMSS dir) -> idempotent flip ---------
t=$(mktmp); mkdir -p "$t/.forge/done/260702-100000-task-b2"
printf '# STATUS — B2\nslug: task-b2\nstatus: executed\nexecuted: 2026-07-02\nverified: yes (ok)\nretro: skipped (y)\n' \
  > "$t/.forge/done/260702-100000-task-b2/STATUS.md"
printf 'p\n' > "$t/.forge/done/260702-100000-task-b2/plan.md"
run_done "$t" --slug task-b2 --completed 2026-07-05 --sealed-id "$SID"
assert "b2-halfsealed-rc0" 0 "$RC"
assert_grep "b2-flipped-done" "$t/.forge/done/260702-100000-task-b2/STATUS.md" "status: done"
rm -rf "$t"

# --- (k) branch-isolated forge root (non-default branch) ----------------------
if command -v git >/dev/null 2>&1; then
  t=$(mktmp)
  ( cd "$t" && git init -q -b feature-x && git config user.email t@t && git config user.name t \
      && git commit -q --allow-empty -m init ) 2>/dev/null
  mkdir -p "$t/.forge"; printf '{ "defaultBranch": "main" }\n' > "$t/.forge/config.json"
  br="$t/.forge/branch/feature-x"
  mkdir -p "$br"
  printf '<!-- forge-slug: task-k -->\n# T\n' > "$br/plan.md"
  printf 'run\n' > "$br/run.md"
  printf '# STATUS — K\nslug: task-k\nstatus: executed\nexecuted: 2026-07-04\nverified: yes (ok)\nretro: pending\n' > "$br/STATUS.md"
  run_done "$t" --skip-retro "branch" --completed 2026-07-05 --sealed-id "$SID"
  assert "k-branch-rc0" 0 "$RC"
  assert_file "k-branch-archive" "$br/done/$SID-task-k/plan.md"
  assert_nofile "k-branch-slot-empty" "$br/plan.md"
  rm -rf "$t"
else
  printf '  skip branch-root case (git not found)\n'
fi

# --- (l) invalid --sealed-id -> exit 64, NON-destructive (path-traversal defense) ---
# The sealed-id is spliced into the done/ dir path, so a malformed value (separators,
# .. , slashes) must be rejected BEFORE any mutation. Valid form is bare YYMMDD-HHMMSS.
t=$(mktmp); seed_active "$t" "task-l" "yes (ok)" "pending"
run_done "$t" --skip-retro "x" --completed 2026-07-05 --sealed-id "../../etc"
assert "l-traversal-rc64" 64 "$RC"
assert_file "l-plan-untouched" "$t/.forge/plan.md"
assert_grep "l-status-still-executed" "$t/.forge/STATUS.md" "status: executed"
assert_nofile "l-no-done-dir" "$t/.forge/done"
rm -rf "$t"

t=$(mktmp); seed_active "$t" "task-l2" "yes (ok)" "pending"
run_done "$t" --skip-retro "x" --completed 2026-07-05 --sealed-id "260705/120000"
assert "l2-slash-rc64" 64 "$RC"
assert_file "l2-plan-untouched" "$t/.forge/plan.md"
rm -rf "$t"

t=$(mktmp); seed_active "$t" "task-l3" "yes (ok)" "pending"
run_done "$t" --skip-retro "x" --completed 2026-07-05 --sealed-id "26070-120000"   # 5-digit date
assert "l3-malformed-rc64" 64 "$RC"
assert_file "l3-plan-untouched" "$t/.forge/plan.md"
rm -rf "$t"

# valid bare id still seals normally (no false rejection)
t=$(mktmp); seed_active "$t" "task-l4" "yes (ok)" "pending"
run_done "$t" --skip-retro "x" --completed 2026-07-05 --sealed-id "260705-120000"
assert "l4-valid-rc0" 0 "$RC"
assert_file "l4-archived" "$t/.forge/done/260705-120000-task-l4/plan.md"
rm -rf "$t"

# --- (m) slug path traversal -> exit 64, NON-destructive (the OTHER half of DEST) ---
# DEST is done/<sealed-id>-<slug>; sealed-id is validated but slug (from the plan's
# forge-slug comment, or --slug) is the other unguarded half. A poisoned slug must be
# rejected before mutation so the final path can't escape done/ (completes #87's DoD).
t=$(mktmp); seed_active "$t" "x/../../../../PWNED" "yes (ok)" "pending"
run_done "$t" --skip-retro "x" --completed 2026-07-05 --sealed-id "260705-120000"
assert "m-slug-forge-slug-rc64" 64 "$RC"
assert_file "m-plan-untouched" "$t/.forge/plan.md"
assert_grep "m-status-still-executed" "$t/.forge/STATUS.md" "status: executed"
rm -rf "$t"

t=$(mktmp); seed_active "$t" "clean-slug" "yes (ok)" "pending"
run_done "$t" --slug "../../x" --skip-retro "x" --completed 2026-07-05 --sealed-id "260705-120000"
assert "m2-arg-slug-rc64" 64 "$RC"
assert_file "m2-plan-untouched" "$t/.forge/plan.md"
rm -rf "$t"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
