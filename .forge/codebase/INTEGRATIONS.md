---
last_mapped_commit: 0472a519cbb8275564cdbaa30469f2d0c5472842
mapped: 2026-06-10
---

# INTEGRATIONS

forge는 **데이터베이스·외부 HTTP API·인증 공급자·웹훅을 일절 사용하지 않는다.** 런타임 코드도, 네트워크 호출 코드도 없다. forge가 "통합"하는 대상은 단 하나 — **Claude Code 호스트 자체**다. forge는 Claude Code가 제공하는 플러그인/스킬/워크플로 메커니즘 위에 얹히는 Markdown 지시문 묶음이고, 외부 세계와의 접점은 (1) 설치 시 GitHub raw 콘텐츠를 당기는 것, (2) 스킬이 실행 중 호출하는 로컬 셸 명령(주로 `git`)뿐이다.

## Claude Code 플러그인·스킬 메커니즘 (주 통합점)

forge는 Claude Code의 **플러그인 시스템**으로 설치되고 **스킬 시스템**으로 호출된다.

- **스킬 자동 탐색** — Claude Code가 `skills/<dir>/SKILL.md`를 자동 발견하고, frontmatter의 `name`을 스킬 식별자로 등록한다. 사용자가 `description`에 명시된 트리거 문구(예: "forge로 시작", "다음 단계", "forge status")를 말하면 Claude가 해당 스킬을 트리거한다.
- **`${CLAUDE_PLUGIN_ROOT}`** — Claude Code가 플러그인 설치 경로로 주입하는 환경 변수. 11개 스킬 전부가 이를 통해 형식 문서·FORGE-ROOT 정의를 참조한다(`${CLAUDE_PLUGIN_ROOT}/skills/<owner>/<file>`). forge가 호스트로부터 받는 유일한 런타임 입력에 가깝다.
- **스킬 간 위임** — `fg-next`/`fg-status`는 다른 `fg-*` 스킬을 호출(invoke)한다. 이는 외부 통합이 아니라 Claude Code 스킬 시스템 내부 호출이다.

## Claude Code Dynamic Workflow (실행 엔진)

`fg-run`은 `.forge/plan.md`를 **Claude Code Dynamic Workflow**로 실행한다(`skills/fg-run/SKILL.md`). 이는 forge가 의존하는 핵심 호스트 기능이다.

- 워크플로는 마이그레이션·전수 감사·대규모 리팩터처럼 **다수의 subagent를 병렬로** 돌려야 하는 큰 작업을 백그라운드로 실행하고, 그 결과를 계획에 대고 검증한다.
- 워크플로는 **실행 중 사용자 입력을 받을 수 없다** — 이 제약 때문에 그릴링(fg-ask)은 절대 워크플로 안에 넣지 않고 반드시 워크플로 밖 대화로 진행한다(설계 기둥 1).

## Claude Code Subagent / Task (병렬 팬아웃)

`fg-map`은 코드베이스 분석을 **4개의 병렬 subagent**로 팬아웃한다(`skills/fg-map/SKILL.md`). 각 subagent가 자기 담당 문서를 `.forge/codebase/`에 직접 쓰고, 오케스트레이터 세션은 확인 메시지(파일 경로 + 줄 수)만 돌려받는다 — 문서 내용 자체는 받지 않아 context rot을 막는다. `fg-run`의 Dynamic Workflow도 동일하게 다수 subagent를 병렬 기동한다.

## Claude Code AskUserQuestion (대화형 선택 UI)

`fg-run`은 백로그에 미실행 계획이 2개 이상일 때 **`AskUserQuestion`** 도구로 선택 다이얼로그를 띄운다(`skills/fg-run/SKILL.md`). 옵션은 우선순위순(high → medium → low) 정렬된 미실행 계획 목록 + 맨 아래 "Run all". 이는 Claude Code가 제공하는 대화형 UI 메커니즘이며 외부 서비스가 아니다.

## 로컬 셸 명령 (git 등)

