#!/usr/bin/env bash
# Fixture-based tests for forge-plan-lint.sh — deterministic plan.md structure
# lint (task superlite-improvements-1of3). Covers the exit contract (0 pass ·
# 1 errors · 2 no input) and every language-neutral check: forge-slug, slices,
# duplicate slice ids, dangling depends, marker formats, the fix-forward `eval`
# marker (PLAN-FORMAT.md fix-forward eval rule) and the missing-task warning.
#
# Run:  bash scripts/forge-plan-lint.test.sh   (or FGPLINT_IMPL=.../forge-plan-lint.js)

set -u
SCRIPT="${FGPLINT_IMPL:-$(cd "$(dirname "$0")" && pwd)/forge-plan-lint.sh}"
pass=0; fail=0
mktmp() { mktemp -d "${TMPDIR:-/tmp}/fgplint.XXXXXX"; }
assert()      { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s exp:[%s] act:[%s]\n' "$1" "$2" "$3"; fi; }
assert_grep() { if printf '%s' "$2" | grep -qF "$3"; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL %s (%s not in output)\n' "$1" "$3"; fi; }
assert_nogrep() { if printf '%s' "$2" | grep -qF "$3"; then fail=$((fail+1)); printf '  FAIL %s (%s unexpectedly in output)\n' "$1" "$3"; else pass=$((pass+1)); fi; }

run_lint() {
  case "$SCRIPT" in
    *.js) OUT="$( node "$SCRIPT" "$@" 2>&1 )"; RC=$? ;;
    *)    OUT="$( bash "$SCRIPT" "$@" 2>&1 )"; RC=$? ;;
  esac
}
T=$(mktmp); trap 'rm -rf "$T"' EXIT
P="$T/plan.md"
# A clean plan in the user's language: headings are prose, only markers/slices are checked.
good() { printf '%s\n' '<!-- forge-slug: add-export -->' '<!-- task: 7 -->' '<!-- tdd: off -->' '# 내보내기 추가' '' '## 작업 단위' \
  '- [ ] S1. 버튼 추가 — 완료 기준: 보임' '- [ ] S2. 저장 — 완료 기준: 파일 생김 (depends: S1)'; }

# --- clean plan -> exit 0, no findings ----------------------------------------
good > "$P"; run_lint "$P"; assert "clean-rc0" 0 "$RC"; assert_nogrep "clean-noerr" "$OUT" "ERROR"; assert_nogrep "clean-nowarn" "$OUT" "WARN"
# --- no argument / unreadable -> exit 2 ---------------------------------------
run_lint; assert "noarg-rc2" 2 "$RC"
run_lint "$T/missing.md"; assert "missing-rc2" 2 "$RC"
# --- E1 forge-slug not on the first line -> error -----------------------------
{ printf '# title\n'; good; } > "$P"; run_lint "$P"; assert "E1-rc1" 1 "$RC"; assert_grep "E1-msg" "$OUT" "ERROR E1"
# --- E2 no slices -> error ----------------------------------------------------
printf '%s\n' '<!-- forge-slug: x -->' '<!-- task: 1 -->' '# t' '목표만 있음' > "$P"; run_lint "$P"; assert "E2-rc1" 1 "$RC"; assert_grep "E2-msg" "$OUT" "ERROR E2"
# --- E3 duplicate slice id -> error -------------------------------------------
{ good; printf '%s\n' '- [ ] S2. 또 S2 — 완료 기준: x'; } > "$P"; run_lint "$P"; assert "E3-rc1" 1 "$RC"; assert_grep "E3-msg" "$OUT" "ERROR E3 S2"
# --- E4 depends on an unknown slice -> error ----------------------------------
{ good; printf '%s\n' '- [ ] S3. 후속 — 완료 기준: x (depends: S1, S9)'; } > "$P"; run_lint "$P"; assert "E4-rc1" 1 "$RC"; assert_grep "E4-msg" "$OUT" "ERROR E4 S3->S9"
# --- E4 negative: multi-ref depends that all exist -> clean -------------------
{ good; printf '%s\n' '- [x] S3. 후속 — 완료 기준: x (depends: S1, S2)'; } > "$P"; run_lint "$P"; assert "E4ok-rc0" 0 "$RC"
# --- E5 marker formats -> error (one per bad marker) ---------------------------
for bad in 'task: 7a' 'tdd: yes' 'priority: urgent' 'part: 3/2' 'part: 0/2' 'part: 1-2'; do
  { good; printf '<!-- %s -->\n' "$bad"; } > "$P"
  run_lint "$P"; assert "E5-rc1 [$bad]" 1 "$RC"; assert_grep "E5-msg [$bad]" "$OUT" "ERROR E5"
