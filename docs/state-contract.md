# forge 상태 계약과 디렉터리

> README의 「공유 상태와 디렉터리」를 풀어 쓴 문서. `.forge/` 디렉터리 구조, 브랜치 격리, 회고 스킵·검증 게이트 규칙, 그리고 전체 흐름 상세도를 담는다.

## 공유 상태와 디렉터리

단계를 독립적으로 호출해도 흐름이 이어지도록 상태를 파일로 넘긴다. 모든 것을 `.forge/` 한 디렉터리에 둔다 — 휘발 루프 상태와 git 추적되는 영속 문서가 함께 산다. `.gitignore`가 `.forge/`를 기본 제외하고 영속 문서만 화이트리스트로 추적하므로, **위치는 전부 `.forge/` 안이고 구분은 git 추적 여부**다.

```
repo/
├── CONTEXT-MAP.md             # 멀티 컨텍스트일 때만 (루트 유지)
└── .forge/                    # 모든 루프 문서가 여기 산다
    │                          # ── 영속 문서 (화이트리스트로 git 추적) ──
    ├── CONTEXT.md             # 글로서리 (단일 컨텍스트)
    ├── adr/0001-*.md          # 아키텍처 결정
    ├── adr/retired/           # 은퇴/대체된 ADR (fg-cleanup이 이동)
    ├── retro/YYYY-MM-DD-*.md  # 회고 로그
    ├── codebase/*.md          # fg-map이 만든 코드베이스 지도
    ├── config.json            # 프로젝트 설정(tdd · eco · defaultBranch) — 전역, 브랜치 해석 안 함
    │                          # ── 휘발 루프 상태 (gitignore) ──
    ├── backlog/<slug>.md      # ① fg-ask 그릴링 산출 — 미실행 plan 대기열
    ├── plan.md                # 활성 슬롯: 지금 도는 한 바퀴의 정답 기준 (fg-run가 백로그에서 승격)
    ├── run.md                 # ② fg-run 산출 = 계획 vs 실제
    ├── STATUS.md              # 활성 슬롯: fg-run가 실행 완료 시 작성 (status: executed, verified: pending, retro: pending) — verified는 yes/skipped/n/a(봉인 가능) 또는 failed(차단), retro는 이후 경로 또는 "skipped"가 됨
    ├── executed/<slug>/       # "모두 실행" 후 회고 대기 (plan+run+STATUS, 미회고)
    ├── done/<날짜-slug>/       # ④ fg-done 봉인 아카이브 (plan+run+STATUS, status: done)
    ├── quick/LOG.md           # fg-quick 차선 로그(빠른 작업당 한 줄)
    ├── dropped/<slug>/        # fg-drop이 "보관"으로 폐기한 미완 작업 (휘발·gitignore; doctor 관용·status 무시 — ADR-0021)
    └── branch/<branch>/       # 비-기본 브랜치는 forge 루트 전체를 여기서 운영(git 추적); fg-merge가 .forge/로 통합 (ADR-0011)
```

비-기본 브랜치에서는 위의 모든 `.forge/...` 경로가 `.forge/branch/<branch>/` 아래로 해석된다(기본 브랜치는 `.forge/`를 그대로 사용) — 단 전역 예외 두 개, `.forge/config.json`(규칙 자신이 읽어야 하는 `defaultBranch`를 담음)과 `.forge/codebase/`(지도는 공유 참조 연료)는 모든 브랜치에서 항상 최상위 `.forge/`에 머문다. 해석 규칙은 `skills/fg-run/FORGE-ROOT.md`에 한 번 정의되고 모든 루프 스킬이 이를 참조한다.

`.gitignore` 패턴:

```gitignore
.forge/*
!.forge/CONTEXT.md
!.forge/adr/
!.forge/retro/
!.forge/codebase/
!.forge/config.json
!.forge/branch/        # 비-기본 브랜치 루트는 통째로 추적 (ADR-0011)
```

