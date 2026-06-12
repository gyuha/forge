---
last_mapped_commit: b45521cd5fc2f536cc212e559af52c3939a5b0a5
mapped: 2026-06-12
---

# CONCERNS — 이 플러그인의 실제 취약점

forge는 런타임 코드가 없는 Claude Code 플러그인이다 — Markdown 스킬(`skills/*/SKILL.md`)과 JSON 매니페스트(`.claude-plugin/*.json`)뿐이다. 따라서 "버그"는 컴파일 에러가 아니라 **설치 실패, 스킬 미탐색, 스킬 간 상태 계약 단절, 문서 드리프트** 형태로 나타난다. 컴파일러·테스트가 잡아주지 않으므로 전부 사람이 편집 규율로 막아야 한다. 아래는 각 항목을 **현재 작업 트리**(HEAD `b45521c` = v0.4.7, origin/main과 동기 + 미커밋 fg-loop 기능 전체)에 대고 검증한 결과다. 직전 지도(v0.4.5 시점) 이후 3차 감사 수정 8건은 전부 커밋·배포됐고(`cc9c063`), 13번째 스킬 **fg-loop**(goal 주도 한정 재계획 루프, ADR-0016)가 새로 추가됐다 — 단 전부 미커밋 상태다.

---

## 0. fg-loop 기능 전체가 미커밋 — 그리고 같은 버전 번호 아래 내용이 갈라져 있다

`git status` 기준 미커밋 더미: 신규 untracked 3건(`skills/fg-loop/`, `.forge/adr/0016-fg-loop-goal-driven-bounded-replan.md`, `.forge/retro/2026-06-12-add-fg-loop.md`) + 수정 6파일(`.claude-plugin/plugin.json`·`marketplace.json`, `CLAUDE.md`, `README.md`·`README.ko.md`, `skills/fg-status/SKILL.md`). 설치는 GitHub main을 당기므로 **커밋+push 전까지 설치된 플러그인에는 fg-loop가 없고, fg-status의 loop.md 인지(step 0)도 없다.**

더 미묘한 문제: **로컬과 원격이 같은 `0.4.7`인데 내용이 다르다.** 커밋된 v0.4.7 매니페스트는 "Twelve fg-* skills"(fg-loop 없음)이고, 작업 트리의 매니페스트는 같은 버전 번호 그대로 "Thirteen"으로 고쳐져 있다(`git show HEAD:.claude-plugin/plugin.json`으로 확인). 즉 **버전 범프(0.4.8)가 아직 안 된 채 릴리스 내용이 쌓이는 중**이다 — CLAUDE.md 배포 규칙의 "미커밋 변경이 곧 릴리스 내용이면 feat 커밋 → 릴리스 절차" 경로가 다음에 반드시 돌아야 한다. (참고: `.forge/codebase/STACK.md`도 수정 중인데 이는 진행 중인 코드베이스 재매핑의 일부다.)

직전 지도의 0번(3차 감사 수정 미커밋)은 해소됐다 — 8건 전부 `cc9c063`로 커밋·배포됐고, fg-done의 커밋 상기 장치(E10)도 이제 발효 상태다.

---

## 1. 매니페스트 버전이 3곳에 흩어져 있다 — 어긋나면 설치 깨짐, 자동 검사 없음

버전 문자열이 세 군데에 중복되며 반드시 동기화되어야 한다:

- `.claude-plugin/plugin.json` → `version` (현재 `0.4.7`)
- `.claude-plugin/marketplace.json` → `metadata.version` (현재 `0.4.7`)
- `.claude-plugin/marketplace.json` → `plugins[0].version` (현재 `0.4.7`)

세 값의 일치와 JSON 파싱 유효성은 확인했다. 그러나 리포의 검증 도구는 JSON 파싱뿐이고 **세 버전이 같은지는 어떤 도구도 검사하지 않는다**. 0번이 보여주듯 "버전은 같은데 내용이 다른" 상태도 못 잡는다. `CLAUDE.md` 배포 규칙이 "3곳 동기 갱신"을 사람 절차로 강제하는 것이 유일한 방어다.

