---
last_mapped_commit: 553484ae395d6ca3df973f5b0cf5762029fd94ec
mapped: 2026-07-20
---

# INTEGRATIONS — 외부 API·데이터·인증·접점

이 리포는 서버 백엔드가 아니라 Claude Code 플러그인이다. 전통적 의미의 외부 API 클라이언트·DB·인증 제공자·웹훅은 **없다**. 실제 외부 접점은 (1) GitHub 설치/배포 경로, (2) `gh` CLI 이슈 연동, (3) vendored 브라우저 컴패니언 localhost 서버, (4) 실행 기질(substrate)로서의 Claude Code Dynamic Workflow, (5) 설정된 MCP 서버(런타임 환경 제공, 이 리포 자체 코드 아님)다.

## 1. GitHub — 설치·배포 경로

- **마켓플레이스 설치는 GitHub 기본 브랜치(main)를 당긴다.** 설치를 테스트하려면 변경이 main에 push되어 있어야 한다. 사용자 흐름:
  - `/plugin marketplace add gyuha/forge` (또는 로컬 경로)
  - `/plugin install forge@forge`
- `/plugin install`·`/plugin marketplace update`는 **interactive 명령이라 에이전트가 실행 못 한다**(사용자가 직접 침).
- 에이전트가 검증 가능한 건 설치 전제뿐:
  - `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json` — 원격 main의 버전 3곳 확인.
  - `awk '/^name:/'`로 `skills/*/SKILL.md` frontmatter `name`(자동 탐색 대상) 누락 확인.
- 리포 좌표: `github.com/gyuha/forge` (매니페스트 `homepage`/`repository`). 라이선스 MIT. 현 로컬 원격 identity는 git worktree(`.git` → `gitdir: .../forge/.git/worktrees/forge-visual-compose`).
- 배포 = commit + push(설치가 main을 당기므로). `chore(release): vX.Y.Z` 커밋으로 `main` push.

## 2. `gh` CLI — 이슈 연동 작업 봉인 (프로젝트 규칙)

이건 스킬 코드가 아니라 **프로젝트 CLAUDE.md 규칙**이다(스킬 `SKILL.md`엔 `gh issue` 호출이 없음 — 봉인 시점에 규칙으로 실행). fg-done이 작업을 봉인(`status: done`)할 때 그 작업 plan의 `## Source of truth`에 `이슈 추적: GitHub 이슈 #N` 표기가 있으면 **확인 질문 없이 자동** 수행:

1. **커밋** — 이 작업이 바꾼 파일만, 메시지에 `(Fixes #N)`(GitHub 자동 링크·자동 닫힘). 전체 릴리스 절차와 다른, 커밋+push만의 가벼운 배포.
2. **push** — `git push origin main`.
3. **이슈 코멘트** — `gh issue comment N`으로 커밋 해시·수정 요약·검증 근거.
4. **닫힘 확인** — `gh issue view N --json state`로 실제 닫혔는지 확인, 안 닫혔으면 `gh issue close N`.

안전장치: 작업 트리에 무관한 미커밋 변경이 섞이면 멈추고 확인받는다. (참고 스킬: `issue-triage` — 읽기 전용 gh 이슈 트리아지, 별개.)

## 3. Vendored Visual Companion — localhost-only 브라우저 서버

`skills/fg-visual/scripts/server.cjs` (obra/superpowers v6.1.1 vendored, MIT, ADR `260719-224442`). 유일한 네트워크 리스너지만 **외부 서비스 호출은 전무** — 텔레메트리·원격 자원·CDN 없음. `server.cjs` 헤더가 명시: "superpowers branding/telemetry removed (the server makes no remote requests)". 브랜딩은 정적 로컬(`⚒ forge — Visual Companion`, no remote assets).

