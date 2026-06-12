---
last_mapped_commit: 382c3f8346ae5b8b68abbb5a2dabe2ab52a80d62
mapped: 2026-06-12
---

# INTEGRATIONS

forge는 **데이터베이스·외부 HTTP API·인증 공급자·웹훅을 일절 사용하지 않는다.** 네트워크 호출 코드 자체가 없다. 외부 접점은 셋뿐이다: (1) 설치·배포 경로로서의 **GitHub**, (2) 호스트인 **Claude Code의 플러그인·스킬·에이전트 메커니즘**, (3) 상태 경계로서의 **로컬 git**.

## GitHub — 설치 원천 (installs pull main)

- 원격: `origin = https://github.com/gyuha/forge.git`.
- 설치: Claude Code 세션에서 `/plugin marketplace add gyuha/forge` → `/plugin install forge@forge`(`README.md` Install 섹션). 로컬 경로 추가(`/plugin marketplace add /path/to/forge`)도 동일 매니페스트로 동작.
- **설치는 GitHub 기본 브랜치(`main`)를 당긴다** — 따라서 "배포"의 정의가 `main` push다(`CLAUDE.md` 배포 규칙: CHANGELOG → 버전 3곳 범프 → JSON 검증 → commit → push). push 전의 변경은 어떤 사용자에게도 도달하지 않는다. 현재 HEAD(`382c3f8`)는 v0.4.8 릴리스 뒤 1커밋이 더 있고 작업 브랜치는 `loop`(비-기본)이다 — main에 닿기 전까지 미배포.
- `/plugin install`·`/plugin marketplace update`는 interactive 명령이라 에이전트가 실행할 수 없다(사용자가 직접). 에이전트 측 배포 검증은 `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`으로 원격 main의 버전 3곳 확인 + `awk '/^name:/' skills/*/SKILL.md`로 frontmatter `name` 누락 확인뿐.

## Claude Code 플러그인·마켓플레이스 메커니즘

- 단일 리포가 플러그인이자 마켓플레이스다: `.claude-plugin/marketplace.json`의 `plugins[0].source: "./"`가 리포 루트를 플러그인 루트로 가리킨다.
- **스킬 자동 탐색** — Claude Code가 `skills/<dir>/SKILL.md`를 자동 발견하고 frontmatter `name`을 식별자로 등록한다(`plugin.json`에 `skills` 필드 없음; 현재 13개 모두 `name` = 디렉터리명). 트리거는 frontmatter `description`에 박힌 문구들("forge run", "forge loop", "다음 단계", "어디까지 했지" 등)을 Claude가 매칭하는 방식 — description이 곧 라우팅 테이블이다.
- **`${CLAUDE_PLUGIN_ROOT}`** — 호스트가 주입하는 플러그인 설치 경로. 스킬 간 형식 문서 참조가 전부 이를 경유한다(예: `skills/fg-next/SKILL.md`가 `${CLAUDE_PLUGIN_ROOT}/skills/fg-status/SKILL.md`를, `skills/fg-ask/SKILL.md`가 `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md`를 참조; 상대경로 `../fg-run/PLAN-FORMAT.md` 병기). forge가 호스트로부터 받는 유일한 런타임 입력에 가깝다.

## 호스트(harness) 기능 사용 지점

### Dynamic Workflow — fg-run의 실행 엔진 (`skills/fg-run/SKILL.md`)

- 프롬프트에 `workflow` 키워드(또는 effort `ultracode`)를 넣어 Dynamic Workflow를 빌드시킨다. `.forge/plan.md`의 Work slices가 작업 단위이고, `depends:` 마커에 따라 직렬 웨이브/병렬 묶음을 짠다.
- 오케스트레이션 스크립트는 **사용자 승인 후** 백그라운드 병렬 서브에이전트로 실행되며, 진행은 `/workflows`로 관찰한다.
- **워크플로는 실행 중 인간 입력을 못 받는다** — 설계 기둥 1(그릴링을 워크플로에 안 넣음)의 근거이자, 중간 사인오프가 필요하면 작업을 둘로 쪼개는 규칙(`PLAN-FORMAT.md` 분할 규칙)의 근거.
- 조건부 코드 리뷰(위험·대형 변경 시)는 **워크플로 자체의 adversarial-verify 서브에이전트**로 구성 — 외부 스킬·플러그인 하드 의존 없음(ADR-0007). TDD 모드도 `superpowers:test-driven-development` 같은 외부 스킬에 "있으면 활용하되 의존하지 않는" 소프트 연계.

### Agent 도구 fan-out — fg-map (`skills/fg-map/SKILL.md`)

- `Agent` 도구 + `run_in_background: true`로 **4개 병렬 서브에이전트**(tech/arch/quality/concerns)를 한 메시지에 발사. 각 에이전트가 `.forge/codebase/` 문서를 **직접 쓰고** 오케스트레이터는 확인(경로+줄수)만 받는다 — context rot 방지의 핵심.
- 비-Agent 폴백 없음: "forge is Claude Code only, so the `Agent` tool is always available". `--paths` 증분 모드·순차 폴백도 의도적으로 없다.
- 각 에이전트 프롬프트에 `git rev-parse HEAD` sha를 넘겨 frontmatter `last_mapped_commit`으로 스탬프 — fg-ask의 stale 판정 근거.

