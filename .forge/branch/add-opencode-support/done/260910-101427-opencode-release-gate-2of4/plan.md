<!-- forge-slug: opencode-release-gate-2of4 -->
<!-- task: 2 -->
<!-- part: 2/4 -->
<!-- priority: high -->
<!-- tdd: off -->
# 릴리스 게이트·doctor를 3호스트로 일반화 (하드코딩 제거)

## Goal / Non-goals
- Goal: `scripts/release-check.sh`/`.js`의 `for host in claude codex` 하드코딩을 제거해 `hosts/` 아래 실재하는 호스트 전부를 검사하게 만들고, opencode가 누락되면 **실제로 exit 1이 나는지** mutation test로 증명한다. 두 트윈의 패리티와 기존 21개 테스트 무손상 유지.
- Non-goals: 매니페스트 버전 범프. docs/README 갱신(태스크 3·4). 새 capability 키 추가. `hosts/` 밖 스크립트 리팩터.

## Source of truth
- Glossary terms: 릴리스 게이트, 스크립트 트윈 — .forge/CONTEXT.md
- Related ADRs: ADR-0022(sh/js 트윈 계약), ADR-0030/0031(스크립트가 판정, 산문은 라우팅)
- Definition of Done:
  1. `npm run release:check` → exit 0 (사전 상태: 태스크 1 완료 후에도 opencode를 아예 안 보므로 exit 0 — 그래서 이 항목만으로는 불충분하고 아래 2가 본 검사다)
  2. **mutation test**: `mv hosts/opencode/execution.md /tmp/oc-exec.md; npm run release:check; rc=$?; mv /tmp/oc-exec.md hosts/opencode/execution.md` 에서 `rc` = 1 이고 stderr에 `opencode` 문자열 포함 (사전 상태: rc=0 — 게이트가 opencode를 모름)
  3. `bash scripts/release-check.parity.test.sh` → exit 0 이고, 그 파일에 opencode 픽스처 케이스가 존재: `grep -c opencode scripts/release-check.parity.test.sh` ≥ 1 (사전 상태: 0)
  4. `for t in scripts/*.test.sh hooks/*.test.sh; do bash "$t" >/dev/null 2>&1 || echo "FAIL $t"; done` → 출력 0줄 (기준선 21/21 통과 — regression guard)
  5. `bash scripts/forge-doctor.sh` exit 0, 0 errors (regression guard)

## Work slices
- [ ] S1. `scripts/release-check.sh`의 호스트 목록을 `hosts/` 디렉터리에서 도출하도록 변경(정렬 안정화). 완료 기준: `hosts/`에 디렉터리를 추가하면 그 호스트가 자동으로 검사 대상이 됨 — DoD 2의 mutation test로 증명.
- [ ] S2. `scripts/release-check.js`에 동일 변경(트윈 패리티). 완료 기준: DoD 3 패리티 테스트 통과.
- [ ] S3. `scripts/release-check.parity.test.sh`의 픽스처에 opencode 호스트를 포함하고, "어댑터 파일 누락 → exit 1" 케이스를 추가. 완료 기준: DoD 3.
- [ ] S4. docs 지원표 검사(`docs/codex.md` 하드코딩)를 호스트별로 일반화할지 판정 — opencode 문서는 태스크 3에서 생기므로, 이 태스크에서는 **파일이 없으면 에러**가 되지 않도록 순서 의존을 정리하거나 태스크 3까지 유예되도록 처리. 완료 기준: DoD 1이 태스크 3 완료 전에도 exit 0.
- [ ] S5. `scripts/forge-doctor.{sh,js}`가 호스트 어댑터를 검사한다면 같은 일반화 적용, 안 한다면 손대지 않음(판정을 run.md에 기록). 완료 기준: DoD 5.
