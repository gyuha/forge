# 2026-06-11 — fg-run 메뉴 4지화("회고 후 봉인까지") + Run-all 배치 핸드오프 진술형

## Plan vs actual
- 계획대로 된 것: 4슬라이스(S1 ADR-0015 개정 섹션 / S2 fg-run 4지 메뉴+RUN-ALL 진술형·헤더 / S3 fg-next skip 기록 귀속 / S4 "3지" 전수 동기화) 전부 완료. 합의대로 워크플로우 없이 직접 처리, DoD 정적 grep 전수 통과. 그릴링이 의미론 분기(4번째 옵션 해석)·탈출 조건·ADR 형식(제자리 개정)을 전부 사전 해소해 실행은 순수 전사였다.
- Divergences: 미세 1건 — fg-run L136 "proceed to the three points below"(옛 3불릿 핸드오프 구조 잔재)를 편집 중 발견해 함께 정리(계획 밖 1줄, 같은 클래스).

## Learnings
- Do differently next time:
  - **키워드 grep 인벤토리는 숫자-단어 드리프트를 놓친다.** S4 사전 인벤토리(`3지|three-way|3-way`)는 같은 클래스의 "the three points below"를 못 잡았다 — 구조 변경 작업의 동기화 sweep은 키워드 grep에 더해, 바뀐 구조를 참조하는 문장을 의미 단위로 한 번 훑을 것(특히 수사·서수 표현: three points, 세 가지, both 등).

## Doc updates
- CONTEXT.md 승급: 없음 — 새 도메인 용어 없음.
- ADR 추가: 없음(회고에서) — 핵심 결정은 실행 슬라이스 S1에서 ADR-0015 개정 섹션으로 이미 기록됨.
