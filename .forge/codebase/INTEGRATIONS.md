---
last_mapped_commit: b45521cd5fc2f536cc212e559af52c3939a5b0a5
mapped: 2026-06-12
---

# INTEGRATIONS

forge는 **데이터베이스·외부 HTTP API·인증 공급자·웹훅을 일절 사용하지 않는다.** 네트워크 호출 코드 자체가 없다. 외부 접점은 셋뿐이다: (1) 설치·배포 경로로서의 **GitHub**, (2) 호스트인 **Claude Code의 플러그인·스킬·에이전트 메커니즘**, (3) 상태 경계로서의 **로컬 git**. 전부 v0.4.7 작업 트리(신규 13번째 스킬 `skills/fg-loop/` 포함, 미커밋) 기준.

## GitHub — 설치 원천 (installs pull main)

- 설치: Claude Code 세션에서 `/plugin marketplace add gyuha/forge` → `/plugin install forge@forge` (`README.md` Install 섹션). 로컬 경로 추가(`/plugin marketplace add /path/to/forge`)도 동일 매니페스트로 동작.
- **설치는 GitHub 기본 브랜치(`main`)를 당긴다** — 따라서 "배포"의 정의가 `main` push다(`CLAUDE.md` 배포 규칙: CHANGELOG → 버전 3곳 범프 → JSON 검증 → commit → push). push 전의 변경은 어떤 사용자에게도 도달하지 않는다(현재 fg-loop 추가분이 정확히 이 상태).
- 갱신/제거: `/plugin marketplace update forge`, `/plugin uninstall forge@forge`.
- `/plugin ...` 명령은 interactive라 에이전트가 실행할 수 없다. 에이전트 측 배포 검증은 `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`으로 원격 버전 3곳 확인 + `awk '/^name:/' skills/*/SKILL.md`로 frontmatter 누락 확인뿐.

## Claude Code 플러그인 마켓플레이스 메커니즘

- 단일 리포가 플러그인이자 마켓플레이스다: `.claude-plugin/marketplace.json`의 `plugins[0].source: "./"`가 리포 루트를 플러그인 루트로 가리킨다.
- **스킬 자동 탐색** — Claude Code가 `skills/<dir>/SKILL.md`를 자동 발견하고 frontmatter `name`을 식별자로 등록한다(`plugin.json`에 `skills` 필드 없음; 현재 13개 모두 `name` = 디렉터리명). 트리거는 frontmatter `description`에 박힌 문구들("forge run", "forge loop", "다음 단계", "어디까지 했지" 등)을 Claude가 매칭하는 방식 — 즉 description이 곧 라우팅 테이블이다.
- **`${CLAUDE_PLUGIN_ROOT}`** — 호스트가 주입하는 플러그인 설치 경로. 스킬 간 형식 문서 참조가 전부 이를 경유한다(예: `fg-loop`가 `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md`·`../fg-run/PLAN-FORMAT.md`·`../fg-next/SKILL.md`를 참조). forge가 호스트로부터 받는 유일한 런타임 입력에 가깝다.

## Dynamic Workflow / Agent 도구 사용

### fg-run — Dynamic Workflow 실행 엔진 (`skills/fg-run/SKILL.md`)

- 프롬프트에 `workflow` 키워드(또는 effort `ultracode`)로 Dynamic Workflow를 빌드시킨다. `.forge/plan.md`의 Work slices가 작업 단위이고, `depends:` 마커로 직렬 웨이브/병렬 묶음을 짠다.
- **오케스트레이션 스크립트는 사용자 승인 후** 백그라운드 병렬 서브에이전트로 실행되며, 진행은 `/workflows`로 관찰한다.
- **워크플로는 실행 중 인간 입력을 못 받는다** — 이것이 설계 기둥 1(그릴링을 워크플로에 안 넣음)의 근거이고, 중간 사인오프가 필요하면 작업을 둘로 쪼개는 규칙의 근거다(`SKILL.md` 제약 절).
- 조건부 코드 리뷰(위험·대형 변경 시)는 **워크플로 자체의 adversarial-verify 서브에이전트**로 구성한다 — 외부 스킬·플러그인 하드 의존 없음(ADR-0007). TDD 모드도 `superpowers:test-driven-development` 같은 외부 스킬에 "기대되 의존하지 않는" 소프트 연계.
- **eco 모드 연동**: 최상위 `.forge/config.json`의 `eco`가 `true`면 워크플로/실행 서브에이전트 모델을 `model: sonnet`으로 캡(내리기만, 명시적 사용자 지시 우선 — ADR-0014).

