# 2026-09-07 — fg-debug vendoring과 적대적 리뷰가 드러낸 상태·eval·cleanup 계약 결함

## 계획 대비 실제
- 계획대로 된 것: vendored 3파일과 LICENSE가 원본 바이트를 유지했고, 래퍼·fg-run/PLAN-FORMAT 배선·22개 스킬 카탈로그가 착지했다. 작성 당시 DoD 9/9와 forge-doctor 0/0, 문서 빌드, release check가 모두 통과했다.
- 발산: 실행 중에는 `.codex-plugin/plugin.json`의 설명 형태가 계획의 전제와 달라 최소 확장이 필요했다. 실행 후 적대적 리뷰에서 major 5건·minor 2건이 발견됐고 사용자가 전부 승인했다. 특히 `verified: failed` 활성 슬롯에서 새 backlog plan을 만들면 기존 작업은 봉인 불가·새 plan은 승격 불가가 되어 교착했고, 일회성 red 명령을 영속 eval로 과대 보증했으며, 원인 미확정과 민감 캡처 cleanup 경로가 비어 있었다. HANDOFF의 `fourteen` 잔여와 CONTEXT의 13곳도 기존 grep DoD를 통과했다.

## 학습
- 다음에 다르게 할 것 ①: 새 유틸리티의 출구를 설계할 때 결과 종류만 나누지 말고 **진입 당시 활성 상태를 먼저 교차표로 검증한다**. 한 슬롯 모델에서 `verified: failed`는 봉인할 수 없으므로 “항상 새 fix-forward plan”은 실행 불가능한 경로가 된다.
- 다음에 다르게 할 것 ②: “기존 규칙을 by construction 만족한다”는 주장은 생산물의 종류까지 대조한다. red-capable 명령은 curl·trace·HITL일 수 있지만 eval은 프로젝트에 남는 영속 체크여야 한다. 참조는 규칙 복사가 아니라 **적용 여부의 명시적 판정**을 요구한다.
- 다음에 다르게 할 것 ③: 워킹 트리에 진단 산출물을 두는 결정에는 성공 경로만이 아니라 불확정·중단·경량 차선까지 포함한 cleanup 소유자가 필요하다. 민감 원본 캡처는 워킹 트리 밖 임시 위치에서만 다루고 모든 종료 경로에서 제거한다.
- 다음에 다르게 할 것 ④: 카탈로그 개수의 단순 양성 grep은 내부 모순을 잡지 못한다. canonical 선언 수·실제 열거 수·CONTEXT 수를 서로 대조하고, 새 스킬의 핵심 라우팅 계약도 값싼 doctor 검사로 영속화한다.

## 문서 갱신
- CONTEXT.md 승급: 새 용어 없음. 기존 `핸드오프 표` 적용 수를 15곳으로 교정.
- ADR 추가: 없음. `.forge/adr/260907-140655-fg-debug-vendored-diagnosis.md`를 상태 우선 라우팅·불확정 두 경로·안전한 산출물·doctor 영속 검사 결정으로 개정.
- eval 승급: `.forge/backlog/fg-debug-contract-hardening.md` 작업 #140에 B18 doctor 검사와 bash/Node parity 테스트를 TDD red→green slice로 적재.
