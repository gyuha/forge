---
last_mapped_commit: 0472a519cbb8275564cdbaa30469f2d0c5472842
mapped: 2026-06-10
---

# STACK

forge에는 전통적 의미의 "기술 스택"이 없다. 런타임 코드가 없고, 빌드·테스트·린트 시스템도 없다. 산출물은 전부 **Markdown 문서**(`SKILL.md`, `*-FORMAT.md` 등)와 **JSON 매니페스트**(`plugin.json`, `marketplace.json`)다. 따라서 여기서 말하는 "스택"은 곧 **Claude Code 플러그인 패키징 포맷**이다 — 어떤 파일이 어떤 규약으로 배치되면 Claude Code가 이 리포를 플러그인이자 마켓플레이스로 인식하는가가 전부다.

## 언어·런타임

- **Markdown** — 모든 스킬 본문과 형식 문서. 스킬은 에이전트(Claude)가 읽고 실행하는 자연어 지시문이므로 컴파일·인터프리팅 대상이 아니다.
- **JSON** — 두 매니페스트(`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`)와 런타임 설정(`.forge/config.json`).
- **런타임은 Claude Code 자체**다. forge는 독립 실행 바이너리·프로세스를 갖지 않는다. "실행"이란 사용자가 Claude Code 안에서 `fg-*` 스킬을 트리거하면 Claude가 해당 `SKILL.md` 지시문을 따라 행동하는 것이다.
- 스킬은 셸 명령을 직접 호출하기도 한다. 가장 빈번한 것은 forge 루트 해석을 위한 `git rev-parse --abbrev-ref HEAD`(`skills/fg-run/FORGE-ROOT.md`)이고, JSON 매니페스트 유효성 검증에는 `node -e "..."` 한 줄(레포 CLAUDE.md에 정의)을 쓴다. Node.js는 빌드 도구가 아니라 **JSON 파싱 검증용 일회성 도구**로만 등장한다.

## 빌드·테스트·린트 시스템 (없음 — 사실로 명기)

- `package.json`, `Makefile`, `*.lock`, CI 워크플로 파일 모두 **존재하지 않는다**(레포 루트 확인 완료).
- 의존성 매니페스트가 없으므로 외부 라이브러리 의존성도 **없다**. 설치 시 `npm install`류 단계가 없다.
- 단위 테스트가 없다. 검증은 (1) 매니페스트 JSON이 파싱되는지, (2) 실제로 설치해서 스킬을 트리거해보는지 두 가지뿐이다.
- "개발"이란 Markdown/JSON 파일을 편집하는 것이다.

## 플러그인 패키징 포맷 (이 리포 = 플러그인 + 마켓플레이스)

리포 루트가 곧 플러그인 루트이자 마켓플레이스 루트인 단일 리포 구조다.

- **`.claude-plugin/plugin.json`** — 플러그인 매니페스트. `name`, `description`, `version`, `author`, `homepage`, `repository`, `license`, `keywords` 필드를 담는다. `skills` 필드는 생략 — `skills/<name>/SKILL.md`가 **자동 탐색**되기 때문이다.
- **`.claude-plugin/marketplace.json`** — 이 리포를 마켓플레이스로 등록한다. `name`, `owner`, `metadata`(루프 정의 태그라인 + 버전), `plugins[]` 배열을 담는다. `plugins[0].source`는 `"./"` — 루트가 곧 플러그인.
- **스킬 자동 탐색** — `skills/<dir>/SKILL.md`가 자동 발견된다. **스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name`** 이다. 각 `SKILL.md`는 YAML frontmatter(`name`, `description`)로 시작하고 본문은 Markdown 지시문이다.

## 매니페스트 필드 (현재 값)

| 위치 | 키 | 값 |
| --- | --- | --- |
| `.claude-plugin/plugin.json` | `version` | `0.4.2` |
| `.claude-plugin/plugin.json` | `name` | `forge` |
| `.claude-plugin/plugin.json` | `license` | `MIT` |
| `.claude-plugin/marketplace.json` | `metadata.version` | `0.4.2` |
| `.claude-plugin/marketplace.json` | `plugins[0].version` | `0.4.2` |
| `.claude-plugin/marketplace.json` | `plugins[0].source` | `"./"` |

**버전은 세 곳을 동기 갱신**해야 한다(`plugin.json`의 `version`, `marketplace.json`의 `metadata.version`과 `plugins[0].version`). 현재 모두 `0.4.2`로 일치. 배포 기본은 patch 범프이며, CHANGELOG 갱신 → 버전 3곳 범프 → JSON 검증 → commit → push 순으로 진행한다(레포 CLAUDE.md의 배포 규칙).

## 스킬 목록 (11개, 자동 탐색 대상)

`skills/` 아래 11개 디렉터리, 각각 `SKILL.md` 보유. 루프 4단계 + 루프 밖 유틸리티 7개.

| 디렉터리 | frontmatter `name` | 역할 |
| --- | --- | --- |
| `skills/fg-ask/` | `fg-ask` | ① 질의·계획·그릴링 (루프 진입점) |
| `skills/fg-run/` | `fg-run` | ② 실행 (Dynamic Workflow) |
| `skills/fg-learn/` | `fg-learn` | ③ 회고·문서 승급 |
| `skills/fg-done/` | `fg-done` | ④ 완료·봉인·재실행 가드 |
| `skills/fg-map/` | `fg-map` | 코드베이스 지도 (병렬 subagent) |
| `skills/fg-quick/` | `fg-quick` | 경량 차선 (사소한 작업) |
| `skills/fg-status/` | `fg-status` | 읽기 전용 상태 리포터 |
| `skills/fg-next/` | `fg-next` | 다음 단계 도출+실행 오케스트레이터 |
| `skills/fg-tdd/` | `fg-tdd` | TDD 모드 토글 (`.forge/config.json`) |
| `skills/fg-merge/` | `fg-merge` | 브랜치 forge 상태 통합 |
| `skills/fg-cleanup/` | `fg-cleanup` | 오래된 ADR 은퇴 |

## 형식 문서·참조 파일

스킬 디렉터리에 함께 두는 보조 Markdown. 형식 정의는 **한 벌만 존재하며 소유 스킬 디렉터리에 둔다**(복붙 금지). 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>` 경로(스킬 상대경로 `../fg-ask/` 등)로 참조한다.