### fg-map — Agent 도구 4-way 팬아웃 (`skills/fg-map/SKILL.md`)

- `Agent` 도구를 `run_in_background: true`로 **한 메시지에 4개** 띄운다(tech/arch/quality/concerns). 각 서브에이전트가 `.forge/codebase/` 7문서를 **직접 쓰고** 확인(경로+줄수)만 반환 — 오케스트레이터 컨텍스트 오염 방지가 존재 이유.
- 비-Agent 폴백 없음: "forge is Claude Code only, the `Agent` tool is always available."
- 에이전트 반환 후 비밀키 패턴 스캔(`sk-`, `ghp_`, `AKIA`, `eyJ...`, PRIVATE KEY)이 **필수** — `.forge/codebase/`는 git 추적 영속 문서라 커밋되기 때문. 커밋은 제안만 하고 자동 커밋하지 않는다.

## AskUserQuestion 사용처

대화형 분기 중 구조화된 메뉴가 필요한 곳에만 쓴다(grep 기준 사용처는 두 스킬뿐):

- **`fg-run`** — (1) 백로그에 미실행 plan이 2개 이상일 때 선택 메뉴(priority 정렬, 마지막 옵션 "Run all" → `skills/fg-run/RUN-ALL.md` 절차), (2) 단일작업 실행 종료 핸드오프의 **4지 메뉴**(회고 후 봉인까지[기본·divergence 무관] / 회고만 / 바로 종료=skip+봉인[저-divergence 한정] / 프롬프트로 나가기 — 루프 스킬 중 유일하게 허용된 질문형 핸드오프; `AskUserQuestion`의 옵션 한도에 정확히 맞음, ADR-0015 개정 2026-06-11). Run-all 배치 핸드오프는 진술형이다.
- **`fg-eco`** — 인자 없이 호출 시 현재 상태 보고 후 켜기/끄기/유지 선택.

그 외 모든 상호작용(fg-ask 그릴링, fg-learn 회고, fg-loop의 초기 질의, fg-merge·fg-cleanup의 충돌/승인 문답)은 평문 대화다 — 그릴링은 절대 워크플로 안에 넣지 않는다는 기둥 1이 적용된다.

## 스킬 간 위임 (호스트 내부 호출)

