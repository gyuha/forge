# Codex에서 forge 사용하기

forge는 Claude Code와 Codex가 **같은 `skills/`와 `.forge/` 상태**를 사용하도록 구성돼 있다. 작업 규칙을 두 벌로 복제하지 않고, 질문과 서브에이전트 실행처럼 호스트마다 다른 부분만 `hosts/` 어댑터로 분리한다.

## 설치와 호출

저장소에는 Codex 매니페스트인 `.codex-plugin/plugin.json`이 포함돼 있다. Codex의 로컬 Marketplace에 이 저장소를 추가하고 플러그인을 설치한 다음, 새 작업을 시작해 스킬을 다시 로드한다. 플러그인 훅은 설치만으로 신뢰되지 않으므로 내용을 검토한 뒤 허용해야 한다.

| 목적 | Claude Code | Codex |
| --- | --- | --- |
| 계획 시작 | `/forge:fg-ask` | `$fg-ask` |
| 계획 실행 | `/forge:fg-run` | `$fg-run` |
| 다음 단계 실행 | `/forge:fg-next` | `$fg-next` |
| 상태 확인 | `/forge:fg-status` | `$fg-status` |
| 무결성 검사 | `/forge:fg-doctor` | `$fg-doctor` |

자연어 트리거도 동일하다. 예를 들어 “forge로 새 작업 시작”이라고 말하면 `fg-ask`가 선택될 수 있다.

## 공유 코어와 어댑터

```text
.claude-plugin/plugin.json ─┐
                            ├─▶ skills/ + scripts/ ─▶ 같은 .forge/ 상태
.codex-plugin/plugin.json ──┘
                                  │
                                  ├─ hosts/claude/
                                  └─ hosts/codex/
```

- `core/HOST.md`: 호스트 판별과 capability 선택 규칙
- `core/INTERACTION.md`: 질문·선택·확인의 공통 계약
- `core/EXECUTION.md`: 직렬/병렬 실행과 결과 수집의 공통 계약
- `hosts/codex/`: Codex의 입력 및 collaboration/subagent 실행 방식
- `hosts/claude/`: Claude Code의 `AskUserQuestion` 및 Dynamic Workflow 방식

스크립트 경로는 `PLUGIN_ROOT`를 우선하고 `CLAUDE_PLUGIN_ROOT`로 fallback한다. 따라서 두 호스트가 동일한 결정론 스크립트를 실행한다.

## 현재 지원 범위

| 기능 | Codex 상태 | 설명 |
| --- | --- | --- |
| 핵심 루프 (`fg-ask` → `fg-run` → `fg-learn` → `fg-done`) | 지원 | 동일한 상태 전이와 검증·봉인 규칙 사용 |
| 상태/도구 (`fg-status`, `fg-doctor`, `fg-quick`, `fg-tdd`) | 지원 | 공통 스크립트와 스킬 사용 |
| 독립 작업 병렬 실행 | 지원 | Codex collaboration/subagent 도구가 없으면 직렬 fallback |
| SessionStart 알림 | 지원 | `hooks/hooks.json` 기본 탐색; 사용자가 훅을 검토하고 신뢰해야 함 |
| `fg-next all`, `fg-loop` 무인 주행 | 제한적 | Stop 훅의 재진입 동작은 호스트별 차이가 있어 감독 실행 권장 |
| `fg-agents` 프로젝트 역할 생성 | 제한적 | 현재 생성 포맷이 `.claude/agents/` 중심이므로 Codex 전용 materialize는 후속 작업 |
| 선택 메뉴 (structured choice) | 미확인 | 번호 텍스트 목록으로 fallback — 어느 호스트에서도 정확하다 |
| `fg-statusline` | 미지원 | Codex에서는 `$fg-status` 사용 |

이 표는 산문이 아니라 **선언**이다 — 같은 내용이 `hosts/codex/capabilities.json`의 8개 키에 기계가 읽는 형태로 들어 있고, 둘은 항상 함께 갱신한다. **능력은 그 호스트가 실제로 제공하는 것을 *관측*했을 때만 `true`이며, 미확인은 `false`가 기본값이다** — 모든 능력에는 정의된 fallback(직렬 실행·번호 목록·명시적 정지)이 있어서, 도는 fallback이 없는 도구를 부르는 것보다 항상 싸기 때문이다. `false`를 `true`로 바꾸는 것은 가정이 아니라 관측이다(`core/HOST.md`).

## 호스트를 바꿔 이어서 작업하기

Forge 상태는 호스트가 아니라 저장소의 `.forge/`에 저장된다. Claude Code에서 계획을 만든 뒤 Codex에서 `$fg-status` 또는 `$fg-next`로 이어가거나, 반대로 Codex에서 실행한 작업을 Claude Code에서 회고·봉인할 수 있다. 단, 두 호스트가 같은 브랜치와 working tree를 보고 있어야 한다.

## 릴리스 검사

```bash
npm run release:check
```

이 검사는 Claude/Codex 매니페스트 버전, 공통 `skills/` 경로, 기본 훅 파일, 양쪽 호스트 어댑터 존재 여부를 함께 확인한다. `fg-doctor`도 Codex 매니페스트가 존재할 때 네 버전 위치의 drift를 검사한다.
