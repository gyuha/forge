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
assert_nogrep() { if printf '%s' "$2" | grep -qF "$3"; then fail=$((fail+1)); printf '  FAIL %s (%s unexpectedly in output)\n' "$1" "$3"; else pass=$((pass+1)); fi; }

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

# --- B17: canonical-body validation (ADR 260824-134246, hardened after adversarial review) --
# The check compares the CANONICAL BODY, not the marker, so these fixtures read the single
# definition instead of hardcoding a 23rd copy. severity is warning (rc 1), per the rubric in
# skills/fg-doctor/SKILL.md — a missing style paragraph is drift, not release breakage.
RULE="$(cat "$(cd "$(dirname "$SCRIPT")" && pwd)/explaining-forge.rule.txt")"
seed_forge_manifest() { mkdir -p "$1/.forge" "$1/.claude-plugin" "$1/skills/foo"; printf '{"name":"forge"}\n' > "$1/.claude-plugin/plugin.json"; }
seed_skill() { printf 'name: foo\ndescription: short core\n---\n**Language**: write in the user language.\n\n' > "$1/skills/foo/SKILL.md"; printf '%s\n' "$2" >> "$1/skills/foo/SKILL.md"; }
# no rule at all -> warning
t=$(mktmp); seed_forge_manifest "$t"; seed_skill "$t" "(nothing here)"
run_doc "$t"; assert "B17-missing-rc1" 1 "$RC"; assert_grep "B17-missing-msg" "$OUT" "B17 missing Explaining forge rule"; rm -rf "$t"
# canonical body present -> clean (the old fixture passed an abbreviated sentence; that is the
# gap Codex flagged, so this one uses the real canonical text)
t=$(mktmp); seed_forge_manifest "$t"; seed_skill "$t" "$RULE"
run_doc "$t"; assert "B17-canonical-rc0" 0 "$RC"; assert_nogrep "B17-canonical-msg" "$OUT" "B17 missing"; rm -rf "$t"
# SUPERSET (canonical + an appended sentence, exactly what skills/fg-ask/SKILL.md carries)
# -> clean. This is why containment needs no exception list.
t=$(mktmp); seed_forge_manifest "$t"; seed_skill "$t" "$RULE **One extra normative sentence.**"
run_doc "$t"; assert "B17-superset-rc0" 0 "$RC"; assert_nogrep "B17-superset-msg" "$OUT" "B17 missing"; rm -rf "$t"
# heading-only: marker kept, body gone -> warning (marker-substring check missed this)
t=$(mktmp); seed_forge_manifest "$t"; seed_skill "$t" "**Explaining forge**: (body deleted)"
run_doc "$t"; assert "B17-heading-only-rc1" 1 "$RC"; assert_grep "B17-heading-only-msg" "$OUT" "B17 missing Explaining forge rule"; rm -rf "$t"
# truncated: canonical minus its tail -> warning
t=$(mktmp); seed_forge_manifest "$t"; seed_skill "$t" "$(printf '%s' "$RULE" | cut -c1-200)"
run_doc "$t"; assert "B17-truncated-rc1" 1 "$RC"; assert_grep "B17-truncated-msg" "$OUT" "B17 missing Explaining forge rule"; rm -rf "$t"
# altered: one clause negated -> warning (a rule that says the opposite must not pass)
t=$(mktmp); seed_forge_manifest "$t"; seed_skill "$t" "$(printf '%s' "$RULE" | sed 's/A gloss is not filler/A gloss IS filler/')"
run_doc "$t"; assert "B17-altered-rc1" 1 "$RC"; assert_grep "B17-altered-msg" "$OUT" "B17 missing Explaining forge rule"; rm -rf "$t"
# mention-only: a file that DOCUMENTS the check (as skills/fg-doctor/SKILL.md must) still fails
# unless it carries the rule -> warning. Under the old marker test this passed, which would
# have blinded B17 to its own documentation.
t=$(mktmp); seed_forge_manifest "$t"; seed_skill "$t" "- **B17 missing Explaining forge rule** — a SKILL.md without the **Explaining forge** paragraph is a warning."
run_doc "$t"; assert "B17-mention-only-rc1" 1 "$RC"; assert_grep "B17-mention-only-msg" "$OUT" "B17 missing Explaining forge rule"; rm -rf "$t"
# scope guard: not the forge plugin repo -> never flagged (fg-doctor is an AI-free CI gate, so
# a false finding in a user project would break it)
t=$(mktmp); mkdir -p "$t/.forge" "$t/.claude-plugin" "$t/skills/theirs"
printf '{"name":"someone-elses-plugin"}\n' > "$t/.claude-plugin/plugin.json"
printf 'name: theirs\ndescription: short core\n---\n**Language**: x\n' > "$t/skills/theirs/SKILL.md"
run_doc "$t"; assert "B17-scope-rc0" 0 "$RC"; assert_nogrep "B17-scope-msg" "$OUT" "B17 missing"; rm -rf "$t"
# scope guard: nested "name": "forge" (e.g. author.name) must NOT trigger -- jname takes the
# top-level name only. Reproduced as a real false positive before this fix.
t=$(mktmp); mkdir -p "$t/.forge" "$t/.claude-plugin" "$t/skills/theirs"
printf '{"name":"my-plugin","author":{"name":"forge"}}\n' > "$t/.claude-plugin/plugin.json"
printf 'name: theirs\ndescription: short core\n---\n**Language**: x\n' > "$t/skills/theirs/SKILL.md"
run_doc "$t"; assert "B17-nested-name-rc0" 0 "$RC"; assert_nogrep "B17-nested-name-msg" "$OUT" "B17 missing"; rm -rf "$t"

printf '\nforge-doctor: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