스킬은 실행 중 로컬 셸 명령을 호출한다. 외부 네트워크가 아닌 **로컬 도구 실행**이다.

- **`git`** — 가장 빈번. forge 루트 해석에 `git rev-parse --abbrev-ref HEAD`(현재 브랜치 판별, `skills/fg-run/FORGE-ROOT.md`). `fg-merge`는 사용자가 `git merge`를 **먼저 끝낸 뒤** 실행되는 후속 단계로, **자신은 git을 조작하지 않고** 네임스페이스된 `.forge/branch/<branch>/`를 `.forge/`로 통합한다(ADR·retro·CONTEXT·done 병합 + 브랜치 폴더 제거).
- **`node -e`** — 매니페스트 JSON 유효성 검증용 일회성 도구(레포 CLAUDE.md의 검증·배포 규칙). 런타임 의존성이 아니다.
- **`gh` CLI** — 배포·GitHub 작업 시 사용 가능하나 forge 스킬 본문이 직접 의존하지는 않는다.

## 플러그인 마켓플레이스 설치 메커니즘 (배포 통합)

forge는 자기 자신이 설치 가능한 마켓플레이스다. 설치는 Claude Code의 마켓플레이스 명령으로 이뤄진다.

```
/plugin marketplace add gyuha/forge      # GitHub 소스 (또는 로컬 경로)
/plugin install forge@forge
```

- 설치는 **GitHub 기본 브랜치(`main`)를 당긴다** → 설치 테스트하려면 `main`에 push되어 있어야 한다.
- `/plugin install`·`/plugin marketplace update`는 **interactive 명령**이라 에이전트가 직접 실행하지 못한다(사용자가 직접 입력). 에이전트가 검증 가능한 것은 설치 전제뿐 — 원격 `main`의 버전 3곳을 `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`으로, 스킬 frontmatter `name` 누락 여부를 `awk '/^name:/'`로 확인한다.
- 즉 forge가 외부 호스트(`raw.githubusercontent.com`)와 통신하는 유일한 시점이 **설치/업데이트**이며, 이는 forge 코드가 아니라 Claude Code 호스트와 사용자가 수행한다.

## 데이터 영속 (DB 아님 — 파일 시스템)

전통적 데이터베이스가 없다. 모든 상태는 **로컬 파일 시스템의 `.forge/` 디렉터리**에 Markdown/JSON으로 저장된다.

- **휘발 상태** — `.forge/{plan,run,STATUS}.md`, `.forge/backlog/`, `.forge/executed/`, `.forge/done/`. 상태의 원천은 **파일 위치**다(활성 슬롯 → executed/ → done/ 이동). 기본 브랜치에서는 gitignored.
- **영속 문서** — `.forge/CONTEXT.md`, `.forge/adr/`, `.forge/retro/`, `.forge/codebase/`. git 추적되는 루프의 "연료".
- **전역 설정** — `.forge/config.json`(`defaultBranch`, `tdd`). 브랜치 무관 항상 top-level. 현재 리포에는 파일 부재 → `defaultBranch`는 `main`으로 기본 처리.
- **브랜치 격리(ADR-0011)** — 비-기본 브랜치는 상태 전체가 `.forge/branch/<branch>/`로 이동하고 통째로 git 추적된다. 경로가 브랜치별로 네임스페이스되어 두 브랜치가 같은 파일을 안 건드리므로 **git merge 충돌이 없고**, 통합은 `fg-merge`가 담당한다.

## 인증·웹훅·메시지 버스 (없음 — 사실로 명기)

- 인증 공급자, OAuth, API 키, 토큰 인증 **없음**. forge 스킬 어디에도 인증 코드가 없다.
- 웹훅 수신/발신 **없음**.
- 메시지 버스·큐 **없음**. ("백로그"는 큐가 아니라 미실행 계획 파일 디렉터리다.)
- MCP 서버를 forge가 정의하거나 제공하지 **않는다**. (호스트 환경에 MCP 서버가 있을 수는 있으나 forge 플러그인의 일부가 아니다.)
