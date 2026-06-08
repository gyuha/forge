# forge

> 작업 하나를 **질의·계획 → 실행 → 회고 → 완료**의 한 바퀴로 돌리는 개발 루프.
> 11개의 `fg-` 프리픽스 Claude Code 스킬로 구성된 루프형 워크플로우 플러그인 — 루프를 이루는 4개와, 루프 밖 유틸리티 7개(`fg-map`·`fg-quick`·`fg-status`·`fg-next`·`fg-tdd`·`fg-merge`·`fg-cleanup`).

[English](./README.md)

계획은 grill-with-docs식 대화형 그릴링으로, 실행은 Claude Code Dynamic Workflow로 수행하고, 회고는 학습을 프로젝트 문서(`CONTEXT.md` · ADR · 회고 로그)에 되돌린 뒤, 완료 단계에서 한 바퀴의 잔여물을 정리하며 작업을 봉인해 같은 작업이 두 번 실행되지 않게 한다.

## 스킬 카탈로그

| 스킬 | 단계 | 한 줄 역할 | 입력 | 출력 | 다음 |
| --- | --- | --- | --- | --- | --- |
| `fg-ask` | ① 질의·계획 | grill-with-docs 원문 그대로 — 계획을 도메인·용어·결정에 대고 그릴링 | 사용자 요청 | `.forge/backlog/<slug>.md` + CONTEXT/ADR | `fg-run` |
| `fg-run` | ② 실행 | 계획을 Dynamic Workflow로 실행 — 미실행 plan이 하나면 메뉴 없이 즉시 실행, 여럿이면 선택 메뉴 제시(마지막 옵션 "모두 실행") | `.forge/backlog/`, `plan.md` | 결과 + `.forge/run.md` + `STATUS.md` (또는 `executed/`) | `fg-learn` |
| `fg-learn` | ③ 회고 | 학습을 문서로 승급, 다음 질의 도출 | `.forge/run.md`, `plan.md`, `executed/` | `.forge/retro/*.md` + 승급 | `fg-done` (크게 어긋났으면 `fg-ask`로 재그릴링) |
| `fg-done` | ④ 완료 | 한 바퀴 정리 — 회고 확인, `STATUS.md`를 done으로 마감, 아카이브, 활성 상태 비우기, 루프 닫기 | `.forge/*` | `.forge/done/<날짜-slug>/` | `fg-ask` / 종료 |
| `fg-map` | 유틸리티(루프 밖) | 병렬 서브에이전트로 코드베이스를 `.forge/codebase/`에 매핑해, 그릴링이 코드를 다시 탐색하지 않고 지도를 읽게 한다(context rot 감소) | 코드베이스 | `.forge/codebase/*.md` (7개 문서) | — (`fg-ask`가 소비) |
| `fg-quick` | 경량 차선(루프 밖) | 사소한 작업용 — 가볍게 그릴링한 뒤 형식 산출물(ADR/plan/회고) 없이 바로 실행; 비-trivial로 드러나면 `fg-ask`로 bail | 사용자 요청 | `.forge/quick/LOG.md`에 항목 하나 | — (자체 완결) |
| `fg-status` | 리포터(루프 밖) | 읽기 전용 — `.forge/`를 조사해 모든 작업의 현황과 지금 필요한 다음 단계 하나를 출력; 아무것도 쓰지 않고 자동 실행도 안 함 | `.forge/*` (읽기 전용) | 출력 보고(파일 없음) | — (다음 단계 제안) |
| `fg-next` | 오케스트레이터(루프 밖) | fg-status의 상태 머신으로 다음 단계 하나를 도출해 한 줄로 알린 뒤 그 스킬을 곧바로 실행 — 보고만 하지 않음, one-shot; fg-status는 보고, fg-next는 행동 | `.forge/*` (자신은 읽기 전용) | 없음 — 호출한 스킬에 위임 | — (다음 스킬을 호출) |
| `fg-tdd` | 토글(루프 밖) | `.forge/config.json`의 TDD 모드를 켜고 끔 — 켜면 `fg-ask`가 기본으로 질문하고 `fg-run`이 test-first로 실행 | `on`/`off`/(없음) | `.forge/config.json`(`tdd`) | — (설정만) |
| `fg-merge` | 통합기(루프 밖) | `git merge` 뒤 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합 — ADR 번호 재부여(+교차참조)·CONTEXT 용어 병합·done 합침·브랜치 폴더 제거, 진짜 충돌 시 멈춤. git은 직접 안 돌림 | `.forge/branch/<branch>/` | 통합된 `.forge/` 문서 | — (통합 단계) |
| `fg-cleanup` | 은퇴기(루프 밖) | 오래된/대체된 ADR을 활성 결정 집합에서 은퇴 — 후보를 근거와 함께 제시하고, 승인 시 각 ADR을 `.forge/adr/retired/<NNNN>-slug.md`로 이동+supersede/retire 마킹. 번호 불변·재사용 금지·삭제 안 함. fg-ask는 `retired/`를 정답소스로 안 읽음 | `.forge/adr/*.md` | `.forge/adr/retired/*` | — (ADR 정비) |

