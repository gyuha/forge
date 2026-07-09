#!/usr/bin/env bash
# Parity test (ADR-0022): forge-statusline.sh and forge-statusline.js must emit
# identical line(s) for the same state. The session JSON is fed on stdin
# (carrying the project cwd), exactly as Claude Code invokes the statusLine.
# ANSI color codes are stripped before comparison — the exact color values are
# a live-tuned implementation detail (ADR-0017), but both scripts must still
# emit the same *structure* (grouped [ ... ] text, symbols, line count).
#
# Contract: ADR-0029 grouping (bracketed semantic groups, " · " intra-group
# separator by default) + line-2 mode indicators (🧪 tdd / ♻️ eco).
#
# `set -euo pipefail` + an explicit expected value per case (ADR-0022 review).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SH="$HERE/forge-statusline.sh"
JS="$HERE/forge-statusline.js"
fails=0

strip_ansi() { sed -E $'s/\x1b\\[[0-9;]*m//g'; }

check() { # $1=desc  $2=fixture-cwd  $3=expected (may be multi-line)
  local desc="$1" wd="$2" exp="$3" json out_sh out_js
  json="{\"cwd\":\"$wd\"}"
  out_sh="$(printf '%s' "$json" | bash "$SH" 2>/dev/null | strip_ansi | sed -e 's/[[:space:]]*$//')"
  out_js="$(printf '%s' "$json" | node "$JS" 2>/dev/null | strip_ansi | sed -e 's/[[:space:]]*$//')"
  if [ "$out_sh" = "$exp" ] && [ "$out_js" = "$exp" ]; then
    echo "ok   - $desc"
  else
    echo "FAIL - $desc  expected=[$exp] sh=[$out_sh] js=[$out_js]"
    fails=$((fails+1))
  fi
}

# idle: no .forge → no output
I="$(mktemp -d)"
check "idle (no .forge)" "$I" ""

# active learn, verified yes
A="$(mktemp -d)"; mkdir -p "$A/.forge"
printf '<!-- forge-slug: my-task --> <!-- task: 1 -->\n# T\n' > "$A/.forge/plan.md"
: > "$A/.forge/run.md"
printf 'verified: yes (x)\nretro: pending\n' > "$A/.forge/STATUS.md"
check "active learn verified yes" "$A" "[⚒ #1 my-task · ✔ ask → ✔ run → ● learn → ○ done · ✓]"

# run.md + verified: failed -> still run current, ✗
F="$(mktemp -d)"; mkdir -p "$F/.forge"
printf '<!-- forge-slug: broke-task --> <!-- task: 4 -->\n# T\n' > "$F/.forge/plan.md"
: > "$F/.forge/run.md"
printf 'verified: failed (UAT broke)\nretro: pending\n' > "$F/.forge/STATUS.md"
check "run.md + verified failed stays run" "$F" "[⚒ #4 broke-task · ✔ ask → ● run → ○ learn → ○ done · ✗]"

# active run (no run.md) -> run current
R="$(mktemp -d)"; mkdir -p "$R/.forge"
printf '<!-- forge-slug: pre-run --> <!-- task: 2 -->\n# T\n' > "$R/.forge/plan.md"
check "active run (plan only)" "$R" "[⚒ #2 pre-run · ✔ ask → ● run → ○ learn → ○ done]"

# ask.md only -> ask current
AM="$(mktemp -d)"; mkdir -p "$AM/.forge"
printf '<!-- forge-ask: my-idea -->\n' > "$AM/.forge/ask.md"
check "ask.md only" "$AM" "[⚒ my-idea · ● ask → ○ run → ○ learn → ○ done]"

# plan.md + ask.md both -> plan wins
PA="$(mktemp -d)"; mkdir -p "$PA/.forge"
printf '<!-- forge-slug: promoted-task -->\n' > "$PA/.forge/plan.md"
printf '<!-- forge-ask: other-idea -->\n' > "$PA/.forge/ask.md"
check "plan.md + ask.md both present, plan wins" "$PA" "[⚒ promoted-task · ✔ ask → ● run → ○ learn → ○ done]"

