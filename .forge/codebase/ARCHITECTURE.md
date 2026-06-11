---
last_mapped_commit: 847fa4208a8ef8b709da41d36d106a3f3f92af29
mapped: 2026-06-11
---

# forge 아키텍처 — 루프와 상태 계약

## 요약

forge는 코드를 빌드하는 프로젝트가 아니라 **Claude Code 플러그인**이다. 산출물은 전부 Markdown(`SKILL.md`, `*-FORMAT.md`)과 JSON(매니페스트)뿐 — 런타임 코드도, 빌드·테스트·린트 시스템도 없다. "아키텍처"란 곧 **스킬들이 `.forge/` 상태 파일을 주고받으며 만드는 워크플로우 구조**다.

핵심 추상은 작업 하나를 한 바퀴 도는 **4단계 forge 루프**다. 각 스킬은 독립 실행되며, 직접 서로를 호출하지 않고 `.forge/` 파일 위치로 상태를 전달한다(파일 위치가 곧 상태 머신). 루프 4개 스킬 외에 루프-밖 유틸리티 8개가 있어 **총 12개 스킬**이다.

```
fg-ask(①질의·계획·그릴링) → fg-run(②실행) → [verify] → fg-learn(③회고) → fg-done(④완료·봉인) → (새 작업) fg-ask
```

## 두 기둥 (설계 불변식)

이 둘을 깨면 forge가 forge가 아니게 된다 (`CLAUDE.md` "설계 원칙").

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** 워크플로우는 실행 중 사람 입력을 못 받는다. 한 질문씩 주고받는 그릴링(fg-ask)·회고(fg-learn)는 반드시 워크플로우 밖 대화로 한다.
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.

## 루프 4단계 (각 스킬 = 한 턴)

- **fg-ask (① 질의·계획·그릴링)** — grill-with-docs식 대화형 그릴링. 계획을 도메인·용어·결정에 대고 검증해 `.forge/backlog/<slug>.md`로 적재하고, 그릴링 중 `CONTEXT.md`/ADR을 인라인 갱신한다. 시작 전에 (1) 미완 선행 루프 1회 확인(active slot의 `status: executed` 미봉인 또는 parked `executed/` 존재 시 "먼저 끝낼까/새로 시작할까" — (a)면 fg-next 호출), (2) slug 충돌·재그릴링 검사, (3) 최근 retro 3–5건 피드백, (4) `.forge/codebase/` 지도 읽기(+`last_mapped_commit` staleness 경고), (5) TDD 모드 질문(`.forge/config.json`의 `tdd`가 기본값)을 거친다. 외부 지식이 필요하면 deep-research를 **제안만**(자동 실행 금지, ADR-0006). `skills/fg-ask/SKILL.md` — 본문은 grill-with-docs 영문 verbatim이고, forge 연결은 맨 아래 "Forge integration (minimal)" 섹션에만 있다.
- **fg-run (② 실행)** — 백로그에서 plan을 활성 슬롯(`.forge/plan.md`)으로 승격해 Dynamic Workflow로 실행한다. 후보 0개면 fg-ask 안내, 1개면 **메뉴 없이 즉시 실행**, 2개+면 priority 정렬(`high→medium→low`, part는 N/M 순) `AskUserQuestion` 메뉴(마지막 옵션 "Run all" — 절차는 `skills/fg-run/RUN-ALL.md`로 분리, 선택 시에만 로드). plan의 "Work slices"가 1차 작업 단위, `(depends:)`로 wave를 구성한다. 위험/대형 변경엔 조건부 적대 코드리뷰(ADR-0007), `tdd: on`이면 test-first(ADR-0008), `eco: true`면 위임 서브에이전트를 sonnet으로 캡(내리기만, ADR-0014). 종료 시 `.forge/run.md`(계획↔실제 차이) → `.forge/STATUS.md`(`status: executed`, `verified: pending`, `retro: pending`) → **핸드오프 UAT로 `verified:` 기록** 순. `skills/fg-run/SKILL.md`.
- **fg-learn (③ 회고)** — `run.md`·`plan.md`(활성 슬롯 또는 `executed/<slug>/`)를 읽어 학습을 3분류한다: 도메인 용어→`CONTEXT.md`, 3조건(되돌리기 어렵다/맥락 없이 의아하다/진짜 트레이드오프) 전부 충족→ADR, 나머지 전부→`.forge/retro/YYYY-MM-DD-<slug>.md`. 승급은 사람 확인 후에만. 항상 대화형. `skills/fg-learn/SKILL.md`.
- **fg-done (④ 완료·봉인)** — 게이트 통과 후: STATUS를 **제자리에서 먼저** `status: done`으로 마감(중단돼도 idempotent 재진입 가능) → `.forge/done/<날짜-slug>/`로 이동 → 활성 슬롯 비움(**재실행 방지의 핵심 메커니즘** — plan.md가 사라지면 fg-run이 돌릴 대상을 못 찾음) → 완료 통지. 통지에는 **커밋 리마인더**가 포함된다: 이 루프가 만진 git 추적 영속 문서(`.forge/retro/`·`.forge/adr/`·`CONTEXT.md`)가 `git status`에 미커밋으로 남아 있으면 한 줄로 커밋을 상기시킨다(리마인더만, git 실행은 절대 안 함). 이어 조건부 fg-map 제안(지도 존재 + 비-`.forge/` 변경 둘 다 참일 때만, 제안일 뿐 자동 실행 금지). `skills/fg-done/SKILL.md`.

