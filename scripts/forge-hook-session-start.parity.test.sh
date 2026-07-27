#!/usr/bin/env bash
# Parity test (ADR-0022): forge-hook-session-start.sh and .js MUST produce
# identical output for the same .forge fixture. This is the real drift guard for
# the dual sh/js hook body — the forge-doctor retro (2026-07-16) recorded a bug
# that slipped past behavior assertions and was caught only here.
#
# `set -euo pipefail` so a failed mktemp / fixture build ABORTS rather than
# letting "both produced empty output, so they're equal" pass as PARITY OK.
# Populated cases additionally assert a sentinel substring, so a script that
# silently emitted nothing is a mismatch, not a pass.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SH="$HERE/forge-hook-session-start.sh"
JS="$HERE/forge-hook-session-start.js"
fails=0

norm() { sed -e 's/[[:space:]]*$//'; }

assert_parity() { # $1=desc  $2=workdir  $3=must-contain (optional; empty = expect silence)
  local desc="$1" wd="$2" must="${3:-}" out_sh out_js rc_sh rc_js
  out_sh="$(cd "$wd" && bash "$SH" 2>/dev/null | norm)"; rc_sh=$?
  out_js="$(cd "$wd" && node "$JS" 2>/dev/null | norm)"; rc_js=$?
  if [ "$out_sh" != "$out_js" ]; then
    echo "FAIL - $desc (sh≠js)"
    diff <(printf '%s\n' "$out_sh") <(printf '%s\n' "$out_js") || true
    fails=$((fails+1)); return
  fi
  if [ "$rc_sh" -ne 0 ] || [ "$rc_js" -ne 0 ]; then
    echo "FAIL - $desc (exit codes: sh=$rc_sh js=$rc_js — a hook must always exit 0)"
    fails=$((fails+1)); return
  fi
  if [ -n "$must" ] && ! printf '%s' "$out_sh" | grep -qF -- "$must"; then
    echo "FAIL - $desc (equal but missing sentinel '$must' — script likely didn't run)"
    fails=$((fails+1)); return
  fi
  if [ -z "$must" ] && [ -n "$out_sh" ]; then
    echo "FAIL - $desc (expected silence, got: $out_sh)"
    fails=$((fails+1)); return
  fi
  echo "ok   - $desc"
}

seed_status() { printf '# STATUS — t\nslug: %s\nstatus: %s\nexecuted: 2026-07-20\nverified: %s\nretro: %s\n' "$2" "$3" "$4" "$5" > "$1"; }
seed_plan()   { printf '<!-- forge-slug: %s -->\n<!-- task: %s -->\n# %s\n' "$2" "$3" "$2" > "$1"; }

# --- A: no .forge -> both silent ---------------------------------------------
A="$(mktemp -d)"
assert_parity "empty: no .forge dir" "$A" ""

# --- B: backlog only -> both silent (queue is not debt) ----------------------
B="$(mktemp -d)"; mkdir -p "$B/.forge/backlog"
seed_plan "$B/.forge/backlog/a.md" aaa 1
assert_parity "backlog only: silent" "$B" ""

# --- C: promoted-but-unrun plan -> both silent ------------------------------
C="$(mktemp -d)"; mkdir -p "$C/.forge"
seed_plan "$C/.forge/plan.md" promoted 2
assert_parity "plan.md without run.md: silent" "$C" ""

# --- D: full populated (active + 4 parked + loop + backlog) -----------------
D="$(mktemp -d)"; mkdir -p "$D/.forge/backlog"
seed_plan "$D/.forge/plan.md" active-thing 41
printf 'run notes\n' > "$D/.forge/run.md"
seed_status "$D/.forge/STATUS.md" active-thing executed "yes (npm test → 42 passing)" pending
for s in p1 p2 p3 p4; do
  mkdir -p "$D/.forge/executed/$s"
  seed_plan "$D/.forge/executed/$s/plan.md" "$s" "2${s#p}"
  seed_status "$D/.forge/executed/$s/STATUS.md" "$s" executed "n/a (docs only)" pending
