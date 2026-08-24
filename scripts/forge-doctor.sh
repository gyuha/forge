#!/usr/bin/env bash
# forge-doctor.sh — deterministic read-only integrity health check
# (task forge-doctor-script-extract; extends ADR-0020/0030 script-backing to
# fg-doctor per ADR 260716-16a). Surveys the `.forge/` state contract + the
# docs/manifests and REPORTS violations with severity + a fix hint. It writes
# nothing and fixes nothing (fg-doctor's read-only contract, ADR-0019); the skill
# runs it and relays. Because it has a clean exit-code contract it doubles as a
# CI gate (AI-free).
#
# Usage:  forge-doctor.sh
# Output: one `[sev] check — path\n   fix: hint` line per finding, then a verdict.
# Exit:   0 clean · 1 warnings only · 2 one or more errors
#         (a CI gate fails on non-zero for strict, or >=2 for errors-only.)
#
# Dependencies: bash + coreutils + awk/sed/grep (+ node only for B9 JSON parse,
# best-effort).  Dual dispatch: forge-doctor.js twin.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
repo="${top:-.}"
root="$(bash "$SCRIPT_DIR/resolve-forge-root.sh" 2>/dev/null)"; [ -n "$root" ] || root="$repo/.forge"
cur_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

errN=0; warnN=0; infoN=0
finding() { # <sev> <check> <path> <hint>
  case "$1" in error) errN=$((errN+1));; warning) warnN=$((warnN+1));; info) infoN=$((infoN+1));; esac
  printf '[%s] %s — %s\n   fix: %s\n' "$1" "$2" "$3" "$4"
}
# field readers tolerate legacy dash-list form (`- field:`)
field()  { [ -f "$1" ] || return 0; sed -n "s/^[[:space:]]*-\{0,1\}[[:space:]]*$2:[[:space:]]*\([^ ]*\).*/\1/p" "$1" | head -1 | tr -d '\r'; }
has_field() { [ -f "$1" ] && grep -qE "^[[:space:]]*-?[[:space:]]*$2:" "$1"; }
slugof() { sed -n 's/.*forge-slug:[[:space:]]*\([^ ]*\)[[:space:]]*-->.*/\1/p' "$1" 2>/dev/null | head -1 | tr -d '\r'; }

# =============================================================================
# Group A — state-contract integrity (resolved root)
# =============================================================================
# A1 active-slot single & no orphans
if { [ -f "$root/run.md" ] || [ -f "$root/STATUS.md" ]; } && [ ! -f "$root/plan.md" ]; then
  finding error "A1 active-slot orphan" "$root/run.md|STATUS.md (no plan.md)" "an orphaned run/STATUS with no plan — seal via fg-done or discard via fg-drop"
