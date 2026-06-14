---
last_mapped_commit: 74d8c840911bb14b4600e1618d678af158d1ce69
mapped: 2026-06-14
---

# Architecture

forge는 코드를 빌드하는 프로젝트가 아니라 **Claude Code 플러그인**이다. 산출물은 전부 Markdown(`SKILL.md`, `*-FORMAT.md`)과 JSON(매니페스트)이며, 빌드·테스트·린트·CI 시스템이 없다(예외: statusline용 bash 스크립트와 그 `*.test.sh`). "아키텍처"는 곧 스킬들이 `.forge/` 파일을 통해 상태를 주고받는 **데이터 흐름 계약**이다. 이 문서는 그 계약과 설계 원칙을 기록한다(도메인 용어 정의는 `CONTEXT.md` 소관 — 여기 없음).

## The forge loop (4-stage core)

forge의 본질은 작업 하나를 한 바퀴 돌리는 4단계 루프다. 각 스킬은 **독립 실행**되며 상태를 `.forge/` 파일로 주고받아 흐름을 잇는다. 한 스킬이 다음 스킬을 자동 호출하지 않고(체이닝은 `fg-next` 전담), 끝에서 다음 단계를 진술형으로 알리고 멈춘다.

```
fg-ask (①inquiry·plan·grill)
   → fg-run (②execute as Dynamic Workflow)
   → [fg-adversarial-review (optional, outside loop)]
   → fg-learn (③retro)
   → fg-done (④seal)
   → (new task) fg-ask
```

- **fg-ask** (`skills/fg-ask/SKILL.md`) — grill-with-docs식 대화형 그릴링. 계획을 도메인·용어·결정에 대고 검증해 `.forge/backlog/<slug>.md`로 적재한다. 반드시 본 세션 대화로 진행(워크플로우 밖). 루프의 진입점.
- **fg-run** (`skills/fg-run/SKILL.md`) — `.forge/plan.md`(또는 백로그의 대기 plan)를 Claude Code Dynamic Workflow로 실행하고, 계획↔실제 차이를 `.forge/run.md`에 기록한다. 핸드오프에서 plan 목표에 대고 UAT를 수행해 `verified:`를 기록한다.
- **fg-learn** (`skills/fg-learn/SKILL.md`) — 학습을 분류해 영속 문서(CONTEXT/ADR)로 승급하고, 승급 바를 못 넘는 학습은 `.forge/retro/`에 회고로 남긴다. 항상 대화형.
- **fg-done** (`skills/fg-done/SKILL.md`) — 루프의 ④완료(봉인). 한 바퀴의 잔여물을 정리해 `STATUS.md`를 `done`으로 마감하고 작업을 `.forge/done/<날짜-slug>/`로 봉인한 뒤 활성 `.forge/`를 비워 루프를 닫는다. 활성 상태를 비우는 것이 동일 plan 재실행을 막는 핵심 메커니즘.

흐름:
```
fg-ask → backlog/<slug>.md 적재
          ↓ fg-run 승격
       활성 슬롯(plan.md) → 실행 → run.md → STATUS(verified:) 기록
          ↓ verify 게이트 통과
       fg-learn(회고) → fg-done(봉인) → done/<날짜-slug>/ + 활성 비움
```

## Outside-the-loop utilities

이 4단계에 속하지 않는 11개 스킬. 루프 모양을 바꾸지 않고 보조한다.

