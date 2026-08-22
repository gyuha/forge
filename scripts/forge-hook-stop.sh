#!/usr/bin/env bash
# forge-hook-stop.sh — Stop hook body: keep an unattended forge drive going across
# turn boundaries without the harness `/goal` (ADR-0028 amended 2026-08-22).
#
# Why this exists: `/goal` is a session-scoped Stop hook only the USER can type, so
# a drive that yields the turn stalls after one cycle — the reported pain. forge
# ships its own Stop hook instead. On a Stop event `exit 2` prevents stopping and
# continues the conversation, and the blocking message is this script's stderr.
#
# THE SAFETY INVARIANT: every failure and every ambiguous path allows stopping
# (exit 0). Only one narrow case blocks. This matters more than usual because the
# harness provides NO loop protection for Stop hooks (there is no
# `stop_hook_active`-style input field), so the two bounds below are the ONLY
# runaway guard. It also composes with the harness's own exit-code semantics:
# exit 0 proceeds and exit 1 is a non-blocking error that also proceeds, so a
# crash in this script degrades to "you may stop", never to a wedged session.
#
# This hook does NOT judge walls. The drive owns that: it deletes drive.md when it
# reaches its terminal state or a wall, and marker-absent is how "you may stop" is
# expressed. Keeping the hook dumb is deliberate — the riskiest thing forge ships
# should be the simplest.
#
# Marker (`<forge-root>/drive.md`), written and deleted by the drive:
#   started: <epoch seconds>   # epoch, not ISO: `date -d` (GNU) vs `date -j -f`
#                              # (BSD) is a portability trap, and epoch is pure
#                              # arithmetic, so both twins compute it identically.
#   blocked: <count>           # incremented here, the only state this hook writes
#   session: <session id>      # so one session's drive never blocks another's
#
# Dual dispatch (ADR-0022): this is the bash primary; forge-hook-stop.js is the
# node twin (guarded by forge-hook-stop.parity.test.sh). The twins reach the same
# verdict by DIFFERENT routes on purpose — bash greps/seds the raw text, node
# parses structure — so parity is a real cross-check, not two copies of one
# mistake (ADR-0022 amended 2026-08-20).
#
# Usage:  bash scripts/forge-hook-stop.sh [--now <epoch>]   (hook JSON on stdin)
set -u
export LC_ALL=C

MAX_AGE=1800      # 30 min. Clears a marker left by a session that died mid-drive.
MAX_BLOCKED=50    # Stops a drive that re-derives the same step; the age bound
                  # would only catch that after 30 min of burning tokens.

NOW=""
while [ $# -gt 0 ]; do
  case "$1" in
    --now) NOW="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
case "$NOW" in ''|*[!0-9]*) NOW="$(date +%s 2>/dev/null || echo '')" ;; esac
case "$NOW" in ''|*[!0-9]*) exit 0 ;; esac   # no usable clock -> allow stop

# stdin: the hook payload. Never block on a tty (that would hang a session).
payload=""
[ -t 0 ] || payload="$(cat 2>/dev/null || true)"
sid="$(printf '%s' "$payload" | tr -d '\r' \
       | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$sid" ] || exit 0                       # cannot prove the marker is ours

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 2>/dev/null: the resolver warns on a detached HEAD, and any stderr here would
# become the *blocking message* on exit 2 and break the exit-0-is-silent contract
# (the same leak forge-loop-spend's parity test caught).
root="$(bash "$SCRIPT_DIR/resolve-forge-root.sh" 2>/dev/null)"
[ -n "$root" ] || exit 0
marker="$root/drive.md"
[ -f "$marker" ] || exit 0

field() { sed -n "s/^$1:[[:space:]]*\([^ ]*\).*/\1/p" "$marker" | tr -d '\r' | head -1; }
started="$(field started)"; blocked="$(field blocked)"; msession="$(field session)"

case "$started" in ''|*[!0-9]*) exit 0 ;; esac   # unparseable -> allow stop
case "$blocked" in ''|*[!0-9]*) exit 0 ;; esac
[ -n "$msession" ] || exit 0
[ "$msession" = "$sid" ] || exit 0               # another session's drive

[ "$((NOW - started))" -le "$MAX_AGE" ] || exit 0
[ "$blocked" -lt "$MAX_BLOCKED" ] || exit 0

# Bump the counter BEFORE blocking: if we cannot record the attempt the iteration
# bound is unenforceable, so a write failure must allow stopping rather than block
# uncounted. Temp file lives beside the marker so a read-only dir fails here.
next=$((blocked + 1))
tmp="$marker.tmp.$$"
# The braces matter: `> "$tmp"` is the SHELL's redirection, so awk's own
# 2>/dev/null cannot suppress a "permission denied" from it. Grouping puts the
# redirection failure inside the silenced block — without this the read-only-dir
# case leaks a bash error to stderr and breaks the exit-0-is-silent contract
# (caught by the test, not by review).
if ! { awk -v n="$next" '
      !done && /^blocked:/ { print "blocked: " n; done=1; next }
      { print }
    ' "$marker" > "$tmp"; } 2>/dev/null; then rm -f "$tmp" 2>/dev/null; exit 0; fi
if ! mv "$tmp" "$marker" 2>/dev/null; then rm -f "$tmp" 2>/dev/null; exit 0; fi

# stderr becomes the message the agent reads. Keep it a directive, not a status
# line: it must tell the agent what to do next and how to release the block.
printf 'forge drive in progress (%s/%s blocked stops). Do not stop: derive the next step via fg-status'"'"'s state machine and continue the drive. Delete %s when you reach the terminal state or a wall.\n' \
  "$next" "$MAX_BLOCKED" "$marker" >&2
exit 2
