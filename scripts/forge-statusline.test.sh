#!/usr/bin/env bash
# Fixture-based tests for forge-statusline.sh.
# Each case builds a throwaway .forge/ state in a temp dir, runs the script
# with that dir as cwd, and compares the output (ANSI codes stripped — exact
# colors are a live-tuned implementation detail, ADR-0017) to an expectation.
#
# Contract (ADR-0029 grouping + density): segments are grouped as [ ... ], groups
# joined by a space, segments inside a group joined by " <SEP> " (SEP defaults to
# "·"; the merge-mode full script passes "|"). Density: "full" (default, up to two
# lines) or "compact" (a single line, queue folded into the forge group). Mode
# indicators 🧪 (plan tdd:on) / ♻️ (top-level config eco:true) render only with
# real activity (never idle / loop-only). verified flag sits at the pipeline end.
#
# Run:  bash scripts/forge-statusline.test.sh
# Exit: 0 if all pass, 1 otherwise.

set -u

SCRIPT="$(cd "$(dirname "$0")" && pwd)/forge-statusline.sh"

pass=0
fail=0

# assert <name> <expected> <actual>
assert() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf '  FAIL %s\n       expected: [%s]\n       actual:   [%s]\n' "$1" "$2" "$3"
  fi
}

mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgsl.XXXXXX"; }
strip_ansi() { sed -E $'s/\x1b\\[[0-9;]*m//g'; }

# Run the script with the given dir as cwd (no stdin -> $PWD fallback path).
run_in() { ( cd "$1" && bash "$SCRIPT" </dev/null ) | strip_ansi; }
# Run with extra env (FORGE_SL_SEP / FORGE_SL_DENSITY).
run_in_env() { local d="$1"; shift; ( cd "$d" && env "$@" bash "$SCRIPT" </dev/null ) | strip_ansi; }
# Run from cwd $1 with JSON $2 piped on stdin — exercises the cwd-from-stdin path.
run_in_json() { ( cd "$1" && printf '%s' "$2" | bash "$SCRIPT" ) | strip_ansi; }

write() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }

# --- no .forge / idle -> empty -----------------------------------------------
t=$(mktmp); assert "no-forge-dir" "" "$(run_in "$t")"; rm -rf "$t"
t=$(mktmp); mkdir -p "$t/.forge/backlog" "$t/.forge/executed"; assert "idle-empty" "" "$(run_in "$t")"; rm -rf "$t"

# --- active plan only (no run.md) -> run current, grouped ---------------------
t=$(mktmp); write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"
assert "active-plan-only" "[⚒ my-task · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in "$t")"
rm -rf "$t"

# --- ask.md only -> ask current ----------------------------------------------
t=$(mktmp); write "$t/.forge/ask.md" "<!-- forge-ask: my-idea -->"
assert "ask-md-only" "[⚒ my-idea · ● ask → ○ run → ○ learn → ○ done]" "$(run_in "$t")"
rm -rf "$t"

# --- plan.md + ask.md -> plan wins -------------------------------------------
t=$(mktmp); write "$t/.forge/plan.md" "<!-- forge-slug: promoted-task -->"; write "$t/.forge/ask.md" "<!-- forge-ask: other-idea -->"
assert "plan-and-ask-both-plan-wins" "[⚒ promoted-task · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in "$t")"
rm -rf "$t"

# --- ask.md malformed marker -> "ask" fallback -------------------------------
t=$(mktmp); write "$t/.forge/ask.md" "# no marker comment here"
assert "ask-md-malformed-marker-fallback" "[⚒ ask · ● ask → ○ run → ○ learn → ○ done]" "$(run_in "$t")"
rm -rf "$t"

# --- verified pending -> run current, ⏳ (flag at pipeline end) ---------------
t=$(mktmp); write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"; write "$t/.forge/run.md" "run notes"
printf 'verified: pending\n' > "$t/.forge/STATUS.md"
assert "verified-pending" "[⚒ my-task · ✔ ask → ● run → ○ learn → ○ done · ⏳]" "$(run_in "$t")"
rm -rf "$t"

