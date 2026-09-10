# opencode에서 forge 사용하기

forge는 Claude Code·Codex·opencode가 **같은 `skills/`와 `.forge/` 상태**를 사용하도록 구성돼 있다. 작업 규칙을 세 벌로 복제하지 않고, 질문과 서브에이전트 실행처럼 호스트마다 다른 부분만 `hosts/` 어댑터로 분리한다.

## 설치와 호출

opencode는 forge 전용 매니페스트가 필요 없다 — `.claude-plugin`·`.codex-plugin`에 대응하는 세 번째 매니페스트가 없고, 스킬은 `SKILL.md` 탐색만으로 로드된다. 다만 **forge가 그 탐색 경로에 놓여 있어야 한다.** opencode가 스캔하는 곳은 `.opencode/skills/`·`.claude/skills/`·`.agents/skills/`(프로젝트 — git worktree까지 거슬러 올라가며 탐색)와 `~/.config/opencode/skills/`·`~/.claude/skills/`·`~/.agents/skills/`(전역)뿐이다.

**`/plugin install`로 설치한 forge는 이 목록에 없다.** 플러그인은 `~/.claude/plugins/cache/<마켓플레이스>/<플러그인>/<버전>/skills/`라는 플러그인 캐시로 들어가고, 그 경로는 Claude Code의 플러그인 로더만 안다. opencode에서 다른 스킬은 보이는데 forge만 보이지 않는다면 이것이 원인이며, 링크를 한 번 걸면 해결된다.

### 링크 걸기

```bash
git clone https://github.com/gyuha/forge.git ~/.forge
mkdir -p ~/.config/opencode/skills
ln -s ~/.forge/skills/* ~/.config/opencode/skills/
```

확인한 뒤 **opencode를 재시작한다** — 스킬은 세션 시작 시 로드되므로 이미 열려 있는 세션에는 반영되지 않는다.

```bash
ls ~/.config/opencode/skills/ | wc -l   # forge 스킬 개수만큼 나오면 정상
```

갱신은 `git pull` 하나로 끝난다 — 링크가 clone을 직접 가리키기 때문이다.

주의 세 가지:

- **플러그인 캐시를 직접 링크하지 말 것.** 캐시 경로에는 버전이 박혀 있고(`.../forge/0.8.3/`) 옛 버전 디렉터리가 지워지지 않으므로, 버전을 올려도 링크는 끊기지 않고 **조용히 옛 forge를 가리킨 채** 남는다.
- **`~/.claude/skills/`는 권하지 않는다** — Claude Code가 플러그인 사본과 이 사본을 중복으로 발견할 수 있다. 특정 리포에서만 쓰려면 전역 대신 그 리포의 `.opencode/skills/`에 링크한다.
- **clone은 Claude Code 플러그인과 독립이다** — 두 호스트가 서로 다른 forge 버전을 볼 수 있으므로, 맞추려면 clone은 `git pull`, 플러그인은 `/plugin marketplace update`로 각각 갱신한다.

호출은 스킬 이름을 부르는 방식이다. 자연어 트리거는 세 호스트가 동일하다.

| 목적 | Claude Code | Codex | opencode |
| --- | --- | --- | --- |
| 계획 시작 | `/forge:fg-ask` | `$fg-ask` | `fg-ask` 스킬 호출 |
| 계획 실행 | `/forge:fg-run` | `$fg-run` | `fg-run` 스킬 호출 |
| 다음 단계 실행 | `/forge:fg-next` | `$fg-next` | `fg-next` 스킬 호출 |
| 상태 확인 | `/forge:fg-status` | `$fg-status` | `fg-status` 스킬 호출 |
| 무결성 검사 | `/forge:fg-doctor` | `$fg-doctor` | `fg-doctor` 스킬 호출 |

## 공유 코어와 어댑터

```text
.claude-plugin/plugin.json ─┐
                            ├─▶ skills/ + scripts/ ─▶ 같은 .forge/ 상태
.codex-plugin/plugin.json ──┤
                            │
 (opencode: 매니페스트 없이 ─┘
  .claude/skills/ 직접 탐색)
                                  │
                                  ├─ hosts/claude/
                                  ├─ hosts/codex/
                                  └─ hosts/opencode/
```

- `core/HOST.md`: 호스트 판별과 capability 선택 규칙
- `core/INTERACTION.md`: 질문·선택·확인의 공통 계약
- `core/EXECUTION.md`: 직렬/병렬 실행과 결과 수집의 공통 계약
- `hosts/opencode/`: opencode의 평문 질문과 직렬 실행 방식

