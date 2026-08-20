#!/usr/bin/env bash
# forge-loop-spend.sh — measure a goal loop's cumulative token spend and judge it
# against loop.md's declared ceiling (ADR-0016, amended 2026-08-19 / 2026-08-20).
#
# Why a script: summing per-message `usage` across a session transcript plus every
# workflow subagent transcript is purely mechanical, and having an LLM read those
# files would burn tokens to measure tokens (ADR-0031, leg 2).
#
# WHAT THIS NUMBER IS. The raw sum of four usage fields — input_tokens,
# cache_creation_input_tokens, cache_read_input_tokens, output_tokens — over every
# `message.usage` in this PROJECT's transcripts since the `since:` stamp. So it is
# token THROUGHPUT for the whole project while the loop is alive, NOT "this drive's
# billed cost": cache reads are far cheaper per token, and work a human does in this
# repo between a wall and a resume lands in the next delta. Both are accepted
# (ADR-0016 amended 2026-08-20): this is a SAFETY BOUND, not an accounting ledger,
# and over-counting is the safe direction — an early halt is raised by a human,
# whereas under-counting means the ceiling never fires at all. Counting cache reads
# is the point: they ARE the context re-sent on every iteration, the compounding a
# round cap cannot see.
#
# Exit codes (fg-loop routes on these; stdout carries `TOKEN detail`):
#   0   OK spent=N cap=M remaining=R          — within budget
#   0   NONE no-budget-declared               — `budget-tokens: none`, checks bypassed
#   3   EXHAUSTED spent=N cap=M               — overrun          -> budget-exhausted wall
#   4   PREFLIGHT-HALT spent=N cap=M avg=A remaining=R
#                                             — predicted overrun -> budget-exhausted wall
#   5   BLOCKED <reason>                      — a ceiling IS declared but cannot be
#                                               measured -> blocked-health wall. Never
#                                               report 0 spend in this case: "nothing
#                                               spent yet" and "cannot measure" must not
#                                               look alike, or the ceiling silently
#                                               never fires (ADR-0016 amended 2026-08-20).
#   2   EMPTY no-loop-md                      — no goal loop in flight
#   64  usage error
#
# Dual dispatch (ADR-0022): bash primary, forge-loop-spend.js is the node fallback.
#
# Usage:
#   bash scripts/forge-loop-spend.sh [--transcripts DIR] [--now ISO]
#     --transcripts DIR override the transcript root (tests; default is derived from
#                       the session cwd under ~/.claude/projects/)
#     --now ISO         override the `since:` stamp written back (tests)
#
# ONE CALL PER TASK BOUNDARY — there is no --preflight flag. Post-hoc and pre-flight
# were two calls at what is the same moment, and the first advanced `since:`, so the
# second re-counted the interval (measured 10 -> 20). One call now yields both
# verdicts (ADR-0016 amended 2026-08-20).
set -u

tdir=""
now=""

while [ $# -gt 0 ]; do
  case "$1" in
    --transcripts) shift; [ $# -gt 0 ] || { echo "forge-loop-spend: --transcripts needs a value" >&2; exit 64; }; tdir="$1" ;;
    --now) shift; [ $# -gt 0 ] || { echo "forge-loop-spend: --now needs a value" >&2; exit 64; }; now="$1" ;;
    *) echo "forge-loop-spend: unknown arg: $1" >&2; exit 64 ;;
  esac
  shift
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# stderr suppressed to match the node twin, which calls resolveForgeRoot() as a
# library and so never emits the standalone fallback warning (same convention as
# forge-done.sh / forge-doctor.sh / forge-status.sh).
root="$(bash "$here/resolve-forge-root.sh" 2>/dev/null)"
loop="$root/loop.md"

[ -f "$loop" ] || { echo "EMPTY no-loop-md"; exit 2; }

# Full millisecond precision — flooring to whole seconds made a message that arrived
# later in the stamped second get re-counted at the next boundary.
[ -n "$now" ] || now="$(date -u +%Y-%m-%dT%H:%M:%S).$(date -u +%N 2>/dev/null | cut -c1-3 | sed 's/^$/000/')Z"
case "$now" in *..*|*.Z) now="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" ;; esac

# --- read the contract fields -------------------------------------------------
# `tr -d '\r'` so a CRLF-authored loop.md parses (the convention 5 sibling scripts
# already follow); without it bash died at exit 64 while node passed.
field() { sed -n "s/^$1:[[:space:]]*\(.*\)$/\1/p" "$loop" | head -1 | tr -d '\r'; }

