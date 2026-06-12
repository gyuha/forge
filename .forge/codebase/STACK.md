---
last_mapped_commit: 382c3f8346ae5b8b68abbb5a2dabe2ab52a80d62
mapped: 2026-06-12
---

# STACK

forge에는 전통적 의미의 "기술 스택"이 없다. 런타임 코드·빌드·테스트·린트 시스템이 전부 부재하고(`package.json`·`Makefile`·lockfile·CI 워크플로 없음 — 루트 확인 완료), 산출물은 전부 **Markdown 문서**와 **JSON 매니페스트**다. 따라서 이 문서의 "스택"은 곧 **Claude Code 플러그인 패키징 포맷**이다: 어떤 파일이 어떤 규약으로 배치되면 Claude Code가 이 리포를 플러그인이자 마켓플레이스로 인식하는가. 매니페스트 버전은 **v0.4.8**이며, HEAD(`382c3f8`)는 v0.4.8 릴리스 커밋(`f4d6674`) 이후 한 커밋(fg-learn 일괄 승급 모드 + loop.md 멤버십)을 더 담고 있다 — 즉 미배포 변경이 1커밋 존재한다.

## Languages & Formats

- **Markdown** — 모든 스킬 본문(`skills/*/SKILL.md`)과 형식·참조 문서(`*-FORMAT.md`, `skills/fg-run/FORGE-ROOT.md`, `skills/fg-run/RUN-ALL.md`). 스킬은 에이전트(Claude)가 읽고 따르는 자연어 지시문이므로 컴파일 대상이 아니다. 스킬 본문은 영문, 사용자 출력·산출 문서는 사용자 언어(각 SKILL.md에 Language 지시 명문화). 스킬 문서의 흐름도는 Mermaid 금지·텍스트 흐름도만(`CLAUDE.md` 규약 — 렌더링 없이 파싱·diff·grep 가능해야 함).
- **JSON** — 매니페스트 2개(`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`)와 사용자 프로젝트 쪽 런타임 설정(`.forge/config.json`).
- **YAML frontmatter** — 각 `SKILL.md` 머리의 `name`/`description`(스킬 자동 탐색·트리거 매칭의 원천), 그리고 `.forge/codebase/*.md`의 `last_mapped_commit` 신선도 스탬프.

## Runtime — Claude Code 플러그인 호스트

- **런타임은 Claude Code 자체**다. forge는 독립 프로세스를 갖지 않는다. "실행" = 사용자가 트리거 문구를 말하면 Claude가 해당 `SKILL.md`를 따라 행동하는 것.
- **호스트 버전 요구사항은 명시적으로 고정되어 있지 않다.** `plugin.json`에 엔진/버전 제약 필드가 없고 `README.md`에도 최소 버전이 없다. 대신 호스트 기능 의존이 암묵적 요구사항이다: 스킬 자동 탐색, `Agent` 도구(서브에이전트 fan-out), Dynamic Workflow, `AskUserQuestion`, `Skill` 도구(fg-next의 위임 호출), `${CLAUDE_PLUGIN_ROOT}` 환경 변수, (선택적으로) `/goal`·`/workflows` 슬래시 명령. `skills/fg-map/SKILL.md`는 "forge is Claude Code only — the `Agent` tool is always available"이라 명기하고 비-Agent 폴백을 두지 않는다.
- **셸 의존**: `git`(브랜치 판별 `git rev-parse --abbrev-ref HEAD` — `skills/fg-run/FORGE-ROOT.md`; fg-map의 HEAD sha 스탬프; fg-done의 stale-map 감지 `git status --short`)과 `node`(매니페스트 JSON 검증 한 줄 — 아래). Node는 빌드 도구가 아니라 일회성 JSON 파서다.

## Skills Inventory — 13개 (`skills/<dir>/SKILL.md`)

스킬 식별자는 디렉터리명이 아니라 frontmatter `name`이다(현재 13개 모두 디렉터리명과 일치). 루프 4단계 + 루프 밖 9개:

| 스킬 | 역할 | 본문 줄수 | 동반 문서 |
| --- | --- | --- | --- |
| `fg-ask` | 루프 ① 질의·그릴링 (진입점, 항상 대화) | 106 | `CONTEXT-FORMAT.md`(60), `ADR-FORMAT.md`(47) — grill-with-docs verbatim |
| `fg-run` | 루프 ② 실행 (Dynamic Workflow) | 161 | `PLAN-FORMAT.md`(68), `FORGE-ROOT.md`(53, 브랜치 루트 해석 단일 정의), `RUN-ALL.md`(15, Run-all 절차 — progressive disclosure 분리) |
| `fg-learn` | 루프 ③ 회고 (항상 대화) | 114 | `RETRO-FORMAT.md`(47) |
| `fg-done` | 루프 ④ 완료·봉인·재실행 방지 | 126 | — |
| `fg-map` | 코드베이스 지도 유틸리티 (4 병렬 서브에이전트) | 93 | — |
| `fg-quick` | 경량 차선 (형식 산출물 없음) | 66 | — |
| `fg-status` | 읽기 전용 상태 리포터 + 상태 머신 | 102 | — |
| `fg-next` | 다음 단계 도출·실행 오케스트레이터 (`all` 모드 포함) | 128 | — |
| `fg-loop` | goal 주도 한정 재계획 루프 (`.forge/loop.md` 계약) | 121 | — |
| `fg-tdd` | TDD 모드 토글 (`config.json`의 `tdd`) | 47 | — |
| `fg-eco` | 위임 모델 티어링 토글 (`config.json`의 `eco`) | 51 | — |
| `fg-merge` | 브랜치 forge 콘텐츠 통합 유틸리티 | 84 | — |
| `fg-cleanup` | ADR 은퇴 유틸리티 | 63 | — |

