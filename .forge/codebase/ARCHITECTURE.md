---
last_mapped_commit: 41c10d7cb477eddab9b7d0f1aa8bd23bbcf34d98
mapped_date: 2026-06-09
---

# forge 루프 아키텍처

## 요약

forge는 **하나의 작업을 한 바퀴 도는 4단계 루프**다. 각 스킬은 독립적으로 실행되며 forge 루트(`.forge/` 또는 브랜치 격리 시 `.forge/branch/<branch>/`)의 파일로 상태를 주고받아 흐름을 잇는다. 4단계 루프 외에 **7개의 루프 밖 유틸리티 스킬**(fg-map, fg-quick, fg-status, fg-next, fg-tdd, fg-merge, fg-cleanup)이 부가 기능을 수행한다. 현재 스킬은 총 **11개**다.

## 4단계 루프

```
fg-ask(①질의·계획·그릴링)
    ↓
fg-run(②실행·Dynamic Workflow)
    ↓
fg-learn(③회고·문서 승급)
    ↓
fg-done(④봉인·재실행 방지)
    ↓
(새 작업) fg-ask로 돌아감
```

④단계의 단어는 이제 **done(완료)**이며 스킬은 **fg-done**이다(ADR-0012로 `fg-cleanup`에서 개명). 루프 표기는 `ask·plan → execute → retro → done`. 봉인 전 검증을 포함한 내부 순서는 `run → verify → learn → done`이다.

### 단계별 역할

| 단계 | 스킬 | 입력 | 출력 | 핵심 기능 |
|------|------|------|------|---------|
| ① Ask·Plan | `fg-ask` | 사용자 요청 | `.forge/backlog/<slug>.md` + CONTEXT/ADR | grill-with-docs 방식의 대화형 그릴링. 계획을 도메인·용어·결정에 대고 검증 |
| ② Execute | `fg-run` | `.forge/backlog/` 또는 `.forge/plan.md` | `.forge/run.md` + `.forge/STATUS.md` | 백로그에서 계획을 승격해 Dynamic Workflow로 실행. 계획↔실제 차이 기록. 핸드오프 UAT로 `verified:` 기록 |
| ③ Retro | `fg-learn` | `.forge/run.md` + `.forge/plan.md` | `.forge/retro/*.md` + CONTEXT/ADR 승급 | 실행 결과를 회고하고 학습을 영속 문서로 승급 |
| ④ Done | `fg-done` | `.forge/plan.md` + `.forge/run.md` + `.forge/STATUS.md` | `.forge/done/<date-slug>/` | 작업을 봉인·아카이빙. 활성 상태를 비워 같은 작업의 재실행을 구조적으로 방지 |

## 루프 밖 유틸리티 (7개)

루프의 4단계에 속하지 않으면서 부가 기능을 제공하는 스킬들이다. on-demand로 실행되며 루프 진행을 방해하지 않는다.

### fg-map (코드베이스 지도 유틸리티)

- **역할**: 병렬 서브에이전트로 코드베이스를 `.forge/codebase/` 하위 구조화된 문서로 작성
- **이유**: fg-ask가 그릴링 전에 지도를 읽어 context rot을 줄임 (매 루프마다 코드 전체를 다시 탐색하지 않음)
- **산출물**: `STACK.md`, `INTEGRATIONS.md`, `ARCHITECTURE.md`, `STRUCTURE.md`, `CONVENTIONS.md`, `TESTING.md`, `CONCERNS.md` (각각 `last_mapped_commit` frontmatter 포함)
- **전역 경로**: 브랜치 격리 예외 — 항상 최상위 `.forge/codebase/`에 둠

### fg-quick (경량 차선)

