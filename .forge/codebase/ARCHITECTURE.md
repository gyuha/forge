---
last_mapped_commit: 54877b368a1025c44da1e1ca669880c2f955ac45
mapped: 2026-06-18
---

# ARCHITECTURE

forge는 코드를 빌드하는 프로젝트가 아니라 **Claude Code 플러그인**이다. 산출물은 전부 Markdown(`SKILL.md`, `*-FORMAT.md`)과 JSON 매니페스트이며, 빌드·테스트·린트 시스템이 없다. "아키텍처"란 곧 17개 `fg-*` 스킬이 `.forge/` 상태 파일을 주고받으며 짜내는 **워크플로우 설계**다. 각 스킬은 독립 실행되고(`SKILL.md`가 곧 실행 지시문), 직접적인 함수 호출이 아니라 디스크 위 파일의 존재·위치로 흐름을 잇는다.

## 핵심 — forge 루프 (4단계)

forge의 본질은 작업 하나를 한 바퀴 돌리는 4단계 루프다. 각 단계는 별개 스킬이고, 앞 단계의 산출 파일을 뒤 단계가 입력으로 읽어 사슬이 이어진다.

```
fg-ask(① 질의·계획·그릴링) → fg-run(② 실행) → fg-learn(③ 회고) → fg-done(④ 봉인) → (새 작업) fg-ask
                                  ↓ 크게 어긋나면 재그릴링        ↓ 재그릴링
                                fg-ask                          fg-ask
```

- **fg-ask** — grill-with-docs식 대화형 그릴링. 계획을 도메인·용어·결정에 대고 검증해 `.forge/backlog/<slug>.md`로 적재. 반드시 본 세션 대화로 진행(워크플로우 밖).
- **fg-run** — 백로그/활성 슬롯의 `plan.md`를 Claude Code Dynamic Workflow로 실행하고, 계획↔실제 차이를 `run.md`에 기록. 실행 직후 핸드오프에서 UAT를 수행해 `STATUS.md`의 `verified:`를 기록한다.
- **fg-learn** — 학습을 분류해 영속 문서(CONTEXT.md·ADR)로 승급하고, 승급 바를 못 넘는 학습은 `.forge/retro/`에 남긴다. 항상 대화형.
- **fg-done** — 한 바퀴의 잔여물을 정리(tidy up)하는 봉인 단계. 회고 확인 → `STATUS.md`를 `done`으로 마감 → 작업을 `.forge/done/<날짜-slug>/`로 봉인 → 활성 `.forge/` 비움. **활성 상태를 비우는 것이 같은 plan의 재실행을 막는 핵심 메커니즘**이다.

## 두 설계 기둥

이 둘을 깨면 forge가 forge가 아니게 된다.

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** 워크플로우는 실행 중 사용자 입력을 못 받는다. 한 질문씩 주고받는 그릴링(fg-ask)은 반드시 워크플로우 밖 대화로 진행한다.
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.

## 상태 계약 (`.forge/`)

스킬은 입력 파일을 `.forge/`(브랜치별로 해석됨, 아래 참조)에서 읽고 산출을 같은 곳에 쓴다. 입력 파일이 없으면 각 스킬은 앞 단계를 안내한다.

- **활성 슬롯은 항상 1개.** 한 `plan.md` = 한 `run.md` = 한 봉인. `plan.md` 첫 줄의 `<!-- forge-slug: ... -->` 주석이 회고·봉인의 짝 맞춤 식별자다(파일이 이동해도 영속).
- **세 버킷.** `backlog/<slug>.md`(미실행 plan 대기열) → 활성 슬롯(`plan.md`/`run.md`/`STATUS.md`) → `executed/<slug>/`("모두 실행" 후 회고 대기) → `done/<날짜-slug>/`(봉인 아카이브). 활성 슬롯·backlog·executed가 모두 비면 = 진행 중 작업 없음. `fg-run`는 빈 상태에서 실행하지 않는다(재실행 방지). 완료 판별은 `done/*/STATUS.md`의 `status: done`이다.
- **STATUS.md 라이프사이클.** 이중 장부가 아니라 작업 파일들과 함께 이동하는 동반 마커다(상태의 원천은 파일 위치). `fg-run`가 `status: executed`(+`verified: pending`+`retro: pending`)로 만들고, `fg-done`이 `status: done`(+`completed`/`verified`/`retro`/`docs updated`)으로 마감한 뒤 plan/run과 함께 활성 슬롯 → `executed/` → `done/`을 따라 아카이브한다.
- **봉인 전 검증 게이트 (ADR-0009).** 루프 순서는 run → verify → learn → done. fg-run 핸드오프가 plan 목표에 대고 UAT를 수행해 `verified:`를 기록한다 — 봉인 가능: `yes (증거)`/`skipped (사유)`/`n/a (사유)`, 차단: `pending`(미검증)/`failed (사유)`(검증했으나 깨짐). fg-done은 검증 게이트를 회고 게이트보다 먼저 확인하고(no-seal-without-verification), 봉인 가능 값이 아니면 봉인하지 않는다. `failed`은 fresh re-run으로 재검증돼야만 봉인되며 waiver로 통과시키지 않는다.
- **선택적 회고 스킵 (ADR-0002).** 기본값은 회고. `run.md`의 계획↔실제 divergence가 없거나 미미할 때만 fg-run 핸드오프가 "회고 / 건너뛰기"를 명시 제시하고, 건너뛰면 `STATUS.md`의 `retro: skipped (사유)`를 기록한다(회고 파일 없음). fg-done 봉인 가드는 회고 파일 존재 **또는** `retro: skipped`를 통과 조건으로 인정한다.

