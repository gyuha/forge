#!/usr/bin/env bash
# forge-status.sh — deterministic survey + 6-column task table for fg-status.
#
# Why this exists (ADR-0020): fg-status was slow because an LLM interpreted a
# long prose skill, doing many tool round-trips to survey .forge/ (esp. dozens
# of done/ dirs) and rendering the table by hand. This script does that
# mechanical survey + table in bash+git (<50ms). The skill runs it and relays
# the output; the next-step priority machine stays in fg-status's prose
# (LLM-derived), preserving ADR-0017's "prose is the single source of truth for
# what to do next" — this script never derives the next step.
#
# Usage:
#   forge-status.sh           full: 6-column table + counts/loop footer
#   forge-status.sh --table   table only (the fast "table" mode — no footer)
#
# Output columns:  No. | Date | Task | Stage | Verify | Retro
#   Verify: O=yes  ~=skipped/n-a  x=failed  -=pending/missing/legacy
#   Retro:  O=done(path or retro file exists)  X=skipped  -=none/pending
#   (ASCII glyphs so `column -t` aligns; meaning matches SKILL.md's spec.)
#
# Dependencies: bash + git + coreutils only. Reads STATUS fields in BOTH
# `field:` and `- field:` (dash-list legacy) forms — the fg-doctor lesson.

set -u

DONE_ROWS=5   # how many most-recent done tasks to show as rows

table_only=0
[ "${1:-}" = "--table" ] && table_only=1

# --- Resolve forge root via the shared resolver (ADR-0011 / ADR-0022) --------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
root="$(bash "$SCRIPT_DIR/resolve-forge-root.sh" 2>/dev/null)"
[ -n "$root" ] || root=".forge"

if [ ! -d "$root" ]; then
  echo "No forge state (no $root/). Start a task with fg-ask."
  exit 0
fi

# --- Field extractors (accept both `field:` and `- field:` forms) ------------
field() { # $1=file  $2=fieldname  -> first whitespace-delimited token after colon
  [ -f "$1" ] || return 0
  # tr -d '\r': on a CRLF-checked-out file (Windows), `[^ ]` would capture a
  # trailing CR (CR is not a space), so e.g. verified="yes\r" → vsym misfires and
  # diverges from the node twin (which strips CR via \S). Strip it (ADR-0022 review).
  sed -n "s/^[[:space:]]*-\{0,1\}[[:space:]]*$2:[[:space:]]*\([^ ]*\).*/\1/p" "$1" | head -1 | tr -d '\r'
}
slugof() { sed -n 's/.*forge-slug:[[:space:]]*\([^ ]*\)[[:space:]]*-->.*/\1/p' "$1" 2>/dev/null | head -1 | tr -d '\r'; }
taskof() { sed -n 's/.*task:[[:space:]]*\([0-9]\{1,\}\).*/\1/p' "$1" 2>/dev/null | head -1; }
looptag() { grep -q 'generated-by:[[:space:]]*fg-loop' "$1" 2>/dev/null && printf ' (loop)'; }

vsym() { case "$1" in yes) echo O;; skipped|n/a) echo '~';; failed) echo x;; *) echo '-';; esac; }
rsym() { # $1=retro value  $2=slug
  case "$1" in
    skipped) echo X ;;
    ""|pending) ls "$root"/retro/*-"$2".md >/dev/null 2>&1 && echo O || echo '-' ;;
    *) echo O ;;   # a retro path
  esac
}
prio_rank() { # priority marker → 0 high / 1 medium(default/none) / 2 low (fg-run's order)
  case "$(sed -n 's/.*priority:[[:space:]]*\([A-Za-z]*\).*/\1/p' "$1" 2>/dev/null | head -1 | tr -d '\r')" in
    high) echo 0 ;; low) echo 2 ;; *) echo 1 ;;
  esac
}
part_num() { # part: N/M → N zero-padded to 3 (so 2 sorts before 10); 000 if no part marker
  n="$(sed -n 's/.*part:[[:space:]]*\([0-9]\{1,\}\)\/.*/\1/p' "$1" 2>/dev/null | head -1 | tr -d '\r')"
  if [ -n "$n" ]; then printf '%03d' "$n"; else printf '000'; fi
}

