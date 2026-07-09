#!/usr/bin/env bash
# Parity test (ADR-0022): forge-statusline-full.sh and forge-statusline-full.js
# must emit identical line(s) for the same state. The forge part (L3/L4) is
# delegated to the already-parity'd fragment twins; this guards the SYSTEM
# rendering (grouped [ ... ] layout, model/effort/dir/git, Context/size + emoji +
# gradient bars, the session group $cost/±lines/⏱, density) plus the compact splice.
#
# ANSI stripped before comparison (colors/gradient live-tuned, ADR-0017); an
# explicit expected value per case prevents a "both empty" false OK. Time pinned.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SH="$HERE/forge-statusline-full.sh"
JS="$HERE/forge-statusline-full.js"
fails=0
NOW=1000000000
R30=$((NOW + 1800)); R17=$((NOW + 62400))

strip_ansi() { sed -E $'s/\x1b\\[[0-9;]*m//g'; }

run() { # <impl> <cwd> <json> [density]
  local density="${4:-}"
  case "$1" in
    *.js) ( cd "$2" && printf '%s' "$3" | FORGE_SL_NOW=$NOW node "$1" $density ) ;;
    *)    ( cd "$2" && printf '%s' "$3" | FORGE_SL_NOW=$NOW bash "$1" $density ) ;;
  esac | strip_ansi
}

check() { # <desc> <cwd> <json> <expected> [density]
  local d="$1" wd="$2" j="$3" e="$4" density="${5:-}" a b
  a="$(run "$SH" "$wd" "$j" "$density")"
  b="$(run "$JS" "$wd" "$j" "$density")"
  if [ "$a" = "$e" ] && [ "$b" = "$e" ]; then
    echo "ok   - $d"
  else
    echo "FAIL - $d"; printf '   exp=[%s]\n   sh =[%s]\n   js =[%s]\n' "$e" "$a" "$b"
    fails=$((fails + 1))
  fi
}

B0='░░░░░░░░░░'; B30='███░░░░░░░'; B45='█████░░░░░'; B60='██████░░░░'; B89='█████████░'

# all fields + forge active (verified yes)
A="$(mktemp -d)"; wd="$A/myproj"
mkdir -p "$wd/.forge"; printf '<!-- forge-slug: pt-a -->\n' > "$wd/.forge/plan.md"
: > "$wd/.forge/run.md"; printf 'verified: yes (x)\n' > "$wd/.forge/STATUS.md"
j="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"effort\":{\"level\":\"high\"},\"context_window\":{\"used_percentage\":45},\"rate_limits\":{\"five_hour\":{\"used_percentage\":30,\"resets_at\":$R30},\"seven_day\":{\"used_percentage\":60,\"resets_at\":$R17}}}"
check "all fields + active yes" "$wd" "$j" "$(printf '%s\n%s\n%s' \
  '[Opus 4.8 | high] [myproj]' \
  "[⚡ Context $B45 45% | 5h $B30 30% (~30m) | 7d $B60 60% (~17h 20m)]" \
  '[⚒ pt-a | ✔ ask → ✔ run → ● learn → ○ done | ✓]')"
rm -rf "$A"

# rate_limits absent + forge idle
B="$(mktemp -d)"; wd="$B/myproj"; mkdir -p "$wd/.forge"
j="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Sonnet 5\"},\"context_window\":{\"used_percentage\":45}}"
check "no rate_limits + idle" "$wd" "$j" "$(printf '%s\n%s' '[Sonnet 5] [myproj]' "[⚡ Context $B45 45%]")"
rm -rf "$B"

# context null -> 0
C_="$(mktemp -d)"; wd="$C_/myproj"; mkdir -p "$wd/.forge"
j="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":null}}"
check "context null -> 0" "$wd" "$j" "$(printf '%s\n%s' '[myproj]' "[🟢 Context $B0 0%]")"
rm -rf "$C_"

