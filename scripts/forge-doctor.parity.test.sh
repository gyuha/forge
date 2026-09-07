#!/usr/bin/env bash
# Parity test (ADR-0022): forge-doctor.sh and forge-doctor.js must, for the same
# state, produce the SAME output AND exit code. forge-doctor is READ-ONLY (mutates
# nothing), so parity is checked by running BOTH in the SAME fixture dir and
# diffing stdout + comparing exit codes (not a file-tree diff like forge-done/merge).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SH="$HERE/forge-doctor.sh"; JS="$HERE/forge-doctor.js"
fails=0
mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgdocp.XXXXXX"; }

# normalize cosmetic path-format only (bash string vs node path.join): collapse
# `./` and repeated slashes. Findings/severity/exit are what parity actually checks.
norm() { printf '%s' "$1" | sed -e 's#\./##g' -e 's#//*#/#g'; }
check() { # <desc> <seed-fn>
  local desc="$1" seedfn="$2"; local D O_SH O_JS rc_sh rc_js
  D=$(mktmp); "$seedfn" "$D"
  O_SH="$( cd "$D" && bash "$SH" 2>&1 )"; rc_sh=$?
  O_JS="$( cd "$D" && node "$JS" 2>&1 )"; rc_js=$?
  if [ "$rc_sh" != "$rc_js" ]; then echo "FAIL - $desc  rc sh=$rc_sh js=$rc_js"; fails=$((fails+1)); rm -rf "$D"; return; fi
  if [ "$(norm "$O_SH")" = "$(norm "$O_JS")" ]; then echo "ok   - $desc  (rc=$rc_sh)"
  else echo "FAIL - $desc  findings differ:"; diff <(norm "$O_SH") <(norm "$O_JS") | head -20; fails=$((fails+1)); fi
  rm -rf "$D"
}

