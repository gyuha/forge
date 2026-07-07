#!/usr/bin/env bash
# forge-statusline-full.sh — "merge" mode (method 2, ADR-0029).
#
# Renders daleseo-style SYSTEM info AND forge progress in a single command that
# forge owns. This is the alternative to method 1 (the wrapper, which appends the
# thin forge fragment below a third-party statusline). See fg-statusline/SKILL.md.
#
# Layout (each line independent; a field renders only when present):
#   Line 1: <model> | <effort> | <dir> | <branch [+staged] [!modified] [?untracked]>
#   Line 2: Context <bar> N% [| Usage <bar> N% (resets in H)] [| Weekly <bar> N% (resets in H)]
#   Line 3: forge | <slug> | <ask→run→learn→done> | <flag>   (DELEGATED to forge-statusline.sh)
#   Line 4: 📋 N queued · 📝 M awaiting retro                  (DELEGATED to forge-statusline.sh)
# The two SYSTEM lines always render (system info is independent of forge). The
# forge lines are the fragment's own output with FORGE_SL_PREFIX='forge | ', so
# the stage-gating is REUSED, never re-implemented (drift guarded by the reuse +
# forge-statusline-full.parity.test.sh / forge-statusline.parity.test.sh).
#
# jq-free: system JSON is parsed with defensive sed. used_percentage appears in
# THREE places (context_window / rate_limits.five_hour / seven_day) and resets_at
# in TWO, so a first-match grab is WRONG — each leaf is read from its PARENT
# object's flat body (json_obj), the node twin uses JSON.parse (ADR-0022).
#
# Bars: 10 cells, filled = round(pct/10) via integer (pct+5)/10 clamped 0..10.
# Colors are threshold-based (<70 green / 70–89 yellow / ≥90 red) but live-tuned
# and stripped in tests (ADR-0017). Time via FORGE_SL_NOW (epoch s) or `date +%s`.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- colors (live-tuned; stripped in tests) ----------------------------------
C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'
C_MODEL=$'\033[1;36m'; C_DIR=$'\033[36m'; C_GIT=$'\033[35m'; RESET=$'\033[0m'
eff_color() {
  case "$1" in
    low) printf '%s' "$C_GREEN" ;; medium) printf '%s' "$C_DIR" ;;
    high) printf '%s' "$C_YELLOW" ;; max) printf '%s' "$C_RED" ;;
    *) printf '%s' "$RESET" ;;
  esac
}

# --- read session JSON on stdin (only when piped) ----------------------------
input=""
[ ! -t 0 ] && input="$(cat 2>/dev/null || true)"
oneline="$(printf '%s' "$input" | tr '\n' ' ')"

# json_obj <key>: flat inner body of "key":{ ... } (parent-anchor for nested leaves)
json_obj() { printf '%s' "$oneline" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*{\\([^{}]*\\)}.*/\\1/p" | head -1; }
str_in() { printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -1; }
num_in() { printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\\([0-9][0-9.]*\\).*/\\1/p" | head -1; }

floor_int() { local r="${1%%.*}"; case "$r" in ""|*[!0-9]*) printf '0' ;; *) printf '%s' "$r" ;; esac; }
join_bar() { local out="" first=1 p; for p in "$@"; do if [ "$first" = 1 ]; then out="$p"; first=0; else out="$out | $p"; fi; done; printf '%s' "$out"; }

bar() { # <pctInt> -> "<colored 10-cell bar> N%"
  local p="$1" filled empty i out="" col
  filled=$(( (p + 5) / 10 )); [ "$filled" -gt 10 ] && filled=10; [ "$filled" -lt 0 ] && filled=0
  empty=$(( 10 - filled ))
  if [ "$p" -ge 90 ]; then col="$C_RED"; elif [ "$p" -ge 70 ]; then col="$C_YELLOW"; else col="$C_GREEN"; fi
  i=0; while [ "$i" -lt "$filled" ]; do out="${out}█"; i=$((i + 1)); done
  i=0; while [ "$i" -lt "$empty" ]; do out="${out}░"; i=$((i + 1)); done
  printf '%s%s%s %s%%' "$col" "$out" "$RESET" "$p"
}

