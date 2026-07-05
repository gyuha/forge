#!/usr/bin/env bash
# Fixture-based tests for forge-statusline-full.sh (the "merge" mode / method 2
# unified script — daleseo-style system info + forge progress in one command;
# see .forge/adr/0029-fg-statusline-combined-daleseo-dual-mode.md).
#
# Layout it must emit (each line independent, graceful omission per field):
#   Line 1: <model> | <effort> | <dir> | <branch [+staged] [!modified] [?untracked]>
#   Line 2: Context <bar> N% [| Usage <bar> N% (resets in H)] [| Weekly <bar> N% (resets in H)]
#   Line 3: forge | <slug> | <ask→run→learn→done pipeline> | <flag>   (delegated to the fragment)
#   Line 4: 📋 N queued · 📝 M awaiting retro                         (delegated to the fragment)
# System lines (1,2) always render (system info is independent of forge state);
# the forge lines (3,4) are omitted when forge is idle.
#
# The forge part (Line 3/4) is produced by DELEGATING to forge-statusline.sh with
# FORGE_SL_PREFIX='forge | ' — so the stage-gating logic is reused, never
# re-implemented here (drift guarded by that reuse + forge-statusline.parity.test.sh).
#
# ANSI codes are stripped before comparison — exact colors are a live-tuned
# implementation detail (ADR-0017 2026-07-02 amendment), so threshold *colors*
# are not asserted; the pct text and bar fill (which encode the same info) are.
# Time is pinned via FORGE_SL_NOW so "resets in …" humanization is deterministic.
#
# Run:  bash scripts/forge-statusline-full.test.sh
#       FGSL_FULL_IMPL=scripts/forge-statusline-full.js bash scripts/forge-statusline-full.test.sh
# Exit: 0 if all pass, 1 otherwise.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="${FGSL_FULL_IMPL:-$HERE/forge-statusline-full.sh}"
FRAGMENT="$HERE/forge-statusline.sh"   # (existence sanity only; the impl finds its own)

pass=0
fail=0

assert() { # <name> <expected> <actual>
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf '  FAIL %s\n       expected: [%s]\n       actual:   [%s]\n' "$1" "$2" "$3"
  fi
}

mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgslfull.XXXXXX"; }
strip_ansi() { sed -E $'s/\x1b\\[[0-9;]*m//g'; }
write() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }

NOW=1000000000                 # pinned clock for humanize
R_30M=$((NOW + 1800))          # +30m
R_17H20M=$((NOW + 62400))      # +17h 20m
R_60M=$((NOW + 3600))          # +1h 0m
R_PAST=$((NOW - 100))          # already elapsed -> 0m

# run_full <cwd> <json> [now]  -> stdout, ANSI stripped (exact, no trailing strip)
run_full() {
  local wd="$1" json="$2" now="${3:-$NOW}"
  case "$IMPL" in
    *.js) ( cd "$wd" && printf '%s' "$json" | FORGE_SL_NOW="$now" node "$IMPL" ) ;;
    *)    ( cd "$wd" && printf '%s' "$json" | FORGE_SL_NOW="$now" bash "$IMPL" ) ;;
  esac | strip_ansi
}

# Bars (filled = clamp((pctInt+5)/10, 0..10)):
B0='░░░░░░░░░░'    # 0%
B30='███░░░░░░░'   # 30%
B45='█████░░░░░'   # 45%
B60='██████░░░░'   # 60%
B69='███████░░░'   # 69%  (round to 7)
B70='███████░░░'   # 70%  (round to 7)
B89='█████████░'   # 89%  (round to 9)
B90='█████████░'   # 90%  (round to 9)
B100='██████████'  # 100%

# ---------------------------------------------------------------------------
# (a) all fields present + forge active (verified yes) -> 3 lines
t=$(mktmp); wd="$t/myproj"
write "$wd/.forge/plan.md" "<!-- forge-slug: active-a -->"
write "$wd/.forge/run.md" "run"
printf 'verified: yes (x)\n' > "$wd/.forge/STATUS.md"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"effort\":{\"level\":\"high\"},\"context_window\":{\"used_percentage\":45,\"context_window_size\":200000},\"rate_limits\":{\"five_hour\":{\"used_percentage\":30,\"resets_at\":$R_30M},\"seven_day\":{\"used_percentage\":60,\"resets_at\":$R_17H20M}}}"
exp="$(printf '%s\n%s\n%s' \
  "Opus 4.8 | high | myproj" \
  "Context $B45 45% | Usage $B30 30% (resets in 30m) | Weekly $B60 60% (resets in 17h 20m)" \
  "forge | active-a | ✔ ask → ✔ run → ● learn → ○ done | ✓")"
