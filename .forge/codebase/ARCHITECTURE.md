---
last_mapped_commit: 553484ae395d6ca3df973f5b0cf5762029fd94ec
mapped: 2026-07-20
---

# ARCHITECTURE

## 무엇을 빌드하는가 (패턴)

이 리포는 코드를 빌드하지 않는다. **Claude Code 플러그인**이자 그 자신이 곧 **마켓플레이스**인 단일 리포다(`harness` 플러그인과 동일 패턴). 산출물은 전부 Markdown(`SKILL.md`, `*-FORMAT.md`, 규율 문서)과 JSON(매니페스트), 그리고 결정론 로직을 담는 셸/노드 스크립트다. 빌드·테스트·린트·CI 파이프라인은 없다 — `package.json`·`Makefile` 없음. "개발"은 Markdown/JSON/스크립트를 편집하는 것이고, 유일한 자동 검증은 매니페스트 JSON 파싱과 `scripts/*.test.sh`뿐이다.

플러그인 루트 = 리포 루트다. `.claude-plugin/plugin.json`이 플러그인 매니페스트, `.claude-plugin/marketplace.json`이 이 리포를 마켓플레이스로 등록한다(`plugins[].source: "./"`). 스킬은 `skills/<name>/SKILL.md`로 **자동 탐색**되며, `plugin.json`에 `skills` 필드는 없다. 스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name:`이다.

## 핵심 아키텍처 — forge 루프 (4단계)

forge의 본질은 작업 하나를 한 바퀴 돌리는 4단계 루프다. 각 스킬은 **독립 실행**되며, 상태를 `.forge/` 파일로 주고받아 흐름을 잇는다(스킬끼리 직접 호출하지 않음 — 상태 파일이 유일한 결합면).

```
fg-ask(①질의·계획·그릴링) → fg-run(②실행) → fg-learn(③회고) → fg-done(④완료·봉인) → (새 작업) fg-ask
```

- `fg-ask` — grill-with-docs식 대화형 그릴링. 반드시 **본 세션 대화**로 진행(워크플로 밖). 산출: `.forge/backlog/<slug>.md`.
- `fg-run` — 백로그 plan을 활성 슬롯(`.forge/plan.md`)으로 승격해 Claude Code Dynamic Workflow로 실행. 계획↔실제 차이를 `.forge/run.md`에, 상태를 `.forge/STATUS.md`에 기록.
- `fg-learn` — 학습을 분류·승급(CONTEXT/ADR/retro). 항상 대화형.
- `fg-done` — 봉인·재실행 방지. 기계적 봉인은 결정론 스크립트가 처리.

## 데이터 흐름 — `.forge/` 상태 계약 (생산자/소비자)

스킬 간 결합은 오직 `.forge/` 파일의 입출력 계약으로 이뤄진다. 아래 경로는 모두 **해석된 forge 루트 기준**(브랜치 격리 절 참고).

| 파일 | 생산자 | 소비자 |
| --- | --- | --- |
| `.forge/ask.md` (표시용 마커) | fg-ask | fg-statusline(표시 전용) |
| `.forge/backlog/<slug>.md` | fg-ask | fg-run(선택·승격) |
| `.forge/plan.md` (활성 슬롯) | fg-run(백로그에서 승격) | fg-run·fg-learn |
| `.forge/run.md` | fg-run | fg-learn |
| `.forge/review.md` (적대적 리뷰 findings, 선택·비-게이트) | fg-adversarial-review | fg-learn·fg-done(아카이브) |
| `.forge/STATUS.md` (동반 마커) | fg-run | fg-run·fg-learn·fg-done |
| `.forge/executed/<slug>/` | fg-run(Run all park) | fg-learn·fg-done |
| `.forge/done/<날짜-slug>/` | fg-done | fg-ask(slug 충돌)·fg-run·fg-learn·fg-done |
| `.forge/loop.md` (goal 계약) | fg-loop | fg-loop·fg-status·fg-ask·fg-next·fg-merge |
| `.forge/quick/LOG.md` (경량 차선 로그) | fg-quick | (읽기 참조) |

## 상태 머신 — 활성 슬롯 / 백로그 / executed / done

작업의 상태 원천은 **파일 위치**이며, `STATUS.md`는 작업 파일과 함께 이동하는 동반 마커다(이중 장부 아님).

```
fg-ask ──> backlog/<slug>.md
                │ fg-run 승격
                v
          plan.md (활성 슬롯 — 항상 1개) ──> run.md + STATUS.md(status: executed, verified: pending, retro: pending)
                │                                  │ Run all: 파킹
                │ (단일 작업)                       v
                │                            executed/<slug>/ (실행됐으나 미회고)
                │                                  │
                v                                  v
          [검증 게이트] ─fail─> fg-run unpark(fix & re-run) 또는 fg-ask 재그릴
                │ verified: yes/skipped/n/a
                v
          fg-learn(회고) ──> retro/ 승급 (또는 retro: skipped)
                │
                v
          fg-done ──> done/<날짜-slug>/ (status: done) + 활성 .forge 비움 = 루프 닫힘