`fg-ask`가 루프의 진입점이다 — 질의·분류와 그릴링을 함께 맡는다(기존 별도 `fg-plan` 단계를 `fg-ask`로 통합). "forge 시작", "새 작업", "이거 작업하자", "계획 다듬자" 같은 발화에서 트리거된다. `fg-done`은 "작업 완료", "봉인", "이거 마무리"에서 트리거된다(기존 "작업 정리", "forge complete"도 alias로 인식한다). `fg-map`은 **루프 단계가 아니다** — 코드베이스가 크게 바뀌어 지도가 낡았을 때 돌리는 온디맨드 유틸리티로, "코드베이스 분석", "코드베이스 지도" 같은 발화에서 트리거된다. `fg-quick`도 **루프 밖**이다 — 사소한 작업(오타·작은 rename·버전 범프)용 경량 차선으로, 그릴링은 하되 가볍게 하고 형식 산출물(ADR/plan/회고) 없이 바로 실행하며 `.forge/quick/LOG.md`에 한 줄 기록한다. 그릴링 중 비-trivial로 드러나면 `fg-ask`(정식 루프)로 bail한다. "forge quick", "이거 빨리 해줘" 같은 발화에서 트리거된다. `fg-status`도 **루프 밖 읽기 전용 리포터**다 — 아무 때나 돌려 모든 작업의 현황(active slot·backlog·회고 대기·완료 이력·빠른 작업 로그)과 지금 필요한 다음 단계 하나를 본다; 아무것도 쓰지 않고 자동 실행도 하지 않는다. "forge status", "어디까지 했지" 같은 발화에서 트리거된다. `fg-next`는 **fg-status의 행동하는 형제로, 역시 루프 밖**이다 — 같은 다음 단계 하나를 (fg-status의 상태 머신을 재사용해 — 재구현하지 않고) 도출하되, 한 줄로 알린 뒤 그 스킬을 곧바로 **실행**한다 — 보고만 하고 멈추지 않으며 별도 승인을 기다리지 않는다. one-shot(한 단계만, 이후는 호출된 스킬 자체 핸드오프가 이어받음)이며 자신은 아무것도 쓰지 않고 모든 행동을 해당 스킬에 위임한다. "어디까지 했는지 기억 안 날 때 그냥 다음 걸 해줘"라는 차가운 재진입 진입점이다. **`all` 모드**(`fg-next all`)에서는 백로그가 빌 때까지 작업을 하나씩 끝까지 몰며 진행한다 — 선형 기계적 단계는 자동 추천 진행하고 **회고는 (divergence 무관) 항상 자동 skip**하되, **대화의 벽**(실패/검증불가 UAT·진짜 fork·빈 상태)에서는 멈춰 사람에게 넘긴다. `fg-run`의 "Run all"을 verify→done까지 확장한 모멘텀 상위집합이다 ([ADR-0010](./.forge/adr/0010-fg-next-all-momentum-mode.md)). "forge next", "다음 단계", "이어서 해줘", "fg-next all", "다음 전부 진행" 같은 발화에서 트리거된다. `fg-tdd`도 **루프 밖**이다 — `.forge/config.json`의 영속 TDD 모드 토글(`fg-tdd on|off`, 인자 없으면 상태 표시). 켜면 `fg-ask`가 기본으로 "이 작업 TDD로?"를 묻고 `fg-run`이 test-first로 실행한다. "forge tdd", "TDD 켜/꺼" 같은 발화에서 트리거된다. `fg-merge`는 **브랜치 격리의 통합 유틸리티로, 역시 루프 밖**이다 — 피처 브랜치를 `git merge`한 뒤, 그 브랜치의 `.forge/branch/<branch>/`를 기본 브랜치의 `.forge/`로 합친다: 브랜치 ADR을 다음 빈 번호로 재부여(교차참조 갱신)하고 CONTEXT 용어를 병합하며 `done/` 이력을 합치고 브랜치 폴더를 제거한다. 기계적 부분은 자동, 진짜 충돌(용어 재정의·ADR 모순)에서만 멈춰 묻고, git은 직접 돌리지 않는다. "forge merge", "fg-merge \<branch\>", "브랜치 통합" 같은 발화에서 트리거된다 ([ADR-0011](./.forge/adr/0011-branch-isolated-forge-root.md)). `fg-cleanup`은 **ADR 은퇴 유틸리티로, 역시 루프 밖**이다 — 오래된/대체된 ADR을 활성 결정 집합에서 은퇴시킨다: 은퇴 후보를 근거와 함께 제시하고, 사람이 승인하면 각 ADR을 `.forge/adr/retired/<NNNN>-slug.md`로 옮기며 `Superseded by ADR-NNNN` / `Retired (사유)` 한 줄을 단다. 번호는 절대 바뀌지 않고 재사용도 없으며, 아무것도 삭제하지 않는다(왜는 디스크에 남는다). `fg-ask`는 `retired/`를 정답소스로 읽지 않아 은퇴된 결정이 그릴링 연료에서 빠진다. 은퇴는 사람 승인이 원칙이고 자동이 아니며, 작업 봉인은 이 스킬이 아니라 `fg-done`이다. "forge cleanup", "ADR 정리", "ADR 은퇴", "오래된 ADR 치워" 같은 발화에서 트리거된다 ([ADR-0012](./.forge/adr/0012-fg-cleanup-renamed-to-fg-done-cleanup-retires-adrs.md)).

