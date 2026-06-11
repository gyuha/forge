---
last_mapped_commit: 847fa4208a8ef8b709da41d36d106a3f3f92af29
mapped: 2026-06-11
---

# STACK

forge에는 전통적 의미의 "기술 스택"이 없다. 런타임 코드·빌드·테스트·린트 시스템이 전부 부재하고(`package.json`·`Makefile`·lockfile·CI 워크플로 없음 — 루트 확인 완료), 산출물은 전부 **Markdown 문서**와 **JSON 매니페스트**다. 따라서 이 문서의 "스택"은 곧 **Claude Code 플러그인 패키징 포맷**이다: 어떤 파일이 어떤 규약으로 배치되면 Claude Code가 이 리포를 플러그인이자 마켓플레이스로 인식하는가. 현재 버전은 **v0.4.5** (HEAD `847fa42`, 작업 트리에 미커밋 감사 수정 일부 포함).

## Languages & Formats

- **Markdown** — 모든 스킬 본문(`skills/*/SKILL.md`)과 형식·참조 문서(`*-FORMAT.md`, `FORGE-ROOT.md`, `RUN-ALL.md`). 스킬은 에이전트(Claude)가 읽고 따르는 자연어 지시문이므로 컴파일 대상이 아니다. 스킬 본문은 영문, 사용자 출력·산출 문서는 사용자 언어(각 SKILL.md에 Language 지시문 명문화). 흐름도는 Mermaid 금지·텍스트 흐름도만(`CLAUDE.md` 규약 — 렌더링 없이 파싱·diff·grep 가능해야 함).
- **JSON** — 매니페스트 2개(`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`)와 사용자 프로젝트의 런타임 설정(`.forge/config.json`).
- **YAML frontmatter** — 각 `SKILL.md` 머리의 `name`/`description`(스킬 자동 탐색·트리거의 원천), 그리고 `.forge/codebase/*.md`의 `last_mapped_commit` 신선도 스탬프.

## Runtime — Claude Code 플러그인 시스템

- **런타임은 Claude Code 자체**다. forge는 독립 프로세스를 갖지 않는다. "실행" = 사용자가 트리거 문구를 말하면 Claude가 해당 `SKILL.md`를 따라 행동하는 것.
- **버전 요구사항은 명시적으로 고정되어 있지 않다.** `plugin.json`에 엔진/버전 제약 필드가 없고 README에도 최소 버전이 없다. 대신 호스트 기능 의존이 암묵적 요구사항이다: 스킬 자동 탐색, `Agent` 도구(서브에이전트), Dynamic Workflow, `AskUserQuestion`, `${CLAUDE_PLUGIN_ROOT}` 환경 변수. `skills/fg-map/SKILL.md`는 "forge is Claude Code only — the `Agent` tool is always available"이라 명기하고 비-Agent 폴백을 두지 않는다.
- **셸 의존**: `git`(브랜치 판별 `git rev-parse --abbrev-ref HEAD` — `skills/fg-run/FORGE-ROOT.md`, 커밋 sha 스탬프, fg-map의 커밋 제안)과 `node`(매니페스트 JSON 검증 한 줄 — 아래). Node는 빌드 도구가 아니라 일회성 파서다.

## Skills Inventory — 12개 (`skills/<dir>/SKILL.md`)

스킬 식별자는 디렉터리명이 아니라 frontmatter `name`이다(현재 12개 모두 디렉터리명과 일치). 루프 4단계 + 루프 밖 유틸리티 8개:

| 스킬 | 역할 | 본문 줄수 | 동반 문서 |
| --- | --- | --- | --- |
| `fg-ask` | 루프 ① 질의·그릴링 (진입점, 항상 대화) | 105 | `CONTEXT-FORMAT.md`(60), `ADR-FORMAT.md`(47) — grill-with-docs verbatim |
| `fg-run` | 루프 ② 실행 (Dynamic Workflow) | 158 | `PLAN-FORMAT.md`(68), `FORGE-ROOT.md`(53, 브랜치 루트 해석 단일 정의), `RUN-ALL.md`(15, Run-all 절차 — progressive disclosure로 분리) |
| `fg-learn` | 루프 ③ 회고 (항상 대화) | 104 | `RETRO-FORMAT.md`(47) |
| `fg-done` | 루프 ④ 봉인·재실행 방지 | 126 | — |
| `fg-map` | 코드베이스 지도 (4 병렬 서브에이전트 → `.forge/codebase/` 7문서) | 93 | — |
| `fg-quick` | trivial 작업 경량 차선 (형식 산출물 없음, `.forge/quick/LOG.md` 한 줄) | 66 | — |
| `fg-status` | 읽기 전용 상태 리포터 (아무것도 안 씀) | 99 | — |
| `fg-next` | 다음 단계 도출+실행 오케스트레이터 (`all` 모드 포함) | 126 | — |
| `fg-tdd` | `config.json`의 `tdd` 토글 | 47 | — |
| `fg-eco` | `config.json`의 `eco` 토글 (위임 에이전트 sonnet 캡) | 51 | — |
| `fg-merge` | 브랜치 forge 루트(`.forge/branch/<branch>/`) 통합 | 84 | — |
| `fg-cleanup` | ADR 은퇴 (`.forge/adr/retired/`) | 63 | — |

