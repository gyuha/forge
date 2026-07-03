# 무인 주행 연속성 — 턴 내 계속 강제 + /goal 주경로 + 공유 DRIVE.md

## Status
accepted

## 맥락
`fg-next all`(과 자매 `fg-loop`)이 "다음 단계 하나만 하고 중단"된다는 사용자 피드백. 근본 원인은 버그가 아니라 구조다: 스킬은 모델에게 주는 마크다운 지시문일 뿐이고, "턴"은 모델이 도구 호출을 멈추면 끝난다. 멈춤 지점은 셋이다 — (1) **소프트 양보**: 위임된 fg-run/fg-done의 **진술형 핸드오프**(ADR-0015: "다음은 X — 멈춤")를 오케스트레이터가 턴 경계로 오인해 양보(가장 흔함), (2) **비동기 경계**: 백그라운드 Dynamic Workflow 실행, (3) **사람 경계**: 워크플로우 스크립트 승인. (2)(3), 그리고 (1)의 잔여는 **Stop hook(`/goal`) 없이는 구조적으로 넘을 수 없고, 스킬은 `/goal`을 스스로 걸 수 없다(사용자만 침)**.

두 개의 불균형도 있었다: fg-loop에는 이미 "턴 사이 멈추지 마라"·"reliably enforced only by /goal"라는 강한 서술이 있었으나 **fg-next all에는 그 강제 문장이 없었다**(사용자가 겪은 바로 그 갭). 그리고 `/goal` 페어링 서술이 두 스킬에 중복돼 드리프트 위험(CLAUDE.md "알려진 불일치" 목록이 이미 그런 드리프트의 증거).

## 결정
1. **턴 내 계속 강제(best-effort).** 오케스트레이터(all-mode/loop)는 위임 스킬의 진술형 정지를 **턴 경계로 보지 않고** 즉시 다음 단계를 도출(fg-status 상태 머신)·실행한다. 봉인은 정지점이 아니다. 반복-메뉴 버그(ADR-0015) 재발 없음 — 구동은 **변하는 상태**(봉인→다음 승격)로 전진하지, 불변 상태에서 루프하지 않는다.
2. **`/goal`을 무인 주행의 operating premise·붙여넣기 주경로로.** 진입 시 정확한 정지-조건이 담긴 `/goal` 한 줄을 **주경로**로 제시하고, 그 붙여넣기가 진입 확인(재실행 방지 게이트)을 겸한다("go"/직접 진행도 확인). 별도 이중 게이트 없음.
3. **공유분을 `skills/fg-next/DRIVE.md` 한 벌로 추출.** 턴 내 계속(Part 1) + `/goal` 페어링·문구 규칙·정직한 폴백(Part 2)을 담고 fg-next(all)·fg-loop이 함께 참조한다(FORGE-ROOT.md와 동형의 "단일 정의·복붙 금지"). **각 레인은 자기 벽 집합을 스스로 채운다** — DRIVE.md는 중립 메커니즘만, 벽 목록은 각 SKILL.md(fg-next all의 4벽 vs fg-loop의 goal-met·tension·safety 등).

## 고려한 대안
- **스킬이 settings.json에 지속 Stop hook 자동 설치(완전 자동 /goal)** — 기각. `/goal`은 세션 범위·자동 해제 hook이지만 settings.json hook은 **영속**이라 이후 모든 턴의 정지를 막고, 구동이 예기치 않게 죽으면 hook이 남아 "멈춤 불가" 상태를 만드는 큰 발모(정리 취약). 강력함보다 위험이 크다.
- **인라인 중복 유지(공유 추출 안 함)** — 기각. 두 스킬에 같은 /goal 서술이 갈라져 드리프트(이미 fg-loop이 fg-next 섹션을 참조하는 반쪽 결합 상태였음).
- **현행 유지** — 기각. 사용자의 실제 고통이고, fg-next all이 fg-loop보다 약한 비대칭이 결함이었다.

## 결과
- fg-next all이 fg-loop 수준의 턴 내 연속성을 확보한다 — 작은/직접 실행 작업 백로그는 `/goal` 없이도 한 턴에 끝까지 비워진다.
- **정직한 한계 명문화**: 턴 내 계속은 best-effort(텍스트가 모델의 양보를 100% 못 막음), `/goal`이 reliable한 크로스-턴 보장. 어느 쪽도 "절대 안 멈춤"을 주장하지 않는다.
- **불변**: ADR-0015(위임 스킬은 *사람* 호출 시 여전히 진술-후-정지 — 바뀐 건 오케스트레이터의 해석뿐). ADR-0009/0010/0016의 벽·검증 게이트 전부 불변. 자동 hook을 기각했으므로 스크립트 승인은 여전히 사람이 필요한 정지점.
- README·`docs/skills.md`가 `/goal` 메커니즘을 처음으로 사용자 문서에 명시한다("looped until it needs you" 약속의 실제 메커니즘 노출).
- 교차참조: [ADR-0010](0010-fg-next-all-momentum-mode.md)(all-mode 정의 정밀화)·[ADR-0016](0016-fg-loop-goal-driven-bounded-replan.md)(fg-loop 공유분 이관)·[ADR-0015](0015-fg-run-handoff-menu-others-stated.md)(진술형 핸드오프 = 소프트 양보 원인, 불변)·[ADR-0011](0011-branch-isolated-forge-root.md)(FORGE-ROOT.md 공유문서 선례)·[ADR-0009](0009-verification-gate-before-seal.md)(검증 게이트 불변).