### AskUserQuestion — 대화형 분기

- `skills/fg-run/SKILL.md`: 미실행 plan 2+개일 때 선택 메뉴(priority 정렬, 마지막 옵션 "Run all"), 단일작업 종료 시 4지 핸드오프 메뉴("The four options fit `AskUserQuestion`'s option limit exactly").
- `skills/fg-eco/SKILL.md`: 무인자 호출 시 현재 상태 보고 후 on/off/유지 선택 제시.

### `/goal` 페어링 — 무인 주행 (fg-next all · fg-loop)

- `/goal`은 harness의 세션 스코프 Stop hook(조건 충족까지 정지 차단). `skills/fg-next/SKILL.md` "Unattended to completion — pairing with /goal" 섹션이 원 정의이고 `skills/fg-loop/SKILL.md`가 이를 참조한다.
- **스킬은 `/goal`을 스스로 설정할 수 없다** — 사용자가 직접 타이핑하는 슬래시 명령. fg-loop는 조건 문구를 "stop only when the stop-condition checks all pass, OR a wall is hit"로 쓰라고 못 박는다(벽을 넘는 강제 주행 방지). 안전 벽과 기본 one-shot 동작은 `/goal` 유무와 무관하게 불변.

### Skill 도구 — fg-next의 위임 호출

- `skills/fg-next/SKILL.md`: 다음 단계를 도출하면 한 줄 알림 후 **같은 턴에 Skill 도구로 해당 스킬을 호출**한다(보고만 하는 fg-status와의 차별점). 자체 쓰기는 0 — 모든 쓰기는 위임받은 스킬 내부에서.

### 소프트(비-하드) 외부 능력

- deep-research: `skills/fg-ask/SKILL.md` — 리포 밖 지식이 필요할 때만, 제안 후 동의 시 실행, 없으면 조용히 생략(ADR-0006).
- fg-done의 stale-map 제안: `.forge/codebase/` 존재 + 프로젝트 파일 변경 시 fg-map 실행을 **제안만**(자동 실행 금지 — deep-research와 같은 절제).

## 로컬 git 통합 지점

### `.gitignore` 화이트리스트 — 휘발/영속 경계

`/Users/gyuha/workspace/forge/.gitignore`가 `.forge/*`를 기본 제외하되 영속 문서만 되살린다:

```
.forge/*
!.forge/CONTEXT.md
!.forge/adr/
!.forge/retro/
!.forge/codebase/
!.forge/config.json
!.forge/branch/
```

휘발 상태(plan/run/STATUS/backlog/executed/done/loop.md/quick)는 기본 브랜치에서 git 미추적, 영속 문서(CONTEXT/adr/retro/codebase/config)는 추적. **위치는 같은 `.forge/` 지붕 아래, 구분은 git 추적 여부**다.

### 브랜치 루트 추적 (ADR-0011, 단일 정의 `skills/fg-run/FORGE-ROOT.md`)

- 루트 해석: 현재 브랜치(`git rev-parse --abbrev-ref HEAD`) == `defaultBranch`(`.forge/config.json`, 없으면 `main`) → `.forge/`; 그 외 → `.forge/branch/<branch>/`; detached HEAD/비-git → `.forge/` + 한 줄 경고.
- **비-기본 브랜치 루트는 통째로 git 추적**(`!.forge/branch/` 화이트리스트 — 휘발 유형 파일 포함). 경로가 브랜치별 네임스페이스라 두 브랜치가 같은 파일을 안 써서 `git merge` 충돌이 없다. 기본 브랜치 휘발 상태만 gitignored인 **의도된 비대칭**. 브랜치 forge 상태는 코드처럼 브랜치에 커밋해야 fg-merge가 통합할 수 있다.
- 전역 예외 2개는 항상 최상위: `.forge/config.json`(부트스트랩 역설 방지), `.forge/codebase/`(공유 참조 연료). 비-기본 브랜치에서 영속 연료(`CONTEXT.md`·`adr/`·`retro/`)의 **읽기는 최상위+브랜치 루트 overlay**(브랜치 우선), 쓰기는 브랜치 루트 전용.
- 통합은 git이 아니라 **fg-merge**(`skills/fg-merge/SKILL.md`): 사용자가 `git merge`를 먼저 하면 fg-merge가 브랜치의 ADR을 다음 빈 번호로 재부여(교차참조 갱신)·retro 이동·CONTEXT 용어 병합·done 합침·브랜치 폴더 제거. **git 조작은 일절 안 함**, 진짜 충돌(용어 재정의·ADR 모순)에서만 멈추고 질문.

### 스킬이 실행하는 git 명령

| 명령 | 사용처 | 목적 |
| --- | --- | --- |
| `git rev-parse --abbrev-ref HEAD` | 모든 루프 스킬(`FORGE-ROOT.md` 경유) | forge 루트 해석 |
| `git rev-parse HEAD` | `skills/fg-map/SKILL.md` | `last_mapped_commit` 신선도 스탬프 |
| `git status --short` | `skills/fg-done/SKILL.md` | 루프가 프로젝트 파일을 바꿨는지 → stale-map 제안 트리거 |
| `git merge` (사용자 수행, 스킬 아님) | fg-merge 전제 조건 | 브랜치 forge 폴더를 기본 브랜치로 반입 |
