---
last_mapped_commit: 21c8bdbf3b13543c1aec209669ec38b57f8f25e2
mapped: 2026-06-04
---

# forge 루프 아키텍처

## 요약

forge는 **하나의 작업을 한 바퀴 도는 4단계 루프**다. 각 스킬은 독립적으로 실행되며 `.forge/` 파일로 상태를 주고받아 흐름을 잇는다. 루프 밖의 3개 유틸리티 스킬(fg-map, fg-quick, fg-status)이 부가 기능을 수행한다.

## 4단계 루프

```
fg-ask(①질의·계획·그릴링)
    ↓
fg-run(②실행·Dynamic Workflow)
    ↓
fg-learn(③회고·문서 승급)
    ↓
fg-cleanup(④Cleanup·재실행 방지)
    ↓
(새 작업) fg-ask로 돌아감
```

### 단계별 역할

| 단계 | 스킬 | 입력 | 출력 | 핵심 기능 |
|------|------|------|------|---------|
| ① Ask·Plan | `fg-ask` | 사용자 요청 | `.forge/backlog/<slug>.md` + CONTEXT/ADR | grill-with-docs 방식의 대화형 그릴링. 계획을 도메인·용어·결정에 대고 검증 |
| ② Execute | `fg-run` | `.forge/plan.md` 또는 `.forge/backlog/` | `.forge/run.md` + `.forge/STATUS.md` | 계획을 Dynamic Workflow로 실행. 계획과 실제 차이를 기록 |
| ③ Retro | `fg-learn` | `.forge/run.md` + `.forge/plan.md` | `.forge/retro/*.md` + CONTEXT/ADR 승급 | 실행 결과를 회고하고 학습을 영속 문서로 승급 |
| ④ Cleanup | `fg-cleanup` | `.forge/plan.md` + `.forge/run.md` + `.forge/STATUS.md` | `.forge/done/<date-slug>/` | 작업을 봉인·아카이빙. 활성 상태를 비워 같은 작업의 재실행을 구조적으로 방지 |

## 루프 밖 유틸리티 (3개)

세 개의 스킬이 루프의 4단계에 속하지 않으면서 부가 기능을 제공한다.

### fg-map (코드베이스 지도 유틸리티)

- **언제**: 코드베이스가 충분히 변경되었을 때, 지도가 stale해졌을 때 on-demand로 실행
- **역할**: `.forge/codebase/` 하위 7개 문서로 코드베이스를 구조화된 지도로 작성
- **이유**: fg-ask가 지도를 읽어 context rot을 줄임 (매 루프마다 코드 전체를 다시 탐색하지 않음)
- **산출물**: STACK.md, INTEGRATIONS.md, ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md (각각 `last_mapped_commit` frontmatter 포함)

### fg-quick (경량 차선)

- **언제**: 사소한 작업 (오타·경로·버전 범프)일 때 직접 호출
- **역할**: 가벼운 그릴링 → `.forge/quick/LOG.md`에 한 줄 기록 → 직접 실행 (형식 산출물 없음)
- **제약**: ADR/plan.md/run.md/STATUS/retro 산출물 없음. 메인 루프의 활성 슬롯 건드리지 않음. 작업이 비-trivial로 드러나면 fg-ask로 bail
- **이유**: trivial 작업의 의식 과부하를 피하면서도 그릴링(기둥 1)은 유지. 단, 정식 문서화(기둥 2)는 intentional하게 완화

### fg-status (읽기 전용 리포터)

- **언제**: 상태를 언제든지 조회할 때 on-demand로 실행
- **역할**: `.forge/` 전체를 조사해 현재 활성 작업·백로그·회고 대기·완료 이력을 표 형식으로 출력. 다음 단계를 제시
- **제약**: 아무것도 쓰지 않음. 다음 단계를 자동으로 호출하지 않음
- **이유**: 언제든 현재 위치와 진행 상황을 투명하게 볼 수 있도록 함

## 상태 계약 (`.forge/`의 파일 흐름)

### 휘발 상태 (git 미추적, `.gitignore` 제외)

