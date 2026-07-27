#!/usr/bin/env bash
# forge-hook-session-start.sh — SessionStart hook body: inject the unsealed-tail
# notice into the session context (ADR 260727-201031).
#
# Why this exists: the statusline already shows an unsealed task, but a passive
# display fails when nobody looks at it, and fg-ask's STEP 0 check never runs at
# all if the user starts a session by just talking instead of triggering a forge
# skill. So the state is pushed into the agent's context as text at session entry.
#
# Contract:
#   - SILENT (no stdout, exit 0) unless there is real debt: an unsealed active
#     slot (run.md present and STATUS status != done), a parked executed/<slug>/,
#     or a loop.md. A backlog-only or promoted-but-unrun state is NOT debt — the
#     statusline's "nothing when idle" rule (ADR-0017), so a fresh session on a
#     clean repo costs zero tokens and zero noise.
#   - When it speaks: a <forge-state> block with at most 3 debt items (active
#     slot first, then parked dirs in name order), a "+N more parked" line when
#     truncated, an optional goal-loop line, an optional backlog count, and a
#     fixed weak-directive paragraph (tell the user, never auto-run).
#   - ALWAYS exits 0 — a hook must never fail a session start.
#
# Output language is English on purpose: this text is read by the agent, which
# relays it to the user in the user's language (the same split as the skills —
# skill bodies are English, user-facing output follows the user).
#
# Dual dispatch (ADR-0022): this is the bash primary; forge-hook-session-start.js
# is the node twin (guarded by forge-hook-session-start.parity.test.sh). The
# hooks/ wrapper picks whichever runtime exists.
#
# Usage:  bash scripts/forge-hook-session-start.sh
set -u

# Byte collation so the executed/ glob order is locale-independent — the node
# twin sorts by bytes (Buffer.compare), and a Hangul slug would otherwise sort
# differently under a UTF-8 locale and break parity. Safe for the data we touch:
# every per-character operation here is ASCII (field names, digits), and values
# are passed through byte-wise.
export LC_ALL=C

MAX_ITEMS=3

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
root="$(bash "$SCRIPT_DIR/resolve-forge-root.sh" 2>/dev/null)"
[ -n "$root" ] || root=".forge"
[ -d "$root" ] || exit 0

# Repo-relative label for messages (the resolver returns an absolute path inside
# a git repo; an absolute path in the injected block would be noise).
top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
disp="$root"
[ -n "$top" ] && disp="${root#${top}/}"

# --- Field extractors --------------------------------------------------------
# Full value after the colon (not just the first token — a reason like
# "failed (button dead)" is exactly what makes the notice actionable). Accepts
# both `field:` and `- field:` (dash-list legacy) and strips CR (CRLF checkouts)
# — the fg-doctor lesson.
field() { # $1=file  $2=field name
  [ -f "$1" ] || return 0
  tr -d '\r' < "$1" \
    | sed -n "s/^[[:space:]]*-\{0,1\}[[:space:]]*$2:[[:space:]]*//p" \
    | head -1 | sed 's/[[:space:]]*$//'
}
slugof() { # $1=plan file
  [ -f "$1" ] || return 0
  sed -n 's/.*forge-slug:[[:space:]]*\([^ ]*\)[[:space:]]*-->.*/\1/p' "$1" 2>/dev/null | head -1 | tr -d '\r'
}
taskof() { # $1=plan file
  [ -f "$1" ] || return 0
  sed -n 's/.*task:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$1" 2>/dev/null | head -1 | tr -d '\r'
}

# --- Collect debt items ------------------------------------------------------
items=()
parked_total=0

mk_item() { # $1=task  $2=slug  $3=where  $4=verified  $5=retro
  local tsk="$1" slug="$2" where="$3" v="$4" r="$5" prefix=""
  [ -n "$tsk" ] && prefix="task ${tsk} "
  [ -n "$v" ] || v="pending"
  [ -n "$r" ] || r="pending"
  printf -- '- %s`%s` — %s, verified: %s, retro: %s' "$prefix" "$slug" "$where" "$v" "$r"
}

