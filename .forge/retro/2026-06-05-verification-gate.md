# 2026-06-05 — 봉인 전 검증(UAT) 게이트 도입 (ADR-0009)

## 계획 대비 실제
- 계획대로 된 것: S1(fg-run §4 STATUS `verified: pending` + 핸드오프 UAT 3상태 yes/skipped/n/a, tdd 시너지), S2(fg-cleanup no-seal-without-verification 가드 + ASCII/Mermaid + closed STATUS verified 필드). 두 핵심 슬라이스는 계획대로.
- 차이(divergence — 작지 않음): 실행 후 `/codex:adversarial-review`를 반복하며 원 plan의 Non-goal(fg-status·README 제외)을 **의도적으로 번복**하고 같은 활성 슬롯에서 범위를 확장 — S3(fg-status: `verified` 읽기·Verify 컬럼·run→verify→learn→cleanup 라우팅·`executed/` 검증 회수), S4(README 양 언어 STATUS 계약 동기), Run-all 파킹 전 작업별 UAT, fg-run §4 검증-전용 재진입 분기(중복 실행 방지), `n-a`→`n/a` 토큰 정규화, **상태값 `failed` 신설**(pending=미검증·재개 / failed=검증했으나 깨짐·수정·재그릴), codebase 연료 문서(ARCHITECTURE.md) 동기화. 이 작업 자체는 문서 변경이라 `verified: n/a`.

## 학습
- **(헤드라인) 공유 상태 필드를 바꾸는 작업의 blast radius는 "그 상태를 읽는 모든 소비자"다.** 이번 plan은 검증 게이트를 *생산자/가드 단계*(fg-run·fg-cleanup)로만 스코핑했지만, adversarial review가 드러낸 건 STATUS 스키마/상태 enum을 바꾸면 그걸 **읽고 라우팅하는 fg-status**, **문서화하는 README·codebase 연료**까지 전부 따라와야 한다는 것이었다 — 안 그러면 미검증 작업이 fg-learn으로 오라우팅되거나, 공개 계약이 옛 상태를 가리킨다. 상태 계약 변경을 생산자 단계에만 스코핑한 건 체계적 과소-스코핑 오류였다.
- 다음에 다르게 할 것: **fg-ask 그릴링에서 "이 작업이 공유 상태(STATUS 스키마/enum/계약)를 건드리나?"를 명시 점검하고, 그렇다면 그 상태의 *소비자 전부*(읽는 스킬·라우팅하는 스킬·문서화하는 README/codebase)를 슬라이스에 처음부터 포함하라.** Non-goal로 빼기 전에 "이게 게이트 없이 일관되나"를 자문. 이번엔 사후 adversarial review가 잡아줬지만, 그릴링이 잡았어야 했다.
- **adversarial review가 *실행 후* 같은 슬롯에서 스코프를 키운 패턴 — 작동했으나 경계선.** forge 모델은 "중간 체크포인트 = 작업 분할"인데, 이번 확장은 사후 발견이라 in-slot으로 흡수했고 plan/run/ADR에 조정을 반영해 봉인 가능했다. 트레이드오프: 사후 확장이 *독립 봉인 가능한 큰 덩어리*였다면 새 작업으로 쪼개는 게 더 깔끔했을 수 있다. 다음에 사후 review가 큰 범위를 열면 "in-slot 흡수 vs 새 backlog 작업"을 의식적으로 판단할 것.
- `failed` 상태 신설은 enum이 "실행했으나 깨짐"을 표현 못 하던 실제 구멍을 메웠다 — pending(미검증)과 구분되는 비봉인 상태. 결정·전파는 ADR-0009에 기록됨(아래).

## 문서 갱신
- CONTEXT.md 승급: 없음 (`.forge/CONTEXT.md` 부재, `verified`/`failed`는 STATUS 계약의 구현 세부지 도메인 글로서리 용어 아님)
- ADR 추가: 없음 (신규) — 게이트·`failed` 상태 결정은 이번 그릴링 중 생성된 **ADR-0009**(`.forge/adr/0009-verification-gate-before-seal.md`)에 이미 포착됨
