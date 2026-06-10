---
last_mapped_commit: 0472a519cbb8275564cdbaa30469f2d0c5472842
mapped: 2026-06-10
---

# forge 아키텍처 — 루프와 상태 계약

## 요약

forge는 코드를 빌드하는 프로젝트가 아니라 **Claude Code 플러그인**이다. 산출물은 전부 Markdown(`SKILL.md`, `*-FORMAT.md`)과 JSON(매니페스트)뿐 — 런타임 코드도, 빌드·테스트·린트 시스템도 없다. "아키텍처"란 곧 **스킬들이 `.forge/` 상태 파일을 주고받으며 만드는 워크플로우 구조**다.

핵심 추상은 작업 하나를 한 바퀴 도는 **4단계 forge 루프**다. 각 스킬은 독립 실행되며, 직접 서로를 호출하지 않고 `.forge/` 파일 위치로 상태를 전달한다(파일이 곧 상태 머신). 루프를 잇는 4개 스킬 외에 7개의 루프-밖 유틸리티가 있어 **총 11개 스킬**이다.

```
fg-ask(①질의·계획·그릴링) → fg-run(②실행) → fg-learn(③회고) → fg-done(④완료·봉인) → (새 작업) fg-ask
```

## 두 기둥 (설계 불변식)

이 둘을 깨면 forge가 forge가 아니게 된다.

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** 워크플로우는 실행 중 사람 입력을 못 받는다. 한 질문씩 주고받는 그릴링(fg-ask)·회고(fg-learn)는 반드시 워크플로우 밖 대화로 한다.
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.

## 루프 4단계 (각 스킬 = 한 턴)

각 스킬은 끝에서 "방금 한 것 / 다음 단계 / 시작하는 법"을 대화체 핸드오프로 전한다. 입력 파일이 없으면 앞 단계를 가리킨다.

- **fg-ask (① 질의·계획·그릴링)** — grill-with-docs식 대화형 그릴링. 계획을 도메인·용어·결정에 대고 검증해 `.forge/backlog/<slug>.md`로 적재한다. 그릴링 중 CONTEXT.md/ADR를 인라인 갱신한다. `skills/fg-ask/SKILL.md`. 본문은 grill-with-docs 원본의 영문 verbatim이고, forge 루프 연결은 맨 아래 "Forge integration" 섹션에만 둔다 — 둘이 따로 움직이므로 한쪽만 고치면 계약이 깨진다.
- **fg-run (② 실행)** — 백로그에서 plan을 활성 슬롯(`.forge/plan.md`)으로 승격하고 Claude Code Dynamic Workflow로 실행한다. plan의 "Work slices"가 1차 작업 단위다. 계획↔실제 차이를 `.forge/run.md`에 기록하고, 직후 `STATUS.md`(`status: executed`)를 쓴 뒤 핸드오프 UAT로 `verified:`를 기록한다. `skills/fg-run/SKILL.md`.
- **fg-learn (③ 회고)** — 학습을 분류해 영속 문서(CONTEXT.md·ADR)로 승급하고 `.forge/retro/`에 회고를 남긴다. 항상 대화형. 승급 바를 못 넘는 학습은 retro에 머문다. `skills/fg-learn/SKILL.md`.
- **fg-done (④ 완료·봉인)** — 한 바퀴의 잔여물을 정리한다: 검증·회고 게이트 확인 → `STATUS.md`를 `status: done`으로 마감 → `.forge/done/<날짜-slug>/`로 봉인 → 활성 `.forge/` 비움. **활성 상태를 비우는 것이 재실행 방지의 핵심 메커니즘**이다(plan.md가 사라지면 fg-run이 돌릴 대상을 못 찾음). `skills/fg-done/SKILL.md`.

## 루프-밖 유틸리티 (7개 — 루프 단계 아님)