---

## 2. 스킬 개수·목록이 산문에 하드코딩 ≥6곳 — 이번 13번째 추가는 6곳 모두 정확히 갱신됐다 (이번엔)

스킬 개수와 전체 목록이 서로 다른 문장 구조의 산문 여러 벌에 박혀 있다. fg-loop 추가에 맞춰 전 지점이 `thirteen`/`nine`(13개/9개)으로 갱신됐음을 각각 확인했다:

- `marketplace.json` `plugins[0].description` — "Thirteen fg-* skills … Nine more sit outside the loop" + fg-loop 서술 포함 ✓
- `plugin.json` `description` — 13개 스킬 전부 열거(fg-loop 포함) ✓
- `README.md:4` "thirteen … nine utilities" / `README.ko.md:4` "13개 … 9개" — 9개 유틸 괄호 나열에 fg-loop 포함 ✓
- `README.md:28` / `README.ko.md:28` — 루프 밖 9개 스킬 장문 서술에 fg-loop 단락 추가 ✓
- `CLAUDE.md:44` "루프 밖 스킬" 단락 — fg-loop 서술 추가 ✓

작업 트리에 stale한 "twelve/eight/12개/8개" 잔재는 없다(`grep` 전수 확인). `metadata.description`은 루프 태그라인 그대로이고 fg-loop를 넣지 않았다 — "루프 밖 유틸은 metadata 제외" 규칙 준수 ✓. **그러나 구조적 위험은 그대로다**: 직전 12스킬 체제에서 CLAUDE.md의 fg-tdd 통누락이 실제로 발생했었고(3차 감사 A1), 14번째 스킬이 오면 또 최소 6지점을 손으로 동시에 고쳐야 하며 자동 검출은 없다.

---

## 3. 스킬은 frontmatter `name`으로 자동 탐색 — 틀리면 조용히 사라진다; fg-next description은 여전히 한도 초과 의심

`plugin.json`에 `skills` 필드가 없어 `skills/`가 자동 탐색되고, 식별자는 디렉터리명이 아니라 `SKILL.md` frontmatter의 `name`이다. **13개 스킬 전부**(fg-loop 포함) 디렉터리명과 `name` 일치를 확인했다. `name`을 빠뜨리거나 오타 내면 그 스킬은 에러 없이 그냥 탐색에서 빠진다. 배포 전 점검 `awk '/^name:/' skills/*/SKILL.md`는 누락만 잡고 오타는 못 잡는다.

frontmatter `description` 길이: `skills/fg-next/SKILL.md`가 **약 1,084자**로 직전 지도와 동일하게 흔히 문서화되는 권장 한도(약 1,024자)를 넘는 유일한 스킬이다 [중간 — 한도 수치·강제 여부는 공식 문서 재확인 필요]. 신규 `skills/fg-loop/SKILL.md`는 약 687자로 여유 있고, 나머지도 325–673자 범위다.

---

## 4. 신규 상태 표면 `.forge/loop.md` — 생산자(fg-loop)는 적었는데 주변 스킬들이 모른다

fg-loop는 goal 계약을 `.forge/loop.md`(휘발, fg-loop 소유)에 쓰고, goal 충족 시 삭제·벽에서는 유지한다. 이 새 표면에 대한 인지가 스킬마다 갈라져 있다 — 5번(계약은 의무 당사자에게)의 신규 발화점 후보들이다:

