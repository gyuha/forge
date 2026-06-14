#!/usr/bin/env bash
# forge-statusline.sh — print a compact one-line forge progress fragment.
#
# A deliberately thin, display-only reader of forge state (see ADR-0017).
# It reads the resolved forge root (ADR-0011 branch resolution) relative to the
# current working directory and prints a single line, or nothing when idle.
# It does NOT reproduce fg-status's next-step priority machine — fg-status stays
# the single source of truth for "what to do next"; this only shows "where we are".
#
# Output (single segment, in precedence order):
#   ⚒ [🔁 rN/cap ] <slug>:<stage> [flag]   active slot   (stage run|learn)
#   ⚒ [🔁 rN/cap ] 📝 N awaiting retro       parked in executed/
#   ⚒ [🔁 rN/cap ] 📋 N queued               backlog only
#   ⚒ 🔁 rN/cap                              loop in flight, no work shown
#   (nothing)                                idle
#
# Dependencies: bash + git only. No JSON/jq parsing (reads files by path).

set -u

# --- cwd from session JSON (stdin) -------------------------------------------
# Claude Code feeds the statusLine command the session JSON on stdin. The host
# may run that command from a directory other than the project, so resolve the
# project dir from the JSON's "cwd" (or workspace.current_dir) and cd into it,
# making the .forge/ read below correct regardless of the shell's cwd. This is
# the one place the fragment parses JSON — kept jq-free (defensive sed), with a
# $PWD fallback so a no-stdin / no-cwd invocation still works (ADR-0017).
# Read stdin only when it is piped (not a tty), so an interactive run never blocks.
if [ ! -t 0 ]; then
  input="$(cat 2>/dev/null || true)"
  if [ -n "${input:-}" ]; then
    cwd="$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    [ -z "$cwd" ] && cwd="$(printf '%s' "$input" | sed -n 's/.*"current_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    [ -n "$cwd" ] && [ -d "$cwd" ] && cd "$cwd" 2>/dev/null || true
  fi
fi

# --- Resolve forge root (ADR-0011 / FORGE-ROOT.md) ---------------------------
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

default_branch="main"
if [ -f .forge/config.json ]; then
  d="$(sed -n 's/.*"defaultBranch"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .forge/config.json | head -1)"
  [ -n "$d" ] && default_branch="$d"
fi

# detached HEAD ("HEAD"), empty, or not a git repo → fall back to top-level .forge/
if [ -z "$branch" ] || [ "$branch" = "HEAD" ] || [ "$branch" = "$default_branch" ]; then
  root=".forge"
else
  root=".forge/branch/$branch"
fi

[ -d "$root" ] || exit 0

# --- Loop indicator (prefix) -------------------------------------------------
loop=""
if [ -f "$root/loop.md" ]; then
  rnd="$(sed -n 's/.*replan-round[[:space:]]*:[[:space:]]*\([0-9]\{1,\}\).*/\1/p' "$root/loop.md" | head -1)"
  cap="$(sed -n 's/.*replan-cap[[:space:]]*:[[:space:]]*\([0-9]\{1,\}\).*/\1/p' "$root/loop.md" | head -1)"
  if [ -n "$rnd" ] && [ -n "$cap" ]; then
    loop="🔁 r${rnd}/${cap} "
  fi
fi

# --- Determine the single segment (active > executed > backlog) ---------------
segment=""

if [ -f "$root/plan.md" ]; then
  slug="$(sed -n 's/.*forge-slug:[[:space:]]*\([^ ]*\)[[:space:]]*-->.*/\1/p' "$root/plan.md" | head -1)"
  [ -z "$slug" ] && slug="plan"
  if [ -f "$root/run.md" ]; then
    stage="learn"
    flag=""
    if [ -f "$root/STATUS.md" ]; then
      v="$(sed -n 's/^verified:[[:space:]]*\([A-Za-z/]\{1,\}\).*/\1/p' "$root/STATUS.md" | head -1)"
      case "$v" in
        yes)            flag=" ✓" ;;
        failed)         flag=" ✗" ;;
        pending|"")     flag=" ⏳" ;;
        skipped|n/a)    flag="" ;;
        *)              flag=" ⏳" ;;
      esac
    else
      flag=" ⏳"
    fi
    segment="${slug}:${stage}${flag}"
  else
    segment="${slug}:run"
  fi
elif [ -d "$root/executed" ] && [ -n "$(ls -A "$root/executed" 2>/dev/null)" ]; then
  n="$(find "$root/executed" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  segment="📝 ${n} awaiting retro"
elif [ -d "$root/backlog" ] && [ -n "$(ls -A "$root/backlog"/*.md 2>/dev/null)" ]; then
  n="$(ls -1 "$root/backlog"/*.md 2>/dev/null | wc -l | tr -d ' ')"
  segment="📋 ${n} queued"
fi

# --- Emit --------------------------------------------------------------------
if [ -z "$segment" ] && [ -z "$loop" ]; then
  exit 0
fi

# Trim a trailing space when only the loop prefix is present.
out="⚒ ${loop}${segment}"
out="${out%"${out##*[![:space:]]}"}"
printf '%s\n' "$out"
