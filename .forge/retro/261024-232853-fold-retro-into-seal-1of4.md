<!-- auto-retro: fg-done all -->
# 2026-10-24 — 회고를 봉인에 흡수 ①: fg-done 0b·fg-learn 재정의·핸드오프 전환

## Plan vs actual
- What went as planned: fg-done 0b(신호 4종·기본 건너뛰기·대화형/무인 승급 차이), fg-learn의 루프 밖 일괄 승급 재작성, 핸드오프의 fg-done 전환. 완료 정의 7/7 충족.
- Divergences:
  - description에 판정 설명을 넣자 648자가 되어 doctor B16(600자) 경고 → 설명을 줄임.
  - RETRO-FORMAT의 자동 회고 규칙을 "fg-loop all 전용"에서 "무인 봉인 전부"로 미리 일반화(파트 3 몫을 파트 1에서 처리).
  - PLAN-FORMAT `retro-hint`의 의미가 바뀌어 계획 영향 위치에 없던 PLAN-FORMAT·fg-ask도 고침.
  - fg-ask STEP 0의 묻는 분기를 3개에서 2개로 합침(고-divergence도 무인 마감).

## Learnings
- Do differently next time: 루프 단계를 바꾸는 작업은 그 단계를 언급하는 형식 문서(PLAN-FORMAT·RETRO-FORMAT)까지 영향 위치에 넣고 시작한다. description 길이 상한(B16)은 계획 단계에서 미리 센다.

## Doc updates
- 미검토(자동 회고)
- CONTEXT.md promotion: none
- ADR added: none