- **fg-status는 안다** ✓ — `skills/fg-status/SKILL.md:23`(조사 대상), `:35`(출력 한 줄), `:78`(상태 머신 step 0: loop.md 존재 → fg-loop 재개 라우팅). 미커밋이지만 작업 트리 기준 정합.
- **fg-next는 간접으로만 안다** — fg-status의 상태 머신을 참조로 재사용하므로 step 0을 통해 fg-loop로 라우팅은 되지만, `skills/fg-next/SKILL.md`의 invoke 매핑(§2: 기계적=fg-run/fg-done, 대화형=fg-ask/fg-learn)에 fg-loop가 없고, **`fg-next all`을 loop.md 존재 중에 치면 어떻게 되는지가 미정의**다 — 도출이 매번 "fg-loop 재개"를 반환하므로 all 모드 드라이브가 통째로 fg-loop에 위임되는 셈인데 그 상호작용을 어느 쪽 문서도 다루지 않는다 [중간].
- **fg-ask는 모른다** — `skills/fg-ask/SKILL.md`의 "Before starting: check for existing work" (1)은 활성 슬롯 run.md와 `executed/`만 본다. **벽에서 멈춘 루프(loop.md 존재, 슬롯·백로그는 깨끗할 수 있음 — 예: 상한 소진)는 무경고 통과**되고, 더 위험하게는 fg-ask가 새로 적재한 정식 루프용 backlog plan이 **fg-loop 재개 시 무필터로 자동 주행된다** — `skills/fg-loop/SKILL.md` §2의 드라이브는 "promote the next backlog task"로 백로그 소속을 가리지 않는다(자기가 만든 plan인지 사람이 그릴링한 plan인지 구분 없음). 회고 자동 skip까지 따라붙는다 [높음 — 루프가 벽에서 며칠 묵으면 충분히 일어날 시나리오].
- **fg-merge도 모른다** — `skills/fg-merge/SKILL.md`의 in-flight halt 목록은 활성 슬롯·`executed/`·quick `결과: pending`뿐이다. 브랜치 루트에 halted loop.md가 남아 있어도 halt 없이 통합이 진행되고, 마지막의 브랜치 폴더 제거와 함께 **goal 계약(체크 상태·재계획 라운드)이 조용히 소실된다** [중간 — 시나리오는 드물지만 소실은 무경고].
- **`<!-- generated-by: fg-loop -->` 마커는 읽는 곳이 없다** — `skills/fg-loop/SKILL.md:62`는 "so fg-status and the audit trail show its origin"이라 주장하지만, `skills/fg-status/SKILL.md`에는 generated-by를 읽거나 표시하는 규칙이 한 줄도 없다(`grep` 확인 — 마커 언급은 fg-loop 자신·ADR-0016·README 표 두 곳뿐). 생산자가 존재하지 않는 소비자를 전제한 채 적힌 계약이다 [중간].
- **CLAUDE.md 상태 계약 표에 loop.md 행이 없다** — `CLAUDE.md:44` 단락은 fg-loop를 서술하지만 "상태 계약" 표(파일/생산자/소비자)는 6행 그대로다. loop.md는 fg-loop가 쓰고 fg-status가 읽는 다중 당사자 휘발 상태이므로 표의 누락은 다음 편집자가 이 표면을 모르고 깨기 좋은 드리프트다 [중간].

---

## 5. 상태 계약 — 계약은 의무 당사자에게 적혀 있어야 한다; **"추후 fg-learn 일괄 승급" 경로는 수신 구현이 없다**

스킬들은 독립 실행되며 오직 `.forge/` 파일로 상태를 주고받는다. `<!-- forge-slug: ... -->` 짝 맞춤, STATUS.md의 `status:`/`verified:`/`retro:` 어휘, fg-status 상태 머신의 단일 정의(fg-next·이제 fg-loop도 재사용)가 결합 지점이라는 구조는 변함없다. 3차 감사의 교훈("계약은 그것을 지켜야 하는 스킬의 본문에 적혀 있어야 한다")도 그대로 유효한데, **이번 검증에서 그 패턴의 미해결 사례를 새로 확인했다**:

`fg-next all`(ADR-0010)·fg-loop(ADR-0016)·fg-run의 회고 skip 경로는 모두 "**학습은 아카이브된 run.md에 보존, 추후 사람이 fg-learn으로 일괄 승급**"을 약속한다(`skills/fg-next/SKILL.md:73,85`, `skills/fg-loop/SKILL.md:75,107,111`). 그런데 정작 `skills/fg-learn/SKILL.md`는 정반대로 동작한다 — `:20` "sealed STATUS.md(`status: done`)인 작업의 재회고는 state error로 표면화", `:22` "`retro: skipped`인 작업은 후보에서 제외(do not re-offer)". 즉 **fg-loop의 핸드오프를 따라 나중에 fg-learn을 연 사용자는, 승급하라던 그 작업들이 후보에서 배제되는 모순**을 만난다. 일괄 승급 모드(봉인된 작업의 run.md를 회고 후보로 명시 재허용하는 경로)가 fg-learn에 없는 한 이 약속은 공수표다 [높음 — 세 문서가 같은 약속을 반복하므로 가설이 아니라 문서 간 모순].

---

## 6. 직전 감사의 record-only 항목 재검증 — 2건 해소, 3건 유지

1. **[E4] 해소** — Run-all 배치 핸드오프의 질문형("which first?")은 `802076b`(ADR-0015 개정)로 진술형으로 고쳐졌다. `skills/fg-run/RUN-ALL.md:15`가 명시적으로 "do not ask … 'which first?'" + "'Which task first?' is fg-learn's own question"으로 단일 정의 위임까지 못 박았다.
2. **[B4] 해소** — fg-next all의 `retro: skipped` 기록 주체 모호는 `skills/fg-next/SKILL.md:73`이 "**the write itself happens inside the delegated done stage**: fg-done records … via its cleanup-time skip path"로 귀속을 명시해 풀렸고, fg-loop도 같은 귀속을 따른다(`skills/fg-loop/SKILL.md:47,117`). 다만 의무 당사자인 `skills/fg-done/SKILL.md:29`의 해당 경로는 여전히 "If the **user** explicitly chooses to skip"이라고만 적혀 있어 오케스트레이터 주행을 모른다 — 5번 패턴의 잔향 [낮음].
3. **[B5] 유지** — `skills/fg-quick/SKILL.md`는 LOG 항목을 "in the user's language"로 쓰라면서 템플릿은 한국어 리터럴 `결과: pending`을 보여주고, `skills/fg-merge/SKILL.md:36`은 여전히 리터럴 `결과: pending` 매칭으로 in-flight를 판정한다. 영어 사용자의 `Result: pending`이면 halt 가드가 조용히 빠진다.
4. **[D8] 유지** — `skills/fg-tdd/SKILL.md`는 여전히 자기 근거 ADR-0008을 미인용(인용은 `CLAUDE.md` 1곳뿐). **ADR-0004·0013은 어느 스킬·README·CLAUDE.md에서도 인용되지 않고**, ADR-0001은 README 트리 예시(`adr/0001-*.md`)로만 등장한다. 신규 ADR-0016은 fg-loop·README 양판·CLAUDE.md가 인용해 정합 ✓.
5. **[F9] 유지** — README 트리거 현지화 이원화: fg-map(`README.md:28` "map the codebase" vs `README.ko.md:28` "코드베이스 분석")과 시작 발화(`README.md:87` "start with forge" vs `README.ko.md:86` "forge로 시작")는 언어별 분기, 나머지 대부분은 양판 동일 복제. 신규 fg-loop 트리거("forge loop", "루프 시작", "조건 충족까지 반복")는 양판 동일 복제 패턴을 따랐다 — 방침 미통일 상태에서 다수파 패턴이 한 표 더 쌓인 셈.

---

## 7. 이중 파일 구조의 드리프트 표면 — 변함없이 유지

