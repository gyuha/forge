#!/usr/bin/env bash
# forge-statusline-full.sh — "merge" mode (method 2, ADR-0029).
#
# Renders daleseo-style SYSTEM info AND forge progress in a single forge-owned
# command. Segments are grouped into bracketed semantic units [ ... ], groups
# joined by a space, segments inside a group joined by " | " (method 2 always
# uses "|"; the delegated fragment is passed FORGE_SL_SEP="|"). Brackets and
# separators are dim.
#
# Density (positional arg $1: "full" default, or "compact"):
#   full (4 lines):
#     [<model> | <effort>] [<dir> | ⎇ <branch [↑N ↓N] [+s !m ?u]>] [⏱ (D) | $X.XX | +A −R]
#     [<emoji> Context[/<size>] <bar> N% | 5h <bar> N% (~H) | 7d <bar> N% (~H)]
#     [⚒ [#N ]<slug> | <pipeline>[ | <flag>]]                     (DELEGATED)
#     [📋 N queued | 📝 M awaiting retro[ | ♻️][ | 🧪]]            (DELEGATED)
#   compact (2 lines): system groups + the usage-bars group on ONE line, then the
#     fragment's single compact group; the session group (⏱/$/±lines) is dropped.
#     [<model> | <effort>] [<dir> | ⎇ …] [<emoji> Context[/<size>] <bar> N% | 5h … | 7d …]
#     [⚒ [#N ]<slug> | <pipeline>[ | <flag>][ | 📋 N][ | ♻️][ | 🧪]]
#
# New fields (guide-informed): Context/<size> attaches context_window_size
# (>=1e6 -> "1M", else round(size/1000)+"K"); a dynamic emoji prefixes Context
# (🟢<20 ⚡20–69 🔥70–89 🚨≥90); bars use a per-cell truecolor gradient; the
# session group carries $cost (cost.total_cost_usd) and +A −R lines
# (cost.total_lines_added/removed). All graceful-omit when their source is absent.
#
# jq-free (defensive sed; nested leaves parent-anchored via json_obj). Colors are
# live-tuned and stripped in tests (ADR-0017): model magenta · ⎇ branch cyan ·
# $cost yellow · +add green / −rm red · separators/brackets dim · bars gradient.
# Time via FORGE_SL_NOW (epoch s) or `date +%s`.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DENSITY="${1:-full}"; [ "$DENSITY" = "compact" ] || DENSITY="full"
SEP="|"

# --- colors (live-tuned; stripped in tests) ----------------------------------
C_MODEL=$'\033[35m'    # magenta
C_BRANCH=$'\033[36m'   # cyan
C_COST=$'\033[33m'     # yellow
C_ADD=$'\033[32m'      # green
C_DEL=$'\033[31m'      # red
DIM=$'\033[2m'
RESET=$'\033[0m'
eff_color() {
  case "$1" in
    low) printf '\033[32m' ;; medium) printf '\033[36m' ;;
    high) printf '\033[33m' ;; max) printf '\033[31m' ;;
    *) printf '%s' "$RESET" ;;
  esac
}

# grp <part...> -> "[ p1 | p2 ]" with dim brackets/separators; empty parts dropped.
grp() {
  local out="" first=1 p
  for p in "$@"; do
    [ -z "$p" ] && continue
    if [ "$first" = 1 ]; then out="$p"; first=0; else out="${out} ${DIM}${SEP}${RESET} ${p}"; fi
  done
  [ -z "$out" ] && return 0
  printf '%s[%s%s%s]%s' "$DIM" "$RESET" "$out" "$DIM" "$RESET"
}

# join_groups <group...> -> groups joined by a single space (empty ones dropped).
join_groups() {
  local out="" g
  for g in "$@"; do
    [ -z "$g" ] && continue
    if [ -z "$out" ]; then out="$g"; else out="${out} ${g}"; fi
  done
  printf '%s' "$out"
}

# --- read session JSON on stdin (only when piped) ----------------------------
input=""
[ ! -t 0 ] && input="$(cat 2>/dev/null || true)"
oneline="$(printf '%s' "$input" | tr '\n' ' ')"

