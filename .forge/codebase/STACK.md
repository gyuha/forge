---
last_mapped_commit: 21c8bdbf3b13543c1aec209669ec38b57f8f25e2
mapped: 2026-06-04
---

# forge — 플러그인 스택

## 개요

forge는 **Claude Code 플러그인**이며 동시에 자신의 설치 마켓플레이스다. 코드를 빌드하는 프로젝트가 아니라, 7개의 `fg-*` 워크플로우 스킬을 패키징한 정적 아티팩트(Markdown + JSON 매니페스트)다.

## 언어 및 형식

- **프로그래밍 언어**: 없음 — 이것은 코드 프로젝트가 아니다
- **콘텐츠 형식**: 
  - **Markdown** (`SKILL.md`, `*-FORMAT.md`, `CONTEXT.md`, `ADR`, 회고, 코드베이스 지도, README 등 모든 산출물)
  - **JSON** (매니페스트: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`)

## 매니페스트 구조

두 파일이 리포의 플러그인·마켓플레이스 정체성을 정의한다:

| 파일 | 역할 | 소유권 |
|------|------|--------|
| `.claude-plugin/plugin.json` | 플러그인 메타데이터(이름, 버전, 저자, 설명) 및 라이선스. `skills/` 디렉터리는 자동 탐색되므로 명시적 `skills` 필드 불필요. 버전: `0.2.4` | 단일 루트 플러그인 |
| `.claude-plugin/marketplace.json` | 마켓플레이스 레지스트리. 이 리포를 마켓플레이스로 등록. `plugins[].source: "./"` 는 루트가 곧 플러그인 소스임을 명시. 버전: `0.2.4` (plugin.json과 동기) | 마켓플레이스 메타 |

두 매니페스트의 버전 필드(`plugin.json`의 `version`, `marketplace.json`의 `metadata.version`과 `plugins[0].version`)는 **항상 3곳 모두 동기화되어야 한다** — 배포 시 함께 갱신.

## 스킬 자동 탐색

스킬은 `skills/<name>/SKILL.md` 패턴으로 배치된다. **스킬의 식별자(identity)는 디렉터리명이 아니라 frontmatter의 `name` 필드**다.

현재 7개 스킬:

| 디렉터리 | frontmatter `name` | 역할 | 루프 위치 |
|---------|-------------------|------|----------|
| `skills/fg-ask/` | `fg-ask` | ① 질의·계획 단계. grill-with-docs 방식 대화형 그릴링. 계획을 도메인·용어·결정에 대고 검증하여 `.forge/backlog/<slug>.md` 산출. **반드시 대화(워크플로우 외)**로 진행 | 루프 내 (1/4) |
| `skills/fg-run/` | `fg-run` | ② 실행 단계. 정제된 `.forge/plan.md`를 Claude Code Dynamic Workflow로 실행. 병렬 서브에이전트로 대규모 작업(마이그레이션, 감사, 리팩터) 조율. `.forge/run.md`에 계획·실제 차이 기록 | 루프 내 (2/4) |
| `skills/fg-learn/` | `fg-learn` | ③ 회고 단계. 실행 결과의 학습을 영속 문서로 승급(CONTEXT.md, ADR, 회고 로그). 항상 대화형 | 루프 내 (3/4) |
| `skills/fg-cleanup/` | `fg-cleanup` | ④ 정리 단계. 한 바퀴의 잔여물 정리. 회고 확인, `STATUS.md`를 `status: done`으로 마감, 작업을 `.forge/done/<날짜-slug>/` 아카이브로 봉인하여 **재실행 방지** | 루프 내 (4/4) |
| `skills/fg-map/` | `fg-map` | 루프 외 유틸리티. 코드베이스를 구조화된 지도(7문서)로 평행 서브에이전트가 매핑. 후속 그릴링이 context rot 없이 지도를 읽음 | 루프 밖 |
| `skills/fg-quick/` | `fg-quick` | 루프 외 경량 차선. 사소한 작업용. 그릴링은 유지하되 형식 산출물(ADR·plan·run·회고) 미생성. `.forge/quick/LOG.md`에 한 줄만 기록 | 루프 밖 |
| `skills/fg-status/` | `fg-status` | 루프 외 읽기 전용 리포터. `.forge/` 상태 조사하여 각 작업의 현황과 다음 단계 출력. 아무것도 기록하지 않음 | 루프 밖 |

## 형식 문서 (스킬 소유 구조)

형식 정의는 소유 스킬의 디렉터리에 단 하나씩만 존재. 다른 스킬은 상대경로로 참조:

| 파일 | 위치 | 용도 | 생성 | 소비 |
|------|------|------|------|------|
| `CONTEXT-FORMAT.md` | `skills/fg-ask/` | CONTEXT.md 형식 정의(용어 글로서리) | fg-ask (인라인 갱신) | fg-ask, fg-run, fg-learn |
| `ADR-FORMAT.md` | `skills/fg-ask/` | 아키텍처 결정 기록 형식 정의 | fg-ask (트레이드오프 발생 시) | fg-learn, fg-run (참조) |
| `PLAN-FORMAT.md` | `skills/fg-run/` | `.forge/plan.md` 형식 정의 및 분할 규칙 | fg-ask (생산) | fg-run (소비 및 형식 기준) |
| `RETRO-FORMAT.md` | `skills/fg-learn/` | `.forge/retro/YYYY-MM-DD-<slug>.md` 형식 | fg-learn (생산) | fg-ask (참조), fg-cleanup (검증) |

모두 **영문**(grill-with-docs 원문 유지). 형식에 정의된 섹션 제목(예: "Assumptions", "Divergences")은 canonical 영문이지만, 실제 생성 문서는 사용자 언어로 작성.

## 검증 및 배포 규칙

### JSON 유효성

빌드·린트 시스템이 없으므로 매니페스트는 수동 검증:

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

### 설치 및 테스트

- 설치: `/plugin marketplace add gyuha/forge` 또는 로컬 경로
- 설치는 GitHub의 기본 브랜치(`main`)를 당기므로, 설치 테스트는 `main`에 push 후 수행
- 실제 스킬 동작은 설치 후 트리거로만 검증(단위 테스트 없음)

### 버전 동기화

배포 시 3곳 버전 필드를 동시에 갱신:
1. `plugin.json` → `version`
2. `marketplace.json` → `metadata.version`
3. `marketplace.json` → `plugins[0].version`

배포 절차:
1. `CHANGELOG.md` 갱신 (마지막 배포 이후의 커밋 요약, Keep a Changelog 형식)
2. 버전 범프 (기본: patch, 사용자 지정 가능: minor/major)
3. JSON 검증 (위 node 한 줄)
4. `chore(release): vX.Y.Z` 커밋 및 `main` push

## 파일 시스템 레이아웃 및 git 추적

### 휘발 상태 (`.forge/` — git 제외)

`.gitignore` 기본 제외 패턴: `.forge/*`

- `.forge/backlog/<slug>.md` — 미실행 계획 대기열
- `.forge/plan.md` — 활성 슬롯(현재 실행 중 작업)
- `.forge/run.md` — 실행 결과 노트
- `.forge/STATUS.md` — 상태 마커(활성 슬롯)
- `.forge/executed/<slug>/` — 실행됐으나 미회고 작업 (plan+run+STATUS)
- `.forge/done/<날짜-slug>/` — 완료 아카이브 (plan+run+STATUS + 회고 파일)

### 영속 문서 (`.forge/` 내부 — git 추적)

`.gitignore` 화이트리스트로 추적:

```
!.forge/CONTEXT.md
!.forge/adr/
!.forge/retro/
!.forge/codebase/
```

- `.forge/CONTEXT.md` — 도메인 용어 글로서리. lazy 생성(용어 필요할 때만)
- `.forge/adr/NNNN-<slug>.md` — 아키텍처 결정. 되돌리기 어렵고, 맥락 없이 의아하고, 진짜 트레이드오프일 때만 승급
- `.forge/retro/<YYYY-MM-DD>-<slug>.md` — 세션 회고 로그. fg-learn이 생산
- `.forge/codebase/` — fg-map이 생산하는 코드베이스 지도 (7문서: `STACK.md`, `INTEGRATIONS.md`, `ARCHITECTURE.md`, `ENTRY.md`, `KEY_FLOWS.md`, `DATA.md`, `THIRD_PARTY.md`)

`CONTEXT.md`는 단일 컨텍스트 전용. 멀티 컨텍스트 프로젝트라면 `CONTEXT-MAP.md`(루트)와 `src/<context>/CONTEXT.md` 별도 배치.

## 플러그인과 마켓플레이스 단일 리포 패턴

forge는 `harness` 플러그인과 동일한 패턴을 따른다: **리포 루트 자체가 플러그인 루트이자 마켓플레이스**. 따라서:

- 복잡한 워크스페이스 구조 없음
- 추가 설정(git submodule, monorepo 도구 등) 불필요
- `.claude-plugin/` 매니페스트만으로 충분

`marketplace.json`의 `plugins[].source: "./"` 는 루트의 모든 `skills/` 폴더를 자동 탐색한다는 뜻.

## README 이중 언어 규칙

- `README.md` (영문)과 `README.ko.md` (한글)는 같은 내용의 번역 쌍
- 한쪽을 갱신하면 다른 쪽도 반드시 같은 변경으로 함께 갱신
- 비동기화 상태는 문서 신뢰도 저하의 직접 원인

## 설계 원칙 (스킬 편집 시 불변)

forge 루프의 핵심 계약:

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다** — fg-ask는 한 질문씩 주고받아야 하므로 반드시 대화(워크플로우 밖)로만 진행
2. **문서는 산출물이 아니라 루프의 연료다** — 계획의 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점

이 둘을 깨면 forge가 forge가 아니게 된다.
