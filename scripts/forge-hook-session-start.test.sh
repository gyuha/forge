#!/usr/bin/env bash
# Fixture-based tests for forge-hook-session-start.sh — the SessionStart hook
# body that injects the unsealed-tail notice into the session context
# (ADR 260727-201031). Each case builds a throwaway .forge/ state in a temp dir,
# runs the script with that dir as cwd, and asserts the exact output content.
#
# Assertions are content-specific on purpose: the forge-doctor retro (2026-07-16)
# recorded that a behavior test asserting only "something was emitted" let a real
# bug through — the parity twin caught it instead. So here we assert the block's
# actual lines, not merely that it is non-empty.
#
# Contract under test:
#   - SILENT (empty stdout, exit 0) unless there is real debt: an unsealed active
#     slot (run.md present, STATUS status != done), a parked executed/<slug>/, or
#     a loop.md. A backlog-only or promoted-but-unrun state is NOT debt.
#   - When it speaks: a <forge-state> block listing at most 3 debt items
#     (active slot first, then parked dirs in name order), a "+N more parked"
#     line when truncated, an optional goal-loop line, an optional backlog count,
#     and the fixed weak-directive paragraph.
#   - Always exit 0 (a hook must never fail a session start).
#
# Run:  bash scripts/forge-hook-session-start.test.sh
#       (or FGHOOK_IMPL=/abs/path/forge-hook-session-start.js bash …)
# Exit: 0 if all pass, 1 otherwise.

set -u
SCRIPT="${FGHOOK_IMPL:-$(cd "$(dirname "$0")" && pwd)/forge-hook-session-start.sh}"
pass=0; fail=0

mktmp() { mktemp -d "${TMPDIR:-/tmp}/fghook.XXXXXX"; }

assert()      { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s\n       expected: [%s]\n       actual:   [%s]\n' "$1" "$2" "$3"; fi; }
assert_grep() { if printf '%s' "$2" | grep -qF -- "$3"; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s (missing: %s)\n       actual: [%s]\n' "$1" "$3" "$2"; fi; }
assert_ngrep() { if printf '%s' "$2" | grep -qF -- "$3"; then fail=$((fail+1)); printf '  FAIL %s (should NOT contain: %s)\n       actual: [%s]\n' "$1" "$3" "$2"; else pass=$((pass+1)); fi; }

run_hook() { local wd="$1"; shift
  case "$SCRIPT" in
    *.js) OUT="$( cd "$wd" && node "$SCRIPT" "$@" 2>/dev/null )"; RC=$? ;;
    *)    OUT="$( cd "$wd" && bash "$SCRIPT" "$@" 2>/dev/null )"; RC=$? ;;
  esac
}

# seed_status <file> <slug> <status> <verified> <retro>
seed_status() { printf '# STATUS — t\nslug: %s\nstatus: %s\nexecuted: 2026-07-20\nverified: %s\nretro: %s\n' "$2" "$3" "$4" "$5" > "$1"; }
seed_plan()   { printf '<!-- forge-slug: %s -->\n<!-- task: %s -->\n# %s\n' "$2" "$3" "$2" > "$1"; }

# --- (1) no .forge/ at all -> silence, exit 0 --------------------------------
t=$(mktmp)
run_hook "$t"
assert "1-no-forge-silent" "" "$OUT"
assert "1-no-forge-rc0" 0 "$RC"
rm -rf "$t"

# --- (2) done/ history only -> silence --------------------------------------
t=$(mktmp); mkdir -p "$t/.forge/done/2026-07-20-old"
seed_plan "$t/.forge/done/2026-07-20-old/plan.md" old 3
seed_status "$t/.forge/done/2026-07-20-old/STATUS.md" old done "yes (t)" "skipped (x)"
run_hook "$t"
assert "2-done-only-silent" "" "$OUT"
assert "2-done-only-rc0" 0 "$RC"
rm -rf "$t"

