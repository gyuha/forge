#!/usr/bin/env bash
# Parity test (ADR-0022): forge-plan-lint.sh and forge-plan-lint.js must, for the
# same plan file, produce the SAME output AND exit code. Read-only, so both run
# against the same fixture and stdout/exit are compared.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SH="$HERE/forge-plan-lint.sh"; JS="$HERE/forge-plan-lint.js"
fails=0
D=$(mktemp -d "${TMPDIR:-/tmp}/fgplintp.XXXXXX"); trap 'rm -rf "$D"' EXIT

check() { # <desc> <file|"">
  local desc="$1" f="$2" O_SH O_JS rc_sh rc_js
  O_SH="$( bash "$SH" ${f:+"$f"} 2>&1 )"; rc_sh=$?
  O_JS="$( node "$JS" ${f:+"$f"} 2>&1 )"; rc_js=$?
  if [ "$rc_sh" != "$rc_js" ]; then echo "FAIL - $desc  rc sh=$rc_sh js=$rc_js"; fails=$((fails+1)); return; fi
  if [ "$O_SH" = "$O_JS" ]; then echo "ok   - $desc  (rc=$rc_sh)"
  else echo "FAIL - $desc  output differs:"; diff <(printf '%s\n' "$O_SH") <(printf '%s\n' "$O_JS") | head -20; fails=$((fails+1)); fi
}

printf '%s\n' '<!-- forge-slug: a -->' '<!-- task: 3 -->' '# t' '- [ ] S1. x — 완료 기준: y' '- [ ] S2. z — 완료 기준: w (depends: S1)' > "$D/clean.md"
printf '%s\n' '# no slug' '<!-- task: x -->' '<!-- tdd: maybe -->' '<!-- priority: top -->' '<!-- part: 4/3 -->' \
  '<!-- generated-by: fg-loop -->' '<!-- eval: none -->' '- [ ] S1. a — 완료 기준: b' '- [ ] S1. dup — 완료 기준: c (depends: S7)' > "$D/mixed.md"
printf '%s\n' '<!-- forge-slug: b -->' '# t' '<!-- generated-by: fg-debug -->' '- [ ] S1. a — 완료 기준: b' > "$D/noeval.md"
printf '%s\n' '<!-- forge-slug: c -->' '# t' '본문만' > "$D/noslice.md"

check "clean plan" "$D/clean.md"
check "mixed findings" "$D/mixed.md"
check "fix-forward without eval" "$D/noeval.md"
check "no slices + missing task" "$D/noslice.md"
check "missing file" "$D/absent.md"
check "no argument" ""

if [ "$fails" -eq 0 ]; then echo "FORGE-PLAN-LINT PARITY OK"; else echo "FORGE-PLAN-LINT PARITY FAIL ($fails)"; exit 1; fi