# ask.md malformed marker -> "ask" fallback
AMF="$(mktemp -d)"; mkdir -p "$AMF/.forge"
printf '# no marker comment here\n' > "$AMF/.forge/ask.md"
check "ask.md malformed marker falls back to ask" "$AMF" "[⚒ ask · ● ask → ○ run → ○ learn → ○ done]"

# backlog queued
Q="$(mktemp -d)"; mkdir -p "$Q/.forge/backlog"
: > "$Q/.forge/backlog/a.md"; : > "$Q/.forge/backlog/b.md"
check "backlog 2 queued" "$Q" "[📋 2 queued]"

# executed awaiting retro
E="$(mktemp -d)"; mkdir -p "$E/.forge/executed/t1" "$E/.forge/executed/t2"
check "executed 2 awaiting" "$E" "[📝 2 awaiting retro]"

# loop + active
L="$(mktemp -d)"; mkdir -p "$L/.forge"
printf 'replan-round: 1\nreplan-cap: 3\n' > "$L/.forge/loop.md"
printf '<!-- forge-slug: goal-task --> <!-- task: 1 -->\n# T\n' > "$L/.forge/plan.md"
: > "$L/.forge/run.md"
printf 'verified: pending\nretro: pending\n' > "$L/.forge/STATUS.md"
check "loop + active learn pending" "$L" "[🔁 r1/3] [⚒ #1 goal-task · ✔ ask → ● run → ○ learn → ○ done · ⏳]"

# loop only (no work) — standalone group, no ⚒
LO="$(mktemp -d)"; mkdir -p "$LO/.forge"
printf 'replan-round: 2\nreplan-cap: 3\n' > "$LO/.forge/loop.md"
check "loop only, no work" "$LO" "[🔁 r2/3]"

# active + backlog + executed all shown at once
AB="$(mktemp -d)"; mkdir -p "$AB/.forge/backlog" "$AB/.forge/executed/t1"
printf '<!-- forge-slug: active-task --> <!-- task: 3 -->\n# T\n' > "$AB/.forge/plan.md"
: > "$AB/.forge/backlog/x.md"
check "active + pending both lines" "$AB" "$(printf '[⚒ #3 active-task · ✔ ask → ● run → ○ learn → ○ done]\n[📋 1 queued · 📝 1 awaiting retro]')"

# indicators (ADR-0029): task # + tdd + eco -> flag in forge group (L1),
# "♻️ · 🧪" in the line-2 group
M="$(mktemp -d)"; mkdir -p "$M/.forge"
printf '<!-- forge-slug: modes-task --> <!-- task: 5 --> <!-- tdd: on -->\n# T\n' > "$M/.forge/plan.md"
: > "$M/.forge/run.md"
printf 'verified: yes (x)\nretro: pending\n' > "$M/.forge/STATUS.md"
printf '{ "eco": true }\n' > "$M/.forge/config.json"
check "task + tdd + eco indicators" "$M" "$(printf '[⚒ #5 modes-task · ✔ ask → ✔ run → ● learn → ○ done · ✓]\n[♻️ · 🧪]')"
rm -rf "$M"

# escaped (Windows-style) cwd: JSON "\\" must decode to "\" before chdir.
WIN="$(mktemp -d)"; mkdir -p "$WIN/wd\\sub/.forge/backlog"; : > "$WIN/wd\\sub/.forge/backlog/x.md"
esc="$(printf '%s' "$WIN/wd\\sub" | sed 's/\\/\\\\/g')"
wjson="{\"cwd\":\"$esc\"}"
o_sh="$(printf '%s' "$wjson" | bash "$SH" 2>/dev/null | strip_ansi | sed -e 's/[[:space:]]*$//')"
o_js="$(printf '%s' "$wjson" | node "$JS" 2>/dev/null | strip_ansi | sed -e 's/[[:space:]]*$//')"
if [ "$o_sh" = "[📋 1 queued]" ] && [ "$o_js" = "[📋 1 queued]" ]; then
  echo "ok   - escaped (Windows-style) cwd decodes"
else
  echo "FAIL - escaped cwd  sh=[$o_sh] js=[$o_js]"; fails=$((fails+1))
fi

echo ""
if [ "$fails" -eq 0 ]; then echo "STATUSLINE PARITY OK"; exit 0
else echo "STATUSLINE PARITY FAILED ($fails)"; exit 1; fi
