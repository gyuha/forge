#!/usr/bin/env bash
# forge-done.sh — deterministic single-task seal primitive (ADR-0030).
#
# Why this exists: fg-done was slow because an LLM interpreted a long prose skill
# and hand-ran the seal as 5-6 separate bash round-trips + token-reasoned guards
# per task. This script does the MECHANICAL seal in one call (like forge-status.sh
# did for the survey — ADR-0020), so the three seal paths (interactive fg-done,
# fg-done all, fg-next all via delegation) share one fast, atomic primitive. The
# JUDGMENT stays OUT of this script, which never routes. Each piece lives in a
# named place, and this list must name the place, not just the piece:
#   * gate-failure routing, fg-map offer, all-mode confirmation, handoff
#       -> skills/fg-done/SKILL.md
#   * per-task commit after an unattended-drive seal (opt-in `driveCommit`)
#       -> skills/fg-next/DRIVE.md Part 3 (shared by fg-next all + fg-loop),
#          ADR 260901-213128. This script stays git-free either way.
#   * issue-linked commit/push/close
#       -> the PROJECT's own instructions (this repo: CLAUDE.md), NOT the plugin.
#          An earlier version of this comment said it lived in fg-done's prose;
#          it never did (`issue` appears nowhere in that skill), so a reader was
#          sent looking for text that does not exist.
#
# Unlike forge-status.sh (read-only), this MUTATES/MOVES files, so it is
# GATE-FIRST, NON-DESTRUCTIVE-ON-REFUSE: it touches nothing until every pre-check
# and gate passes, then closes out STATUS in place and moves atomically.
#
# Usage:
#   forge-done.sh [--slug <slug>] [--skip-retro "<reason>"] \
#                 [--docs-updated "<value>"] [--completed <YYYY-MM-DD>] \
#                 [--sealed-id <YYMMDD-HHMMSS>]
#   --slug         target a parked executed/<slug> or a half-sealed done/*-<slug>;
#                  default = the active slot's plan.
#   --skip-retro   record `retro: skipped (<reason>)` (the orchestrator decided to
#                  skip; the script only records it). Without it, a retro file is required.
#   --docs-updated STATUS `docs updated:` field (default: none).
#   --completed    seal DATE for the STATUS `completed:` field (default: today, YYYY-MM-DD)
#                  — an arg so tests are deterministic.
#   --sealed-id    the done-dir timestamp prefix, YYMMDD-HHMMSS (default: now, 24h local
#                  wall clock; ADR 260719-161701). The dir is `done/<sealed-id>-<slug>/`,
#                  with a serial letter appended only on a same-second same-slug collision.
#                  An arg so tests are deterministic.
#
# Exit codes (fg-done routes on these):
#   0  sealed OK (or a half-sealed dir completed idempotently)
#   2  nothing to seal (empty state / slug not found)
#   3  verify gate: verified: not sealable (pending/failed/missing) — nothing moved
#   4  retro gate:  retro owed (no retro file and no --skip-retro) — nothing moved
#   5  duplicate:   done/<date>-<slug>/ already sealed (status: done) — nothing moved
#
# Dependencies: bash + git + coreutils only.

set -u

# --- args --------------------------------------------------------------------
slug_arg=""; skip_retro=""; skip_given=0; docs="none"; completed=""; sealed_id=""
while [ $# -gt 0 ]; do
  case "$1" in
    --slug)         slug_arg="${2:-}"; shift 2 ;;
    --skip-retro)   skip_retro="${2:-}"; skip_given=1; shift 2 ;;
    --docs-updated) docs="${2:-none}"; shift 2 ;;
    --completed)    completed="${2:-}"; shift 2 ;;
    --sealed-id)    sealed_id="${2:-}"; shift 2 ;;
    *) echo "forge-done: unknown arg: $1" >&2; exit 64 ;;
  esac
done
[ -n "$completed" ] || completed="$(date +%F 2>/dev/null || echo 0000-00-00)"
[ -n "$sealed_id" ] || sealed_id="$(date +%y%m%d-%H%M%S 2>/dev/null || echo 000000-000000)"
# --sealed-id is spliced into the done/ dir path, so it MUST be a bare YYMMDD-HHMMSS
# (the serial letter, if any, is appended by this script on collision). A malformed
# value (separators, .., slashes) could escape done/ — reject it BEFORE any mutation.
case "$sealed_id" in
  [0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]) : ;;
  *) echo "forge-done: invalid --sealed-id (need bare YYMMDD-HHMMSS): $sealed_id" >&2; exit 64 ;;
esac

