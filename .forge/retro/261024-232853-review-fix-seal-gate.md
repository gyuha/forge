<!-- auto-retro: fg-done all -->
# 2026-10-24 — 적대적 리뷰 수정 ①: 봉인 스크립트의 회고 신호 게이트·판정 표식, 계획 린트 소제목 오탐

## Plan vs actual
- What went as planned: 신호가 있으면 `--skip-retro`를 거부(exit 4), 건너뛰기를 `skipped (judged: …)`로 기록, 린트 E3 오탐 1→0. forge-done 122/122·plan-lint 49/49, 패리티 OK.
- Divergences:
  - 스크립트는 언어와 무관해야 해서 신호 (b)(d)를 영문 헤딩 `## Failed attempts`·`## Rulings`로만 감지 → "이 두 헤딩은 번역하지 않는다"는 규칙을 #177에 추가.
  - 린트의 E3 출력 순서가 마커 오류 뒤로 바뀜(판정은 동일).

## Learnings
- Do differently next time: 스크립트가 읽을 문서 절은 "사용자 언어로 렌더"라는 기본 규칙과 충돌하는지 계획 단계에서 확인하고, 기계 판독 헤딩은 처음부터 영문 고정으로 정한다.

## Doc updates
- 미검토(자동 회고)
- CONTEXT.md promotion: none
- ADR added: none
