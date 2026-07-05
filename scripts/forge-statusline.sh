#!/usr/bin/env bash
# forge-statusline.sh — print forge progress fragment line(s).
#
# A deliberately thin, display-only reader of forge state (see ADR-0017,
# amended 2026-07-02). It reads the resolved forge root (ADR-0011 branch
# resolution) relative to the current working directory and prints up to two
# lines, or nothing when idle. It does NOT reproduce fg-status's next-step
# priority machine — fg-status stays the single source of truth for "what to
# do next"; this only shows "where we are".
#
# Output (each line shown independently — NOT precedence-hidden):
#   Line 1 (active slot present):
#     ⚒ [🔁 rN/cap ]<slug> | ✔ ask → ● run → ○ learn → ○ done | [flag]
#   Line 1 (no active slot, but fg-ask is mid-grilling — ask.md marker present):
#     ⚒ <working-slug> | ● ask → ○ run → ○ learn → ○ done
#   Line 1 fallback (no active slot, no ask.md, but a goal loop is in flight):
#     🔁 rN/cap
#   Line 2 (backlog and/or executed non-empty, independent of line 1):
#     📋 N queued · 📝 M awaiting retro   (either half omitted when zero)
#
# The ask/run/learn/done pipeline always renders all four stages (the fourth,
# "done", completes the visual picture of the full forge loop): stages before
# the current one show ✔ (done, green), the current stage shows ● (bold/
# cyan), stages after show ○ (dim). The current stage is gated, not just
# file-existence-based (ADR-0017, 3rd amendment):
#   no plan.md, no ask.md                  -> line 1 empty (or loop-only fallback)
#   no plan.md, ask.md present             -> ask is current (fg-ask grilling; plan.md
#                                              wins over ask.md if both exist)
#   plan.md present, no run.md             -> run is current (only fg-run promotes into
#                                              the active slot, so this is fg-run's
#                                              territory, not fg-ask's)
#   run.md + verified: pending/failed      -> run is current (fg-learn's own retro gate
#                                              refuses these; it is still fg-run's territory)
#   run.md + verified: yes/skipped/n/a     -> learn is current (retro gate passed)
# "done" never becomes current here — a sealed task leaves .forge/plan.md
# entirely and stops appearing in line 1 (see fg-done); it is shown purely to
# complete the visual picture of the full 4-stage loop.
#
# Dependencies: bash + git only. No JSON/jq parsing (reads files by path).
#
# FORGE_SL_PREFIX (env, optional): the line-1 prefix, default "⚒ ". The "merge"
# mode unified script (forge-statusline-full.sh, ADR-0029) sets it to "forge | "
# so it can REUSE this fragment's stage-gating for its forge line instead of
# re-implementing it. Unset in method-1 (wrap/sole) usage -> byte-identical to before.

set -u

# --- ANSI helpers -------------------------------------------------------------
DOT_DONE=$'\033[32m'      # green — completed stage
DOT_CUR=$'\033[1;36m'     # bold cyan — current stage
DOT_UPCOMING=$'\033[2m'   # dim — upcoming stage
RESET=$'\033[0m'

# build_pipeline <stage: ask|run|learn> -> prints "✔ ask → ● run → ○ learn → ○ done" (colored)
# "done" is always upcoming here — the active slot never sits at "done" (a sealed
# task moves to .forge/done/ and stops appearing in line 1 entirely); it is shown
# purely to complete the visual picture of the full 4-stage loop.
build_pipeline() {
  local stage="$1" target=0 i=0 out="" seg w
  case "$stage" in
    ask) target=0 ;;
    run) target=1 ;;
    learn) target=2 ;;
  esac
  for w in ask run learn done; do
    if [ "$i" -lt "$target" ]; then
      seg="${DOT_DONE}✔ ${w}${RESET}"
    elif [ "$i" -eq "$target" ]; then
      seg="${DOT_CUR}● ${w}${RESET}"
    else
      seg="${DOT_UPCOMING}○ ${w}${RESET}"
    fi
    if [ -z "$out" ]; then out="$seg"; else out="${out} → ${seg}"; fi
    i=$((i + 1))
  done
  printf '%s' "$out"
}

# join_dot <part...> -> prints parts joined by " · "
join_dot() {
  local out="" first=1 p
  for p in "$@"; do
    if [ "$first" -eq 1 ]; then out="$p"; first=0; else out="${out} · ${p}"; fi
  done
  printf '%s' "$out"
}

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
    # Decode JSON's escaped backslashes (a Windows cwd "C:\\Users\\…" leaves "\\"
    # in the raw regex capture) so cd succeeds, matching the node twin's JSON.parse
    # (ADR-0022 review). Best-effort: handles the common "\\" → "\" path case.
    [ -n "$cwd" ] && cwd="$(printf '%s' "$cwd" | sed 's/\\\\/\\/g')"
    [ -n "$cwd" ] && [ -d "$cwd" ] && cd "$cwd" 2>/dev/null || true
  fi
