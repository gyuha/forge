---
last_mapped_commit: 847fa4208a8ef8b709da41d36d106a3f3f92af29
mapped: 2026-06-11
---

# CONCERNS — 이 플러그인의 실제 취약점

forge는 런타임 코드가 없는 Claude Code 플러그인이다 — Markdown 스킬(`skills/*/SKILL.md`)과 JSON 매니페스트(`.claude-plugin/*.json`)뿐이다. 따라서 "버그"는 컴파일 에러가 아니라 **설치 실패, 스킬 미탐색, 스킬 간 상태 계약 단절, 문서 드리프트** 형태로 나타난다. 컴파일러·테스트가 잡아주지 않으므로 전부 사람이 편집 규율로 막아야 한다. 아래는 각 항목을 **현재 작업 트리**(HEAD `847fa42` = v0.4.5, origin/main과 동기 + 미커밋 감사 수정분)에 대고 검증한 결과다. 오늘(2026-06-11) 3차 정합 감사(`.forge/done/2026-06-11-consistency-audit-3/run.md`)가 47건을 훑어 8건을 고치고 5건을 기록만 해뒀다 — 그 5건은 6번에 열린 우려로 올린다.

---

## 0. 오늘 감사의 수정 8건이 전부 미커밋 — 설치본에는 아직 없다

HEAD(`847fa42`)는 origin/main과 일치하지만(이전 지도의 "커밋됨·미푸시" 우려는 해소), **3차 감사의 fix-now 8건이 통째로 작업 트리에만 있다**: `CLAUDE.md`(fg-tdd 누락 복구), `README.md`/`README.ko.md`(+`adr/retired/` 트리 한 줄), `skills/fg-done/SKILL.md`(커밋 상기), `skills/fg-learn/SKILL.md`(STATUS 불간섭 계약), `skills/fg-next/SKILL.md`(ADR-0015 stale 문구), `skills/fg-status/SKILL.md`(case 3 회고 라우팅 + Retro 열 규칙). 회고 파일 `.forge/retro/2026-06-11-consistency-audit-3.md`와 `docs/forge-vs-loop-engineering.md`도 **untracked**다. 설치는 GitHub main을 당기므로, **커밋+push 전까지 설치된 플러그인은 감사 이전 내용으로 동작한다** — 예: 설치본 fg-status는 sealable parked 작업을 회고가 끝났어도 fg-learn으로 보낸다(B1 수정 전). 얄궂게도 "영속 문서 미커밋 시 커밋 상기" 장치(E10, 아래 7번) 자체가 이 미커밋 더미 안에 있다.

---

## 1. 매니페스트 버전이 3곳에 흩어져 있다 — 어긋나면 설치 깨짐, 자동 검사 없음

버전 문자열이 세 군데에 중복되며 반드시 동기화되어야 한다:

- `.claude-plugin/plugin.json` → `version` (현재 `0.4.5`)
- `.claude-plugin/marketplace.json` → `metadata.version` (현재 `0.4.5`)
- `.claude-plugin/marketplace.json` → `plugins[0].version` (현재 `0.4.5`)

세 값의 일치는 확인했다. 그러나 리포의 검증 도구는 JSON 파싱 유효성뿐이고 **세 버전이 같은지는 어떤 도구도 검사하지 않는다**. 배포 후 원격 main의 일치는 `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`로만 사후 확인 가능하다(`/plugin install`은 interactive라 에이전트가 못 돌린다). `CLAUDE.md` 배포 규칙이 "3곳 동기 갱신"을 사람 절차로 강제하는 것이 유일한 방어다.

---

## 2. 스킬 개수·목록이 산문에 하드코딩 — 오늘 감사가 실제 드리프트를 잡았다

스킬 개수와 전체 목록이 **서로 다른 문장 구조의 산문 여러 벌**에 박혀 있다:

- `marketplace.json` `plugins[0].description` — "Twelve fg-* skills … Eight more sit outside the loop" + 8개 유틸 서술
- `plugin.json` `description` — 12개 스킬명을 전부 직접 나열(개수 단어는 없으나 열거가 곧 목록)
- `README.md:4` — "twelve … eight utilities" + 8개 스킬명 괄호 나열, `README.ko.md:4` — "12개 … 8개" 동형
- `README.md:27` / `README.ko.md:27` — 루프 밖 8개 스킬 각각의 장문 서술 + 트리거 목록
- `CLAUDE.md` "루프 밖 스킬" 단락 — 8개 유틸 열거

