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
# NEW-format done dir (YYMMDD-HHMMSS): Date must come from STATUS completed:, not the dirname prefix
mkdir -p "$B/.forge/done/260615-143022-new-task"
cat > "$B/.forge/done/260615-143022-new-task/plan.md" <<'EOF'
<!-- forge-slug: new-task --> <!-- task: 5 -->
# New task
EOF
cat > "$B/.forge/done/260615-143022-new-task/STATUS.md" <<'EOF'
# STATUS — New task
slug: new-task
status: done
executed: 2026-06-15
completed: 2026-06-15
verified: yes (t)
retro: skipped (x)
EOF
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

# --- Fixture H: Stage is gated on `verified:`, not on run.md's existence -----
# Regression: the table printed `learn` for an active run whose UAT was still
# owed (`verified: pending`), while the next-step machine sent the user to
# fg-run on the same screen — the table contradicted the handoff.
H="$(mktemp -d)"; mkdir -p "$H/.forge"
printf '<!-- forge-slug: uat-owed --> <!-- task: 33 -->\n# T\n' > "$H/.forge/plan.md"
: > "$H/.forge/run.md"
printf 'slug: uat-owed\nstatus: executed\nexecuted: 2026-09-06\nverified: pending\nretro: pending\n' > "$H/.forge/STATUS.md"
assert_parity "verified pending: stage gated sh==js" "$H" "--table" "uat-owed"
stage_h="$(cd "$H" && bash "$SH" --table 2>/dev/null | awk 'NR>1{print $4}')"
if [ "$stage_h" = "run" ]; then
  echo "ok   - active run.md + verified pending → stage run (not learn)"
else
  echo "FAIL - verified pending stage: got [$stage_h] expected [run]"; fails=$((fails+1))
fi
printf 'slug: uat-owed\nstatus: executed\nexecuted: 2026-09-06\nverified: failed (goal missed)\nretro: pending\n' > "$H/.forge/STATUS.md"
assert_parity "verified failed: stage gated sh==js" "$H" "--table" "uat-owed"
stage_hf="$(cd "$H" && bash "$SH" --table 2>/dev/null | awk 'NR>1{print $4}')"
if [ "$stage_hf" = "run" ]; then
  echo "ok   - active run.md + verified failed → stage run"
else
  echo "FAIL - verified failed stage: got [$stage_hf] expected [run]"; fails=$((fails+1))
fi

# --- Fixture I: parked tasks — only `failed` returns to fg-run ---------------
# The discriminator is who owns the next step: fg-run unparks a `failed` task,
# while a parked `pending` routes to fg-learn (its gate confirms the UAT), so it
# stays `learn` (fg-status SKILL.md, next-step machine step 3).
I="$(mktemp -d)"; mkdir -p "$I/.forge/executed/failed-task" "$I/.forge/executed/pending-task"
printf '<!-- forge-slug: failed-task --> <!-- task: 1 -->\n# F\n' > "$I/.forge/executed/failed-task/plan.md"
printf 'slug: failed-task\nstatus: executed\nexecuted: 2026-09-06\nverified: failed (broken)\nretro: pending\n' > "$I/.forge/executed/failed-task/STATUS.md"
printf '<!-- forge-slug: pending-task --> <!-- task: 2 -->\n# P\n' > "$I/.forge/executed/pending-task/plan.md"
printf 'slug: pending-task\nstatus: executed\nexecuted: 2026-09-06\nverified: pending\nretro: pending\n' > "$I/.forge/executed/pending-task/STATUS.md"
assert_parity "parked stages: sh==js" "$I" "--table" "failed-task"
stages_i="$(cd "$I" && bash "$SH" --table 2>/dev/null | awk 'NR>1{print $4}' | tr '\n' ',')"
if [ "$stages_i" = "run,learn," ]; then
  echo "ok   - parked failed → run · parked pending → learn"
else
  echo "FAIL - parked stages: got [$stages_i] expected [run,learn,]"; fails=$((fails+1))
fi