fi

# --- Resolve forge root (ADR-0011 / FORGE-ROOT.md) ---------------------------
# Anchor to the git repo root (after the cwd cd above) so a session cwd in a
# subdirectory still finds repo-root state, and so this stays in parity with the
# node twin's resolveForgeRoot() (ADR-0022 review). Non-git → CWD-relative.
top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
prefix="${top:+$top/}"
cfg="${top:-.}/.forge/config.json"

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

default_branch="main"
if [ -f "$cfg" ]; then
  d="$(sed -n 's/.*"defaultBranch"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$cfg" | head -1)"
  [ -n "$d" ] && default_branch="$d"
fi

# detached HEAD ("HEAD"), empty, or not a git repo → fall back to top-level .forge/
if [ -z "$branch" ] || [ "$branch" = "HEAD" ] || [ "$branch" = "$default_branch" ]; then
  root="${prefix}.forge"
else
  root="${prefix}.forge/branch/$branch"
fi

[ -d "$root" ] || exit 0

# --- Loop indicator (rN/cap, without the 🔁 body until assembled below) -------
loop_rnd=""
loop_cap=""
if [ -f "$root/loop.md" ]; then
  loop_rnd="$(sed -n 's/.*replan-round[[:space:]]*:[[:space:]]*\([0-9]\{1,\}\).*/\1/p' "$root/loop.md" | head -1)"
  loop_cap="$(sed -n 's/.*replan-cap[[:space:]]*:[[:space:]]*\([0-9]\{1,\}\).*/\1/p' "$root/loop.md" | head -1)"
fi
loop_indicator=""
[ -n "$loop_rnd" ] && [ -n "$loop_cap" ] && loop_indicator="🔁 r${loop_rnd}/${loop_cap}"

# --- Line 1: active slot, or the loop-only fallback --------------------------
line1=""
if [ -f "$root/plan.md" ]; then
  slug="$(sed -n 's/.*forge-slug:[[:space:]]*\([^ ]*\)[[:space:]]*-->.*/\1/p' "$root/plan.md" | head -1)"
  [ -z "$slug" ] && slug="plan"
  if [ -f "$root/run.md" ]; then
    v=""
    [ -f "$root/STATUS.md" ] && v="$(sed -n 's/^verified:[[:space:]]*\([A-Za-z/]\{1,\}\).*/\1/p' "$root/STATUS.md" | head -1)"
    # verified not yet sealable (pending/failed/missing) -> still fg-run's territory
    # (fg-learn's own retro gate refuses these); sealable -> retro gate passed, learn is current.
    case "$v" in
      yes)            flag=" ✓"; stage="learn" ;;
      failed)         flag=" ✗"; stage="run" ;;
      pending|"")     flag=" ⏳"; stage="run" ;;
      skipped|n/a)    flag="";   stage="learn" ;;
      *)              flag=" ⏳"; stage="run" ;;
    esac
  else
    stage="run"
    flag=""
  fi
  pipeline="$(build_pipeline "$stage")"
  prefix_bit=""
  [ -n "$loop_indicator" ] && prefix_bit="${loop_indicator} "
  line1="${FORGE_SL_PREFIX:-⚒ }${prefix_bit}${slug} | ${pipeline} |${flag}"
elif [ -f "$root/ask.md" ]; then
  working_slug="$(sed -n 's/.*forge-ask:[[:space:]]*\([^ ]*\)[[:space:]]*-->.*/\1/p' "$root/ask.md" | head -1)"
  [ -z "$working_slug" ] && working_slug="ask"
  pipeline="$(build_pipeline "ask")"
  line1="${FORGE_SL_PREFIX:-⚒ }${working_slug} | ${pipeline} |"
elif [ -n "$loop_indicator" ]; then
  line1="$loop_indicator"
fi

# --- Line 2: pending summary (backlog + executed), independent of line 1 -----
queued_n=0
await_n=0
[ -d "$root/executed" ] && await_n="$(find "$root/executed" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
[ -d "$root/backlog" ] && queued_n="$(ls -1 "$root/backlog"/*.md 2>/dev/null | wc -l | tr -d ' ')"

line2=""
parts=()
[ "${queued_n:-0}" -gt 0 ] && parts+=("📋 ${queued_n} queued")
[ "${await_n:-0}" -gt 0 ] && parts+=("📝 ${await_n} awaiting retro")
[ "${#parts[@]}" -gt 0 ] && line2="$(join_dot "${parts[@]}")"

# --- Emit ----------------------------------------------------------------------
[ -n "$line1" ] && printf '%s\n' "$line1"
[ -n "$line2" ] && printf '%s\n' "$line2"
exit 0