**형식 문서 단일 소유 규약**: 형식 정의는 소유 스킬 디렉터리에 한 벌만 존재하고, 타 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<owner>/<file>`로 참조한다(복사 금지, 루트 `references/` 폐지됨). 예: plan 형식의 생산자는 fg-ask지만 `PLAN-FORMAT.md`는 소비자인 `skills/fg-run/`에 있다(fg-ask 디렉터리는 verbatim 영역).

## Manifest 구조 — `.claude-plugin/`

리포 루트 = 플러그인 루트 = 마켓플레이스(단일 리포 이중 역할).

- **`.claude-plugin/plugin.json`** — 플러그인 매니페스트. `name: "forge"`, `version: "0.4.5"`, `description`(전체 12 스킬 목록을 담는 긴 설명), `author`/`homepage`/`repository`/`license`/`keywords`. `skills` 필드는 없음 — `skills/`가 자동 탐색되므로 생략.
- **`.claude-plugin/marketplace.json`** — 마켓플레이스 등록. `metadata.description`(루프만 정의하는 한 줄 태그라인 — 루프 밖 유틸리티는 안 넣음), `metadata.version`, `plugins[0]`: `source: "./"`(루트가 곧 플러그인), `version`, `description`(전체 스킬 설명), `category: "workflow"`, `tags`.
- **버전은 3곳 동기**: `plugin.json`의 `version` + `marketplace.json`의 `metadata.version` + `plugins[0].version`. 현재 3곳 모두 `0.4.5`로 일치. 배포 시 셋을 함께 범프한다(`CLAUDE.md` 배포 규칙).
- **두 description의 역할 차이**: `metadata.description`은 루프 정의 태그라인, `plugins[].description`·`plugin.json`의 `description`은 전체 스킬 카탈로그. 스킬 추가/변경 시 둘 다 갱신해야 한다.

## Config Surface — `.forge/config.json` (사용자 프로젝트 측)

git 추적되는 프로젝트 전역 설정 파일. **lazy 생성** — 첫 토글 때 만들어진다(이 리포 자체의 `.forge/`에는 현재 존재하지 않음). **브랜치 루트 해석의 전역 예외**: 어느 브랜치에서든 항상 최상위 `.forge/config.json`이다(`skills/fg-run/FORGE-ROOT.md` — `defaultBranch`를 읽어야 해석이 시작되므로 브랜치-로컬이면 부트스트랩 역설).

| 키 | 쓰는 스킬 | 읽는 스킬 | 의미 |
| --- | --- | --- | --- |
| `tdd` (bool, 기본 `false`) | `fg-tdd` | `fg-ask`(작업별 질문의 기본값 → plan에 `<!-- tdd: on\|off -->` 기록), `fg-run`(마커 on이면 test-first 실행) | 프로젝트 TDD 기본값 |
| `eco` (bool, 기본 `false`) | `fg-eco` | `fg-run`(워크플로 빌드 시 위임 서브에이전트를 `sonnet`으로 캡 — 내리기만, 명시적 사용자 지시 우선; ADR-0014) | 위임 모델 티어링 |
| `defaultBranch` (string, 기본 `"main"`) | (수동) | `FORGE-ROOT.md` 해석 규칙(모든 루프 스킬) | forge 루트 분기 기준 브랜치 |

쓰기 규칙: 기존 키 보존(read → set → write back), JSON 유효성 유지.

## Validation Tooling — 테스트·CI 없음

- **유일한 자동 검증**은 매니페스트 JSON 파싱 한 줄(`CLAUDE.md` 정의):
  ```bash
  node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
  ```
- **단위 테스트·CI 부재.** 실제 동작 테스트는 설치 후 트리거뿐(`/plugin marketplace add gyuha/forge` → `/plugin install forge@forge`). 설치는 GitHub `main`을 당기므로 설치 테스트 전제는 main push.
- 배포 후 에이전트가 할 수 있는 검증: `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`으로 원격 버전 3곳 확인 + `awk '/^name:/'`로 `skills/*/SKILL.md` frontmatter `name` 누락 확인.

## 부속 파일

- `README.md` ↔ `README.ko.md` — 동일 내용의 번역 쌍(한쪽 갱신 시 반드시 함께 갱신하는 동기 규약).
- `CHANGELOG.md` — Keep a Changelog 약식, 최신 섹션 `[0.4.5] - 2026-06-11`.
- `CLAUDE.md` — 리포 작업 규약(배포 절차, 스킬 편집 규약, 상태 계약 요약).
- `docs/forge-vs-loop-engineering.md` — 비교 문서(현재 git 미추적 신규 디렉터리).
- `.forge/` — 이 리포 자신도 forge 루프를 사용한다(dogfooding): `adr/`(0001~0015), `retro/`, `codebase/`(본 지도), `backlog/`·`done/`·`quick/`(휘발).
