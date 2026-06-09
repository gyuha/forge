---
last_mapped_commit: 41c10d7cb477eddab9b7d0f1aa8bd23bbcf34d98
mapped_date: 2026-06-09
---

# forge — 플러그인 스택

## 개요

forge는 **Claude Code 플러그인**이며 동시에 자신의 설치 마켓플레이스다. 코드를 빌드하는 프로젝트가 아니라, 11개의 `fg-*` 워크플로우 스킬을 패키징한 정적 아티팩트(Markdown + JSON 매니페스트)다.

## 언어 및 형식

- **프로그래밍 언어**: 없음 — 이것은 코드 프로젝트가 아니다. 빌드·테스트·린트 시스템(package.json, Makefile, CI)이 없다.
- **콘텐츠 형식**:
  - **Markdown** (`SKILL.md`, `*-FORMAT.md`, `FORGE-ROOT.md`, `CONTEXT.md`, `ADR`, 회고, 코드베이스 지도, README 등 모든 산출물)
  - **JSON** (매니페스트: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`; 프로젝트 설정: 사용자 프로젝트의 `.forge/config.json`)

## 매니페스트 구조

두 파일이 리포의 플러그인·마켓플레이스 정체성을 정의한다:

| 파일 | 역할 | 소유권 |
|------|------|--------|
| `.claude-plugin/plugin.json` | 플러그인 메타데이터(이름, 버전, 저자, 설명) 및 라이선스. `skills/` 디렉터리는 자동 탐색되므로 명시적 `skills` 필드 불필요. 버전: `0.4.1` | 단일 루트 플러그인 |
| `.claude-plugin/marketplace.json` | 마켓플레이스 레지스트리. 이 리포를 마켓플레이스로 등록. `plugins[].source: "./"` 는 루트가 곧 플러그인 소스임을 명시. 버전: `0.4.1` (plugin.json과 동기) | 마켓플레이스 메타 |

두 매니페스트의 버전 필드(`plugin.json`의 `version`, `marketplace.json`의 `metadata.version`과 `plugins[0].version`)는 **항상 3곳 모두 동기화되어야 한다** — 배포 시 함께 갱신.

**두 description의 역할이 다르다**: `marketplace.json`의 `metadata.description`은 루프(ask·plan → execute → retro → done)를 정의하는 한 줄 태그라인이라 루프 밖 유틸리티를 넣지 않는다. `plugins[].description`(과 `plugin.json`의 `description`)은 전체 11개 스킬 목록을 담으므로 루프 밖 스킬도 반영한다.

## 스킬 자동 탐색

스킬은 `skills/<name>/SKILL.md` 패턴으로 배치된다. **스킬의 식별자(identity)는 디렉터리명이 아니라 frontmatter의 `name` 필드**다.

현재 11개 스킬. **루프는 4단계: fg-ask → fg-run → fg-learn → fg-done**(④봉인 단계). 옛 `fg-cleanup`이 봉인 단계였으나 `fg-done`으로 개명됐고(ADR-0012), 현재 `fg-cleanup`은 **ADR 은퇴 유틸리티**(봉인 단계가 아님)다.

| 디렉터리 | frontmatter `name` | 역할 | 루프 위치 |
|---------|-------------------|------|----------|
| `skills/fg-ask/` | `fg-ask` | ① 질의·계획. grill-with-docs 방식 대화형 그릴링. 계획을 도메인·용어·결정에 대고 검증해 `.forge/backlog/<slug>.md` 산출. **반드시 대화(워크플로우 외)** | 루프 내 (1/4) |
| `skills/fg-run/` | `fg-run` | ② 실행. 정제된 `.forge/plan.md`를 Claude Code Dynamic Workflow로 실행. 병렬 서브에이전트로 대규모 작업 조율. `.forge/run.md`에 차이 기록. 핸드오프 UAT로 STATUS `verified:` 기록 | 루프 내 (2/4) |
| `skills/fg-learn/` | `fg-learn` | ③ 회고. 학습을 영속 문서로 승급(CONTEXT.md, ADR, 회고 로그). 항상 대화형 | 루프 내 (3/4) |
| `skills/fg-done/` | `fg-done` | ④ 봉인. 한 바퀴의 잔여물 정리: 회고 확인, `STATUS.md`를 `status: done`으로 마감, 작업을 `.forge/done/<날짜-slug>/`로 봉인하고 활성 상태를 비워 **재실행 방지** | 루프 내 (4/4) |
| `skills/fg-map/` | `fg-map` | 루프 외 유틸리티. 코드베이스를 구조화된 지도(7문서)로 4개 병렬 서브에이전트가 매핑. 후속 그릴링이 context rot 없이 지도를 읽음 | 루프 밖 |
| `skills/fg-quick/` | `fg-quick` | 루프 외 경량 차선. 사소한 작업용. 그릴링은 유지하되 형식 산출물(ADR·plan·run·회고) 미생성. `.forge/quick/LOG.md`에 한 줄만 기록, 비-trivial 시 fg-ask로 bail | 루프 밖 |
| `skills/fg-status/` | `fg-status` | 루프 외 읽기 전용 리포터. `.forge/` 상태 조사하여 각 작업의 현황과 단일 다음 단계 출력. 아무것도 기록하지 않고 자동 실행 안 함 | 루프 밖 |
| `skills/fg-next/` | `fg-next` | 루프 외 오케스트레이터. fg-status의 상태 머신을 재사용해 단일 다음 단계를 도출하고 곧바로 실행. 기본 one-shot. `all` 모드는 백로그가 빌 때까지 기계적 단계 자동 진행, 대화의 벽에서 정지. 자체적으로 쓰지 않음(위임 스킬이 씀) | 루프 밖 |
| `skills/fg-tdd/` | `fg-tdd` | 루프 외 유틸리티. `.forge/config.json`의 `tdd` 키를 켜고 끔. 켜면 fg-ask가 기본 질의, fg-run이 test-first 실행 | 루프 밖 |
| `skills/fg-merge/` | `fg-merge` | 루프 외 유틸리티. `git merge` 뒤 비-기본 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합(ADR 번호 재부여·교차참조 갱신·retro 이동·CONTEXT 병합·done 합침·브랜치 폴더 제거). git은 직접 조작하지 않음 | 루프 밖 |
| `skills/fg-cleanup/` | `fg-cleanup` | 루프 외 유틸리티 — **봉인 단계 아님**. 낡거나 대체된 ADR을 `.forge/adr/retired/<NNNN>-slug.md`로 은퇴(번호 불변·미삭제). fg-ask가 `retired/`를 source of truth로 안 읽음 (ADR-0012) | 루프 밖 |

## 형식 문서 (스킬 소유 구조)

형식 정의는 소유 스킬의 디렉터리에 단 하나씩만 존재. 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(상대경로 `../fg-ask/` 등)로 참조하고 자체 복사하지 않는다. 루트 `references/` 디렉터리는 폐지됐다.

| 파일 | 위치 | 용도 | 생성 | 소비 |
|------|------|------|------|------|
| `CONTEXT-FORMAT.md` | `skills/fg-ask/` | CONTEXT.md 형식 정의(용어 글로서리) | fg-ask (인라인 갱신) | fg-ask, fg-run, fg-learn |
| `ADR-FORMAT.md` | `skills/fg-ask/` | 아키텍처 결정 기록 형식 정의 | fg-ask (트레이드오프 발생 시) | fg-learn, fg-run (참조) |
| `PLAN-FORMAT.md` | `skills/fg-run/` | `.forge/plan.md` 형식 정의 및 분할 규칙 | fg-ask (생산) | fg-run (소비 및 형식 기준) |
| `RETRO-FORMAT.md` | `skills/fg-learn/` | `.forge/retro/YYYY-MM-DD-<slug>.md` 형식 | fg-learn (생산) | fg-ask (참조), fg-done (검증) |
| `FORGE-ROOT.md` | `skills/fg-run/` | 브랜치별 forge 루트 해석 규칙(ADR-0011)의 단일 정의 | — | 모든 루프 스킬이 참조(복붙 금지) |

모두 **영문**(grill-with-docs 원문 유지). 형식에 정의된 섹션 제목(예: "Assumptions", "Divergences")은 canonical 영문이지만, 실제 생성 문서는 사용자 언어로 작성.

## 검증 및 배포 규칙

### JSON 유효성 (유일한 자동 검증)

빌드·린트 시스템이 없으므로 매니페스트는 수동 검증:

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

스킬 동작에 대한 단위 테스트는 없다 — 설치 후 트리거가 유일한 실동작 검증이다.

### 설치 및 테스트

- 설치: `/plugin marketplace add gyuha/forge` 또는 로컬 경로
- 설치는 GitHub의 기본 브랜치(`main`)를 당기므로, 설치 테스트는 `main`에 push 후 수행
- `/plugin install`·`/plugin marketplace update`는 interactive 명령이라 에이전트가 실행 못 함 — 사용자가 직접 친다. 에이전트가 검증 가능한 것은 원격 main의 버전 3곳(`curl raw.githubusercontent.com/...`)과 `skills/*/SKILL.md`의 frontmatter `name` 누락 여부뿐

### 버전 동기화

배포 시 3곳 버전 필드를 동시에 갱신:
1. `plugin.json` → `version`
2. `marketplace.json` → `metadata.version`
3. `marketplace.json` → `plugins[0].version`

배포 절차: `CHANGELOG.md 작성 → 버전 3곳 범프 → JSON 검증 → commit → main push`
- 기본 버전 범프는 patch (사용자가 "배포 minor"/"배포 major" 지정 시 그에 따름)
- 미커밋 변경이 곧 릴리스 내용이면 먼저 별도 `feat` 커밋으로 묶은 뒤 릴리스 커밋(CHANGELOG+버전만)을 돈다

## 파일 시스템 레이아웃 및 git 추적

### 브랜치별 forge 루트 (ADR-0011)

forge 루트는 브랜치에 따라 해석된다. 단일 정의는 `skills/fg-run/FORGE-ROOT.md`다(모든 루프 스킬이 참조).

- **기본 브랜치** (`.forge/config.json`의 `defaultBranch`, 없으면 `main`) → 루트는 `.forge/`. 휘발 상태는 gitignored, 영속 문서만 추적.
- **비-기본 브랜치** → 루트는 `.forge/branch/<branch>/`이고 **통째로 git 추적**(`.gitignore`가 `!.forge/branch/`로 화이트리스트). 경로가 브랜치별 네임스페이스라 두 브랜치가 같은 파일을 안 건드려 머지 충돌이 없다. `git merge` 뒤 `fg-merge`가 `.forge/`로 통합.
- **글로벌 예외 2개** — `.forge/config.json`과 `.forge/codebase/`는 브랜치 무관하게 항상 최상위 `.forge/`에 둔다(브랜치 루트로 복사 안 함).

### 휘발 상태 (해석된 루트 기준 — 기본 브랜치는 git 제외)

`.gitignore` 기본 제외 패턴: `.forge/*`

- `.forge/backlog/<slug>.md` — 미실행 계획 대기열
- `.forge/plan.md` — 활성 슬롯(현재 실행 중 작업, 항상 1개)
- `.forge/run.md` — 실행 결과 노트
- `.forge/STATUS.md` — 상태 마커(작업 파일과 함께 이동하는 동반 마커)
- `.forge/executed/<slug>/` — 실행됐으나 미회고 작업 (plan+run+STATUS)
- `.forge/done/<날짜-slug>/` — 완료 아카이브 (plan+run+STATUS + 회고 파일)
- `.forge/quick/LOG.md` — fg-quick의 경량 로그

### 영속 문서 (`.forge/` 내부 — git 추적)

`.gitignore` 화이트리스트로 추적:

```
!.forge/CONTEXT.md
!.forge/adr/
!.forge/retro/
!.forge/codebase/
!.forge/config.json
!.forge/branch/
```

- `.forge/CONTEXT.md` — 도메인 용어 글로서리. lazy 생성. (멀티 컨텍스트라면 `CONTEXT-MAP.md`(루트)와 `src/<context>/CONTEXT.md` 별도 배치)
- `.forge/adr/NNNN-<slug>.md` — 아키텍처 결정. 은퇴된 것은 `.forge/adr/retired/`(fg-cleanup)
- `.forge/retro/<YYYY-MM-DD>-<slug>.md` — 세션 회고 로그. fg-learn이 생산
- `.forge/codebase/` — fg-map이 생산하는 코드베이스 지도 (7문서: `STACK.md`, `INTEGRATIONS.md`, `ARCHITECTURE.md`, `STRUCTURE.md`, `CONVENTIONS.md`, `TESTING.md`, `CONCERNS.md`)
- `.forge/config.json` — 프로젝트 전역 설정. `defaultBranch`(브랜치 루트 해석에 선행 필요)와 `tdd` 키. fg-tdd가 쓰고 fg-ask가 읽음

## 플러그인과 마켓플레이스 단일 리포 패턴

forge는 `harness` 플러그인과 동일한 패턴을 따른다: **리포 루트 자체가 플러그인 루트이자 마켓플레이스**. 복잡한 워크스페이스 구조·monorepo 도구·git submodule 불필요. `marketplace.json`의 `plugins[].source: "./"` 는 루트의 모든 `skills/` 폴더를 자동 탐색한다는 뜻.

## README 이중 언어 규칙

- `README.md` (영문)과 `README.ko.md` (한글)는 같은 내용의 번역 쌍
- 한쪽을 갱신하면 다른 쪽도 반드시 같은 변경으로 함께 갱신

## 설계 원칙 (스킬 편집 시 불변)

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다** — fg-ask는 한 질문씩 주고받아야 하므로 반드시 대화(워크플로우 밖)로만 진행
2. **문서는 산출물이 아니라 루프의 연료다** — 계획의 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점

추가 편집 규약: 스킬 본문·형식 문서는 영문(grill-with-docs verbatim 부분은 영문 그대로). 스킬이 사용자에게 출력하는 언어와 산출 문서는 사용자 언어를 따른다. 스킬 문서의 흐름도는 Mermaid 금지·텍스트 흐름도(에이전트가 파싱·grep·diff하기 위함).
