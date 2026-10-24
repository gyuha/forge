#!/usr/bin/env bash
# forge-plan-lint.sh — deterministic structure lint for a forge plan.md.
#
# Why this exists: PLAN-FORMAT.md's rules lived only in prose, and prose drifts
# (the idea is borrowed from iha2/superlite's "plan must lint before work
# starts"). The fix-forward eval rule in particular admitted "nothing
# mechanically catches a fix-forward plan that omits the slice". This script is
# that catch. It checks ONLY language-neutral structure — HTML-comment markers
# and `- [ ] S<n>.` slice lines — because headings and labels are rendered in
# the user's language and a text match would break per language.
#
# Callers: fg-ask (self-check before writing a backlog plan) and fg-run (gate
# right before launch; errors block, warnings are shown). Unattended drives
# treat an error as a human-needed wall. The rules themselves are defined in
# skills/fg-run/PLAN-FORMAT.md — this script implements them, never extends them.
#
# Usage:  forge-plan-lint.sh <plan-file>
# Output: one line per finding — `ERROR <code> <detail>` / `WARN <code> <detail>` —
#         then `forge-plan-lint: <N> errors, <M> warnings`.
# Exit:   0 no errors (warnings allowed) · 1 errors · 2 no input / unreadable file.
#
# Codes:
#   E1 first line is not `<!-- forge-slug: ... -->`
#   E2 no slice line (`- [ ] S<n>.` and the variants listed at slice_re)
#   E3 duplicate slice id
#   E4 `(depends: ...)` names a slice that does not exist
#   E5 malformed marker value (task / tdd / priority / part / playbook), or more than one playbook
#   E6 fix-forward plan (`generated-by`) or bug-fix playbook without an `eval` marker
#   E7 `eval` marker names a missing slice, or `none` without a reason, or is malformed
#   E8 refactor playbook without a `pin` marker, or a `pin` naming a missing slice /
#      `none` without a reason / malformed (PLAN-FORMAT.md "Playbooks")
#   E9 refactor playbook: a slice that does not depend on the pin slice, directly or
#      through another slice (the behavior is pinned before any structure moves)
#   W1 no `task` marker (tolerated for plans written before task numbering)
#
# Twin: forge-plan-lint.js (identical output and exit code; scripts/forge-plan-lint.parity.test.sh).
# Dependencies: bash + coreutils only.

set -u

f="${1:-}"
if [ -z "$f" ]; then echo "forge-plan-lint: usage: forge-plan-lint.sh <plan-file>"; exit 2; fi
if [ ! -f "$f" ] || [ ! -r "$f" ]; then echo "forge-plan-lint: cannot read $f"; exit 2; fi

errors=0; warnings=0
err()  { echo "ERROR $1 $2"; errors=$((errors+1)); }
warn() { echo "WARN $1 $2"; warnings=$((warnings+1)); }

# Read lines, stripping a trailing CR so CRLF files lint the same as LF.
lines=()
while IFS= read -r l || [ -n "$l" ]; do lines+=("${l%$'\r'}"); done < "$f"

marker_re='^<!-- ([a-z-]+): (.*) -->[[:space:]]*$'
# A slice line: a list item (checkbox and **bold** optional) or a ##–#### heading whose
# text starts with S<n>. The template writes `- [ ] S1.`; real plans also use
# `- [ ] **S1. …**`, `- **S1 — …**` and `### S1`, so all of those count.
slice_re='^[[:space:]]*(- (\[[ xX]\] )?(\*\*)?|#{2,4} )(S[0-9]+)([.:)]|\*\*|[[:space:]]|$)'

# E1 — forge-slug on the first line
first="${lines[0]:-}"
if ! [[ "$first" =~ ^\<!--\ forge-slug:\ [^[:space:]].*\ --\>[[:space:]]*$ ]]; then
  err E1 "first line must be <!-- forge-slug: <slug> -->"
fi

# Collect slices, depends, markers in one pass (file order).
slices=" "; slice_order=(); deps=(); list_items=(); head_items=()
has_task=0; generated=0; evals=(); playbook=""; pbs=0; pins=()
for l in "${lines[@]+"${lines[@]}"}"; do
  if [[ "$l" =~ $slice_re ]]; then
    id="${BASH_REMATCH[4]}"; dep=""
    if [[ "$l" =~ \(depends:\ ([^\)]*)\) ]]; then dep="${BASH_REMATCH[1]}"; fi
    # Headings are kept apart: a plan with list-item slices may annotate one
    # with a note heading (`### S3 …`), which must not count as a second S3.
    if [[ "$l" =~ ^[[:space:]]*# ]]; then head_items+=("$id|$dep"); else list_items+=("$id|$dep"); fi
    continue
  fi
  if [[ "$l" =~ $marker_re ]]; then
    key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"
    case "$key" in
      task) has_task=1; [[ "$val" =~ ^[0-9]+$ ]] || err E5 "task: $val" ;;
      tdd) case "$val" in on|off) ;; *) err E5 "tdd: $val" ;; esac ;;
      priority) case "$val" in high|medium|low) ;; *) err E5 "priority: $val" ;; esac ;;
      part)
        if [[ "$val" =~ ^([0-9]+)/([0-9]+)$ ]]; then
          n=$((10#${BASH_REMATCH[1]})); m=$((10#${BASH_REMATCH[2]}))
          { [ "$n" -ge 1 ] && [ "$n" -le "$m" ]; } || err E5 "part: $val"
        else err E5 "part: $val"; fi ;;
      generated-by) generated=1 ;;
      eval) evals+=("$val") ;;
      playbook) pbs=$((pbs+1)); case "$val" in bug-fix|refactor) playbook="$val" ;; *) err E5 "playbook: $val" ;; esac ;;
      pin) pins+=("$val") ;;
    esac
  fi
