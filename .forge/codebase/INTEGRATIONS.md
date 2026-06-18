---
last_mapped_commit: 54877b368a1025c44da1e1ca669880c2f955ac45
mapped: 2026-06-18
---

# INTEGRATIONS.md — forge의 외부 접점

forge는 외부 시스템과의 통합이 거의 없는 자기완결 플러그인이다. 네트워크 API 호출, 데이터베이스, 외부 서비스, MCP 서버 의존이 **하나도 없다**. 실제 외부 접점은 Claude Code 호스트 자체와의 인터페이스뿐이다. 아래가 전부이며, 빈약해 보인다면 그것이 정확한 현실이다 — 패딩하지 않았다.

## 1. Claude Code 플러그인/마켓플레이스 설치 메커니즘 (GitHub main을 당김)

forge는 Claude Code 플러그인 시스템에 두 매니페스트로 등록된다.

- `.claude-plugin/marketplace.json` — `/plugin marketplace add gyuha/forge`로 이 리포를 마켓플레이스로 등록.
- `.claude-plugin/plugin.json` — `/plugin install forge@forge`로 플러그인 설치.

설치는 **GitHub 기본 브랜치(`main`)를 당긴다**. 따라서 설치/업데이트 테스트를 하려면 변경이 `main`에 push돼 있어야 한다(배포 = push까지). `/plugin install`·`/plugin marketplace update`는 interactive 명령이라 에이전트가 실행할 수 없고, 에이전트가 검증 가능한 것은 설치 전제뿐이다 — `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`로 원격 `main`의 버전 3곳을 확인한다. 설치 경로는 업데이트마다 바뀐다(`~/.claude/plugins/cache/<hash>/`).

## 2. `${CLAUDE_PLUGIN_ROOT}` 참조 (스킬 간 형식 문서 공유)

스킬 본문은 호스트가 주입하는 `${CLAUDE_PLUGIN_ROOT}` 환경변수로 설치 위치를 해석해 형식 문서를 참조한다. 17개 SKILL.md 전부가 이 변수를 사용한다(`grep -rl CLAUDE_PLUGIN_ROOT skills/` 결과 = 전 스킬). 용례는 소유 스킬의 형식 문서를 가리키는 것이다 — 예: `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/CONTEXT-FORMAT.md`, `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/PLAN-FORMAT.md`·`FORGE-ROOT.md`, `${CLAUDE_PLUGIN_ROOT}/skills/fg-learn/RETRO-FORMAT.md`. 형식 정의는 한 벌만 두고 복사하지 않는 단일 출처 원칙의 구현이다.

**중요한 제약**: `${CLAUDE_PLUGIN_ROOT}`는 스킬이 실행되는 메인 세션 컨텍스트에서만 가용하다. statusLine 셸에는 주입되지 않으므로(아래 3) statusline 스크립트는 이 변수를 쓸 수 없다.

## 3. settings.json 와이어링 (fg-statusline)

`fg-statusline`이 유일하게 `settings.json`을 건드리는 스킬이다(`grep -rl settings.json skills/` = `fg-statusline`만). Claude Code의 statusLine은 플러그인이 등록할 수 없고 오직 `settings.json`의 `statusLine` 키로만 설정되며, 그 command는 세션 JSON을 stdin으로 받아 텍스트를 찍는 비-interactive 셸 명령이다(스킬을 호출할 수 없음). 그래서 forge는 실제 bash 스크립트를 출하한다.

- `scripts/forge-statusline.sh` — `.forge/`를 직접 읽어 한 줄 진행 상태를 찍는 display-only 조각(ADR-0017). fg-status의 다음-단계 우선순위 머신을 재현하지 않는다.
- `scripts/forge-statusline-wrapper.sh` — 기존 statusLine을 보존하며 forge 조각을 별도 줄로 합성하는 래퍼.

설치 동작(fg-statusline이 대화형으로 수행):

1. 두 스크립트를 안정 경로(`$CLAUDE_CONFIG_DIR` 또는 `~/.claude`, 이하 `<CFG>`)로 복사하고 `chmod +x`. 플러그인 캐시 경로가 업데이트마다 바뀌고 `${CLAUDE_PLUGIN_ROOT}`가 statusLine 셸에 없기 때문에 in-place 참조가 아니라 복사한다.
2. `settings.json`의 `statusLine.command`를 **절대경로**로 기록(`~` 금지 — 호스트가 tilde 확장을 보장하지 않아 전체 statusline이 조용히 비는 클래식 실패 원인).
3. statusLine은 하나뿐이라 기존 것을 교체하지 않고, 원본 command를 `<CFG>/forge-statusline-orig.sh`에 verbatim 보존한 뒤 래퍼를 가리켜 forge를 별도 줄로 래핑(ADR-0017).

스크립트는 stdin의 세션 JSON에서 `cwd`(없으면 `workspace.current_dir`, 그래도 없으면 `$PWD`)를 파싱해 프로젝트 디렉터리로 `cd`한 뒤 해석된 forge 루트(ADR-0011 브랜치 해석)를 읽는다. 적용은 Claude Code 재시작 후. 이 출력은 `.forge/` 루프 상태 밖, Claude 설정 디렉터리에만 쓴다.

## 4. fg-status ↔ 결정적 상태 스크립트

`fg-status`(와 fg-next)는 `scripts/forge-status.sh`를 호출해 `.forge/` 상태를 결정적으로 조사한다(ADR-0020). 이는 외부 통합이 아니라 리포 내부 스크립트 의존이지만, 셸 스크립트가 스킬 동작의 일부라는 점에서 기록한다. statusline 스크립트와 마찬가지로 `jq` 없이 동작한다.

## 5. MCP / 외부 서비스

**없다.** 스킬·스크립트 어디에도 MCP 서버 의존이나 외부 API 호출이 없다(`grep -ril mcp skills/`는 `docs/forge-vs-loop-engineering.md`의 산문 언급 한 건만 — 통합 아님). forge는 Claude Code의 Dynamic Workflow·서브에이전트 기능 위에서 동작하지만, 그것은 호스트가 제공하는 실행 기제이지 forge가 와이어링하는 외부 통합이 아니다.

## 요약

실질 외부 접점은 (1) GitHub `main` 기반 플러그인 설치, (2) 호스트가 주입하는 `${CLAUDE_PLUGIN_ROOT}` 경로 참조, (3) fg-statusline의 `settings.json` 와이어링 셋뿐이다. 네트워크·DB·서드파티·MCP 의존은 0이다.