# --- verified yes -> learn, ✓ ------------------------------------------------
t=$(mktmp); write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"; write "$t/.forge/run.md" "run notes"
printf 'verified: yes (npm test → 42 passing)\n' > "$t/.forge/STATUS.md"
assert "verified-yes" "[⚒ my-task · ✔ ask → ✔ run → ● learn → ○ done · ✓]" "$(run_in "$t")"
rm -rf "$t"

# --- verified failed -> run, ✗ -----------------------------------------------
t=$(mktmp); write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"; write "$t/.forge/run.md" "run notes"
printf 'verified: failed (UAT broke)\n' > "$t/.forge/STATUS.md"
assert "verified-failed" "[⚒ my-task · ✔ ask → ● run → ○ learn → ○ done · ✗]" "$(run_in "$t")"
rm -rf "$t"

# --- verified skipped -> learn, no flag --------------------------------------
t=$(mktmp); write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"; write "$t/.forge/run.md" "run notes"
printf 'verified: skipped (docs only)\n' > "$t/.forge/STATUS.md"
assert "verified-skipped" "[⚒ my-task · ✔ ask → ✔ run → ● learn → ○ done]" "$(run_in "$t")"
rm -rf "$t"

# --- slug falls back to filename stem ----------------------------------------
t=$(mktmp); write "$t/.forge/plan.md" "# some title without slug comment"
assert "slug-fallback-filename" "[⚒ plan · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in "$t")"
rm -rf "$t"

# --- executed parked, no active -> awaiting retro group ----------------------
t=$(mktmp); mkdir -p "$t/.forge/executed/foo"; printf 'status: executed\n' > "$t/.forge/executed/foo/STATUS.md"
assert "executed-parked-1" "[📝 1 awaiting retro]" "$(run_in "$t")"
rm -rf "$t"

# --- backlog only -> queued group --------------------------------------------
t=$(mktmp)
write "$t/.forge/backlog/a.md" "<!-- forge-slug: a -->"; write "$t/.forge/backlog/b.md" "<!-- forge-slug: b -->"; write "$t/.forge/backlog/c.md" "<!-- forge-slug: c -->"
assert "backlog-3" "[📋 3 queued]" "$(run_in "$t")"
rm -rf "$t"

# --- active + executed + backlog: line1 forge group, line2 queue group -------
t=$(mktmp)
write "$t/.forge/plan.md" "<!-- forge-slug: active-one -->"
mkdir -p "$t/.forge/executed/foo"; printf 'status: executed\n' > "$t/.forge/executed/foo/STATUS.md"
write "$t/.forge/backlog/a.md" "<!-- forge-slug: a -->"
expected="$(printf '[⚒ active-one · ✔ ask → ● run → ○ learn → ○ done]\n[📋 1 queued · 📝 1 awaiting retro]')"
assert "active-plus-pending-both-lines" "$expected" "$(run_in "$t")"
rm -rf "$t"

# --- loop.md + active -> [🔁 r2/3] leading group -----------------------------
t=$(mktmp); write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"
printf '# LOOP\nreplan-round: 2\nreplan-cap: 3\n' > "$t/.forge/loop.md"
assert "loop-prefix-active" "[🔁 r2/3] [⚒ my-task · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in "$t")"
rm -rf "$t"

# --- loop.md idle -> loop group alone ----------------------------------------
t=$(mktmp); mkdir -p "$t/.forge/backlog"; printf '# LOOP\nreplan-round: 0\nreplan-cap: 3\n' > "$t/.forge/loop.md"
assert "loop-idle" "[🔁 r0/3]" "$(run_in "$t")"
rm -rf "$t"

# ==== task #N + 🧪/♻️ indicators (ADR-0029; indicators on line 2 in full) =====

# --- plan with task marker -> #N before the slug -----------------------------
t=$(mktmp); write "$t/.forge/plan.md" $'<!-- forge-slug: my-task -->\n<!-- task: 12 -->'
assert "task-number-shown" "[⚒ #12 my-task · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in "$t")"
rm -rf "$t"