- **역할**: 가벼운 그릴링 → `.forge/quick/LOG.md`에 한 줄 기록 → 직접 실행 (형식 산출물 없음)
- **제약**: ADR/plan.md/run.md/STATUS/retro 산출물 없음. 메인 루프의 활성 슬롯·backlog·done을 일절 건드리지 않음. 작업이 비-trivial로 드러나면 fg-ask로 bail (ADR-0003)
- **이유**: trivial 작업의 의식 과부하를 피하면서도 그릴링(기둥 1)은 유지. 정식 문서화(기둥 2)는 intentional하게 완화

### fg-status (읽기 전용 리포터)

- **역할**: forge 루트 전체를 조사해 활성 슬롯·미실행 backlog·회고 대기·완료 이력·quick 항목을 출력하고, 상태 머신으로 다음 단계 하나를 도출해 트리거와 함께 보여줌
- **제약**: 아무것도 쓰지 않음. 다음 단계를 자동으로 호출하지 않음 (보고만)

### fg-next (오케스트레이터)

- **역할**: fg-status의 상태 머신을 재사용해 다음 단계 하나를 도출하고, 한 줄로 알린 뒤 **그 스킬을 곧바로 실행**함 (fg-status는 보고만, fg-next는 행동까지)
- **모드**: 기본 one-shot (한 단계 실행 후 멈춤). `all` 모드(`fg-next all`)는 백로그가 빌 때까지 선형 기계적 단계를 자동 진행하고(회고는 항상 자동 건너뜀) 대화의 벽(실패/검증불가 UAT·진짜 fork·빈 상태)에서 멈춤 (ADR-0010)
- **쓰기**: 자체적으로는 아무것도 쓰지 않음. 모든 쓰기는 위임받은 스킬이 함

### fg-tdd (TDD 모드 토글)

- **역할**: `.forge/config.json`의 `tdd` 플래그를 토글하는 영속 설정 스킬. 켜지면 fg-ask가 기본적으로 테스트 우선을 묻고 fg-run이 test-first로 실행 (ADR-0008)
- **전역 경로**: 브랜치 격리 예외 — 항상 최상위 `.forge/config.json`

### fg-merge (브랜치 통합 유틸리티)

- **역할**: `git merge`로 비-기본 브랜치를 가져온 **뒤**, 그 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합. ADR 번호를 main의 다음 빈 번호로 재부여(+교차참조 갱신)·retro 이동·CONTEXT 용어 병합·done 이력 합침·브랜치 폴더 제거
- **안전 원칙**: 기계적 작업은 자동, 진짜 충돌(용어 재정의·결정 모순)에서만 멈춰 사람에게 확인. git 조작은 하지 않음 (ADR-0011)

### fg-cleanup (ADR 은퇴 유틸리티)

- **역할**: 낡거나 superseded된 ADR을 활성 결정 집합에서 퇴출. supersede 관계로 보이는 후보를 근거와 함께 제시하고, 사람 승인 시 각 ADR을 `.forge/adr/retired/<NNNN>-slug.md`로 이동하며 상단에 한 줄 supersede/retire 사유를 마킹
- **불변**: 번호는 절대 바뀌거나 재사용되지 않음. 삭제 없음("왜"의 기록 보존). fg-ask는 `retired/`를 정답 소스로 더 이상 읽지 않아 그릴링 연료에서 빠짐 (ADR-0012)
- **주의**: 작업 봉인은 fg-done, ADR 은퇴는 fg-cleanup — 같은 단어가 두 뜻으로 충돌하던 것을 ADR-0012가 분리

## forge 루트 해석 — 브랜치 격리 (ADR-0011)

모든 `.forge/...` 경로는 **해석된 forge 루트 기준**이다. 단일 정의는 `skills/fg-run/FORGE-ROOT.md`이며 모든 루프 스킬이 이를 참조한다(복붙 금지).

해석 규칙:
1. 현재 브랜치 감지 — `git rev-parse --abbrev-ref HEAD`
2. 기본 브랜치 — `.forge/config.json`의 `defaultBranch`, 없으면 `main`
3. 분기:
   - 현재 == 기본 → forge 루트는 `.forge/` (이 기능 이전과 동일)
   - 그 외 → forge 루트는 `.forge/branch/<branch>/`