```

- **활성 슬롯은 항상 1개**: 한 `plan.md` = 한 `run.md` = 한 봉인. plan 첫 줄 `<!-- forge-slug: ... -->` 주석이 회고·봉인의 짝 맞춤 식별자(파일 이동에도 영속).
- **활성 슬롯·백로그·executed가 모두 비어 있으면 = 진행 중 작업 없음.** fg-run은 빈 상태에서 실행하지 않는다(재실행 방지). 완료 판별 = `done/*/STATUS.md`의 `status: done`.

## 봉인 전 검증 게이트 (ADR-0009)

루프 순서는 **run → verify → learn → done**. fg-run 핸드오프가 plan 목표에 대고 UAT를 수행해 STATUS `verified:`를 기록한다.

- **봉인 가능**: `yes` / `skipped (사유)` / `n/a (사유)`
- **차단**: `pending`(미검증 — fg-run 검증 전용 재진입으로) / `failed (사유)`(검증했으나 깨짐 — fg-run parked-failed 회수·fix-and-re-run 또는 fg-ask 재그릴로 라우팅)

fg-done은 **검증 게이트를 회고 게이트보다 먼저** 확인한다(no-seal-without-verification). `failed`는 waiver로 통과시키지 않고 fresh re-run 재검증으로만 봉인된다. ADR-0009 이전 봉인은 `verified: n/a (legacy pre-ADR-0009)`로 백필. 회고는 저-divergence 사소한 작업에 한해 skip 가능(ADR-0002) — `retro: skipped (사유)`가 봉인 가드를 통과.

## 브랜치 격리 forge 루트 (ADR-0011)

모든 `.forge/...` 경로는 **해석된 forge 루트** 기준이다.

- 기본 브랜치(`config.json`의 `defaultBranch`, 없으면 `main`) → 루트 = `.forge/`
- 그 외 브랜치 → 루트 = `.forge/branch/<branch>/` (예: 현재 `feature/visual-compose` → `.forge/branch/feature/visual-compose/`)
- **전역 예외**(모든 브랜치에서 항상 최상위 `.forge/`): `.forge/config.json`, `.forge/codebase/`, 그리고 `.forge/visual/`(fg-visual 세션, 휘발·gitignore).

비-기본 브랜치의 루트는 **통째로 git 추적**된다(`.gitignore`가 `!.forge/branch/`로 화이트리스트). 경로가 브랜치별로 네임스페이스되어 두 브랜치가 같은 파일을 안 건드리므로 git merge 충돌이 없고, `git merge` 뒤 fg-merge가 `.forge/`로 통합한다. 단일 정의는 `skills/fg-run/FORGE-ROOT.md`이고, 런타임 해석은 결정론 스크립트 `scripts/resolve-forge-root.sh`/`.js`가 담당(git 리포 루트에 앵커, `config.json` 파싱, 항상 exit 0).

## 스크립트 백킹 — 결정론 봉인·상태·머지·건강 (ADR-0022·0030·0031)

기계적(비-AI) 작업은 셸+노드 **트윈 스크립트**로 백킹한다. 스킬은 exit code로 라우팅만 하고 의미 판단만 대화로 남긴다. 각 스크립트는 `.sh`(bash 프라이머리) + `.js`(node 폴백)의 dual dispatch이며, `.test.sh`(동작)와 `.parity.test.sh`(sh/js 동치)를 동반한다.

- `scripts/forge-done.sh` / `.js` — 봉인(사전점검·게이트 강제·STATUS 마감·아카이브·슬롯 비우기), 세 봉인 경로 공유·게이트-우선-비파괴 (ADR-0030).
- `scripts/forge-status.sh` / `.js` — 읽기 전용 상태 리포트 + 다음 단계 상태 머신 (ADR-0020).
- `scripts/forge-merge.sh` / `.js` — 브랜치 forge 통합(시간ID ADR 이동·task 번호 재부여·retro 이동·CONTEXT 병합·done 합침·폴더 제거). **git 조작 안 함**(CI git-free); `fg-merge <branch>` 인자 모드만 스킬 계층에서 `git merge`를 대신 돌림.
- `scripts/forge-doctor.sh` / `.js` — 상태·문서 무결성 health check, exit 0/1/2로 AI-free CI 게이트 (ADR-0019).
- `scripts/forge-statusline.sh` / `.js` — statusline forge fragment(방법 1 append용).
- `scripts/forge-statusline-full.sh` / `.js` — daleseo식 통합 statusline(방법 2 merge), forge 부분은 fragment에 위임(3중 복제 금지, ADR-0029).
- `scripts/forge-statusline-wrapper.sh` — 기존 statusline을 별도 줄로 래핑(원본 보존, ADR-0017).
- `scripts/resolve-forge-root.sh` / `.js` — forge 루트 해석.

## 단일 정의·복붙 금지 규약 (형식·규율 문서)

형식/규율 문서는 한 벌만 존재하며 소유 스킬 디렉터리에 둔다. 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(상대경로 `../fg-ask/` 등)로 **참조**하고 자체 복사하지 않는다. 루트 `references/` 디렉터리는 **폐지됨**.

- `skills/fg-ask/CONTEXT-FORMAT.md` · `skills/fg-ask/ADR-FORMAT.md` — grill-with-docs 원본 형식.
- `skills/fg-run/PLAN-FORMAT.md` — plan.md 형식 + 분할 규칙(생산자는 fg-ask지만 소비자 쪽에 둠).
- `skills/fg-run/RUN-ALL.md` — Run all 배치 규율.
- `skills/fg-run/FORGE-ROOT.md` — forge 루트 해석 규율(모든 루프 스킬 참조, ADR-0011).
- `skills/fg-learn/RETRO-FORMAT.md` — 회고 형식.
- `skills/fg-next/DRIVE.md` — 무인 주행 규율(fg-next `all`·fg-loop이 참조, 각자 자기 벽 집합 채움, ADR-0028).
- `skills/fg-eco/ECO.md` — Eco laziness-first 규율(독립 스킬 없이 fg-eco에만 살며 eco가 유일한 활성화 경로, ADR-0014).
- `skills/fg-visual/VISUAL.md` + `skills/fg-visual/scripts/` — Visual Companion 정의(fg-ask가 파일 참조로 사용).

## 설계 원칙 (두 기둥 — 깨면 forge가 아니게 됨)

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** 워크플로는 실행 중 사용자 입력을 못 받는다. 한 질문씩 주고받는 그릴링(fg-ask)은 반드시 워크플로 밖 대화로.
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.

핸드오프 규약: 각 스킬은 끝에서 "방금 한 것 / 다음 단계 / 시작하는 법"을 대화체 **진술형**으로 전하고 멈춘다("진행할까요?"로 묻지 않음). 체이닝(동의 시 다음 스킬 자동 호출)은 **fg-next 전담**(단 fg-learn→fg-done 자동 체인은 ADR-0026 예외).

## 진입점 (entry points)

**루프 4단계 스킬:**
- `skills/fg-ask/SKILL.md` (①)
- `skills/fg-run/SKILL.md` (②)
- `skills/fg-learn/SKILL.md` (③)
- `skills/fg-done/SKILL.md` (④, `fg-done all` 배치 봉인 — ADR-0023)

**루프 밖 유틸리티 스킬(15개):**
- `skills/fg-map/SKILL.md` — 코드베이스 지도(병렬 서브에이전트 → `.forge/codebase/`). **이 문서를 생성하는 스킬.**
- `skills/fg-status/SKILL.md` — 읽기 전용 상태 리포터(보고만).
- `skills/fg-next/SKILL.md` — 다음 단계 오케스트레이터(행동까지, `all` 무인 주행 — ADR-0010).
- `skills/fg-loop/SKILL.md` — goal 주도 한정 재계획 루프(ADR-0016).
- `skills/fg-merge/SKILL.md` — 브랜치 forge 통합(ADR-0011·260717-10a).
- `skills/fg-cleanup/SKILL.md` — ADR 은퇴(→ `.forge/adr/retired/`, ADR-0012).
- `skills/fg-quick/SKILL.md` — 경량 차선(형식 산출물 없음, ADR-0003).
- `skills/fg-doctor/SKILL.md` — 무결성 health check(ADR-0019).
- `skills/fg-drop/SKILL.md` — 미완 작업 폐기(ADR-0021).
- `skills/fg-agents/SKILL.md` — 도메인 에이전트 카드 생성(→ `.claude/agents/`, ADR-0024).
- `skills/fg-tdd/SKILL.md` — TDD 모드 토글(`config.json`, ADR-0008).
- `skills/fg-eco/SKILL.md` — eco 모드 토글(`config.json`, ADR-0014).
- `skills/fg-adversarial-review/SKILL.md` — 선택적 적대적 리뷰(ADR-0018).
- `skills/fg-statusline/SKILL.md` — statusline 설정(ADR-0017·0029).
- `skills/fg-visual/SKILL.md` — 브라우저 시각 컴패니언(ADR 260719-224442).

**스크립트 트윈 진입점:** `scripts/forge-done.{sh,js}` · `scripts/forge-status.{sh,js}` · `scripts/forge-merge.{sh,js}` · `scripts/forge-doctor.{sh,js}` · `scripts/forge-statusline.{sh,js}` · `scripts/forge-statusline-full.{sh,js}` · `scripts/forge-statusline-wrapper.sh` · `scripts/resolve-forge-root.{sh,js}` (각 `*.test.sh`·`*.parity.test.sh` 동반).

**fg-visual 런타임:** `skills/fg-visual/scripts/server.cjs`(zero-dependency Node 서버) · `start-server.sh` · `stop-server.sh` · `helper.js` · `frame-template.html`.

**매니페스트:** `.claude-plugin/plugin.json`(플러그인) · `.claude-plugin/marketplace.json`(마켓플레이스). 스킬 개수·설명은 두 파일을 함께 갱신(둘 다 사람이 읽는 설명). 설치는 GitHub 기본 브랜치(main)를 당긴다.
