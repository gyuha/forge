---
last_mapped_commit: 41c10d7cb477eddab9b7d0f1aa8bd23bbcf34d98
mapped_date: 2026-06-09
---

# forge — 외부 통합점

forge는 코드 프로젝트가 아닌 Claude Code 플러그인이므로, 전통적인 데이터베이스·API·인증 통합이 없다. 대신 사용자 환경 및 상위 Claude Code 플랫폼과의 접점을 통해 동작한다. 모든 "통합"은 상향식(upward-facing)이다.

## 1. Claude Code 스킬 자동 탐색

forge가 Claude Code에 노출되는 1차 통합점은 **스킬 자동 탐색**이다.

- 스킬은 `skills/<name>/SKILL.md` 패턴에 놓이면 자동 탐색된다 — `plugin.json`에 명시적 `skills` 필드 불필요.
- **스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name`**이다. `name` 누락 시 그 스킬은 등록되지 않는다(배포 후 검증 항목: `awk '/^name:/' skills/*/SKILL.md`).
- 현재 11개: `fg-ask`, `fg-run`, `fg-learn`, `fg-done`(④봉인), `fg-map`, `fg-quick`, `fg-status`, `fg-next`, `fg-tdd`, `fg-merge`, `fg-cleanup`(ADR 은퇴).

## 2. GitHub 마켓플레이스 설치 흐름

설치 메커니즘:

```
User: /plugin marketplace add gyuha/forge
       ↓
Claude Code: GitHub 리모트 확인
       ↓
Clone/pull from https://github.com/gyuha/forge (main 브랜치)
       ↓
`.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json` 검증
       ↓
`skills/*/SKILL.md` 자동 탐색 → 11개 스킬 레지스트리 등록
       ↓
사용자 세션에서 모든 fg-* 스킬 사용 가능
```

- **설치는 `main` 브랜치만 당긴다** — 배포는 `main`에 push하는 것으로 완료됨. tag 기반 설치 없음
- **버전 동기화 요구사항**: 버전 필드 3곳(`plugin.json` → `version`, `marketplace.json` → `metadata.version`, `plugins[0].version`)이 항상 일치
- **로컬 설치(개발)**: `/plugin install /Users/gyuha/workspace/forge` — 로컬 경로 설치는 즉시 로드
- `/plugin install`·`/plugin marketplace update`는 interactive 명령이라 에이전트가 실행 못 한다(사용자가 직접 침)

## 3. Upstream: grill-with-docs (mattpocock/skills)

forge의 `fg-ask` 스킬은 [grill-with-docs](https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs)의 grilling·문서화 패턴을 **원문 그대로(verbatim)** 계승한다.

- **파일**: `skills/fg-ask/SKILL.md` (본문 영문 verbatim)
- **형제 형식 문서**: `skills/fg-ask/CONTEXT-FORMAT.md`, `skills/fg-ask/ADR-FORMAT.md` (역시 원문)
- **forge 차용부**: SKILL.md 맨 아래 "Forge integration (minimal)" 섹션에만 forge 루프 연결 로직(백로그 산출, fg-run 핸드오프, 회고 환류) 추가
- **유지 원칙**: 원문은 영문 그대로(추적성), forge 통합은 명시 구분 섹션에만, CONTEXT·ADR 형식은 원본 호환 유지
- forge는 업스트림 정기 업데이트를 추적하지 않으므로 중요한 개선이 있을 때 유지자가 수동 통합

## 4. Claude Code Dynamic Workflow 의존 (fg-run)

`fg-run` 스킬은 **Claude Code의 Dynamic Workflow** 기능을 직접 의존한다:

- **병렬 서브에이전트**: 대규모 작업(마이그레이션, 감사, 리팩터)을 여러 에이전트가 병렬 실행
- **워크플로우 생성**: `.forge/plan.md`의 "Work slices"를 읽어 orchestration script 자동 생성. 스크립트 승인이 실제 워크플로우 실행을 게이트한다(이 승인이 `fg-next all`의 대화 벽 중 하나)
- **배경 실행**: 워크플로우는 세션과 분리되어 백그라운드 실행, 사용자는 `/workflows`로 모니터링
- **MCP·API·외부 서비스 의존 없음** — 모든 작업은 세션 내 파일 조작으로 수행

## 5. Claude Code Agent 도구 (fg-map)