cap_raw="$(field budget-tokens)"
[ -n "$cap_raw" ] || cap_raw="none"
# Read the LEADING token and tolerate a trailing annotation — the loop.md template
# itself annotates its fields inline, so rejecting the whole line would make the
# ceiling fail OPEN (exit 64 is "not a budget verdict", i.e. the drive continues
# unmetered). An undeclared-but-unparseable ceiling is BLOCKED, never ignored.
cap_tok="${cap_raw%%[!0-9]*}"
case "$cap_raw" in
  none|None|NONE) echo "NONE no-budget-declared"; exit 0 ;;
  none[!A-Za-z0-9]*|None[!A-Za-z0-9]*|NONE[!A-Za-z0-9]*) echo "NONE no-budget-declared"; exit 0 ;;
esac
[ -n "$cap_tok" ] || { echo "BLOCKED cap-unparseable ($cap_raw)"; exit 5; }
# base-10 forced: a leading zero made bash read `0100` as octal 64.
cap=$((10#$cap_tok))
[ "$cap" -gt 0 ] || { echo "BLOCKED cap-not-positive ($cap_raw)"; exit 5; }

spent_raw="$(field budget-spent)"
spent_prev="$(printf '%s' "$spent_raw" | sed -n 's/^\([0-9]*\).*/\1/p')"
[ -n "$spent_prev" ] || spent_prev=0
since="$(printf '%s' "$spent_raw" | sed -n 's/.*since:[[:space:]]*\([^ ]*\).*/\1/p')"

# A `since:` that is present but not a timestamp — the template placeholder `{ISO}`
# is the case that actually happens — compares greater than every real stamp, so the
# delta is silently 0 forever. Same silent-bypass class as an unreadable transcript
# root, so same verdict.
baseline=0
if [ -z "$since" ]; then
  since="$now"; baseline=1
else
  case "$since" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*) : ;;
    *) echo "BLOCKED since-unparseable ($since)"; exit 5 ;;
  esac
fi

# --- locate the transcripts ---------------------------------------------------
# Claude Code names the project dir after the session CWD with EVERY non-alphanumeric
# replaced by `-`. Verified against real dirs: /Users/gyuha/.settings/bin ->
# `-Users-gyuha--settings-bin` (so `.` collapses too, and the basis is the cwd, not
# the git toplevel, which for that path is the parent). The old `tr '/' '-'` +
# git-toplevel derivation pointed at a directory that does not exist for any repo
# whose path holds a `.`, `_`, space or non-ASCII character.
if [ -z "$tdir" ]; then
  home="${HOME:-}"
  if [ -z "$home" ]; then
    echo "BLOCKED transcripts-unreadable (HOME unset)"; exit 5
  fi
  cwd="$(pwd -P 2>/dev/null || pwd)"
  slug="$(printf '%s' "$cwd" | tr -c 'A-Za-z0-9' '-')"
  tdir="$home/.claude/projects/$slug"
fi

# Checked BEFORE the baseline shortcut: a ceiling that can never be measured must
# surface at the START of a drive, not several tasks in.
[ -d "$tdir" ] || { echo "BLOCKED transcripts-unreadable ($tdir)"; exit 5; }

