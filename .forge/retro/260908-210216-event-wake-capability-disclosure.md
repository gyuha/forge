# 2026-09-08 — event_wake: 확정-클릭 즉시 반영이 Claude Code 전용임을 capability로 공개

## 계획 대비 실제
- 계획대로 된 것: 7슬라이스 전부 착지, DoD 12/12. TDD의 red가 실측됐다 — `core/HOST.md` 표에 행 하나만 넣은 시점에 `release-check` 두 트윈이 `hosts/{claude,codex}/capabilities.json missing keys: event_wake`로 rc=1, S2 뒤엔 `docs/{,en/}codex.md does not name capability keys: event_wake`만 남아 S3를 강제했다. 그릴링의 핵심 결론("키를 만들면 공개가 기계 강제된다")이 실행에서 증명됐다. 실행은 워크플로우 대신 이 세션 직접 순차(슬라이스 11개 전부 텍스트 편집 + 결정론 검증, 사용자 승인).
- 발산: **S5 범위 확장** — 계획은 fg-showme SKILL/VISUAL의 폴백 문장 2개를 "Monitor가 없으면"에서 `event_wake` 사전 조회로 바꾸는 것이었는데, capability를 소비하는 다른 스킬(fg-next·fg-loop)의 관례인 `**Host contract**` 문단을 신설하고 시작 절차 문장·흐름도·Behavior 3·Constraints까지 5+2곳이 됐다. 슬라이스 의도 안이고 문자열이 아니라 **행동**(장전 전 조회·false면 URL 메시지에서 1회 고지·화면마다 반복 금지)이 서술됐는지 확인했다. 그 외: 실행 중 다른 세션이 v0.8.7을 배포했으나(`d1db622`) 승격 시점 베이스라인 재측정이 작성 시점과 정확히 일치해 영향 없음.

## 학습
- 다음에 다르게 할 것:
  1. **"capability 키를 명명하는 스킬 ↔ `**Host contract**` 문단" 정합을 기계로 잡는다.** 지도 갱신 때 arch 매퍼가 실측한 사실: 키를 명명하는 스킬 7개, 문단을 가진 스킬 10개, 두 집합이 다르다(`fg-config`는 `structured_choice`를 쓰는데 문단 없음 · `fg-done`/`fg-learn`/`fg-status`는 문단은 있는데 키를 안 명명). 이번 S5가 fg-showme에서 정확히 이 구멍을 손으로 메웠고, 새 소비 스킬마다 재발한다. 기계 확인 가능·재발 구조적·저렴 → **eval 승급**. sh·js 트윈 + 픽스처라 인라인은 크므로 백로그 plan으로 적재한다(사용자 확인).
  2. **capability 신설의 실제 사이트 수는 grep으로 열거하고 나서야 안다.** 그릴링 때 "10파일이 wake를 언급"을 세고 `prevent_stop` 선례로 계약면+글로서리로 범위를 좁혔다 — 랜딩(`docs/index.html:312`)까지 잡힌 건 열거 덕이다. PLAN-FORMAT의 "종류가 아니라 사이트를 열거" 규칙이 또 값을 냈다.
  3. **개수 문장은 실측으로 센다.** "8개 키"·"eight keys"를 각 1곳으로 짐작했는데 실측은 ko 2·en 2였다. DoD를 실측 사전값으로 적었기 때문에 편집이 어긋나지 않았다.
  4. **capability를 소비하는 스킬을 고칠 땐 메커니즘 이름(`Monitor`)이 아니라 키(`event_wake`)로 말한다.** HOST.md가 능력을 명명하는 층이라, "도구가 없으면"은 런타임 발견이고 "키가 false면"은 사전 조회다 — 사용자가 겪은 통증("안 되는 걸 몰랐다")은 이 둘의 차이였다.

## 문서 갱신
- CONTEXT.md 승급: 없음 — `Visual Companion` 항목은 S6에서 **정정**(호스트 조건 추가)했고 새 용어 승급이 아니다.
- ADR 추가: `260908-200753-event-wake-capability` (S7, 실행 중 작성 — 고려한 대안 4건·결과 3건).
- Eval: 위 학습 1 → 백로그 plan 적재 예정(fg-ask).

## 후속 작업 후보
- **fg-doctor 검사: capability 키 명명 ↔ Host contract 문단 정합** — 양방향(키를 쓰면 문단 필수, 문단이 있으면 키를 명명). 현재 위반 3+1건을 같은 plan이 고친다.
- Codex에서 `event_wake`를 `true`로 뒤집는 조건은 task 142가 결론지음 — push형 어댑터 구현 + Codex 세션 실측은 별개 fg-ask.