4. detached HEAD·비-git → `.forge/`로 폴백 + 한 줄 경고

```
스킬이 .forge 경로를 필요로 함
   │
   ▼
branch = git rev-parse --abbrev-ref HEAD
default = .forge/config.json:defaultBranch (없으면 "main")
   │
   ├── branch == default ─────────▶ root = .forge/            (휘발 gitignored, 영속 문서 화이트리스트)
   ├── branch != default ─────────▶ root = .forge/branch/<branch>/  (브랜치 루트 통째로 git 추적)
   └── detached / 비-git ──────────▶ root = .forge/ + 한 줄 경고
   │
   ▼
read/write <root>/plan.md, <root>/adr/, <root>/backlog/, …
```

- **비-기본 브랜치의 루트는 완전한 미니루트이며 통째로 git 추적**된다(`.gitignore`가 `!.forge/branch/`로 화이트리스트). 경로가 브랜치별로 네임스페이스되어 두 브랜치가 같은 파일을 안 건드리므로 git merge 충돌이 원천 차단된다. 기본 브랜치 휘발 상태는 종전대로 gitignored — 의도된 비대칭.
- **전역 예외 둘은 항상 최상위 `.forge/`**: `.forge/config.json`(루트 해석이 *먼저* 읽어야 해 부트스트랩 역설 회피 + 프로젝트 전역 설정), `.forge/codebase/`(공유 참조 연료라 브랜치-로컬이면 갓 만든 브랜치 지도가 비어버림). fg-merge도 이 둘은 통합하지 않음.
- **2-트랙 통합**: 코드는 `git merge`로, forge 문서는 `fg-merge`로 통합.

## 상태 계약 (forge 루트의 파일 흐름)

### 휘발 상태 (기본 브랜치는 git 미추적)

루프 스킬들이 주고받는 작업 중 파일들. 한 바퀴가 끝나면 `done/`으로 봉인됨.

| 파일 경로 | 생산자 | 소비자 | 역할 |
|----------|--------|--------|------|
| `.forge/backlog/<slug>.md` | fg-ask | fg-run | 미실행 계획의 대기열. 여러 계획이 쌓일 수 있음 |
| `.forge/plan.md` (활성 슬롯) | fg-run | fg-run, fg-learn | 현재 실행 중인 계획. 한 번에 하나만 존재 (활성 슬롯 불변성) |
| `.forge/run.md` | fg-run | fg-learn, fg-done | 실행 결과. 계획 vs 실제 차이 기록 |
| `.forge/STATUS.md` (활성 슬롯) | fg-run | fg-run, fg-learn, fg-done | 상태 마커. `status: executed`, `verified: pending/yes/skipped/n/a/failed`, `retro: pending/skipped/<path>` 기록. `verified`는 봉인 게이트(ADR-0009) |
| `.forge/executed/<slug>/` | fg-run (Run all) | fg-learn, fg-done | "Run all" 배치 실행 시 각 작업(sealable만)을 임시 주차. plan/run/STATUS 동반 |
| `.forge/done/<date-slug>/` | fg-done | fg-ask, fg-run, fg-learn, fg-done | 완료된 작업의 봉인 아카이브. plan/run/STATUS(`status: done`) 포함 |
| `.forge/quick/LOG.md` | fg-quick | (참고) | 경량 차선 LOG. 휘발 |

### 영속 문서 (git 추적, `.gitignore` 화이트리스트)

루프의 "연료". 한 번 생성되면 매 루프마다 참고·갱신되며 영속적으로 유지됨.