- **`fg-next`** — fg-status의 상태 머신으로 다음 단계를 도출해 해당 스킬을 **직접 invoke**한다(자체 쓰기 없음). `all` 모드는 백로그 소진까지 자동 진행하되 대화의 벽(failed UAT·fork·빈 상태)에서 멈춘다(ADR-0010).
- **`fg-loop`** (신규, ADR-0016) — `fg-next all`의 드라이브 기계를 **참조로 재사용**하되(`../fg-next/SKILL.md` "all mode" — 규칙 복제 금지), `verified: failed`를 벽이 아닌 자동 fix-forward 대상으로 완화한다. 자체 쓰기는 `.forge/loop.md`(목표 계약: 기계 검증 가능 정지 조건·승인된 재계획 범위·`replan-cap` 기본 3)와 `<!-- generated-by: fg-loop -->` 마커가 붙은 백로그 plan뿐 — 나머지 쓰기(승격·run.md·STATUS·봉인)는 전부 위임된 fg-run/fg-done 안에서 일어난다. 벽 4종(검증 불가 UAT·진짜 fork/범위 초과·상한 소진·동일 체크 2연속 무진전)에서 멈추고, 목표 달성 시 `loop.md`를 삭제한다. `fg-status`는 `loop.md` 존재 시 이를 최우선 상태로 보고한다(`skills/fg-status/SKILL.md`).
- **하니스 `/goal` 페어링 (fg-next all · fg-loop 공통)** — 완전 무인 드라이브를 위한 선택적 연계: 세션 Stop hook(`/goal`)에 정지 조건을 걸면 턴 경계(fg-run 워크플로 스크립트 승인 등)를 넘어 자동 재개된다. **스킬은 `/goal`을 스스로 설정할 수 없다 — 사용자가 직접 타이핑하는 하니스 명령**이며, 두 스킬 모두 이를 명문화한다(`skills/fg-next/SKILL.md` §"Unattended to completion — pairing with /goal", `skills/fg-loop/SKILL.md` §"Unattended across turn boundaries"). 조건 문구는 반드시 "벽에서는 멈출 수 있게"(예: "정지 조건 전부 통과 **또는** 벽 도달 시 정지") 작성한다 — "백로그 빌 때까지"만으로 걸면 안전 벽을 강제로 통과하게 되어 ADR-0009/0010 위반. 하드 의존 아님.
- **`fg-done` → `fg-map`** — 봉인 시 지도가 stale해 보이면 fg-map 실행을 **제안만** 한다(자동 실행 금지 — 4 서브에이전트 비용은 인간이 결정, ADR-0006 동일 절제).
- **`fg-quick` → `fg-ask`** — 그릴링 중 non-trivial로 드러나면 bail.

## git — 상태 경계 (gitignore 화이트리스트)

`.gitignore`가 forge 상태의 휘발/영속 경계를 정의한다:

```
.forge/*                  ← 기본 제외 (휘발: plan/run/STATUS/backlog/executed/done/quick/loop.md)
!.forge/CONTEXT.md        ← 영속 문서 화이트리스트
!.forge/adr/
!.forge/retro/
!.forge/codebase/
!.forge/config.json
!.forge/branch/           ← 비-기본 브랜치 forge 루트는 통째로 추적 (ADR-0011)
```

- **기본 브랜치**: 휘발 상태 gitignored, 영속 문서(연료)만 추적. 상태의 원천은 git이 아니라 **파일 위치**다(활성 슬롯 → `executed/` → `done/`; fg-run의 재실행 가드·fg-done의 봉인이 전부 파일 존재 검사). fg-loop의 `.forge/loop.md`도 휘발 — `.forge/*` 패턴에 자동 포함.
- **비-기본 브랜치**: forge 루트가 `.forge/branch/<branch>/`로 네임스페이스되고 **통째로 git 추적**된다 — 두 브랜치가 같은 파일을 안 건드리므로 `git merge`에서 forge 상태 충돌이 구조적으로 없다. 브랜치 forge 상태는 코드처럼 브랜치에 커밋해야 fg-merge에 도달한다(의도된 비대칭, `skills/fg-run/FORGE-ROOT.md`).
- **전역 예외 2개**: `.forge/config.json`·`.forge/codebase/`는 모든 브랜치에서 최상위 — config는 `defaultBranch` 부트스트랩 역설 때문, codebase는 공유 참조 연료라서.
- **fg-merge는 git을 조작하지 않는다** — 사용자가 `git merge`를 먼저 하고, fg-merge는 그 결과로 들어온 `.forge/branch/<branch>/`를 `.forge/`에 통합(ADR 번호 재부여+교차참조 갱신, retro 이동, CONTEXT 용어 병합, done 합침, 폴더 제거)할 뿐이다.
- git 명령 사용처: 브랜치 판별 `git rev-parse --abbrev-ref HEAD`(FORGE-ROOT 해석), HEAD sha 스탬프(`fg-map`), stale 신호용 `git status --short`(`fg-done`), 제안형 커밋 `docs: map codebase`(`fg-map`, 승인 시에만).
