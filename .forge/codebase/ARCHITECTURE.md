---
last_mapped_commit: 382c3f8346ae5b8b68abbb5a2dabe2ab52a80d62
mapped: 2026-06-12
---

# forge 아키텍처 — 루프와 상태 계약

## 요약

forge는 코드를 빌드하는 프로젝트가 아니라 **Claude Code 플러그인**이다. 산출물은 전부 Markdown(`SKILL.md`, `*-FORMAT.md`)과 JSON(매니페스트)뿐 — 런타임 코드도, 빌드·테스트·린트 시스템도 없다. "아키텍처"란 곧 **스킬들이 `.forge/` 상태 파일을 주고받으며 만드는 워크플로우 구조**다.

핵심 추상은 작업 하나를 한 바퀴 도는 **4단계 forge 루프**다. 각 스킬은 독립 실행되며, 직접 서로를 호출하지 않고 `.forge/` 파일 위치로 상태를 전달한다(파일 위치가 곧 상태 머신). 루프 4개 스킬 외에 루프-밖 유틸리티 9개가 있어 **총 13개 스킬**이다.

```
fg-ask(①질의·계획·그릴링) → fg-run(②실행) → [verify] → fg-learn(③회고) → fg-done(④완료·봉인) → (새 작업) fg-ask
```

이 커밋(`382c3f8`)의 최신 계약 변경 — 아래 본문에 반영됨:

- **fg-learn "Batch promotion mode"** — 봉인된 `retro: skipped` 작업들의 학습을 사람이 나중에 일괄 승급하는 명시 진입 모드(자동 skip 차선들의 "추후 승급" 약속의 수신처).
- **fg-loop `loop.md`의 `## Tasks` 멤버십 목록** — 주행은 목록에 등재된 slug만 승격(ADR-0016 개정 2026-06-12). 벽에서 멈춘 사이 fg-ask가 적재한 비소속 plan이 무인 주행에 휩쓸리지 않는다.
- **fg-next all의 fg-loop 양보** — `loop.md`가 존재하면 all 모드는 주행하지 않고 fg-loop에 위임한다(이중 승격 방지).
- **fg-merge의 in-flight halt에 브랜치 `loop.md` 포함** — 미완 goal 계약이 남은 브랜치 루트는 통합 전 halt.
- **fg-status의 `(loop)` 출처 태그** — `<!-- generated-by: fg-loop -->` plan을 테이블에서 구분 표시.
- **fg-ask의 "Halted goal loop?" 사전 확인(1b)** — `loop.md` 존재 시 한 줄 경고 + 새 plan은 루프 비소속으로 안전.

## 두 기둥 (설계 불변식)

이 둘을 깨면 forge가 forge가 아니게 된다 (`CLAUDE.md` "설계 원칙").

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** 워크플로우는 실행 중 사람 입력을 못 받는다. 한 질문씩 주고받는 그릴링(fg-ask)·회고(fg-learn)는 반드시 워크플로우 밖 대화로 한다.
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.

기둥의 **의도적·경계 있는 완화**가 두 곳 있다: fg-quick은 trivial 작업에 한해 기둥 2(형식 산출물)를 완화하고(ADR-0003), fg-loop는 사전 승인된 재계획 범위 안에서만 기둥 1(계획별 그릴링)을 완화한다(ADR-0016). 두 경우 모두 완화의 범위 승인 자체는 대화(그릴링/기초 질의)의 산출물이다.

## 루프 4단계 (각 스킬 = 한 턴)