# --- sum the delta ------------------------------------------------------------
delta=0
if [ "$baseline" -eq 0 ]; then
  # ONE awk process, fed the file LIST on stdin and opening each file itself. The
  # previous `xargs -0 awk` split the list above ARG_MAX into several awk runs whose
  # END blocks each printed a partial total, and the totals CONCATENATED into a
  # nonsense number (reproduced: 3 files -> "111" instead of "3") which then poisoned
  # the ledger permanently.
  delta="$(
    find "$tdir" -type f -name '*.jsonl' 2>/dev/null | sort | awk -v since="$since" '
      function sumfield(line, pat,    s, m) {
        s = 0
        while (match(line, pat)) {
          m = substr(line, RSTART, RLENGTH)
          sub(/^.*:/, "", m)
          s += m + 0
          line = substr(line, RSTART + RLENGTH)
        }
        return s
      }
      {
        fname = $0
        while ((getline line < fname) > 0) {
          if (line !~ /"usage"/) continue
          if (!match(line, /"timestamp":"[^"]*"/)) continue
          ts = substr(line, RSTART, RLENGTH)
          sub(/^"timestamp":"/, "", ts)
          sub(/"$/, "", ts)
          if (ts <= since) continue

          # Count ONLY the message.usage of this entry. Two exclusions, both measured
          # to double-count the very same tokens. NOTE: no apostrophes in this awk
          # program — it is inside a single-quoted shell string and one would end it.
          #
          # (1) toolUseResult.usage — a SUBAGENT spend figure reported back into the
          #     parent transcript. That subagent has its own transcript under
          #     <session>/subagents/, which we already read, so counting this entry
          #     bills it twice. Detected positionally: when "toolUseResult" occurs
          #     before the single unescaped "usage": on the line, the entry is a tool
          #     result, not an assistant message. (Measured: exactly one such line in
          #     the real corpus, worth 35,447 tokens — precisely the residual error.)
          # (2) usage.iterations[] — mirrors the same four fields once per iteration,
          #     so a whole-line scan counts each 1+N times (measured 1.928x).
          pu = index(line, "\"usage\":")
          if (pu > 0) {
            pt = index(line, "\"toolUseResult\"")
            if (pt > 0 && pt < pu) continue
          }
          stripped = line
          gsub(/"iterations":\[[^]]*\]/, "", stripped)

          # The patterns MUST be passed as STRINGS. A regex constant used as a
          # function argument in awk is evaluated as `$0 ~ /re/` and collapses to
          # 0/1 — which silently sums garbage instead of the token counts.
          t += sumfield(stripped, "\"input_tokens\":[0-9]+")
          t += sumfield(stripped, "\"cache_creation_input_tokens\":[0-9]+")
          t += sumfield(stripped, "\"cache_read_input_tokens\":[0-9]+")
          t += sumfield(stripped, "\"output_tokens\":[0-9]+")
        }
        close(fname)
      }
      END { printf "%d", t + 0 }
    '
  )"
  [ -n "$delta" ] || delta=0
fi

spent=$((spent_prev + delta))
remaining=$((cap - spent))
[ "$remaining" -lt 0 ] && remaining=0

# --- write the ledger back ----------------------------------------------------
# awk, not sed: `sed s|^budget-spent:.*|…|` replaced EVERY matching line while the
# node twin replaced only the first, so a duplicated field left the twins with
# different files. First occurrence only, both twins.
tmp="$loop.tmp.$$"
if grep -q '^budget-spent:' "$loop"; then
  awk -v val="budget-spent: $spent · since: $now" '
    !done_ && /^budget-spent:/ { print val; done_ = 1; next } { print }
  ' "$loop" > "$tmp" || { echo "BLOCKED ledger-write-failed"; rm -f "$tmp"; exit 5; }
else
  awk -v cap="budget-tokens: $cap" -v val="budget-spent: $spent · since: $now" '
    !done_ && /^budget-tokens:/ { print cap; print val; done_ = 1; next } { print }
  ' "$loop" > "$tmp" || { echo "BLOCKED ledger-write-failed"; rm -f "$tmp"; exit 5; }
fi
# A silently-failed write loses spend and reports success — check it.
[ -s "$tmp" ] || { echo "BLOCKED ledger-write-failed"; rm -f "$tmp"; exit 5; }
mv "$tmp" "$loop" || { echo "BLOCKED ledger-write-failed"; rm -f "$tmp"; exit 5; }

# --- judge --------------------------------------------------------------------
if [ "$spent" -ge "$cap" ]; then
  echo "EXHAUSTED spent=$spent cap=$cap"
  exit 3
fi

# Pre-flight: refuse to START a task the remaining budget probably cannot cover.
# Observed per-task average = spend / member tasks already sealed. The first task has
# no average, so it always starts (worst-case overshoot is bounded at one task).
sealed=0
members="$(
  sed -n '/^## Tasks/,/^## /p' "$loop" | tr -d '\r' | sed -n 's/^[[:space:]]*-[[:space:]]*//p' |
  sed -e 's/^\[[ xX]\][[:space:]]*//' -e 's/^`//' -e 's/`.*$//' -e 's/[[:space:]].*$//'
)"
for m in $members; do
  [ -n "$m" ] || continue
  case "$m" in '##'*) continue ;; esac
  # Match the STATUS `slug:` field exactly. The old `done/*-<slug>/` glob also matched
  # `2026-08-19-fix-alpha` for member `alpha`, inflating the sealed count and so
  # LOWERING the average — an under-halt, the unsafe direction.
  for d in "$root/done/"*/; do
    [ -d "$d" ] || continue
    st="$d/STATUS.md"; [ -f "$st" ] || continue
    s_slug="$(sed -n 's/^slug:[[:space:]]*\(.*\)$/\1/p' "$st" | head -1 | tr -d '\r')"
    [ "$s_slug" = "$m" ] || continue
    if grep -qs '^status: done' "$st"; then sealed=$((sealed + 1)); fi
    break
  done
done
if [ "$sealed" -gt 0 ]; then
  avg=$((spent / sealed))
  if [ "$remaining" -lt "$avg" ]; then
    echo "PREFLIGHT-HALT spent=$spent cap=$cap avg=$avg remaining=$remaining"
    exit 4
  fi
fi

echo "OK spent=$spent cap=$cap remaining=$remaining"
exit 0
