#!/usr/bin/env bash
# Fixture-based tests for forge-loop-spend.sh — the goal-loop token-spend meter
# (task fg-loop-spend-correctness-fix / ADR-0016 amended 2026-08-20).
#
# The load-bearing test here is the GROUND-TRUTH cross-check: the expected total is
# COMPUTED from the fixture with JSON.parse, never hand-written. A hand-written number
# is only ever as right as the author's model of the schema, and both twins passing a
# hand-written fixture is exactly how a 1.928x over-count shipped with 11/11 parity
# green (ADR-0022 amended 2026-08-20).
#
# Run:  bash scripts/forge-loop-spend.test.sh   (or FGLS_IMPL=.../forge-loop-spend.js)

set -u
SCRIPT="${FGLS_IMPL:-$(cd "$(dirname "$0")" && pwd)/forge-loop-spend.sh}"
pass=0; fail=0
mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgls.XXXXXX"; }
assert()      { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s exp:[%s] act:[%s]\n' "$1" "$2" "$3"; fi; }
assert_grep() { if printf '%s' "$2" | grep -qF "$3"; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s (%s not in output)\n' "$1" "$3"; fi; }

run_ls() { local wd="$1"; shift
  case "$SCRIPT" in
    *.js) OUT="$( cd "$wd" && node "$SCRIPT" "$@" 2>&1 )"; RC=$? ;;
    *)    OUT="$( cd "$wd" && bash "$SCRIPT" "$@" 2>&1 )"; RC=$? ;;
  esac
}

NOW=2026-08-19T12:00:00.000Z
SINCE=2026-08-19T09:00:00.000Z

# ---------------------------------------------------------------------------
# Fixture corpus. Deliberately includes every shape that fooled an earlier version:
#   · usage.iterations[] mirroring the same four fields (the 1.928x over-count)
#   · a nested cache_creation{} INSIDE an iterations entry
#   · a toolUseResult.usage line (a subagent figure echoed into the parent)
#   · an escaped \"usage\" blob inside tool output (must contribute nothing)
#   · a subagent transcript in a nested dir (must be included)
#   · one entry before `since` (must be excluded)
# ---------------------------------------------------------------------------
seed_tx() {
  local d="$1"; mkdir -p "$d/sess-1/subagents"
  # before since -> excluded
  printf '{"uuid":"u0","timestamp":"2026-08-19T08:00:00.000Z","message":{"usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":5}}}\n' >> "$d/main.jsonl"
  # after since, with iterations mirroring the same fields + nested cache_creation
  printf '{"uuid":"u1","timestamp":"2026-08-19T10:00:00.000Z","message":{"usage":{"input_tokens":20,"cache_creation_input_tokens":200,"cache_read_input_tokens":2000,"output_tokens":10,"cache_creation":{"ephemeral_5m_input_tokens":200},"iterations":[{"input_tokens":20,"output_tokens":10,"cache_read_input_tokens":2000,"cache_creation_input_tokens":200,"cache_creation":{"ephemeral_5m_input_tokens":200}}],"output_tokens_details":{"thinking_tokens":3}}}}\n' >> "$d/main.jsonl"
  # a tool result echoing a SUBAGENT usage — already counted from its own transcript
  printf '{"uuid":"u2","timestamp":"2026-08-19T10:30:00.000Z","message":{"role":"user","content":"ok"},"toolUseResult":{"usage":{"input_tokens":7,"cache_creation_input_tokens":70000,"cache_read_input_tokens":0,"output_tokens":77}}}\n' >> "$d/main.jsonl"
  # tool output containing an ESCAPED json blob with usage-looking fields
  printf '{"uuid":"u3","timestamp":"2026-08-19T10:45:00.000Z","message":{"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1},"content":[{"type":"text","text":"{\\"usage\\":{\\"input_tokens\\":999999,\\"output_tokens\\":888888}}"}]}}\n' >> "$d/main.jsonl"
  # nested subagent transcript
  printf '{"uuid":"u4","timestamp":"2026-08-19T11:00:00.000Z","message":{"usage":{"input_tokens":30,"cache_creation_input_tokens":300,"cache_read_input_tokens":3000,"output_tokens":15,"iterations":[{"input_tokens":30,"output_tokens":15,"cache_read_input_tokens":3000,"cache_creation_input_tokens":300}]}}}\n' >> "$d/sess-1/subagents/a-1.jsonl"
}

