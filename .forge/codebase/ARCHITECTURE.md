---
last_mapped_commit: d3c47b5bdc859af54e741f0524f9ed8ce2b61483
mapped: 2026-06-14
---

# forge 아키텍처

## 무엇인가

forge는 Claude Code 플러그인이다 — 실행 산출물을 빌드하지 않고 `fg-*` 워크플로우 스킬을 패키징한다. 거의 전부가 Markdown(`SKILL.md`, `*-FORMAT.md`)과 JSON(매니페스트)이다. 빌드·CI·패키지 매니저는 없다. **단, 이번에 처음으로 실행 코드와 테스트 인프라가 추가됐다** — `scripts/forge-statusline.sh`(bash)와 `scripts/forge-statusline.test.sh`(fixture 기반 bash 테스트). 이는 두 설계 기둥의 의도적·경계 있는 예외다(ADR-0017).

스킬은 총 **14개**다(`skills/` 디렉터리 13개 → 이번에 `fg-statusline` 추가로 14개). 식별자는 디렉터리명이 아니라 `SKILL.md` frontmatter의 `name`이며, `.claude-plugin/plugin.json`이 `skills/`를 자동 탐색한다.

## 핵심 — forge 루프

forge의 본질은 작업 하나를 한 바퀴 돌리는 4단계 루프다. 각 스킬은 독립 실행되며 상태를 `.forge/` 파일로 주고받아 흐름을 잇는다. 입력 파일이 없으면 각 스킬은 앞 단계를 안내한다.

```
fg-ask (①질의·계획·그릴링) → fg-run (②실행) → fg-learn (③회고) → fg-done (④완료) → (새 작업) fg-ask
```

- **fg-ask** (`skills/fg-ask/SKILL.md`) — grill-with-docs식 대화형 그릴링. 계획을 도메인·용어·결정에 대고 검증해 `.forge/backlog/<slug>.md`로 적재. 반드시 본 세션 대화로 진행(워크플로우 밖). grill-with-docs 원본의 자기완결 3파일 구성(`SKILL.md` + `CONTEXT-FORMAT.md`/`ADR-FORMAT.md`, 영문 verbatim 본문 + 맨 아래 "Forge integration" 섹션).
- **fg-run** (`skills/fg-run/SKILL.md`) — 백로그에서 plan을 활성 슬롯으로 승격해 Claude Code Dynamic Workflow로 실행, 계획↔실제 차이를 `.forge/run.md`에 기록. 백로그에 미실행 plan이 정확히 1개면 확인 질문 없이 즉시 실행, 여러 개면 가이드 다이얼로그(마지막 옵션 'Run all')를 제시. `RUN-ALL.md`에 배치 실행 규약, `PLAN-FORMAT.md`에 plan 형식·분할 규칙.
- **fg-learn** (`skills/fg-learn/SKILL.md`) — 학습을 분류해 영속 문서(CONTEXT.md·ADR)로 승급, `.forge/retro/`에 회고 남김. 항상 대화형. `RETRO-FORMAT.md`가 회고 형식 정의.
- **fg-done** (`skills/fg-done/SKILL.md`) — 루프의 ④완료(봉인) 단계. 회고 확인 → `STATUS.md`를 `done`으로 마감 → 작업을 `.forge/done/<날짜-slug>/`로 봉인 → 활성 `.forge/`를 비워 루프를 닫음. **재실행 방지의 핵심 메커니즘**.

### 루프 밖 스킬 (10개)

이 4단계에 속하지 않는 온디맨드 유틸리티/오케스트레이터:

- **fg-map** — 코드베이스를 병렬 서브에이전트로 `.forge/codebase/`에 지도화(context rot 감소).
- **fg-quick** — 사소한 작업용 경량 차선. 그릴링은 유지(기둥 1)하되 형식 산출물(ADR·plan/run/STATUS·done·회고) 없이 `.forge/quick/LOG.md`에 한 줄만 기록 후 직접 실행. 메인 루프 상태와 격리. 비-trivial로 드러나면 fg-ask로 bail. 기둥 2의 의도적 완화(ADR-0003).
- **fg-status** — 읽기 전용 상태 리포터. `.forge/`를 조사해 현황 + 다음 단계 하나를 출력. 아무것도 쓰지 않고 자동 실행 안 함. **다음-단계 상태 머신의 단일 정의처.**
- **fg-next** — fg-status의 상태 머신을 재사용해 다음 단계 하나를 도출, 한 줄 알린 뒤 그 스킬을 곧바로 실행하는 오케스트레이터(보고만 하는 fg-status와 달리 행동까지). 기본 one-shot, `all` 모드는 백로그가 빌 때까지 선형 기계적 단계를 자동 진행하며 회고는 항상 자동 skip, 대화의 벽에서만 정지(ADR-0010). 자체로는 아무것도 안 쓰고 위임 스킬이 전부 씀.
- **fg-loop** — goal 주도 한정 재계획 루프. 기초 질의(대화)로 기계 검증 가능한 정지 체크·승인된 fix-forward 재계획 범위·상한(기본 3라운드)을 `.forge/loop.md`에 못 박고 초기 백로그를 적재한 뒤, 체크 전부 통과까지 run→UAT→회고 자동 skip→봉인을 무인 주행(소프트 결정점마다 추천/기본값 자동 선택, 사용자에게 묻지 않음). 벽에서만 정지(검증불가 UAT·진짜 fork·상한 소진·무진전). `## Tasks` 멤버십 목록 등재 slug만 승격. 기둥 1의 의도적·경계 있는 완화(ADR-0016).
- **fg-tdd** — 영속 TDD 모드 토글(`.forge/config.json`의 `tdd`; ADR-0008).
- **fg-eco** — 위임 모델 티어링 토글(`.forge/config.json`의 `eco`; 켜면 fg-run이 위임 서브에이전트를 sonnet으로 캡, 내리기만·세션 모델 불변; ADR-0014).
- **fg-merge** — `git merge` 뒤 비-기본 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합(ADR 번호 재부여+교차참조 갱신·retro 이동·CONTEXT 병합·done 합침·브랜치 폴더 제거). git 조작은 안 함(ADR-0011).
- **fg-cleanup** — 오래된/대체된 ADR을 활성 결정 집합에서 은퇴(`.forge/adr/retired/<NNNN>-slug.md`로 이동+supersede 마킹, 번호 불변·재사용 금지·삭제 안 함; ADR-0012).
- **fg-statusline** — **신규**. 아래 별도 절 참조.

## fg-statusline와 statusline 스크립트 (신규, ADR-0017)

`fg-statusline`은 루프 밖 일회성 설정 유틸리티다. forge 상태를 터미널 statusline에 띄우기 위해 자기완결 bash 조각 스크립트를 설치하고 사용자 `settings.json`에 배선한다.

**왜 스크립트인가 (플러그인 컴포넌트로 불가능한 이유):** Claude Code의 statusLine은 플러그인이 직접 등록할 수 없고 `settings.json`의 `statusLine` 키로만 설정되며, 명령은 stdin JSON을 받아 텍스트를 뱉는 비대화형 셸이라 Markdown 스킬(fg-status)을 호출할 수 없다. 또 `${CLAUDE_PLUGIN_ROOT}`가 statusLine 셸에 없고 플러그인 설치 경로는 업데이트마다 바뀐다(`~/.claude/plugins/cache/<hash>/`). 그래서 `.forge/`를 직접 읽는 실제 bash 스크립트가 필요하고, 안정 경로 `~/.claude/forge-statusline.sh`로 복사해 settings가 참조한다. 조각은 cwd 기준이라 글로벌 사본 하나가 모든 프로젝트를 서빙한다.

**스크립트 동작** (`scripts/forge-statusline.sh`): bash+git만 의존(node·jq 없음). cwd 기준으로 forge 루트(ADR-0011 브랜치 해석)를 풀어 `loop.md`·활성 슬롯(`plan.md`/`run.md`/`STATUS.md`)·`executed/`·`backlog/`를 읽고 단일 세그먼트 한 줄을 우선순위(active > executed > backlog) 순으로 출력한다. STATUS.md의 `verified:` 값을 플래그로 매핑(`✓`/`⏳`/`✗`/생략). idle이면 아무것도 출력 안 함(exit 0). JSON 파싱 없이 `sed`로 `key: value` 줄을 읽는다.

**설치 로직** (`skills/fg-statusline/SKILL.md`): 조각을 `~/.claude/forge-statusline.sh`로 복사(chmod +x, 재실행 시 idempotent 갱신=refresh) → 편집할 `settings.json` 결정(기존 statusLine 보유 파일 우선, 없으면 사용자 settings) → 분기: 기존 statusLine 없음=직접 설정 / 이미 forge 래퍼=중복 방지 후 보고만 / 다른 명령 존재=auto-wrap. **auto-wrap**은 Claude Code가 statusLine을 동시에 하나만 허용하므로 기존 명령을 대체하지 않고 `~/.claude/forge-statusline-wrapper.sh` 래퍼로 감싸 원래 출력 아래 별도 줄로 forge 조각을 덧붙인다(stdin을 양쪽에 흘려보냄, 조각이 비면 빈 줄 안 붙임).

