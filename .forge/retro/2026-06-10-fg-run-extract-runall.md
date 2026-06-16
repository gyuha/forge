# 2026-06-10 — fg-run progressive disclosure (Run-all 추출) (일괄 승급 2026-06-16)

## Plan vs actual
- What went as planned: 3슬라이스 — Run-all 절차를 `skills/fg-run/RUN-ALL.md`로 추출(스텁 참조), §3 조건부 리뷰 압축(가드 보존·filler만 제거), rule census로 핵심 가드 19/19 (SKILL ∪ RUN-ALL) 무손실 확인.
- Divergences: 1건(중요) — 크기 목표 미달. S3 완료기준 "≤22000자(≥20%)"는 낙관적 추정이었고 실제는 28061→24579자(**-12%**)가 천장. 잔여 본문은 전부 매 호출 필요한 코어라 plan의 비목표("0 삭제·가드 trim 금지")가 더 줄이는 걸 금함 → 안전 제약이 수치 목표를 이김(비목표 우선).

## Learnings
- Do differently next time:
  - **토큰/크기 절감의 수치 목표는 "안전 제약 하에서의 천장"으로 잡아야 한다.** 20%는 콘텐츠 총량 기준 추정이었지만 "0 삭제·가드 유지" 제약 하에서 빼낼 수 있는 only-sometimes 콘텐츠(=Run-all)만 한정돼 12%가 실제 천장. perf 목표를 적을 땐 "삭제 없이 빼낼 수 있는 only-sometimes 분량"을 먼저 가늠해 means-추정치 과대를 피할 것.
  - **progressive disclosure는 공통 경로만 가벼워지고 드문 경로는 합계 동일** — 절감의 진짜 가치 = "호출 빈도 × 평소 미사용 분량". 어떤 콘텐츠를 빼낼지 고를 때 이 곱이 큰 것(fg-run에선 Run-all: 자주 호출되지만 Run-all은 드묾)을 후보로.

## Doc updates
- CONTEXT.md promotion: none
- ADR added: none (분리 사유는 RUN-ALL.md 헤더에 기록, 새 아키텍처 결정 아님)
