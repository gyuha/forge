---
last_mapped_commit: 382c3f8346ae5b8b68abbb5a2dabe2ab52a80d62
mapped: 2026-06-12
---

# CONCERNS — 이 플러그인의 실제 취약점

forge는 런타임 코드가 없는 Claude Code 플러그인이다 — Markdown 스킬(`skills/*/SKILL.md`)과 JSON 매니페스트(`.claude-plugin/*.json`)뿐이다. 따라서 "버그"는 컴파일 에러가 아니라 **설치 실패, 스킬 미탐색, 스킬 간 상태 계약 단절, 문서 드리프트** 형태로 나타난다. 컴파일러·테스트가 잡아주지 않으므로 전부 사람이 편집 규율로 막아야 한다. 아래는 각 항목을 **현재 작업 트리**(HEAD `382c3f8`, origin/main과 동기, 작업 트리 clean)에 대고 검증한 결과다.

직전 지도(`b45521c` 시점) 이후 큰 폭의 해소가 있었다: **구 0번(fg-loop 미커밋·버전 분기)은 완전 해소** — v0.4.8 릴리스(`f4d6674`)로 커밋·배포됐고, 오늘의 행동 계약 수정 2건(`382c3f8`)까지 push 완료, 버전 3곳 모두 `0.4.8` 일치, 작업 트리 clean을 `git status`/`git log origin/main`으로 확인했다. **구 5번(fg-learn 일괄 승급 공수표)과 구 4번(loop.md 인지 격차 6건)도 전부 해소**됐다 — 상세는 아래 4·5번에서 항목별로 재검증했다.

---

## 1. 매니페스트 버전이 3곳에 흩어져 있다 — 어긋나면 설치 깨짐, 자동 검사 없음; 그리고 릴리스 후 커밋 3건이 같은 0.4.8 라벨 아래 쌓여 있다

버전 문자열이 세 군데에 중복되며 반드시 동기화되어야 한다:

- `.claude-plugin/plugin.json` → `version` (현재 `0.4.8`)
- `.claude-plugin/marketplace.json` → `metadata.version` (현재 `0.4.8`)
- `.claude-plugin/marketplace.json` → `plugins[0].version` (현재 `0.4.8`)

세 값의 일치와 JSON 파싱 유효성은 확인했다 [높음]. 그러나 리포의 검증 도구는 JSON 파싱뿐이고 **세 버전이 같은지는 어떤 도구도 검사하지 않는다**. `CLAUDE.md` 배포 규칙이 "3곳 동기 갱신"을 사람 절차로 강제하는 것이 유일한 방어다.

**새 관찰**: v0.4.8 릴리스 커밋(`f4d6674`) 이후 3건(`76e628d` 매니페스트 카탈로그 정정, `c8ea281` fg-merge 브랜치 통합, `382c3f8` fg-learn 일괄 승급+멤버십)이 main에 push됐는데 버전 범프가 없다. 설치는 main HEAD를 당기므로 **사용자는 0.4.8 라벨 아래 0.4.8 릴리스보다 새로운 내용을 받는다** — 구 0번의 "버전 같은데 내용 다름"의 약한 변종(이번엔 커밋·push까지는 됐으므로 로컬/원격 분기는 없음). 다음 "배포" 트리거가 0.4.9로 정리하면 해소된다 [중간 — 동작 위험은 없고 추적성 문제].

---

## 2. 스킬 개수·목록이 산문에 하드코딩 ≥6곳 — 현재 전 지점 정합; C5(매니페스트 카탈로그 누락)는 해소

스킬 개수(13개, 루프 밖 9개)와 전체 목록이 서로 다른 문장 구조의 산문 여러 벌에 박혀 있다. 현재 전 지점 정합을 각각 확인했다 [높음]:

- `marketplace.json` `plugins[0].description` — "Thirteen fg-* skills … Nine more sit outside the loop", **fg-learn·fg-done이 이제 명시 서술됨**("retro (fg-learn) promotes learnings to docs, and done (fg-done) seals the task") — 구 C5는 `76e628d`로 해소 ✓
- `plugin.json` `description` — 13개 스킬 전부 열거 ✓
- `README.md:4` "thirteen … nine utilities" / `README.ko.md:4` "13개 … 9개" ✓
- `README.md:28` / `README.ko.md:28` — 루프 밖 9개 스킬 장문 서술 양판 정합 ✓
- `CLAUDE.md:44` "루프 밖 스킬" 단락 — 9개 전부 서술, fg-loop에 `## Tasks` 멤버십 문구까지 반영 ✓

