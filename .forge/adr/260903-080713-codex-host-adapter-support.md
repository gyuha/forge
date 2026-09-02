---
author: gyuha
decided: 2026-09-03 08:07
---
# forge를 Claude Code + Codex 두 호스트로 확장 — 어댑터 방식(ADR-0025 승계)

## Status
accepted — supersedes ADR-0025

## 맥락
[ADR-0025](./retired/0025-claude-code-only-defer-codex-port.md)는 forge를 **Claude Code 전용**으로 유지하고 Codex 포팅을 보류하되, **재검토 바**를 명문화했다: *"실사용자가 Codex에서 forge 루프를 반복적으로 요구하는 사례가 나타날 때"*, 그때 (a) 전면 도구 추상화 / (b) 방법론-only 두 길을 그릴한다.

**그 바가 충족됐다 — 실제 Codex 사용 수요가 생겼다.** 따라서 이 결정은 ADR-0025를 어긴 것이 아니라 ADR-0025가 지시한 절차를 밟은 것이다.

## 결정
ADR-0025의 **(a) 전면 도구 추상화**를 채택한다. 단 "superpowers식 전면 재작성"이 아니라 **얇은 어댑터 경계**로 한다:

- **호스트 중립 계약** `core/` 3파일 — `HOST.md`(어댑터 선택 규칙 + 능력표) · `EXECUTION.md` · `INTERACTION.md`.
- **호스트 어댑터** `hosts/<claude|codex>/` 3파일씩 — `interaction.md` · `execution.md` · `capabilities.json`.
- 어댑터가 소유하는 것은 **질문 방식·위임 방식·프로젝트 에이전트 로드·주행 계속·상태 UI 다섯 가지뿐**이다. 워크플로 의미론, `.forge/` 상태 계약, 결정론 스크립트, 게이트는 **한 벌만 존재**하고 갈라지지 않는다.
- 패키징은 `.codex-plugin/plugin.json`을 추가하되 `skills`가 `./skills/`를 가리켜 **같은 스킬 트리**를 로드한다(스킬 사본 0).
- 경로 해석은 `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}`로 통일한다.

## 결정 근거
- **재검토 바 충족.** ADR-0025가 요구한 "구체적·재현된 수요"가 실제로 생겼다. 투기적 일반화(ADR-0025가 거부한 것)가 아니라 확인된 수요에 대한 응답이다.
- **ADR-0025가 예상한 비용이 실제보다 컸다.** ADR-0025는 비용을 "도구 계층 전면 추상화 = superpowers식 재작성"으로 추정했으나, 실제로는 계약 3파일 + 어댑터 6파일이면 됐다. 스킬 본문은 대부분 그대로다.
- **깊이를 희생하지 않는다.** ADR-0025의 정체성 우려("최소공통분모로 깎으면 깊이가 희석된다")는 어댑터 경계로 회피한다 — Claude Code 어댑터는 Dynamic Workflow·`AskUserQuestion`·`agentType`을 종전대로 그대로 쓰고, 깎이는 것은 Codex 쪽 fallback뿐이다.
- **상태 계약은 원래부터 플랫폼 독립적이었다.** ADR-0025 스스로 "개념·상태는 이식 가능하다"고 적었다. 이 PR은 이식 가능했던 층은 그대로 두고 결합된 층에만 경계를 그었다.

## 고려한 대안
- **(b) 방법론-only 차선** — 거부: 수요가 "루프를 쓰고 싶다"이지 "규율만 손으로 따르겠다"가 아니었다. 자동 트리거가 없으면 forge의 재실행 방지·게이트가 사람 규율에 의존하게 된다.
- **Codex 전용 스킬 사본** — 거부: 22개 스킬의 이중 유지보수는 ADR-0025가 지목한 진짜 비용이며, 두 사본이 갈라지는 순간 상태 계약이 깨진다. `core/HOST.md`가 이를 명시적으로 금지한다.
- **`CLAUDE_PLUGIN_ROOT` 그대로 두기** — Codex가 호환용으로 같은 변수를 제공한다면 22파일 치환이 불필요했다(`core/HOST.md` 자신이 그 가능성을 적어 두었다). 확인되면 되돌릴 수 있는 값싼 결정이라 ADR 바를 넘지 않는다 — 아래 Consequences 참조.

## Consequences
- **기능이 비대칭이다, 그리고 그건 정직하게 문서화된다.** `fg-statusline`은 Claude 전용, `fg-agents`는 Claude `.claude/agents/` 카드만 생성, Codex 무인 연속 주행은 제한적. 어댑터 `capabilities.json`과 사용자 문서(`docs/codex.md`)가 **같은 선언의 두 형태**이며 항상 함께 갱신된다.
- **능력 선언은 보수적 기본값을 따른다 — 관측한 것만 `true`.** 미확인은 `false`이며, 모든 능력에 정의된 fallback(직렬 실행·번호 목록·명시적 정지)이 있으므로 도는 fallback이 없는 도구 호출보다 항상 싸다. `false`→`true`는 가정이 아니라 관측이고, `docs/codex.md`의 지원 표를 같은 변경에서 함께 고친다. 이 규율이 없으면 어댑터가 "제한적"이라 적어 둔 것을 JSON이 `true`로 주장하는 모순이 다시 생긴다(초기 어댑터에서 실제로 발생했다 — `prevent_stop`·`spawn_role`).
- **능력 이름은 `core/HOST.md` 표가 유일한 어휘다.** `capabilities.json`은 그 여덟 키만 쓰며, 스킬은 이름으로 능력을 지목해(`spawn_parallel`, `prevent_stop`) 기계적으로 조회한다. 표와 JSON이 다른 어휘를 쓰면 파일은 아무도 읽지 않는 죽은 설정이 된다.
- **버전 동기 지점이 3곳 → 4곳이 된다** (`.codex-plugin/plugin.json` 추가). `fg-doctor` B8과 `npm run release:check`가 게이트다. CLAUDE.md 배포 규칙도 함께 갱신됐다.
- **기둥 1은 근거를 유지한다.** "그릴링을 실행 워크플로우에 넣지 않는다"의 이유는 여전히 *위임 실행이 실행 중 사용자 입력을 못 받는다*이며, 호스트가 늘어도 사라지지 않는다.
- **어댑터 경계를 넘어 상태 모델을 복제하면 이 ADR이 무효가 된다.** 어댑터가 `.forge/` 의미론을 조금이라도 갖기 시작하면 ADR-0025가 옳았던 것이 된다.
- **미해결로 남는 것**: `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}` 치환이 정말 필요한지는 Codex에서 `CLAUDE_PLUGIN_ROOT` 제공 여부를 실측해야 확정된다. 제공한다면 22파일 치환과 `hooks.json`의 중첩 확장(비-POSIX 셸 경로 리스크)을 되돌리는 것이 더 단순하다.