- **바인드**: 기본 `127.0.0.1`(loopback)의 랜덤 high port(49152–65534). 컨테이너/원격 환경용으로 `--host 0.0.0.0` 옵션 있음(그때만 loopback 밖 노출).
- **인증 = 세션 키(URL ?key=)**: per-session secret 키가 서빙 URL에 `?key=`로 실리고 첫 로드 때 쿠키로 미러됨(same-origin subresource·WebSocket이 무상태로 키를 나름). loopback·tunnel·remote 바인드 전반에서 실제 클라이언트를 균일 인증하고 DNS rebinding을 무력화한다(Host/Origin allowlist가 못 하는 것). bare `host:port`는 설계상 403. **키드 URL 전체를 사용자에게 넘겨야 접근된다.**
- **세션 파일**: 최상위 `.forge/visual/<pid-epoch>/{content,state}/`(모든 브랜치 전역·휘발·gitignored). `.forge/visual/.last-port`·`.last-token`으로 재시작 시 같은 port·key 재사용 → 열려 있던 브라우저 탭이 유효 쿠키로 재연결.
- **재시작/재연결 생존**: 브라우저측 `helper.js`가 WebSocket 지수 backoff(500ms→30s) 재연결, 15s 초과 시 "Companion paused" tombstone, 서버 복귀 시 키드 부트스트랩으로 reload.
- **수명**: 4시간(240분) 유휴 자동 종료(`--idle-timeout-minutes`로 override, `BRAINSTORM_IDLE_TIMEOUT_MS`). owner 프로세스(harness) 사망 감시(60s 주기 watchdog) — Windows/MSYS2는 PID 검증 불가라 watchdog 비활성·유휴 타임아웃만 유일 종료 트리거.
- **프로토콜**: HTTP + WebSocket(RFC 6455 직접 구현, 프레임 payload 상한 10MB). 에이전트가 push한 HTML을 브라우저 탭에 표시, 사용자 클릭을 JSONL 이벤트(`state_dir/events`)로 수집 → 에이전트가 read.
- **호출 관계**: `fg-visual`이 단독 진입점(`fg-visual` 시작 / `fg-visual stop` 종료). fg-ask가 그릴링 중 just-in-time 1회 제안 후 수락 시 `../fg-visual/VISUAL.md`·`scripts/`를 파일 참조로 직접 구동하고 Output(핸드오프) 시 서버 종료.

## 4. Claude Code Dynamic Workflow — 실행 기질(substrate)

forge의 실행 단계는 Claude Code의 **Dynamic Workflow**를 실행 substrate로 삼는다(외부 API가 아니라 호스트 런타임 기능). 접점:

- **`fg-run`** — `.forge/plan.md`를 Dynamic Workflow로 실행. 워크플로우 안에선 사용자 입력을 못 받으므로 그릴링(fg-ask)은 절대 워크플로우 밖(설계 기둥 1).
- **`fg-adversarial-review`** — 6개 렌즈를 워크플로우 서브에이전트로 병렬 팬아웃(`dimensions → find → adversarially-verify` 패턴). 사람 입력 없는 분석이라 기둥 1 비위반.
- **`fg-agents` + `fg-run`(ADR-0024)** — `.claude/agents/<role>.md` 표준 Claude Code 서브에이전트 카드를 생성하고, fg-run이 워크플로우 `agent()` 호출의 `agentType`으로 slice↔role 매핑. **카드는 세션 시작 시 1회 로드**라 생성 후 **세션 재시작**해야 픽업. 매칭 role 없는 slice는 기본 서브에이전트로 graceful degrade.
- **`fg-map`** — 병렬 서브에이전트로 코드베이스를 `.forge/codebase/`에 매핑(이 문서 생산자).
- **`fg-eco`(ADR-0014)** — 켜면 fg-run 위임 워크플로우 서브에이전트를 **sonnet으로 캡**(내리기만·세션 모델 불변).

## 5. MCP 서버 — 런타임 환경 제공(리포 자체 자산 아님)

이 리포엔 MCP 서버 정의·설정이 **없다**(플러그인 매니페스트에 `mcpServers` 없음). 현재 세션 런타임 환경에 붙어 있는 MCP 서버들(Context7·Figma·Canva·Notion·Vercel·Microsoft 365/Docs·PlayMCP·playwriter 등)은 forge 플러그인의 의존이 아니라 사용자의 Claude Code 환경 자산이다. 리포 코드가 이들을 참조하는 곳은 없고, `docs/forge-vs-loop-engineering.md`가 산문에서 MCP를 언급할 뿐이다. **forge 스킬은 어떤 MCP 서버에도 하드 의존하지 않는다.**

## 없는 것 (명시)

- **데이터베이스** — 없음. 상태는 파일시스템(`.forge/` 마크다운·JSON)이 전부.
- **인증 제공자·OAuth** — 없음(위 Visual Companion 세션 키는 로컬 프로세스 인증이지 외부 IdP 아님).
- **웹훅·아웃바운드 API 클라이언트** — 없음. 유일한 아웃바운드는 배포 시 사람이 치는 `git push`/`gh`와 설치 검증용 `curl raw.githubusercontent.com`.
- **결제·이메일·큐·분석/텔레메트리** — 없음.