### 브랜치 격리된 forge 루트 (ADR-0011)

위의 모든 `.forge/...` 경로는 **해석된 forge 루트** 기준이다 — 기본 브랜치(`config.json`의 `defaultBranch`, 없으면 `main`)면 `.forge/`, 그 외 브랜치면 `.forge/branch/<branch>/`. 전역 예외 둘(`.forge/config.json`·`.forge/codebase/`)은 모든 브랜치에서 항상 최상위 `.forge/`다. 비-기본 브랜치 루트는 통째로 git 추적되어(`.gitignore`가 `!.forge/branch/`로 화이트리스트) 병렬 브랜치가 같은 파일을 안 건드린다. `git merge` 뒤 **fg-merge**가 브랜치 루트를 `.forge/`로 통합한다(ADR 번호 재부여·retro 이동·CONTEXT 병합·폴더 제거). 해석 규칙의 단일 정의는 `skills/fg-run/FORGE-ROOT.md`이며 모든 루프 스킬이 이를 참조한다(복붙 금지).

## 영속 문서 모델 (`.forge/` 내부, git 추적)

휘발 루프 상태와 같은 `.forge/` 지붕 아래 있지만, 이들은 **영속이며 루프의 "연료"**다. `.gitignore`가 `.forge/*`로 기본 제외하되 영속 문서만 화이트리스트로 되살려 추적한다 — `!.forge/CONTEXT.md` · `!.forge/adr/` · `!.forge/retro/` · `!.forge/codebase/` · `!.forge/config.json` · `!.forge/branch/`. 즉 **위치는 `.forge/` 안, 구분은 git 추적 여부**다. 전부 lazy 생성.

- `.forge/CONTEXT.md`(단일 컨텍스트) / 루트 `CONTEXT-MAP.md`(멀티 컨텍스트) — 도메인 글로서리. 용어만, 구현 세부 금지. fg-ask가 그릴링 중 인라인 갱신.
- `.forge/adr/NNNN-slug.md` — 아키텍처 결정. 세 조건(되돌리기 어렵다/맥락 없이 의아하다/진짜 트레이드오프) 모두 충족 시에만 승급. `adr/retired/`는 fg-cleanup이 은퇴시킨 ADR(번호 불변, 삭제 안 함, fg-ask가 정답소스로 안 읽음).
- `.forge/retro/YYYY-MM-DD-slug.md` — 세션 회고 로그. 승급 바를 못 넘는 학습의 종착지.
- `.forge/codebase/*.md` — fg-map이 생성하는 코드베이스 지도. fg-ask가 그릴링 전 읽어 context rot을 줄인다.

## 루프 밖 유틸리티

4단계에 속하지 않는 온디맨드 스킬들. 루프의 활성 상태 계약과 격리되거나 그것을 보조한다.

