<!-- auto-retro: fg-done all -->
# 2026-10-26 — `fg-verify` 스킬 도입(1/2): 스킬 본문·예시 반입·전역 예외·카탈로그 동기화

## Plan vs actual
- What went as planned: `skills/fg-verify/SKILL.md` 신설, pstack 기능 지도 예시 3파일 바이트 동일 반입, `.forge/verify/` 전역 예외 등재, 스킬 24→25·유틸리티 21→22·핸드오프 15→16 동기화. DoD 1–9 통과(doctor 0 warnings·138 passed, pi-host 25 skills, docs:build·release:check).
- Divergences:
  - 개수 finder(`24개|twenty-four|15곳|fifteen…`)가 대문자 `Twenty-four`, 숫자 리터럴 `>24<`, 헤딩 `(21)`, `Fifteen skills`, `Applies (15)`, `Nine wired sites`, "Twenty-one more", `all 24 skill names`, "24곳"을 놓쳐, 봉인 전 코드 리뷰가 9곳을 찾아냈다. DoD 7번(finder 0건)은 **통과했지만 아무것도 보증하지 못했다**.
  - doctor B18은 HANDOFF.md와 CONTEXT.md의 핸드오프 개수가 **함께 낡아 있어** 0 warnings로 통과했다(서로 같은지만 비교하는 검사의 fail-open).
  - 리뷰가 계약 결함 4건도 잡았다: 다중 표면 생성 경로 부재, 판별 수단이 없던 재시작 요구(루프는 파일을 읽어 따르면 되므로 철회), 시도 간에 섞이는 증거 경로(시도별 디렉터리로 바꾸고 FORGE-ROOT 한 곳에 정의), 원형 예시의 `artifacts/` 경로가 여는 커밋 진입로.
  - description 625자 → B16 warning → 549자로 줄였다.

## Learnings
- Do differently next time: 스킬 개수가 바뀌는 계획은 DoD finder를 대소문자 무시(`-i`)로 돌리고, 숫자 리터럴과 영문 서수(`Fifteen`·`Nine`)까지 넣는다. 그리고 "finder 0건"을 유일한 근거로 삼지 말고 HANDOFF.md의 `Applies (N)` 표와 landing 카드 수를 직접 센다. 더 근본적으로는 개수를 하드코딩하지 않거나 실측과 대조하는 doctor 검사가 필요하다(후속 후보로 등록).
- Do differently next time: "세션 시작 때 로드"(ADR-0024)를 새 스킬에 그대로 적용하기 전에, 루프가 그 스킬을 *호출*하는지 *파일로 읽는지*부터 확인한다. 읽기만 한다면 재시작 제약은 해당하지 않는다.
- Do differently next time: 원형 보존(vendoring)한 예시를 "형식의 단일 정의"로 지정할 때는, 예시 안의 경로·부작용이 forge의 위치 계약과 충돌하지 않는지 먼저 확인한다.
- Do differently next time: 여러 작업을 "모두 실행"으로 돌리면 둘 다 `executed/`로 넘어가 적대적 리뷰 대상에서 빠진다. 리뷰를 받을 작업은 하나씩 실행한다(이번 세션에서 두 번 반복됐다).

## Doc updates
- 미검토(자동 회고) — 승급 판단은 fg-learn 일괄 승급에서