**이 위험은 가설이 아니다.** 오늘 3차 감사(A1)가 `CLAUDE.md`에서 **fg-tdd가 통째로 빠져 있던 것**을 발견했다 — 12스킬 체제(v0.4.3에서 fg-tdd, v0.4.4에서 fg-eco 추가)인데 CLAUDE.md만 7개 유틸을 열거하고 있었다. 수정됐지만(미커밋, 0번), 구조적 원인은 그대로다: **13번째 스킬을 추가하면 최소 위 6지점을 손으로 동시에 고쳐야 하고, 자동 검출은 없다.** `marketplace.json`의 `metadata.description`은 루프 태그라인이라 유틸을 안 넣는 것이 규칙(`CLAUDE.md` 배포 규칙)인데, 이 역할 분리도 사람만 지킨다.

---

## 3. 스킬은 frontmatter `name`으로 자동 탐색 — 틀리면 조용히 사라진다; fg-next description은 한도 초과 의심

`plugin.json`에 `skills` 필드가 없어 `skills/`가 자동 탐색되고, 식별자는 디렉터리명이 아니라 `SKILL.md` frontmatter의 `name`이다. 12개 스킬 전부 디렉터리명과 `name` 일치를 확인했다(fg-ask·fg-cleanup·fg-done·fg-eco·fg-learn·fg-map·fg-merge·fg-next·fg-quick·fg-run·fg-status·fg-tdd). `name`을 빠뜨리거나 오타 내면 그 스킬은 **에러 없이 그냥 탐색에서 빠진다.** 배포 전 점검은 `awk '/^name:/' skills/*/SKILL.md`(CLAUDE.md 배포 규칙)로 누락만 잡는다 — 오타는 못 잡는다.

추가: `skills/fg-next/SKILL.md`의 frontmatter `description`이 **약 1,084자**로, 이전 지도 시점(1,038자)보다 더 자랐고 흔히 문서화되는 권장 한도(약 1,024자)를 넘는다 [중간 — 한도 수치·강제 여부는 공식 문서 재확인 필요]. 나머지 11개는 352–709자로 여유 있다. fg-next에 서술을 더할 때마다 이 경계가 위태로워진다.

---

## 4. 이중 파일 구조의 드리프트 표면 — fg-ask verbatim 분리, fg-run의 RUN-ALL 분리

같은 스킬의 행동 규칙이 두 파일(또는 두 구역)에 걸쳐 살고, 한쪽만 고치면 갈라진다:

- **`skills/fg-ask/SKILL.md`(105줄)**: 1–89줄은 grill-with-docs 원본의 **영문 verbatim**(손대지 않는 영역), 90줄~ `## Forge integration (minimal)` 섹션에만 forge 루프 연결(백로그 산출 마커, slug 충돌 검출, 핸드오프)이 산다. `CLAUDE.md`가 "알려진 불일치"로 명시한 구조다. plan 형식 정의(`PLAN-FORMAT.md`)가 생산자(fg-ask)가 아닌 소비자(fg-run) 디렉터리에 있는 비대칭도 이 verbatim 규칙의 부산물이다 — 모르고 fg-ask 쪽에 형식을 새로 쓰면 정의가 둘로 갈라진다.
- **`skills/fg-run/SKILL.md` + `skills/fg-run/RUN-ALL.md`**: Run-all 절차가 progressive disclosure로 분리됐고, RUN-ALL.md 헤더가 "**Behavior is unchanged** from when this lived inline"이라고 선언한다. 이 선언 탓에 RUN-ALL.md의 문구 수정 = 곧 행동 변경이 되어, 아래 6-1(E4)의 ADR-0015 회색지대를 기계적으로 못 고치는 잠금 효과까지 생겼다.
- **`skills/fg-run/FORGE-ROOT.md`**: 브랜치별 forge 루트 해석의 유일한 정의(ADR-0011). 12개 스킬 전부가 참조함을 확인했다(`grep -c FORGE-ROOT skills/*/SKILL.md` → 12/12). 전역 예외 2개(`.forge/config.json`·`.forge/codebase/`)는 `skills/fg-tdd/SKILL.md:10`·`skills/fg-map/SKILL.md:12`가 각자 다시 설명하므로, 예외 규칙 변경 시 세 파일이 함께 움직여야 한다.

