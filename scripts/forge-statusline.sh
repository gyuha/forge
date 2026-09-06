#!/usr/bin/env bash
# forge-statusline.sh — print forge progress fragment line(s).
#
# A deliberately thin, display-only reader of forge state (ADR-0017; grouping +
# density added ADR-0029). It reads the resolved forge root (ADR-0011) relative
# to the current working directory and prints the forge progress, grouped into
# bracketed semantic units. It does NOT reproduce fg-status's next-step machine.
#
# Segments are grouped as [ ... ], groups joined by a space, segments inside a
# group joined by " <SEP> " (SEP = FORGE_SL_SEP, default "·"; the merge-mode full
# script passes "|"). Brackets/separators are dim; the pipeline arrows "→" are not
# a group separator. Empty groups are omitted entirely.
#
# Density (FORGE_SL_DENSITY, default "full"; the full script passes "compact"):
#   full     -> up to two lines:
#     [🔁 rN/cap] [⚒ [#N ]<slug> · <pipeline>[ · <flag>]]      (line 1)
#     [📋 N queued · 📝 M awaiting retro[ · ♻️][ · 🧪]]         (line 2)
#   compact  -> a single line, forge + queue-count + mode indicators in one group:
#     [🔁 rN/cap] [⚒ [#N ]<slug> · <pipeline>[ · <flag>][ · 📋 N][ · ♻️][ · 🧪]]
#
# flag (when run.md present): ✓ verified yes · ⏳ pending · ✗ failed · (none) skipped/n/a.
# 🧪 = plan has "<!-- tdd: on -->"; ♻️ = TOP-LEVEL .forge/config.json "eco": true
# (branch-independent global, ADR-0011). Only lit indicators are shown. Method 1
# (append/wrapper) gets these too (global grouping) but keeps SEP "·" and no color.
#
# The current stage is gated, not just file-existence-based (ADR-0017, 3rd amend):
#   no plan.md, no ask.md              -> line 1 empty (or loop-only fallback)
#   no plan.md, ask.md present         -> ask current (plan.md wins if both exist)
#   plan.md, no run.md                 -> run current
#   run.md + verified pending/failed   -> run current (retro gate refuses these)
#   run.md + verified yes/skipped/n/a  -> learn current (retro gate passed)
# "done" never becomes current — a sealed task leaves .forge/plan.md.
#
# Dependencies: bash + git only. No JSON/jq parsing (reads files by path).
# FORGE_SL_PREFIX (env): line-1 prefix, default "⚒ ".
# FORGE_SL_SEP (env):    intra-group separator, default "·" (full passes "|").
# FORGE_SL_DENSITY (env): "full" (default) or "compact" (full passes "compact").

set -u

SEP="${FORGE_SL_SEP:-·}"
DENSITY="${FORGE_SL_DENSITY:-full}"
[ "$DENSITY" = "compact" ] || DENSITY="full"

# --- ANSI helpers -------------------------------------------------------------
DOT_DONE=$'\033[32m'      # green — completed stage
DOT_CUR=$'\033[1;36m'     # bold cyan — current stage
DOT_UPCOMING=$'\033[2m'   # dim — upcoming stage
DIM=$'\033[2m'            # dim — brackets and separators
RESET=$'\033[0m'

# grp <part...> -> "[ part1 <SEP> part2 ... ]" with dim brackets/separators.
# Empty parts are dropped; if nothing remains, prints nothing (no empty []).
grp() {
  local out="" first=1 p
  for p in "$@"; do
    [ -z "$p" ] && continue
    if [ "$first" -eq 1 ]; then out="$p"; first=0; else out="${out} ${DIM}${SEP}${RESET} ${p}"; fi
  done
  [ -z "$out" ] && return 0
  printf '%s[%s%s%s]%s' "$DIM" "$RESET" "$out" "$DIM" "$RESET"
}

# build_pipeline <stage: ask|run|learn> -> "✔ ask → ● run → ○ learn → ○ done" (colored)
build_pipeline() {
  local stage="$1" target=0 i=0 out="" seg w
  case "$stage" in ask) target=0 ;; run) target=1 ;; learn) target=2 ;; esac
  for w in ask run learn done; do
    if [ "$i" -lt "$target" ]; then seg="${DOT_DONE}✔ ${w}${RESET}"
    elif [ "$i" -eq "$target" ]; then seg="${DOT_CUR}● ${w}${RESET}"
    else seg="${DOT_UPCOMING}○ ${w}${RESET}"; fi
    if [ -z "$out" ]; then out="$seg"; else out="${out} → ${seg}"; fi
    i=$((i + 1))
  done
  printf '%s' "$out"
}