done
printf '%s\n' '<!-- forge-slug: x -->' '<!-- task: 2 -->' '<!-- priority: high -->' '<!-- part: 2/3 -->' '# t' '- [ ] S1. a — 완료 기준: b' > "$P"
run_lint "$P"; assert "E5ok-rc0" 0 "$RC"
# --- E6 fix-forward plan without eval marker -> error -------------------------
{ good; printf '<!-- generated-by: fg-adversarial-review -->\n'; } > "$P"; run_lint "$P"; assert "E6-rc1" 1 "$RC"; assert_grep "E6-msg" "$OUT" "ERROR E6"
# --- E6 negative: eval points at an existing slice -> clean -------------------
{ good; printf '%s\n' '<!-- generated-by: fg-loop -->' '<!-- eval: S2 -->'; } > "$P"; run_lint "$P"; assert "E6ok-rc0" 0 "$RC"
# --- E6 negative: eval none with a reason -> clean ----------------------------
{ good; printf '%s\n' '<!-- generated-by: fg-security -->' '<!-- eval: none — exploit repro must not be committed -->'; } > "$P"; run_lint "$P"; assert "E6none-rc0" 0 "$RC"
# --- E7 eval points at an unknown slice -> error ------------------------------
{ good; printf '%s\n' '<!-- generated-by: fg-debug -->' '<!-- eval: S5 -->'; } > "$P"; run_lint "$P"; assert "E7ref-rc1" 1 "$RC"; assert_grep "E7ref-msg" "$OUT" "ERROR E7"
# --- E7 eval none without a reason -> error -----------------------------------
{ good; printf '%s\n' '<!-- generated-by: fg-debug -->' '<!-- eval: none -->'; } > "$P"; run_lint "$P"; assert "E7none-rc1" 1 "$RC"; assert_grep "E7none-msg" "$OUT" "ERROR E7"
# --- an eval marker mentioned mid-line (prose/backticks) is NOT a marker ------
{ good; printf '%s\n' '<!-- generated-by: fg-loop -->' '- 메모: 마커는 `<!-- eval: S2 -->` 형태다'; } > "$P"; run_lint "$P"; assert "midline-rc1" 1 "$RC"; assert_grep "midline-msg" "$OUT" "ERROR E6"
# --- playbooks (PLAN-FORMAT.md "Playbooks", ADR 261025-005132) ----------------
# A three-slice plan in the user's language; refactor fixtures vary only the depends.
pb() { printf '%s\n' '<!-- forge-slug: pb -->' '<!-- task: 9 -->' "<!-- playbook: $1 -->" '# 플레이북' '' '## 작업 단위' \
  '- [ ] S1. 동작 고정 — 완료 기준: 테스트 통과' "- [ ] S2. 구조 이동 — 완료 기준: 고정 green$2" "- [ ] S3. 정리 — 완료 기준: 고정 green$3"; }