stale한 "twelve/12개" 잔재는 산문 동기 지점에는 없다(단 `docs/forge-vs-loop-engineering.md:15`의 "12개 fg-* 스킬"은 역사 문서의 낡음 — 10번 참조). **구조적 위험은 그대로다**: 14번째 스킬이 오면 또 최소 6지점을 손으로 동시에 고쳐야 하며 자동 검출은 없다. 과거 12스킬 체제에서 fg-tdd 통누락이 실제로 발생했었다.

---

## 3. 스킬은 frontmatter `name`으로 자동 탐색 — 틀리면 조용히 사라진다; fg-next description은 여전히 한도 초과 의심

`plugin.json`에 `skills` 필드가 없어 `skills/`가 자동 탐색되고, 식별자는 디렉터리명이 아니라 `SKILL.md` frontmatter의 `name`이다. **13개 스킬 전부** 디렉터리명과 `name` 일치를 확인했다 [높음]. `name`을 빠뜨리거나 오타 내면 그 스킬은 에러 없이 그냥 탐색에서 빠진다. 배포 전 점검 `awk '/^name:/' skills/*/SKILL.md`는 누락만 잡고 오타는 못 잡는다.

frontmatter `description` 길이: `skills/fg-next/SKILL.md`가 **1,084자**로 변함없이 흔히 문서화되는 권장 한도(약 1,024자)를 넘는 유일한 스킬이다 [중간 — 한도 수치·강제 여부는 공식 문서 재확인 필요]. 나머지 12개는 351–708자 범위.

---

## 4. `.forge/loop.md` 인지 격차 — 직전 지도의 6건 전부 해소 확인 (record)

구 4번의 발화점 후보 6건을 현재 파일에 대고 항목별 재검증했다. 전부 해소 [높음]:

- **fg-ask (1b) 경고** ✓ — `skills/fg-ask/SKILL.md:102`: loop.md 존재 시 한 줄 경고 + "(a) fg-loop 재개 / (b) 새 작업 계속" 분기. (b)에서 새 plan이 무필터 주행에 휩쓸리지 않는 근거(멤버십 필터)까지 명시.
- **백로그 무필터 주행 차단** ✓ — `skills/fg-loop/SKILL.md:36,43`: `loop.md`의 `## Tasks` 섹션이 멤버십 목록(초기 plan 등재 + fix-forward 생성 시 append), `:51` 드라이브는 **member slug만 승격**, 비소속 plan은 한 줄 보고 후 불간섭. `:47` 멤버십 없는 구식 loop.md는 재개 시 사용자에게 한 번 물어 추가(추측 금지). `.forge/adr/0016-*`에 "개정 (2026-06-12)" 섹션으로 기록됨.
- **fg-merge in-flight halt** ✓ — `skills/fg-merge/SKILL.md:36`: 브랜치 루트의 loop.md(미완 goal 계약)를 in-flight 상태로 간주해 halt — 브랜치에서 fg-loop 재개(goal-met까지 주행 또는 의도적 삭제) 후 통합.
- **`<!-- generated-by: fg-loop -->` 소비자** ✓ — `skills/fg-status/SKILL.md:50`: 테이블의 Task 열에서 마커를 읽어 `(loop)` origin 태그를 붙인다. 생산(`fg-loop/SKILL.md:66` "fg-status renders it as a `(loop)` origin tag")과 소비가 양쪽에 적혀 정합.
- **CLAUDE.md 상태 계약 표** ✓ — `CLAUDE.md:60`에 loop.md 행 추가: 생산자 fg-loop, 소비자 fg-loop(재개·멤버십 필터)·fg-status(보고+step 0)·fg-ask(경고)·fg-next(all 양보)·fg-merge(halt) — 실제 5개 스킬의 구현과 행 내용이 일치함을 교차 확인.
- **fg-next all 상호작용** ✓ — `skills/fg-next/SKILL.md:63`: loop.md 존재 시 all-mode는 주행하지 않고(이중 승격 방지) 한 줄 알린 뒤 fg-loop에 위임.

**잔여 관찰 [낮음]**: fg-status가 일괄 승급 후의 `retro: <경로> (일괄 승급 <날짜>)` 같은 접미사 달린 값을 읽을 때의 파싱 규칙(`fg-status/SKILL.md:61` "a retro path → O")은 값이 경로로 *시작*하는 형태라 정상 판정될 것으로 보이나, 형식이 fg-learn 쪽에만 예시로 적혀 있고 fg-status는 접미사 가능성을 모른다 — 모델 판단에 맡겨진 느슨한 결합.