`fg-map`은 **`Agent` 도구**를 사용해 코드베이스 지도를 4개 병렬 서브에이전트로 생성:

```
fg-map (orchestrator, context 절약)
  ├─ Agent 1 (tech): STACK.md + INTEGRATIONS.md
  ├─ Agent 2 (arch): ARCHITECTURE.md + STRUCTURE.md
  ├─ Agent 3 (quality): CONVENTIONS.md + TESTING.md
  └─ Agent 4 (concerns): CONCERNS.md
  [각 에이전트가 `.forge/codebase/` 직접 쓰기]
```

- **병렬 실행**: `Agent` 도구를 `run_in_background: true`로 한 메시지에서 4개 모두 시작
- **컨텍스트 절약**: 각 에이전트가 문서를 직접 쓰므로 orchestrator는 확인(파일 경로 + 줄수)만 받음 — 원본 코드가 orchestrator 컨텍스트에 누적되지 않음(context rot 방지)
- **읽기 전용 탐색**: 각 에이전트는 Read, Grep, Glob, Bash의 읽기 전용 도구만 사용
- **staleness 스탬프**: orchestrator가 `git rev-parse HEAD`로 sha를 한 번 얻어 모든 에이전트 프롬프트에 전달, 각 문서 frontmatter(`last_mapped_commit`)에 박힌다 — fg-ask가 지도의 신선도를 판정하는 근거
- **fallback 없음**: forge는 Claude Code 전용이라 `Agent` 도구가 항상 가용 — 비-Agent 순차 경로 없음. 부분 갱신은 Update 메뉴(문서 단위)로만

## 6. fg-next ↔ 하네스 `/goal` Stop 훅 페어링

`fg-next all`은 task→task로 벽이나 빈 상태까지 자동 진행하지만, 진행 중 진짜 턴 경계(주로 **fg-run 워크플로우 스크립트 승인**)가 턴을 끝낸다. **완전 무인 실행**을 원하면 하네스의 `/goal`(세션 범위 Stop 훅 — 조건이 충족될 때까지 정지를 막음)과 페어링한다:

- **fg-next 자체는 `/goal`을 설정할 수 없다** — `/goal`은 **사용자**가 치는 하네스 슬래시 명령이고, 스킬에는 이를 켤 도구가 없다. 사용자가 발동하는 사용 패턴이다.
- **조건은 "언제 멈춰도 되는가"로 표현**해 벽에서 풀리게 해야 한다 — 정지점은 둘뿐: (1) 빈 상태(활성 슬롯+백로그+executed 모두 빔), (2) 사람 필요 벽(`verified: failed`, 검증 불가 UAT, 진짜 fork, fg-run 스크립트 승인)
- "백로그가 빌 때까지"로만 표현하면 안 된다 — 안전 벽에서도 정지를 막아 ADR-0009/0010이 금하는 행위(자동 fix-and-re-run, 미검증 봉인, 자동 fork 선택)를 강요함
- `/goal`은 사람이 손으로 칠 stateless resume만 자동화할 뿐 fg-next 로직을 바꾸지 않는다

## 7. git 의존 (fg-merge — 비-기본 브랜치 통합)

forge 상태는 비-기본 브랜치에서 `.forge/branch/<branch>/`에 네임스페이스되어 git 추적된다(ADR-0011). 이 통합 흐름이 git과의 접점:

```
fg-ask/run/learn/done on <branch>  → .forge/branch/<branch>/ (git tracked)
       ↓
User: git merge <branch>   (네임스페이스라 충돌 없이 폴더째 들어옴)
       ↓
User: fg-merge <branch>    (git 뒤에 실행)
       ↓
.forge/branch/<branch>/ → .forge/ 로 통합:
  ADR 번호 재부여(교차참조 갱신) · retro 이동 · CONTEXT 용어 병합 · done 합침 · 브랜치 폴더 제거
```

- **fg-merge는 git을 직접 조작하지 않는다** — 사용자가 `git merge` 먼저, 그 다음 fg-merge
- 기계적 부분은 자동, 진짜 충돌(용어 재정의, 기본 브랜치 ADR과 모순되는 incoming ADR)은 정지하고 사람에게 질의
- 글로벌 예외(`config.json`, `codebase/`)는 브랜치-로컬이 아니었으므로 통합 대상 아님