- **fg-ask (① 질의·계획·그릴링)** — grill-with-docs식 대화형 그릴링. 계획을 도메인·용어·결정에 대고 검증해 `.forge/backlog/<slug>.md`로 적재하고, 그릴링 중 `CONTEXT.md`/ADR을 인라인 갱신한다. 시작 전 점검 순서: **(1)** 미완 선행 루프 1회 확인(active slot의 `status: executed` 미봉인 또는 parked `executed/` 존재 시 "먼저 끝낼까/새로 시작할까" — (a)면 fg-next 호출), **(1b — 최신)** `.forge/loop.md` 존재 시 "goal 루프가 벽에서 멈춰 있다 — (a) fg-loop로 재개 / (b) 새 작업 계속?" 한 줄 경고. (b)여도 새 plan은 `loop.md`의 `## Tasks` 멤버십에 등재하지 않으므로 무인 주행에서 안전, **(2)** slug 충돌·재그릴링 검사, 이어 최근 retro 3–5건 피드백, `.forge/codebase/` 지도 읽기(+`last_mapped_commit` staleness 경고), TDD 모드 질문(`.forge/config.json`의 `tdd`가 기본값). 외부 지식이 필요하면 deep-research를 **제안만**(자동 실행 금지, ADR-0006). `skills/fg-ask/SKILL.md` — 본문은 grill-with-docs 영문 verbatim이고, forge 연결은 맨 아래 "Forge integration (minimal)" 섹션에만 있다.
- **fg-run (② 실행)** — 백로그에서 plan을 활성 슬롯(`.forge/plan.md`)으로 승격해 Dynamic Workflow로 실행한다. 슬롯이 비어 있으면 **백로그보다 먼저** parked `verified: failed`를 최우선 회수 후보로 노출(unpark의 단일 소유자). 후보 0개면 fg-ask 안내, 1개면 **메뉴 없이 즉시 실행**, 2개+면 priority 정렬(`high→medium→low`, part는 N/M 순) `AskUserQuestion` 메뉴(마지막 옵션 "Run all" — 절차는 `skills/fg-run/RUN-ALL.md`로 분리, 선택 시에만 로드). plan의 "Work slices"가 1차 작업 단위, `(depends:)`로 wave를 구성. 위험/대형 변경엔 조건부 적대 코드리뷰(ADR-0007), `tdd: on`이면 test-first(ADR-0008), `eco: true`면 위임 서브에이전트를 sonnet으로 캡(내리기만, ADR-0014). 종료 시 `.forge/run.md`(계획↔실제 차이) → `.forge/STATUS.md`(`status: executed`, `verified: pending`, `retro: pending`) → **핸드오프 UAT로 `verified:` 기록** 순. 재실행 가드: `run.md`가 이미 있으면 `verified:` 값에 따라 검증 전용 재진입(`pending`)/fix-and-re-run·재그릴(`failed`)/중복 실행 경고(sealable)로 분기. `skills/fg-run/SKILL.md`.
- **fg-learn (③ 회고)** — `run.md`·`plan.md`(활성 슬롯 또는 `executed/<slug>/`)를 읽어 학습을 3분류한다: 도메인 용어→`CONTEXT.md`, 3조건(되돌리기 어렵다/맥락 없이 의아하다/진짜 트레이드오프) 전부 충족→ADR, 나머지 전부→`.forge/retro/YYYY-MM-DD-<slug>.md`. 승급은 사람 확인 후에만. 항상 대화형. 회고 전 **검증 게이트**(STATUS `verified:` 확인 — 아래 섹션). **최신: "Batch promotion mode"** — 기본 경로의 두 제외(봉인된 작업 = 상태 오류 / `retro: skipped` = 재제안 금지)를 **의도적으로 우회하는 유일한 명시 진입 모드**. fg-next all·fg-loop·fg-run skip 경로가 약속한 "학습은 run.md에 보존, 추후 일괄 승급"의 수신처다. 진입은 명시 요청("일괄 승급"/"batch promotion")만 — 오케스트레이터가 자동 호출하지 않음. 후보 = `done/*/STATUS.md`의 `retro: skipped (...)` 봉인 작업; 작업별로 아카이브된 `done/<날짜-slug>/run.md`를 읽어 한 건씩 대화 리뷰; **승급 바를 넘는 학습이 있을 때만** retro 파일 생성("리뷰했지만 승급할 것 없음" = 정상·파일 없는 결과); retro 파일을 쓴 경우에만 봉인 STATUS의 `retro:`를 skipped에서 retro 경로+늦은 승급 주석으로 정정(`status: done`은 절대 불변). `skills/fg-learn/SKILL.md`.
- **fg-done (④ 완료·봉인)** — 게이트 통과 후: STATUS를 **제자리에서 먼저** `status: done`으로 마감(중단돼도 idempotent 재진입 가능 — 양쪽 버킷이 비었어도 half-sealed `done/*` 디렉터리를 먼저 스캔해 마감 완료) → `.forge/done/<날짜-slug>/`로 이동 → 활성 슬롯 비움(**재실행 방지의 핵심 메커니즘** — plan.md가 사라지면 fg-run이 돌릴 대상을 못 찾음) → 완료 통지(+ 영속 문서 미커밋 시 커밋 리마인더 한 줄, git 실행은 절대 안 함) → 조건부 fg-map 제안(지도 존재 + 비-`.forge/` 변경 둘 다 참일 때만, 제안일 뿐 자동 실행 금지). `skills/fg-done/SKILL.md`.

## 상태 계약 — `.forge/` 파일 핸드오프

상태의 원천은 **파일 위치**다: `backlog/<slug>.md`(미실행 대기열) → 활성 슬롯 `plan.md`+`run.md`+`STATUS.md`(항상 1개) → `executed/<slug>/`(Run all이 park한 "실행됐으나 미회고") → `done/<날짜-slug>/`(봉인). plan 첫 줄의 `<!-- forge-slug: ... -->`가 이동에도 영속하는 짝 맞춤 식별자이고, `<!-- task: N -->`은 단조증가 고정 번호다(ADR-0005, `skills/fg-run/PLAN-FORMAT.md`).

