#!/usr/bin/env bash
# Parity test (ADR-0022): forge-merge.sh and forge-merge.js must, for the same
# input state + args, produce the SAME result — identical exit code AND identical
# resulting .forge/ tree (files moved/renamed/rewritten, folders removed). Since
# this primitive MUTATES files, parity is checked on the filesystem outcome.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SH="$HERE/forge-merge.sh"; JS="$HERE/forge-merge.js"
fails=0
mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgmergep.XXXXXX"; }

check() { # <desc> <seed-fn> <args...>
  local desc="$1" seedfn="$2"; shift 2
  local A B rc_sh rc_js
  A=$(mktmp); B=$(mktmp); "$seedfn" "$A"; "$seedfn" "$B"
  ( cd "$A" && bash "$SH" "$@" ) >/dev/null 2>&1; rc_sh=$?
  ( cd "$B" && node "$JS" "$@" ) >/dev/null 2>&1; rc_js=$?
  if [ "$rc_sh" != "$rc_js" ]; then echo "FAIL - $desc  rc sh=$rc_sh js=$rc_js"; fails=$((fails+1)); rm -rf "$A" "$B"; return; fi
  if diff -r "$A/.forge" "$B/.forge" >/dev/null 2>&1; then echo "ok   - $desc  (rc=$rc_sh)"
  else echo "FAIL - $desc  trees differ:"; diff -r "$A/.forge" "$B/.forge" 2>&1 | head -20; fails=$((fails+1)); fi
  rm -rf "$A" "$B"
}

s_adr() { mkdir -p "$1/.forge/branch/feat-x/adr"; printf '# t\n' > "$1/.forge/branch/feat-x/adr/260716-14a-foo.md"; }
seed_clean()   { s_adr "$1"; }
seed_collide() { s_adr "$1"; mkdir -p "$1/.forge/adr"; printf '# e\n' > "$1/.forge/adr/260716-14a-existing.md"
  mkdir -p "$1/.forge/branch/feat-x/retro"; printf 'see ADR-260716-14a\n' > "$1/.forge/branch/feat-x/retro/2026-07-16-foo.md"; }
seed_collide_new() { mkdir -p "$1/.forge/branch/feat-x/adr"; printf '# t\n' > "$1/.forge/branch/feat-x/adr/260719-161701-foo.md"; mkdir -p "$1/.forge/adr"; printf '# e\n' > "$1/.forge/adr/260719-161701-existing.md"
  mkdir -p "$1/.forge/branch/feat-x/retro"; printf 'see ADR-260719-161701\n' > "$1/.forge/branch/feat-x/retro/260719-161701-foo.md"; }
seed_retro()   { mkdir -p "$1/.forge/branch/feat-x/retro" "$1/.forge/retro"
  printf 'b\n' > "$1/.forge/branch/feat-x/retro/2026-07-16-dup.md"; printf 'e\n' > "$1/.forge/retro/2026-07-16-dup.md"; }
seed_ctx_add() { mkdir -p "$1/.forge/branch/feat-x"; printf '# G\n\n## Language\n\n**Alpha**:\nsame\n\n**Beta**:\nnew\n' > "$1/.forge/branch/feat-x/CONTEXT.md"; printf '# G\n\n## Language\n\n**Alpha**:\nsame\n' > "$1/.forge/CONTEXT.md"; }
seed_ctx_redef(){ mkdir -p "$1/.forge/branch/feat-x"; s_adr "$1"; printf '# G\n\n## Language\n\n**Alpha**:\nBRANCH\n' > "$1/.forge/branch/feat-x/CONTEXT.md"; printf '# G\n\n## Language\n\n**Alpha**:\nMAIN\n' > "$1/.forge/CONTEXT.md"; }
seed_nnnn_ok() { mkdir -p "$1/.forge/branch/feat-x/adr"; printf '# l\n' > "$1/.forge/branch/feat-x/adr/0033-legacy.md"; }
seed_nnnn_x()  { mkdir -p "$1/.forge/branch/feat-x/adr"; printf '# d\n' > "$1/.forge/branch/feat-x/adr/0011-dup.md"; mkdir -p "$1/.forge/adr"; printf '# f\n' > "$1/.forge/adr/0011-frozen.md"; }
seed_remap()   { mkdir -p "$1/.forge/backlog" "$1/.forge/branch/feat-x/done/2026-01-01-a" "$1/.forge/branch/feat-x/backlog"
  printf '<!-- forge-slug: keep -->\n<!-- task: 5 -->\n# k\n' > "$1/.forge/backlog/keep.md"
  printf '<!-- forge-slug: a -->\n<!-- task: 2 -->\n# a\n' > "$1/.forge/branch/feat-x/done/2026-01-01-a/plan.md"
  printf '<!-- forge-slug: b -->\n<!-- task: 3 -->\n# b\n' > "$1/.forge/branch/feat-x/backlog/b.md"; }
