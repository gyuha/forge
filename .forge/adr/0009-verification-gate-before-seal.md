# 봉인 전 검증(UAT) 게이트 — fg-run 핸드오프 확인 + fg-cleanup 가드

## Status
accepted

## 맥락과 결정
forge는 지금까지 **회고 완료**면 봉인했지(no-seal-without-retro), **검증됨**이면 봉인하는 게 아니었다. fg-run의 계획-검증(§3)은 "계획대로 만들었나"를 보고 조건부 코드리뷰(ADR-0007)는 품질을 보지만, **"이게 목표를 실제로 달성·동작하나"를 사람이 확인하는 단계가 없어** 한 번도 동작 확인 안 된 작업이 done으로 봉인될 수 있었다(GSD verify-work / superpowers verification-before-completion이 메우는 지점).

그래서 **검증 게이트**를 도입한다 — 회고 게이트와 평행한 골격:
- **fg-run 핸드오프 UAT** — 워크플로우는 실행 중 사람 입력을 못 받으므로, 실행 후 (대화형) 핸드오프에서 plan의 목표/Definition of Done에 대고 "실제로 동작하나?"를 사람에게 확인하고 결과를 STATUS `verified:` 필드에 기록. 순서는 run → verify → learn → cleanup.
- **fg-cleanup 가드** — `verified:`가 봉인 가능 상태가 아니면 봉인 차단(no-seal-without-verification), 회고 게이트와 동일. 봉인 가능 = `yes`/`skipped`/`n/a`; 차단 = `pending`·`failed`.
- **상태(봉인 통과 3 + 차단 2)**:
  - 통과 — `yes`(사람이 동작 확인) / `skipped (사유)`(확인 가능하나 의도적 waiver) / `n/a (사유)`(확인할 런타임이 없음 — 예: 문서만 변경. forge 자신의 작업 다수가 이 경우).
  - 차단 — `pending`(아직 미검증 — 초기값 또는 핸드오프 중단) / `failed (사유)`(UAT를 수행했으나 목표 미달 — 수정·재그릴 대상). `pending`(검증 자체를 안 함)과 `failed`(검증했고 깨졌음)는 라우팅이 다르다: 전자는 UAT 재개, 후자는 수정/재그릴.
  - "미확인 봉인"·"확인 불가"·"확인했으나 실패"를 정직하게 구분한다.

## 결정 근거 / 트레이드오프
- `verified:`는 **STATUS 필드**(상태 동반 마커)이지 plan 마커가 아니다 → 마커 인플레이션(task·retro-hint·priority·part·tdd)과 무관.
- **새 루프 단계 없음** — code-review·TDD와 같은 이유로 fg-run/fg-cleanup에 흡수(4단계 보존).
- **건너뛰기 허용(사유 기록)** — retro-skip과 동일한 절제·정직 패턴. 강제하지 않되 감사 가능.
- **TDD 시너지** — tdd on이면 통과한 테스트가 `verified: yes`의 근거가 된다(중복 수작업 회피).
- **증거-우선 `yes` (보강).** `yes`는 단순 통과 표시가 아니라 **어떻게 확인했는지를 한 줄 증거로 동반**한다(돌린 명령·관찰한 출력, 예: `yes (npm test → 42 passing)`) — `n/a (사유)`·`skipped (사유)`와 동형. "사람이 그렇다고 했다"에만 기대지 않고 실제로 무엇을 확인했는지를 남겨, superpowers `verification-before-completion`의 "증거 먼저, 주장은 그 위에서" 규율을 흡수한다. TDD 모드에선 통과한 슬라이스 테스트가 곧 그 한 줄 증거다. **트레이드오프**: 전면 명령-출력 덤프가 아니라 **한 줄 경량**을 택한다 — 덤프는 인플레이션·소음이 되고, 한 줄이면 "주장만 적힌 yes"를 막기에 충분하다. `n/a`·`skipped`·`failed`는 그대로다(`n/a`는 댈 증거가 없고, `skipped`는 사유가 핵심, `failed (사유)`는 이미 "어떻게 깨졌나"를 포함).

## Legacy(이전 봉인 작업)
이 게이트 도입 전 `done/`에 봉인된 작업은 `verified:` 필드가 없다. 이들은 `verified: n/a (legacy pre-ADR-0009)`로 백필한다. 따라서 `done/` 이력에서 `verified:` 누락 = 게이트 실패가 아니라 legacy 데이터다(fg-status도 done의 `—`를 legacy로 해석). 활성/파킹 작업의 `pending`/누락과는 의미가 다르다.

## 고려한 대안
- fg-cleanup 봉인 시점에서만 확인 — 거부: 실행 직후가 아닌 봉인 단계라 메모리 식음.
- 새 단계 fg-verify — 거부: 4단계 루프·상태 계약 건드림.
- 2상태(yes/skipped) — 거부: '문서라 확인 불가(n/a)'와 '건너뜀'을 못 가림.