- 각 스킬은 입력 파일을 `.forge/`에서 읽고 산출을 `.forge/`에 쓴다(브랜치별로 해석 — 아래 참조). `fg-run`만 따로 불러도 백로그·활성 슬롯을 찾아 이어간다.
- **브랜치 격리 ([ADR-0011](../.forge/adr/0011-branch-isolated-forge-root.md)).** 비-기본 브랜치에서는 forge 루트 전체가 `.forge/branch/<branch>/`(git 추적)로 옮겨가, 병렬 브랜치가 `.forge` 상태에서 충돌하지 않는다 — ADR/task 번호·CONTEXT.md·휘발 상태가 모두 브랜치별로 네임스페이스된다. 영속 연료(CONTEXT.md·ADR·회고)의 읽기는 최상위 베이스 문서 위에 오버레이되어(브랜치 우선) 갓 만든 브랜치도 main의 용어·결정 위에서 그릴링하고, 쓰기는 브랜치 루트에만 간다. `git merge` 뒤 `fg-merge`가 브랜치 루트를 `.forge/`로 통합한다(ADR 번호 재부여·retro 이동·CONTEXT 용어 병합 후 브랜치 폴더 제거). 기본 브랜치는 종전과 같다. 해석 규칙은 `skills/fg-run/FORGE-ROOT.md`에 한 번만 정의된다.
- `fg-run`는 백로그에 작업이 여럿이면 미완료 목록을 선택 메뉴로 제시한다(마지막 옵션 "모두 실행"). 활성 슬롯은 항상 1개 — 한 plan.md = 한 run.md = 한 봉인.
- 입력 파일이 없으면 스킬은 앞 단계를 안내한다.
- 활성 슬롯·백로그·회고 대기열이 모두 비어 있으면 = 진행 중 작업 없음. `fg-run`는 빈 상태에서 실행하지 않는다(재실행 방지). 완료 판별은 `done/*/STATUS.md`(status: done)다.
- 회고는 사소한 **저-divergence** 작업에 한해 **건너뛸 수 있다**. fg-run가 핸드오프에서 명시 선택지로 제시한다 — 자동이 아니고, 계획과 크게 어긋난 실행에는 제시하지 않는다(그때야말로 배울 게 있다). 건너뛰면 STATUS.md에 `retro: skipped`를 기록하고 회고 파일은 만들지 않으며, fg-done이 이를 봉인 가드 통과로 인정한다. 회고가 기본값이다 ([ADR-0002](../.forge/adr/0002-optional-retro-skip.md)).
- 작업은 봉인 전에 **검증 결정이 기록된다**. 루프 순서는 run → verify → learn → done이다. 실행 직후 fg-run의 대화형 핸드오프가 계획의 목표에 대고 UAT를 수행하고 결과를 STATUS.md `verified:`에 기록한다 — `yes (증거)`(동작 확인 + *어떻게* 확인했는지 한 줄 증거를 동반: 돌린 명령·관찰한 출력, 예: `yes (npm test → 42 passing)`; TDD 모드에선 통과한 슬라이스 테스트가 곧 그 증거) / `n/a (사유)`(확인할 런타임 없음, 예: 문서만 변경) / `skipped (사유)`(의도적·감사 가능한 waiver). 두 상태는 봉인을 **차단**한다: `pending`(UAT 미수행 — 초기값 또는 중단된 핸드오프)과 `failed (사유)`(UAT를 수행했으나 목표 미달 — 수정·재실행 또는 재그릴로 가며 절대 봉인 안 됨). fg-done은 `verified:`가 차단 상태이면 봉인하지 않는다(**no-seal-without-verification 가드**) — 기록된 *봉인 가능* 결정 없이는 아무것도 `done/`에 들어가지 않는다. 단 `skipped`는 **봉인을 통과한다** — confirmation이 아니라 명시적 waiver다(retro-skip과 동일한 절제). 이 게이트가 보장하는 것은 "조용한 누락 없음"이지 "모든 작업이 동작 확인됨"이 아니다 ([ADR-0009](../.forge/adr/0009-verification-gate-before-seal.md)). ADR-0009 이전에 봉인된 작업은 이 필드가 없던 시절이라 `verified: n/a (legacy pre-ADR-0009)`로 채워져 있다 — `done/` 이력에서 `verified:`가 비어 있으면 게이트 실패가 아니라 legacy 데이터라는 뜻이다.

## 전체 흐름 상세도

루프와 문서(`.forge/`)의 산출·소비 관계를 한눈에 본 다이어그램. 텍스트 흐름도는 [README](../README.ko.md#전체-흐름)에 있다.

```mermaid
flowchart LR
    A[fg-ask<br/>① 질의·계획·그릴링] --> E[fg-run<br/>② 실행·Dynamic WF]
    E --> L[fg-learn<br/>③ 회고]
    L --> C[fg-done<br/>④ 완료·봉인]
    E -.크게 어긋나면 재그릴링.-> A
    L -.재그릴링.-> A
    C -->|새 작업| A
    A -.용어.-> CTX[(.forge/CONTEXT.md)]
    A -.중대 결정.-> ADR[(.forge/adr/)]
    L -.승급.-> CTX
    L -.승급.-> ADR
    L -.세션 학습.-> RETRO[(.forge/retro/)]
    C -.봉인.-> DONE[(.forge/done/)]
    MAP[fg-map<br/>유틸리티 · 루프 밖] -.작성.-> CB[(.forge/codebase/)]
    CB -.그릴링 전 읽기.-> A
    CLEAN[fg-cleanup<br/>유틸리티 · 루프 밖] -.오래된 ADR 은퇴.-> ADRRET[(.forge/adr/retired/)]
    ADR -.그릴링 전 활성 집합 읽기.-> A
    style A fill:#e3f2fd
    style C fill:#ffe0b2
    style MAP fill:#e8f5e9
    style CLEAN fill:#e8f5e9
```
