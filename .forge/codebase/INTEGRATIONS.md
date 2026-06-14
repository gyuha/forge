---
last_mapped_commit: d3c47b5bdc859af54e741f0524f9ed8ce2b61483
mapped: 2026-06-14
---

# INTEGRATIONS — 외부 통합 / API / 데이터 / 인증

## 요약: 외부 통합은 사실상 없다

forge는 외부 서비스와 통신하지 않는다. 단도직입적으로:

- **외부 API 호출 없음.** HTTP 클라이언트·SDK·`fetch`·`curl` 호출이 런타임 코드에 없다(배포 절차의 `curl raw.githubusercontent.com`은 사람이 손으로 도는 검증 단계일 뿐 플러그인 동작이 아니다).
- **데이터베이스 없음.** DB 드라이버·ORM·연결 문자열·스키마 마이그레이션이 없다. forge의 "상태"는 전부 로컬 파일시스템의 `.forge/` 디렉터리(Markdown + 가끔 JSON)다.
- **인증·시크릿 없음.** API 키·토큰·OAuth·환경변수 기반 자격증명을 읽거나 저장하는 코드가 없다. 매니페스트의 author 이메일(`nicegyuha@gmail.com`)은 메타데이터일 뿐이다.
- **웹훅 없음.** 인바운드/아웃바운드 웹훅 엔드포인트, 콜백 URL, 이벤트 수신기가 없다.
- **메시지 큐·캐시·스토리지 서비스 없음.**

forge는 자기완결적이다. 모든 동작은 로컬 파일 읽기/쓰기 + git 호출(브랜치 판별·머지 안내) + Claude Code 호스트 기능 호출로 끝난다. 외부로 나가는 네트워크 트래픽은 플러그인 마켓플레이스 설치(호스트가 GitHub `main`을 당기는 것)뿐이며, 이는 플러그인 코드가 아니라 Claude Code 설치 메커니즘이다.

## 무엇과 통합하는가 — Claude Code 호스트 기능

forge가 의존하는 "통합"은 전부 자신을 실행하는 **Claude Code 호스트의 내장 기능**이다. 외부 시스템이 아니라 호스트가 제공하는 능력에 올라타는 것이다.

### 1. 플러그인 / 스킬 자동 탐색

Claude Code 플러그인 시스템이 forge를 로드하고, `skills/<name>/SKILL.md`를 frontmatter `name`으로 자동 탐색한다. forge 자체가 마켓플레이스(`.claude-plugin/marketplace.json`, `source: "./"`)이기도 하다. 설치 시 호스트가 GitHub 기본 브랜치(`main`)를 당긴다.

### 2. Agent 도구 (병렬 서브에이전트)

`fg-map`과 `fg-run`이 호스트의 Agent/서브에이전트 기능에 의존한다.
- **fg-map** — 병렬 서브에이전트를 띄워 코드베이스를 분석하고 `.forge/codebase/` 문서(7종)를 채운다(이 문서를 생성한 메커니즘과 동일).
- **fg-eco** — 켜지면 `fg-run`이 위임하는 워크플로우 서브에이전트의 모델을 sonnet으로 캡한다(내리기만, 세션 모델 불변 — ADR-0014). 즉 호스트의 서브에이전트 모델 선택 기능에 올라탄다.

### 3. Dynamic Workflow (실행 엔진)

`fg-run`이 `.forge/plan.md`를 Claude Code **Dynamic Workflow**로 실행한다. 이것이 forge 루프의 실행 단계를 구동하는 핵심 호스트 기능이다. 설계 원칙상 그릴링(fg-ask)은 절대 워크플로우 안에 넣지 않는다(워크플로우는 실행 중 사용자 입력을 못 받기 때문) — 호스트 기능의 제약이 forge 아키텍처를 직접 형성한다.

### 4. statusLine (NEW)

`fg-statusline` 스킬이 호스트의 **statusLine** 설정에 통합한다 — 이것이 forge가 새로 올라탄 호스트 기능이다.
- statusLine은 `settings.json`의 `statusLine` 키로만 설정되며 플러그인이 직접 등록할 수 없다. 그래서 forge는 실제 bash 스크립트(`scripts/forge-statusline.sh`)를 `~/.claude/forge-statusline.sh`로 복사하고 settings에 배선한다.
- 호스트는 statusLine 명령을 **비대화형 셸**로 실행하며 세션 JSON을 stdin으로 넘긴다. 명령은 forge 스킬을 호출할 수 없으므로 스크립트가 `.forge/`를 직접 읽는다.
- statusLine은 단 하나만 존재(스태킹 불가)하므로, 기존 statusLine이 있으면 wrapper(`~/.claude/forge-statusline-wrapper.sh`)로 감싸 forge를 별도 행으로 추가한다(ADR-0017).
- `${CLAUDE_PLUGIN_ROOT}`는 statusLine 셸에서 사용 불가(설치 경로가 업데이트마다 바뀜)하므로 스크립트를 안정 경로로 복사하는 우회가 필요하다.

### 5. MCP (Model Context Protocol)

forge **자체는 MCP 서버를 정의하거나 의존하지 않는다.** 매니페스트(`plugin.json`)에 `mcpServers` 필드가 없고, 스킬 본문도 특정 MCP 도구를 요구하지 않는다. 호스트 환경에 MCP 서버가 떠 있을 수는 있으나(예: 이 세션에 Context7·Playwright 등이 보임) 그것은 사용자 환경의 일이지 forge가 패키징하거나 요구하는 의존이 아니다. forge가 MCP와 "통합"한다고 말할 근거는 없다.

### 6. settings.json (호스트 설정 파일)

`fg-statusline`이 `statusLine` 키를 쓰고, `fg-tdd`/`fg-eco`는 forge 자체 설정(`.forge/config.json`)을 토글한다. 전자는 호스트 설정 파일을 직접 편집하는 유일한 스킬이다(프로젝트 `.claude/settings.json` 우선, 없으면 사용자 `~/.claude/settings.json`).

## 시스템 도구 의존 (외부 서비스 아님)

엄밀히 "통합"은 아니지만 forge가 호출하는 외부 바이너리:

- **git** — 브랜치 판별(`forge-statusline.sh`의 `git rev-parse`), 머지 후 통합 안내(`fg-merge`는 git을 직접 돌리지 않고 사용자가 `git merge`한 뒤 `.forge/branch/`를 통합). 브랜치별 forge 루트(ADR-0011)의 토대.
- **bash / 표준 POSIX 유틸** — statusline 스크립트·테스트가 `sed`/`find`/`ls`/`wc`/`mktemp` 사용.

이들은 로컬 CLI 도구이며 네트워크 서비스가 아니다.

## 결론

통합 관점에서 forge의 표면적은 **호스트 안쪽으로만** 향한다 — Claude Code의 플러그인/스킬 시스템, Agent 서브에이전트, Dynamic Workflow, statusLine, settings.json. **바깥(인터넷·DB·서드파티 API)으로 향하는 통합은 0이다.** 보안·시크릿·네트워크 검토 대상이 본질적으로 없다는 뜻이며, 이는 의도된 설계다(로컬 파일 + 호스트 기능만으로 자기완결).