**opencode는 호스트 식별 신호가 없다.** 모든 세션에 존재한다고 믿을 만한 환경변수를 노출하지 않으므로, `core/HOST.md`의 선택 규칙은 opencode를 **명시적 호스트 메타데이터로만** 식별한다. 다른 두 변수(`CLAUDE_PLUGIN_ROOT`·`PLUGIN_ROOT`)의 *부재*로 opencode를 추론해서는 안 된다 — 그 부재는 순차 fallback 자신의 조건이라, 추론하면 미상 호스트가 조용히 명명 호스트로 승격된다.

## 현재 지원 범위

| 기능 | opencode 상태 | 설명 |
| --- | --- | --- |
| 핵심 루프 (`fg-ask` → `fg-run` → `fg-learn` → `fg-done`) | 지원 | 동일한 상태 전이와 검증·봉인 규칙 사용 |
| 상태/도구 (`fg-status`, `fg-doctor`, `fg-quick`, `fg-config`) | 지원 | 공통 결정론 스크립트와 스킬 사용 |
| 선택 메뉴 (`structured_choice`) | 미확인 | 번호 텍스트 목록으로 fallback — 어느 호스트에서도 정확하다 |
| 독립 작업 병렬 실행 (`spawn_parallel`) | 미확인 | 업스트림 문서는 내장 `@general` 서브에이전트가 여러 작업 단위를 병렬 실행한다고 기술하지만, forge 슬라이스를 위임·회수해 본 **관측이 없다**. 현재는 직렬 실행 — 플립 1순위 |
| 역할 지정 위임 (`spawn_role`) | 미확인 | `.opencode/agents/<role>.md` 커스텀 에이전트를 primary agent가 `description`으로 고른다고 문서화돼 있으나 관측 없음 — 기본 서브에이전트로 fallback. 플립 2순위 |
| 플러그인 파일 경로 해석 (`plugin_root`) | 미확인 | 신뢰할 플러그인 루트 변수가 없다. 스킬은 자기 디렉터리 기준 상대 경로로 동반 파일을 해석한다 |
| SessionStart 알림 (`session_start`) | 미확인 | 미봉인 잔여 주입이 없다 — 세션 진입 시 `fg-status`를 직접 호출한다 |
| `fg-next all`, `fg-loop` 무인 주행 (`prevent_stop`) | 미지원 | 턴 경계를 넘기는 메커니즘이 없어 **turn-bounded**로 동작한다 — 한 턴이 허용하는 만큼 주행하고 상태 파일을 유지한 뒤 재트리거로 stateless 재개 |
| `fg-agents` 프로젝트 역할 생성 (`project_agents`) | 미지원 | 생성 포맷이 `.claude/agents/` 중심 — opencode 전용 materialize는 후속 작업 |
| `fg-statusline` (`status_display`) | 미지원 | `fg-status`를 직접 호출한다 |
| `fg-showme` 확정-클릭 즉시 반영 (`event_wake`) | 미지원 | 확정 뒤 터미널에 아무거나 보내야 재개된다 |
| `fg-loop`의 `budget-tokens` 지출 상한 | 미지원 | 계량기가 Claude Code의 트랜스크립트 파일을 읽는다. opencode에서는 `budget-tokens: none`으로 선언하거나 `--transcripts DIR`로 경로를 지정한다(미지정 시 `blocked-health`로 정지 — fail-closed) |

이 표는 산문이 아니라 **선언**이다 — 같은 내용이 `hosts/opencode/capabilities.json`의 9개 키에 기계가 읽는 형태로 들어 있고, 둘은 항상 함께 갱신한다. `npm run release:check`가 **9개 키가 모두 이 표에 이름으로 등장하는지**를 강제한다(상태 문구 자체의 타당성은 사람이 검토한다). **능력은 그 호스트가 실제로 제공하는 것을 *관측*했을 때만 `true`이며, 미확인은 `false`가 기본값이다** — 그래서 현재 opencode의 9개 키는 전부 `false`다. 이는 opencode가 이 일들을 못 한다는 주장이 아니라 관측 규칙을 문자 그대로 적용한 결과이며, 모든 `false`에는 정의된 fallback이 있다(`core/HOST.md`).

## 호스트를 바꿔 이어서 작업하기

Forge 상태는 호스트가 아니라 저장소의 `.forge/`에 저장된다. Claude Code에서 계획을 만든 뒤 opencode에서 `fg-status`·`fg-next`로 이어가거나, 반대로 opencode에서 실행한 작업을 Claude Code에서 회고·봉인할 수 있다. 단, 세 호스트가 같은 브랜치와 working tree를 보고 있어야 한다.

## 릴리스 검사

```bash
npm run release:check
```

이 검사는 매니페스트 네 곳의 버전, 공통 `skills/` 경로, 기본 훅 파일, 그리고 **`hosts/` 아래 실재하는 모든 호스트 어댑터**의 완비 여부를 함께 확인한다 — 호스트 목록을 하드코딩하지 않으므로 `hosts/opencode/`도 자동으로 검사 대상이다.
