#!/usr/bin/env bash
# Parity test (ADR-0022): forge-statusline.sh and forge-statusline.js must emit
# identical one-line fragments for the same state. The session JSON is fed on
# stdin (carrying the project cwd), exactly as Claude Code invokes the statusLine.
#
# `set -euo pipefail` + an explicit expected value per case (ADR-0022 review):
# a failed mktemp/fixture build aborts the run, and asserting the expected line
# (not just sh==js) stops a "both produced empty output" false PARITY OK.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SH="$HERE/forge-statusline.sh"
JS="$HERE/forge-statusline.js"
fails=0

check() { # $1=desc  $2=fixture-cwd  $3=expected-line
  local desc="$1" wd="$2" exp="$3" json out_sh out_js
  json="{\"cwd\":\"$wd\"}"
  out_sh="$(printf '%s' "$json" | bash "$SH" 2>/dev/null | sed -e 's/[[:space:]]*$//')"
  out_js="$(printf '%s' "$json" | node "$JS" 2>/dev/null | sed -e 's/[[:space:]]*$//')"
  if [ "$out_sh" = "$exp" ] && [ "$out_js" = "$exp" ]; then
    echo "ok   - $desc  [$out_sh]"
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
check "active learn verified yes" "$A" "⚒ my-task:learn ✓"

# active run (no run.md)
R="$(mktemp -d)"; mkdir -p "$R/.forge"
printf '<!-- forge-slug: pre-run --> <!-- task: 2 -->\n# T\n' > "$R/.forge/plan.md"
check "active run (plan only)" "$R" "⚒ pre-run:run"

# backlog queued
Q="$(mktemp -d)"; mkdir -p "$Q/.forge/backlog"
: > "$Q/.forge/backlog/a.md"; : > "$Q/.forge/backlog/b.md"
check "backlog 2 queued" "$Q" "⚒ 📋 2 queued"

# executed awaiting retro
E="$(mktemp -d)"; mkdir -p "$E/.forge/executed/t1" "$E/.forge/executed/t2"
check "executed 2 awaiting" "$E" "⚒ 📝 2 awaiting retro"

# loop + active
L="$(mktemp -d)"; mkdir -p "$L/.forge"
printf 'replan-round: 1\nreplan-cap: 3\n' > "$L/.forge/loop.md"
printf '<!-- forge-slug: goal-task --> <!-- task: 1 -->\n# T\n' > "$L/.forge/plan.md"
: > "$L/.forge/run.md"
printf 'verified: pending\nretro: pending\n' > "$L/.forge/STATUS.md"
check "loop + active learn pending" "$L" "⚒ 🔁 r1/3 goal-task:learn ⏳"

# loop only (no work)
LO="$(mktemp -d)"; mkdir -p "$LO/.forge"
printf 'replan-round: 2\nreplan-cap: 3\n' > "$LO/.forge/loop.md"
check "loop only, no work" "$LO" "⚒ 🔁 r2/3"

# escaped (Windows-style) cwd: JSON "\\" must decode to "\" before chdir, else the
# statusline blanks on the very platform the node twin exists for (ADR-0022 review).
# Tested on Unix with a real dir whose name contains a literal backslash.
WIN="$(mktemp -d)"; mkdir -p "$WIN/wd\\sub/.forge/backlog"; : > "$WIN/wd\\sub/.forge/backlog/x.md"
esc="$(printf '%s' "$WIN/wd\\sub" | sed 's/\\/\\\\/g')"
wjson="{\"cwd\":\"$esc\"}"
o_sh="$(printf '%s' "$wjson" | bash "$SH" 2>/dev/null | sed -e 's/[[:space:]]*$//')"
o_js="$(printf '%s' "$wjson" | node "$JS" 2>/dev/null | sed -e 's/[[:space:]]*$//')"
if [ "$o_sh" = "⚒ 📋 1 queued" ] && [ "$o_js" = "⚒ 📋 1 queued" ]; then
  echo "ok   - escaped (Windows-style) cwd decodes  [$o_sh]"
else
  echo "FAIL - escaped cwd  sh=[$o_sh] js=[$o_js]"; fails=$((fails+1))
fi

echo ""
if [ "$fails" -eq 0 ]; then echo "STATUSLINE PARITY OK"; exit 0
else echo "STATUSLINE PARITY FAILED ($fails)"; exit 1; fi
