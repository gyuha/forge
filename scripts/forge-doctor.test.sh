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
# --- A9 stale drive.md (past the 30-min bound) -> warning --------------------
t=$(mktmp); mkdir -p "$t/.forge"; printf 'started: %s\n' "$(( $(date +%s) - 1860 ))" > "$t/.forge/drive.md"
run_doc "$t"; assert "A9stale-rc1" 1 "$RC"; assert_grep "A9stale-msg" "$OUT" "A9 stale drive.md"; rm -rf "$t"
# --- A9 unparseable drive.md (no valid started:) -> warning ------------------
t=$(mktmp); mkdir -p "$t/.forge"; printf 'started: nonsense\n' > "$t/.forge/drive.md"
run_doc "$t"; assert "A9unparse-rc1" 1 "$RC"; assert_grep "A9unparse-msg" "$OUT" "A9 unparseable drive.md"; rm -rf "$t"
# --- A9 live drive.md (inside the bound) -> silent, must not false-fire ------
t=$(mktmp); mkdir -p "$t/.forge"; printf 'started: %s\n' "$(date +%s)" > "$t/.forge/drive.md"
run_doc "$t"; assert "A9live-rc0" 0 "$RC"; assert_nogrep "A9live-none" "$OUT" "A9 "; rm -rf "$t"
# --- A10 orphan running.md (no plan.md) -> error -----------------------------
t=$(mktmp); mkdir -p "$t/.forge"; printf '<!-- forge-running: s -->\nworkflow: agents\nstarted: %s\nsession: x\n' "$(date +%s)" > "$t/.forge/running.md"
run_doc "$t"; assert "A10orphan-rc2" 2 "$RC"; assert_grep "A10orphan-msg" "$OUT" "A10 orphan running.md"; rm -rf "$t"
# --- A10 leftover running.md (run.md present) -> warning ---------------------
t=$(mktmp); mkdir -p "$t/.forge"; printf '<!-- forge-slug: s -->\n# t\n' > "$t/.forge/plan.md"; printf '# run\n' > "$t/.forge/run.md"
printf '# S\nslug: s\nstatus: executed\nverified: pending\nretro: pending\n' > "$t/.forge/STATUS.md"
printf '<!-- forge-running: s -->\nworkflow: agents\nstarted: %s\nsession: x\n' "$(date +%s)" > "$t/.forge/running.md"
run_doc "$t"; assert "A10leftover-rc1" 1 "$RC"; assert_grep "A10leftover-msg" "$OUT" "A10 leftover running.md"; rm -rf "$t"
# --- A10 unparseable running.md (no valid started:) -> warning ---------------
t=$(mktmp); mkdir -p "$t/.forge"; printf '<!-- forge-slug: s -->\n# t\n' > "$t/.forge/plan.md"
printf '<!-- forge-running: s -->\nworkflow: agents\nstarted: nonsense\nsession: x\n' > "$t/.forge/running.md"
run_doc "$t"; assert "A10unparse-rc1" 1 "$RC"; assert_grep "A10unparse-msg" "$OUT" "A10 unparseable running.md"; rm -rf "$t"
# --- A10 stale running.md (started > 1h ago) -> warning ----------------------
t=$(mktmp); mkdir -p "$t/.forge"; printf '<!-- forge-slug: s -->\n# t\n' > "$t/.forge/plan.md"
printf '<!-- forge-running: s -->\nworkflow: agents\nstarted: %s\nsession: x\n' "$(( $(date +%s) - 3660 ))" > "$t/.forge/running.md"
run_doc "$t"; assert "A10stale-rc1" 1 "$RC"; assert_grep "A10stale-msg" "$OUT" "A10 stale running.md"; rm -rf "$t"
# --- A10 live running.md (fresh, plan.md, no run.md) -> silent ---------------
t=$(mktmp); mkdir -p "$t/.forge"; printf '<!-- forge-slug: s -->\n# t\n' > "$t/.forge/plan.md"
printf '<!-- forge-running: s -->\nworkflow: agents\nstarted: %s\nsession: x\n' "$(date +%s)" > "$t/.forge/running.md"
run_doc "$t"; assert "A10live-rc0" 0 "$RC"; assert_nogrep "A10live-none" "$OUT" "A10 "; rm -rf "$t"
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
# --- B16 folded block scalar -> measured, NOT read as the 2-char indicator -----
# Regression: a `description: >-` value lives on the FOLLOWING indented lines, so a
# line-wise read saw `>-` (2 chars) and every length passed — fail-open, and it blinded
# the five longest descriptions until they were reverted by hand.
t=$(mktmp); mkdir -p "$t/.forge" "$t/skills/foo"; longdesc="$(head -c 700 < /dev/zero | tr '\0' x)"
printf 'name: foo\ndescription: >-\n  %s\n---\nbody\n' "$longdesc" > "$t/skills/foo/SKILL.md"
run_doc "$t"; assert "B16fold-rc1" 1 "$RC"; assert_grep "B16fold-msg" "$OUT" "700 chars > 600"; rm -rf "$t"
# --- B16 folded block scalar under the cap -> clean (no false positive) --------
t=$(mktmp); mkdir -p "$t/.forge" "$t/skills/foo"
printf 'name: foo\ndescription: >-\n  short core spread\n  over two lines\n---\nbody\n' > "$t/skills/foo/SKILL.md"
run_doc "$t"; assert "B16foldshort-rc0" 0 "$RC"; rm -rf "$t"
# --- A1(b) half-executed active slot: plan+run, no STATUS -> warning ----------
# The mirror of A1. A5 demands plan+run+STATUS for executed/<slug>, but the active slot
# had no such arm, so this state passed clean and was caught only by the session hook.
t=$(mktmp); mkdir -p "$t/.forge"; printf '<!-- forge-slug: s -->\n# t\n' > "$t/.forge/plan.md"; printf '# run\n' > "$t/.forge/run.md"
run_doc "$t"; assert "A1b-rc1" 1 "$RC"; assert_grep "A1b-msg" "$OUT" "A1 active-slot incomplete"; rm -rf "$t"
# --- A1(b) complete active slot -> no A1(b) finding ---------------------------
t=$(mktmp); mkdir -p "$t/.forge"; printf '<!-- forge-slug: s -->\n# t\n' > "$t/.forge/plan.md"; printf '# run\n' > "$t/.forge/run.md"
printf 'slug: s\nstatus: executed\nverified: pending\nretro: pending\n' > "$t/.forge/STATUS.md"
run_doc "$t"; assert_nogrep "A1b-none" "$OUT" "A1 active-slot incomplete"; rm -rf "$t"
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

