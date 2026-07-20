#!/usr/bin/env bash
# forge-merge.sh — deterministic branch-forge integration primitive
# (task forge-merge-script-extract; extends the ADR-0030/ADR-0020 script-backing
# pattern to fg-merge). The MECHANICAL integration runs here so it works AI-free
# in CI; the JUDGMENT (semantic ADR contradictions, conflict prose, handoff) stays
# in fg-merge's skill.
#
# Runs AFTER `git merge <branch>` brought `.forge/branch/<branch>/` into the
# default branch. It does NOT run git. (The interactive fg-merge skill may run
# `git merge` itself before calling this, in its merge-and-integrate mode — ADR
# 260717-10a — but this script never does; that git-free property is what keeps
# it usable AI-free in CI.) It integrates the branch root's permanent forge docs
# into the top-level `.forge/`:
#   ADRs   — time-based IDs moved as-is; exact-ID collision -> next free letter,
#            NO cascade renumber (the #77 scheme); incoming grandfathered NNNN
#            moved as-is, but a collision with a frozen target NNNN halts (exit 4).
#   retros — moved; `-2` on filename collision.
#   CONTEXT.md — terms appended; a term redefined differently halts (exit 4).
#   done/ + backlog/ — folded, with ONE monotonic task-number remap across both.
#   dropped/ — moved (never blocks).
#   bumped-ADR cross-references — rewritten within the moved incoming docs;
#            merge-changed non-.forge/ files are grepped and WARNED (never rewritten).
#   then the branch folder is removed (+ empty slashed parent pruned).
#
# GATE-FIRST, NON-DESTRUCTIVE-ON-REFUSE: blocking conditions exit non-zero BEFORE
# anything moves.
#
# Usage:  forge-merge.sh [<branch>] [--completed <YYYY-MM-DD>]
#   <branch>  branch whose root to integrate; omitted => resolve (one leaf root =>
#             that one; several => exit 6 list).
#
# Exit codes (fg-merge routes; CI fails on any non-zero):
#   0  integrated OK (branch folder removed)
#   2  nothing to integrate (no branch root / named branch absent / empty)
#   3  in-flight branch state (active slot · executed/ · pending quick · loop.md)
#   4  genuine conflict needs a human: CONTEXT term redefinition, or an incoming
#      grandfathered NNNN ADR colliding with a frozen target NNNN. Nothing moved.
#      (Semantic ADR contradictions are NOT script-detectable — left to PR review.)
#   6  ambiguous: several branch roots and no <branch> given
#
# Dependencies: bash + coreutils + awk/sed/grep (+ git only for the warn-only
# external-ref grep, best-effort).  Dual dispatch: forge-merge.js twin.

set -u

# --- args --------------------------------------------------------------------
branch_arg=""; completed=""
while [ $# -gt 0 ]; do
  case "$1" in
    --completed) completed="${2:-}"; shift 2 ;;
    -*) echo "forge-merge: unknown arg: $1" >&2; exit 64 ;;
    *)  branch_arg="$1"; shift ;;
  esac
done
[ -n "$completed" ] || completed="$(date +%F 2>/dev/null || echo 0000-00-00)"

top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
prefix="${top:+$top/}"
TARGET="${prefix}.forge"
BRANCHES_DIR="$TARGET/branch"

# --- resolve which branch root to integrate ----------------------------------
is_leaf_root() {
  for m in adr retro done backlog dropped; do [ -d "$1/$m" ] && return 0; done
  for m in CONTEXT.md plan.md run.md STATUS.md loop.md; do [ -e "$1/$m" ] && return 0; done
  return 1
}
find_leaf_roots() {
  [ -d "$BRANCHES_DIR" ] || return 0
  for d in "$BRANCHES_DIR"/*/ "$BRANCHES_DIR"/*/*/; do
    [ -d "$d" ] || continue; d="${d%/}"; is_leaf_root "$d" && echo "$d"
  done
}
if [ -n "$branch_arg" ]; then
  SRC="$BRANCHES_DIR/$branch_arg"
  { [ -d "$SRC" ] && is_leaf_root "$SRC"; } || { echo "EMPTY no-branch-root branch=$branch_arg"; exit 2; }
else
  roots="$(find_leaf_roots)"; n="$(printf '%s\n' "$roots" | grep -c . )"
  if   [ "$n" -eq 0 ]; then echo "EMPTY nothing-to-integrate"; exit 2
  elif [ "$n" -eq 1 ]; then SRC="$roots"
  else echo "AMBIGUOUS several-branch-roots:"; printf '%s\n' "$roots"; exit 6; fi