done
[ "$pbs" -gt 1 ] && err E5 "playbook: one per plan ($pbs markers)"

# `none — <reason>`: true when text follows `none` past one separator (— / - / :).
none_reason() {
  local r="${1#none}"; r="${r#"${r%%[![:space:]]*}"}"
  case "$r" in —*) r="${r#—}" ;; -*) r="${r#-}" ;; :*) r="${r#:}" ;; esac
  r="${r#"${r%%[![:space:]]*}"}"
  [ -n "$r" ]
}

# Slices = list items; heading-form slices count only when there are no list items.
if [ "${#list_items[@]}" -gt 0 ]; then chosen=("${list_items[@]}"); else chosen=("${head_items[@]+"${head_items[@]}"}"); fi
for it in "${chosen[@]+"${chosen[@]}"}"; do
  id="${it%%|*}"; dep="${it#*|}"
  case "$slices" in *" $id "*) err E3 "$id" ;; *) slices="$slices$id "; slice_order+=("$id") ;; esac
  [ -z "$dep" ] || deps+=("$id|$dep")
done

[ "${#slice_order[@]}" -eq 0 ] && err E2 "no '- [ ] S<n>.' slice"

# E4 — every depends reference must exist
for d in "${deps[@]+"${deps[@]}"}"; do
  from="${d%%|*}"; rest="${d#*|}"
  for ref in $(printf '%s' "$rest" | grep -oE 'S[0-9]+'); do
    case "$slices" in *" $ref "*) ;; *) err E4 "$from->$ref" ;; esac
  done
done

# E6/E7 — fix-forward eval marker (PLAN-FORMAT.md fix-forward eval rule)
for v in "${evals[@]+"${evals[@]}"}"; do
  if [[ "$v" =~ ^none ]]; then
    none_reason "$v" || err E7 "eval: none needs a reason"
  elif [[ "$v" =~ ^S[0-9]+([[:space:]]*,[[:space:]]*S[0-9]+)*$ ]]; then
    for ref in $(printf '%s' "$v" | grep -oE 'S[0-9]+'); do
      case "$slices" in *" $ref "*) ;; *) err E7 "eval: $ref is not a slice" ;; esac
    done
  else
    err E7 "eval: $v"
  fi
done
if { [ "$generated" -eq 1 ] || [ "$playbook" = bug-fix ]; } && [ "${#evals[@]}" -eq 0 ]; then
  err E6 "fix-forward plan (generated-by) or bug-fix playbook needs <!-- eval: S<n> --> or <!-- eval: none — <reason> -->"
fi

# E8/E9 — playbooks (PLAN-FORMAT.md "Playbooks"): pin values are checked wherever they
# appear; the requirement and the order constraint bind only a refactor playbook.
pin_ok=""
for v in "${pins[@]+"${pins[@]}"}"; do
  if [[ "$v" =~ ^none ]]; then
    none_reason "$v" || err E8 "pin: none needs a reason"
  elif [[ "$v" =~ ^S[0-9]+$ ]]; then
    case "$slices" in *" $v "*) pin_ok="$v" ;; *) err E8 "pin: $v is not a slice" ;; esac
  else
    err E8 "pin: $v"
  fi
done
if [ "$playbook" = refactor ]; then
  if [ "${#pins[@]}" -eq 0 ]; then
    err E8 "refactor playbook needs <!-- pin: S<n> --> or <!-- pin: none — <reason> -->"
  elif [ "${#pins[@]}" -eq 1 ] && [ -n "$pin_ok" ]; then
    reached=" $pin_ok "; changed=1
    while [ "$changed" -eq 1 ]; do
      changed=0
      for d in "${deps[@]+"${deps[@]}"}"; do
        from="${d%%|*}"; case "$reached" in *" $from "*) continue ;; esac
        for ref in $(printf '%s' "${d#*|}" | grep -oE 'S[0-9]+'); do
          case "$reached" in *" $ref "*) reached="$reached$from "; changed=1; break ;; esac
        done
      done
    done
    for id in "${slice_order[@]}"; do
      case "$reached" in *" $id "*) ;; *) err E9 "$id does not depend on pin $pin_ok" ;; esac
    done
  fi
fi

[ "$has_task" -eq 0 ] && warn W1 "no <!-- task: N --> marker"

echo "forge-plan-lint: $errors errors, $warnings warnings"
[ "$errors" -eq 0 ] || exit 1
exit 0
