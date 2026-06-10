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
fg-ask(①질의·계획·그릴링) → fg-run(②실행) → fg-learn(③회고) → fg-done(④완료) → (새 작업) fg-ask
```

- **fg-ask** — grill-with-docs식 대화형 그릴링. 계획을 도메인·용어·결정에 대고 검증해 `.forge/backlog/<slug>.md`로 적재. **반드시 본 세션 대화로** 진행(워크플로우 밖).
- **fg-run** — `.forge/plan.md`를 Claude Code Dynamic Workflow로 실행, 계획↔실제 차이를 `.forge/run.md`에 기록.
- **fg-learn** — 학습을 분류해 영속 문서로 승급, `.forge/retro/`에 회고 남김. 항상 대화형.
- **fg-done** — 루프의 ④ 완료(봉인) 단계: 한 바퀴의 잔여물을 정리(tidy up)해 마감한다 — 회고 확인, `STATUS.md`를 `done`으로 마감, 작업을 `.forge/done/<날짜-slug>/`로 봉인하고 활성 `.forge/`를 비워 루프를 닫음 → **재실행 방지의 핵심 메커니즘**.

**루프 밖 스킬(이 4단계에 속하지 않음):** `fg-map`(코드베이스 지도 유틸리티)·`fg-quick`(경량 차선)·`fg-status`(읽기 전용 상태 리포터 — `.forge/`를 조사해 현황+다음 단계를 출력, 아무것도 쓰지 않고 자동 실행 안 함)·`fg-next`(상태를 읽어 fg-status의 상태 머신으로 다음 단계 하나를 도출해 한 줄로 알린 뒤 그 스킬을 곧바로 실행하는 오케스트레이터 — 보고만 하고 멈추지 않음, fg-status는 보고만/fg-next는 행동까지. 기본은 one-shot이며 자체적으로는 아무것도 쓰지 않고 위임받은 스킬이 모든 쓰기를 함. `all` 모드(`fg-next all`)는 백로그가 빌 때까지 선형 기계적 단계를 자동 추천 진행하며 회고는 (divergence 무관) 항상 자동 skip하고 대화의 벽(실패/검증불가 UAT·진짜 fork·빈 상태)에서만 멈춤 — ADR-0010(개정 2026-06-08))·`fg-merge`(`git merge` 뒤 비-기본 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합하는 유틸리티 — ADR 번호 재부여+교차참조 갱신·retro 이동·CONTEXT 용어 병합·done 합침·브랜치 폴더 제거, 기계적 자동/진짜 충돌 시 대화, git 조작은 안 함 — ADR-0011)·`fg-cleanup`(오래된/대체된 ADR을 활성 결정 집합에서 은퇴시키는 유틸리티 — 후보 제시→사람 승인으로 `.forge/adr/retired/<NNNN>-slug.md`로 이동+supersede 마킹, 번호 불변·재사용 금지·삭제 안 함, fg-ask는 retired/를 정답소스로 안 읽음; 작업 봉인은 fg-done이지 이 스킬이 아님 — ADR-0012)·`fg-eco`(위임 모델 티어링 토글 — `.forge/config.json`의 `eco`; 켜면 fg-run이 위임 워크플로우 서브에이전트를 sonnet으로 캡, 내리기만·세션 모델 불변·명시적 사용자 지시 우선 — ADR-0014). 특히 **fg-quick**은 사소한 작업용으로, 그릴링은 유지(기둥 1)하되 형식 산출물(ADR·backlog plan.md·run.md·STATUS·done·회고)을 만들지 않고 `.forge/quick/LOG.md`에 한 줄만 기록한 뒤 직접 실행한다. **메인 루프의 활성 슬롯·backlog·done을 일절 건드리지 않아 상태 계약과 격리**되며, 비-trivial로 드러나면 fg-ask로 bail한다(상세·트레이드오프: `.forge/adr/0003-fg-quick-lightweight-lane.md`). 즉 기둥 2(문서=연료)를 trivial 작업에 한해 의도적으로 완화한 차선이다.

### 상태 계약 (`.forge/`의 휘발 상태 — git 미추적)

스킬을 편집할 때 이 입출력 계약을 깨지 않아야 흐름이 이어진다. 입력 파일이 없으면 각 스킬은 앞 단계를 안내한다.

**브랜치별 forge 루트 (ADR-0011).** 아래 표·설명의 모든 `.forge/...` 경로는 **해석된 forge 루트 기준**이다 — 기본 브랜치(`config.json`의 `defaultBranch`, 없으면 `main`)면 `.forge/`, 그 외 브랜치면 `.forge/branch/<branch>/`. 단 전역 예외 두 개(`.forge/config.json`·`.forge/codebase/`)는 모든 브랜치에서 항상 최상위 `.forge/`다. 비-기본 브랜치의 루트는 **통째로 git 추적**된다(`.gitignore`가 `!.forge/branch/`로 화이트리스트). 경로가 브랜치별로 네임스페이스되어 두 브랜치가 같은 파일을 안 건드리므로 git merge 충돌이 없고, 브랜치 내용은 `git merge` 뒤 **fg-merge**가 `.forge/`에 통합한다(번호 재부여·retro 이동·CONTEXT 병합·폴더 제거). 단일 정의는 `skills/fg-run/FORGE-ROOT.md`이며 모든 루프 스킬이 이를 참조한다(복붙 금지). 기본 브랜치의 휘발 상태는 종전대로 gitignored — 브랜치 루트만 추적되는 의도된 비대칭.

| 파일 | 생산자 | 소비자 |
| --- | --- | --- |
| `.forge/backlog/<slug>.md` | fg-ask | fg-run(선택 메뉴·승격) |
| `.forge/plan.md` (활성 슬롯) | fg-run(백로그에서 승격) | fg-run(정답 기준), fg-learn |
| `.forge/run.md` | fg-run | fg-learn |
| `.forge/STATUS.md` (활성 슬롯, `status: executed`, `verified: pending`) | fg-run(run.md 기록 직후 작성, 핸드오프 UAT로 `verified:` 기록) | fg-run(상태 요약·검증 재진입)·fg-learn(검증 통과 시 회고)·fg-done(검증→회고 게이트 후 `status: done` 마감) |
| `.forge/executed/<slug>/` (+`STATUS.md`, `status: executed`) | fg-run("모두 실행" park) | fg-learn(회고 대기), fg-done(봉인) |
| `.forge/done/<날짜-slug>/` (+`STATUS.md`, fg-done이 `status: done`으로 마감) | fg-done | fg-ask(slug 충돌 검출)·fg-run(완료 판별·상태 요약)·fg-learn(회고 대상 제외)·fg-done(이중 봉인 방지) |

- **활성 슬롯은 항상 1개** — 한 plan.md = 한 run.md = 한 봉인. 백로그는 미실행 대기열, `executed/`는 "실행됐으나 미회고"의 명시적 상태다. plan 첫 줄의 `<!-- forge-slug: ... -->` 주석이 회고·봉인의 짝 맞춤 식별자다(파일 이동에도 영속).
- **활성 슬롯·백로그·executed가 모두 비어 있으면 = 진행 중 작업 없음.** fg-run는 빈 상태에서 실행하지 않는다(재실행 방지). fg-done이 봉인하며 비운다.
- **STATUS.md는 작업 파일들과 함께 이동하는 동반 마커다(이중 장부 아님).** 상태의 원천은 파일 위치이고 STATUS.md는 plan/run과 함께 활성 슬롯→`executed/`→`done/`을 따라 이동한다. fg-run가 `status: executed`(+`verified: pending`+`retro: pending`)로 만들고 fg-done이 `status: done`(+`completed`/`verified`/`retro`/`docs updated`)으로 마감한 뒤 plan/run과 함께 아카이브한다. 완료 판별 = `done/*/STATUS.md`의 `status: done`.
- **봉인 전 검증 게이트(ADR-0009).** 루프 순서는 run → verify → learn → done. fg-run 핸드오프가 plan 목표에 대고 UAT를 수행해 STATUS `verified:`를 기록한다 — **봉인 가능** `yes`/`skipped (사유)`/`n/a (사유)`, **차단** `pending`(미검증)/`failed (사유)`(검증했으나 깨짐). fg-done은 **검증 게이트를 회고 게이트보다 먼저** 확인하고(no-seal-without-verification), 봉인 가능 값이 아니면 봉인하지 않는다. `pending`은 fg-run 검증 전용 재진입(재실행 없이 UAT만)으로, `failed`는 fg-run의 parked-failed 회수(executed/→active slot unpark)·fix-and-re-run 또는 fg-ask 재그릴로 라우팅 — fg-run이 unpark의 단일 소유자다. `failed`은 fresh re-run으로 봉인 가능 값에 재검증될 때만 봉인되며 waiver로 통과시키지 않는다. Run all은 작업별 UAT를 파킹 전 수행(sealable만 파킹, `failed`은 active slot에 남김). ADR-0009 이전 봉인 작업은 `verified: n/a (legacy pre-ADR-0009)`로 백필됐다.
- **회고는 저-divergence 사소한 작업에 한해 건너뛸 수 있다(ADR-0002).** 기본값은 회고(fg-learn)다. run.md의 계획↔실제 차이가 없거나 미미할 때만 fg-run 핸드오프가 "회고 / 건너뛰기"를 명시 제시하고, 사용자가 건너뛰기를 고르면 STATUS.md의 `retro:` 필드에 `skipped (사유)`를 기록한다(회고 파일 없음). fg-done의 봉인 가드는 회고 파일 존재 **또는** `retro: skipped`를 통과 조건으로 인정한다. divergence가 크면 건너뛰기를 제시하지 않는다. fg-ask는 plan에 `<!-- retro-hint: optional -->`(비구속 힌트)를 남길 수 있을 뿐, 자동 건너뛰기는 없다.
- 재그릴링이 필요하면 fg-learn/fg-run가 **fg-ask**를 가리킨다(과거 별도 `fg-plan` 단계는 fg-ask로 통합됨).

### 영속 문서 모델 (`.forge/` 내부, git 추적)

휘발 상태와 같은 `.forge/` 지붕 아래 있지만, 이들은 **영속이며 루프의 "연료"**다. `.gitignore`가 `.forge/`를 기본 제외(`​.forge/*`)하되 이 영속 문서들만 화이트리스트로 되살려 추적한다(`!.forge/CONTEXT.md` · `!.forge/adr/` · `!.forge/retro/` · `!.forge/codebase/` · `!.forge/config.json`). 즉 **위치는 `.forge/` 안, 구분은 git 추적 여부**다. 전부 **lazy 생성**(쓸 내용이 생길 때만).

- `.forge/CONTEXT.md` / 루트 `CONTEXT-MAP.md`(멀티 컨텍스트) — 도메인 글로서리. 용어만, 구현 세부 금지. fg-ask가 그릴링 중 인라인 갱신. **멀티 컨텍스트만 예외** — 컨텍스트별 `CONTEXT.md`는 코드 옆(`src/<context>/`)에, `CONTEXT-MAP.md`는 루트에 둔다(`.forge/` 통합 대상 아님). 단일 컨텍스트만 `.forge/CONTEXT.md`.
- `.forge/adr/NNNN-slug.md` — 아키텍처 결정. 세 조건(되돌리기 어렵다/맥락 없이 의아하다/진짜 트레이드오프) 모두 충족 시에만.
- `.forge/retro/YYYY-MM-DD-slug.md` — 세션 회고 로그. 승급 바를 못 넘는 학습의 종착지.
- `.forge/codebase/*.md` — fg-map(루프 밖 유틸리티)이 생성하는 코드베이스 지도(7문서). fg-ask가 그릴링 전 읽어 context rot을 줄인다.

형식 정의는 한 벌만 존재하며 소유 스킬의 디렉터리에 둔다 — `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`(grill-with-docs 원본), `skills/fg-run/PLAN-FORMAT.md`(plan.md 형식 + 분할 규칙; 생산자는 fg-ask지만 fg-ask 디렉터리는 verbatim 영역이라 소비자 쪽에 둠), `skills/fg-learn/RETRO-FORMAT.md`. 전부 영문(생성되는 문서는 사용자 언어). 다른 스킬(fg-done 포함)은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(상대경로 `../fg-ask/` 등)로 참조하고 자체 복사하지 않는다. 루트 `references/` 디렉터리는 폐지됐다.

## 설계 원칙 (두 기둥)

스킬을 수정할 때 이 둘을 깨면 forge가 forge가 아니게 된다:

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** 워크플로우는 실행 중 사용자 입력을 못 받는다. 한 질문씩 주고받는 그릴링(fg-ask)은 반드시 워크플로우 밖 대화로.
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.

## 스킬 편집 규약

- **핸드오프**: 각 스킬은 끝에서 "방금 한 것 / 다음 단계 / 시작하는 법"을 **자연스러운 대화체**로 전한다(정해진 양식을 사무적으로 출력하지 않는다).
- **언어**: 스킬 본문(`SKILL.md`)·형식 문서(`*-FORMAT.md`)는 **영문으로 작성**한다(grill-with-docs 원문을 그대로 옮긴 부분은 영문 verbatim 유지). 단 스킬이 **사용자에게 출력하는 언어는 사용자의 언어를 따른다** — 각 스킬에 "respond in the user's language" 지시를 명시하고, 산출 문서(plan·회고·CONTEXT·ADR 등 사용자 프로젝트에 남는 문서)도 사용자 언어로 쓴다.
- **README 이중 언어 동기화**: `README.md`(영문)와 `README.ko.md`(한글)는 같은 내용의 번역 쌍이다. **`README.md`를 갱신하면 반드시 `README.ko.md`도 같은 변경으로 함께 갱신한다**(역방향도 동일). 한쪽만 고치면 두 문서가 어긋난다.
- **흐름도는 텍스트로**: 스킬 문서(`SKILL.md`)에 흐름·상태 전이·분기를 넣을 때는 **Mermaid를 쓰지 말고 텍스트 흐름도로 작성한다**(`A → B → C`, 분기는 들여쓰기·화살표·조건 레이블로). 스킬 본문은 영문이므로 텍스트 흐름도도 영문으로 쓴다. 이유: 스킬은 에이전트가 읽고 실행하는 지시문이라 렌더링 없이 그대로 파싱되어야 하고, Mermaid 블록은 진단·diff·grep을 어렵게 한다. (이 규약은 스킬 문서 한정이며, 사용자 프로젝트에 생성되는 산출 문서에는 적용되지 않는다.)
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

**배포 후 "설치 테스트":** `/plugin install`·`/plugin marketplace update`는 interactive 명령이라 에이전트가 실행 못 한다(사용자가 직접 침). 에이전트가 검증할 수 있는 건 설치 전제뿐 — `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`으로 원격 main의 버전 3곳을, `awk '/^name:/'`로 `skills/*/SKILL.md`의 frontmatter `name`(자동 탐색 대상) 누락 여부를 확인한다.

- 작업 트리에 배포와 무관한 변경이 섞여 있으면 멈추고 먼저 확인받는다(배포 커밋에 끼워 넣지 않는다).
- 마지막 배포 이후 커밋이 하나도 없으면 배포할 것이 없다고 알리고 멈춘다.
- **미커밋 변경이 곧 릴리스 내용이면**(커밋 0개인데 작업 트리에 그 릴리스의 기능 작업이 쌓여 있음) 먼저 그 작업을 별도 `feat` 커밋으로 묶은 뒤 릴리스 절차를 돈다(릴리스 커밋엔 CHANGELOG+버전 범프만). 이 리포의 정상 흐름이다.
- **매니페스트의 두 description은 역할이 다르다.** `marketplace.json`의 `metadata.description`은 루프(ask→execute→retro→done)를 정의하는 한 줄 태그라인이므로 루프 밖 유틸리티(fg-map류)는 넣지 않는다. `plugins[].description`(과 `plugin.json`의 `description`)은 전체 스킬 목록을 담는 설명이므로 루프 밖 스킬도 여기에 반영한다. 루프 밖 스킬을 metadata에 끼우면 루프 정의가 흐려진다.

## 현재 상태의 알려진 불일치 (편집 전 인지할 것)

여러 파일을 읽어야 드러나는, 의도적 반복 작업으로 생긴 어긋남:

- **`skills/fg-ask/`는 grill-with-docs 원본의 자기완결 3파일**(`SKILL.md` + 형제 `CONTEXT-FORMAT.md`/`ADR-FORMAT.md`, 영문)이며, SKILL.md 본문은 영문 verbatim이고 forge 루프 연결(백로그 산출, fg-run 핸드오프, 회고 환류)은 맨 아래 "Forge integration (minimal)" 섹션에만 둔다. 이 verbatim 본문과 Forge integration 섹션은 따로 움직이므로, 둘 중 하나만 고치면 계약이 깨진다.