# GROUND TRUTH — computed from the fixture by JSON.parse, never hand-written.
truth_of() {
  node -e '
    const fs=require("fs"),path=require("path");
    const F=["input_tokens","cache_creation_input_tokens","cache_read_input_tokens","output_tokens"];
    const since=process.argv[2]; let t=0;
    (function walk(d){for(const e of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,e.name);
      if(e.isDirectory())walk(p); else if(e.name.endsWith(".jsonl")){
        for(const l of fs.readFileSync(p,"utf8").split("\n")){ if(!l.includes("\"usage\""))continue;
          let o; try{o=JSON.parse(l)}catch(_){continue}
          if(typeof o.timestamp!=="string"||o.timestamp<=since)continue;
          const u=o.message&&o.message.usage; if(!u)continue;
          for(const f of F){const v=u[f]; if(typeof v==="number")t+=v;} } } }})(process.argv[1]);
    process.stdout.write(String(t));
  ' "$1" "$2"
}

seed_loop() { # <root> <cap> <spent-line|""> [member lines...]
  mkdir -p "$1/.forge"
  { printf '# LOOP — test goal\nstarted: 2026-08-19\nreplan-round: 0\nreplan-cap: 3\n'
    printf 'budget-tokens: %s\n' "$2"
    [ -n "$3" ] && printf 'budget-spent: %s\n' "$3"
    printf 'wall: none\n\n## Stop-condition checks (ALL must pass)\n- [ ] C1. `true`\n\n## Tasks\n'
  } > "$1/.forge/loop.md"
}
seal() { mkdir -p "$1/.forge/done/$2"; printf '# S\nslug: %s\nstatus: done\n' "$3" > "$1/.forge/done/$2/STATUS.md"; }

# === GROUND TRUTH: the meter must equal the JSON.parse total, exactly ==========
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; seed_loop "$t" 999999999 "0 · since: $SINCE"
EXPECT=$(truth_of "$tx" "$SINCE")
run_ls "$t" --transcripts "$tx" --now "$NOW"
assert "truth-rc0" 0 "$RC"
assert_grep "GROUND-TRUTH (iterations · toolUseResult · escaped blob · nested subagent)" "$OUT" "OK spent=$EXPECT "
# and prove the fixture actually exercises the traps (a naive whole-line scan differs)
NAIVE=$(node -e '
  const fs=require("fs"),path=require("path");let t=0;
  (function w(d){for(const e of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,e.name);
    if(e.isDirectory())w(p); else if(e.name.endsWith(".jsonl")){
      for(const l of fs.readFileSync(p,"utf8").split("\n")){ if(!l.includes("\"usage\""))continue;
        const m=l.match(/"timestamp":"([^"]*)"/); if(!m||m[1]<=process.argv[2])continue;
        for(const re of [/"input_tokens":(\d+)/g,/"cache_creation_input_tokens":(\d+)/g,/"cache_read_input_tokens":(\d+)/g,/"output_tokens":(\d+)/g]){
          let x; re.lastIndex=0; while((x=re.exec(l))!==null)t+=parseInt(x[1],10);} } } }})(process.argv[1]);
  process.stdout.write(String(t));' "$tx" "$SINCE")
