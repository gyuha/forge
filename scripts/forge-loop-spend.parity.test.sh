#!/usr/bin/env bash
# Parity test (ADR-0022): forge-loop-spend.sh and forge-loop-spend.js must, for the
# same state, produce the SAME stdout, the SAME exit code, AND the SAME resulting
# loop.md. The script MUTATES the ledger, so each twin runs in its OWN fixture copy
# and the written loop.md is diffed too.
#
# The twins reach their total by DIFFERENT routes on purpose (bash strips
# `iterations[]` from the raw line; node parses the structure), which is what makes
# this an actual cross-check rather than two copies of one mistake — the failure mode
# that shipped a 1.928x over-count with 11/11 green (ADR-0022 amended 2026-08-20).
#
# COVERAGE NOTE: every `## Tasks` fixture below seeds MULTIPLE members, and at least
# one seals ALL of them. The previous suite seeded `- alpha` alone in every case, so a
# node regex that read only the FIRST member was structurally invisible while parity
# stayed green.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SH="$HERE/forge-loop-spend.sh"; JS="$HERE/forge-loop-spend.js"
fails=0
mktmp() { mktemp -d "${TMPDIR:-/tmp}/fglsp.XXXXXX"; }

NOW=2026-08-19T12:00:00.000Z
SINCE=2026-08-19T09:00:00.000Z

seed_tx() {
  local d="$1"; mkdir -p "$d/sess-1/subagents"
  printf '{"uuid":"u0","timestamp":"2026-08-19T08:00:00.000Z","message":{"usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":5}}}\n' >> "$d/main.jsonl"
  printf '{"uuid":"u1","timestamp":"2026-08-19T10:00:00.000Z","message":{"usage":{"input_tokens":20,"cache_creation_input_tokens":200,"cache_read_input_tokens":2000,"output_tokens":10,"cache_creation":{"ephemeral_5m_input_tokens":200},"iterations":[{"input_tokens":20,"output_tokens":10,"cache_read_input_tokens":2000,"cache_creation_input_tokens":200,"cache_creation":{"ephemeral_5m_input_tokens":200}}]}}}\n' >> "$d/main.jsonl"
  printf '{"uuid":"u2","timestamp":"2026-08-19T10:30:00.000Z","message":{"role":"user","content":"ok"},"toolUseResult":{"usage":{"input_tokens":7,"cache_creation_input_tokens":70000,"cache_read_input_tokens":0,"output_tokens":77}}}\n' >> "$d/main.jsonl"
  printf '{"uuid":"u3","timestamp":"2026-08-19T10:45:00.000Z","message":{"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1},"content":[{"type":"text","text":"{\\"usage\\":{\\"input_tokens\\":999999}}"}]}}\n' >> "$d/main.jsonl"
  printf '{"uuid":"u4","timestamp":"2026-08-19T11:00:00.000Z","message":{"usage":{"input_tokens":30,"cache_creation_input_tokens":300,"cache_read_input_tokens":3000,"output_tokens":15,"iterations":[{"input_tokens":30,"output_tokens":15,"cache_read_input_tokens":3000,"cache_creation_input_tokens":300}]}}}\n' >> "$d/sess-1/subagents/a-1.jsonl"
}
seed_loop() { mkdir -p "$1/.forge"
  { printf '# LOOP — parity goal\nstarted: 2026-08-19\nreplan-round: 1\nreplan-cap: 3\n'
    printf 'budget-tokens: %s\n' "$2"
    [ -n "$3" ] && printf 'budget-spent: %s\n' "$3"
    printf 'wall: none\n\n## Stop-condition checks (ALL must pass)\n- [ ] C1. `true`\n\n## Tasks\n'
  } > "$1/.forge/loop.md"; }
members3() { printf -- '- alpha\n- beta\n- gamma\n' >> "$1/.forge/loop.md"; }
seal() { mkdir -p "$1/.forge/done/$2"; printf '# S\nslug: %s\nstatus: done\n' "$3" > "$1/.forge/done/$2/STATUS.md"; }

check() { # <desc> <seedfn> [args...]
  local desc="$1" seedfn="$2"; shift 2
  local D1 D2 TX O1 O2 rc1 rc2
  D1=$(mktmp); D2=$(mktmp); TX=$(mktmp); seed_tx "$TX"
  "$seedfn" "$D1"; "$seedfn" "$D2"
  O1="$( cd "$D1" && bash "$SH" --transcripts "$TX" --now "$NOW" "$@" 2>&1 )"; rc1=$?
  O2="$( cd "$D2" && node "$JS" --transcripts "$TX" --now "$NOW" "$@" 2>&1 )"; rc2=$?
  if [ "$rc1" != "$rc2" ]; then echo "FAIL - $desc  rc sh=$rc1 js=$rc2"; fails=$((fails+1)); rm -rf "$D1" "$D2" "$TX"; return; fi
  if [ "$O1" != "$O2" ]; then echo "FAIL - $desc  stdout differs:"; diff <(printf '%s\n' "$O1") <(printf '%s\n' "$O2") | head -8; fails=$((fails+1)); rm -rf "$D1" "$D2" "$TX"; return; fi
  if [ ! -f "$D1/.forge/loop.md" ] && [ ! -f "$D2/.forge/loop.md" ]; then
    echo "ok   - $desc  (rc=$rc1, no ledger written)"; rm -rf "$D1" "$D2" "$TX"; return; fi
  if ! diff -q "$D1/.forge/loop.md" "$D2/.forge/loop.md" >/dev/null 2>&1; then
    echo "FAIL - $desc  written loop.md differs:"; diff "$D1/.forge/loop.md" "$D2/.forge/loop.md" | head -8; fails=$((fails+1)); rm -rf "$D1" "$D2" "$TX"; return; fi
  echo "ok   - $desc  (rc=$rc1)"
  rm -rf "$D1" "$D2" "$TX"
}