## 전체 흐름

한 스킬이 끝나면 다음 스킬로 가는 길(무엇을 했고, 다음은 무엇이며, 어떻게 시작하는지)을 안내하고, 바로 이어갈지 물어 동의하면 그 자리에서 다음 스킬을 호출한다. 루프는 `fg-done`이 작업을 봉인한 뒤, **새 작업**으로서만 `fg-ask`에서 다시 시작된다 — 같은 작업을 다시 실행하지 않는다. 두 유틸리티가 루프 밖에서 이 연료를 돌본다: `fg-map`은 `fg-ask`가 읽는 코드베이스 지도를 작성하고, `fg-cleanup`은 `fg-ask`가 읽는 ADR 집합을 정비한다 — 오래된 결정을 `.forge/adr/retired/`(`fg-ask`가 읽지 않음)로 은퇴시켜 그릴링이 더 깨끗한 활성 집합 위에서 돌도록 한다.

```
fg-ask ───▶ fg-run ───▶ fg-learn ───▶ fg-done
① 질의/계획     ② 실행          ③ 회고        ④ 완료
(그릴링·대화형) (Dynamic WF)   (문서 반영)    (봉인·재실행 방지)
```

```mermaid
flowchart LR
    A[fg-ask<br/>① 질의·계획·그릴링] --> E[fg-run<br/>② 실행·Dynamic WF]
    E --> L[fg-learn<br/>③ 회고]
    L --> C[fg-done<br/>④ 완료·봉인]
    E -.크게 어긋나면 재그릴링.-> A
    L -.재그릴링.-> A
    C -->|새 작업| A
    A -.잡일.-> X[루프 건너뛰고 바로 처리]
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

## 설치

Claude Code 세션에서 GitHub 마켓플레이스로 추가한 뒤 플러그인을 설치한다.

```
/plugin marketplace add gyuha/forge
/plugin install forge@forge
```

로컬 클론에서 설치하려면(예: 개발 중) 리포 루트 경로를 넘긴다:

```
/plugin marketplace add /path/to/forge
/plugin install forge@forge
```

참고:

- GitHub 설치는 리포의 기본 브랜치(`main`)를 당긴다 — 변경을 설치로 테스트하려면 먼저 `main`에 push되어 있어야 한다.
- 스킬은 `skills/<name>/SKILL.md`에서 자동 탐색되므로 추가 설정이 필요 없다.
- 이후 업데이트는 `/plugin marketplace update forge`, 제거는 `/plugin uninstall forge@forge`.

설치 후 Claude Code 세션에서 `fg-ask`부터 트리거되거나, "forge로 시작" 같은 발화로 루프가 시작된다.

## 공유 상태와 디렉터리

단계를 독립적으로 호출해도 흐름이 이어지도록 상태를 파일로 넘긴다. 모든 것을 `.forge/` 한 디렉터리에 둔다 — 휘발 루프 상태와 git 추적되는 영속 문서가 함께 산다. `.gitignore`가 `.forge/`를 기본 제외하고 영속 문서만 화이트리스트로 추적하므로, **위치는 전부 `.forge/` 안이고 구분은 git 추적 여부**다.

```
repo/
├── CONTEXT-MAP.md             # 멀티 컨텍스트일 때만 (루트 유지)
└── .forge/                    # 모든 루프 문서가 여기 산다
    │                          # ── 영속 문서 (화이트리스트로 git 추적) ──
    ├── CONTEXT.md             # 글로서리 (단일 컨텍스트)
    ├── adr/0001-*.md          # 아키텍처 결정
    ├── retro/YYYY-MM-DD-*.md  # 회고 로그
    ├── codebase/*.md          # fg-map이 만든 코드베이스 지도
    │                          # ── 휘발 루프 상태 (gitignore) ──
    ├── backlog/<slug>.md      # ① fg-ask 그릴링 산출 — 미실행 plan 대기열
    ├── plan.md                # 활성 슬롯: 지금 도는 한 바퀴의 정답 기준 (fg-run가 백로그에서 승격)
    ├── run.md                 # ② fg-run 산출 = 계획 vs 실제
    ├── STATUS.md              # 활성 슬롯: fg-run가 실행 완료 시 작성 (status: executed, verified: pending, retro: pending) — verified는 yes/skipped/n/a(봉인 가능) 또는 failed(차단), retro는 이후 경로 또는 "skipped"가 됨
    ├── executed/<slug>/       # "모두 실행" 후 회고 대기 (plan+run+STATUS, 미회고)
    ├── done/<날짜-slug>/       # ④ fg-done 봉인 아카이브 (plan+run+STATUS, status: done)
    └── branch/<branch>/       # 비-기본 브랜치는 forge 루트 전체를 여기서 운영(git 추적); fg-merge가 .forge/로 통합 (ADR-0011)
```

비-기본 브랜치에서는 위의 모든 `.forge/...` 경로가 `.forge/branch/<branch>/` 아래로 해석된다(기본 브랜치는 `.forge/`를 그대로 사용). 해석 규칙은 `skills/fg-run/FORGE-ROOT.md`에 한 번 정의되고 모든 루프 스킬이 이를 참조한다.

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
- **브랜치 격리 ([ADR-0011](./.forge/adr/0011-branch-isolated-forge-root.md)).** 비-기본 브랜치에서는 forge 루트 전체가 `.forge/branch/<branch>/`(git 추적)로 옮겨가, 병렬 브랜치가 `.forge` 상태에서 충돌하지 않는다 — ADR/task 번호·CONTEXT.md·휘발 상태가 모두 브랜치별로 네임스페이스된다. `git merge` 뒤 `fg-merge`가 브랜치 루트를 `.forge/`로 통합한다(ADR 번호 재부여·retro 이동·CONTEXT 용어 병합 후 브랜치 폴더 제거). 기본 브랜치는 종전과 같다. 해석 규칙은 `skills/fg-run/FORGE-ROOT.md`에 한 번만 정의된다.
- `fg-run`는 백로그에 작업이 여럿이면 미완료 목록을 선택 메뉴로 제시한다(마지막 옵션 "모두 실행"). 활성 슬롯은 항상 1개 — 한 plan.md = 한 run.md = 한 봉인.
- 입력 파일이 없으면 스킬은 앞 단계를 안내한다.
- 활성 슬롯·백로그·회고 대기열이 모두 비어 있으면 = 진행 중 작업 없음. `fg-run`는 빈 상태에서 실행하지 않는다(재실행 방지). 완료 판별은 `done/*/STATUS.md`(status: done)다.
- 회고는 사소한 **저-divergence** 작업에 한해 **건너뛸 수 있다**. fg-run가 핸드오프에서 명시 선택지로 제시한다 — 자동이 아니고, 계획과 크게 어긋난 실행에는 제시하지 않는다(그때야말로 배울 게 있다). 건너뛰면 STATUS.md에 `retro: skipped`를 기록하고 회고 파일은 만들지 않으며, fg-done이 이를 봉인 가드 통과로 인정한다. 회고가 기본값이다 ([ADR-0002](./.forge/adr/0002-optional-retro-skip.md)).
- 작업은 봉인 전에 **검증 결정이 기록된다**. 루프 순서는 run → verify → learn → done이다. 실행 직후 fg-run의 대화형 핸드오프가 계획의 목표에 대고 UAT를 수행하고 결과를 STATUS.md `verified:`에 기록한다 — `yes (증거)`(동작 확인 + *어떻게* 확인했는지 한 줄 증거를 동반: 돌린 명령·관찰한 출력, 예: `yes (npm test → 42 passing)`; TDD 모드에선 통과한 슬라이스 테스트가 곧 그 증거) / `n/a (사유)`(확인할 런타임 없음, 예: 문서만 변경) / `skipped (사유)`(의도적·감사 가능한 waiver). 두 상태는 봉인을 **차단**한다: `pending`(UAT 미수행 — 초기값 또는 중단된 핸드오프)과 `failed (사유)`(UAT를 수행했으나 목표 미달 — 수정·재실행 또는 재그릴로 가며 절대 봉인 안 됨). fg-done은 `verified:`가 차단 상태이면 봉인하지 않는다(**no-seal-without-verification 가드**) — 기록된 *봉인 가능* 결정 없이는 아무것도 `done/`에 들어가지 않는다. 단 `skipped`는 **봉인을 통과한다** — confirmation이 아니라 명시적 waiver다(retro-skip과 동일한 절제). 이 게이트가 보장하는 것은 "조용한 누락 없음"이지 "모든 작업이 동작 확인됨"이 아니다 ([ADR-0009](./.forge/adr/0009-verification-gate-before-seal.md)). ADR-0009 이전에 봉인된 작업은 이 필드가 없던 시절이라 `verified: n/a (legacy pre-ADR-0009)`로 채워져 있다 — `done/` 이력에서 `verified:`가 비어 있으면 게이트 실패가 아니라 legacy 데이터라는 뜻이다.

## 두 기둥

1. **그릴링(계획)은 Dynamic Workflow 밖의 대화형으로.** Dynamic Workflow는 실행 중 사용자 입력을 못 받으므로, 한 질문씩 주고받는 그릴링을 워크플로우 안에 넣지 않는다.
2. **문서는 산출물이 아니라 루프의 연료.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.

## 크레딧

`fg-ask`의 그릴링·문서화 패턴(원문 포함)과 `CONTEXT-FORMAT.md`/`ADR-FORMAT.md`는 [mattpocock/skills의 grill-with-docs](https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs)를 계승했다.