# git status counts + ahead/behind
if command -v git >/dev/null 2>&1; then
  G="$(mktemp -d)"; wd="$G/gitproj"; mkdir -p "$wd"
  ( cd "$wd" && git init -q -b test-branch && git config user.email t@t && git config user.name t \
      && printf 'a\n' > tracked.txt && git add tracked.txt && git commit -q -m init \
      && printf 'b\n' >> tracked.txt && printf 'x\n' > staged.txt && git add staged.txt \
      && printf 'y\n' > untracked.txt ) 2>/dev/null
  j="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"}}"
  check "git status counts" "$wd" "$j" "$(printf '%s\n%s' '[Opus 4.8] [gitproj | ⎇ test-branch +1 !1 ?1]' "[🟢 Context $B0 0%]")"
  rm -rf "$G"

  G2="$(mktemp -d)"; wd="$G2/gitproj"; bare="$G2/remote.git"; mkdir -p "$wd"
  git init -q --bare "$bare" 2>/dev/null
  ( cd "$wd" && git init -q -b main && git config user.email t@t && git config user.name t \
      && git commit -q --allow-empty -m A \
      && git remote add origin "$bare" && git push -q -u origin main \
      && git checkout -q -b side && git commit -q --allow-empty -m D \
      && git push -q origin side:main && git checkout -q main \
      && git commit -q --allow-empty -m B && git commit -q --allow-empty -m C ) 2>/dev/null
  j="{\"cwd\":\"$wd\"}"
  check "git ahead/behind counts" "$wd" "$j" "$(printf '%s\n%s' '[gitproj | ⎇ main ↑2 ↓1]' "[🟢 Context $B0 0%]")"
  rm -rf "$G2"
else
  echo "skip git parity case (git not found)"
fi

# forge plan-only delegated (minimal system JSON)
P="$(mktemp -d)"; wd="$P/myproj"; mkdir -p "$wd/.forge"; printf '<!-- forge-slug: t -->\n' > "$wd/.forge/plan.md"
check "forge plan-only delegated" "$wd" "{\"cwd\":\"$wd\"}" "$(printf '%s\n%s\n%s' '[myproj]' "[🟢 Context $B0 0%]" '[⚒ t | ✔ ask → ● run → ○ learn → ○ done]')"
rm -rf "$P"

# boundary 89 (emoji 🔥, bar 9) + weekly 17h20m
D="$(mktemp -d)"; wd="$D/myproj"; mkdir -p "$wd/.forge"
j="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":89},\"rate_limits\":{\"seven_day\":{\"used_percentage\":60,\"resets_at\":$R17}}}"
check "boundary 89 + weekly 17h20m" "$wd" "$j" "$(printf '%s\n%s' '[myproj]' "[🔥 Context $B89 89% | 7d $B60 60% (~17h 20m)]")"
rm -rf "$D"

# session group: ⏱ + $cost + ±lines
T="$(mktemp -d)"; wd="$T/myproj"; mkdir -p "$wd/.forge"
j="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":0},\"cost\":{\"total_duration_ms\":4980000,\"total_cost_usd\":0.23,\"total_lines_added\":156,\"total_lines_removed\":23}}"
check "session cost + lines" "$wd" "$j" "$(printf '%s\n%s' '[myproj] [⏱ (1h 23m) | $0.23 | +156 −23]' "[🟢 Context $B0 0%]")"
rm -rf "$T"

# compact density: system + bars on one line, forge group on L2, session dropped
K="$(mktemp -d)"; wd="$K/myproj"; mkdir -p "$wd/.forge"; printf '<!-- forge-slug: cp -->\n' > "$wd/.forge/plan.md"
printf '{ "eco": false }\n' > "$wd/.forge/config.json"
j="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"},\"context_window\":{\"used_percentage\":45,\"context_window_size\":1000000},\"cost\":{\"total_duration_ms\":60000}}"
check "compact density splice" "$wd" "$j" "$(printf '%s\n%s' \
  "[Opus 4.8] [myproj] [⚡ Context/1M $B45 45%]" \
  '[⚒ cp | ✔ ask → ● run → ○ learn → ○ done]')" compact
rm -rf "$K"

echo ""
if [ "$fails" -eq 0 ]; then echo "STATUSLINE-FULL PARITY OK"; exit 0
else echo "STATUSLINE-FULL PARITY FAILED ($fails)"; exit 1; fi
