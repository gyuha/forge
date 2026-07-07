#!/usr/bin/env bash
# Parity test (ADR-0022): forge-statusline-full.sh and forge-statusline-full.js
# must emit identical line(s) for the same state. The forge part (Line 3/4) is
# delegated to the already-parity'd fragment twins, so the NEW surface this guards
# is the SYSTEM rendering (Line 1/2) — model/effort/dir/git, the context/usage/
# weekly bars, graceful field omission, and resets_at humanization.
#
# ANSI stripped before comparison (colors are live-tuned, ADR-0017); an explicit
# expected value per case (not just sh==js) prevents a "both empty" false OK.
# Time pinned via FORGE_SL_NOW so humanization is deterministic.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SH="$HERE/forge-statusline-full.sh"
JS="$HERE/forge-statusline-full.js"
fails=0
NOW=1000000000
R30=$((NOW + 1800)); R17=$((NOW + 62400))

strip_ansi() { sed -E $'s/\x1b\\[[0-9;]*m//g'; }

run() { # <impl> <cwd> <json>
  case "$1" in
    *.js) ( cd "$2" && printf '%s' "$3" | FORGE_SL_NOW=$NOW node "$1" ) ;;
    *)    ( cd "$2" && printf '%s' "$3" | FORGE_SL_NOW=$NOW bash "$1" ) ;;
  esac | strip_ansi
}

check() { # <desc> <cwd> <json> <expected>
  local d="$1" wd="$2" j="$3" e="$4" a b
  a="$(run "$SH" "$wd" "$j")"
  b="$(run "$JS" "$wd" "$j")"
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
  'Opus 4.8 | high | myproj' \
  "Context $B45 45% | Usage $B30 30% (resets in 30m) | Weekly $B60 60% (resets in 17h 20m)" \
  'forge | pt-a | ✔ ask → ✔ run → ● learn → ○ done | ✓')"
rm -rf "$A"

# rate_limits absent + forge idle -> 2 system lines only
B="$(mktemp -d)"; wd="$B/myproj"; mkdir -p "$wd/.forge"
j="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Sonnet 5\"},\"context_window\":{\"used_percentage\":45}}"
check "no rate_limits + idle" "$wd" "$j" "$(printf '%s\n%s' 'Sonnet 5 | myproj' "Context $B45 45%")"
rm -rf "$B"

# context null -> 0
C_="$(mktemp -d)"; wd="$C_/myproj"; mkdir -p "$wd/.forge"
j="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":null}}"
check "context null -> 0" "$wd" "$j" "$(printf '%s\n%s' 'myproj' "Context $B0 0%")"
rm -rf "$C_"

# git status counts (branch + staged/modified/untracked)
if command -v git >/dev/null 2>&1; then
  G="$(mktemp -d)"; wd="$G/gitproj"; mkdir -p "$wd"
  ( cd "$wd" && git init -q -b test-branch && git config user.email t@t && git config user.name t \
      && printf 'a\n' > tracked.txt && git add tracked.txt && git commit -q -m init \
      && printf 'b\n' >> tracked.txt && printf 'x\n' > staged.txt && git add staged.txt \
      && printf 'y\n' > untracked.txt ) 2>/dev/null
  j="{\"cwd\":\"$wd\",\"model\":{\"display_name\":\"Opus 4.8\"}}"
  check "git status counts" "$wd" "$j" "$(printf '%s\n%s' 'Opus 4.8 | gitproj | test-branch +1 !1 ?1' "Context $B0 0%")"
  rm -rf "$G"
else
  echo "skip git parity case (git not found)"
fi

# forge states delegated (plan-only / verified failed) with minimal system JSON
P="$(mktemp -d)"; wd="$P/myproj"; printf '<!-- forge-slug: t -->\n' | { mkdir -p "$wd/.forge"; cat > "$wd/.forge/plan.md"; }
check "forge plan-only delegated" "$wd" "{\"cwd\":\"$wd\"}" "$(printf '%s\n%s\n%s' 'myproj' "Context $B0 0%" 'forge | t | ✔ ask → ● run → ○ learn → ○ done |')"
rm -rf "$P"

# boundary 89 (bar 9) + humanize 17h20m
D="$(mktemp -d)"; wd="$D/myproj"; mkdir -p "$wd/.forge"
j="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":89},\"rate_limits\":{\"seven_day\":{\"used_percentage\":60,\"resets_at\":$R17}}}"
check "boundary 89 + weekly 17h20m" "$wd" "$j" "$(printf '%s\n%s' 'myproj' "Context $B89 89% | Weekly $B60 60% (resets in 17h 20m)")"
rm -rf "$D"

# humanize >24h -> "Nd Nh" (weekly window's common case)
E="$(mktemp -d)"; wd="$E/myproj"; mkdir -p "$wd/.forge"
R4D4H=$((NOW + 360000))
j="{\"cwd\":\"$wd\",\"context_window\":{\"used_percentage\":0},\"rate_limits\":{\"seven_day\":{\"used_percentage\":60,\"resets_at\":$R4D4H}}}"
check "weekly >24h -> 4d 4h" "$wd" "$j" "$(printf '%s\n%s' 'myproj' "Context $B0 0% | Weekly $B60 60% (resets in 4d 4h)")"
rm -rf "$E"

echo ""
if [ "$fails" -eq 0 ]; then echo "STATUSLINE-FULL PARITY OK"; exit 0
else echo "STATUSLINE-FULL PARITY FAILED ($fails)"; exit 1; fi
