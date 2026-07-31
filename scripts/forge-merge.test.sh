#!/usr/bin/env bash
# Fixture-based tests for forge-merge.sh — deterministic branch-forge integration
# (task forge-merge-script-extract). Covers the exit-code contract + every
# mechanical integration op + the gates (in-flight, CONTEXT redefinition, NNNN
# collision) which must NON-DESTRUCTIVELY refuse.
#
# Exit codes:  0 integrated · 2 nothing · 3 in-flight · 4 conflict (context
#              redefinition / NNNN collision) · 6 ambiguous
#
# Run:  bash scripts/forge-merge.test.sh   (or FGMERGE_IMPL=.../forge-merge.js)

set -u
SCRIPT="${FGMERGE_IMPL:-$(cd "$(dirname "$0")" && pwd)/forge-merge.sh}"
pass=0; fail=0
mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgmerge.XXXXXX"; }
assert()        { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s\n    exp:[%s]\n    act:[%s]\n' "$1" "$2" "$3"; fi; }
assert_file()   { if [ -e "$2" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s (missing: %s)\n' "$1" "$2"; fi; }
assert_nofile() { if [ ! -e "$2" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s (should NOT exist: %s)\n' "$1" "$2"; fi; }
assert_grep()   { if grep -qF "$3" "$2" 2>/dev/null; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s (%s not in %s)\n' "$1" "$3" "$2"; fi; }

run_merge() { local wd="$1"; shift
  case "$SCRIPT" in
    *.js) OUT="$( cd "$wd" && node "$SCRIPT" "$@" 2>&1 )"; RC=$? ;;
    *)    OUT="$( cd "$wd" && bash "$SCRIPT" "$@" 2>&1 )"; RC=$? ;;
  esac
}
seed_adr() { mkdir -p "$1/.forge/branch/$2/adr"; printf '# t\n' > "$1/.forge/branch/$2/adr/$3"; }

# --- (a) nothing to integrate -> exit 2 --------------------------------------
t=$(mktmp); mkdir -p "$t/.forge"; run_merge "$t"; assert "a-empty-rc2" 2 "$RC"; rm -rf "$t"
# --- (b) named branch absent -> exit 2 ---------------------------------------
t=$(mktmp); seed_adr "$t" feat-x 260716-14a-foo.md; run_merge "$t" nope; assert "b-missing-rc2" 2 "$RC"; rm -rf "$t"
# --- (c) in-flight active slot -> exit 3, nothing moved ----------------------
t=$(mktmp); seed_adr "$t" feat-x 260716-14a-foo.md; printf '<!-- forge-slug: x -->\n' > "$t/.forge/branch/feat-x/plan.md"
run_merge "$t" feat-x; assert "c-inflight-plan-rc3" 3 "$RC"
assert_file "c-adr-untouched" "$t/.forge/branch/feat-x/adr/260716-14a-foo.md"; assert_nofile "c-target-none" "$t/.forge/adr/260716-14a-foo.md"; rm -rf "$t"
# --- (d) in-flight loop.md -> exit 3 -----------------------------------------
t=$(mktmp); seed_adr "$t" feat-x 260716-14a-foo.md; printf 'g\n' > "$t/.forge/branch/feat-x/loop.md"
run_merge "$t" feat-x; assert "d-inflight-loop-rc3" 3 "$RC"; rm -rf "$t"
# --- (e) clean move + branch folder removed -> exit 0 ------------------------
t=$(mktmp); seed_adr "$t" feat-x 260716-14a-foo.md
run_merge "$t" feat-x; assert "e-clean-rc0" 0 "$RC"
assert_file "e-adr-moved" "$t/.forge/adr/260716-14a-foo.md"; assert_nofile "e-branch-gone" "$t/.forge/branch/feat-x"; rm -rf "$t"
# --- (f) time-ID collision -> bump to 14b + cross-ref rewrite in moved docs ---
t=$(mktmp); seed_adr "$t" feat-x 260716-14a-foo.md
mkdir -p "$t/.forge/adr"; printf '# existing\n' > "$t/.forge/adr/260716-14a-existing.md"
mkdir -p "$t/.forge/branch/feat-x/retro"; printf 'see ADR-260716-14a for why\n' > "$t/.forge/branch/feat-x/retro/2026-07-16-foo.md"
run_merge "$t" feat-x; assert "f-collision-rc0" 0 "$RC"
assert_file "f-existing-kept" "$t/.forge/adr/260716-14a-existing.md"
assert_file "f-incoming-bumped" "$t/.forge/adr/260716-14b-foo.md"
assert_nofile "f-no-overwrite" "$t/.forge/adr/260716-14a-foo.md"
assert_grep "f-crossref-rewritten" "$t/.forge/retro/2026-07-16-foo.md" "ADR-260716-14b"; rm -rf "$t"
# --- (e2) NEW-format ADR (YYMMDD-HHMMSS, bare) moves as-is -> exit 0 ----------
t=$(mktmp); seed_adr "$t" feat-x 260719-161701-foo.md
run_merge "$t" feat-x; assert "e2-new-rc0" 0 "$RC"
assert_file "e2-new-moved" "$t/.forge/adr/260719-161701-foo.md"; rm -rf "$t"
# --- (f2) NEW-format collision -> bump to 161701a + cross-ref rewrite ---------
t=$(mktmp); seed_adr "$t" feat-x 260719-161701-foo.md
mkdir -p "$t/.forge/adr"; printf '# existing\n' > "$t/.forge/adr/260719-161701-existing.md"
mkdir -p "$t/.forge/branch/feat-x/retro"; printf 'see ADR-260719-161701 for why\n' > "$t/.forge/branch/feat-x/retro/260719-161701-foo.md"
run_merge "$t" feat-x; assert "f2-collision-rc0" 0 "$RC"
assert_file "f2-existing-kept" "$t/.forge/adr/260719-161701-existing.md"
assert_file "f2-incoming-bumped" "$t/.forge/adr/260719-161701a-foo.md"
assert_nofile "f2-no-overwrite" "$t/.forge/adr/260719-161701-foo.md"
assert_grep "f2-crossref-rewritten" "$t/.forge/retro/260719-161701-foo.md" "ADR-260719-161701a"; rm -rf "$t"
# --- (f3) time-ID collides with a RETIRED target id -> bump (retired ids never reused) ---
t=$(mktmp); seed_adr "$t" feat-x 260719-161701-foo.md
mkdir -p "$t/.forge/adr/retired"; printf '# retired\n' > "$t/.forge/adr/retired/260719-161701-old.md"
run_merge "$t" feat-x; assert "f3-retired-collision-rc0" 0 "$RC"
assert_file "f3-retired-kept" "$t/.forge/adr/retired/260719-161701-old.md"
assert_file "f3-incoming-bumped" "$t/.forge/adr/260719-161701a-foo.md"
assert_nofile "f3-no-reuse" "$t/.forge/adr/260719-161701-foo.md"; rm -rf "$t"
# --- (f4) bump letter also skips a letter already used in retired/ ------------
t=$(mktmp); seed_adr "$t" feat-x 260719-161701-foo.md
mkdir -p "$t/.forge/adr"; printf '# e\n' > "$t/.forge/adr/260719-161701-existing.md"          # active bare-id collision -> must bump
mkdir -p "$t/.forge/adr/retired"; printf '# ra\n' > "$t/.forge/adr/retired/260719-161701a-old.md"  # letter 'a' taken by retired
run_merge "$t" feat-x; assert "f4-rc0" 0 "$RC"
assert_file "f4-bumped-to-b" "$t/.forge/adr/260719-161701b-foo.md"
assert_nofile "f4-not-a" "$t/.forge/adr/260719-161701a-foo.md"; rm -rf "$t"
# --- (g) ambiguous -> exit 6 -------------------------------------------------
t=$(mktmp); seed_adr "$t" feat-x 260716-14a-foo.md; seed_adr "$t" feat-y 260716-15a-bar.md
run_merge "$t"; assert "g-ambiguous-rc6" 6 "$RC"; rm -rf "$t"
# --- (h) retro move + filename collision -> -2 -------------------------------
t=$(mktmp); mkdir -p "$t/.forge/branch/feat-x/retro" "$t/.forge/retro"
printf 'branch\n' > "$t/.forge/branch/feat-x/retro/2026-07-16-dup.md"; printf 'existing\n' > "$t/.forge/retro/2026-07-16-dup.md"
run_merge "$t" feat-x; assert "h-retro-rc0" 0 "$RC"
assert_file "h-retro-existing" "$t/.forge/retro/2026-07-16-dup.md"; assert_file "h-retro-disambig" "$t/.forge/retro/2026-07-16-dup-2.md"; rm -rf "$t"
# --- (i) CONTEXT new term appended, identical term is a no-op ----------------
# Canonical format (CONTEXT-FORMAT.md): terms are `**Name**:` entries; `## X` is
# an optional GROUP subheading, not a term. The old fixtures used `## Alpha` AS a
# term — the same misreading the code had, which is why neither caught the bug.
t=$(mktmp); mkdir -p "$t/.forge/branch/feat-x"; printf '# Glossary\n\n## Language\n\n**Alpha**:\nsame body\n\n**Beta**:\nnew term\n' > "$t/.forge/branch/feat-x/CONTEXT.md"
printf '# Glossary\n\n## Language\n\n**Alpha**:\nsame body\n' > "$t/.forge/CONTEXT.md"
run_merge "$t" feat-x; assert "i-context-rc0" 0 "$RC"
assert_grep "i-beta-appended" "$t/.forge/CONTEXT.md" "**Beta**:"
assert "i-one-language-heading" 1 "$(grep -c '^## Language$' "$t/.forge/CONTEXT.md")"; rm -rf "$t"
# --- (j) CONTEXT term redefinition -> exit 4, nothing moved ------------------
t=$(mktmp); mkdir -p "$t/.forge/branch/feat-x"; seed_adr "$t" feat-x 260716-14a-foo.md
printf '# G\n\n## Language\n\n**Alpha**:\nBRANCH definition\n' > "$t/.forge/branch/feat-x/CONTEXT.md"
printf '# G\n\n## Language\n\n**Alpha**:\nMAIN definition\n' > "$t/.forge/CONTEXT.md"
run_merge "$t" feat-x; assert "j-redef-rc4" 4 "$RC"
assert_file "j-adr-untouched" "$t/.forge/branch/feat-x/adr/260716-14a-foo.md"; assert_nofile "j-target-adr-none" "$t/.forge/adr/260716-14a-foo.md"; rm -rf "$t"
# --- (k) incoming NNNN, no collision -> move as-is, exit 0 -------------------
t=$(mktmp); seed_adr "$t" feat-x 0033-legacy.md
run_merge "$t" feat-x; assert "k-nnnn-rc0" 0 "$RC"; assert_file "k-nnnn-moved" "$t/.forge/adr/0033-legacy.md"; rm -rf "$t"
# --- (l) incoming NNNN collides with frozen target -> exit 4, nothing moved ---
t=$(mktmp); seed_adr "$t" feat-x 0011-dup.md; mkdir -p "$t/.forge/adr"; printf '# frozen\n' > "$t/.forge/adr/0011-frozen.md"
run_merge "$t" feat-x; assert "l-nnnn-collide-rc4" 4 "$RC"
assert_file "l-branch-adr-untouched" "$t/.forge/branch/feat-x/adr/0011-dup.md"; assert_file "l-frozen-kept" "$t/.forge/adr/0011-frozen.md"; rm -rf "$t"
# --- (m) done + backlog folded with ONE monotonic task-number remap ----------
t=$(mktmp)
mkdir -p "$t/.forge/backlog"; printf '<!-- forge-slug: keep -->\n<!-- task: 5 -->\n# keep\n' > "$t/.forge/backlog/keep.md"   # target max = 5
mkdir -p "$t/.forge/branch/feat-x/done/2026-01-01-a" "$t/.forge/branch/feat-x/backlog"
printf '<!-- forge-slug: a -->\n<!-- task: 2 -->\n# a\n' > "$t/.forge/branch/feat-x/done/2026-01-01-a/plan.md"
printf '<!-- forge-slug: b -->\n<!-- task: 3 -->\n# b\n' > "$t/.forge/branch/feat-x/backlog/b.md"
run_merge "$t" feat-x; assert "m-remap-rc0" 0 "$RC"
assert_grep "m-done-a-remapped-6" "$t/.forge/done/2026-01-01-a/plan.md" "task: 6"
assert_grep "m-backlog-b-remapped-7" "$t/.forge/backlog/b.md" "task: 7"
assert_grep "m-target-keep-unchanged" "$t/.forge/backlog/keep.md" "task: 5"; rm -rf "$t"
# --- (n) dropped moved (never blocks) ----------------------------------------
t=$(mktmp); mkdir -p "$t/.forge/branch/feat-x/dropped/gone"; printf 'x\n' > "$t/.forge/branch/feat-x/dropped/gone/plan.md"
run_merge "$t" feat-x; assert "n-dropped-rc0" 0 "$RC"; assert_file "n-dropped-moved" "$t/.forge/dropped/gone/plan.md"; rm -rf "$t"

# --- (i2) REGRESSION: the case that actually broke (feature/result-summary) --
# Both sides carry `## Language` with DISJOINT terms. The old parser read the
# shared heading as a redefined "term" and refused with exit 4; its merge path
# would then have skipped that heading entirely, silently dropping the incoming
# terms. Four terms must survive under ONE `## Language`.
t=$(mktmp); mkdir -p "$t/.forge/branch/feat-x"
printf '# forge\n\n## Language\n\n**eco summary table**:\nreplaces the prose handoff.\n_Avoid_: summary\n\n**seal summary**:\nexplicit single seal only.\n_Avoid_: completion notice\n' > "$t/.forge/branch/feat-x/CONTEXT.md"
printf '# forge\n\n## Language\n\n**Visual Companion**:\ndisplay and answer channel.\n_Avoid_: display-only\n\n**unsealed tail**:\nran but never sealed.\n_Avoid_: debt\n' > "$t/.forge/CONTEXT.md"
run_merge "$t" feat-x
assert "i2-disjoint-rc0" 0 "$RC"
assert "i2-four-terms" 4 "$(grep -c '^\*\*' "$t/.forge/CONTEXT.md")"
assert "i2-one-heading" 1 "$(grep -c '^## Language$' "$t/.forge/CONTEXT.md")"
assert_grep "i2-incoming-1" "$t/.forge/CONTEXT.md" "**eco summary table**:"
assert_grep "i2-incoming-2" "$t/.forge/CONTEXT.md" "**seal summary**:"
assert_grep "i2-target-kept" "$t/.forge/CONTEXT.md" "**Visual Companion**:"
rm -rf "$t"

# --- (i3) unrecognized CONTEXT shape -> exit 4, target untouched -------------
# `## ` headings but zero `**Term**:` entries. Merging would silently do nothing
# (worse than the false conflict it replaces), so stop and let a human look.
t=$(mktmp); mkdir -p "$t/.forge/branch/feat-x"
printf '# G\n\n## Alpha\nlegacy shape\n' > "$t/.forge/branch/feat-x/CONTEXT.md"
printf '# G\n\n## Language\n\n**Beta**:\ncanonical\n' > "$t/.forge/CONTEXT.md"
before="$(cat "$t/.forge/CONTEXT.md")"
run_merge "$t" feat-x
assert "i3-unrecognized-rc4" 4 "$RC"
assert "i3-target-untouched" "$before" "$(cat "$t/.forge/CONTEXT.md")"
assert_file "i3-branch-root-kept" "$t/.forge/branch/feat-x/CONTEXT.md"
rm -rf "$t"

printf '\nforge-merge: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