# --- Collect rows ------------------------------------------------------------
# Each row: No.|Date|Task|Stage|Verify|Retro  (joined later, aligned by column)
rows=""
add_row() { rows="${rows}${1}|${2}|${3}|${4}|${5}|${6}
"; }

# Active slot
if [ -f "$root/plan.md" ]; then
  slug="$(slugof "$root/plan.md")"; [ -z "$slug" ] && slug="plan"
  no="$(taskof "$root/plan.md")"; [ -z "$no" ] && no="-" || no="#$no"
  tag="$(looptag "$root/plan.md")"
  st="$root/STATUS.md"
  date="$(field "$st" executed)"; [ -z "$date" ] && date="-"
  if [ -f "$root/run.md" ]; then
    stage="learn"
    v="$(field "$st" verified)"; r="$(field "$st" retro)"
    add_row "$no" "$date" "${slug}${tag}" "$stage" "$(vsym "$v")" "$(rsym "$r" "$slug")"
  else
    add_row "$no" "-" "${slug}${tag}" "run" "-" "-"
  fi
fi

# Backlog (sorted by task number ascending; fresh items have no date)
# Ordered by fg-run's selection contract: priority(high→med→low) → part N → slug —
# NOT raw glob order, which would show a low-priority task first or part 10 before
# part 2, conflicting with the order fg-run actually runs (ADR-0022 review). The
# here-doc (not a pipe) keeps the while loop in this shell so add_row persists.
if [ -d "$root/backlog" ]; then
  TAB="$(printf '\t')"
  while IFS="$TAB" read -r _rank _part _slug f; do
    [ -n "$f" ] || continue
    slug="$(slugof "$f")"; [ -z "$slug" ] && slug="$(basename "$f" .md)"
    no="$(taskof "$f")"; [ -z "$no" ] && no="-" || no="#$no"
    add_row "$no" "-" "${slug}$(looptag "$f")" "ask" "-" "-"
  done <<EOF
$(for f in "$root"/backlog/*.md; do
    [ -e "$f" ] || continue
    s="$(slugof "$f")"; [ -z "$s" ] && s="$(basename "$f" .md)"
    printf '%s\t%s\t%s\t%s\n' "$(prio_rank "$f")" "$(part_num "$f")" "$s" "$f"
  done | LC_ALL=C sort)
EOF
fi

# Awaiting retro (executed/)
if [ -d "$root/executed" ]; then
  for dir in "$root"/executed/*/; do
    [ -d "$dir" ] || continue
    p="$dir/plan.md"; st="$dir/STATUS.md"
    slug="$(slugof "$p")"; [ -z "$slug" ] && slug="$(basename "$dir")"
    no="$(taskof "$p")"; [ -z "$no" ] && no="-" || no="#$no"
    date="$(field "$st" executed)"; [ -z "$date" ] && date="-"
    v="$(field "$st" verified)"; r="$(field "$st" retro)"
    add_row "$no" "$date" "${slug}$(looptag "$p")" "learn" "$(vsym "$v")" "$(rsym "$r" "$slug")"
  done
fi

# Done (most recent DONE_ROWS by directory name, which is date-prefixed)
done_total=0
if [ -d "$root/done" ]; then
  done_total="$(find "$root/done" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    name="$(basename "$dir")"
    p="$dir/plan.md"; st="$dir/STATUS.md"
    # Date from STATUS (format-agnostic YYYY-MM-DD); fall back to the legacy dirname prefix.
    # The dir name is a timestamp prefix (YYMMDD-HHMMSS or old YYYY-MM-DD), NOT always a date.
    date="$(field "$st" completed)"; [ -z "$date" ] && date="$(field "$st" executed)"; [ -z "$date" ] && date="${name:0:10}"
    slug="$(slugof "$p")"; [ -z "$slug" ] && slug="$(field "$st" slug)"; [ -z "$slug" ] && slug="${name:11}"
    no="$(taskof "$p")"; [ -z "$no" ] && no="-" || no="#$no"
    v="$(field "$st" verified)"; r="$(field "$st" retro)"
    add_row "$no" "$date" "${slug}$(looptag "$p")" "done" "$(vsym "$v")" "$(rsym "$r" "$slug")"
  done <<EOF
$(find "$root/done" -mindepth 1 -maxdepth 1 -type d | sort -r | head -"$DONE_ROWS")
EOF
fi

# --- Emit table --------------------------------------------------------------
# Align with awk (POSIX, universally present) instead of `column` — `column` is
# util-linux, NOT in the declared bash+git+coreutils deps, and is missing on some
# Git Bash / minimal Linux hosts (ADR-0022 review). Pad each field to its column
# max, join with two spaces, trim trailing — byte-identical to the node twin.
{
  echo "No.|Date|Task|Stage|Verify|Retro"
  printf '%s' "$rows"
} | LC_ALL=C awk -F'|' '
{ lines[NR]=$0; nf[NR]=NF; for (i=1;i<=NF;i++) if (length($i)>w[i]) w[i]=length($i) }
END {
  for (r=1;r<=NR;r++) {
    n=split(lines[r],f,"|"); out=""
    for (i=1;i<=n;i++) {
      s=f[i]; pad=w[i]-length(s); sp=""
      while (pad-- > 0) sp=sp " "
      out=out s sp; if (i<n) out=out "  "
    }
    sub(/[ \t]+$/,"",out); print out
  }
}'

[ "$table_only" -eq 1 ] && exit 0

# --- Footer (counts + loop), full mode only ----------------------------------
quick_n=0
# grep -c prints the count (incl. "0") AND exits 1 on no match; use `|| true` so
# the substitution keeps that single "0" rather than appending a second via `echo`
# (the empty-LOG footer-breaks-into-two-lines bug — ADR-0022 review).
[ -f "$root/quick/LOG.md" ] && quick_n="$(grep -c '^## ' "$root/quick/LOG.md" 2>/dev/null || true)"
[ -n "$quick_n" ] || quick_n=0
retro_n="$(ls "$root"/retro/*.md 2>/dev/null | wc -l | tr -d ' ')"
# adr/ and config are global exemptions, but adr count for display reads the
# resolved root's adr/ (branch overlay shows its own count) — fall back to top-level.
adr_dir="$root/adr"; [ -d "$adr_dir" ] || adr_dir=".forge/adr"
adr_n="$(ls "$adr_dir"/*.md 2>/dev/null | wc -l | tr -d ' ')"

footer="done: ${done_total} · quick: ${quick_n} · retro: ${retro_n} · adr: ${adr_n}"
if [ -f "$root/loop.md" ]; then
  rnd="$(field "$root/loop.md" replan-round)"; cap="$(field "$root/loop.md" replan-cap)"
  [ -n "$rnd" ] && [ -n "$cap" ] && footer="${footer} · loop: r${rnd}/${cap}"
fi
echo ""
echo "$footer"