# --- cwd from session JSON (stdin) -------------------------------------------
if [ ! -t 0 ]; then
  input="$(cat 2>/dev/null || true)"
  if [ -n "${input:-}" ]; then
    cwd="$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    [ -z "$cwd" ] && cwd="$(printf '%s' "$input" | sed -n 's/.*"current_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    [ -n "$cwd" ] && cwd="$(printf '%s' "$cwd" | sed 's/\\\\/\\/g')"
    [ -n "$cwd" ] && [ -d "$cwd" ] && cd "$cwd" 2>/dev/null || true
  fi
fi

# --- Resolve forge root (ADR-0011 / FORGE-ROOT.md) ---------------------------
top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
prefix="${top:+$top/}"
cfg="${top:-.}/.forge/config.json"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

default_branch="main"
if [ -f "$cfg" ]; then
  d="$(sed -n 's/.*"defaultBranch"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$cfg" | head -1)"
  [ -n "$d" ] && default_branch="$d"
fi

if [ -z "$branch" ] || [ "$branch" = "HEAD" ] || [ "$branch" = "$default_branch" ]; then
  root="${prefix}.forge"
else
  root="${prefix}.forge/branch/$branch"
fi

[ -d "$root" ] || exit 0

# --- Eco indicator source (♻️): TOP-LEVEL .forge/config.json -----------------
eco=""
if [ -f "$cfg" ]; then
  e="$(sed -n 's/.*"eco"[[:space:]]*:[[:space:]]*true.*/on/p' "$cfg" | head -1)"
  [ -n "$e" ] && eco="on"
fi

# --- Loop indicator (rN/cap) -------------------------------------------------
loop_rnd=""; loop_cap=""
if [ -f "$root/loop.md" ]; then
  loop_rnd="$(sed -n 's/.*replan-round[[:space:]]*:[[:space:]]*\([0-9]\{1,\}\).*/\1/p' "$root/loop.md" | head -1)"
  loop_cap="$(sed -n 's/.*replan-cap[[:space:]]*:[[:space:]]*\([0-9]\{1,\}\).*/\1/p' "$root/loop.md" | head -1)"
fi
loop_grp=""
[ -n "$loop_rnd" ] && [ -n "$loop_cap" ] && loop_grp="$(grp "🔁 r${loop_rnd}/${loop_cap}")"

# --- Gather forge state ------------------------------------------------------
forge_seg=""       # the "⚒ [#N ]slug" first segment of the forge group
pipeline=""
flag=""
tdd=""
have_forge=0       # 1 if an active plan or ask stage is present (forge group renders)

if [ -f "$root/plan.md" ]; then
  have_forge=1
  slug="$(sed -n 's/.*forge-slug:[[:space:]]*\([^ ]*\)[[:space:]]*-->.*/\1/p' "$root/plan.md" | head -1)"
  [ -z "$slug" ] && slug="plan"
  task_n="$(sed -n 's/.*<!--[[:space:]]*task:[[:space:]]*\([0-9]\{1,\}\)[[:space:]]*-->.*/\1/p' "$root/plan.md" | head -1)"
  grep -q '<!--[[:space:]]*tdd:[[:space:]]*on[[:space:]]*-->' "$root/plan.md" && tdd="on"
  if [ -f "$root/run.md" ]; then
    v=""
    # lowercased: `Yes`/`N/A` must decide the same as `yes`/`n/a` (else the
    # pipeline shows a verified task as still-owed)
    [ -f "$root/STATUS.md" ] && v="$(sed -n 's/^verified:[[:space:]]*\([A-Za-z/]\{1,\}\).*/\1/p' "$root/STATUS.md" | head -1 | tr 'A-Z' 'a-z')"
    case "$v" in
      yes)         flag="✓"; stage="learn" ;;
      failed)      flag="✗"; stage="run" ;;
      pending|"")  flag="⏳"; stage="run" ;;
      skipped|n/a) flag="";  stage="learn" ;;
      *)           flag="⏳"; stage="run" ;;
    esac
  else
    stage="run"; flag=""
  fi
  pipeline="$(build_pipeline "$stage")"
  num_bit=""; [ -n "$task_n" ] && num_bit="#${task_n} "
  forge_seg="${FORGE_SL_PREFIX:-⚒ }${num_bit}${slug}"