done
printf '# LOOP — make the CI pipeline green\nwall: no-progress (C1)\n' > "$D/.forge/loop.md"
seed_plan "$D/.forge/backlog/q1.md" q1 50
seed_plan "$D/.forge/backlog/q2.md" q2 51
# 1 active + 4 parked = 5 items, capped at 3 -> "+2 more"
assert_parity "populated: active + parked truncation + loop + backlog" "$D" "(+2 more parked in"

# --- E: Hangul slugs -> byte-order sort must agree (LC_ALL=C vs Buffer.compare)
E="$(mktemp -d)"; mkdir -p "$E/.forge"
for s in 한글-작업 zzz-task 가나-작업; do
  mkdir -p "$E/.forge/executed/$s"
  seed_plan "$E/.forge/executed/$s/plan.md" "$s" 9
  seed_status "$E/.forge/executed/$s/STATUS.md" "$s" executed "yes (t)" pending
done
assert_parity "Hangul parked slugs: byte-order sort sh==js" "$E" "한글-작업"

# --- F: CRLF + dash-list STATUS fields -------------------------------------
F="$(mktemp -d)"; mkdir -p "$F/.forge"
printf '<!-- forge-slug: crlf-task -->\r\n<!-- task: 4 -->\r\n# T\r\n' > "$F/.forge/plan.md"
printf 'run\r\n' > "$F/.forge/run.md"
printf '# STATUS\r\n- slug: crlf-task\r\n- status: executed\r\n- verified: failed (button dead)\r\n- retro: pending\r\n' > "$F/.forge/STATUS.md"
assert_parity "CRLF + dash-list fields: sh==js" "$F" "failed (button dead)"

# --- G: loop.md only, wall: none -------------------------------------------
G="$(mktemp -d)"; mkdir -p "$G/.forge"
printf '# LOOP — ship the exporter\nwall: none\n' > "$G/.forge/loop.md"
assert_parity "loop only, no wall: in-flight wording" "$G" "in flight"

# --- H: STATUS missing fields / no markers ---------------------------------
H="$(mktemp -d)"; mkdir -p "$H/.forge"
printf '<!-- forge-slug: legacy -->\n# T\n' > "$H/.forge/plan.md"
printf 'run\n' > "$H/.forge/run.md"
printf '# STATUS\nslug: legacy\nstatus: executed\n' > "$H/.forge/STATUS.md"
assert_parity "no task marker + missing verified/retro: defaults" "$H" "verified: pending"

# --- I: non-default branch root -------------------------------------------
I="$(mktemp -d)"
( cd "$I" && git init -q -b feature-x && git config user.email t@t && git config user.name t \
  && git commit -q --allow-empty -m init ) 2>/dev/null
mkdir -p "$I/.forge/branch/feature-x"
seed_plan "$I/.forge/branch/feature-x/plan.md" branch-task 55
printf 'run\n' > "$I/.forge/branch/feature-x/run.md"
seed_status "$I/.forge/branch/feature-x/STATUS.md" branch-task executed "yes (t)" pending
assert_parity "non-default branch: root resolution sh==js" "$I" "branch-task"

# --- J: sealed active slot -> both silent ---------------------------------
J="$(mktemp -d)"; mkdir -p "$J/.forge"
seed_plan "$J/.forge/plan.md" sealed 60
printf 'run\n' > "$J/.forge/run.md"
seed_status "$J/.forge/STATUS.md" sealed done "yes (t)" "skipped (x)"
assert_parity "sealed active slot: silent" "$J" ""

echo ""
if [ "$fails" -eq 0 ]; then echo "PARITY OK (all cases identical)"; exit 0
else echo "PARITY FAILED ($fails case(s))"; exit 1; fi
