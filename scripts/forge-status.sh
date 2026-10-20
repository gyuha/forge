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

if [ ! -d "$root" ] && [ "${1:-}" != --json ]; then
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

# Normalize a STATUS field token before deciding on it: lowercase, and keep only
# the leading [a-z/] run. `Yes`, `N/A`, `yes(ok)` (no space before the reason) all
# then read as the canonical `yes`/`n/a`. Without this the surfaces disagree —
# `retro: Skipped` displayed as "retro done" while forge-done refused to seal on it.
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | sed 's/^\([a-z/]*\).*$/\1/'; }
vsym() { case "$(norm "$1")" in yes) echo O;; skipped|n/a) echo '~';; failed) echo x;; *) echo '-';; esac; }
retro_exists() { # $1=slug — EXACT match, not a `*-<slug>.md` suffix glob.
  # The glob also matched any retro whose slug merely ENDS WITH `-<slug>`, so a
  # task slugged `promotion` showed Retro=O on another task's `…-eval-promotion.md`
  # (and forge-done sealed on it). Require the prefix to be a retro timestamp:
  # `YYMMDD-HHMMSS[a-z]` or grandfathered `YYYY-MM-DD` (RETRO-FORMAT.md).
  for f_re in "$root"/retro/*.md; do
    [ -e "$f_re" ] || continue
    n_re="${f_re##*/}"; n_re="${n_re%.md}"
    p_re="${n_re%-"$1"}"
    [ "$p_re" != "$n_re" ] || continue
    case "$p_re" in
      [0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]) return 0 ;;
      [0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9][a-z]) return 0 ;;
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) return 0 ;;
    esac
  done
  return 1
}
rsym() { # $1=retro value  $2=slug
  case "$(norm "$1")" in
    skipped) echo X ;;
    ""|pending) retro_exists "$2" && echo O || echo '-' ;;
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