- **fg-map** (`skills/fg-map/SKILL.md`) — 병렬 서브에이전트로 코드베이스를 `.forge/codebase/`의 구조화 문서로 매핑(이 문서를 생성하는 스킬). 그릴링이 코드 재탐색 대신 지도를 읽게 해 context rot을 줄인다.
- **fg-quick** (`skills/fg-quick/SKILL.md`) — trivial 작업용 경량 차선. 그릴링은 유지(기둥 1)하되 형식 산출물을 만들지 않고 `.forge/quick/LOG.md`에 한 줄만 기록한 뒤 직접 실행. 메인 루프의 활성 슬롯·backlog·done을 일절 안 건드린다. 비-trivial로 드러나면 fg-ask로 bail(ADR-0003).
- **fg-status** (`skills/fg-status/SKILL.md`) — 읽기 전용 상태 리포터. `.forge/`를 조사해 현황+다음 단계를 출력하고 아무것도 쓰지 않으며 다음 단계를 자동 실행하지 않는다.
- **fg-next** (`skills/fg-next/SKILL.md`) — fg-status의 상태 머신으로 다음 단계 하나를 도출해 한 줄로 알린 뒤 그 스킬을 곧바로 실행하는 오케스트레이터. 기본 one-shot, 자체적으로는 아무것도 쓰지 않음(위임 스킬이 모든 쓰기). `all` 모드는 백로그가 빌 때까지 선형 기계 단계를 자동 추천 진행하며 회고는 항상 자동 skip, 대화의 벽에서만 멈춘다(ADR-0010).
- **fg-loop** (`skills/fg-loop/SKILL.md`) — goal 주도 한정 재계획 루프. 기초 질의로 기계 검증 가능한 정지 체크·승인된 fix-forward 재계획 범위·상한(기본 3라운드)을 `.forge/loop.md`에 못 박고 초기 백로그를 적재한 뒤, 체크 전부 통과까지 run→UAT→회고 자동 skip→봉인을 무인 주행. `## Tasks` 멤버십 목록에 등재된 slug만 승격(ADR-0016).
- **fg-adversarial-review** (`skills/fg-adversarial-review/SKILL.md`) — fg-run과 fg-learn 사이 선택적 적대적 리뷰. "결과가 틀렸다고 가정하고 증거를 찾는" 자세로 6개 렌즈(실패 지점·숨은 가정·요구사항 오해·보안/성능/데이터 손실·예상 못한 오용·약한 근거)를 Dynamic Workflow 서브에이전트로 병렬 팬아웃, findings를 `.forge/review.md`에 기록. **리뷰 대상은 활성 슬롯 작업 전용**(parked `executed/<slug>/`는 대상 아님 — 원하면 fg-run unpark로 활성 슬롯에 올린 뒤 리뷰). 사람 승인 시 fix-needed를 fix-forward plan으로 만들어 재실행. 선택적이며 봉인 게이트가 아니고 무인 주행에선 항상 자동 skip(ADR-0018, ADR-0007과 보완 관계).
- **fg-merge** (`skills/fg-merge/SKILL.md`) — `git merge` 뒤 비-기본 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합(ADR 번호 재부여·교차참조 갱신·retro 이동·CONTEXT 병합·done 합침·브랜치 폴더 제거). git 조작은 안 함(ADR-0011).
- **fg-cleanup** (`skills/fg-cleanup/SKILL.md`) — 오래된/대체된 ADR을 활성 결정 집합에서 은퇴(`.forge/adr/retired/<NNNN>-slug.md`로 이동, supersede 마킹). 번호 불변·재사용 금지·삭제 안 함. fg-ask는 retired/를 정답소스로 안 읽음(ADR-0012).
- **fg-tdd** (`skills/fg-tdd/SKILL.md`) — 영속 TDD 모드 토글(`.forge/config.json`의 `tdd`). fg-ask가 작업마다 기본 답으로 묻고, plan의 `<!-- tdd: on -->`이면 fg-run이 test-first 실행(ADR-0008).
- **fg-eco** (`skills/fg-eco/SKILL.md`) — 위임 모델 티어링 토글(`.forge/config.json`의 `eco`). 켜면 fg-run이 위임 워크플로우 서브에이전트를 sonnet으로 캡(내리기만, 세션 모델 불변; ADR-0014).
- **fg-statusline** (`skills/fg-statusline/SKILL.md`) — 자기완결 bash 조각 스크립트(`scripts/forge-statusline.sh`)를 설치하고 `settings.json`에 연결해 statusline에 루프 진행 상태(활성 작업·단계, goal-loop 인디케이터, 백로그 수) 한 줄을 표시. Claude Code는 statusLine을 하나만 허용하므로 기존 statusLine을 대체하지 않고 자동 래핑(`scripts/forge-statusline-wrapper.sh`)해 추가 행으로 붙인다(ADR-0017).

## State contract (volatile `.forge/` state — git-untracked)

스킬을 편집할 때 이 입출력 계약을 깨지 않아야 흐름이 이어진다. 입력 파일이 없으면 각 스킬은 앞 단계를 안내한다.

| 파일 | 생산자 | 소비자 |
| --- | --- | --- |
| `.forge/backlog/<slug>.md` | fg-ask | fg-run(선택 메뉴·승격) |
| `.forge/plan.md` (활성 슬롯) | fg-run(백로그에서 승격) | fg-run(정답 기준), fg-learn, fg-adversarial-review |
| `.forge/run.md` | fg-run | fg-learn, fg-adversarial-review |
| `.forge/review.md` (활성 슬롯 전용, 선택적) | fg-adversarial-review | fg-learn(retro 승급), fg-done(봉인 시 done/ 아카이브) |
| `.forge/STATUS.md` (활성 슬롯, `status: executed`, `verified: pending`) | fg-run(run.md 직후 작성, 핸드오프 UAT로 `verified:` 기록) | fg-run(검증 재진입)·fg-learn(통과 시 회고)·fg-done(검증→회고 게이트 후 `status: done` 마감) |
| `.forge/executed/<slug>/` (+`STATUS.md`) | fg-run("모두 실행" park) | fg-learn(회고 대기), fg-done(봉인) |
| `.forge/done/<날짜-slug>/` (+`STATUS.md`, `status: done`) | fg-done | fg-ask(slug 충돌)·fg-run(완료 판별)·fg-learn(회고 제외)·fg-done(이중 봉인 방지) |
| `.forge/loop.md` (goal 계약) | fg-loop | fg-loop(재개·멤버십 필터)·fg-status·fg-ask(벽 경고)·fg-next(all 양보)·fg-merge(in-flight halt) |
| `.forge/quick/LOG.md` | fg-quick | (없음 — 한 줄 로그) |

