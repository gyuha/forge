#!/usr/bin/env bash
# Parity test (ADR-0022): forge-hook-stop.sh and forge-hook-stop.js must, for the
# same state, produce the SAME exit code, the SAME stderr, and the SAME resulting
# drive.md. The script MUTATES the marker (it bumps `blocked`), so each twin runs
# in its OWN fixture copy and the written file is diffed too.
#
# The twins reach their verdict by DIFFERENT routes on purpose (bash seds the raw
# text; node parses structure), which is what makes this a real cross-check rather
# than two copies of one mistake — the failure mode that shipped a 1.928x
# over-count with 11/11 green (ADR-0022 amended 2026-08-20).
#
# Behavior is covered by forge-hook-stop.test.sh (run against BOTH twins). This
# file covers what a per-twin behavior run cannot: byte-identical side effects.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SH="$HERE/forge-hook-stop.sh"; JS="$HERE/forge-hook-stop.js"
fails=0
NOW=1787040000
SID="sess-abc-123"
PAYLOAD="{\"session_id\":\"$SID\",\"cwd\":\"/tmp\",\"hook_event_name\":\"Stop\"}"
mktmp() { mktemp -d "${TMPDIR:-/tmp}/fghsp.XXXXXX"; }

# check <desc> <seedfn> [payload-override]
check() {
  local desc="$1" seedfn="$2" pay="${3:-$PAYLOAD}"
  local D1 D2 E1 E2 rc1 rc2
  D1=$(mktmp); D2=$(mktmp); "$seedfn" "$D1"; "$seedfn" "$D2"
  E1="$( cd "$D1" && printf '%s' "$pay" | bash "$SH" --now "$NOW" 2>&1 >/dev/null )"; rc1=$?
  E2="$( cd "$D2" && printf '%s' "$pay" | node "$JS" --now "$NOW" 2>&1 >/dev/null )"; rc2=$?
  if [ "$rc1" != "$rc2" ]; then
    echo "FAIL - $desc  rc sh=$rc1 js=$rc2"; fails=$((fails+1)); rm -rf "$D1" "$D2"; return; fi
  if [ "$E1" != "$E2" ]; then
    echo "FAIL - $desc  stderr differs:"; diff <(printf '%s\n' "$E1") <(printf '%s\n' "$E2") | head -6
    fails=$((fails+1)); rm -rf "$D1" "$D2"; return; fi
  if [ ! -f "$D1/.forge/drive.md" ] && [ ! -f "$D2/.forge/drive.md" ]; then
    echo "ok   - $desc  (rc=$rc1, no marker)"; rm -rf "$D1" "$D2"; return; fi
  if ! diff -q "$D1/.forge/drive.md" "$D2/.forge/drive.md" >/dev/null 2>&1; then
    echo "FAIL - $desc  written marker differs:"; diff "$D1/.forge/drive.md" "$D2/.forge/drive.md" | head -6
    fails=$((fails+1)); rm -rf "$D1" "$D2"; return; fi
  echo "ok   - $desc  (rc=$rc1)"
  rm -rf "$D1" "$D2"
}

mk() { mkdir -p "$1/.forge"
  { printf '# DRIVE — unattended drive in progress\n'
    printf 'started: %s\n' "$2"; printf 'blocked: %s\n' "$3"; printf 'session: %s\n' "$4"
  } > "$1/.forge/drive.md"; }

s_none()      { mkdir -p "$1/.forge"; }
s_noforge()   { :; }
s_block()     { mk "$1" "$((NOW - 60))" 0 "$SID"; }
s_block_hi()  { mk "$1" "$((NOW - 60))" 9 "$SID"; }   # multi-digit -> 10
s_block_49()  { mk "$1" "$((NOW - 60))" 49 "$SID"; }  # last allowed block
s_cap()       { mk "$1" "$((NOW - 60))" 50 "$SID"; }
s_old()       { mk "$1" "$((NOW - 1801))" 0 "$SID"; }
s_edge_age()  { mk "$1" "$((NOW - 1800))" 0 "$SID"; } # exactly at the bound
s_other()     { mk "$1" "$((NOW - 60))" 0 "other"; }
s_garbage()   { mkdir -p "$1/.forge"; printf 'garbage\n' > "$1/.forge/drive.md"; }
s_crlf()      { mkdir -p "$1/.forge"
  printf '# DRIVE\r\nstarted: %s\r\nblocked: 3\r\nsession: %s\r\n' "$((NOW - 60))" "$SID" > "$1/.forge/drive.md"; }
s_extra()     { mk "$1" "$((NOW - 60))" 0 "$SID"
  printf 'note: a human comment the drive may add\n' >> "$1/.forge/drive.md"; }
s_dupfield()  { mk "$1" "$((NOW - 60))" 0 "$SID"; printf 'blocked: 77\n' >> "$1/.forge/drive.md"; }
s_future()    { mk "$1" "$((NOW + 120))" 0 "$SID"; } # clock skew -> negative age

check "no marker"                        s_none
check "no .forge/ at all"                s_noforge
check "in bounds -> block + bump 0->1"   s_block
check "multi-digit bump 9->10"           s_block_hi
check "last allowed block (49)"          s_block_49
check "at the iteration cap (50)"        s_cap
check "older than the age bound"         s_old
check "exactly at the age bound"         s_edge_age
check "another session's marker"         s_other
check "unparseable marker"               s_garbage
check "CRLF marker"                      s_crlf
check "marker with an extra field"       s_extra
check "duplicated blocked (first wins)"  s_dupfield
check "clock skew (started in future)"   s_future
check "payload without session_id"       s_block '{}'
check "payload is not JSON"              s_block 'not json at all'

printf '\nforge-hook-stop parity: %s\n' "$( [ "$fails" -eq 0 ] && echo 'all identical' || echo "$fails MISMATCH(es)" )"
[ "$fails" -eq 0 ] || exit 1