s_status() { printf '# S\nslug: %s\nstatus: %s\nverified: %s\nretro: %s\n' "$2" "$3" "$4" "$5" > "$1"; }
seed_clean()  { mkdir -p "$1/.forge"; }
seed_mixed()  { # several findings across groups
  mkdir -p "$1/.forge/done/2026-07-01-x" "$1/.forge/backlog" "$1/.forge/adr" "$1/.claude-plugin" "$1/skills/foo" "$1/scripts"
  s_status "$1/.forge/done/2026-07-01-x/STATUS.md" x executed "yes (t)" "skipped (r)"; printf 'p\n' > "$1/.forge/done/2026-07-01-x/plan.md"  # A4
  printf '<!-- forge-slug: a -->\n<!-- task: 4 -->\n' > "$1/.forge/backlog/a.md"; printf '<!-- forge-slug: b -->\n<!-- task: 4 -->\n' > "$1/.forge/backlog/b.md"  # A6 dup
  printf '# a\n' > "$1/.forge/adr/0001-a.md"; printf '# c\n' > "$1/.forge/adr/0003-c.md"  # B14 gap
  printf '# 1\n' > "$1/.forge/adr/260716-14a-p.md"; printf '# 2\n' > "$1/.forge/adr/260716-14a-q.md"  # B14 time dup (hour granularity)
  printf '# 3\n' > "$1/.forge/adr/260719-161701-r.md"; printf '# 4\n' > "$1/.forge/adr/260719-161701-s.md"  # B14 time dup (second granularity)
  printf '{"version":"1.0.0"}\n' > "$1/.claude-plugin/plugin.json"
  printf '{"metadata":{"version":"1.0.0"},"plugins":[{"version":"9.9.9"}]}\n' > "$1/.claude-plugin/marketplace.json"  # B8
  printf '# no name\n' > "$1/skills/foo/SKILL.md"  # B10
  printf '#!/bin/bash\n' > "$1/scripts/lonely.sh"  # B15
  mkdir -p "$1/.forge/branch/feat-x/adr"; printf '# t\n' > "$1/.forge/branch/feat-x/adr/260716-15a-z.md"  # A8
}
seed_orphan() { mkdir -p "$1/.forge"; printf 'x\n' > "$1/.forge/run.md"; }  # A1
seed_t3()     { mkdir -p "$1/.forge/adr"; printf '# a\n' > "$1/.forge/adr/0001-a.md"; printf '# t\n' > "$1/.forge/adr/260716-14a-z.md"; }  # no false gap
seed_desclen() { mkdir -p "$1/.forge" "$1/skills/foo"; local d; d="$(head -c 700 < /dev/zero | tr '\0' x)"; printf 'name: foo\ndescription: %s\n' "$d" > "$1/skills/foo/SKILL.md"; }  # B16 over-length
seed_retired_dup() { mkdir -p "$1/.forge/adr/retired"; printf '# a\n' > "$1/.forge/adr/260719-161701-active.md"; printf '# r\n' > "$1/.forge/adr/retired/260719-161701-old.md"; }  # B14 active<->retired time-ID dup
seed_desc_folded() { mkdir -p "$1/.forge" "$1/skills/foo"; local d; d="$(head -c 700 < /dev/zero | tr '\0' x)"; printf 'name: foo\ndescription: >-\n  %s\n---\nbody\n' "$d" > "$1/skills/foo/SKILL.md"; }  # B16 folded scalar (was fail-open)
seed_halfexec() { mkdir -p "$1/.forge"; printf '<!-- forge-slug: s -->\n# t\n' > "$1/.forge/plan.md"; printf '# run\n' > "$1/.forge/run.md"; }  # A1(b) plan+run, no STATUS
seed_a9_stale()       { mkdir -p "$1/.forge"; printf 'started: %s\n' "$(( $(date +%s) - 1860 ))" > "$1/.forge/drive.md"; }  # A9 past the 30-min bound
seed_a9_unparseable() { mkdir -p "$1/.forge"; printf 'started: nonsense\n' > "$1/.forge/drive.md"; }  # A9 no valid started:
seed_a9_live()        { mkdir -p "$1/.forge"; printf 'started: %s\n' "$(date +%s)" > "$1/.forge/drive.md"; }  # A9 must stay silent on a live drive
seed_b17_missing() { mkdir -p "$1/.forge" "$1/.claude-plugin" "$1/skills/foo"; printf '{"name":"forge"}\n' > "$1/.claude-plugin/plugin.json"; printf 'name: foo\ndescription: short core\n---\n**Language**: x\n' > "$1/skills/foo/SKILL.md"; }  # B17 rule missing
seed_b17_scoped_out() { mkdir -p "$1/.forge" "$1/.claude-plugin" "$1/skills/theirs"; printf '{"name":"someone-elses-plugin"}\n' > "$1/.claude-plugin/plugin.json"; printf 'name: theirs\ndescription: short core\n---\n**Language**: x\n' > "$1/skills/theirs/SKILL.md"; }  # B17 scope guard
# The three fixtures below are the shapes that actually DIVERGED before the hardening: bash
# grep is line-oriented while JS \s crossed newlines (multiline), and a raw-text scope grep hit
# a nested name (nested). The canonical-altered one guards the body comparison itself. Both
# twins must now reach the same verdict on each.
B17_RULE="$(cat "$HERE/explaining-forge.rule.txt")"
seed_b17_multiline_name() { mkdir -p "$1/.forge" "$1/.claude-plugin" "$1/skills/foo"; printf '{\n  "name":\n    "forge"\n}\n' > "$1/.claude-plugin/plugin.json"; printf 'name: foo\ndescription: short core\n---\n**Language**: x\n' > "$1/skills/foo/SKILL.md"; }  # B17 scope: value on the next line
seed_b17_nested_name() { mkdir -p "$1/.forge" "$1/.claude-plugin" "$1/skills/foo"; printf '{"name":"my-plugin","author":{"name":"forge"}}\n' > "$1/.claude-plugin/plugin.json"; printf 'name: foo\ndescription: short core\n---\n**Language**: x\n' > "$1/skills/foo/SKILL.md"; }  # B17 scope: nested name must not trigger
seed_b17_canonical_altered() { mkdir -p "$1/.forge" "$1/.claude-plugin" "$1/skills/foo"; printf '{"name":"forge"}\n' > "$1/.claude-plugin/plugin.json"; { printf 'name: foo\ndescription: short core\n---\n**Language**: x\n\n'; printf '%s\n' "$B17_RULE" | sed 's/A gloss is not filler/A gloss IS filler/'; } > "$1/skills/foo/SKILL.md"; }  # B17 canonical body altered