---

## 5. 스킬 간 상태 계약 — 계약은 의무 당사자에게 적혀 있어야 한다 (오늘 감사의 핵심 교훈)

스킬들은 독립 실행되며 오직 `.forge/` 파일로 상태를 주고받는다. 이 계약을 깨는 편집은 컴파일 에러 없이 흐름만 끊는다. 결합 지점:

- **`<!-- forge-slug: ... -->`**: fg-ask가 plan 첫 줄에 심고 fg-learn·fg-done이 짝을 맞춘다. 마커 형식을 바꾸면 짝 맞춤이 깨진다.
- **`STATUS.md`의 `status:`/`verified:`/`retro:` 어휘**: fg-run이 쓰고 fg-status·fg-learn·fg-done·fg-next가 읽는다. 허용값을 한 스킬에서만 바꾸면 게이트가 오작동한다. 검증/회고 게이트(ADR-0009/0002) 규율이 5개 스킬에 분산돼 있어, 한 곳만 고치면 봉인이 새거나(미검증 작업이 done) 영원히 막힌다.
- **fg-status의 상태 머신이 단일 정의**고 fg-next가 재사용한다(ADR-0010). fg-status 판정 변경 = fg-next 행동 변경.

오늘 감사가 이 계약의 전형적 실패와 교훈을 실증했다: **"fg-learn은 `retro:`를 건드리지 않고 fg-done이 봉인 시 채운다"는 의도가 fg-run·fg-status·fg-done 3곳에는 적혀 있었지만 정작 의무 당사자인 fg-learn 자신은 침묵**하고 있었다(B2·B3). 그 결과 이번 세션의 에이전트가 STATUS에 어휘 밖 값(`retro: done (...)`)을 '친절하게' 써넣는 실제 사고가 났다(run.md Divergence 1). 수정으로 `skills/fg-learn/SKILL.md` Doc impact에 불간섭 계약이 명시됐다(미커밋). **교훈을 일반화하면: 계약은 그것을 지켜야 하는 스킬의 본문에 적혀 있어야 하고, 다른 스킬에 적힌 계약은 그 스킬을 안 지킨다.** 같은 침묵이 남아 있는 다른 지점이 있는지는 자동 검출 불가 — 6-2(B4)가 바로 그 후보다.

---

## 6. 오늘 감사의 record-only 5건 — 열린 우려 (수정 안 됨, 전부 현 트리에서 재확인)

1. **[E4] Run-all 배치 핸드오프의 ADR-0015 회색지대.** `skills/fg-run/RUN-ALL.md` 4단계 핸드오프가 "…now let's retro each one via fg-learn, **which first?**"로 **질문형**이다 — ADR-0015가 정한 두 형태(fg-run 단건 종료의 3지 메뉴 / 나머지 진술형) 어디에도 안 속한다. RUN-ALL.md는 "Behavior is unchanged" 선언 파일이라(4번) 문구 수정이 곧 행동 변경 → ADR-0015를 배치 핸드오프로 확장할지 명시 결정(fg-ask 그릴링)이 필요하다.
2. **[B4] fg-next all의 `retro: skipped` 기록 주체 모호.** `skills/fg-next/SKILL.md:10`은 "It **writes nothing itself**; every write happens inside the delegated skill"인데, 같은 파일 73행의 all-모드 드라이브 루프는 "**record** `retro: skipped (fg-next all 자동 진행 …)`"을 지시한다 — 누가 쓰는가? 고-divergence 작업에선 fg-run 3지 메뉴에 skip 선택지가 없으므로(저-divergence 한정) 위임 경로도 불명. 쓰기 귀속만 명확화하면 되는 작은 결정이지만, 방치하면 5번과 같은 "어휘 밖 값" 사고의 다음 발화점이다.
3. **[B5] fg-quick LOG 라벨의 정준 여부 미합의.** `skills/fg-quick/SKILL.md:40`은 LOG 항목을 "**사용자 언어로**" 쓰라 하면서 템플릿(46행)은 한국어 리터럴 `결과: pending`을 보여주고, `skills/fg-merge/SKILL.md:36`은 **리터럴 `결과: pending`에 매칭**해 in-flight 판정을 한다. 영어 사용자의 LOG가 `Result: pending`이면 fg-merge의 halt 가드가 조용히 빠진다. 정준 어휘 선언 또는 의미 매칭 명시가 필요하다.
4. **[D8] fg-tdd가 자기 근거 ADR-0008을 미인용.** `skills/fg-tdd/SKILL.md`는 ADR-0011·0014만 인용하고 자신의 존재 근거인 ADR-0008은 인용하지 않는다(다른 유틸은 전부 자기 ADR 인용 — fg-eco→0014, fg-merge→0011, fg-cleanup→0012 확인). 부수 관찰: `grep -r` 기준 **ADR-0001·0004·0013은 어느 스킬·README·CLAUDE.md에서도 인용되지 않는다**(0007은 `skills/fg-run/SKILL.md:85`가 경로 형태로 인용, 0008은 미커밋 CLAUDE.md 수정에서 1회 인용 추가됨). 무인용 ADR은 fg-cleanup 은퇴 후보 검토감이거나 인용 보강감이다.
5. **[F9] README 트리거 발화의 현지화 방침 이원화.** 두 README의 트리거 목록은 대부분 **양판 동일 복제**(예: fg-done의 "작업 완료"·fg-quick의 "이거 빨리 해줘"가 영문판에도 한국어 그대로)인데, **fg-map**(영문판 "map the codebase" vs 한글판 "코드베이스 분석")과 **시작 발화**(`README.md:86` "start with forge" vs `README.ko.md:85` "forge로 시작")만 언어별 부분집합이다. 방침이 통일돼 있지 않아, 트리거를 추가할 때 어느 쪽 패턴을 따라야 하는지 판단 기준이 없다.