- **fg-map** — 병렬 서브에이전트로 코드베이스를 `.forge/codebase/`(7문서)로 매핑. fg-ask가 그릴링 전 읽어 context rot을 줄인다. `skills/fg-map/SKILL.md`.
- **fg-quick** — trivial 작업용 경량 차선. 그릴링(기둥 1)은 유지하되 형식 산출물(ADR·plan·run·STATUS·done·retro)을 만들지 않고 `.forge/quick/LOG.md`에 한 줄만 기록한 뒤 직접 실행. 메인 루프의 활성 슬롯·backlog·done을 일절 건드리지 않아 상태 계약과 격리되며, 비-trivial로 드러나면 fg-ask로 bail. `skills/fg-quick/SKILL.md`(ADR-0003).
- **fg-status** — 읽기 전용 상태 리포터. `.forge/`를 조사해 현황+다음 단계 하나를 출력하고 **아무것도 쓰지 않으며 자동 실행 안 함**. 다음-단계 도출 상태 머신의 단일 정의처는 이 스킬의 "Deriving the next step (state machine)" 섹션이다. `skills/fg-status/SKILL.md`.
- **fg-next** — fg-status의 상태 머신을 재사용해 다음 단계 하나를 도출하고 **곧바로 실행**한다(보고만 하는 fg-status와 달리 행동까지). 기본은 one-shot — 한 단계 실행 후 멈추고, 위임받은 스킬의 핸드오프가 루프를 잇는다. 자체적으로는 아무것도 쓰지 않는다(모든 쓰기는 위임 스킬이). `all` 모드(`fg-next all`)는 백로그가 빌 때까지 선형 기계적 단계를 자동 진행하며 회고는 (divergence 무관) **항상 자동 skip**하고 대화의 벽(failed/검증불가 UAT·진짜 fork·빈 상태)에서만 멈춘다. `/goal` 페어링으로 턴 경계를 넘어 무인 구동 가능. `skills/fg-next/SKILL.md`(ADR-0010, 개정 2026-06-08).
- **fg-tdd** — `.forge/config.json`의 영속 TDD 모드를 토글. 켜면 fg-ask가 plan에 `<!-- tdd: on -->`를 박고 fg-run이 test-first로 실행. `skills/fg-tdd/SKILL.md`(ADR-0008).
- **fg-merge** — `git merge` 뒤 비-기본 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합(ADR 번호 재부여+교차참조 갱신·retro 이동·CONTEXT 용어 병합·done 합침·브랜치 폴더 제거). git 조작은 안 함. `skills/fg-merge/SKILL.md`(ADR-0011).
- **fg-cleanup** — 오래된/대체된 ADR을 활성 결정 집합에서 은퇴시킴(후보 제시→사람 승인→`.forge/adr/retired/<NNNN>-slug.md`로 이동+supersede 마킹). 번호 불변·재사용 금지·삭제 안 함. fg-ask는 retired/를 정답 소스로 안 읽음. 작업 봉인은 fg-done이지 이 스킬이 아님. `skills/fg-cleanup/SKILL.md`(ADR-0012).

## `.forge/` 상태 계약 — 데이터 흐름

스킬들은 직접 호출이 아니라 `.forge/` 파일을 통해 흐른다. 입출력 계약을 깨면 흐름이 끊긴다.

| 파일 | 생산자 | 소비자 |
| --- | --- | --- |
| `.forge/backlog/<slug>.md` | fg-ask | fg-run(선택 메뉴·승격) |
| `.forge/plan.md` (활성 슬롯) | fg-run(백로그 승격) | fg-run(정답 기준), fg-learn |
| `.forge/run.md` | fg-run | fg-learn |
| `.forge/STATUS.md` (활성 슬롯) | fg-run | fg-run(재진입)·fg-learn·fg-done |
| `.forge/executed/<slug>/` | fg-run("Run all" park) | fg-learn(회고 대기)·fg-done(봉인) |
| `.forge/done/<날짜-slug>/` | fg-done | fg-ask(slug 충돌)·fg-run(완료 판별)·fg-learn·fg-done |

### 활성 슬롯 1개 규칙 / 빈 상태

- **활성 슬롯은 항상 1개** — 한 `plan.md` = 한 `run.md` = 한 봉인. 백로그는 미실행 대기열, `executed/`는 "실행됐으나 미회고"의 명시 상태다.
- plan 첫 줄의 `<!-- forge-slug: ... -->` 주석이 회고·봉인의 짝 맞춤 식별자다(파일 이동에도 영속).
- **활성 슬롯·백로그·executed가 모두 비면 = 진행 중 작업 없음.** fg-run은 빈 상태에서 실행하지 않는다(재실행 방지). fg-done이 봉인하며 비운다.

### STATUS.md 라이프사이클 (동반 마커, 이중 장부 아님)

상태의 원천은 **파일 위치**이고 STATUS.md는 plan/run과 함께 활성 슬롯 → `executed/` → `done/`을 따라 이동하는 동반 마커다.

```
fg-run:  run.md 기록 직후 → STATUS.md (status: executed, verified: pending, retro: pending)
          → 핸드오프 UAT → verified: 기록
fg-done:  status: done (+ completed/verified/retro/docs updated) → done/<날짜-slug>/로 아카이브
완료 판별 = done/*/STATUS.md 의 status: done
```

### 봉인 전 검증 게이트 (ADR-0009)

루프 순서는 **run → verify → learn → done**. fg-run 핸드오프가 plan 목표에 대고 UAT를 수행해 STATUS `verified:`를 기록한다.

- **봉인 가능(sealable)**: `yes (<evidence>)` / `skipped (<사유>)` / `n/a (<사유>)`
- **차단(blocking)**: `pending`(미검증) / `failed (<사유>)`(검증했으나 깨짐)

