#!/usr/bin/env bash
# Fixture-based tests for forge-doctor.sh — deterministic read-only integrity
# check (task forge-doctor-script-extract). Covers the exit-severity contract
# (0 clean · 1 warnings · 2 errors) and representative checks incl. the new A8
# (orphaned branch root) and T3-aware B14 (time-ID uniqueness, no NNNN false-gap).
#
# Run:  bash scripts/forge-doctor.test.sh   (or FGDOCTOR_IMPL=.../forge-doctor.js)

set -u
SCRIPT="${FGDOCTOR_IMPL:-$(cd "$(dirname "$0")" && pwd)/forge-doctor.sh}"
pass=0; fail=0
mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgdoc.XXXXXX"; }
assert()      { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s exp:[%s] act:[%s]\n' "$1" "$2" "$3"; fi; }
assert_grep() { if printf '%s' "$2" | grep -qF "$3"; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s (%s not in output)\n' "$1" "$3"; fi; }

run_doc() { local wd="$1"; shift
  case "$SCRIPT" in
    *.js) OUT="$( cd "$wd" && node "$SCRIPT" "$@" 2>&1 )"; RC=$? ;;
    *)    OUT="$( cd "$wd" && bash "$SCRIPT" "$@" 2>&1 )"; RC=$? ;;
  esac
}
seed_status() { printf '# S\nslug: %s\nstatus: %s\nverified: %s\nretro: %s\n' "$2" "$3" "$4" "$5" > "$1"; }

