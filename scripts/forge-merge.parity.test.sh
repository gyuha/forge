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
seed_retro()   { mkdir -p "$1/.forge/branch/feat-x/retro" "$1/.forge/retro"
  printf 'b\n' > "$1/.forge/branch/feat-x/retro/2026-07-16-dup.md"; printf 'e\n' > "$1/.forge/retro/2026-07-16-dup.md"; }
seed_ctx_add() { mkdir -p "$1/.forge/branch/feat-x"; printf '# G\n\n## Alpha\nsame\n\n## Beta\nnew\n' > "$1/.forge/branch/feat-x/CONTEXT.md"; printf '# G\n\n## Alpha\nsame\n' > "$1/.forge/CONTEXT.md"; }
seed_ctx_redef(){ mkdir -p "$1/.forge/branch/feat-x"; s_adr "$1"; printf '# G\n\n## Alpha\nBRANCH\n' > "$1/.forge/branch/feat-x/CONTEXT.md"; printf '# G\n\n## Alpha\nMAIN\n' > "$1/.forge/CONTEXT.md"; }
seed_nnnn_ok() { mkdir -p "$1/.forge/branch/feat-x/adr"; printf '# l\n' > "$1/.forge/branch/feat-x/adr/0033-legacy.md"; }
seed_nnnn_x()  { mkdir -p "$1/.forge/branch/feat-x/adr"; printf '# d\n' > "$1/.forge/branch/feat-x/adr/0011-dup.md"; mkdir -p "$1/.forge/adr"; printf '# f\n' > "$1/.forge/adr/0011-frozen.md"; }
seed_remap()   { mkdir -p "$1/.forge/backlog" "$1/.forge/branch/feat-x/done/2026-01-01-a" "$1/.forge/branch/feat-x/backlog"
  printf '<!-- forge-slug: keep -->\n<!-- task: 5 -->\n# k\n' > "$1/.forge/backlog/keep.md"
  printf '<!-- forge-slug: a -->\n<!-- task: 2 -->\n# a\n' > "$1/.forge/branch/feat-x/done/2026-01-01-a/plan.md"
  printf '<!-- forge-slug: b -->\n<!-- task: 3 -->\n# b\n' > "$1/.forge/branch/feat-x/backlog/b.md"; }
seed_dropped() { mkdir -p "$1/.forge/branch/feat-x/dropped/gone"; printf 'x\n' > "$1/.forge/branch/feat-x/dropped/gone/plan.md"; }
seed_inflight(){ s_adr "$1"; printf '<!-- forge-slug: x -->\n' > "$1/.forge/branch/feat-x/plan.md"; }
seed_ambig()   { s_adr "$1"; mkdir -p "$1/.forge/branch/feat-y/adr"; printf '# t\n' > "$1/.forge/branch/feat-y/adr/260716-15a-bar.md"; }
seed_empty()   { mkdir -p "$1/.forge"; }

check "clean move + folder removed"   seed_clean    feat-x
check "time-ID collision + xref"      seed_collide  feat-x
check "retro move + -2 disambig"      seed_retro    feat-x
check "CONTEXT append new term"       seed_ctx_add  feat-x
check "CONTEXT redefinition -> 4"     seed_ctx_redef feat-x
check "incoming NNNN ok"              seed_nnnn_ok  feat-x
check "incoming NNNN collide -> 4"    seed_nnnn_x   feat-x
check "done+backlog task remap"       seed_remap    feat-x
check "dropped moved"                 seed_dropped  feat-x
check "in-flight -> 3"                seed_inflight feat-x
check "ambiguous -> 6"                seed_ambig
check "empty -> 2"                    seed_empty

echo ""
if [ "$fails" -eq 0 ]; then echo "FORGE-MERGE PARITY OK"; exit 0
else echo "FORGE-MERGE PARITY FAILED ($fails)"; exit 1; fi