루프 스킬들이 주고받는 작업 중 파일들. 한 바퀴가 끝나면 아카이빙 또는 삭제됨.

| 파일 경로 | 생산자 | 소비자 | 역할 |
|----------|--------|--------|------|
| `.forge/backlog/<slug>.md` | fg-ask | fg-run | 미실행 계획의 대기열. 여러 계획이 쌓일 수 있음 |
| `.forge/plan.md` (활성 슬롯) | fg-run | fg-run, fg-learn | 현재 실행 중인 계획. 한 번에 하나만 존재 (활성 슬롯 불변성) |
| `.forge/run.md` | fg-run | fg-learn, fg-cleanup | 실행 결과. 계획 vs 실제 차이 기록 |
| `.forge/STATUS.md` (활성 슬롯) | fg-run | fg-learn, fg-cleanup | 상태 마커. `status: executed`, `retro: pending/skipped/<path>` 기록 |
| `.forge/executed/<slug>/` | fg-run (Run all) | fg-learn, fg-cleanup | "Run all" 배치 실행 시 각 작업을 임시 주차. plan/run/STATUS 동반 |
| `.forge/done/<date-slug>/` | fg-cleanup | (아카이브) | 완료된 작업의 봉인 아카이브. plan/run/STATUS(`status: done`) 포함 |

### 영속 문서 (git 추적, `.gitignore` 화이트리스트)

루프의 "연료". 한 번 생성되면 매 루프마다 참고·갱신되며 영속적으로 유지됨.

| 파일 경로 | 생산자 | 역할 |
|----------|--------|------|
| `.forge/CONTEXT.md` | fg-ask (inline), fg-learn (promotion) | 도메인 용어 글로서리. 루프가 진행되며 계속 갱신됨 (멀티 컨텍스트는 예외: src/<context>/CONTEXT.md에 둠) |
| `.forge/adr/NNNN-slug.md` | fg-learn (promotion) | 아키텍처 결정 기록. 되돌리기 어렵고·향후 의아하며·진정한 트레이드오프일 때만 생성 |
| `.forge/retro/YYYY-MM-DD-slug.md` | fg-learn | 세션 회고 로그. 영속 문서 승급 바를 못 넘는 학습의 종착지 |
| `.forge/codebase/*.md` (7 문서) | fg-map | 코드베이스 지도. fg-ask가 그릴링 전에 읽음 |
| `.forge/quick/LOG.md` | fg-quick | 경량 차선 LOG. gitignore 대상 (휘발) |

### 활성 슬롯 불변성

- **한 번에 하나의 작업만 활성** — `.forge/plan.md` = 1개 계획 = 1개 run.md = 1개 봉인
- **백로그는 미실행 대기열** — 여러 계획이 쌓일 수 있음
- **`executed/`는 "실행됐으나 미회고"의 명시적 상태** — Run all 배치 시 활성 슬롯이 비도록 각 작업을 임시 주차
- **활성 슬롯·백로그·executed가 모두 비면 = 진행 중 작업 없음**

## 식별자와 파일 추적

### forge-slug: 회고·봉인 짝 맞춤 식별자

계획 파일의 첫 줄:
```markdown
<!-- forge-slug: settlement-payout-split -->
```

이 slug는 **파일이 이동해도 영속**하는 식별자로서 다음과 같이 쓰임:

- **backlog → plan.md로의 승격**: 파일 이름이 바뀌지만 forge-slug 주석은 유지
- **run.md 이름 매칭**: `<!-- forge-slug: ... -->` 주석으로 run.md가 어느 plan의 결과인지 파악
- **retro 파일 이름**: `.forge/retro/2026-06-04-settlement-payout-split.md` (slug가 파일명의 일부)
- **완료 판별**: `.forge/done/2026-06-04-settlement-payout-split/STATUS.md`의 `status: done` 읽기

### slug 이름 규칙

- **kebab-case** 소문자 (예: `settlement-payout-split`, `update-auth-schema`)
- **충돌 시 -2 접미** (예: `update-auth-schema-2`)
- **아카이브 디렉터리**: `done/YYYY-MM-DD-slug/` (날짜 + slug 조합)