# object value; tolerates one level of nested objects (e.g. context_window.current_usage) in any position — order-independent
json_obj() { printf '%s' "$oneline" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*{\\(\\([^{}]*{[^{}]*}\\)*[^{}]*\\)}.*/\\1/p" | head -1; }
str_in() { printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -1; }
num_in() { printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\\([0-9][0-9.]*\\).*/\\1/p" | head -1; }

floor_int() { local r="${1%%.*}"; case "$r" in ""|*[!0-9]*) printf '0' ;; *) printf '%s' "$r" ;; esac; }

emoji() { # <pctInt>
  local p="$1"
  if [ "$p" -ge 90 ]; then printf '🚨'; elif [ "$p" -ge 70 ]; then printf '🔥'
  elif [ "$p" -ge 20 ]; then printf '⚡'; else printf '🟢'; fi
}

grad_cell() { # <i 0..9> -> truecolor escape (green -> yellow -> red)
  local i="$1" r g b
  if [ "$i" -lt 5 ]; then r=$(( 40 + i * 36 )); g=200; b=$(( 90 - i * 10 ))
  else r=220; g=$(( 200 - (i - 5) * 38 )); b=40; fi
  printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

bar() { # <pctInt> -> "<gradient 10-cell bar> N%"
  local p="$1" filled i out=""
  filled=$(( (p + 5) / 10 )); [ "$filled" -gt 10 ] && filled=10; [ "$filled" -lt 0 ] && filled=0
  i=0; while [ "$i" -lt "$filled" ]; do out="${out}$(grad_cell "$i")█"; i=$((i + 1)); done
  i="$filled"; while [ "$i" -lt 10 ]; do out="${out}${DIM}░"; i=$((i + 1)); done
  printf '%s%s %s%%' "$out" "$RESET" "$p"
}

humanize() { # <seconds> -> "Nm" | "Hh Mm" | "Dd Hh"
  local s="$1"; [ "$s" -lt 0 ] && s=0
  if [ "$s" -gt 86400 ]; then printf '%dd %dh' $(( s / 86400 )) $(( (s % 86400) / 3600 )); return; fi
  local m=$(( s / 60 ))
  if [ "$m" -lt 60 ]; then printf '%dm' "$m"; else printf '%dh %dm' $(( m / 60 )) $(( m % 60 )); fi
}

size_label() { # <bytesInt> -> "/1M" | "/NK"  (empty when 0/absent)
  local s="$1"; [ -z "$s" ] || [ "$s" = "0" ] && return 0
  if [ "$s" -ge 1000000 ]; then printf '/%dM' $(( s / 1000000 )); else printf '/%dK' $(( (s + 500) / 1000 )); fi
}

now="${FORGE_SL_NOW:-$(date +%s 2>/dev/null || echo 0)}"

# --- cwd resolution (same as the fragment) -----------------------------------
if [ -n "$oneline" ]; then
  cwd="$(printf '%s' "$oneline" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  [ -z "$cwd" ] && cwd="$(printf '%s' "$oneline" | sed -n 's/.*"current_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  [ -n "$cwd" ] && cwd="$(printf '%s' "$cwd" | sed 's/\\\\/\\/g')"
  [ -n "$cwd" ] && [ -d "$cwd" ] && cd "$cwd" 2>/dev/null || true
fi

# --- System groups: [model | effort] and [dir | ⎇ git] -----------------------
model="$(str_in "$(json_obj model)" display_name)"
effort="$(str_in "$(json_obj effort)" level)"
dir="$(basename "$(pwd)")"

id_parts=()
[ -n "$model" ] && id_parts+=("${C_MODEL}${model}${RESET}")
[ -n "$effort" ] && id_parts+=("$(eff_color "$effort")${effort}${RESET}")
id_grp="$(grp "${id_parts[@]+"${id_parts[@]}"}")"

loc_parts=("$dir")
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
  st="$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"
  md="$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')"
  ut="$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')"
  ab="$(git rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null || true)"
  gitseg="⎇ $branch"
  if [ -n "$ab" ]; then
    set -- $ab
    behind="${1:-0}"; ahead="${2:-0}"
    [ "${ahead:-0}" -gt 0 ] && gitseg="$gitseg ↑$ahead"
    [ "${behind:-0}" -gt 0 ] && gitseg="$gitseg ↓$behind"
  fi
  [ "${st:-0}" -gt 0 ] && gitseg="$gitseg +$st"
  [ "${md:-0}" -gt 0 ] && gitseg="$gitseg !$md"
  [ "${ut:-0}" -gt 0 ] && gitseg="$gitseg ?$ut"
  loc_parts+=("${C_BRANCH}${gitseg}${RESET}")
fi
loc_grp="$(grp "${loc_parts[@]}")"

# --- Usage-bars group: [emoji Context/size bar N% | 5h … | 7d …] -------------
ctx="$(floor_int "$(num_in "$(json_obj context_window)" used_percentage)")"
ctx_size="$(floor_int "$(num_in "$(json_obj context_window)" context_window_size)")"
usage_parts=("$(emoji "$ctx") Context$(size_label "$ctx_size") $(bar "$ctx")")

five="$(json_obj five_hour)"
if [ -n "$five" ]; then
  fp="$(floor_int "$(num_in "$five" used_percentage)")"; fr="$(floor_int "$(num_in "$five" resets_at)")"
  usage_parts+=("5h $(bar "$fp") (~$(humanize $(( fr - now )) ))")
fi
seven="$(json_obj seven_day)"
if [ -n "$seven" ]; then
  sp="$(floor_int "$(num_in "$seven" used_percentage)")"; sr="$(floor_int "$(num_in "$seven" resets_at)")"
  usage_parts+=("7d $(bar "$sp") (~$(humanize $(( sr - now )) ))")
fi
usage_grp="$(grp "${usage_parts[@]}")"

# --- Session group (full only): [⏱ (D) | $X.XX | +A −R] ----------------------
cost="$(json_obj cost)"
sess_parts=()
if [ -n "$cost" ]; then
  dms="$(num_in "$cost" total_duration_ms)"
  [ -n "$dms" ] && sess_parts+=("⏱ ($(humanize $(( $(floor_int "$dms") / 1000 )) ))")
  usd="$(num_in "$cost" total_cost_usd)"
  [ -n "$usd" ] && sess_parts+=("${C_COST}\$$(printf '%.2f' "$usd")${RESET}")
  la="$(floor_int "$(num_in "$cost" total_lines_added)")"
  lr="$(floor_int "$(num_in "$cost" total_lines_removed)")"
  if [ "${la:-0}" -gt 0 ] || [ "${lr:-0}" -gt 0 ]; then
    sess_parts+=("${C_ADD}+${la}${RESET} ${C_DEL}−${lr}${RESET}")
  fi
fi
sess_grp="$(grp "${sess_parts[@]+"${sess_parts[@]}"}")"

# --- forge lines, DELEGATED to the fragment (SEP=| , density passed) ---------
forge_out=""
[ -f "$HERE/forge-statusline.sh" ] && \
  forge_out="$(printf '%s' "$input" | FORGE_SL_SEP="$SEP" FORGE_SL_DENSITY="$DENSITY" bash "$HERE/forge-statusline.sh" 2>/dev/null || true)"

# --- Emit --------------------------------------------------------------------
if [ "$DENSITY" = "compact" ]; then
  # System groups + usage bars on ONE line; then the fragment's single group.
  line1="$(join_groups "$id_grp" "$loc_grp" "$usage_grp")"
  printf '%s\n' "$line1"
  [ -n "$forge_out" ] && printf '%s\n' "$forge_out"
  exit 0
fi

# full: L1 system+session, L2 usage bars, then the fragment's L3/L4
line1="$(join_groups "$id_grp" "$loc_grp" "$sess_grp")"
printf '%s\n' "$line1"
printf '%s\n' "$usage_grp"
[ -n "$forge_out" ] && printf '%s\n' "$forge_out"
exit 0