핵심 불변식:
- **활성 슬롯은 항상 1개** — 한 plan.md = 한 run.md = 한 봉인. 백로그는 미실행 대기열, `executed/`는 "실행됐으나 미회고"의 명시 상태. plan 첫 줄 `<!-- forge-slug: ... -->`가 회고·봉인 짝 맞춤 식별자(파일 이동에도 영속).
- **활성 슬롯·백로그·executed가 모두 비면 = 진행 중 작업 없음.** fg-run은 빈 상태에서 실행 안 함(재실행 방지). fg-done이 봉인하며 비운다.
- **STATUS.md는 동반 마커**(이중 장부 아님). 상태 원천은 파일 위치이고 STATUS.md는 plan/run과 함께 활성 슬롯→`executed/`→`done/`을 따라 이동. 완료 판별 = `done/*/STATUS.md`의 `status: done`.
- **`.forge/review.md`는 활성 슬롯 전용 휘발 파일이다.** parked `executed/<slug>/`에는 review.md를 두지 않는다(per-task `executed/<slug>/review.md` 저장은 기각 — ADR-0018). findings 저장처를 활성 슬롯 한 작업에 모호함 없이 묶기 위함. 봉인 시 fg-done이 done/으로 아카이브.

### Seal gates: verify → learn → done (ADR-0009)

봉인 전 검증 게이트가 핵심이다. 루프 순서는 `run → verify → [adversarial-review optional] → learn → done`. fg-run 핸드오프가 plan 목표에 대고 UAT를 수행해 STATUS `verified:`를 기록한다.

- **봉인 가능** — `yes` / `skipped (사유)` / `n/a (사유)`.
- **차단** — `pending`(미검증) / `failed (사유)`(검증했으나 깨짐).
- fg-done은 **검증 게이트를 회고 게이트보다 먼저** 확인하고(no-seal-without-verification), 봉인 가능 값이 아니면 봉인하지 않는다.
- `pending` → fg-run 검증 전용 재진입(재실행 없이 UAT만). `failed` → fg-run의 parked-failed 회수(executed/→active slot unpark)·fix-and-re-run 또는 fg-ask 재그릴. `failed`은 fresh re-run으로 봉인 가능 값에 재검증될 때만 봉인(waiver 불가).
- ADR-0009 이전 봉인 작업은 `verified: n/a (legacy pre-ADR-0009)`로 백필됨.

```
run → STATUS verified:?
   ├── yes / skipped / n/a ──▶ (게이트 통과) learn → done(봉인)
   ├── pending ─────────────▶ fg-run 검증 재진입(UAT만)
   └── failed ──────────────▶ fg-run unpark fix-and-re-run | fg-ask 재그릴
```

**`reviewed:` 필드(fg-adversarial-review가 활성 슬롯 STATUS.md에 기록)는 봉인 게이트가 아니다 — 기록용일 뿐.** 게이트는 `verified:`와 회고 둘뿐. `reviewed:` 값은 `.forge/review.md (N findings, M→fix-forward)` 또는 `skipped (사유)` 또는 없음.

### Retro skip (ADR-0002)

회고는 저-divergence 사소한 작업에 한해 건너뛸 수 있다(기본값은 회고). run.md의 계획↔실제 차이가 없거나 미미할 때만 fg-run 핸드오프가 "회고 / 건너뛰기"를 제시하고, 건너뛰면 STATUS의 `retro:`에 `skipped (사유)` 기록(회고 파일 없음). fg-done 봉인 가드는 회고 파일 존재 **또는** `retro: skipped`를 통과 조건으로 인정한다.

## Persistent document model (`.forge/` interior — git-tracked)

휘발 상태와 같은 `.forge/` 지붕 아래 있지만 이들은 **영속이며 루프의 "연료"**다. `.gitignore`가 `.forge/*`를 기본 제외하되 영속 문서만 화이트리스트로 되살려 추적한다(`!.forge/CONTEXT.md` · `!.forge/adr/` · `!.forge/retro/` · `!.forge/codebase/` · `!.forge/config.json` · `!.forge/branch/`). 구분은 위치가 아니라 git 추적 여부. 전부 lazy 생성.