fg-done은 **검증 게이트를 회고 게이트보다 먼저** 확인한다(no-seal-without-verification). `pending`은 fg-run의 검증 전용 재진입(재실행 없이 UAT만)으로, `failed`는 fg-run의 parked-failed 회수(executed/→active slot unpark)·fix-and-re-run 또는 fg-ask 재그릴로 라우팅 — **fg-run이 unpark의 단일 소유자**다(fg-learn·fg-done은 둘 다 `failed`를 차단). `failed`는 fresh re-run으로 봉인 가능 값에 재검증될 때만 봉인되며 waiver로 통과시키지 않는다.

### 회고 skip (ADR-0002)

기본값은 회고(fg-learn)다. run.md의 계획↔실제 차이가 없거나 미미할 때만 fg-run 핸드오프가 "회고/건너뛰기"를 명시 제시하고, 사용자가 건너뛰기를 고르면 STATUS `retro:`에 `skipped (<사유>)`를 기록한다(회고 파일 없음). fg-done의 봉인 가드는 회고 파일 존재 **또는** `retro: skipped`를 통과 조건으로 인정한다. divergence가 크면 건너뛰기를 제시하지 않는다. (`fg-next all`은 divergence 무관 항상 자동 skip — ADR-0010.)

## 최근 변경 (정확히 반영)

- **fg-run "Run all" 절차 추출** — Run all(execute-only 배치) 절차가 `skills/fg-run/SKILL.md` 인라인에서 별도 파일 `skills/fg-run/RUN-ALL.md`로 분리됐다. **progressive disclosure**: 2+ 작업 메뉴에서 "Run all"을 실제로 고를 때만 on-demand로 로드해 흔한 경로(단일 작업)를 가볍게 유지한다. 동작은 인라인 시절과 불변. Run all은 순차 실행+UAT 후 sealable이면 `executed/<slug>/`로 park, `failed`면 활성 슬롯에 남기고 배치 정지, 회고에서 멈춘다(`fg-next all`이 그 상위집합).
- **fg-done 조건부 step 3a** — 봉인 후, `.forge/codebase/`가 존재하고 **AND** `git status --short`가 `.forge/` 밖 경로(skills/src/manifests/README 등) 변경(수정 또는 untracked)을 보이면, 지도가 stale할 수 있으니 fg-map 실행을 **한 번 제안한다 — 절대 자동 실행하지 않는다**(deep-research와 같은 offer-not-auto 절제, ADR-0006 정신). `.forge/codebase/`가 없거나 `.forge/` 문서만 바뀌었으면 조용히 skip.

## 브랜치별 forge 루트 (ADR-0011)

모든 `.forge/...` 경로는 **해석된 forge 루트 기준**이다. 단일 정의처는 `skills/fg-run/FORGE-ROOT.md`이며 모든 루프 스킬이 이를 참조한다(복붙 금지).

```
branch = git rev-parse --abbrev-ref HEAD
default = .forge/config.json:defaultBranch (없으면 "main")
   ├── branch == default ──▶ root = .forge/                  (휘발 상태 gitignored, 영속 문서만 화이트리스트)
   ├── branch != default ──▶ root = .forge/branch/<branch>/  (브랜치 루트 통째로 git 추적)
   └── detached / non-git ─▶ root = .forge/ + 1줄 경고
```

- 비-기본 브랜치 루트는 통째로 추적(`.gitignore`의 `!.forge/branch/`). 경로가 브랜치별 네임스페이스라 두 브랜치가 같은 파일을 안 건드려 **git merge 충돌이 없다**.
- 브랜치 내용 통합은 git이 아니라 **fg-merge**가(번호 재부여·retro 이동·CONTEXT 병합·폴더 제거). 기본 브랜치 휘발 상태가 gitignored이고 브랜치 루트만 추적되는 것은 의도된 비대칭이다.
- **전역 예외 2개**(항상 top-level `.forge/`, 절대 해석 안 함): `.forge/config.json`(`defaultBranch`/`tdd` — 해석 부트스트랩 역설 회피)와 `.forge/codebase/`(fg-map 지도는 공유 연료 — 브랜치-로컬이면 새 브랜치가 지도를 잃음).

## 진입점 / 실행 모델

- 스킬 식별자는 **frontmatter `name`**(디렉터리명 아님). 트리거 발화(예: "forge로 시작", "다음 단계", "배포")로 진입한다.
- **콜드 재진입**의 진입점은 fg-next("어디까지 했는지 모르겠으니 다음 걸 그냥 해줘")다.
- 빌드/테스트 없음. 검증은 (1) 매니페스트 JSON 유효성, (2) 설치 후 트리거 — 두 가지뿐. 설치는 GitHub 기본 브랜치(main)를 당기므로 설치 테스트하려면 main에 push되어 있어야 한다.