## 8. 사용자 세션 및 대화 모드

- **fg-ask** — 한 질문씩 주고받는 대화(conversational grilling). Dynamic Workflow 안에서는 사용자 입력 불가하므로 **절대 워크플로우 화면 안에서 실행되지 않음**. 결과물: `.forge/backlog/<slug>.md`, 인라인 `CONTEXT.md`·ADR 갱신
- **fg-learn** — 대화형 회고. 학습 분류·문서 승급 결정에서 사용자 입력 필요
- **fg-status / fg-next** — fg-status는 보고만(쓰지 않음), fg-next는 도출 후 곧바로 실행(쓰기는 위임 스킬이 함)
- **fg-quick** — 가볍게 그릴링 후 직접 실행, `.forge/quick/LOG.md`에 한 줄 기록

## 9. 파일 시스템 계약 (스킬 간 상태 전달)

forge의 모든 스킬은 파일 시스템을 통해 상태를 주고받는다. 경로는 모두 **해석된 forge 루트 기준**(기본 브랜치=`.forge/`, 그 외=`.forge/branch/<branch>/`).

| 파일/경로 | 생산자 | 소비자 |
|---------|--------|--------|
| `.forge/backlog/<slug>.md` | fg-ask | fg-run (선택 메뉴·승격) |
| `.forge/plan.md` (활성 슬롯) | fg-run (백로그에서 승격) | fg-run (실행 기준), fg-learn |
| `.forge/run.md` | fg-run | fg-learn (회고 재료) |
| `.forge/STATUS.md` | fg-run (executed + `verified:` UAT 기록), fg-done (done 마감) | fg-learn (sealable일 때만 회고), fg-done (검증 게이트 → 회고 게이트 순, ADR-0009) |
| `.forge/executed/<slug>/` | fg-run (Run all 경로) | fg-learn, fg-done (회고 대기·봉인) |
| `.forge/done/<날짜-slug>/` | fg-done (최종 봉인) | fg-ask (slug 충돌 검출), fg-run (완료 판별) |
| `.forge/CONTEXT.md` | fg-ask (인라인 갱신) | fg-run, fg-learn, 모든 스킬 (참조) |
| `.forge/adr/NNNN-<slug>.md` | fg-ask (트레이드오프), fg-learn (승급) | fg-run·fg-ask (참조), fg-cleanup (은퇴 → `retired/`) |
| `.forge/retro/<YYYY-MM-DD>-<slug>.md` | fg-learn | fg-ask (후속 계획), fg-done (검증) |
| `.forge/codebase/` | fg-map (4 병렬 에이전트) | fg-ask (그릴링 전 읽음 — context rot 감소) |
| `.forge/config.json` | fg-tdd (`tdd`) | fg-ask (`tdd` 읽음), 루트 해석 규칙 (`defaultBranch`) |

상태 불변성:
- **활성 슬롯은 항상 1개** — 한 plan.md = 한 run.md = 한 봉인
- **위치가 곧 상태** — 파일 위치가 상태 정의(backlog / active slot / executed / done)
- **재실행 방지**: fg-done이 봉인하며 활성 상태를 비우는 것이 같은 plan의 재실행을 막는 메커니즘. 완료 판별 = `done/*/STATUS.md`의 `status: done`

## 전통적 "통합" 없음

forge는 데이터베이스, REST API 호출, OAuth/API 토큰 인증, 웹훅, 외부 서비스 폴링, 패키지 레지스트리(npm/PyPI) 의존이 **전혀 없다**. 모든 동작은 Claude Code 세션 내 파일 조작과 사용자 대화로만 이루어진다.

## 정리

forge의 통합은 전부 상향식:
- **스킬 탐색**: `skills/<name>/SKILL.md` + frontmatter `name`
- **마켓플레이스 설치**: GitHub gyuha/forge (main 브랜치)
- **상위 플랫폼**: Dynamic Workflow(fg-run), `Agent` 도구(fg-map), `/plugin marketplace`, 하네스 `/goal` Stop 훅(fg-next)
- **원본 출처**: mattpocock/skills의 grill-with-docs 원문 계승
- **git**: 비-기본 브랜치 forge 상태 추적 + `git merge` 뒤 fg-merge 통합
- **파일 시스템**: 사용자 프로젝트의 `.forge/` (브랜치별 루트, 휘발/영속 분리)
