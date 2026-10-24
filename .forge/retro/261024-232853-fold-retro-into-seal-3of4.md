<!-- auto-retro: fg-done all -->
# 2026-10-24 — 회고를 봉인에 흡수 ③: 무인 경로(fg-next all·fg-loop·simple)의 회고 규칙 통일

## Plan vs actual
- What went as planned: 무인 경로의 "자동 건너뜀" 서술 제거, fg-loop `all`·`retro:` 필드 하위 호환 유지.
- Divergences:
  - fg-loop이 직접 쓰던 자동 회고 절차를 fg-done 0b로 넘기고, fg-loop에는 제자리 수리 기록 전달만 남김.
  - 완료 정의 5(DRIVE.md `fg-learn` ≤ 1)가 잘못 세운 기준이었다 — 남은 5곳은 링크 경로·역사 설명 등 정당한 언급.
  - 범위 밖 스킬 5곳의 같은 서술도 함께 고침.

## Learnings
- Do differently next time: "단어 개수 ≤ N" 완료 정의는 링크 경로·역사 설명처럼 남아야 하는 언급을 먼저 세어 기준선에 반영한다. 문구 단위 grep(예: `auto-skip`)이 단어 단위보다 의도를 잘 잡는다.

## Doc updates
- 미검토(자동 회고)
- CONTEXT.md promotion: none
- ADR added: none