# --- resolve forge root (ADR-0011 / ADR-0022) --------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
root="$(bash "$SCRIPT_DIR/resolve-forge-root.sh" 2>/dev/null)"
[ -n "$root" ] || root=".forge"
[ -d "$root" ] || { echo "EMPTY no-forge-state ($root missing)"; exit 2; }

# The resolver returns an ABSOLUTE root inside a git repo (so forge works from a
# subdirectory). Paths recorded into STATUS must not carry that machine prefix:
# on a non-default branch the forge root is git-tracked whole (ADR-0011), so an
# absolute path would be committed and mean nothing to a teammate or CI.
repo_top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
relpath() { # absolute path under the repo -> repo-relative; anything else unchanged
  case "${repo_top:+x}" in
    x) case "$1" in "$repo_top"/*) printf '%s' "${1#"$repo_top"/}"; return ;; esac ;;
  esac
  printf '%s' "$1"
}

# --- field extractors (accept `field:` and `- field:`; strip CR) --------------
field() { [ -f "$1" ] || return 0; sed -n "s/^[[:space:]]*-\{0,1\}[[:space:]]*$2:[[:space:]]*\([^ ]*\).*/\1/p" "$1" | head -1 | tr -d '\r'; }
fullfield() { [ -f "$1" ] || return 0; sed -n "s/^[[:space:]]*-\{0,1\}[[:space:]]*$2:[[:space:]]*//p" "$1" | head -1 | tr -d '\r'; }
slugof() { sed -n 's/.*forge-slug:[[:space:]]*\([^ ]*\)[[:space:]]*-->.*/\1/p' "$1" 2>/dev/null | head -1 | tr -d '\r'; }

# write a closed-out STATUS.md (status: done) to $1, preserving title/slug/executed
# /verified from the source, and setting completed/retro/docs (+reviewed if $6).
close_out_status() { # $1=status-file $2=slug $3=retro-out $4=reviewed-line(or empty)
  local sf="$1" slug="$2" retro_out="$3" reviewed="$4"
  local title exec_date verified
  title="$(head -1 "$sf" 2>/dev/null)"; case "$title" in \#*) : ;; *) title="# STATUS — $slug" ;; esac
  exec_date="$(field "$sf" executed)"; [ -n "$exec_date" ] || exec_date="$completed"
  verified="$(fullfield "$sf" verified)"; [ -n "$verified" ] || verified="n/a"
  {
    printf '%s\n' "$title"
    printf 'slug: %s\n' "$slug"
    printf 'status: done\n'
    printf 'executed: %s\n' "$exec_date"
    printf 'completed: %s\n' "$completed"
    printf 'verified: %s\n' "$verified"
    printf 'retro: %s\n' "$retro_out"
    [ -n "$reviewed" ] && printf 'reviewed: %s\n' "$reviewed"
    printf 'docs updated: %s\n' "$docs"
  } > "$sf"
}

# --- determine target slug ---------------------------------------------------
slug="$slug_arg"
[ -z "$slug" ] && [ -f "$root/plan.md" ] && slug="$(slugof "$root/plan.md")"
[ -z "$slug" ] && { echo "EMPTY no-task-to-seal (no --slug and no active plan)"; exit 2; }
# slug is the OTHER half spliced into DEST (done/<sealed-id>-<slug>/). --sealed-id is
# already format-checked; guard slug too so the final path can't escape done/. Reject a
# path-separator, .., or leading-dot slug BEFORE the dup scan and any mutation (gate-first).
case "$slug" in
  */*|*\\*|*..*|.*) echo "forge-done: invalid slug (path traversal): $slug" >&2; exit 64 ;;
esac

# --- duplicate / half-sealed check (precise date-prefix match, no glob suffix) -
if [ -d "$root/done" ]; then
  for d in "$root"/done/*/; do
    [ -d "$d" ] || continue
    bn="$(basename "$d")"
    # two-format aware: grandfathered YYYY-MM-DD-slug, or YYMMDD-HHMMSS[letter]-slug
    case "$bn" in
      ????-??-??-"$slug"|??????-??????-"$slug"|??????-??????[a-z]-"$slug") : ;;
      *) continue ;;
    esac
    if [ "$(field "$d/STATUS.md" status)" = "done" ]; then
      echo "DUP already-sealed slug=$slug at $d"; exit 5
    fi
    # half-sealed (files moved, STATUS not flipped) → complete the flip idempotently
    close_out_status "$d/STATUS.md" "$slug" "$(fullfield "$d/STATUS.md" retro)" ""
    echo "SEALED half-sealed-completed $d"; exit 0
  done
fi