# bug-fix: same eval obligation as a generated-by fix-forward plan (the fg-ask entry)
pb bug-fix '' '' > "$P"; run_lint "$P"; assert "PB-bugfix-noeval-rc1" 1 "$RC"; assert_grep "PB-bugfix-noeval-msg" "$OUT" "ERROR E6"
{ pb bug-fix '' ''; printf '%s\n' '<!-- eval: none — 재현이 사람 손을 거쳐야만 일어난다 -->'; } > "$P"; run_lint "$P"; assert "PB-bugfix-none-rc0" 0 "$RC"
{ pb bug-fix '' ''; printf '%s\n' '<!-- eval: S1 -->'; } > "$P"; run_lint "$P"; assert "PB-bugfix-eval-rc0" 0 "$RC"
# refactor: a pin marker is required
pb refactor ' (depends: S1)' ' (depends: S1)' > "$P"; run_lint "$P"; assert "PB-refactor-nopin-rc1" 1 "$RC"; assert_grep "PB-refactor-nopin-msg" "$OUT" "ERROR E8"
{ pb refactor '' ''; printf '%s\n' '<!-- pin: none -->'; } > "$P"; run_lint "$P"; assert "PB-pin-none-noreason-rc1" 1 "$RC"; assert_grep "PB-pin-none-noreason-msg" "$OUT" "ERROR E8"
{ pb refactor '' ''; printf '%s\n' '<!-- pin: none — 기존 스냅샷 테스트가 이미 동작 전체를 고정한다 -->'; } > "$P"; run_lint "$P"; assert "PB-pin-none-reason-rc0" 0 "$RC"
{ pb refactor ' (depends: S1)' ' (depends: S1)'; printf '%s\n' '<!-- pin: S7 -->'; } > "$P"; run_lint "$P"; assert "PB-pin-missing-slice-rc1" 1 "$RC"; assert_grep "PB-pin-missing-slice-msg" "$OUT" "ERROR E8"
{ pb refactor ' (depends: S1)' ' (depends: S1)'; printf '%s\n' '<!-- pin: S1, S2 -->'; } > "$P"; run_lint "$P"; assert "PB-pin-malformed-rc1" 1 "$RC"; assert_grep "PB-pin-malformed-msg" "$OUT" "ERROR E8"
# refactor: every other slice must depend on the pin, directly or through another slice
{ pb refactor ' (depends: S1)' ' (depends: S2)'; printf '%s\n' '<!-- pin: S1 -->'; } > "$P"; run_lint "$P"; assert "PB-pin-transitive-rc0" 0 "$RC"; assert_nogrep "PB-pin-transitive-msg" "$OUT" "ERROR"
{ pb refactor ' (depends: S1)' ''; printf '%s\n' '<!-- pin: S1 -->'; } > "$P"; run_lint "$P"; assert "PB-pin-order-rc1" 1 "$RC"; assert_grep "PB-pin-order-msg" "$OUT" "ERROR E9 S3"
# unknown playbook value, and more than one playbook marker -> E5
pb feature '' '' > "$P"; run_lint "$P"; assert "PB-unknown-rc1" 1 "$RC"; assert_grep "PB-unknown-msg" "$OUT" "ERROR E5 playbook: feature"
{ pb bug-fix '' ''; printf '%s\n' '<!-- eval: S1 -->' '<!-- playbook: refactor -->' '<!-- pin: S1 -->'; } > "$P"; run_lint "$P"; assert "PB-two-rc1" 1 "$RC"; assert_grep "PB-two-msg" "$OUT" "ERROR E5"
# no playbook marker -> a pin marker alone imposes no order (only its value is checked)
{ good; printf '%s\n' '<!-- pin: S1 -->'; } > "$P"; run_lint "$P"; assert "PB-pin-without-playbook-rc0" 0 "$RC"
# --- W1 missing task marker -> warning only, exit 0 ---------------------------
good | grep -v 'task:' > "$P"; run_lint "$P"; assert "W1-rc0" 0 "$RC"; assert_grep "W1-msg" "$OUT" "WARN W1"
# --- slice variants used by real plans are recognised (no false E2) --------
for v in '- [ ] **S1. 굵게** — 완료 기준: x' '- **S1 — 대시형** 완료 기준: x' '### S1 제목형' '- [x] S1: 콜론형'; do
  printf '%s\n' '<!-- forge-slug: v -->' '<!-- task: 1 -->' '# t' "$v" > "$P"; run_lint "$P"; assert "variant-rc0 [$v]" 0 "$RC"
done
# --- prose that merely mentions S1 is not a slice ----------------------------
printf '%s\n' '<!-- forge-slug: v -->' '<!-- task: 1 -->' '# t' '본문에서 S1을 언급' '- S1x 는 슬라이스가 아님' > "$P"; run_lint "$P"; assert "prose-E2" 1 "$RC"
# --- a note heading that names a list-item slice is not a second slice (no false E3)
printf '%s\n' '<!-- forge-slug: v -->' '<!-- task: 1 -->' '# t' '- [ ] **S3.** 본문 — 완료 기준: x' '### S3 실행 시 주의' '메모' > "$P"; run_lint "$P"; assert "note-heading-rc0" 0 "$RC"; assert_nogrep "note-heading-noE3" "$OUT" "ERROR E3"
# --- headings still count as slices when the plan has no list-item slices ------
printf '%s\n' '<!-- forge-slug: v -->' '<!-- task: 1 -->' '# t' '### S1 제목형' '### S2 다음 (depends: S1)' > "$P"; run_lint "$P"; assert "heading-only-rc0" 0 "$RC"
printf '%s\n' '<!-- forge-slug: v -->' '<!-- task: 1 -->' '# t' '### S1 a' '### S1 b' > "$P"; run_lint "$P"; assert "heading-only-dup-E3" 1 "$RC"
# --- CRLF line endings are tolerated ------------------------------------------
good | sed 's/$/\r/' > "$P"; run_lint "$P"; assert "crlf-rc0" 0 "$RC"

printf '\nforge-plan-lint: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
