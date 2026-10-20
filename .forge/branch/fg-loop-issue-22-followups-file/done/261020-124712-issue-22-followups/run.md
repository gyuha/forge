# 실행 결과 — 후속 후보 원장과 JSON 상태 조회

- S1 후속 후보 저장·상태 전이·봉인 수집 — ✅ 계획대로
- S2 전체 작업·원시 상태·loop·후속 후보 JSON — ✅ 계획대로
- S3 브랜치 원장과 run/retro 마커 task 재매핑 — ✅ 계획대로
- S4 모든 생산/소비 경로 및 양언어 문서 연결 — ✅ 계획대로

## 검증: baseline → after
- 후속 후보: 원래 HEAD에서 신규 동작 테스트 실패(도구 없음) → node scripts/forge-followups.test.js PASS. 저장/종결 상태 보존/비정상 입력 비파괴/봉인 게이트/재시도/Unicode/브랜치 분리 확인.
- JSON: 원래 HEAD의 --json은 텍스트를 반환해 JSON.parse 실패 → node scripts/forge-status.json.test.js 12 parity/behavior checks PASS. 전체 완료 이력, 이유 문자열, 특수문자, 루프/후보, 빈 상태 확인.
- 기존 봉인: 109/109 → 109/109, done parity PASS.
- 기존 통합: 72/72 → 72/72. merge parity 36 사례 및 추가 내용·비파괴·재수집 20 검증 PASS.
- 기존 status parity: PASS → PASS; --table 텍스트 호환 유지.
- release:check: PASS → PASS (0.9.6 버전 유지). 매니페스트 JSON 파싱 PASS.
- npm run docs:build PASS; git diff --check PASS. 양언어 스킬/상태 문서와 README 동기화 검토.
- 브라우저: 양언어 새 절의 #followups 링크 유효, 이미지/관측 자산 실패 없음. 다크 모드 Mermaid 20개 노드 최소 명암비 10.17:1. 스크린샷 API 시간 초과 후 DOM/computed style로 확인.

## 검토에서 반영한 수정
- 통합 시 원장만 재매핑하면 아카이브 마커의 옛 task가 재수집과 충돌한다. snapshot도 동일 매핑으로 바꾸고 replay fixture 추가.
- Unicode slug, task 선행 0, CRLF와 내장 CR, JSON 제목 공백, 원장 symlink/디렉터리 오류 처리의 트윈 호환 수정.
- 새 한국어 앵커를 명시적 #followups로 고정하여 Unicode 정규화 차이를 피함.

## 범위 및 남은 제한
- 과거 자유 제목 기록 전체 자동 이관은 하지 않는다. 봉인 대상의 후보 의미 판별은 스킬, 명시적 마커 수집은 스크립트가 담당한다.
- 실제 새 후속 후보 없음. 후보가 없을 때 원장을 만들지 않는 lazy 규칙을 유지한다.
- 기존 main 작업 폴더의 무관한 변경은 보존하고 이슈 연동 배포는 임시 체크아웃에서 통합한다.