---

## 7. 미커밋 작업 더미 위험 — 오늘 완화 장치가 생겼으나 그 장치도 미커밋

이 리포의 작업 패턴상 영속 문서(retro·ADR·CONTEXT)와 스킬 수정이 작업 트리에 쌓인 채 봉인만 끝나는 일이 반복된다 — 현재도 0번의 7개 수정 파일 + untracked 2건이 그렇다. 오늘 감사(E10, 시드 2 해소)로 `skills/fg-done/SKILL.md`의 완료 통지와 Wrap-up에 **"git-tracked 영속 문서가 미커밋이면 커밋 상기 한 줄"**(상기만, git 실행 금지 — fg-merge와 같은 절제)이 들어갔다. 다음 봉인부터는 더미가 상기되지만, **이 장치 자체가 아직 미커밋**이라 커밋·push 전에는 발효되지 않았고, 상기는 강제가 아니라서 무시하면 같은 더미가 다시 쌓인다.

---

## 8. README.md / README.ko.md 이중 언어 동기화 — 자동 검사 없음

두 README는 같은 내용의 번역 쌍이고, 미커밋 수정(A7)도 양판에 나란히 들어가 동기화가 유지됨을 확인했다. 그러나 검사 도구가 없어 한쪽만 고치면 조용히 어긋난다. 스킬 개수(2번)·루프 서술·트리거 목록(6-5의 이원화 지점) 변경 시 특히 위험하다.

---

## 9. 자동 테스트가 전무 — 의미적 깨짐은 사람만 잡는다

빌드·테스트·린트·CI가 없다(package.json·Makefile·CI 부재 확인). 검증 수단은 (1) 매니페스트 JSON 파싱 한 줄, (2) 실제 설치 후 트리거 — 후자는 interactive라 에이전트 불가, 그리고 설치는 origin main을 당기므로 로컬/미푸시 상태는 검증 자체가 불가능하다. 5번의 상태 계약 단절, 4번의 이중 파일 드리프트, 3번의 `name` 오타는 **어떤 자동 도구도 잡지 못한다.** 실효적 안전망은 `CLAUDE.md`의 편집 규율과 **주기적 정합 감사**뿐인데, 감사가 사흘간 3차례 돌며 매번 실드리프트를 잡아냈다는 사실 자체가(2차 20건, 3차 fix 8건) 드리프트 발생 속도가 빠르다는 증거다. `.forge/retro/2026-06-11-handoff-state-not-ask.md`도 "**스킬이 자기 규약과 조용히 드리프트한다 — 단일 정의가 본문과 갈라지는 게 이 리포의 반복 실패 모드**"를 명시했다.

---

## 10. 스킬 본문 비대화 — 분리해도 다시 자란다