if [ "$NAIVE" != "$EXPECT" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL fixture-is-toothless (naive scan == truth, traps not exercised)\n'; fi
rm -rf "$t" "$tx"

# === contract / gates =========================================================
t=$(mktmp); mkdir -p "$t/.forge"; run_ls "$t"; assert "no-loop-rc2" 2 "$RC"; assert_grep "no-loop-msg" "$OUT" "EMPTY no-loop-md"; rm -rf "$t"
t=$(mktmp); seed_loop "$t" none ""; run_ls "$t"; assert "none-rc0" 0 "$RC"; assert_grep "none-msg" "$OUT" "NONE no-budget-declared"; rm -rf "$t"
t=$(mktmp); seed_loop "$t" "none  # 잠시 해제" ""; run_ls "$t"; assert "none-annot-rc0" 0 "$RC"; assert_grep "none-annot" "$OUT" "NONE no-budget-declared"; rm -rf "$t"
t=$(mktmp); mkdir -p "$t/.forge"; printf '# LOOP\nreplan-cap: 3\nwall: none\n' > "$t/.forge/loop.md"; run_ls "$t"; assert "absent-rc0" 0 "$RC"; rm -rf "$t"

# BLOCKED: a declared ceiling that cannot be measured must never report 0 spend
t=$(mktmp); seed_loop "$t" 5000 "0 · since: $SINCE"; run_ls "$t" --transcripts /nonexistent/xyz --now "$NOW"
assert "blocked-tx-rc5" 5 "$RC"; assert_grep "blocked-tx-msg" "$OUT" "BLOCKED transcripts-unreadable"; rm -rf "$t"
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; seed_loop "$t" 5000 "0 · since: {ISO}"; run_ls "$t" --transcripts "$tx" --now "$NOW"
assert "blocked-since-rc5" 5 "$RC"; assert_grep "blocked-since-msg" "$OUT" "BLOCKED since-unparseable"; rm -rf "$t" "$tx"
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; seed_loop "$t" "abc" "0 · since: $SINCE"; run_ls "$t" --transcripts "$tx" --now "$NOW"
assert "blocked-cap-rc5" 5 "$RC"; assert_grep "blocked-cap-msg" "$OUT" "BLOCKED cap-unparseable"; rm -rf "$t" "$tx"

# cap parsing: trailing annotation tolerated, base 10 forced
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; seed_loop "$t" "999999999 # 상한" "0 · since: $SINCE"
run_ls "$t" --transcripts "$tx" --now "$NOW"; assert "cap-annot-rc0" 0 "$RC"; assert_grep "cap-annot" "$OUT" "cap=999999999"; rm -rf "$t" "$tx"
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; seed_loop "$t" "0100" "0 · since: $SINCE"
run_ls "$t" --transcripts "$tx" --now "$NOW"; assert_grep "cap-base10 (not octal 64)" "$OUT" "cap=100"; rm -rf "$t" "$tx"

# baseline / boundary / accumulate
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; seed_loop "$t" 999999999 ""
run_ls "$t" --transcripts "$tx" --now "$NOW"; assert_grep "baseline-zero" "$OUT" "OK spent=0 "
assert_grep "baseline-stamp" "$(cat "$t/.forge/loop.md")" "budget-spent: 0 · since: $NOW"; rm -rf "$t" "$tx"
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; seed_loop "$t" 999999999 "0 · since: 2026-08-19T11:00:00.000Z"
run_ls "$t" --transcripts "$tx" --now "$NOW"; assert_grep "since-boundary-exclusive" "$OUT" "OK spent=0 "; rm -rf "$t" "$tx"
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; seed_loop "$t" 999999999 "1000 · since: $SINCE"
EXPECT=$(truth_of "$tx" "$SINCE"); run_ls "$t" --transcripts "$tx" --now "$NOW"
assert_grep "accumulate-onto-prior" "$OUT" "OK spent=$((EXPECT + 1000)) "; rm -rf "$t" "$tx"

# ONE CALL PER BOUNDARY: a second call at the same boundary must add nothing
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; seed_loop "$t" 999999999 "0 · since: $SINCE"
EXPECT=$(truth_of "$tx" "$SINCE")
run_ls "$t" --transcripts "$tx" --now "$NOW"; FIRST="$OUT"
run_ls "$t" --transcripts "$tx" --now "$NOW"
assert_grep "idempotent-1st" "$FIRST" "OK spent=$EXPECT "
assert_grep "idempotent-2nd (no double count)" "$OUT" "OK spent=$EXPECT "; rm -rf "$t" "$tx"

# exhausted
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; seed_loop "$t" 100 "0 · since: $SINCE"
run_ls "$t" --transcripts "$tx" --now "$NOW"; assert "exh-rc3" 3 "$RC"; assert_grep "exh-msg" "$OUT" "EXHAUSTED"; rm -rf "$t" "$tx"

# pre-flight (always on — no flag)
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; seed_loop "$t" 999999999 "0 · since: $SINCE"; printf -- '- alpha\n' >> "$t/.forge/loop.md"
run_ls "$t" --transcripts "$tx" --now "$NOW"; assert "pre-noavg-rc0" 0 "$RC"; rm -rf "$t" "$tx"
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; EXPECT=$(truth_of "$tx" "$SINCE")
seed_loop "$t" $((EXPECT + 10)) "0 · since: $SINCE"; printf -- '- alpha\n' >> "$t/.forge/loop.md"; seal "$t" 2026-08-19-alpha alpha
run_ls "$t" --transcripts "$tx" --now "$NOW"; assert "pre-halt-rc4" 4 "$RC"; assert_grep "pre-halt-msg" "$OUT" "PREFLIGHT-HALT"; rm -rf "$t" "$tx"

# pre-flight robustness: checkbox notation must still yield members
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; EXPECT=$(truth_of "$tx" "$SINCE")
seed_loop "$t" $((EXPECT + 10)) "0 · since: $SINCE"; printf -- '- [ ] alpha\n' >> "$t/.forge/loop.md"; seal "$t" 2026-08-19-alpha alpha
run_ls "$t" --transcripts "$tx" --now "$NOW"; assert "pre-checkbox-rc4" 4 "$RC"; rm -rf "$t" "$tx"
# ... and a backticked member
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; EXPECT=$(truth_of "$tx" "$SINCE")
seed_loop "$t" $((EXPECT + 10)) "0 · since: $SINCE"; printf -- '- `alpha`\n' >> "$t/.forge/loop.md"; seal "$t" 2026-08-19-alpha alpha
run_ls "$t" --transcripts "$tx" --now "$NOW"; assert "pre-backtick-rc4" 4 "$RC"; rm -rf "$t" "$tx"
# suffix collision must NOT count as sealed (`fix-alpha` is not `alpha`)
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; EXPECT=$(truth_of "$tx" "$SINCE")
seed_loop "$t" $((EXPECT + 10)) "0 · since: $SINCE"; printf -- '- alpha\n' >> "$t/.forge/loop.md"; seal "$t" 2026-08-19-fix-alpha fix-alpha
run_ls "$t" --transcripts "$tx" --now "$NOW"; assert "pre-suffix-no-false-seal" 0 "$RC"; rm -rf "$t" "$tx"

# CRLF loop.md must parse (bash used to die at exit 64 while node passed)
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; mkdir -p "$t/.forge"
printf '# LOOP\r\nbudget-tokens: 999999999\r\nbudget-spent: 0 · since: %s\r\nwall: none\r\n' "$SINCE" > "$t/.forge/loop.md"
run_ls "$t" --transcripts "$tx" --now "$NOW"; assert "crlf-rc0" 0 "$RC"; rm -rf "$t" "$tx"

# a duplicated budget-spent line: only the FIRST is rewritten (both twins)
t=$(mktmp); tx=$(mktmp); seed_tx "$tx"; seed_loop "$t" 999999999 "0 · since: $SINCE"
printf 'budget-spent: 777 · since: %s\n' "$SINCE" >> "$t/.forge/loop.md"
run_ls "$t" --transcripts "$tx" --now "$NOW"
assert_grep "dup-field-second-untouched" "$(cat "$t/.forge/loop.md")" "budget-spent: 777"; rm -rf "$t" "$tx"

# usage errors
t=$(mktmp); seed_loop "$t" 1000 "0 · since: $SINCE"; run_ls "$t" --bogus; assert "badarg-rc64" 64 "$RC"; rm -rf "$t"
t=$(mktmp); seed_loop "$t" 1000 "0 · since: $SINCE"; run_ls "$t" --transcripts; assert "noval-rc64" 64 "$RC"; rm -rf "$t"
t=$(mktmp); seed_loop "$t" 1000 "0 · since: $SINCE"; run_ls "$t" --preflight; assert "removed-flag-rc64" 64 "$RC"; rm -rf "$t"

printf '\nforge-loop-spend tests: %d passed, %d failed  (impl: %s)\n' "$pass" "$fail" "$(basename "$SCRIPT")"
[ "$fail" -eq 0 ] || exit 1