- **`skills/fg-ask/SKILL.md`**: 영문 verbatim 본문 + 말미 "Forge integration (minimal)" 섹션의 분리 구조 그대로. plan 형식 정의가 소비자(`skills/fg-run/PLAN-FORMAT.md`) 쪽에 있는 비대칭도 그대로 — fg-loop가 새로 PLAN-FORMAT·fg-ask 그릴링 방법을 **참조로** 재사용해(`skills/fg-loop/SKILL.md:18,41,47` — 복붙 없음) 이 표면을 늘리지는 않았다 ✓.
- **`skills/fg-run/RUN-ALL.md`**: "Behavior is unchanged" 선언은 ADR-0015 개정 반영 과정에서 문구가 갱신됐고(6-1), 분리 자체의 드리프트 표면은 유지.
- **`skills/fg-run/FORGE-ROOT.md`**: 브랜치별 루트의 단일 정의. **13개 스킬 전부**가 참조함을 확인(`grep -c FORGE-ROOT skills/*/SKILL.md` → 13/13, fg-loop도 `:14`에서 참조). 전역 예외 2개의 3중 서술(fg-tdd·fg-map이 각자 재설명)도 그대로.

---

## 8. README.md / README.ko.md 이중 언어 동기화 — 자동 검사 없음

fg-loop 추가분(4행 태그라인, 22행 표, 28행 장문 서술)이 양판에 나란히 들어가 동기화가 유지됨을 확인했다. 그러나 검사 도구가 없어 한쪽만 고치면 조용히 어긋난다. 이번처럼 28행짜리 거대 단락 하나에 스킬 9개 서술이 전부 들어 있는 구조는 특히 부분 수정 시 어긋나기 쉽다.

---

## 9. 자동 테스트가 전무 — 의미적 깨짐은 사람만 잡는다

빌드·테스트·린트·CI 없음(변함없음). 검증 수단은 매니페스트 JSON 파싱 한 줄과 실제 설치 후 트리거뿐이고, 후자는 interactive라 에이전트 불가·설치는 origin main을 당기므로 미푸시 상태는 검증 자체가 불가능하다. 4번의 loop.md 인지 격차, 5번의 fg-learn 모순, 3번의 `name` 오타는 어떤 자동 도구도 잡지 못한다. 사흘간 3차례의 정합 감사가 매번 실드리프트를 잡아냈고, 이번 매핑에서도 신규 스킬 하나가 4번·5번급 격차 여럿을 만들었다 — 드리프트 발생 속도가 편집 규율을 앞선다는 증거가 또 쌓였다.

---

## 10. 스킬 본문 비대화 — 분리해도 다시 자란다

`skills/fg-run/SKILL.md`는 **27,654자**로 또 자랐다(직전 지도 26,571자 → 4지 메뉴 개정분; RUN-ALL 분리 직전의 28,061자에 근접). `skills/fg-done/SKILL.md` 17,941자, `skills/fg-ask/SKILL.md` 16,342자, `skills/fg-next/SKILL.md` 15,475자, 신규 `skills/fg-loop/SKILL.md` 12,116자. 게이트·복구 경로가 추가될 때마다 본문이 자라고, 비대해지면 분리(progressive disclosure)가 필요해지는데 그 분리는 7번의 드리프트 표면을 하나씩 늘린다. 구조적 트레이드오프이며 감시 장치 없음.

---

## 11. 기타 관찰 (경미)