---

## 5. 상태 계약 — "추후 fg-learn 일괄 승급" 공수표는 해소: 수신 구현이 생겼다 (record + 신규 미세 드리프트 1건)

구 5번의 문서 간 모순(세 문서가 일괄 승급을 약속하는데 fg-learn은 sealed/skipped를 배제)은 `382c3f8`로 해소됐다 [높음]:

- `skills/fg-learn/SKILL.md:31-39`에 **"Batch promotion mode"** 섹션 신설 — fg-next all(ADR-0010)·fg-loop(ADR-0016)·fg-run skip 경로가 약속한 "수신 측"임을 자기 선언. 진입은 명시적 요청만, 후보 = `done/*/STATUS.md`의 `retro: skipped (...)`, 작업별 대화 리뷰, 승급 바를 넘을 때만 회고 파일 생성(절제 유지), 생성 시 sealed STATUS의 `retro:` 필드를 경로+늦은 승급 주석으로 정정(단 `status: done`은 불변).
- 기본 경로의 두 배제 규칙에 **교차 참조가 양방향으로 달렸다**: `:20` sealed 재회고 = state error "**except through Batch promotion mode below**", `:22` `retro: skipped` 재제시 금지 "becomes reachable again **only through Batch promotion mode below**" ✓.
- 약속하는 쪽도 수신처를 가리킨다: `skills/fg-loop/SKILL.md:79,115`("point to fg-learn for a later batch promotion"), `CLAUDE.md:59` done/ 행("단 `retro: skipped`는 일괄 승급 모드의 후보"), `README.md:22`/`README.ko.md:22` fg-loop 행("later `fg-learn` for batch promotion") ✓.

**신규 미세 드리프트 [낮음]**: 일괄 승급 모드로 fg-learn이 이제 `done/*/STATUS.md`의 `retro:` 필드를 **쓰는** 당사자가 됐는데, `CLAUDE.md:59` 표의 생산자 열은 여전히 fg-done뿐이다(fg-learn은 소비자 열에 후보 자격만 언급). 또 "STATUS.md는 fg-done이 마감한다"는 CLAUDE.md 본문 서술과 sealed STATUS의 사후 정정 사이의 관계는 fg-learn 본문(`:39,113`)에만 적혀 있다. 깨지는 시나리오는 아니나, 표만 보고 편집하는 다음 사람이 이 쓰기 경로를 모를 수 있다.

그 외 결합 지점 구조는 변함없다: `<!-- forge-slug: ... -->` 짝 맞춤, STATUS.md의 `status:`/`verified:`/`retro:` 어휘, fg-status 상태 머신의 단일 정의(fg-next·fg-loop가 참조로 재사용). "계약은 의무 당사자의 본문에 적혀 있어야 한다"는 3차 감사의 교훈이 이번 두 건의 수정 방식 그대로였다 — 패턴이 학습되고 있다는 긍정 신호이되, 신규 표면마다 같은 감사를 반복해야 한다는 비용 구조는 그대로다.

---

## 6. 직전 감사의 record-only 항목 재검증 — 전부 유지

1. **[B5] 유지** — `skills/fg-quick/SKILL.md:46` 템플릿은 한국어 리터럴 `결과: pending`을 보여주면서 LOG 항목은 "사용자 언어로" 쓰라 하고, `skills/fg-merge/SKILL.md:36`은 여전히 리터럴 `결과: pending` 매칭으로 quick-lane in-flight를 판정한다. 영어 사용자의 `Result: pending`이면 halt 가드가 조용히 빠진다 [중간].
2. **[D8] 유지** — `skills/fg-tdd/SKILL.md`는 여전히 자기 근거 ADR-0008을 미인용(인용은 `CLAUDE.md` 1곳뿐). ADR-0004·0013은 스킬·README·CLAUDE.md 어디서도 인용되지 않고, ADR-0001은 README 트리 예시(`adr/0001-*.md`)와 `docs/forge-vs-loop-engineering.md` 대응표에만 등장한다 [높음 — grep 전수 확인].
3. **[F9] 유지** — README 트리거 현지화 이원화: fg-map(`README.md:28` "map the codebase" vs `README.ko.md:28` "코드베이스 분석")과 시작 발화는 언어별 분기, 나머지 대부분(fg-loop 포함: "forge loop", "루프 시작", "조건 충족까지 반복")은 양판 동일 복제. 방침 미통일 그대로.
4. **fg-done skip 경로의 주행 미인지 잔향 유지 [낮음]** — fg-next(`:73` 상당)·fg-loop(`:51`)는 `retro: skipped` 기록을 "fg-done cleanup-time 경로가 쓴다"고 귀속을 명시하지만, 의무 당사자인 `skills/fg-done/SKILL.md:29`의 그 경로는 여전히 "If the **user** explicitly chooses to skip"이라고만 적혀 있어 오케스트레이터 주행(fg-next all·fg-loop)을 모른다.