# B18 semantic contract fixtures. Keep the good contract as independent signals
# instead of a copied paragraph so parity covers parsing, not prose identity.
seed_b18_base() {
  mkdir -p "$1/.forge" "$1/.claude-plugin" "$1/skills/fg-next" "$1/skills/fg-debug"
  printf '{"name":"forge"}\n' > "$1/.claude-plugin/plugin.json"
  printf '# Handoff\n\n**Applies (2)**\n\n| Group | Skills |\n| --- | --- |\n| Loop | `fg-run` |\n| Utility | `fg-debug` |\n\n**Does NOT apply (1)**\n\n| Skills | Why |\n| --- | --- |\n| `fg-help` | Reporter only |\n' > "$1/skills/fg-next/HANDOFF.md"
  printf '# forge\n\n**핸드오프 표 (handoff table)**:\n적용 지점은 다음 단계가 있는 2곳이다.\n\n**다음 용어**:\n끝.\n' > "$1/.forge/CONTEXT.md"
}
write_b18_debug() {
  { printf '%s\n' '---' 'name: fg-debug' 'description: short core' '---' '**Language**: x' '' "$B17_RULE" ''; printf '%s\n' '## Route by invocation state before diagnosis size' "$2" '## Phase 1 artifacts' "$3" "$4" '## The boundary' "$5"; } > "$1/skills/fg-debug/SKILL.md"
}
seed_b18_good() { seed_b18_base "$1"; write_b18_debug "$1" 'For `verified: failed`, return to fg-run fix-and-re-run.' 'Classify persistent checks separately from one-off curl, trace, HITL, and throwaway commands. See PLAN-FORMAT.' 'Delete raw captures and temporary instrumentation on every exit path.' 'A feedback loop may exist while the root cause remains unconfirmed.'; }
seed_b18_handoff_bad() { seed_b18_good "$1"; sed 's/Applies (2)/Applies (3)/' "$1/skills/fg-next/HANDOFF.md" > "$1/H"; mv "$1/H" "$1/skills/fg-next/HANDOFF.md"; }
seed_b18_handoff_excluded_bad() { seed_b18_good "$1"; sed 's/Does NOT apply (1)/Does NOT apply (2)/' "$1/skills/fg-next/HANDOFF.md" > "$1/H"; mv "$1/H" "$1/skills/fg-next/HANDOFF.md"; }
seed_b18_context_bad() { seed_b18_good "$1"; sed 's/2곳/3곳/' "$1/.forge/CONTEXT.md" > "$1/C"; mv "$1/C" "$1/.forge/CONTEXT.md"; }
seed_b18_active_bad() { seed_b18_base "$1"; write_b18_debug "$1" 'A failed task receives a diagnostic report.' 'Classify persistent checks separately from one-off curl and trace commands. See PLAN-FORMAT.' 'Delete raw captures on every exit path.' 'A feedback loop may exist while the root cause remains unconfirmed.'; }
seed_b18_active_decoupled() { seed_b18_base "$1"; write_b18_debug "$1" 'An active failed task receives a diagnostic report.' 'Classify persistent checks separately from one-off curl and trace commands. See PLAN-FORMAT. A glossary elsewhere mentions `verified: failed` and fix-and-re-run.' 'Delete raw captures on every exit path.' 'A feedback loop may exist while the root cause remains unconfirmed.'; }
seed_b18_eval_bad() { seed_b18_base "$1"; write_b18_debug "$1" 'For `verified: failed`, use fg-run fix-and-re-run.' 'The red command satisfies the fix-forward eval rule by construction. See PLAN-FORMAT.' 'Delete raw captures on every exit path.' 'A feedback loop may exist while the root cause remains unconfirmed.'; }
seed_b18_cleanup_bad() { seed_b18_base "$1"; write_b18_debug "$1" 'For `verified: failed`, use fg-run fix-and-re-run.' 'Classify persistent checks separately from one-off curl commands. See PLAN-FORMAT.' 'The later fix may clean temporary files.' 'A feedback loop may exist while the root cause remains unconfirmed.'; }
seed_b18_loop_bad() { seed_b18_base "$1"; write_b18_debug "$1" 'For `verified: failed`, use fg-run fix-and-re-run.' 'Classify persistent checks separately from one-off curl commands. See PLAN-FORMAT.' 'Delete raw captures on every exit path.' 'Inconclusive means no feedback loop could be built.'; }

check "clean"                 seed_clean
check "mixed findings"        seed_mixed
check "A1 orphan"             seed_orphan
check "T3 no-false-gap"       seed_t3
check "B16 desc length"       seed_desclen
check "B16 folded scalar"    seed_desc_folded
check "A1b half-exec slot"   seed_halfexec
check "B14 active<->retired dup" seed_retired_dup
check "A9 stale drive.md"       seed_a9_stale
check "A9 unparseable drive.md" seed_a9_unparseable
check "A9 live drive.md"        seed_a9_live
check "B17 rule missing"       seed_b17_missing
check "B17 scope guard"        seed_b17_scoped_out
check "B17 multiline name"     seed_b17_multiline_name
check "B17 nested name"        seed_b17_nested_name
check "B17 canonical altered"  seed_b17_canonical_altered
check "B18 good"                seed_b18_good
check "B18 handoff mismatch"    seed_b18_handoff_bad
check "B18 handoff excluded mismatch" seed_b18_handoff_excluded_bad
check "B18 context mismatch"    seed_b18_context_bad
check "B18 active failure"      seed_b18_active_bad
check "B18 active decoupled"    seed_b18_active_decoupled
check "B18 persistent eval"     seed_b18_eval_bad
check "B18 cleanup"             seed_b18_cleanup_bad
check "B18 loop inconclusive"   seed_b18_loop_bad

echo ""
if [ "$fails" -eq 0 ]; then echo "FORGE-DOCTOR PARITY OK"; exit 0
else echo "FORGE-DOCTOR PARITY FAILED ($fails)"; exit 1; fi