# --- no task marker + tdd off + eco false -> plain, no line 2 ----------------
t=$(mktmp); write "$t/.forge/plan.md" $'<!-- forge-slug: my-task -->\n<!-- tdd: off -->'
printf '{ "eco": false }\n' > "$t/.forge/config.json"
assert "no-task-tdd-off-eco-false-plain" "[⚒ my-task · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in "$t")"
rm -rf "$t"

# --- tdd marker on -> 🧪 in the line-2 group ---------------------------------
t=$(mktmp); write "$t/.forge/plan.md" $'<!-- forge-slug: my-task -->\n<!-- tdd: on -->'
expected="$(printf '[⚒ my-task · ✔ ask → ● run → ○ learn → ○ done]\n[🧪]')"
assert "tdd-indicator" "$expected" "$(run_in "$t")"
rm -rf "$t"

# --- eco true -> ♻️ in the line-2 group --------------------------------------
t=$(mktmp); write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"
printf '{ "eco": true }\n' > "$t/.forge/config.json"
expected="$(printf '[⚒ my-task · ✔ ask → ● run → ○ learn → ○ done]\n[♻️]')"
assert "eco-indicator" "$expected" "$(run_in "$t")"
rm -rf "$t"

# --- task + tdd + eco -> line2 [♻️ · 🧪] -------------------------------------
t=$(mktmp); write "$t/.forge/plan.md" $'<!-- forge-slug: my-task -->\n<!-- task: 71 -->\n<!-- tdd: on -->'
printf '{ "eco": true }\n' > "$t/.forge/config.json"
expected="$(printf '[⚒ #71 my-task · ✔ ask → ● run → ○ learn → ○ done]\n[♻️ · 🧪]')"
assert "task+tdd+eco-combined" "$expected" "$(run_in "$t")"
rm -rf "$t"

# --- flag + indicators coexist: flag in forge group (L1), 🧪 in L2 -----------
t=$(mktmp); write "$t/.forge/plan.md" $'<!-- forge-slug: my-task -->\n<!-- task: 71 -->\n<!-- tdd: on -->'
write "$t/.forge/run.md" "run notes"; printf 'verified: yes (x)\n' > "$t/.forge/STATUS.md"
expected="$(printf '[⚒ #71 my-task · ✔ ask → ✔ run → ● learn → ○ done · ✓]\n[🧪]')"
assert "flag-then-indicators" "$expected" "$(run_in "$t")"
rm -rf "$t"

# --- ask.md + eco -> ♻️ in line 2 (no 🧪 possible; ask has no plan) ----------
t=$(mktmp); write "$t/.forge/ask.md" "<!-- forge-ask: my-idea -->"
printf '{ "eco": true }\n' > "$t/.forge/config.json"
expected="$(printf '[⚒ my-idea · ● ask → ○ run → ○ learn → ○ done]\n[♻️]')"
assert "ask-eco-indicator" "$expected" "$(run_in "$t")"
rm -rf "$t"

# --- loop-only idle never carries indicators even with eco on ----------------
t=$(mktmp); mkdir -p "$t/.forge/backlog"; printf '# LOOP\nreplan-round: 0\nreplan-cap: 3\n' > "$t/.forge/loop.md"
printf '{ "eco": true }\n' > "$t/.forge/config.json"
assert "loop-only-no-indicators" "[🔁 r0/3]" "$(run_in "$t")"
rm -rf "$t"

# ==== FORGE_SL_SEP override + FORGE_SL_DENSITY compact ========================

# --- SEP=| -> group separator becomes | --------------------------------------
t=$(mktmp); write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"; write "$t/.forge/run.md" "r"
printf 'verified: pending\n' > "$t/.forge/STATUS.md"
assert "sep-pipe-override" "[⚒ my-task | ✔ ask → ● run → ○ learn → ○ done | ⏳]" "$(run_in_env "$t" FORGE_SL_SEP=\|)"
rm -rf "$t"