## 상태 계약 — `.forge/` 파일 핸드오프

상태의 원천은 **파일 위치**다: `backlog/<slug>.md`(미실행 대기열) → 활성 슬롯 `plan.md`+`run.md`+`STATUS.md`(항상 1개) → `executed/<slug>/`(Run all이 park한 "실행됐으나 미회고") → `done/<날짜-slug>/`(봉인). plan 첫 줄의 `<!-- forge-slug: ... -->`가 이동에도 영속하는 짝 맞춤 식별자이고, `<!-- task: N -->`은 단조증가 고정 번호다(ADR-0005, `skills/fg-run/PLAN-FORMAT.md`).

| 파일 | 생산자 | 소비자 |
| --- | --- | --- |
| `.forge/backlog/<slug>.md` | fg-ask | fg-run(선택 메뉴·승격), fg-status |
| `.forge/plan.md` (활성 슬롯) | fg-run(승격; 내용은 fg-ask 소유) | fg-run(정답 기준), fg-learn |
| `.forge/run.md` | fg-run | fg-learn |
| `.forge/STATUS.md` | fg-run(생성·`verified:` 기록) | fg-run·fg-learn·fg-done·fg-status |
| `.forge/executed/<slug>/` | fg-run(Run all park) | fg-learn(회고 대기), fg-done(봉인), fg-run(failed unpark) |
| `.forge/done/<날짜-slug>/` | fg-done | fg-ask(slug 충돌), fg-run(완료 판별), fg-learn(제외), fg-done(이중 봉인 방지) |

### STATUS.md 필드 수명 주기 — 누가 무엇을 쓰는가

`STATUS.md`는 작업 파일들과 **함께 이동하는 동반 마커**다(이중 장부 아님). 필드별 쓰기 소유권:

- **`status:`** — fg-run이 `executed`로 생성, fg-done만 `done`으로 마감. 다른 스킬은 절대 안 건드림.
- **`verified:`** — fg-run의 핸드오프 UAT가 기록(`pending` → `yes (<증거>)`/`skipped (사유)`/`n/a (사유)`/`failed (사유)`). 예외 둘: parked/legacy 작업의 회수 UAT는 fg-learn(검증 게이트 복구)·fg-done(봉인 시점 확인)이 기록할 수 있다.
- **`retro:`** — **fg-learn은 절대 이 필드를 건드리지 않는다**(명시 계약 — `skills/fg-learn/SKILL.md` "Doc impact"). 회고 완료 판정은 retro 파일 존재(slug 매칭)로 하고, 필드는 fg-done이 봉인 시 retro 경로로 채운다. `skipped (사유)`는 fg-run 핸드오프("바로 종료")·fg-next all(자동 skip)·fg-done(봉인 시점 명시 skip)이 기록한다. 따라서 **retro 파일은 있는데 STATUS가 `retro: pending`인 것은 정상 pre-seal 상태**다 — fg-status의 상태 머신은 이를 "retro again"이 아니라 "ready to seal"로 읽는다.

## 검증 게이트 (ADR-0009) — run → verify → learn → done

봉인 가능 값은 `yes (<증거 한 줄>)` / `skipped (사유)` / `n/a (사유)`, 차단 값은 `pending`(UAT 미수행)과 `failed (사유)`(UAT 수행, 결과 깨짐). fg-done은 **검증 게이트를 회고 게이트보다 먼저** 확인한다(no-seal-without-verification).

- `pending` + 활성 슬롯 → fg-run의 **검증 전용 재진입**(재실행 없이 UAT만 수행해 `verified:` 기록).
- `pending` + parked/legacy → 도달 가능한 fg-run 핸드오프가 없으므로 fg-learn(검증 게이트)·fg-done(봉인 시점)이 그 자리에서 UAT를 확인·기록.
- `failed` → fg-learn·fg-done 모두 차단. **fg-run이 unpark의 단일 소유자** — 활성 슬롯이 빌 때 `executed/<slug>/{plan,run,STATUS}`를 활성 슬롯으로 되돌려 fix-and-re-run하거나 fg-ask 재그릴. `failed`는 어떤 waiver로도 봉인 못 하며(skipped 전환 금지), fresh re-run 재검증으로만 풀린다. fg-run은 시작 시 활성 슬롯이 비어 있으면 **백로그보다 먼저** parked `failed`를 최우선 회수 후보로 노출한다.
- Run all(`skills/fg-run/RUN-ALL.md`)은 작업별 UAT를 **파킹 전** 수행 — sealable만 `executed/`로 park하고, `failed`는 활성 슬롯에 남겨 배치를 fail-stop한다(park하면 fg-run의 손이 안 닿아 좌초).

## 회고 skip (ADR-0002)

기본값은 회고(fg-learn). `run.md`의 계획↔실제 divergence가 없거나 미미할 때만 skip이 제시되고, 선택 시 `retro: skipped (사유)`로 기록된다(회고 파일 없음). fg-done의 봉인 가드는 retro 파일 존재 **또는** `retro: skipped`를 통과로 인정한다. fg-ask는 plan에 `<!-- retro-hint: optional -->`(비구속 힌트)만 남길 수 있다 — 실제 skip 판단은 fg-run의 divergence 게이트.

## 핸드오프 설계 (ADR-0015) — state-and-stop, 메뉴는 fg-run 하나

"단계마다 진행할까요?"라고 묻는 드리프트를 걷어낸 결정 (`.forge/adr/0015-fg-run-handoff-menu-others-stated.md`):

- **fg-ask·fg-learn·fg-done의 핸드오프는 전부 진술형(state-and-stop)** — 다음 스킬과 트리거를 알리고 멈춘다. "진행할까요?"를 묻지 않고 자동 호출도 안 한다.
- **유일한 예외 = fg-run 종료의 3지 명시 메뉴**(UAT로 `verified:` 기록 *후*): ① 회고(fg-learn, 기본) ② 바로 종료(`retro: skipped` 기록 후 **fg-done을 인라인 호출**해 봉인까지 — 저-divergence일 때만 제시) ③ 프롬프트로 나가기(executed 상태로 정지). divergence가 크면 ②를 빼고 회고/재그릴을 권한다. `retro-hint: optional`이면 ②를 앞세우되 메뉴는 유지.
- **체이닝(다음 스킬 자동 호출)은 fg-next 전담.** fg-run "바로 종료"의 fg-done 인라인 호출만 예외 — 사용자가 명시 선택한 종료의 이행이다.
- 스킬은 마크다운 지시문이라 **호출자를 런타임에 감지할 수 없으므로**, fg-run은 항상 메뉴를 제시하고 fg-next(오케스트레이터)가 그것을 해소한다.