# --- (3) backlog only (3 plans) -> silence (a queue is not debt) -------------
t=$(mktmp); mkdir -p "$t/.forge/backlog"
seed_plan "$t/.forge/backlog/a.md" aaa 1
seed_plan "$t/.forge/backlog/b.md" bbb 2
seed_plan "$t/.forge/backlog/c.md" ccc 3
run_hook "$t"
assert "3-backlog-only-silent" "" "$OUT"
rm -rf "$t"

# --- (4) active slot executed & unsealed -> full block ----------------------
t=$(mktmp); mkdir -p "$t/.forge"
seed_plan "$t/.forge/plan.md" fg-agents-retro-fuel 41
printf 'run notes\n' > "$t/.forge/run.md"
seed_status "$t/.forge/STATUS.md" fg-agents-retro-fuel executed "yes (slice tests green)" pending
run_hook "$t"
assert "4-rc0" 0 "$RC"
assert_grep "4-open-tag"  "$OUT" "<forge-state>"
assert_grep "4-close-tag" "$OUT" "</forge-state>"
assert_grep "4-header"    "$OUT" "Unfinished forge work (not sealed yet):"
assert_grep "4-item"      "$OUT" "- task 41 \`fg-agents-retro-fuel\` — active slot, verified: yes (slice tests green), retro: pending"
assert_grep "4-directive" "$OUT" "Do NOT auto-run or auto-seal anything."
assert_grep "4-pointer"   "$OUT" "/forge:fg-next"
assert_ngrep "4-no-backlog-line" "$OUT" "Backlog:"
assert_ngrep "4-no-more-line"    "$OUT" "more parked"
rm -rf "$t"

# --- (4b) promoted-but-unrun plan (no run.md) is NOT debt -> silence --------
t=$(mktmp); mkdir -p "$t/.forge"
seed_plan "$t/.forge/plan.md" promoted-unrun 42
run_hook "$t"
assert "4b-plan-only-silent" "" "$OUT"
rm -rf "$t"

# --- (4c) sealed active slot (status: done) is NOT debt -> silence ----------
t=$(mktmp); mkdir -p "$t/.forge"
seed_plan "$t/.forge/plan.md" already-done 43
printf 'run\n' > "$t/.forge/run.md"
seed_status "$t/.forge/STATUS.md" already-done done "yes (t)" "skipped (x)"
run_hook "$t"
assert "4c-sealed-slot-silent" "" "$OUT"
rm -rf "$t"

# --- (5) 4 parked tasks -> list 3 + "(+1 more parked …)" --------------------
t=$(mktmp)
for s in p1 p2 p3 p4; do
  mkdir -p "$t/.forge/executed/$s"
  seed_plan "$t/.forge/executed/$s/plan.md" "$s" "1${s#p}"
  printf 'run\n' > "$t/.forge/executed/$s/run.md"
  seed_status "$t/.forge/executed/$s/STATUS.md" "$s" executed "yes (t)" pending
done
run_hook "$t"
assert_grep "5-p1"   "$OUT" "- task 11 \`p1\` — parked (executed/), verified: yes (t), retro: pending"
assert_grep "5-p3"   "$OUT" "\`p3\`"
assert_ngrep "5-p4-not-listed" "$OUT" "\`p4\`"
assert_grep "5-more" "$OUT" "(+1 more parked in .forge/executed/)"
rm -rf "$t"

# --- (6) loop.md present -> goal + wall line --------------------------------
t=$(mktmp); mkdir -p "$t/.forge"
printf '# LOOP — make the CI pipeline green\nstarted: 2026-07-20\nreplan-round: 2\nreplan-cap: 3\nwall: no-progress (C1)\n' > "$t/.forge/loop.md"
run_hook "$t"
assert_grep "6-goal" "$OUT" "Goal loop: make the CI pipeline green — wall: no-progress (C1)"
assert_grep "6-tag"  "$OUT" "<forge-state>"
rm -rf "$t"

# --- (6b) loop.md with wall: none -> in-flight wording ---------------------
t=$(mktmp); mkdir -p "$t/.forge"
printf '# LOOP — ship the exporter\nwall: none\n' > "$t/.forge/loop.md"
run_hook "$t"
assert_grep "6b-inflight" "$OUT" "Goal loop: ship the exporter — in flight"
rm -rf "$t"