seed_dropped() { mkdir -p "$1/.forge/branch/feat-x/dropped/gone"; printf 'x\n' > "$1/.forge/branch/feat-x/dropped/gone/plan.md"; }
seed_retired_collide() { mkdir -p "$1/.forge/branch/feat-x/adr"; printf '# t\n' > "$1/.forge/branch/feat-x/adr/260719-161701-foo.md"
  mkdir -p "$1/.forge/adr/retired"; printf '# r\n' > "$1/.forge/adr/retired/260719-161701-old.md"
  mkdir -p "$1/.forge/branch/feat-x/retro"; printf 'see ADR-260719-161701\n' > "$1/.forge/branch/feat-x/retro/260719-161701-foo.md"; }
seed_retired_letterskip() { mkdir -p "$1/.forge/branch/feat-x/adr" "$1/.forge/adr" "$1/.forge/adr/retired"
  printf '# t\n' > "$1/.forge/branch/feat-x/adr/260719-161701-foo.md"        # incoming (bare) — collides with active bare
  printf '# e\n' > "$1/.forge/adr/260719-161701-existing.md"                  # active collision -> must bump
  printf '# ra\n' > "$1/.forge/adr/retired/260719-161701a-old.md"; }          # letter 'a' taken by retired -> must skip to 'b'
seed_inflight(){ s_adr "$1"; printf '<!-- forge-slug: x -->\n' > "$1/.forge/branch/feat-x/plan.md"; }
seed_ambig()   { s_adr "$1"; mkdir -p "$1/.forge/branch/feat-y/adr"; printf '# t\n' > "$1/.forge/branch/feat-y/adr/260716-15a-bar.md"; }
seed_empty()   { mkdir -p "$1/.forge"; }
seed_deep() { mkdir -p "$1/.forge/branch/feature/team/topic/adr"; printf '# t\n' > "$1/.forge/branch/feature/team/topic/adr/260716-14a-deep.md"; }
seed_deep_ambig() { seed_deep "$1"; s_adr "$1"; }
check "deep branch auto discovery" seed_deep
check "deep branch ambiguity" seed_deep_ambig

check "clean move + folder removed"   seed_clean    feat-x
check "time-ID collision + xref"      seed_collide  feat-x
check "NEW-fmt time-ID collision"     seed_collide_new feat-x
check "retired-id collision -> bump"  seed_retired_collide feat-x
check "retired letter-skip -> b"      seed_retired_letterskip feat-x
check "retro move + -2 disambig"      seed_retro    feat-x
check "CONTEXT append new term"       seed_ctx_add  feat-x
seed_ctx_disjoint(){ mkdir -p "$1/.forge/branch/feat-x"; printf '# forge\n\n## Language\n\n**eco summary table**:\nreplaces prose.\n\n**seal summary**:\nexplicit single seal only.\n' > "$1/.forge/branch/feat-x/CONTEXT.md"; printf '# forge\n\n## Language\n\n**Visual Companion**:\ndisplay and answer channel.\n\n**unsealed tail**:\nran but never sealed.\n' > "$1/.forge/CONTEXT.md"; }
seed_ctx_legacy(){ mkdir -p "$1/.forge/branch/feat-x"; printf '# G\n\n## Alpha\nlegacy\n' > "$1/.forge/branch/feat-x/CONTEXT.md"; printf '# G\n\n## Language\n\n**Beta**:\ncanonical\n' > "$1/.forge/CONTEXT.md"; }
check "CONTEXT redefinition -> 4"     seed_ctx_redef feat-x
check "CONTEXT disjoint terms merge"  seed_ctx_disjoint feat-x
check "CONTEXT legacy shape -> 4"     seed_ctx_legacy feat-x
check "incoming NNNN ok"              seed_nnnn_ok  feat-x
check "incoming NNNN collide -> 4"    seed_nnnn_x   feat-x
check "done+backlog task remap"       seed_remap    feat-x
check "dropped moved"                 seed_dropped  feat-x
check "in-flight -> 3"                seed_inflight feat-x
check "ambiguous -> 6"                seed_ambig
check "empty -> 2"                    seed_empty
check "gate-only in-flight -> 3"      seed_inflight feat-x --gate-only
check "gate-only clean -> 0, no move" seed_clean    feat-x --gate-only
check "gate-only skips redef -> 0"    seed_ctx_redef feat-x --gate-only

