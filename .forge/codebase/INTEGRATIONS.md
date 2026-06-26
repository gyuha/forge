---
last_mapped_commit: 2059a08bee17a9fbb97e6e938958f5ed813bdb2d
mapped: 2026-06-26
---

# INTEGRATIONS.md — forge의 외부 접점

forge는 외부 시스템과의 통합이 거의 없는 자기완결 플러그인이다. 네트워크 API 호출, 데이터베이스, 외부 서비스, MCP 서버 의존이 **하나도 없다**. 실제 외부 접점은 Claude Code 호스트 자체와의 인터페이스뿐이다. 아래가 전부이며, 빈약해 보인다면 그것이 정확한 현실이다 — 패딩하지 않았다.

## 1. Claude Code 플러그인/마켓플레이스 설치 메커니즘 (GitHub main을 당김)

forge는 Claude Code 플러그인 시스템에 두 매니페스트로 등록된다.

- `.claude-plugin/marketplace.json` — `/plugin marketplace add gyuha/forge`로 이 리포를 마켓플레이스로 등록.
- `.claude-plugin/plugin.json` — `/plugin install forge@forge`로 플러그인 설치.

설치는 **GitHub 기본 브랜치(`main`)를 당긴다**. 따라서 설치/업데이트 테스트를 하려면 변경이 `main`에 push돼 있어야 한다(배포 = push까지). `/plugin install`·`/plugin marketplace update`는 interactive 명령이라 에이전트가 실행할 수 없고, 에이전트가 검증 가능한 것은 설치 전제뿐이다 — `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`로 원격 `main`의 버전 3곳을 확인한다. 설치 경로는 업데이트마다 바뀐다(`~/.claude/plugins/cache/<hash>/`).

## 2. `${CLAUDE_PLUGIN_ROOT}` 참조 (스킬 간 형식 문서 공유)

스킬 본문은 호스트가 주입하는 `${CLAUDE_PLUGIN_ROOT}` 환경변수로 설치 위치를 해석해 형식 문서를 참조한다. 18개 SKILL.md 전부가 이 변수를 사용한다. 용례는 소유 스킬의 형식 문서를 가리키는 것이다 — 예: `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/CONTEXT-FORMAT.md`, `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/PLAN-FORMAT.md`·`FORGE-ROOT.md`, `${CLAUDE_PLUGIN_ROOT}/skills/fg-learn/RETRO-FORMAT.md`. 형식 정의는 한 벌만 두고 복사하지 않는 단일 출처 원칙의 구현이다.

**중요한 제약**: `${CLAUDE_PLUGIN_ROOT}`는 스킬이 실행되는 메인 세션 컨텍스트에서만 가용하다. statusLine 셸에는 주입되지 않으므로 statusline 스크립트는 이 변수를 쓸 수 없다(아래 3 참조).

## 3. settings.json 와이어링 (fg-statusline)

`fg-statusline`이 유일하게 `settings.json`을 건드리는 스킬이다. Claude Code의 statusLine은 플러그인이 등록할 수 없고 오직 `settings.json`의 `statusLine` 키로만 설정되며, 그 command는 세션 JSON을 stdin으로 받아 텍스트를 찍는 비-interactive 셸 명령이다(스킬을 호출할 수 없음). 그래서 forge는 실제 bash/node 스크립트를 출하한다.

- `scripts/forge-statusline.sh` / `scripts/forge-statusline.js` — `.forge/`를 직접 읽어 한 줄 진행 상태를 찍는 display-only 조각(ADR-0017). 두 트윈은 동일 출력을 보장한다(ADR-0022 패리티 테스트).
- `scripts/forge-statusline-wrapper.sh` — 기존 statusLine을 보존하며 forge 조각을 별도 줄로 합성하는 래퍼(bash 전용; no-bash 환경에선 forge를 단독 statusLine으로만 연결).

설치 동작(fg-statusline이 대화형으로 수행):

1. 두 스크립트를 안정 경로(`$CLAUDE_CONFIG_DIR` 또는 `~/.claude`, 이하 `<CFG>`)로 복사하고 `chmod +x`. 플러그인 캐시 경로가 업데이트마다 바뀌고 `${CLAUDE_PLUGIN_ROOT}`가 statusLine 셸에 없기 때문에 in-place 참조가 아니라 복사한다.
2. `settings.json`의 `statusLine.command`를 **절대경로**로 기록(`~` 금지 — tilde 확장 불보장으로 statusline이 조용히 비는 클래식 실패 원인).
3. statusLine은 하나뿐이라 기존 것을 교체하지 않고, 원본 command를 `<CFG>/forge-statusline-orig.sh`에 verbatim 보존한 뒤 래퍼를 가리켜 forge를 별도 줄로 래핑(ADR-0017).

**bash 가용 여부 판정(ADR-0022)**: fg-statusline 설치 시 단 한 번 판정해 `settings.json`에 기록할 STATUSLINE_CMD를 확정한다 — bash 있으면 `<CFG>/forge-statusline.sh`, 없으면 `node <CFG>/forge-statusline.js`. 런타임 내부 위임이 아니라 설치 시점 분기이므로 두 트윈 중 하나만 연결된다. 적용은 Claude Code 재시작 후.