fi
# A2/A3/A4/A5 over every STATUS.md (active slot + executed/ + done/)  (skip dropped/)
check_status() { # <status-file> <ctx: active|executed|done>
  local sf="$1" ctx="$2" st ver rt dir slug pslug
  [ -f "$sf" ] || return 0
  st="$(field "$sf" status)"; ver="$(field "$sf" verified)"; rt="$(field "$sf" retro)"
  # A2 field validity
  case "$st" in executed|done) : ;; *) finding error "A2 STATUS.status" "$sf" "status must be executed|done (got '${st:-<missing>}')";; esac
  if [ "$ctx" != "done-legacy" ]; then
    case "$ver" in yes|skipped|n/a|pending|failed) : ;; *) has_field "$sf" verified || { [ "$ctx" = "done" ] && finding warning "A2 STATUS.verified" "$sf" "legacy done may lack verified: — backfill 'n/a (legacy)' if editing" || finding error "A2 STATUS.verified" "$sf" "verified must be yes|skipped|n/a|pending|failed"; }; esac
  fi
  # A4 half-sealed
  [ "$ctx" = "done" ] && [ "$st" != "done" ] && finding error "A4 half-sealed done/" "$sf" "re-run fg-done to finish close-out (idempotent flip to status: done)"
  # A3 slug pairing (plan forge-slug == STATUS slug)
  dir="$(dirname "$sf")"; slug="$(field "$sf" slug)"
  if [ -f "$dir/plan.md" ]; then pslug="$(slugof "$dir/plan.md")"
    [ -n "$pslug" ] && [ -n "$slug" ] && [ "$pslug" != "$slug" ] && finding error "A3 slug pairing" "$sf" "plan forge-slug ($pslug) != STATUS slug ($slug)"
  fi
  # A3(a) dangling retro path
  case "$rt" in
    .forge/*|"$repo"/*|/*) [ -f "$rt" ] || [ -f "$repo/$rt" ] || finding error "A3 dangling retro" "$sf" "retro: points to a missing file ($rt)";;
    pending) [ "$ctx" = "done" ] && finding warning "A3 retro pending in done/" "$sf" "seal left retro: unfilled — fg-learn then re-seal, or record 'skipped'";;
  esac
}
[ -f "$root/STATUS.md" ] && check_status "$root/STATUS.md" active
for d in "$root"/executed/*/; do [ -d "$d" ] || continue
  for f in plan.md run.md STATUS.md; do [ -f "$d$f" ] || finding warning "A5 executed/ incomplete" "$d" "missing $f (executed/<slug> needs plan+run+STATUS)"; done
  [ "$(field "$d/STATUS.md" status)" = "executed" ] || finding warning "A5 executed/ status" "$d/STATUS.md" "executed/<slug> STATUS must read status: executed"
  check_status "$d/STATUS.md" executed
done
for d in "$root"/done/*/; do [ -d "$d" ] || continue; check_status "$d/STATUS.md" done; done
# A6 backlog markers + task-number uniqueness (across all plans)
nums=""
add_nums() { for p in "$@"; do [ -f "$p" ] || continue; n="$(sed -n 's/.*task:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$p" | head -1)"; [ -n "$n" ] && nums="$nums$n\n"; done; }
for f in "$root"/backlog/*.md; do [ -f "$f" ] || continue
  [ -n "$(slugof "$f")" ] || finding warning "A6 backlog forge-slug" "$f" "add a first-line <!-- forge-slug: ... --> marker"
  grep -qE 'task:[[:space:]]*[0-9]' "$f" || finding warning "A6 backlog task:" "$f" "add a <!-- task: N --> marker (fg-ask assigns it)"
done
add_nums "$root"/backlog/*.md "$root/plan.md" "$root"/executed/*/plan.md "$root"/done/*/plan.md
dup="$(printf "$nums" | sort | uniq -d | grep -c .)"
[ "${dup:-0}" -gt 0 ] && finding error "A6 duplicate task number" "$(printf "$nums" | sort | uniq -d | tr '\n' ' ')" "two plans share a task: number — breaks fg-run selection/fg-status; renumber one"
# A7 stale ask.md (>1 day)
if [ -f "$root/ask.md" ]; then
  if [ -n "$(find "$root/ask.md" -mtime +1 2>/dev/null)" ]; then finding warning "A7 stale ask.md" "$root/ask.md" "finish grilling with fg-ask (overwrites it) or discard via fg-drop"; fi
fi
# A9 stale drive.md — a drive that died without deleting its marker. Harmless
# (the Stop hook ignores a marker past its 30-min bound) but it means some drive
# exited without cleaning up, and the next reader deserves to know why nothing is
# continuing. Read-only: report, never delete (fg-doctor never auto-fixes).
if [ -f "$root/drive.md" ]; then
  started="$(sed -n 's/^started:[[:space:]]*\([0-9]*\).*/\1/p' "$root/drive.md" | head -1)"
  now="$(date +%s 2>/dev/null || echo 0)"
  case "$started" in
    ''|*[!0-9]*) finding warning "A9 unparseable drive.md" "$root/drive.md" "a drive marker with no valid 'started:' — delete it (the Stop hook ignores it, so nothing is blocked)" ;;
    *) if [ "$now" -gt 0 ] && [ "$((now - started))" -gt 1800 ]; then
         finding warning "A9 stale drive.md" "$root/drive.md" "a drive exited without deleting its marker (past the 30-min bound, so it blocks nothing) — delete it"
       fi ;;
  esac
