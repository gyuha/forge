#!/usr/bin/env bash
# Parity + correctness test (ADR-0022) for resolve-forge-root.{sh,js}.
# Asserts, per scenario, that BOTH implementations print the SAME resolved
# forge-root path AND that it matches the expected value (FORGE-ROOT.md rule).
#
# `set -euo pipefail` (ADR-0022 review): a failed mktemp / cd / fixture build now
# ABORTS the run (non-zero exit) instead of silently letting "both empty = equal"
# report PARITY OK. Each check also asserts the expected value, so a script that
# does not run is caught as a mismatch rather than a false pass.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SH="$HERE/resolve-forge-root.sh"
JS="$HERE/resolve-forge-root.js"
fails=0

gitc() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }

check() { # $1=desc  $2=workdir  $3=expected
  local desc="$1" wd="$2" exp="$3" out_sh out_js
  out_sh="$(cd "$wd" && bash "$SH" 2>/dev/null)"
  out_js="$(cd "$wd" && node "$JS" 2>/dev/null)"
  if [ "$out_sh" = "$exp" ] && [ "$out_js" = "$exp" ]; then
    echo "ok   - $desc  ($exp)"
  else
    echo "FAIL - $desc  expected=[$exp] sh=[$out_sh] js=[$out_js]"
    fails=$((fails+1))
  fi
}

# C1: not a git repo → CWD-relative fallback ".forge"
C1="$(mktemp -d)"
check "non-git dir → .forge" "$C1" ".forge"

# C2: git repo on default branch (main) → <top>/.forge  (absolute, anchored)
C2="$(mktemp -d)"
( cd "$C2" && gitc init -q && gitc checkout -q -b main 2>/dev/null || true; gitc commit -q --allow-empty -m x )
TOP2="$(cd "$C2" && git rev-parse --show-toplevel)"
check "default branch main → <top>/.forge" "$C2" "$TOP2/.forge"

# C3: non-default branch → <top>/.forge/branch/feature
C3="$(mktemp -d)"
( cd "$C3" && gitc init -q && gitc checkout -q -b main 2>/dev/null || true; gitc commit -q --allow-empty -m x && gitc checkout -q -b feature )
TOP3="$(cd "$C3" && git rev-parse --show-toplevel)"
check "non-default feature → <top>/.forge/branch/feature" "$C3" "$TOP3/.forge/branch/feature"

# C4: nested branch name (slash)
C4="$(mktemp -d)"
( cd "$C4" && gitc init -q && gitc checkout -q -b main 2>/dev/null || true; gitc commit -q --allow-empty -m x && gitc checkout -q -b feature/x )
TOP4="$(cd "$C4" && git rev-parse --show-toplevel)"
check "nested feature/x → <top>/.forge/branch/feature/x" "$C4" "$TOP4/.forge/branch/feature/x"

# C5: config.json defaultBranch=trunk, current=main → <top>/.forge/branch/main
C5="$(mktemp -d)"
( cd "$C5" && gitc init -q && gitc checkout -q -b main 2>/dev/null || true; gitc commit -q --allow-empty -m x && mkdir .forge && printf '{ "defaultBranch": "trunk" }\n' > .forge/config.json )
TOP5="$(cd "$C5" && git rev-parse --show-toplevel)"
check "config default=trunk, on main → <top>/.forge/branch/main" "$C5" "$TOP5/.forge/branch/main"

# C6: run from a SUBDIRECTORY of a git repo → still anchors to <top>/.forge
#     (the ADR-0022-review regression: running from skills/ used to miss state)
C6="$(mktemp -d)"
( cd "$C6" && gitc init -q && gitc checkout -q -b main 2>/dev/null || true; gitc commit -q --allow-empty -m x && mkdir -p sub/deep )
TOP6="$(cd "$C6" && git rev-parse --show-toplevel)"
check "subdir of git repo → <top>/.forge" "$C6/sub/deep" "$TOP6/.forge"

echo ""
if [ "$fails" -eq 0 ]; then echo "RESOLVE PARITY OK"; exit 0
else echo "RESOLVE PARITY FAILED ($fails)"; exit 1; fi