| 파일 | 생산자 | 소비자 |
| --- | --- | --- |
| `.forge/backlog/<slug>.md` | fg-ask, fg-loop(기초 질의·fix-forward 생성) | fg-run(선택 메뉴·승격), fg-status |
| `.forge/plan.md` (활성 슬롯) | fg-run(승격; 내용은 fg-ask 소유) | fg-run(정답 기준), fg-learn |
| `.forge/run.md` | fg-run | fg-learn(일괄 승급 시엔 `done/*/run.md`도) |
| `.forge/STATUS.md` | fg-run(생성·`verified:` 기록) | fg-run·fg-learn·fg-done·fg-status |
| `.forge/executed/<slug>/` | fg-run(Run all park — sealable만) | fg-learn(회고 대기), fg-done(봉인), fg-run(failed unpark) |
| `.forge/done/<날짜-slug>/` | fg-done | fg-ask(slug 충돌), fg-run(완료 판별), fg-learn(기본 제외 / 일괄 승급 후보), fg-done(이중 봉인 방지) |
| `.forge/loop.md` (goal 계약 + **`## Tasks` 멤버십**) | fg-loop(기초 질의에서 생성, 체크박스·멤버십 갱신, goal-met 시 삭제) | fg-loop(resume·멤버십 필터), fg-status(현황 보고 + 상태 머신 0순위), fg-next all(존재 시 주행 양보), fg-ask(1b 경고), fg-merge(브랜치 루트 in-flight halt) |

### STATUS.md 필드 수명 주기 — 누가 무엇을 쓰는가

`STATUS.md`는 작업 파일들과 **함께 이동하는 동반 마커**다(이중 장부 아님). 필드별 쓰기 소유권:

- **`status:`** — fg-run이 `executed`로 생성, fg-done만 `done`으로 마감. 다른 스킬은 절대 안 건드림(일괄 승급 모드도 `status:`는 불변).
- **`verified:`** — fg-run의 핸드오프 UAT가 기록(`pending` → `yes (<증거>)`/`skipped (사유)`/`n/a (사유)`/`failed (사유)`). 예외 둘: parked/legacy 작업의 회수 UAT는 fg-learn(검증 게이트 복구)·fg-done(봉인 시점 확인)이 기록할 수 있다.
- **`retro:`** — fg-learn은 **in-flight 작업의 이 필드를 절대 건드리지 않는다**(`skills/fg-learn/SKILL.md` "Doc impact"). 회고 완료 판정은 retro 파일 존재(slug 매칭)로 하고, 필드는 fg-done이 봉인 시 retro 경로로 채운다. `skipped (사유)`는 fg-run 핸드오프("바로 종료")·fg-next all/fg-loop(자동 skip — 기록 자체는 위임받은 done 단계가 수행)·fg-done(봉인 시점 명시 skip)이 기록한다. **retro 파일은 있는데 STATUS가 `retro: pending`인 것은 정상 pre-seal 상태** — fg-status의 상태 머신은 이를 "retro again"이 아니라 "ready to seal"로 읽는다. **유일한 사후 쓰기 예외 = fg-learn 일괄 승급 모드**: 봉인 작업의 `retro: skipped`를 늦게 쓴 retro 경로(+일괄 승급 날짜 주석)로 정정한다 — fg-status 테이블이 현실을 반영하도록.

## 검증 게이트 (ADR-0009) — run → verify → learn → done

봉인 가능 값은 `yes (<증거 한 줄>)` / `skipped (사유)` / `n/a (사유)`, 차단 값은 `pending`(UAT 미수행)과 `failed (사유)`(UAT 수행, 결과 깨짐). fg-done은 **검증 게이트를 회고 게이트보다 먼저** 확인한다(no-seal-without-verification).

- `pending` + 활성 슬롯 → fg-run의 **검증 전용 재진입**(재실행 없이 UAT만 수행해 `verified:` 기록).
- `pending` + parked/legacy → 도달 가능한 fg-run 핸드오프가 없으므로 fg-learn(검증 게이트)·fg-done(봉인 시점)이 그 자리에서 UAT를 확인·기록.
- `failed` → fg-learn·fg-done 모두 차단. **fg-run이 unpark의 단일 소유자** — 활성 슬롯이 빌 때 `executed/<slug>/{plan,run,STATUS}`를 활성 슬롯으로 되돌려 fix-and-re-run하거나 fg-ask 재그릴. `failed`는 어떤 waiver로도 봉인 못 하며(`skipped` 전환 금지), fresh re-run 재검증으로만 풀린다.
- Run all(`skills/fg-run/RUN-ALL.md`)은 작업별 UAT를 **파킹 전** 수행 — sealable만 `executed/`로 park하고, `failed`는 활성 슬롯에 남겨 배치를 fail-stop한다(park하면 fg-run의 손이 안 닿아 좌초).

게이트 흐름:

```
run.md 기록 → STATUS(executed, verified: pending) → 핸드오프 UAT
   │ yes/skipped/n/a (sealable) ──▶ fg-learn 회고 (또는 skip) ──▶ fg-done 봉인
   │ pending  ──▶ fg-run 검증 전용 재진입 (재실행 없음)
   │ failed   ──▶ fg-run fix-and-re-run / fg-ask 재그릴  (fg-learn·fg-done 차단, waiver 불가)
```

## 회고 skip (ADR-0002)과 일괄 승급의 짝

기본값은 회고(fg-learn). `run.md`의 계획↔실제 divergence가 없거나 미미할 때만 skip이 제시되고, 선택 시 `retro: skipped (사유)`로 기록된다(회고 파일 없음). fg-done의 봉인 가드는 retro 파일 존재 **또는** `retro: skipped`를 통과로 인정한다. fg-ask는 plan에 `<!-- retro-hint: optional -->`(비구속 힌트)만 남길 수 있다 — 실제 skip 판단은 fg-run의 divergence 게이트. fg-next all과 fg-loop는 divergence 무관 **항상 자동 skip**(학습은 아카이브된 run.md에 보존 — ADR-0010 개정 패턴).

이 "추후 승급" 약속의 수신처가 **fg-learn의 Batch promotion mode**다(이 커밋의 신규 계약): 명시 요청에만 진입해 `done/*/STATUS.md`의 `retro: skipped` 작업들을 한 건씩 대화 리뷰하고, 승급 바를 넘는 학습이 있을 때만 retro 파일을 쓴 뒤 그 작업의 봉인 STATUS `retro:`를 정정한다. skip → 보존 → 일괄 승급의 고리가 이로써 닫힌다.

```
fg-run skip / fg-next all / fg-loop  ──▶ retro: skipped 기록, run.md는 done/에 아카이브
                                              │ (시간 경과, 사람이 원할 때)
                                              ▼
사용자 "일괄 승급" ──▶ fg-learn Batch promotion mode ──▶ done/<날짜-slug>/run.md 리뷰 (한 건씩)
                                              │ 승급 학습 있음 ──▶ retro 파일 생성 + STATUS retro: 정정
                                              │ 없음 ──▶ retro: skipped 유지 (파일 없는 정상 결과)
```

## 핸드오프 설계 (ADR-0015, 개정 2026-06-11) — state-and-stop, 메뉴는 fg-run 하나

"단계마다 진행할까요?"라고 묻는 드리프트를 걷어낸 결정 (`.forge/adr/0015-fg-run-handoff-menu-others-stated.md`):

- **fg-ask·fg-learn·fg-done의 핸드오프는 전부 진술형(state-and-stop)** — 다음 스킬과 트리거를 알리고 멈춘다. "진행할까요?"를 묻지 않고 자동 호출도 안 한다.
- **유일한 예외 = fg-run 단일작업 종료의 4지 명시 메뉴**(UAT로 `verified:` 기록 *후*): ① **회고 후 봉인까지**(기본·divergence 무관 — fg-learn 대화 회고 후 그 자리에서 fg-done 인라인 호출로 봉인; 단 회고 중 재그릴 권고가 나오면 자동 봉인을 중단하고 fg-done 트리거 진술로 폴백) ② **회고만**(fg-learn 후 정지) ③ **바로 종료**(`retro: skipped` 기록 후 fg-done 인라인 호출 — 저-divergence에서만 제시) ④ **프롬프트로 나가기**(executed 상태로 정지). divergence가 크면 ③만 빠진다. `retro-hint: optional`이면 ③을 앞세우되 메뉴는 유지.
- **Run-all 배치 핸드오프도 진술형** — "어느 것부터 회고할까?"는 fg-learn 소유 질문이라 중복 금지(`skills/fg-run/RUN-ALL.md` 4단계).
- **체이닝(다음 스킬 자동 호출)은 fg-next 전담.** fg-run 메뉴 ①/③의 fg-done 인라인 호출만 예외 — 사용자가 명시 선택한 종료의 이행이다.
- 스킬은 마크다운 지시문이라 **호출자를 런타임에 감지할 수 없으므로**, fg-run은 항상 메뉴를 제시하고 fg-next(오케스트레이터)가 그것을 해소한다.

## 루프-밖 유틸리티 (9개) — 격리 방식

어느 것도 루프 4단계가 아니며, 각자 명시된 범위만 만진다.