assert "all-fields+active-yes" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (b) rate_limits absent (non-subscriber) + forge idle -> Usage/Weekly omitted, system stays
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"effort\":{\"level\":\"high\"},\"context_window\":{\"used_percentage\":45}}"
exp="$(printf '%s\n%s' "Opus 4.8 | high | myproj" "Context $B45 45%")"
assert "no-rate-limits+idle" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (c) five_hour present, seven_day absent + no model -> Line1 = dir only, Weekly omitted
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":45},\"rate_limits\":{\"five_hour\":{\"used_percentage\":30,\"resets_at\":$R_30M}}}"
exp="$(printf '%s\n%s' "myproj" "Context $B45 45% | Usage $B30 30% (resets in 30m)")"
assert "five-only+no-model" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (d+e) effort absent + context 0 (explicit) -> "Sonnet 5 | myproj" / "Context ░… 0%"
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Sonnet 5\"},\"context_window\":{\"used_percentage\":0}}"
exp="$(printf '%s\n%s' "Sonnet 5 | myproj" "Context $B0 0%")"
assert "no-effort+context-0" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (e2) context used_percentage null -> 0 fallback
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":null}}"
exp="$(printf '%s\n%s' "myproj" "Context $B0 0%")"
assert "context-null-to-0" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (e3) context_window key entirely absent -> 0 fallback, system line still renders
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"}}"
exp="$(printf '%s\n%s' "Opus 4.8 | myproj" "Context $B0 0%")"
assert "context-missing-to-0" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (f) full system + forge idle (empty .forge) -> only the 2 system lines, no Line 3/4
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge/backlog" "$wd/.forge/executed"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"effort\":{\"level\":\"max\"},\"context_window\":{\"used_percentage\":45}}"
exp="$(printf '%s\n%s' "Opus 4.8 | max | myproj" "Context $B45 45%")"
assert "forge-idle-system-stays" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (g) forge active states — delegated to the fragment, prefixed 'forge | '.
#     System JSON minimal (cwd only) -> Line1=dir, Line2=Context 0%.
minsys() { printf '{"cwd":"%s"}' "$1"; }

# g1: plan-only -> run current, no flag
t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: t -->"
exp="$(printf '%s\n%s\n%s' "myproj" "Context $B0 0%" "forge | t | ✔ ask → ● run → ○ learn → ○ done |")"
assert "forge-plan-only" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

# g2: run + verified pending -> run current, ⏳
t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: t -->"; write "$wd/.forge/run.md" "r"
printf 'verified: pending\n' > "$wd/.forge/STATUS.md"
exp="$(printf '%s\n%s\n%s' "myproj" "Context $B0 0%" "forge | t | ✔ ask → ● run → ○ learn → ○ done | ⏳")"
assert "forge-verified-pending" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

# g3: run + verified failed -> run current, ✗
t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: t -->"; write "$wd/.forge/run.md" "r"
printf 'verified: failed (broke)\n' > "$wd/.forge/STATUS.md"
exp="$(printf '%s\n%s\n%s' "myproj" "Context $B0 0%" "forge | t | ✔ ask → ● run → ○ learn → ○ done | ✗")"
assert "forge-verified-failed" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

# g4: run + verified skipped -> learn current, no flag
t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: t -->"; write "$wd/.forge/run.md" "r"
printf 'verified: skipped (docs)\n' > "$wd/.forge/STATUS.md"
exp="$(printf '%s\n%s\n%s' "myproj" "Context $B0 0%" "forge | t | ✔ ask → ✔ run → ● learn → ○ done |")"
assert "forge-verified-skipped" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