# --- Fixture J: retro lookup is EXACT, not a `*-<slug>.md` suffix glob --------
# Regression: slug `promotion` showed Retro=O on another task's
# `…-eval-promotion.md` (and forge-done sealed on it).
J="$(mktemp -d)"; mkdir -p "$J/.forge/retro"
: > "$J/.forge/retro/260906-171420-eval-promotion.md"
printf '<!-- forge-slug: promotion --> <!-- task: 1 -->\n# T\n' > "$J/.forge/plan.md"
: > "$J/.forge/run.md"
printf 'slug: promotion\nstatus: executed\nexecuted: 2026-09-06\nverified: yes (t)\nretro: pending\n' > "$J/.forge/STATUS.md"
assert_parity "retro exact match: sh==js" "$J" "--table" "promotion"
r_j="$(cd "$J" && bash "$SH" --table 2>/dev/null | awk 'NR==2{print $6}')"
if [ "$r_j" = "-" ]; then
  echo "ok   - another task's retro does NOT count as this task's (Retro —)"
else
  echo "FAIL - retro suffix collision: got [$r_j] expected [-]"; fails=$((fails+1))
fi
: > "$J/.forge/retro/260906-180000-promotion.md"
r_j2="$(cd "$J" && bash "$SH" --table 2>/dev/null | awk 'NR==2{print $6}')"
if [ "$r_j2" = "O" ]; then
  echo "ok   - the task's own retro does count (Retro O)"
else
  echo "FAIL - own retro not detected: got [$r_j2] expected [O]"; fails=$((fails+1))
fi

# --- Fixture K: STATUS values decide case/space-insensitively -----------------
# `Yes`, `N/A`, `yes(ok)` must read as sealable, and `retro: Skipped` must render
# X — it used to render O (retro done) while forge-done refused to seal on it.
K="$(mktemp -d)"; mkdir -p "$K/.forge"
printf '<!-- forge-slug: t --> <!-- task: 1 -->\n# T\n' > "$K/.forge/plan.md"
: > "$K/.forge/run.md"
for pair in "Yes (ok)|pending|learn|O|-" "N/A (docs)|pending|learn|~|-" "yes(ok)|pending|learn|O|-" "yes (ok)|Skipped (why)|learn|O|X"; do
  IFS='|' read -r vv rr xs xv xr <<EOF
$pair
EOF
  printf 'slug: t\nstatus: executed\nexecuted: 2026-09-06\nverified: %s\nretro: %s\n' "$vv" "$rr" > "$K/.forge/STATUS.md"
  assert_parity "STATUS token [$vv / $rr]: sh==js" "$K" "--table" "t"
  got="$(cd "$K" && bash "$SH" --table 2>/dev/null | awk 'NR==2{print $4" "$5" "$6}')"
  if [ "$got" = "$xs $xv $xr" ]; then
    echo "ok   - [$vv / $rr] → $got"
  else
    echo "FAIL - [$vv / $rr]: got [$got] expected [$xs $xv $xr]"; fails=$((fails+1))
  fi
done

# --- Fixture L: done/ dir name split by FORM, not fixed offsets ---------------
# `${name:0:10}` / `${name:11}` assumed the legacy YYYY-MM-DD width, so
# `260615-143022-new-task` rendered Date `260615-143` / Task `22-new-task`.
L="$(mktemp -d)"
for d in 260615-143022-new-task 260615-143022a-serial-task 2026-06-10-legacy-task; do
  mkdir -p "$L/.forge/done/$d"
  printf '# no markers\n' > "$L/.forge/done/$d/plan.md"
  printf 'status: done\n' > "$L/.forge/done/$d/STATUS.md"
done
assert_parity "done dir name split: sh==js" "$L" "--table" "new-task"
got_l="$(cd "$L" && bash "$SH" --table 2>/dev/null | awk 'NR>1{print $2"/"$3}' | LC_ALL=C sort | tr '\n' ' ')"
exp_l="2026-06-10/legacy-task 260615-143022/new-task 260615-143022a/serial-task "
if [ "$got_l" = "$exp_l" ]; then
  echo "ok   - done dir Date/Task split across all three id forms"
else
  echo "FAIL - done dir split: got [$got_l] expected [$exp_l]"; fails=$((fails+1))
fi

echo ""
if [ "$fails" -eq 0 ]; then echo "PARITY OK (all cases identical)"; exit 0
else echo "PARITY FAILED ($fails case(s))"; exit 1; fi