- **`.forge/CONTEXT.md`** / 루트 `CONTEXT-MAP.md`(멀티 컨텍스트) — 도메인 글로서리. 용어만, 구현 세부 금지. fg-ask가 그릴링 중 인라인 갱신. 멀티 컨텍스트만 예외(컨텍스트별 `CONTEXT.md`는 `src/<context>/`에, `CONTEXT-MAP.md`는 루트에).
- **`.forge/adr/NNNN-slug.md`** — 아키텍처 결정. 세 조건(되돌리기 어렵다/맥락 없이 의아하다/진짜 트레이드오프) 모두 충족 시에만. 현재 활성 ADR은 `0001`~`0018`(`.forge/adr/`), 은퇴 ADR은 `.forge/adr/retired/`.
- **`.forge/retro/YYYY-MM-DD-slug.md`** — 세션 회고 로그. 승급 바를 못 넘는 학습의 종착지.
- **`.forge/codebase/*.md`** — fg-map이 생성하는 코드베이스 지도. fg-ask가 그릴링 전 읽어 context rot을 줄인다(이 문서가 그 일부).

형식 정의는 한 벌만 존재하며 소유 스킬 디렉터리에 둔다 — `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`(생산자는 fg-ask지만 소비자 쪽에 둠), `skills/fg-learn/RETRO-FORMAT.md`. 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`로 참조하고 자체 복사하지 않는다.

## Branch-isolated forge root (ADR-0011)

위 표·설명의 모든 `.forge/...` 경로는 **해석된 forge 루트 기준**이다. 단일 정의는 `skills/fg-run/FORGE-ROOT.md`이며 모든 루프 스킬이 이를 참조한다(복붙 금지).

- **해석 규칙** — 현재 브랜치(`git rev-parse --abbrev-ref HEAD`)가 기본 브랜치(`config.json`의 `defaultBranch`, 없으면 `main`)면 루트는 `.forge/`, 그 외 브랜치면 `.forge/branch/<branch>/`. detached HEAD·비-git이면 `.forge/`로 폴백+한 줄 경고. 슬래시 포함 브랜치명은 중첩 디렉터리(`.forge/branch/feature/x/`).
- **전역 예외 2개** — `.forge/config.json`(부트스트랩 역설 회피: 이 규칙이 읽어야 함)·`.forge/codebase/`(공유 참조 연료)는 모든 브랜치에서 항상 최상위 `.forge/`.
- **추적 비대칭** — 기본 브랜치의 휘발 상태는 gitignored, 비-기본 브랜치의 루트는 통째로 git 추적(`.gitignore`가 `!.forge/branch/`로 화이트리스트). 경로가 브랜치별 네임스페이스되어 두 브랜치가 같은 파일을 안 건드리므로 머지 충돌이 없다.
- **읽기 오버레이** — 비-기본 브랜치에서 영속 그릴링 연료(`CONTEXT.md`·`adr/`·`retro/`) 읽기는 브랜치 루트를 최상위 `.forge/` 위에 오버레이(둘 다 읽고 브랜치가 충돌 시 우선). 쓰기는 브랜치 루트에만. ADR 번호는 브랜치 루트 `max+1`(fg-merge가 통합 시 재부여).
- **통합** — `git merge` 뒤 fg-merge가 `.forge/`에 통합(git 조작 없음).

## Design principles (two pillars)

스킬을 수정할 때 이 둘을 깨면 forge가 forge가 아니게 된다:

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** 워크플로우는 실행 중 사용자 입력을 못 받는다. 한 질문씩 주고받는 그릴링(fg-ask)은 반드시 워크플로우 밖 대화로. (fg-adversarial-review는 사용자 입력 없는 자동 분석이라 워크플로우 사용이 이 기둥에 걸리지 않는다 — findings 판단·수정 승인만 워크플로우 후 핸드오프에서.)
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다. fg-quick은 trivial 작업에 한해 이 기둥을 의도적으로 완화한 차선.

## Entry points

- **새 작업 시작** → `fg-ask`(루프 진입점). trivial이면 `fg-quick`.
- **상태 모름·콜드 재진입** → `fg-next`("다음 것 그냥 해줘") 또는 읽기 전용 `fg-status`.
- **goal 충족까지 무인 주행** → `fg-loop`.
- **설치** — `/plugin marketplace add gyuha/forge` → `/plugin install forge@forge`. 설치는 GitHub 기본 브랜치(main)를 당기므로 설치 테스트하려면 main에 push되어 있어야 한다.