humanize() { # <seconds> -> "Nm" | "Hh Mm" | "Dd Hh"
  local s="$1"; [ "$s" -lt 0 ] && s=0
  if [ "$s" -gt 86400 ]; then printf '%dd %dh' $(( s / 86400 )) $(( (s % 86400) / 3600 )); return; fi
  local m=$(( s / 60 ))
  if [ "$m" -lt 60 ]; then printf '%dm' "$m"; else printf '%dh %dm' $(( m / 60 )) $(( m % 60 )); fi
}

now="${FORGE_SL_NOW:-$(date +%s 2>/dev/null || echo 0)}"

# --- cwd resolution (same as the fragment) -----------------------------------
if [ -n "$oneline" ]; then
  cwd="$(printf '%s' "$oneline" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  [ -z "$cwd" ] && cwd="$(printf '%s' "$oneline" | sed -n 's/.*"current_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  [ -n "$cwd" ] && cwd="$(printf '%s' "$cwd" | sed 's/\\\\/\\/g')"
  [ -n "$cwd" ] && [ -d "$cwd" ] && cd "$cwd" 2>/dev/null || true
fi

# --- Line 1: model | effort | dir | git --------------------------------------
model="$(str_in "$(json_obj model)" display_name)"
effort="$(str_in "$(json_obj effort)" level)"
dir="$(basename "$(pwd)")"

seg1=()
[ -n "$model" ] && seg1+=("${C_MODEL}${model}${RESET}")
[ -n "$effort" ] && seg1+=("$(eff_color "$effort")${effort}${RESET}")
seg1+=("${C_DIR}${dir}${RESET}")

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
  st="$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"
  md="$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')"
  ut="$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')"
  gitseg="$branch"
  [ "${st:-0}" -gt 0 ] && gitseg="$gitseg +$st"
  [ "${md:-0}" -gt 0 ] && gitseg="$gitseg !$md"
  [ "${ut:-0}" -gt 0 ] && gitseg="$gitseg ?$ut"
  seg1+=("${C_GIT}${gitseg}${RESET}")
fi
line1="$(join_bar "${seg1[@]}")"

# --- Line 2: Context | Usage | Weekly ----------------------------------------
ctx="$(floor_int "$(num_in "$(json_obj context_window)" used_percentage)")"
seg2=("Context $(bar "$ctx")")

five="$(json_obj five_hour)"
if [ -n "$five" ]; then
  fp="$(floor_int "$(num_in "$five" used_percentage)")"
  fr="$(floor_int "$(num_in "$five" resets_at)")"
  seg2+=("Usage $(bar "$fp") (resets in $(humanize $(( fr - now )) ))")
fi

seven="$(json_obj seven_day)"
if [ -n "$seven" ]; then
  sp="$(floor_int "$(num_in "$seven" used_percentage)")"
  sr="$(floor_int "$(num_in "$seven" resets_at)")"
  seg2+=("Weekly $(bar "$sp") (resets in $(humanize $(( sr - now )) ))")
fi
line2="$(join_bar "${seg2[@]}")"

# --- Line 3/4: forge progress, DELEGATED to the fragment (prefix 'forge | ') --
forge_out=""
[ -f "$HERE/forge-statusline.sh" ] && \
  forge_out="$(printf '%s' "$input" | FORGE_SL_PREFIX='forge | ' bash "$HERE/forge-statusline.sh" 2>/dev/null || true)"

# --- Emit: system lines always; forge lines only when non-empty --------------
printf '%s\n' "$line1"
printf '%s\n' "$line2"
[ -n "$forge_out" ] && printf '%s\n' "$forge_out"
exit 0
