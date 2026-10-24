<!-- auto-retro: fg-done all -->
# 2026-10-24 — 회고를 봉인에 흡수 ②: 상태 표시(status·statusline·훅·모니터)의 단계 이름 정리

## Plan vs actual
- What went as planned: 스크립트의 `learn` 단계 단어 21→0, 테스트를 red로 확인한 뒤 전부 green, 패리티 OK.
- Divergences:
  - 계획은 단계 단어만 다뤘지만 같은 뜻의 "awaiting retro" 문구와 doctor A3 안내도 바꿈.
  - 모니터 UI 실제 화면은 브라우저로 확인하지 않고 단위 테스트만 통과.
  - 이후 사용자가 이 작업이 정한 단계 이름 `seal`(봉인)을 "완료(`done`)가 원래 용어"라며 되돌리게 했다(ADR `261024-191024` 개정, 표에서는 `done`/`done ✔`로 구분).

## Learnings
- Do differently next time: 사용자에게 보이는 단계 이름을 바꿀 때는 기존 용어(여기서는 "완료")를 사용자에게 먼저 확인한다. 동작 이름(봉인)과 단계 이름(완료)을 구분해서 다룬다.

## Doc updates
- 미검토(자동 회고)
- CONTEXT.md promotion: none
- ADR added: none
