# forge에 설정 표면(.forge/config.json)과 선택적 TDD 모드를 도입한다

## Status
accepted

## 맥락과 결정
TDD를 옵션으로 켜고 끄며(영속 토글 커맨드), fg-ask 시작 때 물어보고, on이면 test-first로 개발하고 싶다는 요구가 나왔다. 이를 위해 두 가지를 도입한다:

1. **설정 표면 `.forge/config.json`** — forge엔 지금까지 "설정" 개념이 없었다(상태는 전부 작업 파일). TDD 같은 *프로젝트 영속 기본값*을 담을 git 추적 JSON 설정 파일을 신설한다(`.gitignore` 화이트리스트 `!.forge/config.json`, lazy 생성, 기본 `{"tdd": false}`). 향후 설정도 여기로 확장. CONTEXT/adr/retro/codebase와 같은 "영속·추적" 위상.
2. **선택적 TDD 모드** — 다음 3축으로:
   - **토글**: 전용 스킬 `fg-tdd on|off`(인자 없으면 현재 상태 표시)가 config.json의 `tdd`를 쓴다. 루프 밖 유틸리티.
   - **per-task 의향**: fg-ask가 그릴링 시작 때 config.json의 tdd를 기본값으로 "이 작업 TDD로?"를 묻고, plan에 `<!-- tdd: on|off -->` 마커로 기록(평소처럼 ask에서 정하고 run에서 enact).
   - **실행**: fg-run이 plan의 tdd가 on이면 test-first로(각 슬라이스: 실패하는 테스트 먼저 → 구현 → 통과; 완료 기준에 통과 테스트 포함). 이식성 위해 fg-run에 test-first 규율을 자체 기술하고, `superpowers:test-driven-development` 등 외부 역량은 선택적 보강(하드 의존 없음 — deep-research·code-review 패턴 동일).

## 트레이드오프 / 결정 근거
- **설정은 JSON(.md 아님)** — tdd 같은 기계 판독 설정엔 JSON이 적합(매니페스트 JSON 검증 관례와도 부합). 사람이 읽는 영속 문서(CONTEXT/adr/retro)는 .md, 구조적 설정은 .json으로 구분.
- **git 추적(팀 공유)** — "이 프로젝트는 TDD를 쓴다"는 팀 기본값이라 추적. 개인 오버라이드는 per-task 마커로.
- **마커 인플레이션 인지** — `tdd:`는 plan의 5번째 마커(task·retro-hint·priority·part 다음). 회고가 두 번 경고한 사안이나, per-task 오버라이드(전역 토글 + 시작 시 질문 둘 다 요구)엔 불가피. 단 config 기본값으로 대부분 자동 결정돼 실사용 부담은 낮음.
- **큰 작업이라 3 part로 분할**(ADR-0004 part-plan): part1 설정+fg-tdd / part2 fg-ask 질문+마커 / part3 fg-run test-first. 각 독립 봉인 가능, 소프트 순서.

## 고려한 대안
- 설정 파일 없이 per-task만 — 거부: "영속 토글 커맨드" 요구 미충족.
- 로컬(gitignore) 설정 — 거부: 팀 기본값 공유 안 됨.
- TDD를 새 루프 단계로 — 거부: TDD는 실행 방식이지 단계가 아님. fg-run 실행 방식으로 흡수.
- 외부 TDD 스킬 하드 의존 — 거부: 이식성. 자체 기술 + 선택적 보강.
