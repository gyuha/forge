#!/usr/bin/env bash
# resolve-forge-root.sh — print the resolved forge root (ADR-0011 / FORGE-ROOT.md).
#
# stdout: the resolved root path — `.forge` on the default branch (or when not on
#         a named branch / not a git repo), `.forge/branch/<branch>` otherwise.
# stderr: a one-line warning when falling back (detached HEAD / non-git).
#
# Dual dispatch (ADR-0022): this is the bash primary; resolve-forge-root.js is
# the node fallback. Reads `.forge/config.json` (a global exemption — always
# top-level) for `defaultBranch`. Always exits 0.
#
# Usage:  ROOT="$(bash scripts/resolve-forge-root.sh)"
set -u

# Anchor to the git repo root so forge state resolves correctly even when run
# from a subdirectory (ADR-0022 review: running from skills/ otherwise reported
# "No forge state"). In a git repo the output is absolute (`<top>/.forge…`);
# non-git falls back to a CWD-relative `.forge` (empty prefix), unchanged.
top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
prefix="${top:+$top/}"
cfg="${top:-.}/.forge/config.json"

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

default_branch="main"
if [ -f "$cfg" ]; then
  d="$(sed -n 's/.*"defaultBranch"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$cfg" | head -1)"
  [ -n "$d" ] && default_branch="$d"
fi

if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
  echo "resolve-forge-root: not on a named branch; using default .forge/ root" >&2
  echo "${prefix}.forge"
elif [ "$branch" = "$default_branch" ]; then
  echo "${prefix}.forge"
else
  echo "${prefix}.forge/branch/$branch"
fi
