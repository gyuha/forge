# 2026-06-05 — 큰 작업을 순서 힌트 가진 part-plan들로 분할 (fg-ask/fg-run/PLAN-FORMAT)

## 계획 대비 실제
- 계획대로 된 것: 3슬라이스(PLAN-FORMAT 분할 규칙 확장 · fg-ask Output · fg-run 메뉴) 모두 계획대로 직접 편집 완료. 우회·중단 없음.
- 차이(divergence): 없음. 핵심 결정은 그릴링 중 ADR-0004로 인라인 기록됨.

## 학습
- 다음에 다르게 할 것: **forge 불변식을 깨지 않고 확장할 땐 하드 메커니즘이 아니라 *선택적·소프트 마커*를 얹는다** — 이번 세션에서 세 번 반복된 메타 패턴이다. retro-skip(STATUS `retro:` 필드, 자동 아님)·priority(`priority:` 마커, 자동선택 없음)·part(`part:` 소프트 순서, 하드 의존 거부). 매번 "기존 계약(한 plan=한 워크플로우=한 봉인, 백로그 독립)은 그대로 두고, 그 위에 비구속 신호만 추가"로 풀었다. 강제/자동 메커니즘(`after:` 차단, 자동 선택, 숫자 임계값)은 그때마다 불변식 위반·큐 잠김·부정확을 이유로 거부했다.
- 후속 주의: plan 마커가 셋(`retro-hint`·`priority`·`part`)으로 늘었다. 다음에 마커를 더하기 전에 "정말 소프트/선택적인가, 기존 마커와 의미가 겹치지 않나"를 PLAN-FORMAT에서 한 번 점검할 것. 마커 인플레이션은 그 자체로 복잡도다.

## 문서 갱신
- CONTEXT.md 승급: 없음 (forge 내부 메커니즘은 글로서리 비대상)
- ADR 추가: 없음 — 분할 결정은 이번 그릴링에서 ADR-0004(`.forge/adr/0004-split-oversized-tasks-into-ordered-parts.md`)로 이미 기록됨