- **`docs/forge-vs-loop-engineering.md`가 커밋됐으나(`d0ef253`) 내용이 낡았다** — "검토일 2026-06-11, forge v0.4.4 기준"이고, fg-loop가 메우기로 한 "유일한 미구현 패턴"을 전제로 쓰였는데 그 패턴이 이제 구현됐다(ADR-0016이 이 문서를 맥락으로 인용). 역사 문서로 두려면 상단에 "이후 fg-loop로 구현됨" 한 줄이 없으면 독자가 현황으로 오독한다.
- **'loop'라는 단어의 과적** — 플러그인 태그라인이 "development loop"(ask→run→learn→done)인데 신규 스킬 이름이 fg-**loop**이고 트리거가 "루프 시작"이다. 정식 루프를 시작하려는 사용자의 "루프 시작" 발화가 fg-ask가 아닌 fg-loop로 갈 수 있다 [낮음 — 트리거 라우팅은 모델 판단이라 검증 불가, 어휘 충돌 자체는 사실].
- **`.gitignore`의 `.planning/`·`!.planning/codebase/` 잔재** — `.planning/` 디렉터리는 없다. 동작 위험은 없지만 `.forge/` 화이트리스트 비대칭(ADR-0011)과 나란히 있어 "정리" 손길을 부르는 함정인 점 그대로.
- **현재 루프 상태는 깨끗하다** — 활성 슬롯·`.forge/backlog/`·`.forge/executed/`·`.forge/loop.md` 모두 없음, `done/` 36건. 상태 계약 기준 이상 없음.

---

## 우선순위 요약

| # | 우려 | 깨질 때 증상 | 자동 검출 |
| --- | --- | --- | --- |
| 0 | fg-loop 기능 전체 미커밋 + 같은 0.4.7 아래 내용 분기 | 설치본에 fg-loop 없음 / 버전 같은데 내용 다름 | `git status`로만 |
| 5 | "추후 fg-learn 일괄 승급" 약속 vs fg-learn의 skipped·done 배제 — 문서 간 모순 | auto-skip된 회고의 학습이 영영 승급 불가 | **없음** |
| 4 | loop.md 신규 표면의 인지 격차(fg-ask 무경고·백로그 무필터 주행 / fg-merge 소실 / generated-by 무소비 / CLAUDE.md 표 누락 / fg-next all 상호작용 미정의) | 사람 plan이 자동 주행됨, goal 계약 소실, 마커 사문화 | **없음** |
| 1 | 버전 3곳 동기화 | 설치/업데이트 실패 | JSON 유효성만(일치 검사 X) |
| 2 | 스킬 개수·목록 하드코딩 ≥6곳(이번엔 전부 정합) | 문서가 스킬 현실과 어긋남(과거 fg-tdd 누락 실증) | **없음** |
| 3 | frontmatter `name` 오타 / fg-next desc ~1,084자 | 스킬 조용히 미탐색 / description 잘림 가능 | `awk`로 누락만 |
| 6 | record-only 잔존 3건(B5·D8·F9) + fg-done skip 경로의 주행 미인지 | fg-merge 가드 누락, 무인용 ADR, 트리거 방침 부재 | **없음** |
| 7 | 이중 파일 드리프트(fg-ask verbatim·RUN-ALL·FORGE-ROOT 예외 3중) | 핸드오프/Run-all/루트 해석 분기 | **없음** |
| 8 | README 이중 언어 동기화 | 두 문서 어긋남 | **없음** |
| 10 | 스킬 본문 재비대화(fg-run 27.7KB, fg-loop 12.1KB 신규) | 컨텍스트 비용 → 분리 → 드리프트 표면 증가 | **없음** |

**관통하는 진실**: 대부분 자동 검출 불가이며, 안전망은 `CLAUDE.md` 편집 규율 + 주기적 정합 감사 + 사람의 설치-트리거 검증뿐이다. 이번 fg-loop 추가는 개수 하드코딩 6곳을 전부 정확히 갱신하는 데는 성공했지만, 대신 **새 상태 표면(loop.md·generated-by) 주변의 계약 격차**와 **fg-learn 일괄 승급 모순**이라는 더 깊은 층의 드리프트를 만들었다 — 산문 동기화는 규율로 막아도, 스킬 간 행동 계약은 감사 없이는 샌다. 관련 결정: ADR-0002(회고 스킵)·0009(검증 게이트)·0010(fg-next all)·0011(브랜치 루트)·0012(fg-cleanup)·0014(fg-eco)·0015(핸드오프 형태)·0016(fg-loop).
