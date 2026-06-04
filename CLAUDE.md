# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 이 리포가 무엇인가

forge는 **Claude Code 플러그인**이다 — 코드를 빌드하는 프로젝트가 아니라, `fg-*` 워크플로우 스킬을 패키징한 플러그인이자 그 자신이 설치 가능한 마켓플레이스다. 산출물은 전부 Markdown(`SKILL.md`, 형식 문서)과 JSON(매니페스트)이다.

**빌드·테스트·린트 시스템이 없다.** package.json, Makefile, CI 없음. "개발"은 Markdown/JSON을 편집하는 것이고, 검증은 아래 방법으로 한다.

```bash
# 매니페스트 JSON 유효성 (편집 후 반드시 확인 — 깨지면 설치 실패)
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"

# 실제 동작 테스트는 설치해서 트리거해보는 것뿐 (단위 테스트 없음)
#   /plugin marketplace add gyuha/forge   (또는 로컬 경로)
#   /plugin install forge@forge
# 설치는 GitHub 기본 브랜치(main)를 당긴다 → 설치 테스트하려면 main에 push되어 있어야 한다.
```

## 패키징 구조 (단일 리포 = 플러그인 + 마켓플레이스)

`harness` 플러그인과 동일한 패턴이다: 리포 루트가 곧 플러그인 루트이자 마켓플레이스.

