#!/usr/bin/env bash
# Parity test (ADR-0022): forge-done.sh and forge-done.js must, for the same
# input state + args, produce the SAME result — identical exit code AND identical
# resulting .forge/ tree (STATUS close-out content + archive layout + what was
# moved/removed). Since this primitive MUTATES files, parity is checked on the
# file system outcome, not just stdout.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SH="$HERE/forge-done.sh"; JS="$HERE/forge-done.js"
fails=0

mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgdonep.XXXXXX"; }

# seed_active <dir> <slug> <verified> <retro>
seed_active() {
  mkdir -p "$1/.forge"
  printf '<!-- forge-slug: %s -->\n# T %s\n' "$2" "$2" > "$1/.forge/plan.md"
  printf 'run notes\n' > "$1/.forge/run.md"
  printf '# STATUS — %s\nslug: %s\nstatus: executed\nexecuted: 2026-07-01\nverified: %s\nretro: %s\n' \
    "$2" "$2" "$3" "$4" > "$1/.forge/STATUS.md"
}

# check <desc> <seed-fn> <args...>   (seed-fn takes the target dir)
check() {
  local desc="$1" seedfn="$2"; shift 2
  local A B rc_sh rc_js
  A=$(mktmp); B=$(mktmp)
  "$seedfn" "$A"; "$seedfn" "$B"
  ( cd "$A" && bash "$SH" "$@" ) >/dev/null 2>&1; rc_sh=$?
  ( cd "$B" && node "$JS" "$@" ) >/dev/null 2>&1; rc_js=$?
  if [ "$rc_sh" != "$rc_js" ]; then
    echo "FAIL - $desc  rc sh=$rc_sh js=$rc_js"; fails=$((fails+1)); rm -rf "$A" "$B"; return
  fi
  if diff -r "$A/.forge" "$B/.forge" >/dev/null 2>&1; then
    echo "ok   - $desc  (rc=$rc_sh)"
  else
    echo "FAIL - $desc  trees differ:"; diff -r "$A/.forge" "$B/.forge" 2>&1 | head -20; fails=$((fails+1))
  fi
  rm -rf "$A" "$B"
}

seed_normal() { seed_active "$1" "p-norm" "yes (t)" "pending"; mkdir -p "$1/.forge/retro"; printf 'r\n' > "$1/.forge/retro/2026-07-01-p-norm.md"; }
seed_skip()   { seed_active "$1" "p-skip" "yes (t)" "pending"; }
seed_vfail()  { seed_active "$1" "p-vf" "failed (x)" "pending"; }
seed_vpend()  { seed_active "$1" "p-vp" "pending" "pending"; }
seed_retro_owed() { seed_active "$1" "p-ro" "yes (t)" "pending"; }
seed_review() { seed_active "$1" "p-rv" "yes (t)" "pending"; printf 'findings\n' > "$1/.forge/review.md"; }
seed_executed() {
  mkdir -p "$1/.forge/executed/p-ex"
  printf '<!-- forge-slug: p-ex -->\n# T\n' > "$1/.forge/executed/p-ex/plan.md"
  printf 'run\n' > "$1/.forge/executed/p-ex/run.md"
  printf '# STATUS — EX\nslug: p-ex\nstatus: executed\nexecuted: 2026-07-03\nverified: yes (t)\nretro: skipped (b)\n' > "$1/.forge/executed/p-ex/STATUS.md"
}
seed_halfsealed() {
  mkdir -p "$1/.forge/done/2026-07-02-p-hs"
  printf '# STATUS — HS\nslug: p-hs\nstatus: executed\nexecuted: 2026-07-02\nverified: yes (t)\nretro: skipped (y)\n' > "$1/.forge/done/2026-07-02-p-hs/STATUS.md"
  printf 'p\n' > "$1/.forge/done/2026-07-02-p-hs/plan.md"
}
seed_dup() {
  seed_active "$1" "p-dup" "yes (t)" "pending"; mkdir -p "$1/.forge/retro"; printf 'r\n' > "$1/.forge/retro/2026-07-01-p-dup.md"
  mkdir -p "$1/.forge/done/2026-07-01-p-dup"; printf 'slug: p-dup\nstatus: done\n' > "$1/.forge/done/2026-07-01-p-dup/STATUS.md"
}
seed_empty() { mkdir -p "$1/.forge"; }

check "normal seal (retro file)"       seed_normal    --completed 2026-07-05 --sealed-id 260705-120000
check "skip seal (--skip-retro)"       seed_skip      --skip-retro "auto" --completed 2026-07-05 --sealed-id 260705-120000
check "docs-updated arg"               seed_skip      --skip-retro "auto" --docs-updated "ADR-0030" --completed 2026-07-05 --sealed-id 260705-120000
check "verify gate: failed -> refuse"  seed_vfail     --skip-retro "x" --completed 2026-07-05 --sealed-id 260705-120000
check "verify gate: pending -> refuse" seed_vpend     --skip-retro "x" --completed 2026-07-05 --sealed-id 260705-120000
check "retro gate: owed -> refuse"     seed_retro_owed --completed 2026-07-05 --sealed-id 260705-120000
check "review.md moved + reviewed"     seed_review    --skip-retro "x" --completed 2026-07-05 --sealed-id 260705-120000
check "executed parked seal"           seed_executed  --slug p-ex --completed 2026-07-05 --sealed-id 260705-120000
check "half-sealed completion"         seed_halfsealed --slug p-hs --completed 2026-07-05 --sealed-id 260705-120000
check "duplicate already-sealed"       seed_dup       --completed 2026-07-05 --sealed-id 260705-120000
check "empty state"                    seed_empty     --completed 2026-07-05 --sealed-id 260705-120000

echo ""
if [ "$fails" -eq 0 ]; then echo "FORGE-DONE PARITY OK"; exit 0
else echo "FORGE-DONE PARITY FAILED ($fails)"; exit 1; fi