스크립트는 stdin의 세션 JSON에서 `cwd`(없으면 `workspace.current_dir`, 그래도 없으면 `$PWD`)를 파싱해 프로젝트 디렉터리로 `cd`한 뒤 해석된 forge 루트(ADR-0011 브랜치 해석)를 읽는다.

## 4. fg-status/fg-next ↔ 결정론적 상태 스크립트

`fg-status`(와 fg-next)는 `scripts/forge-status.sh`(없으면 폴백으로 `scripts/forge-status.js`)를 호출해 `.forge/` 상태를 결정론적으로 조사한다(ADR-0020). 이는 외부 통합이 아니라 리포 내부 스크립트 의존이지만, 셸 스크립트가 스킬 동작의 일부라는 점에서 기록한다. 두 스크립트 모두 `jq` 없이 동작한다.

## 5. Claude Code Dynamic Workflow / 서브에이전트 (fg-run의 실행 기제)

fg-run은 작업 실행을 Claude Code의 Dynamic Workflow(`workflow` 키워드 또는 `ultracode` effort)로 구성한다. 호스트가 제공하는 기능이며 forge가 와이어링하는 외부 통합은 아니다. fg-run이 이 기제에 의존하는 방식:

- 워크플로우 오케스트레이션 스크립트를 빌드해 사용자 승인 후 병렬/직렬 서브에이전트로 실행.
- 서브에이전트에는 `model`, `agentType`, 프롬프트 prepend(`skills/fg-eco/ECO.md` 내용)를 전달할 수 있다.
- eco 모드(ADR-0014): 서브에이전트 model을 `sonnet`으로 캡(내리기만), `ECO.md` prepend 주입.
- 도메인 에이전트 dispatch(ADR-0024): `.claude/agents/<role>.md` 카드가 세션 시작 시 로드돼 있으면 `agentType: '<role>'`으로 슬라이스를 해당 role에 위임. graceful — 카드 없으면 기본 서브에이전트로 동일 동작.

## 6. `.claude/agents/` — 도메인 에이전트 dispatch (ADR-0024)

fg-agents 스킬이 프로젝트 도메인을 그릴링해 `.claude/agents/<role>.md`(표준 Claude Code 서브에이전트 정의 카드)를 생성한다. fg-run은 이 카드들을 `agentType`으로 호출해 워크플로우 슬라이스를 전문화된 역할에 위임한다.

두 가지 하드 제약(ADR-0024):

1. **세션 시작 시 1회 로드** — `.claude/agents/`는 session start에 한 번만 읽힌다. fg-agents가 세션 중 카드를 생성해도 그 카드는 해당 세션에서 fg-run이 dispatch할 수 없다. 운영 흐름: `fg-agents 생성 → 세션 재시작 → fg-run 활용`.
2. **카드는 사용자 프로젝트 소유** — forge 플러그인이 자체 에이전트를 보유하는 게 아니라, 사용자 프로젝트의 `.claude/agents/`를 fg-run이 `agentType` 경로로 활용한다.

## 7. 선택적 외부 스킬 참조 (graceful, 하드 의존 아님)

forge는 두 가지 외부 스킬을 조건부 연료로 참조하지만 어느 쪽도 하드 의존이 아니다. 없으면 조용히 건너뛴다.

- **`deep-research`** — fg-ask의 그릴링 전 선택적 참고 연료(ADR-0006). 외부 지식이 필요하거나 사용자가 요청할 때만, fg-ask가 먼저 제안하고 동의 시에만 실행. 없으면 그릴링을 정상 진행.
- **`code-review`** — fg-run 워크플로우 안의 위험/큰 변경에 한해 선택적으로 활용(ADR-0007). 이식성을 위해 워크플로우 자체 adversarial-verify 서브에이전트가 기본이고, code-review 역량이 가용하면 보강. 없으면 동작 불변.

## 8. MCP / 데이터베이스 / 외부 API / 웹훅

**없다.** 스킬·스크립트 어디에도 MCP 서버 의존이나 외부 API 호출이 없다. `docs/forge-vs-loop-engineering.md`의 산문에 MCP가 언급되지만 통합이 아닌 설명 문맥이다. 데이터베이스, 인증, 웹훅도 없다.

## 요약

실질 외부 접점은 다섯 가지다.

1. GitHub `main` 기반 플러그인 설치 메커니즘
2. 호스트가 주입하는 `${CLAUDE_PLUGIN_ROOT}` 경로 참조 (스킬 간 형식 문서 공유)
3. fg-statusline의 `settings.json` 와이어링 (bash/node 스크립트를 안정 경로로 복사)
4. Claude Code Dynamic Workflow / 서브에이전트 (fg-run의 실행 기제, 호스트 제공)
5. `.claude/agents/` 도메인 에이전트 dispatch (fg-agents 생성 → 세션 재시작 → fg-run agentType 호출)

네트워크 API·DB·서드파티·MCP 의존은 0이다.
