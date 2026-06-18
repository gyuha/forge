#!/usr/bin/env bash
# Parity test (ADR-0022): forge-status.sh and forge-status.js MUST produce
# identical output for the same .forge fixture, in both full and --table modes.
# This is the real drift guard for the dual sh/js implementation (fg-doctor's
# twin-existence check is only the static half).
#
# `set -euo pipefail` (ADR-0022 review): a failed mktemp / fixture build now
# ABORTS instead of letting "both produced empty output, so they're equal" pass
# as PARITY OK. Populated cases also assert a sentinel substring is present, so a
# script that silently produced nothing is caught as a mismatch, not a pass.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SH="$HERE/forge-status.sh"
JS="$HERE/forge-status.js"
fails=0

norm() { sed -e 's/[[:space:]]*$//'; }

assert_parity() { # $1=desc  $2=workdir  $3=mode("" or "--table")  $4=must-contain (optional)
  local desc="$1" wd="$2" mode="${3:-}" must="${4:-}" out_sh out_js
  out_sh="$(cd "$wd" && bash "$SH" $mode 2>/dev/null | norm)"
  out_js="$(cd "$wd" && node "$JS" $mode 2>/dev/null | norm)"
  if [ "$out_sh" != "$out_js" ]; then
    echo "FAIL - $desc (sh≠js)"
    diff <(printf '%s\n' "$out_sh") <(printf '%s\n' "$out_js") || true
    fails=$((fails+1)); return
  fi
  if [ -n "$must" ] && ! printf '%s' "$out_sh" | grep -q -- "$must"; then
    echo "FAIL - $desc (equal but missing sentinel '$must' — script likely didn't run)"
    fails=$((fails+1)); return
  fi
  echo "ok   - $desc"
}

# --- Fixture A: empty (no .forge) ------------------------------------------
A="$(mktemp -d)"
assert_parity "empty: no .forge dir" "$A" ""

# --- Fixture B: populated (active learn + backlog + executed + done) --------
B="$(mktemp -d)"
mkdir -p "$B/.forge/backlog" "$B/.forge/executed/parked-task" \
         "$B/.forge/done/2026-06-10-old-task" "$B/.forge/retro" "$B/.forge/adr" "$B/.forge/quick"
cat > "$B/.forge/plan.md" <<'EOF'
<!-- forge-slug: active-thing --> <!-- task: 7 -->
# Active thing
EOF
: > "$B/.forge/run.md"
cat > "$B/.forge/STATUS.md" <<'EOF'
# STATUS — Active thing
slug: active-thing
status: executed
executed: 2026-06-12
verified: yes (slice tests green)
retro: pending
EOF
cat > "$B/.forge/backlog/future-thing.md" <<'EOF'
<!-- forge-slug: future-thing --> <!-- task: 9 -->
# Future thing
EOF
cat > "$B/.forge/executed/parked-task/plan.md" <<'EOF'
<!-- forge-slug: parked-task --> <!-- task: 8 -->
# Parked task
EOF
: > "$B/.forge/executed/parked-task/run.md"
cat > "$B/.forge/executed/parked-task/STATUS.md" <<'EOF'
# STATUS — Parked task
slug: parked-task
status: executed
executed: 2026-06-11
verified: n/a (docs only)
retro: pending
EOF
cat > "$B/.forge/done/2026-06-10-old-task/plan.md" <<'EOF'
<!-- forge-slug: old-task --> <!-- task: 3 -->
# Old task
EOF
cat > "$B/.forge/done/2026-06-10-old-task/STATUS.md" <<'EOF'
# STATUS — Old task
- slug: old-task
- status: done
- verified: yes (manual)
- retro: .forge/retro/2026-06-10-old-task.md
EOF
: > "$B/.forge/retro/2026-06-10-old-task.md"
printf '## entry one\n## entry two\n' > "$B/.forge/quick/LOG.md"

assert_parity "populated: full mode"   "$B" ""        "active-thing"
assert_parity "populated: table mode"  "$B" "--table" "active-thing"

