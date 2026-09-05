---
author: gyuha
decided: 2026-09-05 21:20
---
# fg-config 설정 통합 + simple 모드 — 자동 봉인이지 단계 생략이 아니다

## Status
accepted (supersedes the toggle-skill surface of ADR-0008 · ADR-0014 — 두 ADR의 *설정 의미론*(tdd·eco가 무엇을 켜는가)은 그대로 살고, *진입 표면*(fg-tdd·fg-eco 전용 토글 스킬)만 이 ADR이 대체한다)

## 맥락과 결정
GitHub 이슈 #18. 설정 토글이 항목당 스킬(fg-eco·fg-tdd)로 흩어져 있고, 새 설정 `simple`이 필요해졌다. 이슈가 정확히 지적했듯 "learn·done을 생략"은 문자 그대로는 성립하지 않는다 — fg-done의 봉인이 활성 슬롯을 비워야 다음 작업이 승격되므로, 생략하면 다음 fg-run이 재실행 가드에 걸린다.

**결정 1: `simple`은 생략이 아니라 자동 봉인 모드다.** `simple: true`면 fg-run의 작업 종료 핸드오프가 UAT(검증) 수행 → `retro: skipped (simple mode)` 기록(divergence 무관 무조건 — fg-next all·fg-loop과 같은 완화 계열) → 결정론 봉인 스크립트(forge-done) 호출까지 같은 턴에 잇는다. 사용자 체감은 ask → run 두 단계, 내부적으로는 verify·seal이 전부 돈다. **검증 게이트(ADR-0009)는 불가침** — `verified: pending|failed`면 자동 봉인하지 않고 종전대로 멈춰 알린다. Run all 배치도 동일하게 파킹 대신 작업별 즉시 봉인(`failed`는 활성 슬롯 잔류). fg-next/fg-loop은 이미 자동 봉인 계열이라 동작 불변. 기각한 대안: (b) 산출물 최소화 — fg-quick(ADR-0003)의 재포장, (c) fg-next 기본값화 — fg-run 직접 호출에 일관되지 않아 결국 같은 배선이 필요.

**결정 2: fg-config가 `config.json` 모든 키의 단일 진입점이 된다** (`simple`·`eco`·`tdd`·`driveCommit`·`driveCommitMessage`·`defaultBranch`). CLAUDE.md가 명시하던 "의도된 비대칭"(작업마다 토글하는 값만 전용 스킬)은 **항목당 스킬 비용**을 전제로 했고, 스킬 하나로 통합되는 순간 그 전제가 사라진다. `defaultBranch`는 브랜치 루트 해석에 걸리는 위험 키라 설정 시 경고 문구를 동반한다. 파일 직접 편집은 여전히 가능(스킬은 편의 표면이지 잠금이 아님). 옛 트리거(`eco on`·`TDD 켜` 등)는 fg-config의 description이 한/영 전부 흡수한다.

**부수 결정: `ECO.md`는 `skills/fg-config/ECO.md`로 이관**하고 참조를 전수 갱신한다 — "규율 문서는 소유 스킬 디렉터리에 한 벌"(FORGE-ROOT.md·DRIVE.md 선례) 관례 유지. SKILL.md 없는 `skills/fg-eco/` 잔존(빈 디렉터리)은 관례에 없는 형태라 기각. `skills/fg-tdd/`는 형제 문서가 없어 그냥 삭제. 스킬 개수는 22 → 21.

## 결과
- fg-run·RUN-ALL·fg-status·DRIVE에 `simple` 분기가 배선된다(이슈 #18의 3분할 작업, task #134–#136).
- 회고 완화 선례 계열(ADR-0002·0010·0016·0023·0026)에 "per-task 기본값" 한 칸이 추가되고, 검증 불가침 선언은 한 번 더 반복된다.