# Machine survey: separate representation, no next-step decision logic.
json_quote() {
  LC_ALL=C awk 'BEGIN { for(i=1;i<32;i++) esc[sprintf("%c",i)]=sprintf("\\u%04x",i) }
    { sub(/\r$/, ""); if(NR>1) s=s "\n"; s=s $0 }
    END { printf "\""; for(i=1;i<=length(s);i++){c=substr(s,i,1); if(c=="\\") printf "\\\\"; else if(c=="\"") printf "\\\""; else if(c in esc) printf "%s",esc[c]; else printf "%s",c} printf "\"" }'
}
jq_string() { printf '%s' "$1" | json_quote; }
jq_nullable() { if [ -n "$1" ]; then jq_string "$1"; else printf null; fi; }
full_field() { [ -f "$1" ] || return 0; sed -n "s/^[[:blank:]]*-\{0,1\}[[:blank:]]*$2:[[:blank:]]*//p" "$1" | head -1 | sed 's/[[:space:]]*$//'; }
json_task() {
  local location="$1" dir="$2" plan="$3" st slug num title key val
  st="$dir/STATUS.md"; slug="$(slugof "$plan")"
  [ -n "$slug" ] || slug="$(full_field "$st" slug)"
  if [ -z "$slug" ]; then
    case "$location" in active) slug=plan;; backlog) slug="$(basename "$plan" .md)";; *) slug="$(basename "$dir" | sed -E 's/^([0-9]{6}-[0-9]{6}[a-z]?|[0-9]{4}-[0-9]{2}-[0-9]{2})-//')";; esac
  fi
  num="$(taskof "$plan")"; if [ -n "$num" ]; then num="$(printf '%s' "$num" | sed 's/^0*//')"; num="${num:-0}"; fi; title="$(sed -n 's/^# //p' "$plan" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  printf '%s{"location":' "$json_sep"; jq_string "$location"; printf ',"path":'; jq_string "$plan"
  printf ',"slug":'; jq_string "$slug"; printf ',"task":%s,"title":' "${num:-null}"; jq_nullable "$title"
  for key in status verified retro executed completed; do printf ',"%s":' "$key"; jq_nullable "$(full_field "$st" "$key")"; done
  printf ',"hasRun":'; if [ "$location" != backlog ] && [ -f "$dir/run.md" ]; then printf true; else printf false; fi
  printf ',"generatedByLoop":'; if [ -n "$(looptag "$plan")" ]; then printf true; else printf false; fi
  printf '}'; json_sep=,
}
emit_json() {
  local ledger followups f dir location key pair value json_sep='' active=0 backlog=0 executed=0 done=0 quick=0 retro=0 adr=0 adr_dir exists=false
  # Validate before writing any stdout, so malformed input cannot look successful.
  ledger="$(bash "$SCRIPT_DIR/forge-followups.sh" list --root "$root")" || return 1
  followups="$(printf '%s' "$ledger" | LC_ALL=C awk '
    function quote(s, i,c,o) { o="\""; for(i=1;i<=length(s);i++){c=substr(s,i,1); if(c=="\\")o=o "\\\\"; else if(c=="\"")o=o "\\\""; else if(c in esc)o=o esc[c]; else o=o c} return o "\"" }
    function emit() { if(!id)return; sub(/^[[:space:]]+/,"",body); sub(/[[:space:]]+$/,"",body); printf "%s{\"id\":%s,\"source\":%s,\"task\":%s,\"date\":%s,\"status\":%s,\"taken\":%s,\"body\":%s}",sep,quote(id),quote(source),(task=="-"?"null":task),quote(date),quote(status),(taken=="-"?"null":taken),quote(body); sep="," }
    BEGIN { for(i=1;i<32;i++)esc[sprintf("%c",i)]=sprintf("\\u%04x",i); printf "[" }
    {gsub(/\r/,"")}
    /^<!-- followup:/ { emit(); split($0,a," \\| "); id=a[1]; sub(/^<!-- followup: /,"",id); source=a[2];sub(/^source: /,"",source);task=a[3];sub(/^task: /,"",task);date=a[4];sub(/^date: /,"",date);status=a[5];sub(/^status: /,"",status);taken=a[6];sub(/^taken: /,"",taken);sub(/ -->$/,"",taken);body="";next }
    id {body=body $0 "\n"}
    END {emit();print "]"}')"
  [ -d "$root" ] && exists=true
  printf '{"schemaVersion":1,"root":'; jq_string "$root"; printf ',"exists":%s,"tasks":[' "$exists"
  if [ -f "$root/plan.md" ]; then json_task active "$root" "$root/plan.md"; active=1; fi
  for f in "$root"/backlog/*.md; do [ -f "$f" ] || continue; json_task backlog "$root/backlog" "$f"; backlog=$((backlog+1)); done
  for location in executed done; do
    for dir in "$root/$location"/*; do [ -d "$dir" ] || continue; json_task "$location" "$dir" "$dir/plan.md"; if [ "$location" = executed ]; then executed=$((executed+1)); else done=$((done+1)); fi; done
  done
  printf '],"running":'
  if [ -f "$root/running.md" ]; then printf '{"path":'; jq_string "$root/running.md"; printf ',"content":'; jq_string "$(cat "$root/running.md")"; printf '}'; else printf null; fi
  printf ',"loop":'
  if [ -f "$root/loop.md" ]; then
    printf '{"path":'; jq_string "$root/loop.md"; printf ',"goal":'; jq_nullable "$(sed -n 's/^# //p' "$root/loop.md" | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^LOOP — //')"
    for pair in wall:wall replanRound:replan-round replanCap:replan-cap budgetTokens:budget-tokens budgetSpent:budget-spent retro:retro; do key="${pair%%:*}"; value="${pair#*:}"; printf ',"%s":' "$key"; jq_nullable "$(full_field "$root/loop.md" "$value")"; done
    printf ',"content":'; jq_string "$(cat "$root/loop.md")"; printf '}'
  else printf null; fi
  [ ! -f "$root/quick/LOG.md" ] || quick="$(grep -c '^## ' "$root/quick/LOG.md" || true)"
  for f in "$root"/retro/*.md; do [ ! -f "$f" ] || retro=$((retro+1)); done
  adr_dir="$root/adr"; [ -d "$adr_dir" ] || adr_dir=.forge/adr
  for f in "$adr_dir"/*.md; do [ ! -f "$f" ] || adr=$((adr+1)); done
  printf ',"counts":{"active":%s,"backlog":%s,"executed":%s,"done":%s,"quick":%s,"retro":%s,"adr":%s,"followups":{' "$active" "$backlog" "$executed" "$done" "$quick" "$retro" "$adr"
  json_sep=''; for key in open taken dismissed; do value="$(printf '%s' "$ledger" | grep -c "^<!-- followup:.* | status: $key |" || true)"; printf '%s"%s":%s' "$json_sep" "$key" "$value"; json_sep=,; done
  printf '}},"followups":%s}\n' "$followups"
}
if [ "${1:-}" = --json ]; then LC_ALL=C emit_json; exit $?; fi

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
    v="$(field "$st" verified)"; r="$(field "$st" retro)"
    # Stage is gated on the verification gate, not on run.md's existence: while
    # `verified:` is not sealable, fg-run still owns the task (verification-only
    # resume for pending, fix-and-re-run for failed), so `learn` would contradict
    # the next-step machine (SKILL.md step 1) on the same screen. Same gating the
    # statusline already applies (ADR-0017, 3rd amendment).
    case "$(norm "$v")" in yes|skipped|n/a) stage="learn" ;; *) stage="run" ;; esac
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
    # Only `failed` leaves fg-run's hands here: fg-run unparks it into the active
    # slot. A parked `pending` routes to fg-learn (its gate confirms the UAT
    # first), so it stays `learn` — the discriminator is who owns the next step.
    case "$(norm "$v")" in failed) stage="run" ;; *) stage="learn" ;; esac
    add_row "$no" "$date" "${slug}$(looptag "$p")" "$stage" "$(vsym "$v")" "$(rsym "$r" "$slug")"
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
    # Fallback split by FORM, not fixed offsets: the id prefix is `YYMMDD-HHMMSS`
    # (13/14 chars, optional serial letter) or the grandfathered `YYYY-MM-DD` (10).
    # The old `${name:0:10}` / `${name:11}` assumed the legacy width for every dir,
    # so a new-format `260615-143022-new-task` rendered Date `260615-143` and Task
    # `22-new-task`. Only reachable when the plan has no forge-slug AND STATUS has
    # no slug/completed/executed (hand-made or damaged dir) — but wrong by design.
    id_pfx=""; name_slug=""
    case "$name" in
      [0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9][a-z]-*) id_pfx="${name%%"${name#??????-???????}"}"; name_slug="${name#??????-???????-}" ;;
      [0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]-*)      id_pfx="${name%%"${name#??????-??????}"}";  name_slug="${name#??????-??????-}" ;;
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*)                          id_pfx="${name%%"${name#??????????}"}";     name_slug="${name#??????????-}" ;;
      *) id_pfx="$name"; name_slug="$name" ;;
    esac
    date="$(field "$st" completed)"; [ -z "$date" ] && date="$(field "$st" executed)"; [ -z "$date" ] && date="$id_pfx"
    slug="$(slugof "$p")"; [ -z "$slug" ] && slug="$(field "$st" slug)"; [ -z "$slug" ] && slug="$name_slug"
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