# --- locate the source bucket ------------------------------------------------
if [ -d "$root/executed/$slug" ]; then
  MODE=executed; D="$root/executed/$slug"
  P="$D/plan.md"; R="$D/run.md"; S="$D/STATUS.md"; V="$D/review.md"
elif [ -f "$root/plan.md" ] && [ "$(slugof "$root/plan.md")" = "$slug" ]; then
  MODE=active; D="$root"
  P="$root/plan.md"; R="$root/run.md"; S="$root/STATUS.md"; V="$root/review.md"
else
  echo "EMPTY slug-not-found slug=$slug"; exit 2
fi

# Normalize a STATUS field token before deciding on it: lowercase, and keep only
# the leading [a-z/] run. `Yes`, `N/A`, `yes(ok)` (no space before the reason) all
# then read as the canonical `yes`/`n/a`. Without this the surfaces disagree —
# `retro: Skipped` displayed as "retro done" while forge-done refused to seal on it.
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | sed 's/^\([a-z/]*\).*$/\1/'; }

# --- GATE 1: verification (before any mutation) ------------------------------
vtok="$(norm "$(field "$S" verified)")"
case "$vtok" in
  yes|skipped|n/a) : ;;
  *) echo "GATE_VERIFY not-sealable verified=[$(fullfield "$S" verified)] slug=$slug"; exit 3 ;;
esac

# --- Retro file lookup (EXACT, not a suffix glob) -----------------------------
# `*-<slug>.md` matches any retro whose slug merely ENDS WITH `-<slug>`, so a task
# slugged `promotion` was satisfied by another task's `…-eval-promotion.md` and
# sealed with no retro of its own (fail-open on an irreversible action). Require
# the whole prefix to be a retro timestamp: `YYMMDD-HHMMSS[a-z]` or the
# grandfathered `YYYY-MM-DD` (RETRO-FORMAT.md, ADR `260719-161701`).
# The path is emitted RELATIVE to the repo when $root is (see relpath below), so
# STATUS never records an absolute machine path.
find_retro() { # $1=slug -> path of the single matching retro, or empty
  slug_fr="$1"; hit_fr=""
  for f_fr in "$root"/retro/*.md; do
    [ -e "$f_fr" ] || continue
    base_fr="${f_fr##*/}"; name_fr="${base_fr%.md}"
    pfx_fr="${name_fr%-"$slug_fr"}"
    [ "$pfx_fr" != "$name_fr" ] || continue      # did not end with -<slug>
    case "$pfx_fr" in
      [0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]) ;;
      [0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9][a-z]) ;;
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
      *) continue ;;
    esac
    [ -z "$hit_fr" ] && hit_fr="$f_fr"
  done
  [ -n "$hit_fr" ] && relpath "$hit_fr"
}

# --- GATE 2: retro done-or-skipped (before any mutation) ---------------------
retro_out=""
if [ "$skip_given" -eq 1 ]; then
  retro_out="skipped ($skip_retro)"
else
  rf="$(find_retro "$slug")"
  if [ -n "$rf" ]; then
    retro_out="$rf"
  elif [ "$(norm "$(field "$S" retro)")" = "skipped" ]; then
    retro_out="$(fullfield "$S" retro)"
  else
    echo "GATE_RETRO retro-owed slug=$slug"; exit 4
  fi
fi

# --- SEAL (mutation only past this point) ------------------------------------
reviewed=""
[ -f "$V" ] && reviewed="$(relpath "$V")"   # repo-relative, never a machine path
# 1) close out STATUS in place first (so an interruption leaves it recoverable)
close_out_status "$S" "$slug" "$retro_out" "$reviewed"
# 2) archive into done/<sealed-id>-<slug>/ (YYMMDD-HHMMSS; serial letter only on a
#    same-second same-slug collision — rare, since the dup scan above already caught
#    an existing seal of this slug)
DEST="$root/done/${sealed_id}-${slug}"
if [ -e "$DEST" ]; then
  for c in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
    [ -e "$root/done/${sealed_id}${c}-${slug}" ] || { DEST="$root/done/${sealed_id}${c}-${slug}"; break; }
  done
fi
mkdir -p "$DEST"
mv "$P" "$DEST/" 2>/dev/null || true
[ -f "$R" ] && mv "$R" "$DEST/"
mv "$S" "$DEST/" 2>/dev/null || true
[ -f "$V" ] && mv "$V" "$DEST/"
# 3) empty the source bucket
if [ "$MODE" = executed ]; then
  rm -rf "$D"
fi

echo "SEALED slug=$slug dest=$DEST"
exit 0