fi

# --- helpers -----------------------------------------------------------------
slugof() { sed -n 's/.*forge-slug:[[:space:]]*\([^ ]*\)[[:space:]]*-->.*/\1/p' "$1" 2>/dev/null | head -1 | tr -d '\r'; }
taskof() { sed -n 's/.*task:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$1" 2>/dev/null | head -1 | tr -d '\r'; }
is_timebased() { printf '%s' "$1" | grep -qE '^[0-9]{6}-[0-9]{2}[a-z]+-|^[0-9]{6}-[0-9]{6}[a-z]?-'; }
is_nnnn()      { printf '%s' "$1" | grep -qE '^[0-9]{4}-'; }
# term headings (## X) in a CONTEXT file
ctx_terms() { [ -f "$1" ] || return 0; awk '/^## /{s=$0; sub(/^## /,"",s); print s}' "$1"; }
# body of term $2 in file $1 (lines after its "## X" up to the next "## " / EOF)
ctx_body()  { awk -v t="## $2" 'BEGIN{f=0} $0==t{f=1;next} /^## /{if(f)exit} f{print}' "$1"; }

# --- GATE 1: in-flight branch state ------------------------------------------
inflight=""
[ -f "$SRC/plan.md" ] && inflight="active-slot(plan.md)"
[ -z "$inflight" ] && [ -d "$SRC/executed" ] && [ -n "$(ls -A "$SRC/executed" 2>/dev/null)" ] && inflight="executed/"
[ -z "$inflight" ] && [ -f "$SRC/loop.md" ] && inflight="loop.md(goal contract)"
if [ -z "$inflight" ] && [ -f "$SRC/quick/LOG.md" ]; then
  grep -qiE '^(- )?(result|결과)[[:space:]]*:[[:space:]]*pending' "$SRC/quick/LOG.md" && inflight="quick(pending)"
fi
[ -n "$inflight" ] && { echo "GATE_INFLIGHT $inflight branch=$SRC — seal/recover/resume on the branch first"; exit 3; }

# --- GATE 2: CONTEXT term redefinition ---------------------------------------
if [ -f "$SRC/CONTEXT.md" ] && [ -f "$TARGET/CONTEXT.md" ]; then
  while IFS= read -r term; do
    [ -n "$term" ] || continue
    ctx_terms "$TARGET/CONTEXT.md" | grep -qxF "$term" || continue
    sb="$(ctx_body "$SRC/CONTEXT.md" "$term")"; tb="$(ctx_body "$TARGET/CONTEXT.md" "$term")"
    [ "$sb" = "$tb" ] || { echo "GATE_CONFLICT context-term-redefinition term=[$term] — human resolves"; exit 4; }
  done <<EOF
$(ctx_terms "$SRC/CONTEXT.md")
EOF
fi

# --- GATE 3: incoming grandfathered NNNN ADR colliding with a frozen target --
if [ -d "$SRC/adr" ]; then
  for f in "$SRC"/adr/*.md; do
    [ -e "$f" ] || continue; bn="$(basename "$f")"
    is_nnnn "$bn" || continue
    num="$(printf '%s' "$bn" | sed -E 's/^([0-9]{4})-.*/\1/')"
    if ls "$TARGET"/adr/"$num"-*.md >/dev/null 2>&1 || ls "$TARGET"/adr/retired/"$num"-*.md >/dev/null 2>&1; then
      echo "GATE_CONFLICT incoming-NNNN-collides ADR-$num (frozen target) — human resolves (no cascade renumber)"; exit 4
    fi
  done
fi

# =============================================================================
# MUTATION PHASE (past all gates)
# =============================================================================
MOVED=""              # newline-list of destination paths of moved incoming docs
track() { MOVED="$MOVED$1"$'\n'; }
BUMPS=""              # newline-list of "oldid newid" for cross-ref rewrite

next_free_letter() { # $1=adr-dir $2=base(YYMMDD-HH)
  local dir="$1" base="$2" used c
  used="$(ls "$dir"/"$base"[a-z]*-*.md 2>/dev/null | sed -n "s#.*/$base\([a-z]\{1,\}\)-.*#\1#p")"
  for c in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
    printf '%s\n' "$used" | grep -qx "$c" || { echo "$c"; return 0; }
  done
  echo "aa"
}

integrate_adrs() {
  [ -d "$SRC/adr" ] || return 0
  mkdir -p "$TARGET/adr"
  local f bn id rest base letter newid dest
  for f in "$SRC"/adr/*.md; do
    [ -e "$f" ] || continue; bn="$(basename "$f")"
    if is_timebased "$bn"; then
      if printf '%s' "$bn" | grep -qE '^[0-9]{6}-[0-9]{6}[a-z]?-'; then    # second-granularity (current)
        id="$(printf '%s' "$bn" | sed -E 's/^([0-9]{6}-[0-9]{6}[a-z]?)-.*/\1/')"
        rest="$(printf '%s' "$bn" | sed -E 's/^[0-9]{6}-[0-9]{6}[a-z]?-(.*)/\1/')"
        base="$(printf '%s' "$id" | sed -E 's/([0-9]{6}-[0-9]{6})[a-z]?/\1/')"
      else                                                                 # hour-granularity (grandfathered)
        id="$(printf '%s' "$bn" | sed -E 's/^([0-9]{6}-[0-9]{2}[a-z]+)-.*/\1/')"
        rest="$(printf '%s' "$bn" | sed -E 's/^[0-9]{6}-[0-9]{2}[a-z]+-(.*)/\1/')"
        base="$(printf '%s' "$id" | sed -E 's/([0-9]{6}-[0-9]{2})[a-z]+/\1/')"
      fi
      if [ -e "$TARGET/adr/$bn" ] || ls "$TARGET"/adr/"$id"-*.md >/dev/null 2>&1; then
        letter="$(next_free_letter "$TARGET/adr" "$base")"; newid="${base}${letter}"
        dest="$TARGET/adr/${newid}-${rest}"
        echo "  adr collision: $id -> $newid"
        BUMPS="$BUMPS$id $newid"$'\n'
        mv "$f" "$dest"; track "$dest"
      else
        mv "$f" "$TARGET/adr/$bn"; track "$TARGET/adr/$bn"
      fi
    else
      # NNNN incoming: collision already gated out (GATE 3) -> safe move-as-is
      mv "$f" "$TARGET/adr/$bn"; track "$TARGET/adr/$bn"
    fi
  done
  # retired/ (if the branch retired any) — move as-is (ids are frozen either scheme)
  if [ -d "$SRC/adr/retired" ]; then
    mkdir -p "$TARGET/adr/retired"
    for f in "$SRC"/adr/retired/*.md; do [ -e "$f" ] || continue; mv "$f" "$TARGET/adr/retired/$(basename "$f")"; done
  fi
}

integrate_retros() {
  [ -d "$SRC/retro" ] || return 0
  mkdir -p "$TARGET/retro"
  local f bn dest
  for f in "$SRC"/retro/*.md; do
    [ -e "$f" ] || continue; bn="$(basename "$f")"; dest="$TARGET/retro/$bn"
    [ -e "$dest" ] && dest="$TARGET/retro/${bn%.md}-2.md"
    mv "$f" "$dest"; track "$dest"
  done
}

integrate_context() {
  [ -f "$SRC/CONTEXT.md" ] || return 0
  if [ ! -f "$TARGET/CONTEXT.md" ]; then
    cp "$SRC/CONTEXT.md" "$TARGET/CONTEXT.md"; track "$TARGET/CONTEXT.md"; return 0
  fi
  local term
  while IFS= read -r term; do
    [ -n "$term" ] || continue
    ctx_terms "$TARGET/CONTEXT.md" | grep -qxF "$term" && continue  # exists (identical body — gated)
    { printf '\n## %s\n' "$term"; ctx_body "$SRC/CONTEXT.md" "$term"; } >> "$TARGET/CONTEXT.md"
  done <<EOF
$(ctx_terms "$SRC/CONTEXT.md")
EOF
  track "$TARGET/CONTEXT.md"
}

# ONE monotonic task-number remap across incoming done/ + backlog/, then fold.
integrate_done_and_backlog() {
  local tmax=0 n
  for p in "$TARGET"/backlog/*.md "$TARGET"/plan.md "$TARGET"/executed/*/plan.md "$TARGET"/done/*/plan.md; do
    [ -e "$p" ] || continue; n="$(taskof "$p")"; [ -n "$n" ] && [ "$n" -gt "$tmax" ] && tmax="$n"
  done
  # incoming plans in ascending old-N order (done/*/plan.md + backlog/*.md)
  local incoming="" line oldn f
  for f in "$SRC"/done/*/plan.md "$SRC"/backlog/*.md; do
    [ -e "$f" ] || continue; oldn="$(taskof "$f")"; [ -n "$oldn" ] || oldn=0
    incoming="$incoming$oldn	$f"$'\n'
  done
  incoming="$(printf '%s' "$incoming" | grep -c . >/dev/null 2>&1 && printf '%s' "$incoming" | sort -n)"
  while IFS=$'\t' read -r oldn f; do
    [ -n "${f:-}" ] || continue
    tmax=$((tmax+1))
    sed -i.bak -E "s/(task:[[:space:]]*)[0-9]+/\1$tmax/" "$f" 2>/dev/null && rm -f "$f.bak"
  done <<EOF
$incoming
EOF
  # fold done/
  if [ -d "$SRC/done" ]; then
    mkdir -p "$TARGET/done"
    for d in "$SRC"/done/*/; do
      [ -d "$d" ] || continue; bn="$(basename "$d")"; dest="$TARGET/done/$bn"
      [ -e "$dest" ] && dest="$TARGET/done/${bn}-2"
      mv "$d" "$dest"; track "$dest"
    done
  fi
  # fold backlog/
  if [ -d "$SRC/backlog" ]; then
    mkdir -p "$TARGET/backlog"
    for f in "$SRC"/backlog/*.md; do
      [ -e "$f" ] || continue; bn="$(basename "$f")"; dest="$TARGET/backlog/$bn"
      if [ -e "$dest" ]; then dest="$TARGET/backlog/${bn%.md}-2.md"
        s="$(slugof "$f")"; [ -n "$s" ] && sed -i.bak "s/forge-slug:[[:space:]]*$s/forge-slug: ${s}-2/" "$f" 2>/dev/null && rm -f "$f.bak"
      fi
      mv "$f" "$dest"; track "$dest"
    done
  fi
}

integrate_dropped() {
  [ -d "$SRC/dropped" ] || return 0
  mkdir -p "$TARGET/dropped"
  for d in "$SRC"/dropped/*/; do
    [ -d "$d" ] || continue; bn="$(basename "$d")"; dest="$TARGET/dropped/$bn"
    [ -e "$dest" ] && dest="$TARGET/dropped/${bn}-2"
    mv "$d" "$dest"
  done
}

rewrite_bumped_crossrefs() {
  [ -n "$BUMPS" ] || return 0
  local oldid newid target
  while IFS=' ' read -r oldid newid; do
    [ -n "${newid:-}" ] || continue
    while IFS= read -r target; do
      [ -f "$target" ] || continue
      sed -i.bak "s/ADR-$oldid/ADR-$newid/g; s/$oldid-/$newid-/g" "$target" 2>/dev/null && rm -f "$target.bak"
    done <<EOF
$MOVED
EOF
  done <<EOF
$BUMPS
EOF
  # warn-only: merge-changed non-.forge/ files may cite a bumped id by its old value
  if [ -n "$top" ] && git -C "$top" rev-parse ORIG_HEAD >/dev/null 2>&1; then
    while IFS=' ' read -r oldid newid; do
      [ -n "${newid:-}" ] || continue
      git -C "$top" diff --name-only ORIG_HEAD..HEAD 2>/dev/null | grep -v '^\.forge/' | while IFS= read -r pf; do
        [ -f "$top/$pf" ] || continue
        grep -qF "ADR-$oldid" "$top/$pf" 2>/dev/null && echo "  WARN external ref ADR-$oldid in $pf (now $newid) — rewrite by hand"
      done
    done <<EOF
$BUMPS
EOF
  fi
}

remove_branch_folder() {
  rm -rf "$SRC"
  # prune empty slashed parent (feature/x -> feature/)
  local parent; parent="$(dirname "$SRC")"
  [ "$parent" != "$BRANCHES_DIR" ] && [ -d "$parent" ] && [ -z "$(ls -A "$parent" 2>/dev/null)" ] && rmdir "$parent" 2>/dev/null || true
}

integrate_adrs
integrate_retros
integrate_context
integrate_done_and_backlog
integrate_dropped
rewrite_bumped_crossrefs
remove_branch_folder

echo "SEALED integrated branch=$SRC target=$TARGET"
exit 0
