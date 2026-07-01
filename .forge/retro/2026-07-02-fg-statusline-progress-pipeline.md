# 2026-07-02 — fg-statusline: task 이름 + ask/run/learn/done 진행 파이프라인 2줄 상시 표시

## Plan vs actual
- What went as planned: S1~S5 전부 계획대로 완료(스크립트 2개 재작성, 테스트 3개 갱신, SKILL.md·ADR-0017 개정, 라이브 동기화). 워크플로우 없이 직접 처리한 판단도 적절했음 — 규모가 작아 서브에이전트 팬아웃이 오히려 오버헤드였을 것.
- Divergences:
  - 계획(S1)은 `forge-statusline.test.sh` 갱신만 명시했지만, 같은 출력 문자열을 그대로 하드코딩해 쓰던 `forge-statusline-wrapper.test.sh`의 fixture 2곳도 구식 포맷이라 함께 고쳐야 했다.
  - `verified: pending`으로 사용자 확인을 기다리던 중 "done 상태도 추가해달라"는 새 요청이 들어와, 3단계(ask/run/learn) 파이프라인을 4단계(+done, 항상 예정 표시)로 확장했다. plan.md는 건드리지 않고 run.md에 divergence로 기록.

## Learnings
- Do differently next time:
  - **출력 포맷을 하드코딩 문자열로 검증하는 스크립트를 고칠 때는, 그 포맷 문자열을 복붙해 쓰는 다른 테스트 파일까지 grep으로 찾아라.** 이번엔 계획에 명시된 파일만 고치고 넘어갔다가 래퍼 테스트에서 놓칠 뻔했다 — `forge-statusline.sh`처럼 여러 테스트 파일이 같은 출력을 assert하는 스크립트는 계획 단계에서 "이 포맷을 assert하는 파일 전부"를 먼저 grep해 슬라이스에 명시해두면 좋다.
  - **TUI/색상 표시 설계는 텍스트 미리보기의 한계가 크다.** `AskUserQuestion`의 preview도, Bash로 캡처한 ANSI 출력도 실제 색상을 보여주지 못했다(이 하네스의 도구 결과 캡처는 raw escape 코드를 그대로 노출). 색상이 걸린 TUI 기능을 그릴링할 땐 처음부터 "메커니즘은 말로 합의하고, 정확한 색상 값은 구현 후 실제 터미널에서 확인"으로 기대치를 맞추는 게 낫다 — 이번엔 이 판단을 잘 했다(plan의 Non-goals에 명시).
  - **검증(UAT) 대기 중 들어온 요구사항 추가는 plan.md를 고치지 말고 run.md에 divergence로 기록하며 그 자리에서 반영하는 게 맞다.** fg-run이 plan을 소유하지 않는다는 원칙과, 사소한 확장을 매번 fg-ask 재그릴링으로 되돌리는 오버헤드 사이에서, 이번처럼 작고 명확한 추가는 run.md 기록 + 즉시 반영이 실용적이었다. 단, 추가가 더 컸다면(예: 설정 가능한 스타일 시스템 도입) fg-ask 재그릴링으로 넘겼어야 했을 것 — 판단 기준은 "plan의 Non-goals를 뒤집는가" 여부.

## Doc updates
- CONTEXT.md promotion: none (새 도메인 용어 없음 — ask/run/learn/done은 이미 확립된 forge 루프 용어)
- ADR added: none (이번 회고 시점 추가 없음) — 단 `.forge/adr/0017-statusline-integration.md`가 **실행(fg-run) 중에** 이미 개정됨("## 개정 (2026-07-02)" 섹션 — 단일 세그먼트 → 2줄 상시 표시 + progress-dots 파이프라인, done 4번째 단계 포함).