`skills/fg-run/SKILL.md`는 RUN-ALL 분리(v0.4.2) 직후 24,579자였는데 현재 **26,571자**로 다시 자랐다(분리 전 28,061자에 근접). `skills/fg-done/SKILL.md`도 16.0KB→**17.9KB**. 게이트·복구 경로·상기 문구가 추가될 때마다 본문이 자라고, 비대해지면 또 분리(progressive disclosure)가 필요해지는데 그 분리는 4번의 드리프트 표면을 하나씩 늘린다. 구조적 트레이드오프이며 감시 장치 없음.

---

## 11. 기타 관찰 (경미하지만 새로 확인된 것)

- **`docs/forge-vs-loop-engineering.md`가 untracked이고 자리가 없다.** 오늘 새로 생긴 검토 문서(Loop Engineering 대응표)인데 forge의 문서 모델(`.forge/` 영속 문서 또는 README) 어디에도 속하지 않는 신규 최상위 `docs/`에 있다. 내용도 "forge v0.4.4 기준"으로 적혀 있어 v0.4.5 트리와 한 버전 어긋난다. 커밋할지, `.forge/` 체계로 들일지, 버릴지 미정 상태.
- **`.gitignore`에 `.planning/`·`!.planning/codebase/` 항목이 있으나 `.planning/` 디렉터리가 없다.** GSD 워크플로우용 잔재로 보이며 동작 위험은 없지만, forge의 화이트리스트 패턴(`.forge/*` + `!...`)과 나란히 있어 `.gitignore`를 "정리"하려는 손길을 부른다 — 바로 아래의 `.forge/` 비대칭(기본 브랜치 휘발 상태는 gitignored, `!.forge/branch/`만 통째 추적 — ADR-0011)을 모르고 건드리면 브랜치 상태 추적이 깨진다.
- **현재 루프 상태는 깨끗하다**: 활성 슬롯·`.forge/backlog/`·`.forge/executed/` 모두 비어 있고 `done/` 34건 — "진행 중 작업 없음" 상태로, 상태 계약 기준 이상 없음.

---

## 우선순위 요약

| # | 우려 | 깨질 때 증상 | 자동 검출 |
| --- | --- | --- | --- |
| 0 | 감사 수정 8건 미커밋(+untracked 2건) | 설치본이 감사 이전 행동 | `git status`로만 |
| 1 | 버전 3곳 동기화 | 설치/업데이트 실패 | JSON 유효성만(일치 검사 X) |
| 2 | 스킬 개수·목록 하드코딩 ≥6곳 | 문서가 스킬 현실과 어긋남(CLAUDE.md fg-tdd 누락으로 실증) | **없음** |
| 3 | frontmatter `name` 오타 / fg-next desc ~1,084자 | 스킬 조용히 미탐색 / description 잘림 가능 | `awk`로 누락만 |
| 5 | 상태 계약 — 계약이 의무 당사자에 없음 | 어휘 밖 값 기록, 게이트 오작동(이번 세션 실증) | **없음** |
| 6 | record-only 5건(E4·B4·B5·D8·F9) | 배치 핸드오프 회색지대, 쓰기 귀속 모호, fg-merge 가드 누락 등 | **없음** |
| 4 | 이중 파일 드리프트(fg-ask·RUN-ALL·FORGE-ROOT 예외 3중 서술) | 핸드오프/Run-all/루트 해석 분기 | **없음** |
| 7 | 미커밋 더미(완화: fg-done 커밋 상기 — 자신도 미커밋) | 영속 문서가 디스크에만 존재 | **없음**(상기만) |
| 8 | README 이중 언어 동기화 | 두 문서 어긋남 | **없음** |
| 10 | 스킬 본문 재비대화(fg-run 26.6KB) | 컨텍스트 비용 → 분리 → 드리프트 표면 증가 | **없음** |

**관통하는 진실**: 대부분 자동 검출 불가이며, 안전망은 `CLAUDE.md` 편집 규율 + 주기적 정합 감사 + 사람의 설치-트리거 검증뿐이다. 감사가 매번 실드리프트를 잡는다는 것은 규율만으로는 새는 속도를 못 따라간다는 뜻이다. 관련 결정: ADR-0002(회고 스킵)·0009(검증 게이트)·0010(fg-next all)·0011(브랜치 루트)·0012(fg-cleanup)·0014(fg-eco)·0015(핸드오프 형태).
