---
last_mapped_commit: 21c8bdbf3b13543c1aec209669ec38b57f8f25e2
mapped: 2026-06-04
---

# forge — 외부 통합점

forge는 코드 프로젝트가 아닌 Claude Code 플러그인이므로, 전통적인 데이터베이스·API·인증 통합이 없다. 대신 사용자 환경 및 상위 Claude Code 플랫폼과의 접점을 통해 동작한다.

## 1. GitHub 마켓플레이스 설치 흐름

### 설치 메커니즘

```
User: /plugin marketplace add gyuha/forge
       ↓
Claude Code: GitHub 리모트 확인
       ↓
Clone/pull from https://github.com/gyuha/forge (main 브랜치)
       ↓
`.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json` 검증
       ↓
`skills/*/SKILL.md` 자동 탐색 → 스킬 레지스트리 등록
       ↓
사용자 세션 내 `fg-ask`, `fg-run`, `fg-learn`, `fg-cleanup`, `fg-map`, `fg-quick`, `fg-status` 사용 가능
```

### 버전 제어

- **설치는 `main` 브랜치만 당긴다** — 배포는 `main`에 push하는 것으로 완료됨. feature 브랜치, tag 기반 설치 없음
- **버전 동기화 요구사항**: `plugin.json`과 `marketplace.json`의 버전 필드 3곳(`plugin.json` → `version`, `marketplace.json` → `metadata.version`, `plugins[0].version`)이 항상 일치해야 함
- 버전 불일치는 설치 검증 실패를 유발할 수 있음

### 로컬 설치 (개발)

```
/plugin install /Users/gyuha/workspace/forge
```

로컬 경로 설치는 즉시 로드되며, 파일 변경 시 세션 재시작 없이 다시 로드.

## 2. Upstream: grill-with-docs (mattpocock/skills)

### 출처

forge의 `fg-ask` 스킬은 [grill-with-docs](https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs)의 grilling·문서화 패턴을 **원문 그대로(verbatim)** 계승한다.

### 영속적 동기화

- **파일**: `skills/fg-ask/SKILL.md` (본문 영문 verbatim)
- **형제 형식 문서**: `skills/fg-ask/CONTEXT-FORMAT.md`, `skills/fg-ask/ADR-FORMAT.md` (역시 원문)
- **forge 차용부**: SKILL.md 맨 아래 "Forge integration (minimal)" 섹션에만 forge 루프 연결 로직 추가
  - 백로그 산출 (`.forge/backlog/<slug>.md`)
  - fg-run 핸드오프
  - 회고 환류

### 유지 원칙

- grill-with-docs 본문은 영문 그대로 유지 (원본과의 추적성 확보)
- Forge 통합은 명시적으로 구분된 섹션에만 (해제 가능성 유지)
- CONTEXT·ADR 형식은 원본 호환 유지

### 업스트림 변경 반영

forge가 grill-with-docs의 정기적 업데이트를 추적하지는 않으므로, 원본에 중요한 개선이 있을 때 forge 유지자가 수동으로 통합. 현재는 v0.2.4 기준으로 최종 동기화 상태.

## 3. Claude Code Dynamic Workflow 의존

### fg-run의 핵심 기능

`fg-run` 스킬은 **Claude Code의 Dynamic Workflow** 기능을 직접 의존한다:

- **병렬 서브에이전트**: 대규모 작업(마이그레이션, 감사, 리팩터)을 여러 에이전트가 병렬 실행
- **워크플로우 생성**: `.forge/plan.md`의 "Work slices" 리스트를 읽어 orchestration script 자동 생성
- **배경 실행**: 워크플로우는 세션과 분리되어 백그라운드 실행되며, 사용자는 `/workflows` 명령으로 진행 상황 모니터링
- **비용 추정**: 대규모 작업은 사전에 작은 슬라이스로 비용 시험 후 스케일링

### 환경 요구사항

- Claude Code v2.1.154 이상
- 유료 플랜
- 연구 미리보기(research preview) 활성화

**모레 의존성 없음** — MCP, API 인증, 외부 서비스 호출 불필요. 모든 작업은 Claude Code 세션 내에서 자체 코드·파일 조작으로 수행.

## 4. Claude Code Agent 도구 (fg-map)

### 병렬 매핑 메커니즘

`fg-map` 스킬은 **Claude Code의 `Agent` 도구**를 사용하여 코드베이스 지도를 병렬 생성:

```
fg-map (orchestrator, context 절약)
  ├─ Agent 1: 기술 스택 (STACK.md) → 언어, 프레임워크, 의존성
  ├─ Agent 2: 통합점 (INTEGRATIONS.md) → API, DB, auth, webhook
  ├─ Agent 3: 아키텍처 (ARCHITECTURE.md) → 구조, 계층, 모듈
  ├─ Agent 4: 핵심 흐름 (KEY_FLOWS.md) → 사용자 여정, 데이터 흐름
  └─ [각 에이전트가 `.forge/codebase/` 직접 쓰기]
```

- **병렬 실행**: `Agent` 도구를 `run_in_background: true`로 모두 한 메시지에서 시작
- **컨텍스트 절약**: 각 에이전트가 문서를 직접 쓰므로, orchestrator는 확인(파일 경로 + 줄수)만 받음 — 원본 코드 내용이 orchestrator 컨텍스트에 누적되지 않음 (context rot 방지)
- **읽기 전용 도구**: 각 에이전트는 Read, Grep, Glob, Bash의 읽기 전용 도구만 사용 (파일 수정 없음)

### 다시 실행 (Update 메뉴)

`fg-map`은 `/update` 메뉴로 문서별 부분 재생성 지원하지 않음. 전체 재실행만 가능. (코드베이스 변경이 클 때만 다시 실행)

## 5. 사용자 세션 및 대화 모드

### fg-ask: 반드시 워크플로우 외 대화

- **진행 방식**: 한 질문씩 사용자와 주고받는 대화(conversational grilling)
- **제약**: Dynamic Workflow 안에서는 사용자 입력 불가능하므로, fg-ask는 **절대 워크플로우 화면 안에서 실행되지 않음**
- **결과물**: `.forge/backlog/<slug>.md` (계획), 인라인 `CONTEXT.md` · ADR 갱신

### fg-learn: 대화형 회고

- **진행 방식**: 역시 대화(conversational retro) — 학습 분류, 문서 승급 결정 등에서 사용자 입력 필요
- **비블로킹**: fg-run의 배경 워크플로우 진행 중에도 사용자 세션은 응답 가능 (`/workflows`로 모니터링)

## 6. 파일 시스템 계약

### 입출력 경로

forge의 모든 스킬은 파일 시스템을 통해 상태를 주고받는다:

| 파일/경로 | 생산자 | 소비자 |
|---------|--------|--------|
| `.forge/backlog/<slug>.md` | fg-ask | fg-run (선택 메뉴) |
| `.forge/plan.md` | fg-run (백로그에서 승격) | fg-run (실행 기준), fg-learn (회고 기준) |
| `.forge/run.md` | fg-run | fg-learn (회고 재료) |
| `.forge/STATUS.md` | fg-run (executed), fg-cleanup (done) | fg-learn, fg-cleanup (상태 검증) |
| `.forge/executed/<slug>/` | fg-run (Run all 경로) | fg-learn, fg-cleanup (회고 대기) |
| `.forge/done/<날짜-slug>/` | fg-cleanup (최종 봉인) | fg-ask (slug 충돌 검출), fg-run (완료 판별) |
| `.forge/CONTEXT.md` | fg-ask (인라인 갱신) | fg-run, fg-learn, 모든 스킬 (참조) |
| `.forge/adr/NNNN-<slug>.md` | fg-ask (트레이드오프 발생), fg-learn (승급) | fg-run (참조), fg-ask (재그릴링 시) |
| `.forge/retro/<YYYY-MM-DD>-<slug>.md` | fg-learn | fg-ask (후속 계획 시), fg-cleanup (검증) |
| `.forge/codebase/` | fg-map (병렬 에이전트) | fg-ask (그릴링 전 읽음 — context rot 감소) |

### 상태 불변성

- **활성 슬롯은 항상 1개** — `.forge/plan.md` 하나, 한 번에 한 작업만 진행
- **위치가 곧 상태** — 파일이 어디에 있는지가 상태 정의 (backlog / active slot / executed / done)
- **재실행 방지**: `.forge/done/<날짜-slug>/` 마커가 완료 작업임을 영구 기록

## 7. 버전 동기화 (배포)

### 3곳 필드 동시 갱신

배포 시 **반드시 이 3곳을 동시에 갱신**:

1. `.claude-plugin/plugin.json` → `"version": "X.Y.Z"`
2. `.claude-plugin/marketplace.json` → `"metadata": { "version": "X.Y.Z" }`
3. `.claude-plugin/marketplace.json` → `"plugins[0]": { "version": "X.Y.Z" }`

불일치하면 마켓플레이스 검증 실패.

### 배포 단계

1. `CHANGELOG.md` 갱신 (커밋 요약)
2. 버전 범프 (patch/minor/major)
3. 매니페스트 JSON 검증
4. `chore(release): vX.Y.Z` 커밋 및 `main` push

## 전통적 "통합" 없음

forge는 **다음 요소가 없다**:

- 데이터베이스 (로컬 또는 원격)
- REST API 호출
- OAuth / API 토큰 인증
- 웹훅
- 외부 서비스 폴링
- 패키지 레지스트리(npm, PyPI 등)에의 의존

모든 동작은 **Claude Code 세션 내 파일 조작**과 **사용자와의 대화**로만 이루어진다. 따라서 배포, 업그레이드, 보안 감사가 단순하다.

## 정리

forge의 "통합"은 **상향식**(upward-facing):

- **마켓플레이스 설치**: GitHub의 gyuha/forge 리포 의존 (main 브랜치)
- **상위 플랫폼**: Claude Code의 Dynamic Workflow, Agent 도구 의존
- **원본 출처**: mattpocock/skills의 grill-with-docs 원문 계승
- **파일 시스템**: 사용자 프로젝트의 `.forge/` 디렉터리 (git 추적, 휘발 상태 분리)

수평적 서비스 통합은 없으므로, 각 사용자 프로젝트가 자신의 도구(테스트 러너, 배포 도구, API 클라이언트 등)를 독립 관리한다.