# --- (7) debt + backlog 2 -> backlog count folded in -----------------------
t=$(mktmp); mkdir -p "$t/.forge/backlog"
seed_plan "$t/.forge/plan.md" active-thing 7
printf 'run\n' > "$t/.forge/run.md"
seed_status "$t/.forge/STATUS.md" active-thing executed "n/a (docs only)" pending
seed_plan "$t/.forge/backlog/x.md" xxx 8
seed_plan "$t/.forge/backlog/y.md" yyy 9
run_hook "$t"
assert_grep "7-backlog" "$OUT" "Backlog: 2 plan(s) waiting."
assert_grep "7-item"    "$OUT" "verified: n/a (docs only)"
rm -rf "$t"

# --- (8) non-default branch -> reads .forge/branch/<branch>/ ---------------
t=$(mktmp)
( cd "$t" && git init -q -b feature-x && git config user.email t@t && git config user.name t \
  && git commit -q --allow-empty -m init ) 2>/dev/null
mkdir -p "$t/.forge/branch/feature-x"
seed_plan "$t/.forge/branch/feature-x/plan.md" branch-task 55
printf 'run\n' > "$t/.forge/branch/feature-x/run.md"
seed_status "$t/.forge/branch/feature-x/STATUS.md" branch-task executed "yes (t)" pending
# a top-level (default-root) state must NOT be read on this branch
mkdir -p "$t/.forge/executed/wrong-root"
seed_plan "$t/.forge/executed/wrong-root/plan.md" wrong-root 56
seed_status "$t/.forge/executed/wrong-root/STATUS.md" wrong-root executed "yes (t)" pending
run_hook "$t"
assert_grep  "8-branch-task"      "$OUT" "\`branch-task\`"
assert_ngrep "8-not-default-root" "$OUT" "wrong-root"
rm -rf "$t"

# --- (9) dash-list STATUS fields + CRLF -> parsed like plain/LF ------------
t=$(mktmp); mkdir -p "$t/.forge"
printf '<!-- forge-slug: crlf-task -->\r\n<!-- task: 4 -->\r\n# T\r\n' > "$t/.forge/plan.md"
printf 'run\r\n' > "$t/.forge/run.md"
printf '# STATUS\r\n- slug: crlf-task\r\n- status: executed\r\n- verified: failed (button dead)\r\n- retro: pending\r\n' > "$t/.forge/STATUS.md"
run_hook "$t"
assert_grep "9-crlf-slug"     "$OUT" "\`crlf-task\`"
assert_grep "9-crlf-verified" "$OUT" "verified: failed (button dead)"
rm -rf "$t"

# --- (10) STATUS missing verified/retro -> treated as pending --------------
t=$(mktmp); mkdir -p "$t/.forge"
seed_plan "$t/.forge/plan.md" bare-status 12
printf 'run\n' > "$t/.forge/run.md"
printf '# STATUS\nslug: bare-status\nstatus: executed\n' > "$t/.forge/STATUS.md"
run_hook "$t"
assert_grep "10-defaults" "$OUT" "- task 12 \`bare-status\` — active slot, verified: pending, retro: pending"
rm -rf "$t"

# --- (11) no task marker -> slug only, no "task" prefix -------------------
t=$(mktmp); mkdir -p "$t/.forge"
printf '<!-- forge-slug: legacy-task -->\n# T\n' > "$t/.forge/plan.md"
printf 'run\n' > "$t/.forge/run.md"
seed_status "$t/.forge/STATUS.md" legacy-task executed "yes (t)" pending
run_hook "$t"
assert_grep  "11-no-task-prefix" "$OUT" "- \`legacy-task\` — active slot,"
assert_ngrep "11-no-task-word"   "$OUT" "task  \`legacy-task\`"
rm -rf "$t"

printf '\n%s: %d passed, %d failed\n' "$(basename "$SCRIPT")" "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