---

## 7. 이중 파일 구조의 드리프트 표면 — 변함없이 유지

- **`skills/fg-ask/SKILL.md`**: 영문 verbatim 본문 + 말미 "Forge integration (minimal)" 섹션의 분리 구조 그대로. 이번 (1b) 추가는 Forge integration 섹션 안에 들어가 verbatim 영역은 안 건드렸다 ✓. plan 형식 정의가 소비자(`skills/fg-run/PLAN-FORMAT.md`) 쪽에 있는 비대칭도 그대로.
- **`skills/fg-run/RUN-ALL.md`**: 분리 자체의 드리프트 표면 유지.
- **`skills/fg-run/FORGE-ROOT.md`**: 브랜치별 루트의 단일 정의. **13개 스킬 전부** 참조 유지(`grep -l FORGE-ROOT skills/*/SKILL.md` → 13파일). 전역 예외 2개의 3중 서술(fg-tdd·fg-map 각자 재설명)도 그대로.

---

## 8. README.md / README.ko.md 이중 언어 동기화 — 자동 검사 없음

이번 변경분(fg-loop 표 행의 "일괄 승급" 문구, 28행 장문 서술)이 양판에 나란히 들어가 동기화 유지를 확인했다. 그러나 검사 도구가 없어 한쪽만 고치면 조용히 어긋난다. 28행 한 단락에 스킬 9개 서술이 전부 들어 있는 구조는 부분 수정 시 특히 어긋나기 쉽다.

---

## 9. 자동 테스트가 전무 — 의미적 깨짐은 사람만 잡는다

빌드·테스트·린트·CI 없음(변함없음). 검증 수단은 매니페스트 JSON 파싱 한 줄과 실제 설치 후 트리거뿐이고, 후자는 interactive라 에이전트 불가. 이번 사이클은 긍정적 데이터다 — 직전 지도가 지목한 행동 계약 격차(구 4·5번)가 **하루 안에 전부 수정·커밋·push**됐다. 그러나 그 수정을 잡은 것도 사람(코드베이스 감사)이지 도구가 아니며, 6번의 잔존 항목들(B5 리터럴 매칭, fg-done 주행 미인지)은 여전히 어떤 자동 도구도 못 잡는다.

---

## 10. 스킬 본문 비대화 — 계약 격차를 메울 때마다 자란다

`skills/fg-run/SKILL.md` **27,654자**(변동 없음), `skills/fg-done/SKILL.md` 17,941자(변동 없음), `skills/fg-ask/SKILL.md` **16,894자**(+552, (1b) 추가), `skills/fg-next/SKILL.md` **15,955자**(+480, all-mode 양보 추가), `skills/fg-learn/SKILL.md` **13,731자**(일괄 승급 모드 추가), `skills/fg-loop/SKILL.md` **13,326자**(+1,210, 멤버십 추가). 이번 사이클이 패턴을 그대로 보여준다 — **계약 격차 6건을 메우는 비용이 곧 5개 스킬 본문의 증가**였다. 게이트·복구 경로가 추가될 때마다 본문이 자라고, 비대해지면 분리(progressive disclosure)가 필요해지는데 그 분리는 7번의 드리프트 표면을 하나씩 늘린다. 구조적 트레이드오프이며 감시 장치 없음.

---

## 11. 기타 관찰 (경미)