# --- B18: fg-debug contract coherence ---------------------------------------
# This is forge-repo-scoped like B17. The fixture spells the contract as
# independent semantic signals rather than copying one canonical paragraph, so
# harmless prose edits do not make the doctor test its own wording.
seed_b18_base() {
  mkdir -p "$1/.forge" "$1/.claude-plugin" "$1/skills/fg-next" "$1/skills/fg-debug"
  printf '{"name":"forge"}\n' > "$1/.claude-plugin/plugin.json"
  printf '# Handoff\n\n**Applies (2)**\n\n| Group | Skills |\n| --- | --- |\n| Loop | `fg-run` |\n| Utility | `fg-debug` |\n\n**Does NOT apply (1)**\n\n| Skills | Why |\n| --- | --- |\n| `fg-help` | Reporter only |\n' > "$1/skills/fg-next/HANDOFF.md"
  printf '# forge\n\n**핸드오프 표 (handoff table)**:\n적용 지점은 다음 단계가 있는 2곳이다.\n\n**다음 용어**:\n끝.\n' > "$1/.forge/CONTEXT.md"
}
write_b18_debug() { # <dir> <active-failure> <eval> <cleanup> <loop-inconclusive>
  {
    printf '%s\n' '---' 'name: fg-debug' 'description: short core' '---' '**Language**: x' '' "$RULE" ''
    printf '%s\n' '## Route by invocation state before diagnosis size' "$2" '## Phase 1 artifacts' "$3" "$4" '## The boundary' "$5"
  } > "$1/skills/fg-debug/SKILL.md"
}
seed_b18_good() {
  seed_b18_base "$1"
  write_b18_debug "$1" \
    'An active slot at `verified: failed` returns the diagnosis to the existing fg-run fix-and-re-run path.' \
    'Classify whether the Phase 1 command is a persistent regression check; curl, trace, HITL, and throwaway commands are one-off. Follow PLAN-FORMAT.' \
    'Delete raw captures, temporary instrumentation, and throwaway harnesses on every exit path.' \
    'Inconclusive with a feedback loop already built and the root cause unconfirmed asks for more instrumentation.'
}
seed_b18_handoff_bad() { seed_b18_good "$1"; sed 's/Applies (2)/Applies (3)/' "$1/skills/fg-next/HANDOFF.md" > "$1/H"; mv "$1/H" "$1/skills/fg-next/HANDOFF.md"; }
seed_b18_handoff_excluded_bad() { seed_b18_good "$1"; sed 's/Does NOT apply (1)/Does NOT apply (2)/' "$1/skills/fg-next/HANDOFF.md" > "$1/H"; mv "$1/H" "$1/skills/fg-next/HANDOFF.md"; }
seed_b18_context_bad() { seed_b18_good "$1"; sed 's/2곳/3곳/' "$1/.forge/CONTEXT.md" > "$1/C"; mv "$1/C" "$1/.forge/CONTEXT.md"; }
seed_b18_active_bad() { seed_b18_base "$1"; write_b18_debug "$1" 'A failed task receives a diagnostic report.' 'Classify whether the Phase 1 command is a persistent regression check; curl and trace commands are one-off. Follow PLAN-FORMAT.' 'Remove temporary captures and instrumentation on every exit path.' 'A feedback loop can exist while the root cause is unconfirmed.'; }
seed_b18_active_decoupled() { seed_b18_base "$1"; write_b18_debug "$1" 'An active failed task receives a diagnostic report.' 'Classify whether the Phase 1 command is a persistent regression check; curl and trace commands are one-off. Follow PLAN-FORMAT. A glossary elsewhere mentions `verified: failed` and fix-and-re-run.' 'Remove temporary captures and instrumentation on every exit path.' 'A feedback loop can exist while the root cause is unconfirmed.'; }
seed_b18_eval_bad() { seed_b18_base "$1"; write_b18_debug "$1" 'For `verified: failed`, use fg-run fix-and-re-run.' 'The red command satisfies the fix-forward eval rule by construction. See PLAN-FORMAT.' 'Remove temporary captures and instrumentation on every exit path.' 'A feedback loop can exist while the root cause is unconfirmed.'; }
seed_b18_cleanup_bad() { seed_b18_base "$1"; write_b18_debug "$1" 'For `verified: failed`, use fg-run fix-and-re-run.' 'Classify persistent checks separately from one-off curl and trace commands. See PLAN-FORMAT.' 'The later fix may clean temporary files.' 'A feedback loop can exist while the root cause is unconfirmed.'; }
seed_b18_loop_bad() { seed_b18_base "$1"; write_b18_debug "$1" 'For `verified: failed`, use fg-run fix-and-re-run.' 'Classify persistent checks separately from one-off curl and trace commands. See PLAN-FORMAT.' 'Remove temporary captures and instrumentation on every exit path.' 'Inconclusive means no feedback loop could be built.'; }