- **fg-map** (`skills/fg-map/SKILL.md`) — 4개 병렬 서브에이전트가 `.forge/codebase/` 7문서(STACK·INTEGRATIONS·ARCHITECTURE·STRUCTURE·CONVENTIONS·TESTING·CONCERNS)를 **직접 쓰고 확인만 반환**(오케스트레이터 컨텍스트 보호). `last_mapped_commit` frontmatter 스탬프, 시크릿 스캔 필수, 커밋은 제안만. 루프 상태 일절 안 만짐.
- **fg-quick** (`skills/fg-quick/SKILL.md`, ADR-0003) — trivial 작업 경량 차선. 가벼운 그릴링(기둥 1 유지)→`.forge/quick/LOG.md` 한 줄→직접 실행. 형식 산출물 없음, **활성 슬롯·backlog·done과 완전 격리**, 비-trivial이면 fg-ask로 bail.
- **fg-status** (`skills/fg-status/SKILL.md`) — 읽기 전용 리포터. 6열 작업 테이블(No./Date/Task/Stage/Verify/Retro) + 다음 단계 한 줄. **아무것도 쓰지 않고 자동 실행 안 함.** 조사 대상에 `.forge/loop.md`(goal 한 줄·round N/cap·체크 통과/실패 — 없으면 섹션 생략) 포함. **최신: `(loop)` 출처 태그** — plan에 `<!-- generated-by: fg-loop -->` 마커가 있으면 Task 열의 slug 뒤에 `(loop)`를 붙여 자동 생성 작업과 사람 그릴링 작업을 한눈에 구분. "Deriving the next step (state machine)" 섹션이 다음-단계 도출 로직의 **단일 정의처** — **0순위: `loop.md` 존재 시 fg-loop resume**, 이후 failed→pending→retro→seal 우선순위.
- **fg-next** (`skills/fg-next/SKILL.md`, ADR-0010) — fg-status의 상태 머신을 **재구현 없이 참조**해 다음 단계를 도출하고 한 줄 알린 뒤 **그 스킬을 같은 턴에 호출**한다(go-ahead 대기 없음). 기본 one-shot, 자체 쓰기 0(모든 쓰기는 위임 스킬). `all` 모드는 백로그가 빌 때까지 자동 주행 — 회고는 divergence 무관 **항상 자동 skip**(`retro: skipped (fg-next all 자동 진행 …)` — 기록은 위임받은 done 단계가 수행), 4개 halt 조건(failed·검증불가 UAT·진짜 fork·빈 상태)에서만 정지. **최신: `loop.md`가 존재하면 all 모드는 주행하지 않는다** — goal 루프가 자기 멤버 작업을 자체 주행하므로 병행 주행은 이중 승격이 된다; 한 줄 알리고 fg-loop에 위임(one-shot의 announce-then-invoke와 동일 패턴). `/goal` 페어링으로 턴 경계 넘는 무인 구동 패턴 문서화(스킬이 `/goal`을 직접 켤 수는 없음 — 사용자가 입력).
- **fg-loop** (`skills/fg-loop/SKILL.md`, ADR-0016) — goal 주도 한정 재계획 모멘텀 루프. 아래 별도 섹션 참조.
- **fg-tdd** (`skills/fg-tdd/SKILL.md`, ADR-0008) — `.forge/config.json`의 `tdd`만 토글. fg-ask가 작업별 기본 답으로 쓰고 fg-run이 `tdd: on` plan을 test-first로 실행.
- **fg-eco** (`skills/fg-eco/SKILL.md`, ADR-0014) — `.forge/config.json`의 `eco`만 토글. 켜면 fg-run이 위임 워크플로우 서브에이전트를 sonnet으로 **캡**(내리기만·세션 모델 불변·명시적 사용자 지시 우선). fg-map 매퍼는 범위 밖(지도 품질 = 설계 품질).
- **fg-merge** (`skills/fg-merge/SKILL.md`, ADR-0011) — `git merge` **후** 비-기본 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합: ADR 재번호(전체 old→new 맵 먼저, placeholder 1패스, incoming 문서만 재작성)·retro 이동·CONTEXT 용어 병합·done/backlog 합침(task 번호 재부여)·브랜치 폴더 제거. 기계적 부분 자동, 진짜 충돌(용어 재정의·결정 모순)만 사람에게. git 실행 안 함. **최신: in-flight halt 대상에 브랜치 루트의 `loop.md` 포함** — 미완 goal 계약(goal-met였다면 삭제됐을 파일)이 남아 있으면 통합을 halt하고 브랜치에서 fg-loop로 goal-met까지 주행하거나 의도적으로 `loop.md`를 삭제(포기)한 뒤 통합하라고 안내한다 — 체크 상태·replan 라운드를 흔적 없이 버리는 사고 방지. 기존 halt 대상(활성 슬롯·`executed/`·`결과: pending` quick 엔트리)은 그대로.
- **fg-cleanup** (`skills/fg-cleanup/SKILL.md`, ADR-0012) — 낡은/대체된 ADR을 **사람 승인으로만** `.forge/adr/retired/<NNNN>-slug.md`로 은퇴. 번호 불변·재사용 금지·삭제 없음·교차참조 재작성 없음. fg-ask는 `retired/`를 그릴링 연료로 읽지 않는다. 봉인은 fg-done이지 이 스킬이 아님.

## fg-loop (ADR-0016, 개정 2026-06-12) — goal 주도 한정 재계획 루프