s_noloop()     { mkdir -p "$1/.forge"; }
s_none()       { seed_loop "$1" none ""; }
s_none_ann()   { seed_loop "$1" "none  # off" ""; }
s_absent()     { mkdir -p "$1/.forge"; printf '# LOOP\nreplan-cap: 3\nwall: none\n' > "$1/.forge/loop.md"; }
s_delta()      { seed_loop "$1" 999999999 "0 · since: $SINCE"; members3 "$1"; }
s_accum()      { seed_loop "$1" 999999999 "1000 · since: $SINCE"; members3 "$1"; }
s_baseline()   { seed_loop "$1" 999999999 ""; members3 "$1"; }
s_exhausted()  { seed_loop "$1" 100 "0 · since: $SINCE"; members3 "$1"; }
s_cap_ann()    { seed_loop "$1" "999999999 # 상한" "0 · since: $SINCE"; members3 "$1"; }
s_cap_oct()    { seed_loop "$1" "0100" "0 · since: $SINCE"; members3 "$1"; }
s_cap_bad()    { seed_loop "$1" "abc" "0 · since: $SINCE"; }
s_since_bad()  { seed_loop "$1" 999999999 "0 · since: {ISO}"; }
s_crlf()       { mkdir -p "$1/.forge"; printf '# LOOP\r\nbudget-tokens: 999999999\r\nbudget-spent: 0 · since: %s\r\nwall: none\r\n\r\n## Tasks\r\n- alpha\r\n- beta\r\n' "$SINCE" > "$1/.forge/loop.md"; }
s_dupfield()   { seed_loop "$1" 999999999 "0 · since: $SINCE"; printf 'budget-spent: 777 · since: %s\n' "$SINCE" >> "$1/.forge/loop.md"; }
# ALL THREE members sealed — the case that exposes a first-member-only read (avg
# divisor 3 vs 1), invisible to any single-member fixture.
s_sealed3()    { seed_loop "$1" 6000 "0 · since: $SINCE"; members3 "$1"
                 seal "$1" 2026-08-19-alpha alpha; seal "$1" 2026-08-19-beta beta; seal "$1" 2026-08-19-gamma gamma; }
s_sealed1()    { seed_loop "$1" 6000 "0 · since: $SINCE"; members3 "$1"; seal "$1" 2026-08-19-alpha alpha; }
s_checkbox()   { seed_loop "$1" 6000 "0 · since: $SINCE"; printf -- '- [ ] alpha\n- [x] beta\n- `gamma`\n' >> "$1/.forge/loop.md"
                 seal "$1" 2026-08-19-alpha alpha; seal "$1" 2026-08-19-beta beta; }
s_suffix()     { seed_loop "$1" 6000 "0 · since: $SINCE"; members3 "$1"; seal "$1" 2026-08-19-fix-alpha fix-alpha; }

check "no loop.md (rc2)"                      s_noloop
check "budget none (bypass)"                  s_none
check "budget none + annotation"              s_none_ann
check "budget field absent"                   s_absent
check "delta sum + ledger write"              s_delta
check "accumulate onto prior spend"           s_accum
check "baseline stamps since"                 s_baseline
check "exhausted (rc3)"                       s_exhausted
check "cap with trailing annotation"          s_cap_ann
check "cap 0100 is base-10"                   s_cap_oct
check "cap unparseable -> BLOCKED (rc5)"      s_cap_bad
check "since placeholder -> BLOCKED (rc5)"    s_since_bad
check "CRLF loop.md"                          s_crlf
check "duplicated budget-spent (first only)"  s_dupfield
check "3 members, ALL sealed (avg divisor)"   s_sealed3
check "3 members, 1 sealed"                   s_sealed1
check "checkbox/backtick member notation"     s_checkbox
check "suffix collision is not a seal"        s_suffix

# transcripts-unreadable: run WITHOUT --transcripts so both derive it themselves
D1=$(mktmp); D2=$(mktmp); s_delta "$D1"; s_delta "$D2"
O1="$( cd "$D1" && HOME=/nonexistent/home bash "$SH" --now "$NOW" 2>&1 )"; rc1=$?
O2="$( cd "$D2" && HOME=/nonexistent/home node "$JS" --now "$NOW" 2>&1 )"; rc2=$?
if [ "$rc1" = "$rc2" ] && [ "$rc1" = 5 ]; then echo "ok   - transcripts-unreadable -> BLOCKED both (rc=5)"
else echo "FAIL - transcripts-unreadable  sh=[$rc1 $O1] js=[$rc2 $O2]"; fails=$((fails+1)); fi
rm -rf "$D1" "$D2"

printf '\nforge-loop-spend parity: %s\n' "$( [ "$fails" -eq 0 ] && echo 'all identical' || echo "$fails MISMATCH(es)" )"
[ "$fails" -eq 0 ] || exit 1