elif [ -f "$root/ask.md" ]; then
  have_forge=1
  working_slug="$(sed -n 's/.*forge-ask:[[:space:]]*\([^ ]*\)[[:space:]]*-->.*/\1/p' "$root/ask.md" | head -1)"
  [ -z "$working_slug" ] && working_slug="ask"
  pipeline="$(build_pipeline "ask")"
  flag=""; tdd=""   # no plan yet at the ask stage
  forge_seg="${FORGE_SL_PREFIX:-⚒ }${working_slug}"
fi

# --- Queue counts (backlog + executed) ---------------------------------------
queued_n=0; await_n=0; failed_n=0
# `awaiting retro` counts only parks that CAN be retro'd. A `verified: failed`
# park is blocked from both retro and seal and needs fg-run recovery, so it gets
# its own tally — the same split the SessionStart hook already reports (calling it
# "awaiting retro" told the user to do something the gate refuses).
if [ -d "$root/executed" ]; then
  for d_ex in "$root"/executed/*/; do
    [ -d "$d_ex" ] || continue
    case "$(sed -n 's/^verified:[[:space:]]*\([A-Za-z/]\{1,\}\).*/\1/p' "${d_ex}STATUS.md" 2>/dev/null | head -1 | tr 'A-Z' 'a-z')" in
      failed) failed_n=$((failed_n + 1)) ;;
      *)      await_n=$((await_n + 1)) ;;
    esac
  done
fi
[ -d "$root/backlog" ] && queued_n="$(ls -1 "$root/backlog"/*.md 2>/dev/null | wc -l | tr -d ' ')"

tdd_ind=""; [ -n "$tdd" ] && tdd_ind="🧪"
eco_ind=""; [ -n "$eco" ] && eco_ind="♻️"

# Mode indicators render only alongside real activity (an active task or a
# non-empty queue) — never on a fully idle repo or the loop-only fallback, so
# "nothing when idle" holds (ADR-0017). tdd already implies an active plan.
if [ "$have_forge" -ne 1 ] && [ "${queued_n:-0}" -eq 0 ] && [ "${await_n:-0}" -eq 0 ] && [ "${failed_n:-0}" -eq 0 ]; then
  tdd_ind=""; eco_ind=""
fi

# --- Assemble by density -----------------------------------------------------
if [ "$DENSITY" = "compact" ]; then
  # Always ONE line (the full script splices it as its L2). Groups: [loop] then
  # either the active forge group (with 📋N count + modes folded in) or, with no
  # active task, a queue-count group. Awaiting-retro (📝) is dropped in compact.
  count_bit=""; [ "${queued_n:-0}" -gt 0 ] && count_bit="📋 ${queued_n}"
  if [ "$have_forge" -eq 1 ]; then
    main_grp="$(grp "$forge_seg" "$pipeline" "$flag" "$count_bit" "$eco_ind" "$tdd_ind")"
  else
    main_grp="$(grp "$count_bit" "$eco_ind" "$tdd_ind")"
  fi
  out=""
  [ -n "$loop_grp" ] && out="$loop_grp"
  [ -n "$main_grp" ] && { [ -n "$out" ] && out="${out} ${main_grp}" || out="$main_grp"; }
  [ -n "$out" ] && printf '%s\n' "$out"
  exit 0
fi

# full density: line 1 = [loop] [forge group]; line 2 = [queue + modes]
line1=""
if [ "$have_forge" -eq 1 ]; then
  fg="$(grp "$forge_seg" "$pipeline" "$flag")"
  [ -n "$loop_grp" ] && line1="${loop_grp} "
  line1="${line1}${fg}"
elif [ -n "$loop_grp" ]; then
  line1="$loop_grp"
fi

queued_bit=""; [ "${queued_n:-0}" -gt 0 ] && queued_bit="📋 ${queued_n} queued"
await_bit="";  [ "${await_n:-0}" -gt 0 ] && await_bit="📝 ${await_n} awaiting retro"
failed_bit=""; [ "${failed_n:-0}" -gt 0 ] && failed_bit="✗ ${failed_n} failed"
line2="$(grp "$queued_bit" "$await_bit" "$failed_bit" "$eco_ind" "$tdd_ind")"

[ -n "$line1" ] && printf '%s\n' "$line1"
[ -n "$line2" ] && printf '%s\n' "$line2"
exit 0