`skills/fg-loop/SKILL.md`. **기둥 1을 세 경계 안에서만 의도적으로 완화한다**(fg-quick이 기둥 2를 trivial 한정 완화한 ADR-0003과 동형의 선례). "AI가 만족됐다고 생각함"은 정지 조건이 아니다 — 기록된 체크만이 정지 조건이다.

1. **기초 질의 (대화, 워크플로우 밖)** — fg-ask의 그릴링 방법(`skills/fg-ask/SKILL.md` 참조)을 재사용해 두 산출물을 만든다: (a) **goal 계약 `.forge/loop.md`** — 한 줄 goal, `replan-round`/`replan-cap`(기본 **3**), **기계 검증 가능한 정지 조건 체크 목록**(grep 단언·테스트·빌드·JSON 파싱 등 에이전트가 실행 가능한 형태만), **사전 승인 재계획 범위**(기본: "실패 체크에 직접 추적되는 fix-forward 작업, 그 외 없음"), 그리고 **`## Tasks` 멤버십 목록**(이 커밋의 신규 계약 — 이 루프가 소유한 모든 plan의 slug; 기초 질의 plan을 생성 시점에 등재하고 이후 생성되는 fix-forward plan도 생성 시점에 추가); (b) **초기 백로그** — goal을 분해해 `.forge/backlog/`에 PLAN-FORMAT plan들로 적재(`forge-slug`·단조 `task:` 번호·TDD 질문·slug 충돌 검사·분할 규칙 전부 fg-ask와 동일). `loop.md`가 이미 있으면 **resume**(질의 skip, 상태 보고 후 주행 재진입 — fg-next all과 같은 stateless 패턴; `## Tasks`가 없는 구판 loop.md는 resume 시 사용자에게 한 번 물어 멤버십을 추가, 추측 금지).
2. **주행(drive)** — `fg-next all`의 기계를 **참조로 재사용**(`skills/fg-next/SKILL.md` "all mode", 복붙 금지)하되 **`## Tasks`에 등재된 멤버 slug만 승격**한다(멤버십 필터). 벽에서 멈춘 사이 fg-ask가 적재한 비소속 backlog plan은 건드리지 않고 한 줄 보고만 — 그것은 정식 루프의 몫. 승격→fg-run 실행→공격적 UAT→**회고 항상 자동 skip**(`retro: skipped (fg-loop 자동 진행 — 학습은 run.md, 승급은 추후 fg-learn)` — 기록은 done 단계가 수행)→fg-done 봉인→반복. 봉인마다·백로그가 빌 때마다 **정지 조건 체크를 실행**해 `loop.md` 체크박스를 갱신. 전부 통과 → 요약 보고 + **`loop.md` 삭제** + 종료(goal met). fg-loop 자체가 쓰는 파일은 `loop.md`와 자기가 생성하는 plan뿐 — "자체 쓰기 0"인 fg-next와의 유일한 의도적 차이.
3. **한정 재계획(bounded replan)** — 사람 대화 없이 새 작업이 생기는 두 경우, 모두 `loop.md`가 경계: (a) **UAT `verified: failed`** — fg-next all에서는 벽이지만 fg-loop에서는 **자동화 대상**: 실패 체크에 직접 추적되는 fix-forward 작업을 생성하고, failed 작업 자체는 fg-run의 정상 failed 처리(fix-and-re-run → fresh run.md → 재검증)에 맡긴다. `failed` 봉인 금지는 불변(ADR-0009). (b) **백로그 빈 상태 + 체크 실패** — `replan-round` +1, cap 초과면 벽; 아니면 실패 체크 클러스터당 fix-forward plan 생성 — **승인 범위 안에서만**. 생성된 plan은 전부 정상 plan(PLAN-FORMAT·`forge-slug`·단조 `task:` 번호) + `<!-- generated-by: fg-loop -->` 출처 마커(fg-status가 `(loop)` 태그로 표시) + **생성 시점에 `## Tasks`에 slug 등재**. 필요한 수정이 승인 범위를 벗어나면 생성하지 않고 벽(진짜 fork)으로 처리.
4. **벽과 종료** — 4개 벽에서 halt 후 사람에게 보고: ① 검증 불가 UAT(`pending` — 미검증 봉인 금지, ADR-0009) ② 진짜 설계 fork(범위 초과 수정 포함) ③ replan cap 소진 ④ **무진전 조기 중단**(같은 체크가 2연속 fix-forward에도 무진전이면 cap 전이라도 중단). 벽에서는 `loop.md`가 디스크에 남고(fg-status가 보고, fg-ask가 1b 경고, fg-next all이 주행 양보), 사람이 해소 후 `fg-loop` 재트리거로 resume. goal-met 종료 시에만 `loop.md` 삭제 + 진술형 최종 요약(추후 일괄 승급은 fg-learn Batch promotion mode 안내). 턴 경계 넘는 무인 주행은 fg-next all과 동일하게 `/goal` 페어링 패턴으로만 문서화 — goal 조건은 반드시 "체크 전부 통과 **또는** 벽 도달 시 정지 허용"으로 표현(벽을 강행 돌파하는 표현 금지).

