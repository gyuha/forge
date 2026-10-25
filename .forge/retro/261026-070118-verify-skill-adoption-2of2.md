<!-- auto-retro: fg-done all -->
# 2026-10-26 — `fg-verify` 스킬 도입(2/2): 계획이 증명할 기능을 지목하고 UAT가 구동하는 루프 연동

## Plan vs actual
- What went as planned: fg-ask(DoD 지목·기능 파일 슬라이스·`fg-verify` 1회 제안), fg-run UAT(지목 journey 구동), PLAN-FORMAT(DoD 줄 형태) 조항 추가. DoD 1–5 통과.
- Divergences:
  - 봉인 전 코드 리뷰가 UAT 계약 결함 4건을 잡았다. (1) 구동 실패를 원인과 무관하게 `failed`로 기록 → 인증 만료만으로도 fg-loop가 멀쩡한 코드를 상한까지 제자리 수리할 수 있었다. "어디서 멈췄나"(Doctor 통과 여부)로 판정하도록 고쳤다: 통과 전이면 `pending`, 통과 뒤 불일치면 `failed`. (2) "무인 주행은 공짜로 혜택" 문장이 fg-verify의 무인 금지와 모순 → 생성과 구동을 구분했다. (3) 판별 수단 없는 재시작 분기 → 삭제. (4) 증거 경로·자체-ignore 규칙 중복 → FORGE-ROOT 참조로 바꿨다.

## Learnings
- Do differently next time: UAT가 새 실패 경로를 얻을 때는 "검증이 실행되지 못한 것"(환경·전제 미충족 → `pending`)과 "검증이 결함을 찾은 것"(`failed`)을 처음부터 갈라 쓴다. `failed`는 무인 수리를 부르는 신호이므로, 작업에 대해 알아낸 것이 없는 실패를 `failed`로 기록하면 엉뚱한 코드 수정이 자동으로 일어난다.
- Do differently next time: 한 스킬이 무인 주행을 금지할 때, 다른 스킬이 같은 행위를 무인 주행에 허용하는 문장을 쓰지 않는지 같은 작업에서 교차 확인한다. 금지의 이유가 "생성"인지 "구동"인지를 명시한다.

## Doc updates
- 미검토(자동 회고) — 승급 판단은 fg-learn 일괄 승급에서
