#!/usr/bin/env bash
# Fixture-based tests for forge-hook-stop.sh — the Stop hook body that keeps an
# unattended forge drive going across turn boundaries WITHOUT the harness `/goal`
# (ADR-0028 amended 2026-08-22).
#
# Why this hook may block at all: `/goal` is a session-scoped Stop hook only the
# USER can type, so a drive that yields the turn stalls. forge ships its own Stop
# hook instead; a plugin hooks/hooks.json may provide one, and on a Stop event
# `exit 2` prevents stopping and continues the conversation.
#
# THE SAFETY INVARIANT UNDER TEST: every failure and every ambiguous path allows
# stopping (exit 0). Only one narrow case blocks — a drive marker that exists AND
# is inside both bounds AND belongs to this session. There is no harness-side
# loop protection (no `stop_hook_active`-style field), so these bounds are the
# ONLY runaway guard; that is why they are tested case by case rather than
# assumed.
#
# The hook never judges walls. The drive deletes `<root>/drive.md` when it reaches
# its terminal state or a wall; marker-absent is how "you may stop" is expressed.
# So this script stays dumb — the riskiest thing in the repo should be simple.
#
# Contract under test:
#   exit 0, silent  — no marker / age > MAX_AGE / blocked >= MAX_BLOCKED /
#                     session mismatch / unparseable marker / counter write fails /
#                     not a forge project
#   exit 2          — marker present, both bounds OK, session matches:
#                     stderr carries the continue directive AND `blocked` is
#                     incremented in the marker
#
# Run:  bash scripts/forge-hook-stop.test.sh
#       (or FGHOOK_IMPL=/abs/path/forge-hook-stop.js bash …)
# Exit: 0 if all pass, 1 otherwise.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="${FGHOOK_IMPL:-$HERE/forge-hook-stop.sh}"
case "$IMPL" in *.js) RUN=(node "$IMPL");; *) RUN=(bash "$IMPL");; esac

pass=0; fail=0
NOW=1787040000            # fixed clock for determinism (--now, like forge-loop-spend)
SID="sess-abc-123"
STDIN_JSON="{\"session_id\":\"$SID\",\"cwd\":\"/tmp\",\"hook_event_name\":\"Stop\"}"

mktmp() { mktemp -d "${TMPDIR:-/tmp}/fghs.XXXXXX"; }

# write_marker <dir> <started-epoch> <blocked> <session>
write_marker() {
  mkdir -p "$1/.forge"
  { printf '# DRIVE — unattended drive in progress\n'
    printf 'started: %s\n' "$2"
    printf 'blocked: %s\n' "$3"
    printf 'session: %s\n' "$4"
  } > "$1/.forge/drive.md"
}

# run_case <desc> <dir> <expected-exit> [expect-stderr-substring]
run_case() {
  local desc="$1" dir="$2" want="$3" needle="${4:-}"
  local out err rc
  out="$(cd "$dir" && printf '%s' "$STDIN_JSON" | "${RUN[@]}" --now "$NOW" 2>/tmp/fghs.err)"; rc=$?
  err="$(cat /tmp/fghs.err)"
  if [ "$rc" != "$want" ]; then
    echo "FAIL - $desc  (exit want=$want got=$rc; stderr=${err:0:90})"; fail=$((fail+1)); return
  fi
  if [ "$want" = 0 ] && [ -n "$out$err" ]; then
    echo "FAIL - $desc  (exit 0 must be silent; stdout=${out:0:60} stderr=${err:0:60})"; fail=$((fail+1)); return
  fi
  if [ -n "$needle" ] && ! printf '%s' "$err" | grep -q "$needle"; then
    echo "FAIL - $desc  (stderr missing '$needle'; got=${err:0:120})"; fail=$((fail+1)); return
  fi
  echo "ok   - $desc"; pass=$((pass+1))
}

# --- (a) no marker -> allow stop, silent. The overwhelmingly common case: every
#         session that is not driving must be untouched.
D=$(mktmp); mkdir -p "$D/.forge"
run_case "no drive marker -> exit 0 silent" "$D" 0
rm -rf "$D"

# --- (b) marker inside both bounds -> BLOCK, directive on stderr, counter bumped
D=$(mktmp); write_marker "$D" "$((NOW - 60))" 0 "$SID"
run_case "marker in bounds -> exit 2 + directive" "$D" 2 "drive"
b="$(sed -n 's/^blocked:[[:space:]]*\([0-9]*\).*/\1/p' "$D/.forge/drive.md" | head -1)"
if [ "$b" = "1" ]; then echo "ok   - blocked counter 0 -> 1"; pass=$((pass+1))
else echo "FAIL - blocked counter want=1 got=$b"; fail=$((fail+1)); fi
rm -rf "$D"

# --- (c) age bound: a session that died mid-drive leaves a stale marker; only the
#         TIME bound clears that (the iteration count survives a restart).
D=$(mktmp); write_marker "$D" "$((NOW - 1801))" 0 "$SID"
run_case "age > 30min -> exit 0" "$D" 0
rm -rf "$D"

# --- (d) iteration bound: a drive re-deriving the same step would burn tokens
#         until the time bound; only the BLOCK COUNT stops that promptly.
D=$(mktmp); write_marker "$D" "$((NOW - 60))" 50 "$SID"
run_case "blocked >= 50 -> exit 0" "$D" 0
rm -rf "$D"

# --- (e) session mismatch: this repo has had concurrent peer sessions (a peer
#         authored plan #120), so one session's marker must not block another's.
D=$(mktmp); write_marker "$D" "$((NOW - 60))" 0 "other-session"
run_case "session mismatch -> exit 0" "$D" 0
rm -rf "$D"

# --- (f) unparseable marker -> allow stop (never guess at a block)
D=$(mktmp); mkdir -p "$D/.forge"; printf 'garbage not a marker\n' > "$D/.forge/drive.md"
run_case "unparseable marker -> exit 0" "$D" 0
rm -rf "$D"

# --- (g) counter write fails (read-only marker) -> allow stop. Blocking without
#         being able to count would defeat the iteration bound entirely.
D=$(mktmp); write_marker "$D" "$((NOW - 60))" 0 "$SID"; chmod 444 "$D/.forge/drive.md"; chmod 555 "$D/.forge"
run_case "counter write fails -> exit 0" "$D" 0
chmod 755 "$D/.forge"; chmod 644 "$D/.forge/drive.md"; rm -rf "$D"

# --- (h) not a forge project at all -> allow stop
D=$(mktmp)
run_case "no .forge/ -> exit 0" "$D" 0
rm -rf "$D"

# --- (i) missing stdin session_id: the marker cannot be proven to be ours
D=$(mktmp); write_marker "$D" "$((NOW - 60))" 0 "$SID"
out="$(cd "$D" && printf '%s' '{}' | "${RUN[@]}" --now "$NOW" 2>/dev/null)"; rc=$?
if [ "$rc" = 0 ]; then echo "ok   - stdin without session_id -> exit 0"; pass=$((pass+1))
else echo "FAIL - stdin without session_id want=0 got=$rc"; fail=$((fail+1)); fi
rm -rf "$D"

printf '\nforge-hook-stop [%s]: %s passed, %s failed\n' "$(basename "$IMPL")" "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