```
fg-loop
   │
   ▼
loop.md 존재? ── yes ──▶ resume: 상태 보고 (## Tasks 멤버십 필터 유지) ──▶ 주행
   │ no
   ▼
기초 질의(대화): 기계 검증 체크 + 재계획 범위 + cap + ## Tasks → loop.md, 초기 plan → backlog/
   │
   ▼
┌─▶ 멤버 slug 승격 ─▶ run ─▶ UAT ─▶ 회고 자동 skip ─▶ 봉인 ─▶ 정지 조건 체크 실행
│        │ verified: failed ─▶ fix-forward 생성(범위·cap 내, ## Tasks 등재) ─▶ fix-and-re-run ─┐
│   전부 통과 ──▶ 요약 보고, loop.md 삭제, 종료 (goal met)                                       │
│   백로그에 멤버 작업 남음 ────────────────────────────────────────────────────────────────◀─┘
│   백로그 빔 + 체크 실패 ──▶ replan-round +1 ≤ cap? ── yes ─▶ fix-forward plan 생성 ─┐
│                                  │ no                                                │
│                                  ▼                                                    │
│                               벽: halt, 보고, 사람 대기                                │
└────────────────────────────────────────────────────────────────────────────────────◀─┘
   (벽 어디서든: 검증불가 UAT · 진짜 fork/범위 초과 · cap 소진 · 무진전 ×2)
```

## 모멘텀 차선 셋 + fg-quick

같은 루프 기계 위의 세 가지 진행 방식 (fg-quick은 별도 — trivial 전용):

| 차선 | 회고 | 종료 조건 | 새 작업 생성 | 주행 대상 |
| --- | --- | --- | --- | --- |
| 정식 루프 (fg-ask→fg-run→fg-learn→fg-done, one-shot fg-next 포함) | 대화 회고 | 작업 1개 봉인 | 없음 — 사람이 그릴링 | 전체 백로그 |
| `fg-next all` (ADR-0010) | 항상 자동 skip | **백로그 소진**(빈 상태) 또는 벽 | 없음 — 사람이 그릴링한 백로그만 소진 | 전체 백로그 (단, `loop.md` 존재 시 fg-loop에 양보) |
| `fg-loop` (ADR-0016) | 항상 자동 skip | **정지 조건 체크 전부 통과** 또는 벽 | **있음(한정)** — 승인 범위 내 fix-forward, cap 기본 3 | **`loop.md` `## Tasks` 멤버 slug만** |

fg-loop는 fg-next all의 superset이다: 빈 상태에서 goal을 재점검하고, `verified: failed`(fg-next all의 벽)를 cap 내 자동 fix-forward 대상으로 바꾼다 — 이 벽 완화가 fg-loop의 존재 이유. 세 차선이 같은 백로그를 공유하되 **멤버십 목록이 경계선**이다: fg-loop는 멤버만, fg-next all은 `loop.md`가 없을 때만 주행하므로 이중 승격이 구조적으로 차단된다.

## 단일 정의 참조 규칙

복붙 금지 — 정의는 한 벌만 두고 다른 스킬은 참조한다:

- **forge 루트 해석** — `skills/fg-run/FORGE-ROOT.md` 단일 정의(소유: fg-run). 모든 루프 스킬 + 유틸리티가 참조.
- **plan 형식·마커·분할 규칙** — `skills/fg-run/PLAN-FORMAT.md`(소유: fg-run). 생산자 fg-ask·fg-loop, 소비자 fg-run. 생산자 fg-ask 쪽이 아닌 소비자 쪽에 두는 이유: `skills/fg-ask/`는 grill-with-docs verbatim 영역.
- **다음-단계 상태 머신** — `skills/fg-status/SKILL.md` "Deriving the next step"(소유: fg-status). fg-next가 재구현 없이 참조하고, fg-ask의 미완 루프 분기(1)도 이 머신에 위임. `loop.md` 존재가 0순위(→ fg-loop resume).
- **Run-all 배치 절차** — `skills/fg-run/RUN-ALL.md`(소유: fg-run, 선택 시에만 로드 — 토큰 효율).
- **fg-next all 주행 기계** — `skills/fg-next/SKILL.md` "all mode"(소유: fg-next). fg-loop가 참조로 재사용(멤버십 필터만 얹음).
- **형식 문서** — `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`, `skills/fg-learn/RETRO-FORMAT.md`. 타 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(또는 `../fg-ask/` 등 상대경로)로 참조.

## 브랜치 격리 forge 루트 (ADR-0011)

단일 정의는 `skills/fg-run/FORGE-ROOT.md` — 모든 루프 스킬이 참조하고 복붙하지 않는다.

