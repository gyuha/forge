# 2026-06-14 — fg-statusline: forge 진행 상태를 statusline에 띄우는 통합

## Plan vs actual
- What went as planned: 4슬라이스(테스트→스크립트→스킬→매니페스트/README)를 워크플로우 없이 직접 test-first로 완주. 스크립트 15/15 fixture 테스트 green, 라이브 실행 `⚒ fg-statusline-integration:run` 정확. 매니페스트 두 description 동기·`metadata.description` 불변·README 양쪽 동기 전부 검증 통과.
- Divergences (낮음):
  - 테스트 하니스 버그 1건(브랜치 케이스에서 `.forge/` 생성 전 config.json 쓰기) → red 단계에서 드러나 `mkdir -p` 선행으로 즉시 수정. **TDD가 실제로 회귀를 잡은 사례.**
  - 테스트 케이스를 계획보다 강화(slug 파일명 폴백·비-기본 브랜치 최상위 무시 등 총 15케이스).
  - loop 프리픽스를 idle 상태에도 표시하도록 결정(loop.md 존재 시 작업 없어도 `⚒ 🔁 rN/cap` — 주행 중임을 더 정확히 알림).

## Learnings
- Do differently next time:
  - **호스트 통합 기능은 호스트 사실 조사를 설계 분기 전에 전부 앞당겨라.** statusline 메커니즘 1차 조사 후 그릴링 도중 "`${CLAUDE_PLUGIN_ROOT}` 가용성 + 플러그인 경로 안정성" 2차 조사가 필요해졌고, 그 결과(경로 불안정 → 설정 시 복사)가 전달 모델 결정을 뒤집었다. 두 조사를 한 번에 묶었으면 그릴링이 덜 끊겼다. → 다음 호스트 통합 작업(훅·MCP·슬래시명령 등)에선 "이 기능을 호스트가 어떻게 노출/제약하는가"를 단일 조사 배치로 먼저 확정하고 설계 질문을 시작할 것.
  - **얇은 두 번째 상태 판독자는 정본과의 동기 결합을 남긴다.** `scripts/forge-statusline.sh`의 bucket→stage 매핑은 `fg-status/SKILL.md` Task table의 표시 트윈이다. 그 매핑이 바뀌면 양쪽을 같이 고쳐야 한다(ADR-0017 Consequences에 기록). fg-status 상태 머신 수정 시 이 스크립트도 점검 대상.
  - **statusLine 셸 cwd 가정은 미검증으로 남았다.** 스크립트가 `$PWD` 기준 `.forge/`를 읽는데, 호스트가 다른 cwd에서 실행하면 래퍼가 stdin JSON의 cwd를 추출해 `cd`하는 폴백이 필요. SKILL.md "Notes & assumptions"에 명시했고, 실제 터미널 통합은 사용자가 fg-statusline 실행 후 눈으로 확인해야 최종 검증됨.
  - forge에 **첫 실행 코드(bash)와 첫 테스트 인프라**가 들어왔다 — 두 기둥(문서=연료, no-code)의 경계 있는 예외(fg-quick 선례와 동형). 이 예외 범위가 넓어지지 않도록 후속 작업에서 경계를 지킬 것.

## Doc updates
- CONTEXT.md promotion: none (새 도메인 용어 없음 — "statusline fragment"는 구현 개념)
- ADR added: ADR-0017 (fg-ask 그릴링 단계에서 이미 기록 — statusline 통합: 첫 런타임 스크립트 + 얇은 두 번째 상태 판독자)