## 상태 시스템과 재실행 방지

### fg-run의 재실행 방지 (re-run guard)

1. **활성 슬롯 존재 확인**: `.forge/plan.md` 있으면 이미 진행 중
2. **백로그 스캔**: `.forge/backlog/` 내 완료 판별 — 각 계획의 slug가 `.forge/done/*/STATUS.md` (`status: done`)에 매칭되면 완료로 간주
3. **백로그 후보 개수에 따른 분기**:
   - 0개: 실행할 계획 없음 → fg-ask 가리키고 중단
   - 1개: 바로 실행 (확인 질문 생략, 승격 후 실행)
   - 2개 이상: 선택 메뉴 표시 + "Run all" 옵션 제시

### fg-cleanup의 재실행 방지 메커니즘 (핵심)

활성 슬롯을 비움으로써 구조적으로 방지:

1. **활성 `.forge/` 확인**: plan.md/run.md/STATUS.md 없으면 진행 중 작업 없음 (멈춤)
2. **회고 가드 확인**: 각 작업에 대해 retro 파일이 존재하거나 STATUS.md에 `retro: skipped`로 기록되어야 진행 (없으면 fg-learn 가리킴)
3. **봉인·아카이빙**: plan/run/STATUS를 `.forge/done/<date-slug>/`로 이동
4. **활성 상태 비우기**: 남겨진 임시 파일 확인 및 삭제. 이 시점에서 `.forge/plan.md` 사라짐 → fg-run이 다음에 실행할 계획이 없음

## STATUS.md 상태 마커

작업의 생명주기를 추적하는 companion 파일:

```yaml
# STATUS — 작업 제목
slug: settlement-payout-split
status: executed                    # executed → done (fg-cleanup이 변경)
executed: 2026-06-04
completed: —                        # fg-cleanup이 채움
retro: pending                      # pending → .forge/retro/path or skipped
docs updated: CONTEXT.md, ADR-0001  # fg-cleanup이 채움
```

**역할**:
- **원천**: 파일 위치가 상태의 진실의 원천. STATUS.md는 수반 마커일 뿐
- **이동**: plan/run/STATUS는 함께 backlog → plan.md (활성) → executed/ 또는 done/로 이동
- **조회**: fg-run은 `done/*/STATUS.md`를 읽어 완료된 작업을 판별. fg-cleanup은 `retro:` 필드로 회고 완료 여부 확인

## 회고 건너뛰기 (ADR-0002)

### retro: skipped 경로

저-divergence 사소한 작업에서만, fg-run 핸드오프에서 명시 선택으로 회고를 건너뜬다:

```yaml
retro: skipped (계획과 실제가 일치)
```

**가드**:
- **divergence 게이팅**: `.forge/run.md`의 계획 ↔ 실제 차이가 없거나 미미할 때만 선택지 제시
- **크게 어긋나면 건너뜨기 선택 없음** — divergence가 크다는 것은 회고가 가장 필요한 신호
- **기본값은 회고** — fg-ask의 `<!-- retro-hint: optional -->` 주석은 구속 없는 힌트일 뿐, 실제 건너뜨기는 fg-run이 divergence 판단 후 결정

**fg-cleanup 수용**:
- 회고 파일 존재 **또는** STATUS.md에 `retro: skipped` → 무결성 가드 통과
- 둘 다 없으면 → fg-learn 가리킴 (회고 강제)

## 두 설계 기둥

### 기둥 1: 그릴링은 대화형, 워크플로우 밖

- **fg-ask**: 한 질문씩 주고받는 conversational grilling. 절대 Dynamic Workflow 안에 넣지 않음 (워크플로우는 실행 중 사용자 입력을 못 받음)
- **fg-quick**: 경량 그릴링이지만 여전히 conversational
- **fg-run, fg-learn, fg-cleanup**: 워크플로우 또는 자동화 가능, 회고는 항상 conversational

### 기둥 2: 문서는 산출물이 아니라 루프의 연료