t=$(mktmp); seed_b18_good "$t"; run_doc "$t"; assert "B18-good-rc0" 0 "$RC"; assert_nogrep "B18-good-msg" "$OUT" "B18 "; rm -rf "$t"
t=$(mktmp); seed_b18_handoff_bad "$t"; run_doc "$t"; assert "B18-handoff-rc1" 1 "$RC"; assert_grep "B18-handoff-msg" "$OUT" "B18 handoff applies count"; rm -rf "$t"
t=$(mktmp); seed_b18_handoff_excluded_bad "$t"; run_doc "$t"; assert "B18-handoff-excluded-rc1" 1 "$RC"; assert_grep "B18-handoff-excluded-msg" "$OUT" "B18 handoff excluded count"; rm -rf "$t"
t=$(mktmp); seed_b18_context_bad "$t"; run_doc "$t"; assert "B18-context-rc1" 1 "$RC"; assert_grep "B18-context-msg" "$OUT" "B18 CONTEXT handoff count"; rm -rf "$t"
t=$(mktmp); seed_b18_active_bad "$t"; run_doc "$t"; assert "B18-active-rc1" 1 "$RC"; assert_grep "B18-active-msg" "$OUT" "B18 fg-debug active-failure route"; rm -rf "$t"
t=$(mktmp); seed_b18_active_decoupled "$t"; run_doc "$t"; assert "B18-active-decoupled-rc1" 1 "$RC"; assert_grep "B18-active-decoupled-msg" "$OUT" "B18 fg-debug active-failure route"; rm -rf "$t"
t=$(mktmp); seed_b18_eval_bad "$t"; run_doc "$t"; assert "B18-eval-rc1" 1 "$RC"; assert_grep "B18-eval-msg" "$OUT" "B18 fg-debug persistent eval"; rm -rf "$t"
t=$(mktmp); seed_b18_cleanup_bad "$t"; run_doc "$t"; assert "B18-cleanup-rc1" 1 "$RC"; assert_grep "B18-cleanup-msg" "$OUT" "B18 fg-debug cleanup"; rm -rf "$t"
t=$(mktmp); seed_b18_loop_bad "$t"; run_doc "$t"; assert "B18-loop-rc1" 1 "$RC"; assert_grep "B18-loop-msg" "$OUT" "B18 fg-debug inconclusive route"; rm -rf "$t"

