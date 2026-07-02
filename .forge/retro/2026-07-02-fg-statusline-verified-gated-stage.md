# 2026-07-02 — fg-statusline: 파이프라인 현재 단계 판정을 verified 게이트 기반으로 변경

## Plan vs actual
- What went as planned: S1~S3 전부 계획대로 완료. 새 3-way 게이팅 규칙(ask/run/learn)이 자동 테스트 36개 전부 green, 라이브 wrapper 확인까지 마쳤다.
- Divergences (낮음):
  - 테스트 기대값 하나(`verified-pending`)를 처음에 새 시맨틱에 맞게 안 고치고 넘어갔다가 테스트 실행이 즉시 FAIL로 잡아냈다.
  - plan에 없던 parity 테스트 케이스(`verified: failed`)를 하나 추가했다 — 이번 변경의 핵심 동작이라 bash/node 패리티를 명시적으로 검증해두는 게 맞다고 판단.
  - `fg-statusline/SKILL.md`의 "thin display twin" 서술이 이번 변경으로 부정확해진 걸 문서 갱신 중 발견 — fg-status의 Stage 컬럼(순수 파일 존재 기반)과 이 스크립트(verified까지 반영)가 이제 `verified: failed`/`pending` 상태에서 서로 다른 현재 단계를 보고할 수 있음을 명시적으로 적어뒀다.

## Learnings
- Do differently next time:
  - **"출력 포맷 변경 시 관련 테스트 파일 전부 grep" 교훈이 두 번째로 반복됐다.** 직전 fg-statusline 작업(2026-07-02, task #57)의 회고에서도 같은 패턴(계획에 명시된 파일만 고치고 넘어갔다가 다른 테스트 파일에서 놓칠 뻔함)이 나왔다. 이번엔 실제로 놓치진 않았지만(fixture 갱신은 계획대로 3개 파일 다 처리), 기대값 자체를 새 시맨틱에 맞게 안 고친 실수가 있었다 — 같은 계열의 "포맷 변경 시 연쇄 확인 누락" 리스크다. 두 번 연속이면 이 프로젝트에서 statusline류 출력 포맷을 바꾸는 작업의 **표준 체크리스트 항목**으로 굳혀도 좋을 만큼 반복성이 있다 — 다음에 또 나오면 CONVENTIONS성 문서나 PLAN-FORMAT.md에 짧게 남기는 걸 고려.
  - **fg-status와 fg-statusline의 "thin display twin" 관계가 이번 변경으로 완전한 미러가 아니게 됐다.** 앞으로 fg-status의 next-step 머신을 고칠 때, 이 스크립트가 이제 더 세분화된 판정(verified 반영)을 한다는 걸 인지하고 있어야 한다 — 다만 fg-status 자체를 지금 당장 맞출 필요는 없다고 판단(fg-status는 "버킷", 이 스크립트는 "지금 사람 손이 필요한 곳"이라는 다른 질문에 답하므로).

## Doc updates
- CONTEXT.md promotion: none (새 도메인 용어 없음)
- ADR added: none (이번 회고 시점 추가 없음) — `.forge/adr/0017-statusline-integration.md`가 **실행(fg-run) 중에** 이미 개정됨("## 개정 (2026-07-02, 2차)").