# Active slot: debt only when it has actually run and is not sealed. A promoted
# plan with no run.md is deliberate backlog stacking, not debt (ADR 260727-201031).
if [ -f "$root/run.md" ]; then
  st="$(field "$root/STATUS.md" status)"
  if [ "$st" != "done" ]; then
    slug="$(slugof "$root/plan.md")"
    [ -n "$slug" ] || slug="$(field "$root/STATUS.md" slug)"
    [ -n "$slug" ] || slug="(unknown)"
    items+=("$(mk_item "$(taskof "$root/plan.md")" "$slug" "active slot" \
                       "$(field "$root/STATUS.md" verified)" "$(field "$root/STATUS.md" retro)")")
  fi
fi

# Parked tasks awaiting retro (glob order = name order).
for d in "$root"/executed/*/; do
  [ -d "$d" ] || continue
  parked_total=$((parked_total + 1))
  slug="$(slugof "${d}plan.md")"
  [ -n "$slug" ] || slug="$(field "${d}STATUS.md" slug)"
  if [ -z "$slug" ]; then
    slug="$(basename "$d")"
  fi
  items+=("$(mk_item "$(taskof "${d}plan.md")" "$slug" "parked (executed/)" \
                     "$(field "${d}STATUS.md" verified)" "$(field "${d}STATUS.md" retro)")")
done

# --- Goal loop ---------------------------------------------------------------
loop_line=""
if [ -f "$root/loop.md" ]; then
  goal="$(sed -n '1p' "$root/loop.md" | tr -d '\r' \
          | sed -e 's/^#[[:space:]]*//' -e 's/^LOOP[[:space:]]*//' -e 's/^—[[:space:]]*//' -e 's/^--*[[:space:]]*//' \
          | sed 's/[[:space:]]*$//')"
  [ -n "$goal" ] || goal="(unnamed goal)"
  wall="$(field "$root/loop.md" wall)"
  if [ -z "$wall" ] || [ "$wall" = "none" ]; then
    loop_line="$(printf 'Goal loop: %s — in flight' "$goal")"
  else
    loop_line="$(printf 'Goal loop: %s — wall: %s' "$goal" "$wall")"
  fi
fi

# --- Silence when there is nothing owed --------------------------------------
n_items=${#items[@]}
if [ "$n_items" -eq 0 ] && [ -z "$loop_line" ]; then
  exit 0
fi

# --- Backlog count (context only — never a reason to speak) ------------------
queued=0
if [ -d "$root/backlog" ]; then
  queued="$(ls -1 "$root"/backlog/*.md 2>/dev/null | wc -l | tr -d ' ')"
fi

# --- Emit --------------------------------------------------------------------
printf '<forge-state>\n'
if [ "$n_items" -gt 0 ]; then
  printf 'Unfinished forge work (not sealed yet):\n'
  i=0
  for it in "${items[@]}"; do
    i=$((i + 1))
    [ "$i" -gt "$MAX_ITEMS" ] && break
    printf '%s\n' "$it"
  done
  if [ "$n_items" -gt "$MAX_ITEMS" ]; then
    printf '  (+%s more parked in %s/executed/)\n' "$((n_items - MAX_ITEMS))" "$disp"
  fi
fi
[ -n "$loop_line" ] && printf '%s\n' "$loop_line"
[ "${queued:-0}" -gt 0 ] && printf 'Backlog: %s plan(s) waiting.\n' "$queued"
cat <<'DIRECTIVE'

You MUST surface this to the user in ONE line before starting any new work, and
ask whether to close it first. `/forge:fg-next` derives and runs the owed step
(verify / retro / seal). Do NOT auto-run or auto-seal anything.
</forge-state>
DIRECTIVE
exit 0