## 루프-밖 유틸리티 (8개) — 격리 방식

어느 것도 루프 4단계가 아니며, 각자 명시된 범위만 만진다.

- **fg-map** (`skills/fg-map/SKILL.md`) — 4개 병렬 서브에이전트가 `.forge/codebase/` 7문서(STACK·INTEGRATIONS·ARCHITECTURE·STRUCTURE·CONVENTIONS·TESTING·CONCERNS)를 **직접 쓰고 확인만 반환**(오케스트레이터 컨텍스트 보호). `last_mapped_commit` frontmatter 스탬프, 시크릿 스캔 필수, 커밋은 제안만. 루프 상태 일절 안 만짐.
- **fg-quick** (`skills/fg-quick/SKILL.md`, ADR-0003) — trivial 작업 경량 차선. 가벼운 그릴링(기둥 1 유지)→`.forge/quick/LOG.md` 한 줄→직접 실행. 형식 산출물 없음, **활성 슬롯·backlog·done과 완전 격리**, 비-trivial이면 fg-ask로 bail.
- **fg-status** (`skills/fg-status/SKILL.md`) — 읽기 전용 리포터. 6열 작업 테이블(No./Date/Task/Stage/Verify/Retro) + 다음 단계 한 줄. **아무것도 쓰지 않고 자동 실행 안 함.** "Deriving the next step (state machine)" 섹션이 다음-단계 도출 로직의 **단일 정의처**다(failed→pending→retro→seal 우선순위).
- **fg-next** (`skills/fg-next/SKILL.md`, ADR-0010) — fg-status의 상태 머신을 **재구현 없이 참조**해 다음 단계를 도출하고 한 줄 알린 뒤 **그 스킬을 같은 턴에 호출**한다(go-ahead 대기 없음). 기본 one-shot, 자체 쓰기 0(모든 쓰기는 위임 스킬). `all` 모드는 백로그가 빌 때까지 자동 주행 — 회고는 divergence 무관 **항상 자동 skip**(`retro: skipped (fg-next all 자동 진행 …)`), 4개 halt 조건(failed·검증불가 UAT·진짜 fork·빈 상태)에서만 정지. `/goal` 페어링으로 턴 경계 넘는 무인 구동 패턴 문서화.
- **fg-tdd** (`skills/fg-tdd/SKILL.md`, ADR-0008) — `.forge/config.json`의 `tdd`만 토글. fg-ask가 작업별 기본 답으로 쓰고 fg-run이 `tdd: on` plan을 test-first로 실행.
- **fg-eco** (`skills/fg-eco/SKILL.md`, ADR-0014) — `.forge/config.json`의 `eco`만 토글. 켜면 fg-run이 위임 워크플로우 서브에이전트를 sonnet으로 **캡**(내리기만·세션 모델 불변·명시적 사용자 지시 우선). fg-map 매퍼는 범위 밖(지도 품질 = 설계 품질).
- **fg-merge** (`skills/fg-merge/SKILL.md`, ADR-0011) — `git merge` **후** 비-기본 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합: ADR 재번호(전체 old→new 맵 먼저, placeholder 1패스, incoming 문서만 재작성)·retro 이동·CONTEXT 용어 병합·done/backlog 합침(task 번호 재부여)·브랜치 폴더 제거. 기계적 부분 자동, 진짜 충돌(용어 재정의·결정 모순)만 사람에게. git 실행 안 함. 브랜치 루트에 in-flight 상태(활성 슬롯·executed·pending quick 엔트리)가 남아 있으면 halt.
- **fg-cleanup** (`skills/fg-cleanup/SKILL.md`, ADR-0012) — 낡은/대체된 ADR을 **사람 승인으로만** `.forge/adr/retired/<NNNN>-slug.md`로 은퇴. 번호 불변·재사용 금지·삭제 없음·교차참조 재작성 없음. fg-ask는 `retired/`를 그릴링 연료로 읽지 않는다. 이름이 과거 봉인 스킬이었으므로 시작 시 의도 확인 1회(봉인은 fg-done).