형식 문서는 한 벌만 존재하며 소유 스킬 디렉터리에 둔다 — 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(또는 상대경로 `../fg-run/PLAN-FORMAT.md` 등)로 참조하고 복사하지 않는다. 루트 `references/` 디렉터리는 폐지됐다(`CLAUDE.md`).

## 매니페스트 구조 (`.claude-plugin/`)

단일 리포 = 플러그인 + 마켓플레이스(harness 패턴). 리포 루트가 곧 플러그인 루트다.

- **`.claude-plugin/plugin.json`** — 플러그인 매니페스트. 필드: `name`("forge"), `description`(전체 13스킬 카탈로그를 담은 장문), `version`("0.4.8"), `author`, `homepage`/`repository`(`https://github.com/gyuha/forge`), `license`("MIT"), `keywords`. **`skills` 필드 없음** — `skills/<dir>/SKILL.md` 자동 탐색에 의존.
- **`.claude-plugin/marketplace.json`** — 이 리포를 마켓플레이스로 등록. `name`/`owner`, `metadata.description`(루프 ask·plan → execute → retro → done을 정의하는 한 줄 태그라인 — 루프 밖 유틸리티는 여기 넣지 않음), `metadata.version`("0.4.8"), `plugins[0]`: `source: "./"`(루트가 곧 플러그인), `description`(전체 스킬 카탈로그), `version`("0.4.8"), `category`("workflow"), `tags`.

**동기화 규칙 (어기면 어긋남):**

1. **버전 3곳 동시 범프** — `plugin.json`의 `version`, `marketplace.json`의 `metadata.version`과 `plugins[0].version`. 현재 셋 다 `0.4.8`로 일치 확인.
2. **두 카탈로그 description 동행** — `plugin.json`의 `description`과 `marketplace.json`의 `plugins[0].description`은 같은 전체-스킬 설명의 쌍이다. 스킬 추가/변경 시 둘 다 갱신. 단 `metadata.description`은 루프 태그라인이므로 루프 밖 스킬을 넣지 않는다(`CLAUDE.md` 배포 규칙).
3. (매니페스트는 아니지만 같은 규칙) `README.md`와 `README.ko.md`는 번역 쌍 — 한쪽 갱신 시 반드시 양쪽.

## Dependencies

- **패키지 의존성 0개.** npm/pip 류 의존 없음. 유일한 "의존"은 호스트(Claude Code)의 플러그인 시스템과 셸의 `git`·`node`.
- 외부 스킬 연계는 전부 **소프트**(있으면 활용, 없으면 자체 수행): deep-research 능력(`skills/fg-ask/SKILL.md`, ADR-0006), `superpowers:test-driven-development`(`skills/fg-run/SKILL.md` TDD 모드). 하드 의존은 의도적으로 없다.

## Configuration Surfaces — `.forge/config.json`

사용자 프로젝트에 lazy 생성되는 단일 전역 설정 파일(git 추적 — `.gitignore`가 `!.forge/config.json` 화이트리스트). **브랜치 루트 해석의 전역 예외**로, 어느 브랜치에서든 항상 최상위 `.forge/config.json`이다(branch-local이면 `defaultBranch`를 읽기 위한 부트스트랩 역설 — `skills/fg-run/FORGE-ROOT.md`). 이 리포 자체에는 현재 이 파일이 존재하지 않는다(전 키 기본값 적용).

| 키 | 쓰는 쪽 | 읽는 쪽 | 의미 / 기본값 |
| --- | --- | --- | --- |
| `defaultBranch` | (수동 편집) | 모든 루프 스킬의 루트 해석(`FORGE-ROOT.md`) | 기본 브랜치명. 없으면 `"main"`. 현재 브랜치 ≠ 이 값이면 forge 루트가 `.forge/branch/<branch>/` |
| `tdd` | `fg-tdd`(`on`/`off`) | `fg-ask`(작업별 질문의 기본 답) → plan의 `<!-- tdd: on -->` 마커 → `fg-run`(test-first 실행) | TDD 모드 기본값. 없으면 `false` |
| `eco` | `fg-eco`(`on`/`off`) | `fg-run`(Dynamic Workflow 구성 시) | `true`면 위임 워크플로 서브에이전트 모델을 `sonnet`으로 캡 — 내리기만, 세션 모델 불변, 명시적 사용자 지시 우선(ADR-0014). 없으면 `false` |

## Validation Tooling — 빌드/테스트/CI 없음

검증 수단은 아래가 전부다(`CLAUDE.md`):

```bash
# 매니페스트 JSON 유효성 — 편집 후 필수 (깨지면 설치 실패)
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

- **단위 테스트 없음.** 실제 동작 테스트는 설치해서 트리거해보는 것뿐: `/plugin marketplace add gyuha/forge`(또는 로컬 경로) → `/plugin install forge@forge`. 설치는 GitHub `main`을 당기므로 설치 테스트 전제는 main push.
- `/plugin ...` 명령은 interactive라 에이전트가 직접 실행 불가. 에이전트 측 검증은 `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`으로 원격 버전 3곳 확인 + `awk '/^name:/' skills/*/SKILL.md`로 frontmatter `name` 누락 확인.
- 배포 절차: `CHANGELOG.md 작성 → 버전 3곳 범프 → JSON 검증 → commit(chore(release): vX.Y.Z) → main push`.