# --- B19: fg-showme confirm snippet single definition (retro 260805-063357 learning 3 → eval) ---
# One fenced copy, carrying both the confirm: prefix (wake filter) and the dataset.sent guard.
# Scoped to the forge repo (plugin.json name=forge); no SKILL.md is seeded so B17 stays silent.
b19_seed() { mkdir -p "$1/.forge" "$1/.claude-plugin" "$1/skills/fg-showme"; printf '{"name":"forge"}\n' > "$1/.claude-plugin/plugin.json"; printf '# V\n\n### Confirm button\n\n```html\n%s\n```\n' "$2" > "$1/skills/fg-showme/VISUAL.md"; }
B19_GOOD="<button onclick=\"if (this.dataset.sent === key) return; this.dataset.sent = key; window.brainstorm.send({type:'confirm', choice:'confirm:'+key, value:sel});\">ok</button>"
t=$(mktmp); b19_seed "$t" "$B19_GOOD"; run_doc "$t"; assert "B19-good-rc0" 0 "$RC"; assert_nogrep "B19-good-none" "$OUT" "B19 "; rm -rf "$t"
t=$(mktmp); b19_seed "$t" "$B19_GOOD"; printf '\n```html\n%s\n```\n' "$B19_GOOD" >> "$t/skills/fg-showme/VISUAL.md"; run_doc "$t"; assert "B19-dup-rc1" 1 "$RC"; assert_grep "B19-dup-msg" "$OUT" "B19 confirm snippet duplicated"; rm -rf "$t"
t=$(mktmp); b19_seed "$t" "$(printf '%s' "$B19_GOOD" | sed "s/choice:'confirm:'+key/choice:key/")"; run_doc "$t"; assert "B19-noprefix-rc1" 1 "$RC"; assert_grep "B19-noprefix-msg" "$OUT" "B19 confirm snippet incomplete"; rm -rf "$t"
t=$(mktmp); b19_seed "$t" "$(printf '%s' "$B19_GOOD" | sed 's/if (this.dataset.sent === key) return; this.dataset.sent = key; //')"; run_doc "$t"; assert "B19-noguard-rc1" 1 "$RC"; assert_grep "B19-noguard-msg" "$OUT" "B19 confirm snippet incomplete"; rm -rf "$t"
t=$(mktmp); b19_seed "$t" "<button>no confirm</button>"; run_doc "$t"; assert "B19-missing-rc1" 1 "$RC"; assert_grep "B19-missing-msg" "$OUT" "B19 confirm snippet missing"; rm -rf "$t"

# --- B20: capability key <-> **Host contract** paragraph coherence (retro 260908-210216 -> eval) ---
# Vocabulary comes from a copied real core/HOST.md (never restated). Seeds one skill each way.
# The seeded SKILL.md carries the canonical Explaining-forge body so B17 stays silent.
b20_seed() { # $1=dir $2=skill-body-after-rule
  mkdir -p "$1/.forge" "$1/.claude-plugin" "$1/core" "$1/skills/foo"; printf '{"name":"forge"}\n' > "$1/.claude-plugin/plugin.json"
  cp "$(cd "$(dirname "$SCRIPT")" && pwd)/../core/HOST.md" "$1/core/HOST.md"
  { printf 'name: foo\ndescription: short core\n---\n**Language**: x\n\n'; printf '%s\n\n' "$RULE"; printf '%s\n' "$2"; } > "$1/skills/foo/SKILL.md"; }
t=$(mktmp); b20_seed "$t" '**Host contract**: needs `structured_choice`; falls back to a numbered list.'; run_doc "$t"; assert "B20-good-rc0" 0 "$RC"; assert_nogrep "B20-good-none" "$OUT" "B20 "; rm -rf "$t"
t=$(mktmp); b20_seed "$t" 'Uses `spawn_parallel` for fan-out.'; run_doc "$t"; assert "B20-missing-rc1" 1 "$RC"; assert_grep "B20-missing-msg" "$OUT" "B20 host contract missing"; rm -rf "$t"
t=$(mktmp); b20_seed "$t" '**Host contract**: this skill is host-neutral.'; run_doc "$t"; assert "B20-nokey-rc1" 1 "$RC"; assert_grep "B20-nokey-msg" "$OUT" "B20 host contract names no capability"; rm -rf "$t"
t=$(mktmp); b20_seed "$t" '**Host contract**: this skill is host-neutral.

Elsewhere it uses `structured_choice`.'; run_doc "$t"; assert "B20-key-outside-rc1" 1 "$RC"; assert_grep "B20-key-outside-msg" "$OUT" "B20 host contract names no capability"; rm -rf "$t"
t=$(mktmp); b20_seed "$t" '**Host adapter**: needs `structured_choice`.'; run_doc "$t"; assert "B20-label-rc1" 1 "$RC"; assert_grep "B20-label-msg" "$OUT" "B20 host contract label"; rm -rf "$t"

printf '\nforge-doctor: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
