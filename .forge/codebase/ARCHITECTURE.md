---
last_mapped_commit: 8aaed407ae96e0d59f87de00424a18a652577950
mapped: 2026-06-27
---

# forge 아키텍처

## 진입점

모든 작업은 **`fg-ask`** 에서 시작한다. fg-ask는 대화형 그릴링을 거쳐 `.forge/backlog/<slug>.md` 에 계획(plan)을 만들어 두고, fg-run이 그 계획을 실행한다.

## 4단계 루프

루프는 한 작업을 한 바퀴 돌리는 단방향 파이프라인이다.

```
① fg-ask → ② fg-run → ③ fg-learn → ④ fg-done → (새 작업) ① fg-ask
```

각 단계는 독립 실행되며, `.forge/` 파일을 매개로 상태를 전달한다.

### ① fg-ask — 질의·그릴링·계획

- 대화 중 `CONTEXT.md`, ADR을 인라인으로 갱신한다.
- `.forge/codebase/*.md` 를 먼저 읽어 컨텍스트 로트를 줄인다.
- 작업 완료 시 `.forge/backlog/<slug>.md` 를 생성한다.
- 항상 워크플로우 밖 대화로 진행한다 (기둥 #1).
- `.forge/config.json` 의 `tdd` 설정을 기본값으로 TDD 여부를 묻는다.
- `fg-loop` 가 생성한 `.forge/loop.md` 가 있으면 활성 goal 루프 진행 중임을 경고한다.

### ② fg-run — 실행 (Dynamic Workflow)

- `.forge/backlog/` 에서 계획을 선택해 `.forge/plan.md` (활성 슬롯)으로 승격한다.
- Claude Code Dynamic Workflow로 실행 후 `.forge/run.md` 에 계획↔실제 차이를 기록한다.
- 실행 완료 후 UAT를 수행해 `.forge/STATUS.md` 의 `verified:` 필드를 기록한다.
- 검증 게이트(ADR-0009): `verified: yes/skipped/n/a` 면 봉인 가능, `pending/failed` 이면 차단.
- `eco` 가 `true` 이면 위임 서브에이전트를 `sonnet` 으로 캡하고 `ECO.md` 규율을 주입한다.
- **도메인 에이전트 디스패치**: 프로젝트에 `.claude/agents/<role>.md` 카드가 있으면 슬라이스를 `agentType: '<role>'` 로 디스패치한다. 없으면 동작 변화 없다(graceful/optional — ADR-0024).
- 핸드오프는 진술형 — "다음은 fg-learn"을 알리고 멈춘다(ADR-0015).

### ③ fg-learn — 회고 (Retro)

- `.forge/run.md` 와 `.forge/plan.md` 를 비교해 divergence를 분류한다.
- 학습을 `CONTEXT.md`, ADR, `.forge/retro/YYYY-MM-DD-<slug>.md` 로 승급한다.
- 검증 게이트: `verified: pending` 이면 fg-run으로, `failed` 이면 fg-run (실패 작업 복구)으로 라우팅.
- divergence가 낮으면 회고 건너뛰기 제시 → 건너뛰면 `STATUS.md: retro: skipped (사유)` 기록(ADR-0002).
- 항상 대화형으로 진행한다 — 워크플로우로 자동 생성하지 않는다.

### ④ fg-done — 완료·봉인

- 검증 게이트(먼저) + 회고 게이트(다음) 순서로 확인한다.
- 통과하면 `.forge/done/<날짜-slug>/` 에 `plan.md`, `run.md`, `STATUS.md` 를 보관하고 활성 슬롯을 비운다.
- `STATUS.md` 의 `status:` 를 `done` 으로 마감한다.
- 활성 슬롯을 비우는 것이 재실행 방지의 핵심 메커니즘이다.
- `fg-done all` 은 이미 실행된 작업 전부를 회고 자동 skip하고 일괄 봉인한다(ADR-0023).

## 상태 계약 — `.forge/` 파일 흐름

### 활성 슬롯 (항상 1개)

활성 슬롯은 `.forge/plan.md` 하나뿐이다. 슬롯이 비어 있으면 작업 없음 = fg-run 실행 불가.

```
.forge/backlog/<slug>.md    ← fg-ask 생성
        │ fg-run 승격
        ▼
.forge/plan.md              ← 활성 슬롯 (한 번에 1개)
.forge/run.md               ← fg-run 기록 (계획↔실제 차이)
.forge/STATUS.md            ← 동반 마커 (status/verified/retro 필드)
        │ "Run all" 배치 파킹
        ▼
.forge/executed/<slug>/     ← 실행됐으나 미회고 상태
 plan.md / run.md / STATUS.md
        │ fg-learn 회고 + fg-done 봉인
        ▼
.forge/done/<날짜-slug>/    ← 봉인 완료 (STATUS.md: status: done)
 plan.md / run.md / STATUS.md
```

`.forge/review.md` 는 `fg-adversarial-review` 가 생성하는 휘발 파일 — 활성 슬롯과 동행하며 선택적·비-게이트.

### STATUS.md 필드

| 필드 | 값 | 의미 |
|------|-----|------|
| `status:` | `executed` / `done` | 실행 완료 / 봉인 완료 |
| `verified:` | `yes(증거)` / `skipped(사유)` / `n/a(사유)` | 봉인 가능 |
| `verified:` | `pending` / `failed(사유)` | 봉인 차단 |
| `retro:` | 경로 / `skipped(사유)` | 회고 완료 or 건너뜀 |
| `reviewed:` | 경로 (선택적) | 적대적 리뷰 기록 — 봉인 게이트 아님 |

### 식별자

- **slug** — plan 첫 줄의 `<!-- forge-slug: <slug> -->` 주석. 파일 이동 후에도 영속.
- **task 번호** — plan의 `task:` 마커. 단조 증가, 재사용 금지.

## Forge Root 분기 (ADR-0011)

기본 브랜치(`config.json:defaultBranch`, 없으면 `main`) 면 forge root = `.forge/`, 다른 브랜치면 `.forge/branch/<branch>/`.

전역 예외 2개 — 모든 브랜치에서 항상 최상위 `.forge/` 사용:
- `.forge/config.json` — 브랜치 독립 전역 설정 (`tdd`, `eco`, `defaultBranch`).
- `.forge/codebase/` — fg-map이 생성하는 공유 코드베이스 맵.

`scripts/resolve-forge-root.sh` / `scripts/resolve-forge-root.js` 가 결정론적 스크립트 구현체다(ADR-0022, 이중 디스패치: bash 우선, node 폴백).

비-기본 브랜치 상태는 git 추적된다 (`.gitignore` 가 `.forge/branch/` 화이트리스트). 기본 브랜치 휘발 상태는 gitignored.

## 두 기둥

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** fg-ask는 항상 대화. 워크플로우는 실행 중 사용자 입력을 받지 못한다.
2. **문서는 산출물이 아니라 루프의 연료다.** `CONTEXT.md` 용어 → 실행 기준 → 회고 학습 → 다음 계획의 출발점.

## 도메인 에이전트 실행 경로 (ADR-0024)

프로젝트별 도메인 에이전트는 `.claude/agents/<role>.md` 에 둔다. 각 카드는 YAML frontmatter(`name`, `description`) + 시스템 프롬프트 본문으로 구성된다.

```
fg-agents 그릴링 (대화)
      │ 역할 승인
      ▼
.claude/agents/<role>.md 생성
      │ 세션 재시작 필요 (카드는 세션 시작 시 1회만 로드)
      ▼
fg-run이 슬라이스에 agentType: '<role>' 로 디스패치
      │ 카드 description의 "when to use"로 슬라이스↔역할 매칭
      ▼
해당 role 에이전트가 슬라이스를 실행
```

두 가지 하드 사실:
1. 세션 시작 시 한 번만 로드 — 중간에 생성한 카드는 재시작 전까지 fg-run이 디스패치 불가.
2. 에이전트는 **사용자 프로젝트 소속** — forge 플러그인이 소유하거나 강제하지 않는다(ADR-0013 비충돌).

forge 자체 dogfood 에이전트 (`.claude/agents/`): `skill-author.md`, `manifest-doc-syncer.md` — forge 리포 내 스킬 문서 작성과 매니페스트 동기화 전담.

## 루프 밖 유틸리티 — 스킬 간 핸드오프 없음

루프 밖 스킬은 `.forge/` 를 읽거나 쓰되 루프 단계에 속하지 않으며 fg-next / fg-loop 자동 오케스트레이션에서 건너뛴다.

| 스킬 | 입력 | 출력 | 비고 |
|------|------|------|------|
| `fg-map` | 코드베이스 | `.forge/codebase/*.md` | 7문서 병렬 생성 |
| `fg-quick` | 대화 | `.forge/quick/LOG.md` 한 줄 | trivial 작업 경량 차선(ADR-0003) |
| `fg-status` | `.forge/` | 읽기 전용 보고 | 아무것도 쓰지 않음 |
| `fg-next` | `.forge/` | 다음 단계 실행 | `all` 모드: 벽까지 자동 진행(ADR-0010) |
| `fg-loop` | 대화 + `.forge/` | `.forge/loop.md` + 루프 주행 | 목표 주도 유한 재계획(ADR-0016) |
| `fg-tdd` | 대화 | `.forge/config.json` | TDD 모드 토글 |
| `fg-eco` | 대화 | `.forge/config.json` | Eco 모드 토글(ADR-0014) |
| `fg-merge` | `.forge/branch/<branch>/` | `.forge/` | git merge 후 forge 상태 통합(ADR-0011) |
| `fg-cleanup` | `.forge/adr/` | `.forge/adr/retired/` | 폐기된 ADR 은퇴(ADR-0012) |
| `fg-statusline` | `.forge/` | `settings.json` + 스크립트 설치 | 터미널 상태바 설정(ADR-0017) |
| `fg-adversarial-review` | `.forge/run.md` | `.forge/review.md` | 선택적·비-게이트(ADR-0018) |
| `fg-doctor` | `.forge/` + 매니페스트 | 읽기 전용 보고 | 무결성 점검(ADR-0019) |
| `fg-drop` | `.forge/` | 불완전 작업 삭제 또는 `.forge/dropped/` | 폐기 유틸리티(ADR-0021) |
| `fg-agents` | 대화 + `.forge/codebase/` | `.claude/agents/<role>.md` | 도메인 에이전트 생성(ADR-0024) |

## 검증 게이트 (ADR-0009)

루프 순서: run → verify → learn → done. fg-done은 검증 게이트를 회고 게이트보다 먼저 확인한다.

```
verified: yes/skipped/n/a  →  봉인 가능
verified: pending           →  fg-run 검증 전용 재진입 (재실행 없음)
verified: failed            →  fg-run fix-and-re-run 또는 fg-ask 재그릴
```

`failed` 파킹 작업의 unpark는 fg-run 단독 소유 (`executed/<slug>/` → 활성 슬롯).

## 회고 건너뛰기 (ADR-0002)

fg-run 핸드오프에서 divergence가 낮을 때만 "회고 / 건너뛰기" 선택지를 제시한다. 건너뛰면 `STATUS.md: retro: skipped (사유)`. fg-done 봉인 가드는 retro 파일 존재 **또는** `retro: skipped` 를 통과 조건으로 인정한다.

## 현재 ADR 수

`.forge/adr/` 에 0001–0025 총 25개. `retired/` 폴더에 은퇴된 ADR이 별도 보관된다. ADR 번호는 단조 증가하며 재사용·삭제하지 않는다.
