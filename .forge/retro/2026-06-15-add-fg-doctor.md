# 2026-06-15 — fg-doctor 도입 (harness engineering health check 적용)

## Plan vs actual
- What went as planned:
  - fg-doctor(루프 밖 읽기 전용 무결성 검사) 도입 — ADR-0019, SKILL.md(검사 그룹 A 6 + B 7항목), 매니페스트(스킬 16), CLAUDE.md(+fg-statusline 누락 보완), README 이중언어. 4슬라이스 모두 plan대로.
  - dogfooding UAT — 막 만든 fg-doctor의 문서 정합 검사(B7~B13)를 자기 자신으로 돌려 전부 green, B11이 이번에 보완한 CLAUDE.md 누락을 입증(검사가 의도대로 작동).
- Divergences:
  - **Codex 적대적 리뷰로 [high] 결함 발견·봉인 전 즉시 수정.** fg-doctor SKILL.md가 "checks the resolved root's branch only"라 적어 ADR-0011 영속 문서 오버레이 계약과 충돌했다 — 비-기본 브랜치에서 B13 ADR 검사가 top-level ADR을 놓치거나 branch cross-ref를 dangling으로 오판. check-group별 스코프 분리(그룹 A 휘발=branch root만 / B13 ADR=top-level+branch 오버레이·active+retired 결합 / B7~B12 repo-root=branch 무관)로 수정.
  - Codex [medium] "버전 미범프"는 결함 아님 — 미배포 상태(봉인 후 별도 배포 단계에서 범프).

## Learnings
- Do differently next time:
  - **`.forge/` 영속 문서(ADR/CONTEXT/retro)를 읽는 새 스킬을 작성할 땐 ADR-0011 FORGE-ROOT 브랜치 오버레이를 처음부터 명시하라.** 이게 두 번 연속 반복된 패턴이다 — 직전 fg-adversarial-review는 "활성 슬롯 vs parked" 스코프를 틀렸고(Codex가 잡음), 이번 fg-doctor는 "branch root only vs 오버레이"를 틀렸다(Codex가 잡음). 상태/문서를 읽는 스킬의 기본 체크리스트: (1) 휘발 상태 = resolved branch root, (2) 영속 문서 = 비-기본 브랜치에서 top-level + branch root 오버레이(branch wins), (3) 전역 예외(config.json·codebase/)는 항상 top-level. 새 스킬 grilling(fg-ask) 때 이 세 줄을 점검 항목으로.
  - **새 스킬/계약 도입 직후 외부 적대 리뷰(Codex/fg-adversarial-review)를 거는 것이 두 번 연속 값어치를 입증했다.** 자기가 쓴 산출물의 계약 스코프 오류는 스스로 놓치기 쉽다 — 새 스킬은 봉인 전 한 번 적대 검토를 기본 절차로 삼을 만하다.
  - **dogfooding은 health check류 스킬의 가장 강한 UAT다.** fg-doctor를 자기 자신으로 돌려 동작 검증 + 현 상태 건강을 한 번에 확인했고, 이번에 고친 결함(CLAUDE.md 누락)이 바로 그 검사로 입증됐다.

## Doc updates
- CONTEXT.md promotion: none (새 도메인 용어 없음)
- ADR added: ADR-0019(fg-doctor 도입) — 작업 중 생성. branch 오버레이 수정은 ADR-0019/0011 범위 내라 추가 ADR 불필요.