# (h) forge active + backlog + executed -> Line 4 present
t=$(mktmp); wd="$t/myproj"
write "$wd/.forge/plan.md" "<!-- forge-slug: active-h -->"
write "$wd/.forge/backlog/x.md" "<!-- forge-slug: x -->"
mkdir -p "$wd/.forge/executed/foo"; printf 'status: executed\n' > "$wd/.forge/executed/foo/STATUS.md"
exp="$(printf '%s\n%s\n%s\n%s' "myproj" "Context $B0 0%" \
  "forge | active-h | ✔ ask → ● run → ○ learn → ○ done |" \
  "📋 1 queued · 📝 1 awaiting retro")"
assert "forge-active+backlog+executed" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

# (i) resets_at humanize edges: past -> 0m, exactly 60min -> 1h 0m
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":0},\"rate_limits\":{\"five_hour\":{\"used_percentage\":0,\"resets_at\":$R_PAST},\"seven_day\":{\"used_percentage\":0,\"resets_at\":$R_60M}}}"
exp="$(printf '%s\n%s' "myproj" "Context $B0 0% | Usage $B0 0% (resets in 0m) | Weekly $B0 0% (resets in 1h 0m)")"
assert "humanize-edges" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (j1) threshold boundary 69/70 -> bars 7/7 (color stripped; assert bar+% text)
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":69},\"rate_limits\":{\"five_hour\":{\"used_percentage\":70,\"resets_at\":$R_30M}}}"
exp="$(printf '%s\n%s' "myproj" "Context $B69 69% | Usage $B70 70% (resets in 30m)")"
assert "boundary-69-70" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (j2) threshold boundary 89/90 + 100 -> bars 9/9/10
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":89},\"rate_limits\":{\"five_hour\":{\"used_percentage\":90,\"resets_at\":$R_30M},\"seven_day\":{\"used_percentage\":100,\"resets_at\":$R_60M}}}"
exp="$(printf '%s\n%s' "myproj" "Context $B89 89% | Usage $B90 90% (resets in 30m) | Weekly $B100 100% (resets in 1h 0m)")"
assert "boundary-89-90-100" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (k) git status rendering: branch + staged/modified/untracked counts
if command -v git >/dev/null 2>&1; then
  t=$(mktmp); wd="$t/gitproj"; mkdir -p "$wd"
  ( cd "$wd" && git init -q -b test-branch && git config user.email t@t && git config user.name t \
      && printf 'a\n' > tracked.txt && git add tracked.txt && git commit -q -m init \
      && printf 'b\n' >> tracked.txt \
      && printf 'x\n' > staged.txt && git add staged.txt \
      && printf 'y\n' > untracked.txt ) 2>/dev/null
  json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"}}"
  exp="$(printf '%s\n%s' "Opus 4.8 | gitproj | test-branch +1 !1 ?1" "Context $B0 0%")"
  assert "git-status-counts" "$exp" "$(run_full "$wd" "$json")"
  rm -rf "$t"

  # (k2) clean git repo -> branch only, no counts
  t=$(mktmp); wd="$t/cleanproj"; mkdir -p "$wd"
  ( cd "$wd" && git init -q -b main && git config user.email t@t && git config user.name t \
      && printf 'a\n' > f.txt && git add f.txt && git commit -q -m init ) 2>/dev/null
  json="{\"cwd\":\"$wd\"}"
  exp="$(printf '%s\n%s' "cleanproj | main" "Context $B0 0%")"
  assert "git-clean-branch-only" "$exp" "$(run_full "$wd" "$json")"
  rm -rf "$t"
else
  printf '  skip git cases (git not found)\n'
fi

# (l) cwd from workspace.current_dir (no top-level cwd) still resolves dir + forge
t=$(mktmp); wd="$t/wsproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: ws -->"
json="{\"workspace\":{\"current_dir\":\"$wd\"},\"model\":{\"display_name\":\"Opus 4.8\"}}"
exp="$(printf '%s\n%s\n%s' "Opus 4.8 | wsproj" "Context $B0 0%" "forge | ws | ✔ ask → ● run → ○ learn → ○ done |")"
assert "workspace-current-dir" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

printf '\n%d passed, %d failed  (impl: %s)\n' "$pass" "$fail" "$(basename "$IMPL")"
[ "$fail" -eq 0 ]
