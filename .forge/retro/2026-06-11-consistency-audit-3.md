# 2026-06-11 — 3차 정합 감사 (v0.4.5 변경분 드리프트 점검·수정)

## Plan vs actual
- 계획대로 된 것: 커버리지 합의(A–D·F 전수 + E는 ADR-0015/fg-eco/v0.4.5 변경분 한정) 그대로 수행. 하이브리드 실행(감사 = 병렬 5 에이전트 워크플로우, 수정 = 메인 세션)도 계획대로. 발견 47건(fix-now 8 · record-only 5 · by-design 5 · ok 29), fix-now 전부 수정·record-only 전부 run.md 기록, non-goal 침범 없음, DoD(grep 재검증+JSON) 통과.
- Divergences:
  - **시드 1 재해석** — 계획은 "fg-learn에 STATUS `retro:` 뒤집기 단계가 누락됐을 것"으로 가정했으나, 감사 결과 'fg-learn은 안 건드리고 fg-done이 봉인 시 채운다'가 fg-run·fg-status·fg-done 3곳에 명시된 **by-design**이었다. 진짜 공백은 다른 3곳: 계약 주체인 fg-learn 자신의 침묵(B2·B3), fg-status 작업 테이블 Retro 열의 한-화면 자기모순(E9), 상태 머신 case 3 sealable 분기의 회고 검사 누락(B1) — 셋 다 수정.
  - **계획에 없던 fix-now 2건** — CLAUDE.md의 fg-tdd 전체 누락(A1: 12스킬 체제 전환 때 CLAUDE.md만 안 따라옴), fg-next 핸드오프의 ADR-0015 이전 stale 괄호(E5). 경계 규칙대로 즉시 수정.
  - **라이브 실증** — 이번 세션에서 에이전트가 STATUS에 어휘 밖 값(`retro: done (...)`)을 '친절하게' 써넣은 것이 정확히 B2가 경고한 실패 모드였다(봉인 시 fg-done close-out이 경로로 덮어써 자가 치유).

## Learnings
- Do differently next time:
  - **감사 시드는 가설로 적되 결론을 예단하지 말 것.** 시드를 "X가 누락됐을 것(없으면 명시)"처럼 수정을 전제해 적으면 감사를 그쪽으로 편향시킨다. "X 지점을 검증하라"로 적고 by-design 판정을 허용해야 한다 — 이번엔 감사 에이전트가 정직하게 by-design을 돌려줘 잘못된 수정을 피했다.
  - **계약은 의무 당사자 자신의 문서에 명시돼야 한다.** "fg-learn은 retro:를 안 건드린다"가 소비자 3곳(fg-run·fg-status·fg-done)에 적혀 있어도 주체인 fg-learn이 침묵하면 에이전트가 어긴다(이번 세션 실증). 소비자 쪽 문서만으로는 생산자의 행동을 못 막는다 — "단일 정의가 본문과 갈라진다" 반복 실패 모드의 변종. 계약을 적을 땐 모든 당사자, 특히 의무 주체에 적을 것.
  - (참고) 스킬 추가 시 CLAUDE.md 갱신 누락(A1)은 CONCERNS.md #2의 "스킬 추가 시 4곳 이상 수동 동기" 위험의 실현 사례 — 다음 스킬 추가 때 CLAUDE.md 루프 밖 스킬 목록도 체크 대상에 포함.
- 후속 후보 (record-only 5건, 상세는 run.md → 봉인 후 `.forge/done/2026-06-11-consistency-audit-3/run.md`): ① Run-all 배치 핸드오프의 ADR-0015 회색지대(E4 — fg-ask 그릴링감, 가장 무거움) ② fg-next all의 `retro: skipped` 기록 주체 모호(B4) ③ fg-quick LOG 라벨 정준 여부(B5) ④ fg-tdd의 자기 ADR-0008 미인용(D8) ⑤ README 트리거 현지화 방침 이원화(F9).

## Doc updates
- CONTEXT.md 승급: 없음 — 새 도메인 용어 없음.
- ADR 추가: 없음 — 이번 수정은 전부 기존 결정(ADR-0015·0002·0009·0010)의 정합 복구로, 새 트레이드오프 없음.