**아키텍처적으로 주목할 이중성:** statusline 스크립트는 forge 상태의 **얇은·표시 전용 두 번째 판독자**이고, `skills/fg-status/SKILL.md`는 다음-단계 상태 머신의 **단일 정의처**로 남는다. 즉 forge 상태 머신이 두 곳에 존재한다 — fg-status(정본·"다음에 뭘 할지")와 스크립트(표시본·"지금 어디인지"). 스크립트는 우선순위 머신을 재현하지 않고 bucket→stage 매핑만 fg-status의 task 테이블과 동형으로 복제한다. **이 매핑이 바뀌면 양쪽(스크립트 + fg-status)을 같이 고쳐야 한다** — 의도적이지만 드리프트 위험이 있는 결합이다. 테스트(`scripts/forge-statusline.test.sh`)는 임시 디렉터리에 가짜 `.forge/` 상태를 만들고 출력 한 줄을 기대값과 비교한다.

## 상태 계약 (`.forge/`의 휘발 상태 — git 미추적)

스킬을 편집할 때 이 입출력 계약을 깨지 않아야 흐름이 이어진다.

| 파일 | 생산자 | 소비자 |
| --- | --- | --- |
| `.forge/backlog/<slug>.md` | fg-ask | fg-run(선택 메뉴·승격) |
| `.forge/plan.md` (활성 슬롯) | fg-run(백로그에서 승격) | fg-run(정답 기준), fg-learn |
| `.forge/run.md` | fg-run | fg-learn |
| `.forge/STATUS.md` (활성 슬롯) | fg-run | fg-run·fg-learn·fg-done |
| `.forge/executed/<slug>/` | fg-run("모두 실행" park) | fg-learn(회고 대기), fg-done(봉인) |
| `.forge/done/<날짜-slug>/` | fg-done | fg-ask(slug 충돌)·fg-run(완료 판별)·fg-learn(회고 제외)·fg-done(이중 봉인 방지) |
| `.forge/loop.md` | fg-loop | fg-loop(재개)·fg-status·fg-ask·fg-next·fg-merge·`forge-statusline.sh`(loop 인디케이터) |

**핵심 불변식:**

- **활성 슬롯은 항상 1개** — 한 `plan.md` = 한 `run.md` = 한 봉인. 백로그는 미실행 대기열, `executed/`는 "실행됐으나 미회고"의 명시적 상태. plan 첫 줄의 `<!-- forge-slug: ... -->` 주석이 회고·봉인의 짝 맞춤 식별자(파일 이동에도 영속).
- **활성 슬롯·백로그·executed가 모두 비어 있으면 = 진행 중 작업 없음.** fg-run는 빈 상태에서 실행 안 함(재실행 방지). fg-done이 봉인하며 비운다.
- **STATUS.md는 동반 마커**(이중 장부 아님). 상태 원천은 파일 위치이고 STATUS.md는 plan/run과 함께 활성 슬롯→`executed/`→`done/`을 따라 이동. fg-run가 `status: executed`(+`verified: pending`+`retro: pending`)로 만들고 fg-done이 `status: done`으로 마감. 완료 판별 = `done/*/STATUS.md`의 `status: done`.

### 봉인 전 검증 게이트 (ADR-0009)

루프 순서는 **run → verify → learn → done**. fg-run 핸드오프가 plan 목표에 대고 UAT를 수행해 STATUS `verified:`를 기록한다 — 봉인 가능 값(`yes`/`skipped (사유)`/`n/a (사유)`), 차단 값(`pending` 미검증/`failed (사유)` 검증했으나 깨짐). fg-done은 **검증 게이트를 회고 게이트보다 먼저** 확인하고(no-seal-without-verification) 봉인 가능 값이 아니면 봉인하지 않는다. `pending`은 fg-run 검증 전용 재진입, `failed`는 fg-run의 parked-failed 회수(executed/→active slot unpark)·fix-and-re-run 또는 fg-ask 재그릴로 라우팅. `failed`은 fresh re-run으로 재검증돼야만 봉인되며 waiver로 통과 불가.

### 회고 스킵 (ADR-0002)

기본값은 회고(fg-learn). run.md의 계획↔실제 차이가 없거나 미미할 때만 fg-run 핸드오프가 "회고/건너뛰기"를 명시 제시하고, 건너뛰기 선택 시 STATUS.md `retro:`에 `skipped (사유)`를 기록(회고 파일 없음). fg-done의 봉인 가드는 회고 파일 존재 **또는** `retro: skipped`를 통과 조건으로 인정. divergence가 크면 건너뛰기를 제시하지 않는다.

### 브랜치별 forge 루트 (ADR-0011)

