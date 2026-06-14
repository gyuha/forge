#!/usr/bin/env bash
# forge-statusline-wrapper.sh — composition wrapper installed by fg-statusline.
#
# Claude Code allows only ONE statusLine, so forge cannot be "added" alongside
# an existing one — it must be composed in. This wrapper runs your ORIGINAL
# statusline command (preserved verbatim in forge-statusline-orig.sh), prints
# its output, then appends the forge progress fragment as a separate row below
# — only when the fragment is non-empty, so an idle forge adds no blank row.
#
# It is fully generic (no per-install substitution): the original-command file
# and the fragment both live at fixed paths under the Claude config dir, so
# fg-statusline simply COPIES this file (like the fragment) and writes your
# original command into forge-statusline-orig.sh. See ADR-0017.
#
# To RESTORE your original-only statusline: set settings.json statusLine.command
# back to the command preserved in <claude-config-dir>/forge-statusline-orig.sh.

set -u

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# Capture the session JSON once, then feed the SAME bytes to both commands so
# each resolves the project cwd identically.
input="$(cat 2>/dev/null || true)"

# Original statusline (claude-hud, a powerline script, etc.). Errors are
# suppressed so a misbehaving original cannot blank the whole line.
orig_out=""
if [ -f "$CLAUDE_DIR/forge-statusline-orig.sh" ]; then
  orig_out="$(printf '%s' "$input" | bash "$CLAUDE_DIR/forge-statusline-orig.sh" 2>/dev/null || true)"
fi

# Forge progress fragment, fed the same JSON so it resolves cwd from stdin.
forge_out=""
if [ -f "$CLAUDE_DIR/forge-statusline.sh" ]; then
  forge_out="$(printf '%s' "$input" | bash "$CLAUDE_DIR/forge-statusline.sh" 2>/dev/null || true)"
fi

# Original first; forge as an extra row below it, only when non-empty.
[ -n "$orig_out" ] && printf '%s\n' "$orig_out"
[ -n "$forge_out" ] && printf '%s\n' "$forge_out"
exit 0
