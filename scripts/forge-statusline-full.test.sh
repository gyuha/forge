#!/usr/bin/env bash
# Fixture-based tests for forge-statusline-full.sh (the "merge" mode / method 2
# unified script; ADR-0029). Grouped [ ... ] layout, " | " intra-group separators,
# density arg ("full" default / "compact").
#
# Layout (full):
#   L1: [<model> | <effort>] [<dir> | ⎇ <branch [↑N ↓N] [+s !m ?u]>] [⏱ (D) | $X.XX | +A −R]
#   L2: [<emoji> Context[/<size>] <bar> N% | 5h <bar> N% (~H) | 7d <bar> N% (~H)]
#   L3: [⚒ [#N ]<slug> | <pipeline>[ | <flag>]]                   (delegated)
#   L4: [📋 N queued | 📝 M awaiting retro[ | ♻️][ | 🧪]]          (delegated)
# System groups (L1/L2) always render; forge groups (L3/L4) omitted when idle.
# compact: system groups + usage-bars group on ONE line, then the fragment's
# single compact group; the session group (⏱/$/±lines) is dropped.
#
# ANSI stripped before comparison — colors/gradient are live-tuned (ADR-0017);
# the pct text + bar fill + emoji + labels carry the asserted info. Time pinned
# via FORGE_SL_NOW.
#
# Run:  bash scripts/forge-statusline-full.test.sh
#       FGSL_FULL_IMPL=scripts/forge-statusline-full.js bash scripts/forge-statusline-full.test.sh
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="${FGSL_FULL_IMPL:-$HERE/forge-statusline-full.sh}"
case "$IMPL" in /*) : ;; *) IMPL="$(cd "$(dirname "$IMPL")" && pwd)/$(basename "$IMPL")" ;; esac

pass=0
fail=0

assert() {
  if [ "$2" = "$3" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); printf '  FAIL %s\n       expected: [%s]\n       actual:   [%s]\n' "$1" "$2" "$3"; fi
}

mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgslfull.XXXXXX"; }
strip_ansi() { sed -E $'s/\x1b\\[[0-9;]*m//g'; }
write() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }

NOW=1000000000
R_30M=$((NOW + 1800)); R_17H20M=$((NOW + 62400)); R_60M=$((NOW + 3600))
R_PAST=$((NOW - 100)); R_24H=$((NOW + 86400)); R_4D4H=$((NOW + 360000))

# run_full <cwd> <json> [density]  -> stdout, ANSI stripped
run_full() {
  local wd="$1" json="$2" density="${3:-}"
  case "$IMPL" in
    *.js) ( cd "$wd" && printf '%s' "$json" | FORGE_SL_NOW="$NOW" node "$IMPL" $density ) ;;
    *)    ( cd "$wd" && printf '%s' "$json" | FORGE_SL_NOW="$NOW" bash "$IMPL" $density ) ;;
  esac | strip_ansi
}

B0='░░░░░░░░░░'; B30='███░░░░░░░'; B45='█████░░░░░'; B60='██████░░░░'
B69='███████░░░'; B70='███████░░░'; B89='█████████░'; B90='█████████░'; B100='██████████'

# (a) all fields present + forge active (verified yes), ctx size 200K -> 3 lines
t=$(mktmp); wd="$t/myproj"
write "$wd/.forge/plan.md" "<!-- forge-slug: active-a -->"; write "$wd/.forge/run.md" "run"
printf 'verified: yes (x)\n' > "$wd/.forge/STATUS.md"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"effort\":{\"level\":\"high\"},\"context_window\":{\"used_percentage\":45,\"context_window_size\":200000},\"rate_limits\":{\"five_hour\":{\"used_percentage\":30,\"resets_at\":$R_30M},\"seven_day\":{\"used_percentage\":60,\"resets_at\":$R_17H20M}}}"
exp="$(printf '%s\n%s\n%s' \
  "[Opus 4.8 | high] [myproj]" \
  "[⚡ Context/200K $B45 45% | 5h $B30 30% (~30m) | 7d $B60 60% (~17h 20m)]" \
  "[⚒ active-a | ✔ ask → ✔ run → ● learn → ○ done | ✓]")"
assert "all-fields+active-yes" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (b) rate_limits absent + forge idle -> 2 system lines
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"effort\":{\"level\":\"high\"},\"context_window\":{\"used_percentage\":45}}"
exp="$(printf '%s\n%s' "[Opus 4.8 | high] [myproj]" "[⚡ Context $B45 45%]")"
assert "no-rate-limits+idle" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (c) five_hour only + no model -> id group omitted, L1 = [dir]
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":45},\"rate_limits\":{\"five_hour\":{\"used_percentage\":30,\"resets_at\":$R_30M}}}"
exp="$(printf '%s\n%s' "[myproj]" "[⚡ Context $B45 45% | 5h $B30 30% (~30m)]")"
assert "five-only+no-model" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (d) effort absent + context 0 -> "[Sonnet 5] [myproj]" / "[🟢 Context …]"
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Sonnet 5\"},\"context_window\":{\"used_percentage\":0}}"
exp="$(printf '%s\n%s' "[Sonnet 5] [myproj]" "[🟢 Context $B0 0%]")"
assert "no-effort+context-0" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (e2) context used_percentage null -> 0
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":null}}"
exp="$(printf '%s\n%s' "[myproj]" "[🟢 Context $B0 0%]")"
assert "context-null-to-0" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (e3) context_window entirely absent -> 0
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"}}"
exp="$(printf '%s\n%s' "[Opus 4.8] [myproj]" "[🟢 Context $B0 0%]")"
assert "context-missing-to-0" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (e4) REAL schema: context_window carries a nested current_usage object -> still parses
#      (regression for the always-0% bug: the .sh flat-object parser must not choke on the nesting)
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"context_window\":{\"total_input_tokens\":90000,\"total_output_tokens\":5000,\"context_window_size\":200000,\"used_percentage\":45,\"remaining_percentage\":55,\"current_usage\":{\"input_tokens\":90000,\"output_tokens\":5000,\"cache_creation_input_tokens\":0,\"cache_read_input_tokens\":80000}}}"
exp="$(printf '%s\n%s' "[Opus 4.8] [myproj]" "[⚡ Context/200K $B45 45%]")"
assert "context-nested-current_usage" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (e5) nested current_usage placed FIRST (real Claude Code key order) -> must still read used_percentage
#      this is the order that actually broke it: a prefix-only parser reads 0% here, so parsing must be order-independent
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"context_window\":{\"current_usage\":{\"input_tokens\":90000,\"cache_read_input_tokens\":80000},\"context_window_size\":200000,\"used_percentage\":45,\"remaining_percentage\":55}}"
exp="$(printf '%s\n%s' "[Opus 4.8] [myproj]" "[⚡ Context/200K $B45 45%]")"
assert "context-nested-current_usage-first" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (f) full system + forge idle -> only the 2 system lines
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge/backlog" "$wd/.forge/executed"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"effort\":{\"level\":\"max\"},\"context_window\":{\"used_percentage\":45}}"
exp="$(printf '%s\n%s' "[Opus 4.8 | max] [myproj]" "[⚡ Context $B45 45%]")"
assert "forge-idle-system-stays" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (g) forge active states — delegated. Minimal system JSON (cwd only).
minsys() { printf '{"cwd":"%s"}' "$1"; }

t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: t -->"
exp="$(printf '%s\n%s\n%s' "[myproj]" "[🟢 Context $B0 0%]" "[⚒ t | ✔ ask → ● run → ○ learn → ○ done]")"
assert "forge-plan-only" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: t -->"; write "$wd/.forge/run.md" "r"
printf 'verified: pending\n' > "$wd/.forge/STATUS.md"
exp="$(printf '%s\n%s\n%s' "[myproj]" "[🟢 Context $B0 0%]" "[⚒ t | ✔ ask → ● run → ○ learn → ○ done | ⏳]")"
assert "forge-verified-pending" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: t -->"; write "$wd/.forge/run.md" "r"
printf 'verified: failed (broke)\n' > "$wd/.forge/STATUS.md"
exp="$(printf '%s\n%s\n%s' "[myproj]" "[🟢 Context $B0 0%]" "[⚒ t | ✔ ask → ● run → ○ learn → ○ done | ✗]")"
assert "forge-verified-failed" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: t -->"; write "$wd/.forge/run.md" "r"
printf 'verified: skipped (docs)\n' > "$wd/.forge/STATUS.md"
exp="$(printf '%s\n%s\n%s' "[myproj]" "[🟢 Context $B0 0%]" "[⚒ t | ✔ ask → ✔ run → ● learn → ○ done]")"
assert "forge-verified-skipped" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

# (h) forge active + backlog + executed -> L4 present
t=$(mktmp); wd="$t/myproj"
write "$wd/.forge/plan.md" "<!-- forge-slug: active-h -->"
write "$wd/.forge/backlog/x.md" "<!-- forge-slug: x -->"
mkdir -p "$wd/.forge/executed/foo"; printf 'status: executed\n' > "$wd/.forge/executed/foo/STATUS.md"
exp="$(printf '%s\n%s\n%s\n%s' "[myproj]" "[🟢 Context $B0 0%]" \
  "[⚒ active-h | ✔ ask → ● run → ○ learn → ○ done]" \
  "[📋 1 queued | 📝 1 awaiting retro]")"
assert "forge-active+backlog+executed" "$exp" "$(run_full "$wd" "$(minsys "$wd")")"
rm -rf "$t"

# (i) humanize edges: past -> 0m, exactly 60min -> 1h 0m
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":0},\"rate_limits\":{\"five_hour\":{\"used_percentage\":0,\"resets_at\":$R_PAST},\"seven_day\":{\"used_percentage\":0,\"resets_at\":$R_60M}}}"
exp="$(printf '%s\n%s' "[myproj]" "[🟢 Context $B0 0% | 5h $B0 0% (~0m) | 7d $B0 0% (~1h 0m)]")"
assert "humanize-edges" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (i2) humanize >24h
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":0},\"rate_limits\":{\"five_hour\":{\"used_percentage\":0,\"resets_at\":$R_24H},\"seven_day\":{\"used_percentage\":0,\"resets_at\":$R_4D4H}}}"
exp="$(printf '%s\n%s' "[myproj]" "[🟢 Context $B0 0% | 5h $B0 0% (~24h 0m) | 7d $B0 0% (~4d 4h)]")"
assert "humanize-over-24h" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (j1) boundary 69/70 -> bars 7/7, emoji ⚡ (69)
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":69},\"rate_limits\":{\"five_hour\":{\"used_percentage\":70,\"resets_at\":$R_30M}}}"
exp="$(printf '%s\n%s' "[myproj]" "[⚡ Context $B69 69% | 5h $B70 70% (~30m)]")"
assert "boundary-69-70" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (j2) boundary 89/90/100 -> bars 9/9/10, emoji 🔥 (89)
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":89},\"rate_limits\":{\"five_hour\":{\"used_percentage\":90,\"resets_at\":$R_30M},\"seven_day\":{\"used_percentage\":100,\"resets_at\":$R_60M}}}"
exp="$(printf '%s\n%s' "[myproj]" "[🔥 Context $B89 89% | 5h $B90 90% (~30m) | 7d $B100 100% (~1h 0m)]")"
assert "boundary-89-90-100" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (j3) emoji 🚨 at 90 (context)
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":90}}"
exp="$(printf '%s\n%s' "[myproj]" "[🚨 Context $B90 90%]")"
assert "emoji-crit-90" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (k) git status counts
if command -v git >/dev/null 2>&1; then
  t=$(mktmp); wd="$t/gitproj"; mkdir -p "$wd"
  ( cd "$wd" && git init -q -b test-branch && git config user.email t@t && git config user.name t \
      && printf 'a\n' > tracked.txt && git add tracked.txt && git commit -q -m init \
      && printf 'b\n' >> tracked.txt && printf 'x\n' > staged.txt && git add staged.txt \
      && printf 'y\n' > untracked.txt ) 2>/dev/null
  json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"}}"
  exp="$(printf '%s\n%s' "[Opus 4.8] [gitproj | ⎇ test-branch +1 !1 ?1]" "[🟢 Context $B0 0%]")"
  assert "git-status-counts" "$exp" "$(run_full "$wd" "$json")"
  rm -rf "$t"

  t=$(mktmp); wd="$t/cleanproj"; mkdir -p "$wd"
  ( cd "$wd" && git init -q -b main && git config user.email t@t && git config user.name t \
      && printf 'a\n' > f.txt && git add f.txt && git commit -q -m init ) 2>/dev/null
  json="{\"cwd\":\"$wd\"}"
  exp="$(printf '%s\n%s' "[cleanproj | ⎇ main]" "[🟢 Context $B0 0%]")"
  assert "git-clean-branch-only" "$exp" "$(run_full "$wd" "$json")"
  rm -rf "$t"

  t=$(mktmp); wd="$t/gitproj"; bare="$t/remote.git"; mkdir -p "$wd"
  git init -q --bare "$bare" 2>/dev/null
  ( cd "$wd" && git init -q -b main && git config user.email t@t && git config user.name t \
      && git commit -q --allow-empty -m A \
      && git remote add origin "$bare" && git push -q -u origin main ) 2>/dev/null
  json="{\"cwd\":\"$wd\"}"
  exp="$(printf '%s\n%s' "[gitproj | ⎇ main]" "[🟢 Context $B0 0%]")"
  assert "git-upstream-zero-omitted" "$exp" "$(run_full "$wd" "$json")"
  ( cd "$wd" && git checkout -q -b side && git commit -q --allow-empty -m D \
      && git push -q origin side:main && git checkout -q main ) 2>/dev/null
  exp="$(printf '%s\n%s' "[gitproj | ⎇ main ↓1]" "[🟢 Context $B0 0%]")"
  assert "git-behind-only" "$exp" "$(run_full "$wd" "$json")"
  ( cd "$wd" && git commit -q --allow-empty -m B && git commit -q --allow-empty -m C ) 2>/dev/null
  exp="$(printf '%s\n%s' "[gitproj | ⎇ main ↑2 ↓1]" "[🟢 Context $B0 0%]")"
  assert "git-ahead-behind" "$exp" "$(run_full "$wd" "$json")"
  printf 'u\n' > "$wd/untracked.txt"
  exp="$(printf '%s\n%s' "[gitproj | ⎇ main ↑2 ↓1 ?1]" "[🟢 Context $B0 0%]")"
  assert "git-ahead-behind-before-counts" "$exp" "$(run_full "$wd" "$json")"
  rm -rf "$t"
else
  printf '  skip git cases (git not found)\n'
fi

# (l) cwd from workspace.current_dir
t=$(mktmp); wd="$t/wsproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: ws -->"
json="{\"workspace\":{\"current_dir\":\"$wd\"},\"model\":{\"display_name\":\"Opus 4.8\"}}"
exp="$(printf '%s\n%s\n%s' "[Opus 4.8] [wsproj]" "[🟢 Context $B0 0%]" "[⚒ ws | ✔ ask → ● run → ○ learn → ○ done]")"
assert "workspace-current-dir" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (m1) cost.total_duration_ms -> ⏱ in the session group at L1 end
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":45},\"rate_limits\":{\"five_hour\":{\"used_percentage\":30,\"resets_at\":$R_30M}},\"cost\":{\"total_duration_ms\":4980000}}"
exp="$(printf '%s\n%s' "[myproj] [⏱ (1h 23m)]" "[⚡ Context $B45 45% | 5h $B30 30% (~30m)]")"
assert "duration-present" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (m2) cost.total_duration_ms 0 -> "⏱ (0m)"
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":0},\"cost\":{\"total_duration_ms\":0}}"
exp="$(printf '%s\n%s' "[myproj] [⏱ (0m)]" "[🟢 Context $B0 0%]")"
assert "duration-zero" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (n1) $cost + lines in the session group: [⏱ (D) | $0.23 | +156 −23]
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":0},\"cost\":{\"total_duration_ms\":4980000,\"total_cost_usd\":0.23,\"total_lines_added\":156,\"total_lines_removed\":23}}"
exp="$(printf '%s\n%s' "[myproj] [⏱ (1h 23m) | \$0.23 | +156 −23]" "[🟢 Context $B0 0%]")"
assert "cost-usd-and-lines" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (n2) context_window_size 1M -> Context/1M
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":45,\"context_window_size\":1000000}}"
exp="$(printf '%s\n%s' "[myproj]" "[⚡ Context/1M $B45 45%]")"
assert "context-size-1M" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# (n3) lines both 0 -> ±lines omitted, ⏱ still shown
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":0},\"cost\":{\"total_duration_ms\":60000,\"total_lines_added\":0,\"total_lines_removed\":0}}"
exp="$(printf '%s\n%s' "[myproj] [⏱ (1m)]" "[🟢 Context $B0 0%]")"
assert "lines-zero-omitted" "$exp" "$(run_full "$wd" "$json")"
rm -rf "$t"

# ==== compact density =========================================================

# (o1) compact: system groups + usage bars on L1, forge group on L2
t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: active-o -->"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"effort\":{\"level\":\"high\"},\"context_window\":{\"used_percentage\":45,\"context_window_size\":1000000}}"
exp="$(printf '%s\n%s' \
  "[Opus 4.8 | high] [myproj] [⚡ Context/1M $B45 45%]" \
  "[⚒ active-o | ✔ ask → ● run → ○ learn → ○ done]")"
assert "compact-active" "$exp" "$(run_full "$wd" "$json" compact)"
rm -rf "$t"

# (o2) compact drops the session group even when cost present; queue folds to 📋N
t=$(mktmp); wd="$t/myproj"; write "$wd/.forge/plan.md" "<!-- forge-slug: active-o -->"
write "$wd/.forge/backlog/x.md" "<!-- forge-slug: x -->"
json="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":0},\"cost\":{\"total_duration_ms\":4980000,\"total_cost_usd\":0.23}}"
exp="$(printf '%s\n%s' \
  "[myproj] [🟢 Context $B0 0%]" \
  "[⚒ active-o | ✔ ask → ● run → ○ learn → ○ done | 📋 1]")"
assert "compact-drops-session+folds-count" "$exp" "$(run_full "$wd" "$json" compact)"
rm -rf "$t"

# (o3) compact + forge idle -> just the system+bars line
t=$(mktmp); wd="$t/myproj"; mkdir -p "$wd/.forge"
json="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"context_window\":{\"used_percentage\":45}}"
exp="[Opus 4.8] [myproj] [⚡ Context $B45 45%]"
assert "compact-idle" "$exp" "$(run_full "$wd" "$json" compact)"
rm -rf "$t"

printf '\n%d passed, %d failed  (impl: %s)\n' "$pass" "$fail" "$(basename "$IMPL")"
[ "$fail" -eq 0 ]