# --- compact: single line, no queue -> just the forge group ------------------
t=$(mktmp); write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"
assert "compact-active-only" "[⚒ my-task · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in_env "$t" FORGE_SL_DENSITY=compact)"
rm -rf "$t"

# --- compact: backlog folds into the forge group as 📋N (await dropped) -------
t=$(mktmp); write "$t/.forge/plan.md" "<!-- forge-slug: active-one -->"
mkdir -p "$t/.forge/executed/foo"; printf 'status: executed\n' > "$t/.forge/executed/foo/STATUS.md"
write "$t/.forge/backlog/a.md" "<!-- forge-slug: a -->"
assert "compact-forge-with-count" "[⚒ active-one · ✔ ask → ● run → ○ learn → ○ done · 📋 1]" "$(run_in_env "$t" FORGE_SL_DENSITY=compact)"
rm -rf "$t"

# --- compact + tdd -> 🧪 folded into the forge group -------------------------
t=$(mktmp); write "$t/.forge/plan.md" $'<!-- forge-slug: my-task -->\n<!-- tdd: on -->'
assert "compact-tdd" "[⚒ my-task · ✔ ask → ● run → ○ learn → ○ done · 🧪]" "$(run_in_env "$t" FORGE_SL_DENSITY=compact)"
rm -rf "$t"

# --- compact + SEP=| combined ------------------------------------------------
t=$(mktmp); write "$t/.forge/plan.md" "<!-- forge-slug: my-task -->"
write "$t/.forge/backlog/a.md" "<!-- forge-slug: a -->"
assert "compact-sep-pipe" "[⚒ my-task | ✔ ask → ● run → ○ learn → ○ done | 📋 1]" "$(run_in_env "$t" FORGE_SL_DENSITY=compact FORGE_SL_SEP=\|)"
rm -rf "$t"

# ==== branch root + cwd resolution (unchanged behavior) ======================
if command -v git >/dev/null 2>&1; then
  t=$(mktmp)
  ( cd "$t" && git init -q && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init ) 2>/dev/null
  default_branch="$(cd "$t" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
  ( cd "$t" && git checkout -q -b feature-x ) 2>/dev/null
  mkdir -p "$t/.forge"; printf '{ "defaultBranch": "%s" }\n' "$default_branch" > "$t/.forge/config.json"
  mkdir -p "$t/.forge/branch/feature-x"
  write "$t/.forge/branch/feature-x/plan.md" "<!-- forge-slug: branch-task -->"
  assert "branch-root-resolution" "[⚒ branch-task · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in "$t")"
  write "$t/.forge/plan.md" "<!-- forge-slug: should-not-show -->"
  assert "branch-root-ignores-toplevel" "[⚒ branch-task · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in "$t")"
  rm -rf "$t"
else
  printf '  skip git branch-root case (git not found)\n'
fi

a=$(mktmp); b=$(mktmp); write "$a/.forge/plan.md" "<!-- forge-slug: cwd-task -->"
assert "stdin-cwd-redirects" "[⚒ cwd-task · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in_json "$b" "{\"cwd\":\"$a\",\"model\":{\"display_name\":\"x\"}}")"
rm -rf "$a" "$b"

a=$(mktmp); b=$(mktmp); write "$a/.forge/plan.md" "<!-- forge-slug: ws-task -->"
assert "stdin-workspace-current-dir" "[⚒ ws-task · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in_json "$b" "{\"workspace\":{\"current_dir\":\"$a\"}}")"
rm -rf "$a" "$b"

a=$(mktmp); write "$a/.forge/plan.md" "<!-- forge-slug: pwd-task -->"
assert "stdin-no-cwd-uses-pwd" "[⚒ pwd-task · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in_json "$a" "{\"model\":{\"display_name\":\"x\"}}")"
rm -rf "$a"

a=$(mktmp); write "$a/.forge/plan.md" "<!-- forge-slug: missing-cwd -->"
assert "stdin-cwd-nonexistent-falls-back" "[⚒ missing-cwd · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in_json "$a" "{\"cwd\":\"/no/such/dir/xyz123\"}")"
rm -rf "$a"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