- **`docs/forge-vs-loop-engineering.md`의 낡음 유지·심화** — 여전히 "검토일 2026-06-11, forge v0.4.4 기준"·"forge 자체가 12개 fg-* 스킬"(`:15`)이고, "유일한 갭(Automations)은 도입하지 않기로 했다"는 결론 그대로다. 그 갭을 메우는 fg-loop가 이미 v0.4.8로 배포됐으므로(ADR-0016이 이 문서를 맥락으로 인용) 상단에 "이후 fg-loop로 구현됨" 한 줄이 없으면 독자가 현황으로 오독한다 [높음 — 파일 직접 확인].
- **`.forge/branch/` 빈 디렉터리 잔존** — `c8ea281`의 fg-merge가 `branch/loop/`를 제거하며 상위 `branch/` 빈 폴더를 남겼다(`find .forge/branch -type f` → 없음). 동작 영향 없음(gitignore가 `!.forge/branch/`로 화이트리스트하지만 빈 폴더는 git이 추적 안 함) [낮음].
- **'loop'라는 단어의 과적 유지** — 플러그인 태그라인이 "development loop"(ask→run→learn→done)인데 스킬 이름이 fg-**loop**이고 트리거가 "루프 시작"이다. 정식 루프를 시작하려는 사용자의 "루프 시작" 발화가 fg-ask가 아닌 fg-loop로 갈 수 있다 [낮음 — 트리거 라우팅은 모델 판단이라 검증 불가, 어휘 충돌 자체는 사실].
- **`.gitignore`의 `.planning/`·`!.planning/codebase/` 잔재 유지** — `.planning/` 디렉터리는 없다. 동작 위험은 없지만 "정리" 손길을 부르는 함정인 점 그대로.
- **현재 루프 상태는 깨끗하다** — 활성 슬롯·`.forge/backlog/`·`.forge/executed/`·`.forge/loop.md` 모두 없음, `done/` 39건. 상태 계약 기준 이상 없음.

---

## 우선순위 요약

| # | 우려 | 깨질 때 증상 | 자동 검출 |
| --- | --- | --- | --- |
| 1 | 버전 3곳 동기화(현재 0.4.8 정합) + 릴리스 후 커밋 3건 미범프 | 설치/업데이트 실패 / 0.4.8 라벨에 신규 내용 | JSON 유효성만(일치 검사 X) |
| 2 | 스킬 개수·목록 하드코딩 ≥6곳(현재 전부 정합, C5 해소) | 문서가 스킬 현실과 어긋남(과거 fg-tdd 누락 실증) | **없음** |
| 3 | frontmatter `name` 오타 / fg-next desc 1,084자 | 스킬 조용히 미탐색 / description 잘림 가능 | `awk`로 누락만 |
| 5 | 일괄 승급 해소 후 잔여: CLAUDE.md 표 생산자 열에 fg-learn 누락 | 표만 보고 편집 시 sealed STATUS 쓰기 경로 누락 | **없음** |
| 6 | record-only 잔존(B5 리터럴 매칭·D8 무인용 ADR·F9 트리거 방침·fg-done 주행 미인지) | fg-merge 가드 누락, 근거 추적 단절 | **없음** |
| 7 | 이중 파일 드리프트(fg-ask verbatim·RUN-ALL·FORGE-ROOT 예외 3중) | 핸드오프/Run-all/루트 해석 분기 | **없음** |
| 8 | README 이중 언어 동기화 | 두 문서 어긋남 | **없음** |
| 9 | 자동 테스트 전무 | 의미적 계약 깨짐을 사람만 잡음 | **없음** |
| 10 | 스킬 본문 비대화(fg-run 27.7KB, 이번 사이클 5개 스킬 증가) | 컨텍스트 비용 → 분리 → 드리프트 표면 증가 | **없음** |
| 11 | docs 검토 문서 낡음(12스킬·Automations 미도입 결론) / 'loop' 어휘 과적 / .gitignore 잔재 | 독자 오독, 트리거 오라우팅 | **없음** |

**관통하는 진실**: 직전 지도의 상위 3건(미커밋 분기·fg-learn 공수표·loop.md 인지 격차 6건)이 한 사이클 만에 전부 해소된 것은 "지도 → 감사 → 수정"의 루프가 작동한다는 증거다. 그러나 해소 방식이 전부 **스킬 본문에 산문을 더 적는 것**이었고(10번), 그 산문의 정합은 여전히 어떤 도구도 검사하지 않는다(9번). 신규 표면(일괄 승급 모드)이 또 하나의 미세 드리프트(CLAUDE.md 표 생산자 열)를 남긴 것이 패턴의 반복이다 — 산문 동기화는 규율로 막아도, 스킬 간 행동 계약은 감사 없이는 샌다. 관련 결정: ADR-0002(회고 스킵)·0009(검증 게이트)·0010(fg-next all)·0011(브랜치 루트)·0012(fg-cleanup)·0014(fg-eco)·0015(핸드오프 형태)·0016(fg-loop, 개정 2026-06-12).
