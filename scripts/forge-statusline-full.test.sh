#!/usr/bin/env bash
# Fixture-based tests for forge-statusline-full.sh (the "merge" mode / method 2
# unified script — daleseo-style system info + forge progress in one command;
# see .forge/adr/0029-fg-statusline-combined-daleseo-dual-mode.md).
#
# Layout it must emit (each line independent, graceful omission per field):
#   Line 1: <model> · <effort> · <dir> · ⎇ <branch [+staged] [!modified] [?untracked]>
#   Line 2: Ctx <bar> N% [· 5h <bar> N% (~H)] [· 7d <bar> N% (~H)] [· ⏱ (D)]
#   Line 3: ⚒ <slug> · <ask→run→learn→done pipeline>[ · <flag>]   (delegated to the fragment)
#   Line 4: 📋 N queued · 📝 M awaiting retro                     (delegated to the fragment)
# System lines (1,2) always render (system info is independent of forge state);
# the forge lines (3,4) are omitted when forge is idle. The ⏱ segment renders
# cost.total_duration_ms (session elapsed, humanized) and is omitted when absent.
#
# The forge part (Line 3/4) is produced by DELEGATING to forge-statusline.sh with
# its default '⚒ ' prefix — so the stage-gating logic is reused, never
# re-implemented here (drift guarded by that reuse + forge-statusline.parity.test.sh).
#
# ANSI codes are stripped before comparison — exact colors are a live-tuned
# implementation detail (ADR-0017 2026-07-02 amendment), so threshold *colors*
# are not asserted; the pct text and bar fill (which encode the same info) are.
# Time is pinned via FORGE_SL_NOW so "(~…)" humanization is deterministic.
#
# Run:  bash scripts/forge-statusline-full.test.sh
#       FGSL_FULL_IMPL=scripts/forge-statusline-full.js bash scripts/forge-statusline-full.test.sh
# Exit: 0 if all pass, 1 otherwise.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="${FGSL_FULL_IMPL:-$HERE/forge-statusline-full.sh}"
case "$IMPL" in /*) : ;; *) IMPL="$(cd "$(dirname "$IMPL")" && pwd)/$(basename "$IMPL")" ;; esac  # run_full cd's into the fixture, so a relative FGSL_FULL_IMPL must be absolutized
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
R_24H=$((NOW + 86400))         # exactly +24h -> stays "24h 0m" (boundary: > 86400 only)
R_4D4H=$((NOW + 360000))       # +4d 4h -> "4d 4h"

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
  "Opus 4.8 · high · myproj" \
  "Ctx $B45 45% · 5h $B30 30% (~30m) · 7d $B60 60% (~17h 20m)" \
  "⚒ active-a · ✔ ask → ✔ run → ● learn → ○ done · ✓")"
assert "all-fields+active-yes" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (b) rate_limits absent (non-subscriber) + forge idle -> Usage/Weekly omitted, system stays
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"effort\":{\"level\":\"high\"},\"context_window\":{\"used_percentage\":45}}"
exp="$(printf '%s\n%s' "Opus 4.8 · high · myproj" "Ctx $B45 45%")"
assert "no-rate-limits+idle" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (c) five_hour present, seven_day absent + no model -> Line1 = dir only, Weekly omitted
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":45},\"rate_limits\":{\"five_hour\":{\"used_percentage\":30,\"resets_at\":$R_30M}}}"
exp="$(printf '%s\n%s' "myproj" "Ctx $B45 45% · 5h $B30 30% (~30m)")"
assert "five-only+no-model" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (d+e) effort absent + context 0 (explicit) -> "Sonnet 5 · myproj" / "Ctx ░… 0%"
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Sonnet 5\"},\"context_window\":{\"used_percentage\":0}}"
exp="$(printf '%s\n%s' "Sonnet 5 · myproj" "Ctx $B0 0%")"
assert "no-effort+context-0" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (e2) context used_percentage null -> 0 fallback
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":null}}"
exp="$(printf '%s\n%s' "myproj" "Ctx $B0 0%")"
assert "context-null-to-0" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (e3) context_window key entirely absent -> 0 fallback, system line still renders
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"}}"
exp="$(printf '%s\n%s' "Opus 4.8 · myproj" "Ctx $B0 0%")"
assert "context-missing-to-0" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (f) full system + forge idle (empty .forge) -> only the 2 system lines, no Line 3/4
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge/backlog" "$wd/.forge/executed"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"effort\":{\"level\":\"max\"},\"context_window\":{\"used_percentage\":45}}"
exp="$(printf '%s\n%s' "Opus 4.8 · max · myproj" "Ctx $B45 45%")"
assert "forge-idle-system-stays" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (g) forge active states — delegated to the fragment (default '⚒ ' prefix).
#     System JSON minimal (cwd only) -> Line1=dir, Line2=Context 0%.
minsys() { printf '{"cwd":"%s"}' "$1"; }

# g1: plan-only -> run current, no flag
t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: t -->"
exp="$(printf '%s\n%s\n%s' "myproj" "Ctx $B0 0%" "⚒ t · ✔ ask → ● run → ○ learn → ○ done")"
assert "forge-plan-only" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

# g2: run + verified pending -> run current, ⏳
t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: t -->"; write "$wd/.forge/run.md" "r"
printf 'verified: pending\n' > "$wd/.forge/STATUS.md"
exp="$(printf '%s\n%s\n%s' "myproj" "Ctx $B0 0%" "⚒ t · ✔ ask → ● run → ○ learn → ○ done · ⏳")"
assert "forge-verified-pending" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

# g3: run + verified failed -> run current, ✗
t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: t -->"; write "$wd/.forge/run.md" "r"
printf 'verified: failed (broke)\n' > "$wd/.forge/STATUS.md"
exp="$(printf '%s\n%s\n%s' "myproj" "Ctx $B0 0%" "⚒ t · ✔ ask → ● run → ○ learn → ○ done · ✗")"
assert "forge-verified-failed" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

# g4: run + verified skipped -> learn current, no flag
t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: t -->"; write "$wd/.forge/run.md" "r"
printf 'verified: skipped (docs)\n' > "$wd/.forge/STATUS.md"
exp="$(printf '%s\n%s\n%s' "myproj" "Ctx $B0 0%" "⚒ t · ✔ ask → ✔ run → ● learn → ○ done")"
assert "forge-verified-skipped" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

# (h) forge active + backlog + executed -> Line 4 present
t=$(mktmp); wd="$t/myproj"
write "$wd/.forge/plan.md" "<!-- forge-slug: active-h -->"
write "$wd/.forge/backlog/x.md" "<!-- forge-slug: x -->"
mkdir -p "$wd/.forge/executed/foo"; printf 'status: executed\n' > "$wd/.forge/executed/foo/STATUS.md"
exp="$(printf '%s\n%s\n%s\n%s' "myproj" "Ctx $B0 0%" \
  "⚒ active-h · ✔ ask → ● run → ○ learn → ○ done" \
  "📋 1 queued · 📝 1 awaiting retro")"
assert "forge-active+backlog+executed" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

# (i) resets_at humanize edges: past -> 0m, exactly 60min -> 1h 0m
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":0},\"rate_limits\":{\"five_hour\":{\"used_percentage\":0,\"resets_at\":$R_PAST},\"seven_day\":{\"used_percentage\":0,\"resets_at\":$R_60M}}}"
exp="$(printf '%s\n%s' "myproj" "Ctx $B0 0% · 5h $B0 0% (~0m) · 7d $B0 0% (~1h 0m)")"
assert "humanize-edges" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (i2) humanize >24h: exactly 24h stays "24h 0m" (boundary), beyond -> "Nd Nh"
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":0},\"rate_limits\":{\"five_hour\":{\"used_percentage\":0,\"resets_at\":$R_24H},\"seven_day\":{\"used_percentage\":0,\"resets_at\":$R_4D4H}}}"
exp="$(printf '%s\n%s' "myproj" "Ctx $B0 0% · 5h $B0 0% (~24h 0m) · 7d $B0 0% (~4d 4h)")"
assert "humanize-over-24h" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (j1) threshold boundary 69/70 -> bars 7/7 (color stripped; assert bar+% text)
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":69},\"rate_limits\":{\"five_hour\":{\"used_percentage\":70,\"resets_at\":$R_30M}}}"
exp="$(printf '%s\n%s' "myproj" "Ctx $B69 69% · 5h $B70 70% (~30m)")"
assert "boundary-69-70" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (j2) threshold boundary 89/90 + 100 -> bars 9/9/10
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":89},\"rate_limits\":{\"five_hour\":{\"used_percentage\":90,\"resets_at\":$R_30M},\"seven_day\":{\"used_percentage\":100,\"resets_at\":$R_60M}}}"
exp="$(printf '%s\n%s' "myproj" "Ctx $B89 89% · 5h $B90 90% (~30m) · 7d $B100 100% (~1h 0m)")"
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
  exp="$(printf '%s\n%s' "Opus 4.8 · gitproj · ⎇ test-branch +1 !1 ?1" "Ctx $B0 0%")"
  assert "git-status-counts" "$exp" "$(run_full "$wd" "$json")"
  rm -rf "$t"

  # (k2) clean git repo -> branch only, no counts
  t=$(mktmp); wd="$t/cleanproj"; mkdir -p "$wd"
  ( cd "$wd" && git init -q -b main && git config user.email t@t && git config user.name t \
      && printf 'a\n' > f.txt && git add f.txt && git commit -q -m init ) 2>/dev/null
  json="{\"cwd\":\"$wd\"}"
  exp="$(printf '%s\n%s' "cleanproj · ⎇ main" "Ctx $B0 0%")"
  assert "git-clean-branch-only" "$exp" "$(run_full "$wd" "$json")"
  rm -rf "$t"

  # (k3) ahead/behind vs upstream — a local bare repo stands in as the remote.
  # Display contract (plan task 71): "⎇ main ↑N ↓N +s !m ?u" — ↑/↓ sit after the
  # branch name and BEFORE the worktree counts; each is omitted when 0, and both
  # are omitted entirely when there is no upstream (cases k/k2 above stay as the
  # no-upstream guards). Progressive asserts on one repo:
  t=$(mktmp); wd="$t/gitproj"; bare="$t/remote.git"; mkdir -p "$wd"
  git init -q --bare "$bare" 2>/dev/null
  ( cd "$wd" && git init -q -b main && git config user.email t@t && git config user.name t \
      && git commit -q --allow-empty -m A \
      && git remote add origin "$bare" && git push -q -u origin main ) 2>/dev/null
  json="{\"cwd\":\"$wd\"}"
  # upstream present but ahead 0 / behind 0 -> both omitted (same shape as clean)
  exp="$(printf '%s\n%s' "gitproj · ⎇ main" "Ctx $B0 0%")"
  assert "git-upstream-zero-omitted" "$exp" "$(run_full "$wd" "$json")"
  # advance origin/main past local main via a side branch -> behind 1, ahead 0
  ( cd "$wd" && git checkout -q -b side && git commit -q --allow-empty -m D \
      && git push -q origin side:main && git checkout -q main ) 2>/dev/null
  exp="$(printf '%s\n%s' "gitproj · ⎇ main ↓1" "Ctx $B0 0%")"
  assert "git-behind-only" "$exp" "$(run_full "$wd" "$json")"
  # two local commits on main -> ahead 2, behind 1
  ( cd "$wd" && git commit -q --allow-empty -m B && git commit -q --allow-empty -m C ) 2>/dev/null
  exp="$(printf '%s\n%s' "gitproj · ⎇ main ↑2 ↓1" "Ctx $B0 0%")"
  assert "git-ahead-behind" "$exp" "$(run_full "$wd" "$json")"
  # ordering: ↑↓ between branch name and worktree counts
  printf 'u\n' > "$wd/untracked.txt"
  exp="$(printf '%s\n%s' "gitproj · ⎇ main ↑2 ↓1 ?1" "Ctx $B0 0%")"
  assert "git-ahead-behind-before-counts" "$exp" "$(run_full "$wd" "$json")"
  rm -rf "$t"
else
  printf '  skip git cases (git not found)\n'
fi

# (l) cwd from workspace.current_dir (no top-level cwd) still resolves dir + forge
t=$(mktmp); wd="$t/wsproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: ws -->"
json="{\"workspace\":{\"current_dir\":\"$wd\"},\"model\":{\"display_name\":\"Opus 4.8\"}}"
exp="$(printf '%s\n%s\n%s' "Opus 4.8 · wsproj" "Ctx $B0 0%" "⚒ ws · ✔ ask → ● run → ○ learn → ○ done")"
assert "workspace-current-dir" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (m1) cost.total_duration_ms present -> ⏱ segment appended at the very end of
#      Line 2 (after the usage segments). 4980000ms -> 4980s -> "1h 23m".
#      (All earlier cases carry no "cost" key — they double as omission cases.)
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":45},\"rate_limits\":{\"five_hour\":{\"used_percentage\":30,\"resets_at\":$R_30M}},\"cost\":{\"total_duration_ms\":4980000}}"
exp="$(printf '%s\n%s' "myproj" "Ctx $B45 45% · 5h $B30 30% (~30m) · ⏱ (1h 23m)")"
assert "duration-present" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (m2) cost.total_duration_ms explicit 0 -> shown as "⏱ (0m)" (0 is a value, not absence)
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":0},\"cost\":{\"total_duration_ms\":0}}"
exp="$(printf '%s\n%s' "myproj" "Ctx $B0 0% · ⏱ (0m)")"
assert "duration-zero" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

printf '\n%d passed, %d failed  (impl: %s)\n' "$pass" "$fail" "$(basename "$IMPL")"
[ "$fail" -eq 0 ]
