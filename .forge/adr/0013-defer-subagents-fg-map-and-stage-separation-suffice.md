# 서브에이전트(explorer/retro-analyzer/verifier) 도입 보류

## Status
accepted (deferred — 재검토 바는 아래)

## 맥락
"긴 루프 동안 메인 스레드 컨텍스트가 오염된다"는 가설로, Claude Code 서브에이전트(격리 컨텍스트·요약만 반환) 3종 도입이 제안됐다: **explorer**(grilling 직전 코드/ADR/CONTEXT 맥락 JIT 수집), **retro-analyzer**(fg-learn용 plan↔run diff 분석), **verifier**(ADR-0009 검증 게이트용 UAT/테스트 실행). explorer가 "fg-map 자산 재활용 → 신규 복잡도 최소"라는 이유로 첫 PoC로 권장됐다.

## 결정
**지금은 셋 다 도입하지 않는다.** 추가 서브에이전트 없이 현행 구조를 유지한다.

## 결정 근거
- **explorer는 fg-map과 중복.** fg-map이 이미 코드베이스를 `.forge/codebase/`로 떠두고, fg-ask가 그릴링 전에 그 지도를 읽어 context rot를 완화한다(ADR-0001 계열). explorer가 더할 건 "지도에 없는 조각의 JIT fetch"라는 좁은 창뿐 — 4번째 에이전트류를 정당화하기엔 약하다.
- **루프가 이미 context rot를 구조로 완화한다.** 각 단계가 별도 스킬 호출(ask/run/learn/done)로 컨텍스트가 단계마다 갈리고, 상태 문서(plan/run/STATUS)는 작으며(실행자가 run.md에 이미 요약), fg-map이 코드 맥락을 덮는다. retro-analyzer가 겨냥한 "무거운 diff 분석"·메인 스레드 오염은 대부분 이 구조로 이미 해소돼 있어 투기적이다(YAGNI·Simplicity First).
- **verifier는 ADR-0009의 실제 통증을 못 고친다.** 그 통증의 정체는 "지시문 스킬은 런타임이 없어 `verified`가 n/a로 떨어짐"인데, verifier 서브에이전트는 없는 런타임을 만들어내지 못한다. 그 사각을 실제로 메운 것은 verifier가 아니라 **샌드박스 dogfood**(fg-merge 라이프사이클 e2e, 2026-06-09 `done`)였다. 즉 verifier는 통증의 원인을 빗나간다.

## 재검토 바 (이게 충족되면 그때 *그 하나만*)
투기적 일반론이 아니라 **구체적·재현된 통증**이 생기면 해당하는 하나만 만든다:
- 거대 `run.md`/계획으로 **fg-learn 컨텍스트가 실제로 압박**받는 사례 → 그때 **retro-analyzer**.
- **fg-run UAT의 테스트 출력이 수천 줄**이라 세션이 오염되는 사례 → 그때 **verifier**(테스트를 격리 실행하고 한 줄 evidence만 반환).
- explorer는 fg-map과 중복이라 재검토에서도 후순위 — 필요가 생기면 별도 에이전트보다 **fg-map 확장/재실행**을 먼저 검토.

## 고려한 대안
- **explorer 먼저(thin PoC)** — 거부: fg-map과 가장 겹쳐 "신규 복잡도 최소 = 신규 가치 최소". 패턴 증명용이라도 중복을 또 만드는 셈.
- **셋 다 도입** — 거부: 구체적 통증 없는 투기적 최적화. forge 루프가 이미 대부분 완화.
- **(채택) 보류 + 재검토 바 명문화** — 누군가(또는 미래의 같은 분석)가 "당연한 최적화"로 재제안할 때, 이 ADR이 거부 근거와 재검토 조건을 제시해 재그릴을 막는다.