- `skills/fg-ask/CONTEXT-FORMAT.md`, `skills/fg-ask/ADR-FORMAT.md` — grill-with-docs 원본 형식 정의.
- `skills/fg-run/PLAN-FORMAT.md` — `plan.md` 형식 + 분할 규칙. 생산자는 fg-ask지만 소비자(fg-run) 쪽에 둔다(fg-ask 디렉터리는 verbatim 영역).
- `skills/fg-run/FORGE-ROOT.md` — forge 루트 해석 규칙의 **단일 정의**. 모든 루프 스킬이 참조.
- `skills/fg-run/RUN-ALL.md` — Run-all 절차.
- `skills/fg-learn/RETRO-FORMAT.md` — 회고 형식.

형식·스킬 본문은 모두 **영문**이며, 스킬이 사용자에게 출력하는 언어·산출 문서는 사용자 언어를 따른다.

## 런타임 설정·상태 파일

- **`.forge/config.json`** — 프로젝트 전역 설정 파일(JSON). `defaultBranch`(forge 루트 해석의 기준)와 `tdd`(TDD 모드 플래그)를 담는다. `fg-tdd`가 쓰고 `fg-ask`/`fg-run`/`FORGE-ROOT.md`가 읽는다. **브랜치와 무관하게 항상 top-level `.forge/config.json`** (글로벌 예외 — 브랜치-로컬이면 부트스트랩 역설 발생). 현재 리포에는 파일이 **없으며**, 그 경우 `defaultBranch`는 `main`으로 간주된다.
- **`.forge/` 디렉터리** — 루프의 휘발 상태(plan/run/STATUS/backlog/executed/done)와 영속 문서(CONTEXT/adr/retro/codebase)가 같은 지붕 아래 공존한다. 구분은 위치가 아니라 **git 추적 여부**다.

## 환경 변수·경로 규약

- **`${CLAUDE_PLUGIN_ROOT}`** — Claude Code가 플러그인 설치 위치로 주입하는 환경 변수. 11개 스킬 전부가 형식 문서·FORGE-ROOT 참조에 사용한다(예: `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md`).
- **forge 루트 해석** — `.forge/...` 경로는 모두 "해석된 루트" 기준이다. 기본 브랜치면 `.forge/`, 비-기본 브랜치면 `.forge/branch/<branch>/`(통째로 git 추적). 단일 정의는 `skills/fg-run/FORGE-ROOT.md`. 두 글로벌 예외(`.forge/config.json`, `.forge/codebase/`)는 항상 top-level.

## .gitignore 규약 (스택의 일부 — 추적 경계)

`.gitignore`는 `.forge/`를 기본 제외(`.forge/*`)하되 영속 문서만 화이트리스트로 되살린다.

```
.forge/*
!.forge/CONTEXT.md
!.forge/adr/
!.forge/retro/
!.forge/codebase/
!.forge/config.json
!.forge/branch/
```

- 휘발 상태(plan/run/STATUS/backlog/executed/done)는 **gitignored**.
- 영속 문서(CONTEXT.md·adr/·retro/·codebase/)와 설정(config.json)은 **추적**.
- 비-기본 브랜치 루트(`.forge/branch/`)는 **통째로 추적**(휘발 타입 파일 포함) — ADR-0011의 의도된 비대칭.
- `.claude/worktrees`, `.planning/`(단 `!.planning/codebase/` 화이트리스트), `.DS_Store`도 제외.

## 검증 방법 (빌드 대신)

```bash
# 매니페스트 JSON 유효성 — 편집 후 필수, 깨지면 설치 실패
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

실제 동작 테스트는 설치해서 트리거해보는 것뿐(단위 테스트 없음). 설치는 GitHub 기본 브랜치(`main`)를 당기므로, 설치 테스트하려면 `main`에 push되어 있어야 한다.