- **fg-status** — 읽기 전용 상태 리포터. `.forge/`를 조사해 현황 + 다음 단계 하나를 출력. 아무것도 안 쓰고 자동 실행 안 함. ("어디까지 했지")
- **fg-next** — fg-status의 상태 머신을 재사용해 다음 단계 하나를 도출하고 곧바로 그 스킬을 실행하는 오케스트레이터(보고만 하는 fg-status와 달리 행동까지). 기본 one-shot, `all` 모드는 백로그가 빌 때까지 선형 기계 단계를 자동 진행(회고 항상 skip)하고 대화의 벽에서만 멈춤. 자체적으로는 아무것도 안 쓰고 위임받은 스킬이 모든 쓰기를 함.
- **fg-loop** — goal 주도 한정 재계획 루프(ADR-0016). 기계 검증 가능한 정지 체크·승인된 fix-forward 범위·상한(기본 3라운드)을 `.forge/loop.md`에 못 박고 체크 전부 통과까지 run→UAT→회고 자동 skip→봉인을 무인 주행. `## Tasks` 멤버십 목록에 등재된 slug만 승격하며, 벽(검증불가 UAT·진짜 fork·상한 소진·무진전)에서 멈추고 사람에게 넘긴다.
- **fg-map** — 코드베이스를 병렬 서브에이전트로 `.forge/codebase/` 지도 문서로 만든다. 그릴링이 코드 재탐색 대신 지도를 읽게 해 context rot을 줄인다.
- **fg-quick** — 사소한 작업용 경량 차선. 그릴링은 유지(기둥 1)하되 형식 산출물 없이 `.forge/quick/LOG.md`에 한 줄만 남기고 직접 실행. 활성 슬롯·backlog·done을 일절 안 건드려 상태 계약과 격리. 비-trivial로 드러나면 fg-ask로 bail(기둥 2의 의도적·경계 있는 완화).
- **fg-merge** — `git merge` 뒤 비-기본 브랜치 forge 루트를 `.forge/`로 통합(ADR-0011). git 조작은 안 함.
- **fg-cleanup** — 오래된/대체된 ADR을 `adr/retired/`로 은퇴(ADR-0012). 번호 불변·삭제 안 함.
- **fg-doctor** — 읽기 전용 무결성 health check(ADR-0019). `.forge/` 상태 계약(고아 파일·STATUS 필드·slug 페어링·half-sealed)과 문서/매니페스트 정합(버전 3곳·README 이중언어·CLAUDE.md 스킬 목록)을 검사해 severity·수정 안내와 함께 보고. 아무것도 안 쓰고 자동 수정 안 함. (fg-status는 "어디", fg-doctor는 "건강".)
- **fg-drop** — 미봉인 작업(backlog·활성 슬롯·executed·멈춘 goal loop)을 폐기(ADR-0021). 항목별 리스크 제시 → hard-delete(기본) 또는 `.forge/dropped/<slug>/` 보관 선택. forge 상태만 건드리고 git·코드는 안 건드림(이미 실행된 코드 변경은 되돌리지 않음 경고).
- **fg-tdd** — 영속 TDD 모드 토글(`config.json`의 `tdd`, ADR-0008). fg-ask가 작업마다 기본 답으로 묻고, plan 마커가 on이면 fg-run이 test-first로 실행.
- **fg-eco** — 위임 모델 티어링 토글(`config.json`의 `eco`, ADR-0014). 켜면 fg-run의 Dynamic Workflow 서브에이전트를 sonnet으로 캡. 메인 세션 모델은 불변.
- **fg-statusline** — statusline에 forge 진행 상태를 띄우는 설정 유틸리티(ADR-0017). `.forge/`를 읽어 한 줄 출력하는 bash 조각을 `~/.claude/`에 설치하고 settings.json에 연결. 기존 statusLine을 교체 않고 별도 줄로 래핑.
- **fg-adversarial-review** — fg-run↔fg-learn 사이 선택적 적대적 리뷰(ADR-0018). "결과가 틀렸다고 가정하고 증거를 찾는" 6개 렌즈를 Dynamic Workflow 서브에이전트로 병렬 팬아웃, findings를 `.forge/review.md`(휘발)에 기록하고 fix-needed 건은 사람 승인 후 fix-forward plan으로 만들어 fg-run 재실행. 비-게이트라 봉인을 안 막고, 무인 주행(fg-next all·fg-loop)에선 항상 skip.

## 진입점 (entry points)

코드 진입점이 아니라 **스킬 트리거**다. 사용자가 프롬프트에 트리거 문구를 치면 Claude Code가 해당 `SKILL.md`를 로드해 실행한다. 정식 식별자는 디렉터리명이 아니라 각 `SKILL.md` frontmatter의 `name`이다. 대표 트리거: 루프 진입 `fg-ask`("새 작업 시작"·"forge로 시작"), 실행 `fg-run`("forge run"·"계획 실행"), 회고 `fg-learn`("회고하자"), 봉인 `fg-done`("작업 완료"·"봉인"). 콜드 재진입은 `fg-next`("다음 단계"·"이어서 해줘"). 트리거 전체 목록은 각 `SKILL.md`의 `description`에 있다.