| 파일 경로 | 생산자 | 역할 |
|----------|--------|------|
| `.forge/CONTEXT.md` | fg-ask (inline), fg-learn (promotion) | 도메인 용어 글로서리 (멀티 컨텍스트는 예외: `src/<context>/CONTEXT.md` + 루트 `CONTEXT-MAP.md`) |
| `.forge/adr/NNNN-slug.md` | fg-learn (promotion) | 아키텍처 결정 기록. 세 조건(되돌리기 어렵다/맥락 없이 의아하다/진짜 트레이드오프) 모두 충족 시만 |
| `.forge/adr/retired/NNNN-slug.md` | fg-cleanup | 은퇴된 ADR. fg-ask가 정답 소스로 읽지 않음 (ADR-0012) |
| `.forge/retro/YYYY-MM-DD-slug.md` | fg-learn | 세션 회고 로그. 영속 문서 승급 바를 못 넘는 학습의 종착지 |
| `.forge/codebase/*.md` (7 문서) | fg-map | 코드베이스 지도. fg-ask가 그릴링 전에 읽음 (전역 경로) |
| `.forge/config.json` | fg-tdd | 프로젝트 전역 설정 (`defaultBranch`, `tdd`). 전역 경로 |

### 활성 슬롯 불변성

- **한 번에 하나의 작업만 활성** — `.forge/plan.md` = 1개 계획 = 1개 run.md = 1개 봉인
- **백로그는 미실행 대기열** — 여러 계획이 쌓일 수 있음
- **`executed/`는 "실행됐으나 미회고"의 명시적 상태** — Run all 배치 시 활성 슬롯이 비도록 각 작업을 임시 주차
- **활성 슬롯·백로그·executed가 모두 비면 = 진행 중 작업 없음**

## 식별자와 파일 추적

### forge-slug: 회고·봉인 짝 맞춤 식별자

계획 파일의 첫 줄에 `<!-- forge-slug: settlement-payout-split -->` 주석이 들어가며, **파일이 이동해도 영속**한다:

- **backlog → plan.md 승격**: 파일 이름이 바뀌지만 forge-slug 주석은 유지
- **run.md 매칭**: 어느 plan의 결과인지 파악
- **retro 파일명**: `.forge/retro/2026-06-04-settlement-payout-split.md`
- **완료 판별**: `.forge/done/2026-06-04-settlement-payout-split/STATUS.md`의 `status: done`

### slug 이름 규칙

- **kebab-case** 소문자
- **충돌 시 `-2` 접미**
- **아카이브 디렉터리**: `done/YYYY-MM-DD-slug/`

## 상태 시스템과 재실행 방지

### fg-run의 재실행 방지 (re-run guard)

1. **활성 슬롯 확인**: `.forge/plan.md` 있으면 이미 진행 중 → run.md가 있으면 `verified:`로 분기: `pending`/누락=검증 전용 재진입(재실행 없이 UAT), `failed`=fix-and-re-run/재그릴, sealable=중복 실행 경고
2. **parked-failed 회수 (백로그 이전)**: 활성 슬롯이 비면 백로그를 세기 전에 `.forge/executed/*/STATUS.md`의 `verified: failed`를 스캔. 있으면 새 백로그보다 우선 — unpark(executed/→active slot) 후 fix-and-re-run. fg-run이 unpark의 단일 소유자
3. **백로그 스캔**: 각 계획의 slug가 `.forge/done/*/STATUS.md`(`status: done`)에 매칭되면 완료로 간주
4. **백로그 후보 개수에 따른 분기**:
   - 0개: 실행할 계획 없음 → fg-ask 가리키고 중단
   - 1개: 바로 실행 (확인 질문 생략, 승격 후 실행)
   - 2개 이상: 선택 메뉴 + "Run all" 옵션

### fg-done의 재실행 방지 메커니즘 (핵심)

활성 슬롯을 비움으로써 구조적으로 방지:

1. **작업 존재 확인**: 활성 슬롯 **그리고** `.forge/executed/`(Run all 파킹)이 **둘 다** 비었을 때만 "작업 없음"으로 보고 멈춤
2. **검증 가드 확인 (no-seal-without-verification, ADR-0009)**: STATUS.md `verified:`가 봉인 가능 값(`yes`/`skipped`/`n/a`)이어야 진행. `pending`/누락=fg-run 검증 전용 재진입, `failed`=수정·재실행/재그릴. **회고 가드보다 먼저** 검사 (순서 run→verify→learn→done)
3. **회고 가드 확인**: retro 파일 존재 **또는** STATUS.md `retro: skipped`여야 진행 (없으면 fg-learn 가리킴)
4. **봉인·아카이빙**: plan/run/STATUS를 `.forge/done/<date-slug>/`로 이동, `status: done` 마감
5. **활성 상태 비우기**: `.forge/plan.md` 사라짐 → fg-run이 다음에 실행할 계획이 없음

## STATUS.md 상태 마커

작업의 생명주기를 추적하는 companion 파일(이중 장부 아님 — 상태의 원천은 파일 위치):

```yaml
# STATUS — 작업 제목
slug: settlement-payout-split
status: executed                    # executed → done (fg-done이 변경)
executed: 2026-06-04
completed: —                        # fg-done이 채움
verified: pending                   # pending/failed=차단, yes/skipped/n/a=봉인 가능 (fg-run UAT, ADR-0009)
retro: pending                      # pending → .forge/retro/path or skipped
docs updated: CONTEXT.md, ADR-0001  # fg-done이 채움
```

- **이동**: plan/run/STATUS는 함께 backlog → plan.md (활성) → executed/ 또는 done/로 이동
- **조회**: fg-run은 `done/*/STATUS.md`로 완료를 판별. fg-done은 `verified:`로 검증 게이트를, `retro:`로 회고 완료를 확인 (검증 → 회고 순)
- ADR-0009 이전 봉인 작업은 `verified: n/a (legacy pre-ADR-0009)`로 백필됨

## 봉인 전 검증 게이트 (ADR-0009)

루프 순서는 `run → verify → learn → done`. fg-run 핸드오프가 plan 목표에 대고 UAT를 수행해 STATUS `verified:`를 기록:

- **봉인 가능**: `yes` / `skipped (사유)` / `n/a (사유)`
- **차단**: `pending`(미검증) / `failed (사유)`(검증했으나 깨짐)

`pending`은 fg-run 검증 전용 재진입(재실행 없이 UAT만)으로, `failed`은 fg-run의 parked-failed 회수·fix-and-re-run 또는 fg-ask 재그릴로 라우팅. `failed`은 fresh re-run으로 재검증될 때만 봉인되며 waiver로 통과시키지 않음.

## 회고 건너뛰기 (ADR-0002)

저-divergence 사소한 작업에서만, fg-run 핸드오프에서 명시 선택으로 회고를 건너뜀(`retro: skipped (사유)`):

- **divergence 게이팅**: run.md의 계획↔실제 차이가 없거나 미미할 때만 선택지 제시
- **크게 어긋나면 건너뛰기 없음** — divergence가 크다는 것은 회고가 가장 필요한 신호
- **기본값은 회고** — fg-ask의 `<!-- retro-hint: optional -->`는 구속 없는 힌트일 뿐
- **fg-done 수용**: retro 파일 존재 **또는** `retro: skipped` → 봉인 가드 통과

## 서브에이전트 도입 보류 (ADR-0013)

explorer/retro-analyzer/verifier 3종 서브에이전트 도입은 **보류**됐다. explorer는 fg-map과 중복이고, 루프가 단계별 스킬 분리로 이미 context rot를 구조적으로 완화하며, verifier는 ADR-0009의 실제 통증(지시문 스킬에 런타임 없음)을 못 고치기 때문. 구체적·재현된 통증이 생기면 그때 해당하는 하나만 만든다.

## 두 설계 기둥

### 기둥 1: 그릴링은 대화형, 워크플로우 밖

- **fg-ask**: 한 질문씩 주고받는 conversational grilling. 절대 Dynamic Workflow 안에 넣지 않음 (워크플로우는 실행 중 사용자 입력을 못 받음)
- **fg-quick**: 경량 그릴링이지만 여전히 conversational
- **fg-run, fg-learn, fg-done**: 워크플로우/자동화 가능, 회고는 항상 conversational