- `.claude-plugin/plugin.json` — 플러그인 매니페스트. `skills/` 가 자동 탐색되므로 `skills` 필드는 생략 가능.
- `.claude-plugin/marketplace.json` — 이 리포를 마켓플레이스로 등록. `plugins[].source` 는 `"./"`(루트가 곧 플러그인).
- 스킬은 `skills/<name>/SKILL.md` 로 자동 탐색된다. **스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name`** 이다.

매니페스트의 스킬 개수·설명을 바꿀 땐 `plugin.json`과 `marketplace.json`을 함께 갱신해야 한다(둘 다 사람이 읽는 설명을 담는다).

## 핵심 아키텍처 — forge 루프

forge의 본질은 작업 하나를 한 바퀴 돌리는 4단계 루프다. 각 스킬은 **독립 실행**되며, 상태를 `.forge/` 파일로 주고받아 흐름을 잇는다.

```
fg-ask(①질의·계획·그릴링) → fg-execute(②실행) → fg-learn(③회고) → fg-cleanup(④Cleanup) → (새 작업) fg-ask
```

- **fg-ask** — grill-with-docs식 대화형 그릴링. 계획을 도메인·용어·결정에 대고 검증해 `.forge/backlog/<slug>.md`로 적재. **반드시 본 세션 대화로** 진행(워크플로우 밖).
- **fg-execute** — `.forge/plan.md`를 Claude Code Dynamic Workflow로 실행, 계획↔실제 차이를 `.forge/run.md`에 기록.
- **fg-learn** — 학습을 분류해 영속 문서로 승급, `docs/retro/`에 회고 남김. 항상 대화형.
- **fg-cleanup** — "완료 선언"이 아니라 한 바퀴의 잔여물을 정리(tidy up)하는 단계: 회고 확인, `STATUS.md`를 `done`으로 마감, 작업을 `.forge/done/<날짜-slug>/`로 봉인하고 활성 `.forge/`를 비워 루프를 닫음 → **재실행 방지의 핵심 메커니즘**.

### 상태 계약 (`.forge/` — 휘발, gitignore)

스킬을 편집할 때 이 입출력 계약을 깨지 않아야 흐름이 이어진다. 입력 파일이 없으면 각 스킬은 앞 단계를 안내한다.

| 파일 | 생산자 | 소비자 |
| --- | --- | --- |
| `.forge/backlog/<slug>.md` | fg-ask | fg-execute(선택 메뉴·승격) |
| `.forge/plan.md` (활성 슬롯) | fg-execute(백로그에서 승격) | fg-execute(정답 기준), fg-learn |
| `.forge/run.md` | fg-execute | fg-learn |
| `.forge/STATUS.md` (활성 슬롯, `status: executed`) | fg-execute(run.md 기록 직후 작성) | fg-execute(상태 요약 보강)·fg-learn(회고 대기 확인)·fg-cleanup(`status: done`으로 마감) |
| `.forge/executed/<slug>/` (+`STATUS.md`, `status: executed`) | fg-execute("모두 실행" park) | fg-learn(회고 대기), fg-cleanup(봉인) |
| `.forge/done/<날짜-slug>/` (+`STATUS.md`, fg-cleanup이 `status: done`으로 마감) | fg-cleanup | fg-ask(slug 충돌 검출)·fg-execute(완료 판별·상태 요약)·fg-learn(회고 대상 제외)·fg-cleanup(이중 봉인 방지) |

- **활성 슬롯은 항상 1개** — 한 plan.md = 한 run.md = 한 봉인. 백로그는 미실행 대기열, `executed/`는 "실행됐으나 미회고"의 명시적 상태다. plan 첫 줄의 `<!-- forge-slug: ... -->` 주석이 회고·봉인의 짝 맞춤 식별자다(파일 이동에도 영속).
- **활성 슬롯·백로그·executed가 모두 비어 있으면 = 진행 중 작업 없음.** fg-execute는 빈 상태에서 실행하지 않는다(재실행 방지). fg-cleanup이 봉인하며 비운다.
- **STATUS.md는 작업 파일들과 함께 이동하는 동반 마커다(이중 장부 아님).** 상태의 원천은 파일 위치이고 STATUS.md는 plan/run과 함께 활성 슬롯→`executed/`→`done/`을 따라 이동한다. fg-execute가 `status: executed`로 만들고 fg-cleanup이 `status: done`(+`completed`/`retro`/`docs updated`)으로 마감한 뒤 plan/run과 함께 아카이브한다. 완료 판별 = `done/*/STATUS.md`의 `status: done`.
- 재그릴링이 필요하면 fg-learn/fg-execute가 **fg-ask**를 가리킨다(과거 별도 `fg-plan` 단계는 fg-ask로 통합됨).

### 영속 문서 모델

`.forge/`(휘발)와 달리 이들은 영속이며 루프의 "연료"다. 전부 **lazy 생성**(쓸 내용이 생길 때만).

- `CONTEXT.md` / `CONTEXT-MAP.md`(멀티 컨텍스트) — 도메인 글로서리. 용어만, 구현 세부 금지. fg-ask가 그릴링 중 인라인 갱신.
- `docs/adr/NNNN-slug.md` — 아키텍처 결정. 세 조건(되돌리기 어렵다/맥락 없이 의아하다/진짜 트레이드오프) 모두 충족 시에만.
- `docs/retro/YYYY-MM-DD-slug.md` — 세션 회고 로그. 승급 바를 못 넘는 학습의 종착지.

형식 정의는 한 벌만 존재하며 소유 스킬의 디렉터리에 둔다 — `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`(grill-with-docs 원본), `skills/fg-execute/PLAN-FORMAT.md`(plan.md 형식 + 분할 규칙; 생산자는 fg-ask지만 fg-ask 디렉터리는 verbatim 영역이라 소비자 쪽에 둠), `skills/fg-learn/RETRO-FORMAT.md`. 전부 영문(생성되는 문서는 사용자 언어). 다른 스킬(fg-cleanup 포함)은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(상대경로 `../fg-ask/` 등)로 참조하고 자체 복사하지 않는다. 루트 `references/` 디렉터리는 폐지됐다.

## 설계 원칙 (두 기둥)

스킬을 수정할 때 이 둘을 깨면 forge가 forge가 아니게 된다:

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** 워크플로우는 실행 중 사용자 입력을 못 받는다. 한 질문씩 주고받는 그릴링(fg-ask)은 반드시 워크플로우 밖 대화로.
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.

## 스킬 편집 규약

- **핸드오프**: 각 스킬은 끝에서 "방금 한 것 / 다음 단계 / 시작하는 법"을 **자연스러운 대화체**로 전한다(정해진 양식을 사무적으로 출력하지 않는다).
- **언어**: 스킬 본문(`SKILL.md`)·형식 문서(`*-FORMAT.md`)는 **영문으로 작성**한다(grill-with-docs 원문을 그대로 옮긴 부분은 영문 verbatim 유지). 단 스킬이 **사용자에게 출력하는 언어는 사용자의 언어를 따른다** — 각 스킬에 "respond in the user's language" 지시를 명시하고, 산출 문서(plan·회고·CONTEXT·ADR 등 사용자 프로젝트에 남는 문서)도 사용자 언어로 쓴다.
- **README 이중 언어 동기화**: `README.md`(영문)와 `README.ko.md`(한글)는 같은 내용의 번역 쌍이다. **`README.md`를 갱신하면 반드시 `README.ko.md`도 같은 변경으로 함께 갱신한다**(역방향도 동일). 한쪽만 고치면 두 문서가 어긋난다.
- **절제**: ADR·글로서리 용어는 바를 넘을 때만 승급. 회고에서 나온 모든 걸 영속 문서로 밀어 넣지 않는다.

## 배포 규칙

사용자가 프롬프트에 **"배포"** 라고 치면 아래 절차를 순서대로 수행한다.

1. **CHANGELOG.md 갱신** — 마지막 배포(마지막 버전 범프 커밋) 이후의 커밋들을 요약해 새 버전 섹션을 맨 위에 추가한다. 형식은 Keep a Changelog 약식:

   ```markdown
   ## [X.Y.Z] - YYYY-MM-DD
   ### Added / Changed / Fixed (해당 항목만)
   - 변경 요약 한 줄씩
   ```

   파일이 없으면 `# Changelog` 헤더와 함께 새로 만든다(lazy 생성).
2. **버전 범프** — 기본은 **patch**. 사용자가 "배포 minor" / "배포 major"라고 지정하면 그에 따른다. 버전은 **3곳을 반드시 동기 갱신**한다: `plugin.json`의 `version`, `marketplace.json`의 `metadata.version`과 `plugins[0].version`.
3. **검증** — 매니페스트 JSON 유효성 확인(위 node 한 줄).
4. **commit & push** — `chore(release): vX.Y.Z` 형식으로 커밋하고 `main`에 push한다(설치는 main을 당기므로 push까지가 배포다).

절차 흐름: `CHANGELOG.md 작성 → 버전 3곳 범프 → JSON 검증 → commit → push`

- 작업 트리에 배포와 무관한 변경이 섞여 있으면 멈추고 먼저 확인받는다(배포 커밋에 끼워 넣지 않는다).
- 마지막 배포 이후 커밋이 하나도 없으면 배포할 것이 없다고 알리고 멈춘다.

## 현재 상태의 알려진 불일치 (편집 전 인지할 것)

여러 파일을 읽어야 드러나는, 의도적 반복 작업으로 생긴 어긋남:

- **`skills/fg-ask/`는 grill-with-docs 원본의 자기완결 3파일**(`SKILL.md` + 형제 `CONTEXT-FORMAT.md`/`ADR-FORMAT.md`, 영문)이며, SKILL.md 본문은 영문 verbatim이고 forge 루프 연결(백로그 산출, fg-execute 핸드오프, 회고 환류)은 맨 아래 "Forge integration (minimal)" 섹션에만 둔다. 이 verbatim 본문과 Forge integration 섹션은 따로 움직이므로, 둘 중 하나만 고치면 계약이 깨진다.
- **`forge-prd.md`는 옛 설계 초안**이다. 본문은 "스킬 5개"라 하면서 다이어그램은 4단계만 나열하고(fg-ask→fg-execute→fg-learn→fg-complete), 마지막 단계를 현재의 `fg-cleanup`·④정리가 아닌 옛 이름 `fg-complete`·④완료로 가리킨다. 명세로 신뢰하지 말 것 — 실제는 `skills/`와 `README.md`가 기준.