# Ledger integration: parity alone cannot catch identical data loss in both twins.
fu_entry() { printf '<!-- followup: fu-%s | source: alpha | task: %s | date: 2026-10-20 | status: %s | taken: %s -->\n%s\n\n' "$1" "$2" "$3" "$4" "$5"; }
seed_followups() {
  seed_remap "$1"
  { printf '# Follow-ups\n\n'; fu_entry 111111111111 2 open - 'Open body'; fu_entry 222222222222 2 taken 3 'Taken body'; fu_entry 333333333333 - dismissed - 'Dismissed body'; fu_entry 444444444444 88 open - 'Unresolved legacy'; } > "$1/.forge/branch/feat-x/followups.md"
  { printf '# Follow-ups\n\n'; fu_entry aaaaaaaaaaaa 5 open - 'Existing target'; } > "$1/.forge/followups.md"
}
seed_followups_only() { mkdir -p "$1/.forge/branch/feat-x"; { printf '# Follow-ups\n\n'; fu_entry 111111111111 - open - 'Only ledger'; } > "$1/.forge/branch/feat-x/followups.md"; }
seed_followups_same() { seed_followups_only "$1"; cp "$1/.forge/branch/feat-x/followups.md" "$1/.forge/followups.md"; }
seed_followups_conflict() { seed_followups_same "$1"; { printf '# Follow-ups\n\n'; fu_entry 111111111111 - dismissed - 'Only ledger'; } > "$1/.forge/followups.md"; }
seed_followups_bad() { seed_followups "$1"; printf '<!-- followup: broken -->\n' >> "$1/.forge/branch/feat-x/followups.md"; }
seed_followups_duplicate() { seed_followups_only "$1"; fu_entry 111111111111 - open - 'Only ledger' >> "$1/.forge/branch/feat-x/followups.md"; }
seed_followups_body_conflict() { seed_followups_same "$1"; printf 'Different body\n' >> "$1/.forge/followups.md"; }
seed_followups_empty_body() { seed_followups_only "$1"; sed -i.bak '/Only ledger/d' "$1/.forge/branch/feat-x/followups.md"; rm "$1/.forge/branch/feat-x/followups.md.bak"; }
seed_followups_bad_target() { seed_followups_only "$1"; printf '<!-- followup: broken -->\n' > "$1/.forge/followups.md"; }
seed_followups_snapshots() {
  seed_followups "$1"
  mkdir -p "$1/.forge/branch/feat-x/retro"
  { printf '# Run\n\nLiteral task: 2 and taken: 3 stay unchanged.\n\n'; fu_entry 222222222222 2 taken 3 'Taken body'; } > "$1/.forge/branch/feat-x/done/2026-01-01-a/run.md"
  cp "$1/.forge/branch/feat-x/done/2026-01-01-a/run.md" "$1/.forge/branch/feat-x/retro/261020-120000-a.md"
}
seed_followups_bad_snapshot() { seed_followups_snapshots "$1"; printf '<!-- followup: broken -->\n' >> "$1/.forge/branch/feat-x/retro/261020-120000-a.md"; }
seed_followups_unicode() { seed_followups_only "$1"; sed -i.bak 's/source: alpha/source: 후속.후보-수집/' "$1/.forge/branch/feat-x/followups.md"; rm "$1/.forge/branch/feat-x/followups.md.bak"; }
seed_followups_unterminated() { seed_followups_snapshots "$1"; printf 'Final body without newline' >> "$1/.forge/branch/feat-x/done/2026-01-01-a/run.md"; }
check 'followups unterminated body preservation' seed_followups_unterminated feat-x
check 'followups snapshots remap' seed_followups_snapshots feat-x
check 'followups snapshot validation before mutation' seed_followups_bad_snapshot feat-x
check 'followups Unicode source' seed_followups_unicode feat-x
check 'followups all states + task and taken remap' seed_followups feat-x
check 'followups-only root discovery' seed_followups_only
check 'followups identical ID deduplicates' seed_followups_same feat-x
check 'followups terminal conflict refuses' seed_followups_conflict feat-x
check 'followups malformed refuses' seed_followups_bad feat-x
check 'followups duplicate ID refuses' seed_followups_duplicate feat-x
check 'followups changed body refuses' seed_followups_body_conflict feat-x
check 'followups empty body refuses' seed_followups_empty_body feat-x
check 'followups malformed target refuses' seed_followups_bad_target feat-x
check 'followups gate-only skips conflicts' seed_followups_conflict feat-x --gate-only
for runtime in bash node; do
  script="$SH"; [ "$runtime" = node ] && script="$JS"
  D=$(mktmp); seed_followups "$D"
  (cd "$D" && "$runtime" "$script" feat-x) >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 0 ] && [ ! -d "$D/.forge/branch/feat-x" ] &&
     grep -qF 'task: 6 | date: 2026-10-20 | status: taken | taken: 7' "$D/.forge/followups.md" &&
     grep -qF 'task: 88 |' "$D/.forge/followups.md" &&
     grep -qF 'Dismissed body' "$D/.forge/followups.md" &&
     grep -qF 'Existing target' "$D/.forge/followups.md" &&
     [ "$(grep -c '^<!-- followup:' "$D/.forge/followups.md")" -eq 5 ]; then
    echo "ok   - $runtime followups content assertions"
  else echo "FAIL - $runtime followups content assertions"; fails=$((fails+1)); fi
  rm -rf "$D"
  for seed in seed_followups_conflict seed_followups_bad seed_followups_duplicate seed_followups_body_conflict seed_followups_empty_body seed_followups_bad_target seed_followups_bad_snapshot; do
    D=$(mktmp); "$seed" "$D"; cp -R "$D/.forge" "$D/before"
    (cd "$D" && "$runtime" "$script" feat-x) >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 4 ] && diff -r "$D/.forge" "$D/before" >/dev/null; then echo "ok   - $runtime $seed non-destructive gate"
    else echo "FAIL - $runtime $seed non-destructive gate"; fails=$((fails+1)); fi
    rm -rf "$D"
  done
  D=$(mktmp); seed_followups_snapshots "$D"
  (cd "$D" && "$runtime" "$script" feat-x) >/dev/null 2>&1
  helper="$HERE/forge-followups.sh"; [ "$runtime" = node ] && helper="$HERE/forge-followups.js"
  (cd "$D" && "$runtime" "$helper" collect --root .forge --file .forge/done/2026-01-01-a/run.md --file .forge/retro/261020-120000-a.md) >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 0 ] && grep -qF 'Literal task: 2 and taken: 3 stay unchanged.' "$D/.forge/done/2026-01-01-a/run.md" && grep -qF 'task: 6 | date: 2026-10-20 | status: taken | taken: 7' "$D/.forge/retro/261020-120000-a.md"; then echo "ok   - $runtime merged snapshots replay and prose preserved"
  else echo "FAIL - $runtime merged snapshots replay"; fails=$((fails+1)); fi
  rm -rf "$D"
  D=$(mktmp); seed_followups_same "$D"
  (cd "$D" && "$runtime" "$script" feat-x) >/dev/null 2>&1
  if [ "$(grep -c '^<!-- followup:' "$D/.forge/followups.md")" -eq 1 ]; then echo "ok   - $runtime identical ID retained once"
  else echo "FAIL - $runtime identical ID dedup"; fails=$((fails+1)); fi
  rm -rf "$D"
done

echo ""
if [ "$fails" -eq 0 ]; then echo "FORGE-MERGE PARITY OK"; exit 0
else echo "FORGE-MERGE PARITY FAILED ($fails)"; exit 1; fi
