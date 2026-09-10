<!-- forge-slug: opencode-readme-manifest-4of4 -->
<!-- task: 4 -->
<!-- part: 4/4 -->
<!-- priority: medium -->
<!-- tdd: off -->
# README 이중언어 + 매니페스트 설명에 opencode 반영

## Goal / Non-goals
- Goal: forge가 지원하는 호스트가 셋임을 사용자 진입 문서에 반영한다 — `README.md`·`README.ko.md`(번역 쌍 동시 갱신)와 3개 매니페스트의 사람이 읽는 설명. 무결성 검사 무손상.
- Non-goals: 버전 범프·CHANGELOG·release 커밋(배포 절차는 별개). 스킬 카탈로그 개수 변경. `marketplace.json`의 `metadata.description`(루프 정의 태그라인)에 호스트 목록을 끼워 넣는 것.

## Source of truth
- Glossary terms: 마켓플레이스 매니페스트
- Related ADRs: CLAUDE.md "README 이중 언어 동기화" 규약
- Definition of Done:
  1. `grep -ci opencode README.md` ≥ 1 (사전 상태: 0)
  2. `grep -ci opencode README.ko.md` ≥ 1 (사전 상태: 0)
  3. 두 README의 호스트 언급이 같은 절에 들어감: `grep -n -i 'codex' README.md | wc -l` 과 `grep -n -i 'codex' README.ko.md | wc -l` 이 갱신 후에도 서로 같음 (구조 대칭 확인)
  4. `node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json','.codex-plugin/plugin.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"` → `OK`
  5. `npm run release:check` exit 0 · `bash scripts/forge-doctor.sh` exit 0, 0 errors (regression guard)
  6. `for t in scripts/*.test.sh hooks/*.test.sh; do bash "$t" >/dev/null 2>&1 || echo "FAIL $t"; done` → 출력 0줄 (regression guard)

## Work slices
- [ ] S1. `README.md`의 호스트/설치 관련 절에 opencode 지원을 추가(스킬은 `.claude/skills/` 경로로 그대로 로드된다는 사실 포함). 완료 기준: DoD 1.
- [ ] S2. `README.ko.md`에 동일 변경을 같은 위치·같은 구조로 반영. 완료 기준: DoD 2·3.
- [ ] S3. `.claude-plugin/plugin.json`·`.claude-plugin/marketplace.json`의 `plugins[].description`·`.codex-plugin/plugin.json`의 설명 중 호스트를 열거하는 문장이 있으면 opencode를 포함하도록 갱신(없으면 손대지 않고 판정을 run.md에 기록). 완료 기준: DoD 4·5.