# --- Fixture C: config.json defaultBranch present ---------------------------
C="$(mktemp -d)"
mkdir -p "$C/.forge"
printf '{ "defaultBranch": "trunk" }\n' > "$C/.forge/config.json"
assert_parity "config.json present, no tasks" "$C" ""

# --- Fixture D: EMPTY quick LOG (F3 regression — footer must not split) -----
# grep -c on a match-less file prints "0" and exits 1; the old `|| echo 0`
# appended a second "0" → footer broke into two lines and diverged from node.
D="$(mktemp -d)"
mkdir -p "$D/.forge/backlog" "$D/.forge/quick"
cat > "$D/.forge/backlog/q.md" <<'EOF'
<!-- forge-slug: queued --> <!-- task: 1 -->
# Queued
EOF
: > "$D/.forge/quick/LOG.md"   # exists but empty → 0 matches
assert_parity "empty quick LOG: footer single-line" "$D" "" "quick: 0"

# --- Fixture E: CRLF state files (Windows) — sh must strip CR like node ------
# A CRLF-checked-out STATUS.md made the .sh capture "yes\r"/"pending\r" → wrong
# Verify/Retro glyphs, diverging from the node twin (the Windows fallback!).
E="$(mktemp -d)"; mkdir -p "$E/.forge"
printf '<!-- forge-slug: crlf-task --> <!-- task: 4 -->\r\n# T\r\n' > "$E/.forge/plan.md"
: > "$E/.forge/run.md"
printf 'slug: crlf-task\r\nstatus: executed\r\nexecuted: 2026-06-12\r\nverified: yes\r\nretro: pending\r\n' > "$E/.forge/STATUS.md"
assert_parity "CRLF state files: sh strips CR like node" "$E" "--table" "crlf-task"

# --- Fixture F: multibyte (Hangul) slug — byte-based padding must match ------
# awk(LC_ALL=C) pads by bytes; the node twin must pad by UTF-8 bytes too, else
# the Task column misaligns for Korean slugs (forge is a Korean-first tool).
F="$(mktemp -d)"; mkdir -p "$F/.forge/backlog"
printf '<!-- forge-slug: 한글-task --> <!-- task: 5 -->\n# T\n' > "$F/.forge/backlog/k.md"
assert_parity "Hangul slug: byte-aligned table sh==js" "$F" "--table" "한글-task"

# --- Fixture G: backlog order = fg-run contract priority→part→slug (not glob) ---
# Glob order would be aaa-low, mmm-10of10, mmm-2of10, zzz-high; the contract order
# is zzz-high (high) → mmm-2of10 → mmm-10of10 (part 2 before 10) → aaa-low (low).
G="$(mktemp -d)"; mkdir -p "$G/.forge/backlog"
printf '<!-- forge-slug: zzz-high --> <!-- task: 1 --> <!-- priority: high -->\n# H\n'   > "$G/.forge/backlog/zzz-high.md"
printf '<!-- forge-slug: aaa-low --> <!-- task: 2 --> <!-- priority: low -->\n# L\n'     > "$G/.forge/backlog/aaa-low.md"
printf '<!-- forge-slug: mmm-2of10 --> <!-- task: 3 --> <!-- part: 2/10 -->\n# P2\n'     > "$G/.forge/backlog/mmm-2of10.md"
printf '<!-- forge-slug: mmm-10of10 --> <!-- task: 4 --> <!-- part: 10/10 -->\n# P10\n'  > "$G/.forge/backlog/mmm-10of10.md"
assert_parity "backlog priority/part order: sh==js" "$G" "--table" "zzz-high"
order_sh="$(cd "$G" && bash "$SH" --table 2>/dev/null | awk 'NR>1{print $3}' | tr '\n' ',')"
exp_order="zzz-high,mmm-2of10,mmm-10of10,aaa-low,"
if [ "$order_sh" = "$exp_order" ]; then
  echo "ok   - backlog semantic order (high→part2→part10→low)"
else
  echo "FAIL - backlog order: got [$order_sh] expected [$exp_order]"; fails=$((fails+1))
fi

echo ""
if [ "$fails" -eq 0 ]; then echo "PARITY OK (all cases identical)"; exit 0
else echo "PARITY FAILED ($fails case(s))"; exit 1; fi