모든 `.forge/...` 경로는 **해석된 forge 루트 기준**이다 — 기본 브랜치(`config.json`의 `defaultBranch`, 없으면 `main`)면 `.forge/`, 그 외 브랜치면 `.forge/branch/<branch>/`. 단일 정의는 `skills/fg-run/FORGE-ROOT.md`이며 모든 루프 스킬이 이를 참조한다(복붙 금지). detached HEAD·비-git이면 `.forge/`로 폴백 + 한 줄 경고. statusline 스크립트도 이 규칙을 자체 구현해 루트를 푼다(스크립트는 FORGE-ROOT.md를 참조 못 하므로 로직 복제 — 이 또한 위 이중성의 일부).

**전역 예외 2개** — `.forge/config.json`(부트스트랩 역설 방지: 이 규칙이 읽어야 하는 `defaultBranch`를 담음)와 `.forge/codebase/`(공유 지도 연료)는 모든 브랜치에서 항상 최상위 `.forge/`. 비-기본 브랜치 루트는 통째로 git 추적(`.gitignore`가 `!.forge/branch/`로 화이트리스트). 경로가 브랜치별로 네임스페이스돼 머지 충돌이 없고, `git merge` 뒤 fg-merge가 `.forge/`로 통합.

**영속 그릴링 연료 read overlay** — 비-기본 브랜치에서 `CONTEXT.md`·`adr/`·`retro/` 읽기는 브랜치 루트를 최상위 `.forge/` 위에 오버레이(둘 다 읽고 브랜치 우선). 쓰기는 브랜치 루트로만, 새 ADR 번호는 브랜치 루트 `max+1`(fg-merge가 통합 시 재부여).

## 영속 문서 모델 (`.forge/` 내부, git 추적 — 루프의 "연료")

휘발 상태와 같은 `.forge/` 지붕 아래 있지만 영속이며 루프의 연료다. `.gitignore`가 `.forge/*`로 기본 제외하되 이들만 화이트리스트로 추적(`!.forge/CONTEXT.md` · `!.forge/adr/` · `!.forge/retro/` · `!.forge/codebase/` · `!.forge/config.json` · `!.forge/branch/`). 전부 lazy 생성(쓸 내용이 생길 때만).

- `.forge/CONTEXT.md` / 루트 `CONTEXT-MAP.md`(멀티 컨텍스트) — 도메인 글로서리. fg-ask가 그릴링 중 인라인 갱신.
- `.forge/adr/NNNN-slug.md` — 아키텍처 결정. 세 조건(되돌리기 어렵다/맥락 없이 의아하다/진짜 트레이드오프) 모두 충족 시에만. 현재 0001~0017.
- `.forge/retro/YYYY-MM-DD-slug.md` — 세션 회고 로그.
- `.forge/codebase/*.md` — fg-map이 생성하는 코드베이스 지도(이 문서가 그중 하나).

형식 정의는 한 벌만 존재하며 소유 스킬 디렉터리에 둔다 — `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-learn/RETRO-FORMAT.md`. 전부 영문. 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`로 참조하고 자체 복사 안 함. 루트 `references/`는 폐지됨.

## 설계 원칙 (두 기둥)

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** 워크플로우는 실행 중 사용자 입력을 못 받는다. 한 질문씩 주고받는 그릴링(fg-ask)은 반드시 워크플로우 밖 대화로. (fg-loop은 ADR-0016의 경계 있는 완화.)
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다. (fg-quick은 ADR-0003의 trivial 한정 완화.)

두 기둥 모두 "no-code" 함의를 가졌으나, `scripts/forge-statusline.sh`+테스트는 ADR-0017이 명시한 의도적·경계 있는 예외다(forge 최초의 실행 코드·테스트 인프라).

## 핸드오프 규약

각 스킬은 끝에서 "방금 한 것 / 다음 단계 / 시작하는 법"을 자연스러운 대화체로 전한다. **전환은 진술형** — "진행할까요?"로 묻지 않고 다음 스킬·트리거를 알리고 멈춘다. 체이닝은 fg-next 전담. 예외는 fg-run 단일작업 종료뿐(4지 명시 메뉴 제시 — ADR-0015).

## 진입점 (스킬 트리거)

각 스킬 frontmatter `description`이 트리거 문맥을 정의한다. 대표 예: fg-ask("새 작업 시작"·"forge로 시작"·"계획 다듬자"), fg-run("forge run"·"계획 실행"), fg-learn("forge learn"·"회고하자"), fg-done("작업 완료"·"봉인"), fg-status("forge status"·"상태"·"어디까지 했지"), fg-next("forge next"·"다음 단계"·"이어서 해줘"), fg-loop("forge loop"·"루프 시작"), fg-statusline("forge statusline"·"상태바"·"상태 표시줄"). 전체 목록은 `.claude-plugin/plugin.json`/`marketplace.json`의 description에 집약.