fi

# A8 (NEW) orphaned branch root — forgot fg-merge?
if [ -d "$repo/.forge/branch" ]; then
  for d in "$repo"/.forge/branch/*/ "$repo"/.forge/branch/*/*/; do [ -d "$d" ] || continue
    bn="${d#"$repo"/.forge/branch/}"; bn="${bn%/}"
    [ "$bn" = "$cur_branch" ] && continue
    # only leaf roots (contain forge docs)
    for m in adr retro done backlog CONTEXT.md plan.md loop.md; do
      if [ -e "$d$m" ]; then finding warning "A8 orphaned branch root" "$d" "branch forge state present on this branch — did you forget 'fg-merge $bn' after git merge?"; break; fi
    done
  done
fi

# =============================================================================
# Group B — docs & manifest integrity (repo root)
# =============================================================================
PJ="$repo/.claude-plugin/plugin.json"; MP="$repo/.claude-plugin/marketplace.json"
# extract every "version": "X" value in document order (handles multi-per-line JSON)
jver() { grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" | sed -E 's/.*"([^"]*)"$/\1/'; }
# B8 manifest version sync
if [ -f "$PJ" ] && [ -f "$MP" ]; then
  pv="$(jver "$PJ" | head -1)"; m1="$(jver "$MP" | head -1)"; m2="$(jver "$MP" | sed -n 2p)"
  { [ "$pv" = "$m1" ] && [ "$pv" = "$m2" ]; } || finding error "B8 manifest version drift" "$PJ|$MP" "sync all 3: plugin.json=$pv metadata=$m1 plugins[0]=$m2"
fi
# B9 manifest JSON validity
if [ -f "$PJ" ] && [ -f "$MP" ] && command -v node >/dev/null 2>&1; then
  node -e "JSON.parse(require('fs').readFileSync('$PJ','utf8'));JSON.parse(require('fs').readFileSync('$MP','utf8'))" 2>/dev/null || finding error "B9 manifest JSON invalid" "$PJ|$MP" "fix the JSON syntax (install breaks otherwise)"
fi
# B10 skill name frontmatter
for s in "$repo"/skills/*/SKILL.md; do [ -f "$s" ] || continue
  grep -qE '^name:' "$s" || finding error "B10 skill missing name:" "$s" "add a frontmatter 'name:' (else not auto-discovered)"
done
# B12 CLAUDE.md skill-list completeness
CM="$repo/CLAUDE.md"
if [ -f "$CM" ]; then
  for s in "$repo"/skills/*/SKILL.md; do [ -f "$s" ] || continue
    nm="$(sed -n 's/^name:[[:space:]]*//p' "$s" | head -1 | tr -d '\r')"; [ -n "$nm" ] || continue
    grep -qF "$nm" "$CM" || finding warning "B12 CLAUDE.md skill-list" "$nm" "skill on disk but absent from CLAUDE.md's skill list — add an entry"
  done
fi
# B13 README bilingual sync (skill-row count parity)
RE="$repo/README.md"; RK="$repo/README.ko.md"
if [ -f "$RE" ] && [ -f "$RK" ]; then
  ce="$(grep -cE '\| ?`fg-' "$RE")"; ck="$(grep -cE '\| ?`fg-' "$RK")"
  [ "$ce" = "$ck" ] || finding warning "B13 README bilingual drift" "$RE|$RK" "skill-row counts differ (en=$ce ko=$ck) — sync the pair"
fi
# B14 ADR integrity — MULTI-FORMAT aware (T3): NNNN contiguity only over the NNNN set;
# time-based IDs are not gaps; time-ID uniqueness across BOTH granularities — the
# grandfathered YYMMDD-HH+letter and the current YYMMDD-HHMMSS[+letter] (ADR 260719-161701).
ADRD="$root/adr"
if [ -d "$ADRD" ]; then
  # time-ID uniqueness — collect both granularities (mutually exclusive globs by digit
  # count), across active adr/ AND adr/retired/ (a retired time-id is frozen/never reused,
  # so an active<->retired duplicate is an error — mirrors the NNNN gap scan's retired/ include).
  tids_hh="$( { ls "$ADRD"/[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][a-z]*-*.md 2>/dev/null; ls "$ADRD"/retired/[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][a-z]*-*.md 2>/dev/null; } | sed -E 's#.*/([0-9]{6}-[0-9]{2}[a-z]+)-.*#\1#')"
  # two globs: bare YYMMDD-HHMMSS (glob [a-z]* needs >=1 letter, so bare needs its own), and lettered — each over adr/ + retired/
  tids_hms="$( { ls "$ADRD"/[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]-*.md 2>/dev/null; ls "$ADRD"/[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9][a-z]*-*.md 2>/dev/null; ls "$ADRD"/retired/[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]-*.md 2>/dev/null; ls "$ADRD"/retired/[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9][a-z]*-*.md 2>/dev/null; } | sed -E 's#.*/([0-9]{6}-[0-9]{6}[a-z]?)-.*#\1#')"
  tids="$(printf '%s\n%s\n' "$tids_hh" "$tids_hms" | grep -v '^$')"
  tdup="$(printf '%s\n' "$tids" | sort | uniq -d | grep -c .)"
  [ "${tdup:-0}" -gt 0 ] && finding error "B14 duplicate time-ID" "$(printf '%s\n' "$tids" | sort | uniq -d | tr '\n' ' ')" "two ADRs share a time-based id — bump one to the next free letter"
  # NNNN contiguity (only over the grandfathered NNNN set, incl. retired/)
  nn="$( { ls "$ADRD"/[0-9][0-9][0-9][0-9]-*.md 2>/dev/null; ls "$ADRD"/retired/[0-9][0-9][0-9][0-9]-*.md 2>/dev/null; } | sed -E 's#.*/([0-9]{4})-.*#\1#' | sort -u)"
  if [ -n "$nn" ]; then
    prev=""; for n in $nn; do
      if [ -n "$prev" ]; then exp=$(printf '%04d' $((10#${prev}+1)))
        [ "$n" = "$exp" ] || [ "$((10#${n}))" -le "$((10#${prev}))" ] || finding warning "B14 NNNN gap" "ADR-${prev}→ADR-${n}" "gap in the grandfathered NNNN set with no retired/ entry — confirm intentional"
      fi; prev="$n"
    done
  fi
fi
# B15 script twin parity (.sh <-> .js), excluding *.test.sh/*.parity.test.sh/*-wrapper.sh
for sh in "$repo"/scripts/*.sh; do [ -f "$sh" ] || continue
  case "$sh" in *.test.sh|*.parity.test.sh|*-wrapper.sh) continue;; esac
  js="${sh%.sh}.js"; [ -f "$js" ] || finding warning "B15 missing .js twin" "$sh" "add the node twin (dual dispatch, ADR-0022)"
done
for js in "$repo"/scripts/*.js; do [ -f "$js" ] || continue
  sh="${js%.js}.sh"; [ -f "$sh" ] || finding warning "B15 missing .sh twin" "$js" "add the bash primary (dual dispatch, ADR-0022)"
done
# B16 SKILL.md description length (drift lint for the trigger-core discipline, ADR 260716-22a):
# description is dual-use (/fg menu display + auto-invocation trigger, same char cap), so it
# must stay a terse trigger core. Warn (not error — bloat is drift, not breakage) when it
# regrows past DESC_MAX. Measured in Unicode codepoints via a locale-independent count
# (bytes − UTF-8 continuation bytes) so it matches the /fg char cap and the .js twin exactly.
DESC_MAX=600
desclen() { # <string> -> codepoint count
  local s="$1" b c
  b="$(printf '%s' "$s" | wc -c)"; b="${b//[![:digit:]]/}"
  c="$(printf '%s' "$s" | LC_ALL=C tr -dc '\200-\277' | wc -c)"; c="${c//[![:digit:]]/}"
  echo $(( b - c ))
}
for s in "$repo"/skills/*/SKILL.md; do [ -f "$s" ] || continue
  desc="$(sed -n 's/^description:[[:space:]]*//p' "$s" | head -1 | tr -d '\r')"
  [ -n "$desc" ] || continue
  n="$(desclen "$desc")"
  [ "$n" -gt "$DESC_MAX" ] && finding warning "B16 description length" "$s ($n chars > $DESC_MAX)" "trim the SKILL.md frontmatter description toward the trigger core — it drives /fg menu readability (ADR 260716-22a)"
done
# B17 always-on explanation discipline present (drift guard, ADR 260824-134246): the
# `**Explaining forge**` rule is inlined in every SKILL.md rather than kept in one shared doc,
# so a newly added skill silently ships outside the discipline unless something counts. Two
# properties here were earned by adversarial review, not by the original design:
#   * It compares the CANONICAL BODY, not the marker. A marker-only substring test passes a
#     SKILL.md that keeps the heading while deleting, weakening or CONTRADICTING the three
#     instructions, and it passes any file that merely *mentions* the marker — which would
#     permanently blind this check to the very file documenting it. Containment (not equality)
#     is what makes that free: fg-ask appends one sentence, so its variant is a superset and
#     needs no exception list. Canonical lives in ONE place (explaining-forge.rule.txt), never
#     hardcoded per twin — two hand-copied strings are the same defect class this check exists
#     to catch.
#   * warning, not error, per the rubric in skills/fg-doctor/SKILL.md: "error = state/release
#     actually broken · warning = drift that misleads but doesn't block". A missing style
#     paragraph breaks no install and blocks no release; every sibling prose-drift check
#     (B12/B13/B15/B16) is a warning, and B16's comment above states that same rule.
# Scoped to the forge plugin repo itself (top-level manifest name == forge) — a user project
# with its own skills/*/SKILL.md must never be told to carry forge's internal rule, since
# fg-doctor doubles as an AI-free CI gate. jname takes the FIRST "name" in document order (the
# top-level one) and is line-bounded exactly like jver, so a nested `"author": {"name":
# "forge"}` cannot trigger it and the node twin (same [ \t] bound) reaches the same verdict on
# a manifest whose value sits on the next line.
jname() { grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" | sed -E 's/.*"([^"]*)"$/\1/' | head -1; }
RULE_FILE="$SCRIPT_DIR/explaining-forge.rule.txt"
if [ -f "$PJ" ] && [ "$(jname "$PJ")" = "forge" ] && [ -f "$RULE_FILE" ]; then
  rule="$(cat "$RULE_FILE")"
  for s in "$repo"/skills/*/SKILL.md; do [ -f "$s" ] || continue
    grep -qF -e "$rule" "$s" || finding warning "B17 missing Explaining forge rule" "$s" "the canonical **Explaining forge** paragraph is absent or altered — copy it verbatim from scripts/explaining-forge.rule.txt next to this skill's **Language** rule (ADR 260824-134246)"
  done
fi

# =============================================================================
# Verdict
# =============================================================================
printf '\n🩺 forge-doctor — %d errors, %d warnings, %d info\n' "$errN" "$warnN" "$infoN"
if [ "$errN" -gt 0 ]; then exit 2; elif [ "$warnN" -gt 0 ]; then exit 1; else exit 0; fi