# --- clean (.forge only) -> exit 0 -------------------------------------------
t=$(mktmp); mkdir -p "$t/.forge"; run_doc "$t"; assert "clean-rc0" 0 "$RC"; rm -rf "$t"
# --- A1 orphan run.md (no plan) -> error, exit 2 -----------------------------
t=$(mktmp); mkdir -p "$t/.forge"; printf 'x\n' > "$t/.forge/run.md"; run_doc "$t"; assert "A1-rc2" 2 "$RC"; assert_grep "A1-msg" "$OUT" "A1 active-slot orphan"; rm -rf "$t"
# --- A4 half-sealed done/ -> error -------------------------------------------
t=$(mktmp); mkdir -p "$t/.forge/done/2026-07-01-x"; seed_status "$t/.forge/done/2026-07-01-x/STATUS.md" x executed "yes (t)" "skipped (x)"; printf 'p\n' > "$t/.forge/done/2026-07-01-x/plan.md"
run_doc "$t"; assert "A4-rc2" 2 "$RC"; assert_grep "A4-msg" "$OUT" "A4 half-sealed"; rm -rf "$t"
# --- A3 slug mismatch (plan vs STATUS) -> error ------------------------------
t=$(mktmp); mkdir -p "$t/.forge"; printf '<!-- forge-slug: aaa -->\n# T\n' > "$t/.forge/plan.md"; printf 'run\n' > "$t/.forge/run.md"; seed_status "$t/.forge/STATUS.md" bbb executed "yes (t)" pending
run_doc "$t"; assert "A3-rc2" 2 "$RC"; assert_grep "A3-msg" "$OUT" "A3 slug pairing"; rm -rf "$t"
# --- A3 dangling retro path -> error -----------------------------------------
t=$(mktmp); mkdir -p "$t/.forge/done/2026-07-01-y"; seed_status "$t/.forge/done/2026-07-01-y/STATUS.md" y done "yes (t)" ".forge/retro/2026-07-01-y.md"; printf 'p\n' > "$t/.forge/done/2026-07-01-y/plan.md"
run_doc "$t"; assert "A3dangle-rc2" 2 "$RC"; assert_grep "A3dangle-msg" "$OUT" "A3 dangling retro"; rm -rf "$t"
# --- A6 duplicate task number -> error ---------------------------------------
t=$(mktmp); mkdir -p "$t/.forge/backlog"; printf '<!-- forge-slug: a -->\n<!-- task: 4 -->\n' > "$t/.forge/backlog/a.md"; printf '<!-- forge-slug: b -->\n<!-- task: 4 -->\n' > "$t/.forge/backlog/b.md"
run_doc "$t"; assert "A6dup-rc2" 2 "$RC"; assert_grep "A6dup-msg" "$OUT" "A6 duplicate task number"; rm -rf "$t"
# --- A7 stale ask.md -> warning ----------------------------------------------
t=$(mktmp); mkdir -p "$t/.forge"; printf '<!-- forge-ask: x -->\n' > "$t/.forge/ask.md"; touch -t 202001010000 "$t/.forge/ask.md"
run_doc "$t"; assert "A7-rc1" 1 "$RC"; assert_grep "A7-msg" "$OUT" "A7 stale ask.md"; rm -rf "$t"
# --- A8 orphaned branch root -> warning --------------------------------------
t=$(mktmp); mkdir -p "$t/.forge/branch/feat-x/adr"; printf '# t\n' > "$t/.forge/branch/feat-x/adr/260716-14a-foo.md"
run_doc "$t"; assert "A8-rc1" 1 "$RC"; assert_grep "A8-msg" "$OUT" "A8 orphaned branch root"; rm -rf "$t"
# --- B8 manifest version drift -> error --------------------------------------
t=$(mktmp); mkdir -p "$t/.forge" "$t/.claude-plugin"
printf '{"version":"0.5.16"}\n' > "$t/.claude-plugin/plugin.json"
printf '{"metadata":{"version":"0.5.16"},"plugins":[{"version":"0.5.15"}]}\n' > "$t/.claude-plugin/marketplace.json"
run_doc "$t"; assert "B8-rc2" 2 "$RC"; assert_grep "B8-msg" "$OUT" "B8 manifest version drift"; rm -rf "$t"
# --- B10 skill missing name: -> error ----------------------------------------
t=$(mktmp); mkdir -p "$t/.forge" "$t/skills/foo"; printf '# no frontmatter\n' > "$t/skills/foo/SKILL.md"
run_doc "$t"; assert "B10-rc2" 2 "$RC"; assert_grep "B10-msg" "$OUT" "B10 skill missing name:"; rm -rf "$t"
# --- B14 duplicate time-ID -> error ------------------------------------------
t=$(mktmp); mkdir -p "$t/.forge/adr"; printf '# a\n' > "$t/.forge/adr/260716-14a-x.md"; printf '# b\n' > "$t/.forge/adr/260716-14a-y.md"
run_doc "$t"; assert "B14dup-rc2" 2 "$RC"; assert_grep "B14dup-msg" "$OUT" "B14 duplicate time-ID"; rm -rf "$t"
# --- B14 duplicate time-ID, NEW granularity (YYMMDD-HHMMSS) -> error ----------
t=$(mktmp); mkdir -p "$t/.forge/adr"; printf '# a\n' > "$t/.forge/adr/260719-161701-x.md"; printf '# b\n' > "$t/.forge/adr/260719-161701-y.md"
run_doc "$t"; assert "B14dup-hms-rc2" 2 "$RC"; assert_grep "B14dup-hms-msg" "$OUT" "B14 duplicate time-ID"; rm -rf "$t"
# --- B14 old + new granularity coexist, no false dup -> clean -----------------
t=$(mktmp); mkdir -p "$t/.forge/adr"; printf '# a\n' > "$t/.forge/adr/260716-14a-old.md"; printf '# b\n' > "$t/.forge/adr/260719-161701-new.md"; printf '# c\n' > "$t/.forge/adr/260719-161702-new2.md"
run_doc "$t"; assert "B14-mixed-gran-rc0" 0 "$RC"; rm -rf "$t"
# --- B14 time-based ADR is NOT a NNNN gap (T3) -> no false gap, clean ---------
t=$(mktmp); mkdir -p "$t/.forge/adr"; printf '# a\n' > "$t/.forge/adr/0001-a.md"; printf '# t\n' > "$t/.forge/adr/260716-14a-z.md"
run_doc "$t"; assert "B14-no-false-gap-rc0" 0 "$RC"; rm -rf "$t"
# --- B14 NNNN gap -> warning -------------------------------------------------
t=$(mktmp); mkdir -p "$t/.forge/adr"; printf '# a\n' > "$t/.forge/adr/0001-a.md"; printf '# c\n' > "$t/.forge/adr/0003-c.md"
run_doc "$t"; assert "B14gap-rc1" 1 "$RC"; assert_grep "B14gap-msg" "$OUT" "B14 NNNN gap"; rm -rf "$t"
# --- B15 missing .js twin -> warning -----------------------------------------
t=$(mktmp); mkdir -p "$t/.forge" "$t/scripts"; printf '#!/bin/bash\n' > "$t/scripts/lonely.sh"
run_doc "$t"; assert "B15-rc1" 1 "$RC"; assert_grep "B15-msg" "$OUT" "B15 missing .js twin"; rm -rf "$t"
# --- B16 description too long (> 600 chars) -> warning ------------------------
t=$(mktmp); mkdir -p "$t/.forge" "$t/skills/foo"; longdesc="$(head -c 700 < /dev/zero | tr '\0' x)"; printf 'name: foo\ndescription: %s\n' "$longdesc" > "$t/skills/foo/SKILL.md"
run_doc "$t"; assert "B16-rc1" 1 "$RC"; assert_grep "B16-msg" "$OUT" "B16 description length"; rm -rf "$t"
# --- B16 short description -> no B16 finding, clean ---------------------------
t=$(mktmp); mkdir -p "$t/.forge" "$t/skills/bar"; printf 'name: bar\ndescription: short and sweet trigger core\n' > "$t/skills/bar/SKILL.md"
run_doc "$t"; assert "B16short-rc0" 0 "$RC"; rm -rf "$t"
# --- B14 active<->retired time-ID duplicate -> error (retired ids never reused) ---
t=$(mktmp); mkdir -p "$t/.forge/adr/retired"
printf '# a\n' > "$t/.forge/adr/260719-161701-active.md"; printf '# r\n' > "$t/.forge/adr/retired/260719-161701-old.md"
run_doc "$t"; assert "B14-active-retired-dup-rc2" 2 "$RC"; assert_grep "B14-ar-msg" "$OUT" "B14 duplicate time-ID"; assert_grep "B14-ar-id" "$OUT" "260719-161701"; rm -rf "$t"
# --- B14 distinct active + retired time-IDs -> no false dup, clean ------------
t=$(mktmp); mkdir -p "$t/.forge/adr/retired"
printf '# a\n' > "$t/.forge/adr/260719-161701-active.md"; printf '# r\n' > "$t/.forge/adr/retired/260719-161702-old.md"
run_doc "$t"; assert "B14-ar-distinct-rc0" 0 "$RC"; rm -rf "$t"

printf '\nforge-doctor: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