- 기본 브랜치(`config.json`의 `defaultBranch`, 없으면 `main`) → 루트 `.forge/`. 그 외 브랜치 → `.forge/branch/<branch>/`(슬래시 브랜치는 중첩 디렉터리). detached HEAD/비-git → `.forge/` 폴백 + 한 줄 경고.
- **전역 예외 2개** — `.forge/config.json`(루트 해석 자체가 `defaultBranch`를 읽어야 하는 부트스트랩 + 프로젝트 전역 설정)과 `.forge/codebase/`(공유 참고 연료 — 브랜치-로컬이면 새 브랜치가 지도를 잃음)는 모든 브랜치에서 항상 최상위.
- **읽기 오버레이** — 비-기본 브랜치에서 영속 연료(`CONTEXT.md`·`adr/`·`retro/`)의 **읽기**는 최상위 `.forge/` 베이스 위에 브랜치 루트를 겹쳐 읽는다(충돌 시 브랜치 우선). **쓰기는 브랜치 루트에만**(머지 충돌 방지의 본체). 새 ADR 번호는 브랜치-루트 `max+1`(통합 시 fg-merge가 재번호). `adr/retired/`는 양쪽에서 제외.
- 비-기본 브랜치 루트는 **통째로 git 추적**(`.gitignore`의 `!.forge/branch/`), 기본 브랜치 휘발 상태는 종전대로 gitignored — 의도된 비대칭. 경로가 브랜치별로 네임스페이스되어 두 브랜치가 같은 파일을 안 건드리므로 git merge 충돌이 없다. 통합은 `git merge` 후 fg-merge(브랜치 `loop.md` 등 in-flight 상태가 남아 있으면 halt).

## 진입점 (스킬 트리거)

스킬은 frontmatter `description`의 트리거 발화로 자동 매칭된다(한/영 혼재). 대표 트리거:

| 스킬 | 트리거 |
| --- | --- |
| fg-ask | "start a new task" · "새 작업 시작" · "forge로 시작" · "계획 다듬자" |
| fg-run | "forge run" · "계획 실행" (구 별칭 "forge execute") |
| fg-learn | "forge learn" · "회고하자" (+ 일괄 승급: "일괄 승급" / "batch promotion") |
| fg-done | "작업 완료" · "봉인" (구 별칭 "작업 정리"·"forge complete"; "forge cleanup"은 ADR 은퇴 스킬로 라우팅) |
| fg-map | "map the codebase" · "코드베이스 분석" |
| fg-quick | "forge quick" · "빠르게 처리" |
| fg-status | "forge status" · "상태" · "어디까지 했지" |
| fg-next | "forge next" · "다음 단계" · "이어서 해줘" / all: "fg-next all" · "다음 전부 진행" |
| fg-loop | "forge loop" · "루프 시작" · "조건 충족까지 반복" |
| fg-tdd / fg-eco | "tdd on/off" · "TDD 켜/꺼" / "eco on/off" · "에코 모드" |
| fg-merge | "forge merge" · "브랜치 통합" |
| fg-cleanup | "forge cleanup" · "ADR 정리" · "ADR 은퇴" |

## 전체 흐름

```
fg-ask (대화 그릴링, CONTEXT/ADR 인라인 갱신 · 시작 전 미완 루프/halted goal 루프 확인)
   │  .forge/backlog/<slug>.md  (forge-slug · task: N · tdd · priority · part · retro-hint 마커)
   ▼
fg-run (승격 → Dynamic Workflow → plan 교차검증 → run.md → STATUS(executed) → 핸드오프 UAT verified:)
   │  4지 메뉴: 회고 후 봉인까지(기본) / 회고만 / 바로 종료(저-divergence만) / 나가기   ← 루프 유일의 메뉴 (ADR-0015 개정)
   │     ├ verified: failed ──▶ fix-and-re-run 또는 fg-ask 재그릴 (fg-learn 금지)
   │     └ Run all ──▶ 작업별 실행+UAT → sealable만 executed/ park, failed는 슬롯에 fail-stop (배치 핸드오프는 진술형)
   ▼
fg-learn (대화 회고 → 3분류 승급 → .forge/retro/ · in-flight STATUS retro: 필드는 안 건드림
   │       · 별도 명시 진입: Batch promotion mode — 봉인된 retro: skipped 작업의 일괄 승급)
   │  진술형 핸드오프 → fg-done
   ▼
fg-done (검증 게이트 → 회고 게이트 → STATUS done 제자리 마감 → done/<날짜-slug>/ → 활성 비움
   │      → 커밋 리마인더(영속 문서 미커밋 시 한 줄) → 조건부 fg-map 제안)
   ▼
(새 작업) fg-ask    ※ fg-status가 보고, fg-next가 다음 한 걸음 실행, fg-next all은 백로그 소진까지(loop.md 존재 시 양보),
                      fg-loop는 .forge/loop.md의 정지 조건 충족까지 (## Tasks 멤버만, 한정 fix-forward 재계획 포함)
```