- **계획 입력**: 다듬은 용어와 결정이 실행의 기준이 됨
- **회고 환류**: 실행 중 배운 내용이 다음 계획의 출발점이 됨
- **경량 경로 (fg-quick)**: trivial 작업에 한해 기둥 2를 intentional하게 완화 (LOG 한 줄, 정식 문서 없음). 단, 기둥 1(그릴링 대화형)은 유지

## 텍스트 흐름 다이어그램

```
┌─────────────────────────────────────────────────────────────────┐
│                        FORGE LOOP                                │
└─────────────────────────────────────────────────────────────────┘

    사용자 요청 (새 작업)
           │
           ▼
    ┌──────────────┐
    │   fg-ask     │  ① 그릴링 · 대화형 · .forge/backlog/<slug>.md 산출
    │  질의·계획   │  
    └──────┬───────┘
           │
     (여러 계획 쌓일 수 있음)
           │
           ▼
    ┌──────────────────────────────────────────┐
    │   fg-run   (선택 메뉴 / Run all)          │  ② 한 계획 선택 및 실행
    │  backlog → plan.md 승격                  │     Dynamic Workflow
    │  ↓ Dynamic Workflow 실행                 │     
    │  ↓ run.md · STATUS.md 기록               │
    └──────┬───────────────────────────────────┘
           │
      ┌────┴────┐
      │          │
   (1개 실행)  (Run all)
      │          │
      ▼          ▼
  .forge/     .forge/
  STATUS.md   executed/
 status:      (<slug>/)
 executed
      │          │
      └────┬─────┘
           │
           ▼
    ┌──────────────┐
    │  fg-learn    │  ③ 회고 · 대화형
    │   회고·승급  │     CONTEXT.md/ADR 승격
    │              │     .forge/retro/*.md 기록
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ fg-cleanup   │  ④ Cleanup · 봉인 · 재실행 방지
    │ 봉인·아카이빙│    plan/run/STATUS → done/<date-slug>/
    │ 활성 상태 비움│    .forge/plan.md 삭제 (→ fg-run이 plan 찾을 수 없음)
    └──────┬───────┘
           │
      ┌────┴─────────────┐
      │                  │
  (new task?)         (end)
      │
      ▼
   fg-ask  ← 다음 루프 시작


┌─────────────────────────────────────────────────────────────────┐
│            LOOP-OUTSIDE UTILITIES (3개)                          │
└─────────────────────────────────────────────────────────────────┘

    fg-map              fg-quick            fg-status
    (on-demand)         (trivial task)      (anytime)
       │                     │                   │
       ├─→ 4 parallel     ┌──┴──┐            ┌──┴──┐
       │   subagents      │light│            │ read│
       │                  │grill│            │only │
       ▼                  └─────┘            └─────┘
    .forge/
    codebase/
    (7 docs)
       │
       │ (fg-ask reads before grilling)
       │
       └──→ context rot 감소
```

## 엔트리 포인트

루프를 시작하는 유일한 공식 진입점은 **fg-ask**다. 루프 밖 유틸리티들은 필요할 때만 호출하며 루프 진행을 방해하지 않는다.

- **새 작업 시작**: fg-ask 호출 (대화형 그릴링)
- **계획 실행**: 자동으로 fg-run 진행
- **회고/정리**: 자동으로 fg-learn → fg-cleanup 진행
- **중간에 코드 변경 있으면**: fg-map으로 지도 갱신 (next fg-ask에서 읽힘)
- **사소한 작업**: fg-quick으로 경량 처리 (루프 밖)
- **현황 조회**: fg-status로 투명성 확보 (읽기 전용)

## 루프의 원자성

한 바퀴(fg-ask → fg-run → fg-learn → fg-cleanup)의 원자성은 다음으로 보장된다:

1. **forge-slug**: 계획의 첫 줄 주석으로 파일 이동에도 영속적 추적
2. **활성 슬롯 불변성**: 한 번에 하나의 작업만 진행 (다른 작업과 섞이지 않음)
3. **파일 위치 기반 상태**: git 추적이 아닌 파일 위치로 상태 결정 (STATUS.md는 수반 마커)
4. **fg-cleanup의 재실행 방지**: plan.md 삭제로 구조적으로 중복 실행 차단