### 기둥 2: 문서는 산출물이 아니라 루프의 연료

- **계획 입력**: 다듬은 용어와 결정이 실행의 기준이 됨
- **회고 환류**: 실행 중 배운 내용이 다음 계획의 출발점이 됨
- **경량 경로 (fg-quick)**: trivial 작업에 한해 기둥 2를 intentional하게 완화. 기둥 1은 유지

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
    │   fg-run   (선택 메뉴 / Run all)          │  ② backlog → plan.md 승격
    │  ↓ Dynamic Workflow 실행                 │     Dynamic Workflow
    │  ↓ run.md · STATUS.md 기록               │
    │  ↓ verify (UAT → verified:)              │     run → verify (ADR-0009)
    └──────┬───────────────────────────────────┘
           │
      ┌────┴────┐
   (1개 실행)  (Run all)
      │          │
      ▼          ▼
  STATUS.md   executed/<slug>/
  status:     (sealable만 주차)
  executed
      │          │
      └────┬─────┘
           │
           ▼
    ┌──────────────┐
    │  fg-learn    │  ③ 회고 · 대화형 · CONTEXT/ADR 승급 · retro/*.md
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │   fg-done    │  ④ 봉인 · 재실행 방지
    │              │    plan/run/STATUS → done/<date-slug>/
    │              │    .forge/plan.md 삭제 (→ fg-run이 plan 못 찾음)
    └──────┬───────┘
           │
      ┌────┴─────────────┐
  (new task?)         (end)
      │
      ▼
   fg-ask  ← 다음 루프 시작


┌─────────────────────────────────────────────────────────────────┐
│            LOOP-OUTSIDE UTILITIES (7개)                          │
└─────────────────────────────────────────────────────────────────┘

  fg-map      fg-quick    fg-status   fg-next    fg-tdd    fg-merge   fg-cleanup
  (지도)      (경량)      (읽기전용)  (오케스)   (TDD토글) (브랜치통합) (ADR은퇴)
    │            │           │          │          │          │          │
    ▼            ▼           ▼          ▼          ▼          ▼          ▼
 codebase/    quick/LOG   보고만     보고+실행  config.json branch→.forge adr/retired/
 (7 docs)
    │
    └─→ fg-ask가 그릴링 전 읽음 → context rot 감소
```

## 엔트리 포인트

루프를 시작하는 공식 진입점은 **fg-ask**다. 콜드 재진입("어디까지 했는지 모름, 다음 거 해줘")의 진입점은 **fg-next**다. 루프 밖 유틸리티는 필요할 때만 호출한다.

- **새 작업 시작**: fg-ask (대화형 그릴링)
- **계획 실행 / 회고 / 봉인**: 핸드오프로 fg-run → fg-learn → fg-done 자동 진행
- **다음 단계 자동 진행**: fg-next (one-shot) / fg-next all (백로그 소진까지)
- **현황 조회**: fg-status (읽기 전용)
- **코드 변경 후 지도 갱신**: fg-map
- **사소한 작업**: fg-quick (루프 밖)
- **브랜치 통합**: git merge 후 fg-merge
- **ADR 은퇴**: fg-cleanup

## 루프의 원자성

한 바퀴(fg-ask → fg-run → fg-learn → fg-done)의 원자성은 다음으로 보장된다:

1. **forge-slug**: 계획 첫 줄 주석으로 파일 이동에도 영속적 추적
2. **활성 슬롯 불변성**: 한 번에 하나의 작업만 진행
3. **파일 위치 기반 상태**: git 추적이 아닌 파일 위치로 상태 결정 (STATUS.md는 수반 마커)
4. **fg-done의 재실행 방지**: plan.md 삭제로 구조적으로 중복 실행 차단
5. **브랜치 격리**: 비-기본 브랜치는 별도 forge 루트에서 운영되어 병렬 작업이 섞이지 않음 (ADR-0011)
