---
author: gyuha
decided: 2026-07-16
---
# 스킬 description은 이중 용도(메뉴 표시 + 자동-발동 트리거)이므로 트리거 코어로 간결하게

## 맥락
`/fg`를 치면 슬래시 메뉴가 각 스킬의 긴 `description`을 그대로 보여줘 "벽 같은 설명"으로 읽기 어려웠다(스샷 근거). claude-code-guide로 Claude Code 메커니즘을 검증한 결과: **메뉴는 `description`(+`when_to_use`)의 앞 1,536자를 표시**(하드 char cap)하고, **바로 그 `description`이 Claude가 언제 이 스킬을 자동 발동할지 판단하는 트리거 신호**이며, **표시용 별도 짧은 필드가 없다**(`name`은 표시 전용, 트리거 무관; `when_to_use`는 description에 이어붙어 같은 cap에 합산돼 메뉴 분리에 도움 안 됨). forge의 설명이 길었던 건 ADR 번호·상세 동작·근거·형제 대비 에세이를 description에 담았기 때문이다.

## 결정
`description`은 **이중 용도**(메뉴 표시 + 자동-발동 트리거, 같은 1,536자 cap 필드)이므로 **트리거 코어로 간결하게 유지**한다:
- **유지(트리거 코어)**: 무엇을 하나(1문장) · 언제 쓰나 + 트리거 문구(한국어 발화 포함) · 오발동 위험이 실제 있는 곳만 한 줄 형제 구분(fg-status↔fg-next, fg-done↔fg-cleanup↔fg-drop).
- **절단(→ SKILL 본문, 발동 시 로드)**: ADR-NNNN 참조 · 상세 동작/메커니즘 · 근거(rationale) · "consists of…" 에세이 · 모드/플래그 세부.
- **레버는 트림뿐**: `name`은 트리거에 안 쓰이고, `when_to_use`는 메뉴 분리에 도움 안 되며, `disable-model-invocation`은 forge가 의도한 자연어 트리거("eco on", "새 작업 시작")를 잃는다. 따라서 description 자체를 트리거 코어로 줄이는 것이 유일한 안전한 방법.

## 트레이드오프 · 근거
- **무작정 줄이면 깨진다**: description이 트리거 신호라, 트리거 문구·형제 구분을 지우면 자동 발동/구분이 약해진다. 트리거 코어를 지키고 **트리거가 아닌 문서-살만** 절단하면 안전 — forge의 긴 설명은 살이 대부분이라 트리거 코어를 건드리지 않고 크게 줄일 수 있었다.
- **실효는 행동 베팅**: 실제 자동-발동 정확도는 단발 테스트 불가(실사용에서 드러남). 각 트림이 what+when+트리거 문구+필요한 구분을 보존했는지 리뷰로 담보.
- **실용 목표 길이(소프트)**: 트리거 문구(특히 한국어)와 형제 구분을 보존하면 ~350자 미만은 대부분 비현실적. 18개를 1229/1139자 벽 → **279–591자**(완결·스캔 가능)로 절반 이하 축소 — 트리거가 많은 상위 스킬(fg-doctor 591·fg-agents/fg-adversarial-review 531·fg-statusline/fg-drop 501)이 500대에 안착.

## 결과 (Consequences)
- 18개 SKILL.md `description`을 트리거 코어로 트림(별도 작업 `skill-description-trigger-core-trim`). 매니페스트 카탈로그·CLAUDE.md 스킬목록은 `/fg` 메뉴 소스가 아니라 무변경.
- **fg-doctor description-길이 lint(후속 `fg-doctor-description-length-lint`)**가 이 규약을 강제 — 임계 초과 시 warning으로 재-비대화를 감지(임계값은 이 트림 **실측 최대 591 위**로 ~600에 잡아, 방금 트림한 description을 곧바로 flag하지 않게 한다).