## 브랜치 격리 forge 루트 (ADR-0011)

단일 정의는 `skills/fg-run/FORGE-ROOT.md` — 모든 루프 스킬이 참조하고 복붙하지 않는다.

- 기본 브랜치(`config.json`의 `defaultBranch`, 없으면 `main`) → 루트 `.forge/`. 그 외 브랜치 → `.forge/branch/<branch>/`(슬래시 브랜치는 중첩 디렉터리). detached HEAD/비-git → `.forge/` 폴백 + 한 줄 경고.
- **전역 예외 2개** — `.forge/config.json`(루트 해석 자체가 `defaultBranch`를 읽어야 하는 부트스트랩 + 프로젝트 전역 설정)과 `.forge/codebase/`(공유 참고 연료 — 브랜치-로컬이면 새 브랜치가 지도를 잃음)는 모든 브랜치에서 항상 최상위.
- **읽기 오버레이** — 비-기본 브랜치에서 영속 연료(`CONTEXT.md`·`adr/`·`retro/`)의 **읽기**는 최상위 `.forge/` 베이스 위에 브랜치 루트를 겹쳐 읽는다(충돌 시 브랜치 우선). **쓰기는 브랜치 루트에만**(머지 충돌 방지의 본체). 새 ADR 번호는 브랜치-루트 `max+1`(통합 시 fg-merge가 재번호). `adr/retired/`는 양쪽에서 제외.
- 비-기본 브랜치 루트는 **통째로 git 추적**(`.gitignore`의 `!.forge/branch/`), 기본 브랜치 휘발 상태는 종전대로 gitignored — 의도된 비대칭. 경로가 브랜치별로 네임스페이스되어 두 브랜치가 같은 파일을 안 건드리므로 git merge 충돌이 없다.

## 전체 흐름

```
fg-ask (대화 그릴링, CONTEXT/ADR 인라인 갱신)
   │  .forge/backlog/<slug>.md  (forge-slug · task: N · tdd · priority · part · retro-hint 마커)
   ▼
fg-run (승격 → Dynamic Workflow → plan 교차검증 → run.md → STATUS(executed) → 핸드오프 UAT verified:)
   │  3지 메뉴: 회고 / 바로 종료(skip+fg-done 인라인) / 나가기      ← 루프 유일의 메뉴 (ADR-0015)
   │     ├ verified: failed ──▶ fix-and-re-run 또는 fg-ask 재그릴 (fg-learn 금지)
   │     └ Run all ──▶ 작업별 실행+UAT → sealable만 executed/ park, failed는 슬롯에 fail-stop
   ▼
fg-learn (대화 회고 → 3분류 승급 → .forge/retro/  · STATUS retro: 필드는 안 건드림)
   │  진술형 핸드오프 → fg-done
   ▼
fg-done (검증 게이트 → 회고 게이트 → STATUS done 제자리 마감 → done/<날짜-slug>/ → 활성 비움
   │      → 커밋 리마인더(영속 문서 미커밋 시 한 줄) → 조건부 fg-map 제안)
   ▼
(새 작업) fg-ask          ※ 어느 단계든 fg-status가 보고, fg-next가 다음 한 걸음을 실행
```
