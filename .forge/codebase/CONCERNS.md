---
last_mapped_commit: 0472a519cbb8275564cdbaa30469f2d0c5472842
mapped: 2026-06-10
---

# CONCERNS — 이 플러그인의 실제 취약점

forge는 런타임 코드가 없는 Claude Code 플러그인이다 — Markdown 스킬(`skills/*/SKILL.md`)과 JSON 매니페스트(`.claude-plugin/*.json`)뿐이다. 따라서 "버그"는 컴파일 에러가 아니라 **설치 실패, 스킬 미탐색, 스킬 간 상태 계약 단절, 문서 드리프트** 형태로 나타난다. 컴파일러·테스트가 잡아주지 않으므로 전부 사람이 편집 규율로 막아야 한다. 아래는 각 항목을 **현재 작업 트리**에 대고 검증한 결과다.

---

## 0. 로컬 main이 origin보다 앞서 있다 — 설치본은 push 전까지 옛 버전

9개 파일의 문서 드리프트 수정은 커밋 `1aecebb`로 **커밋됐으나 아직 push되지 않았다**. 설치는 GitHub main을 당기므로, **push 전까지 설치된 플러그인은 수정 전 내용으로 동작한다** — 예: 설치본의 `skills/fg-done/SKILL.md`는 아직 `verified: yes`(evidence 없는 옛 형식)를 봉인 가능 값으로 안내한다. 이 커밋들이 origin/main에 올라가야 아래 8·10번의 "해소됨" 상태가 실제 사용자에게 반영된다.

---

## 1. 매니페스트 버전이 3곳에 흩어져 있다 — 어긋나면 설치 깨짐

버전 문자열이 세 군데에 중복되며 **반드시 동기화**되어야 한다:

- `.claude-plugin/plugin.json` → `version` (현재 `0.4.2`)
- `.claude-plugin/marketplace.json` → `metadata.version` (현재 `0.4.2`)
- `.claude-plugin/marketplace.json` → `plugins[0].version` (현재 `0.4.2`)

세 값이 일치함은 확인했다. 그러나 검증 도구는 JSON 파싱 유효성뿐이고 **세 버전이 같은지는 어떤 도구도 검사하지 않는다**:

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

배포 후 원격 main의 세 버전 일치는 `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`로만 사후 확인 가능하다(`/plugin install`은 interactive라 에이전트가 못 돌린다).

---

## 2. 긴 설명이 두 벌 + 스킬 개수가 하드코딩 — 스킬 추가 시 4곳 이상을 손으로 맞춰야 한다

설명 텍스트의 역할 분리는 현재 지켜지고 있다(검증됨):

- `marketplace.json` → `metadata.description`: **루프 태그라인** — `ask·plan → execute → retro → done`만 정의. 루프 밖 유틸리티를 여기 넣으면 안 된다.
- `plugin.json` → `description`과 `marketplace.json` → `plugins[0].description`: **전체 스킬 목록**을 담는 긴 설명. 단 이 둘은 **복사본이 아니라 서로 다르게 쓰인 두 벌의 긴 텍스트**다 — `plugins[0].description`은 "Eleven fg-* skills"로 시작해 루프 4단계를 스킬명 대신 단계명으로 서술하고, `plugin.json` 쪽은 11개 스킬명을 전부 직접 나열한다. 둘 다 현재 11개 스킬과 일치함을 확인했지만, 스킬을 추가/제거하면 **서로 다른 문장 구조의 두 텍스트를 따로 고쳐야 한다**.

추가 위험: 스킬 개수가 산문에 하드코딩돼 있다 — `marketplace.json`의 "Eleven … Seven more", `README.md:4`의 "eleven … seven utilities", `README.ko.md:4`의 "11개 … 7개". 12번째 스킬을 추가하면 **최소 4곳의 숫자**가 동시에 stale해진다. 자동 검출 없음.

---

## 3. 스킬은 frontmatter `name`으로 자동 탐색된다 — 이름이 틀리면 조용히 사라진다

스킬 식별자는 **디렉터리명이 아니라 `SKILL.md` frontmatter의 `name`**이다. `plugin.json`에 `skills` 필드가 없어 `skills/`가 자동 탐색된다. 11개 스킬 모두 디렉터리명과 `name`이 일치함을 확인했다(`fg-ask`·`fg-cleanup`·`fg-done`·`fg-learn`·`fg-map`·`fg-merge`·`fg-next`·`fg-quick`·`fg-run`·`fg-status`·`fg-tdd`).

위험: `name`을 빠뜨리거나 오타를 내면 그 스킬은 **에러 없이 그냥 탐색되지 않는다**. 배포 전 점검은 `awk '/^name:/' skills/*/SKILL.md`로 누락만 확인 가능하다(`CLAUDE.md` 배포 규칙에 명시).

추가 관찰: `skills/fg-next/SKILL.md`의 frontmatter `description`이 **1,038자**로, 흔히 문서화되는 스킬 description 권장 한도(약 1,024자)를 넘는다 [중간 — 한도 수치는 공식 문서 기준 확인 필요]. 현재 세션에서는 잘려 보이지 않으나, 한도 강제가 빡빡한 환경에서 잘리거나 거부될 수 있는 경계값이다. 나머지 10개는 325–673자로 여유 있다.

---

## 4. fg-ask는 grill-with-docs verbatim 본문 + 별도 Forge integration 섹션 — 따로 움직여 드리프트

`skills/fg-ask/SKILL.md`(105줄)는 구조가 둘로 쪼개져 있다:

- **본문(1–89줄)**: grill-with-docs 원본의 **영문 verbatim**. 자기완결 3파일 패턴(`SKILL.md` + 형제 `CONTEXT-FORMAT.md` / `ADR-FORMAT.md`)이며 손대지 않는 영역으로 취급된다.
- **`## Forge integration (minimal)` 섹션(90줄~)**: forge 루프 연결 로직이 **여기에만** 산다 — 백로그 산출(`<!-- forge-slug: -->`·`<!-- task: N -->`·`<!-- tdd: -->`·`<!-- retro-hint: -->`·`<!-- priority: -->`·`<!-- part: N/M -->` 마커), 미봉인 선행 작업 알림, slug 충돌 검출, fg-run 핸드오프, 휘발/영속 추적 구분.

이 둘은 **독립적으로 움직인다.** 한쪽만 고치면 둘이 어긋나 상태 계약이 깨진다. `CLAUDE.md`가 "알려진 불일치"로 명시한 항목이다. 같은 패턴이 fg-run에도 새로 생겼다(8번 참조).

---

## 5. 스킬 간 상태 계약 — 한 스킬을 고치면 `.forge/` 파일 핸드오프가 조용히 깨진다

스킬들은 **독립 실행**되며 오직 `.forge/` 파일로 상태를 주고받는다. 이 계약을 깨는 편집은 컴파일 에러도 테스트 실패도 없이 흐름만 끊는다. 핵심 결합 지점:

- **`<!-- forge-slug: ... -->` 식별자**: fg-ask가 plan 첫 줄에 심고, fg-learn(회고)·fg-done(봉인)이 같은 slug로 짝을 맞춘다. 마커 형식/위치를 바꾸면 짝 맞춤이 깨진다.
- **`STATUS.md`의 `status:` / `verified:` / `retro:` 필드**: fg-run이 `status: executed`(+`verified: pending`+`retro: pending`)로 쓰고 fg-done이 `status: done`으로 마감한다. `verified:` 허용값 어휘는 현재 트리 기준 fg-run(`yes (<evidence>)` 형식, `skills/fg-run/SKILL.md:120`)·fg-done(`skills/fg-done/SKILL.md:24`)·fg-status(`skills/fg-status/SKILL.md:58,77–85`)·fg-next가 **일치함을 확인했다**(커밋 `1aecebb`로 fg-done이 evidence 형식을 따라잡음). 이 필드명·허용값을 한 스킬에서만 바꾸면 게이트가 오작동한다.
- **활성 슬롯 = 항상 1개**: 한 `plan.md` = 한 `run.md` = 한 봉인. failed 작업 unpark의 단일 소유자는 fg-run이다(ADR-0009). 다른 스킬이 활성 슬롯을 건드리도록 고치면 이 불변식이 깨진다.
- **빈 상태 = 진행 중 작업 없음**: 활성 슬롯·백로그·`executed/`가 모두 비면 fg-run은 실행하지 않는다(재실행 방지). fg-done이 봉인하며 비운다.

**fg-status는 이 상태 머신의 단일 정의**이고 fg-next가 재사용한다(ADR-0010). fg-status의 상태 판정을 바꾸면 fg-next의 다음-단계 도출도 같이 흔들린다.

---

## 6. README.md / README.ko.md 이중 언어 동기화 — 한쪽만 고치면 어긋난다

`README.md`(영문)와 `README.ko.md`(한글)는 같은 내용의 번역 쌍이다. 커밋 `1aecebb`의 수정도 양쪽에 같은 변경(전역 예외 2개 문서화, fg-next 핸드오프 문구, 트리거 목록)이 나란히 들어가 **동기화가 유지되고 있음을 확인했다**. 그러나 자동 동기화 검사가 없어, 한쪽만 고치면 조용히 어긋난다. 스킬 개수(2번의 하드코딩 숫자)·루프 설명·트리거 목록을 바꿀 때 특히 위험하다.

---

## 7. 자동 테스트가 없다 — 깨진 상태 계약을 잡는 건 수동 설치+트리거뿐

빌드·테스트·린트·CI가 전혀 없다(`package.json`·`Makefile`·CI 없음). 검증 수단은 둘뿐:

1. JSON 파싱 유효성(위 node 한 줄) — 매니페스트 문법만 본다.
2. **실제 설치 후 트리거** — `/plugin marketplace add` → `/plugin install` 후 직접 호출. 이 명령들은 interactive라 **에이전트가 실행 못 한다**.

결과: 5번의 상태 계약 단절, 4번의 fg-ask 드리프트, 3번의 `name` 누락 같은 **의미적 깨짐은 어떤 자동 도구도 잡지 못한다.** 게다가 설치는 main을 당기므로 로컬 편집만으로는 진짜 동작 검증이 불가능하다(0번과 결합하면: 커밋된 수정도 push 전까지 설치 검증 불가).

---

## 8. 단일 정의 + 참조 원칙 — 복붙하면 갈라지고, 분리 파일은 새 드리프트 표면

중복을 피하려 "단일 정의 + 참조"를 쓰는데, 지점이 늘었다:

- **`skills/fg-run/FORGE-ROOT.md`**: 브랜치별 forge 루트 해석의 **유일한 정의**(ADR-0011). 11개 스킬 전부가 참조함을 확인했다(`grep -l FORGE-ROOT skills/*/SKILL.md` → 11개). 전역 예외 2개(`.forge/config.json`·`.forge/codebase/`)도 이 파일이 정의하고, `skills/fg-tdd/SKILL.md:10`·`skills/fg-map/SKILL.md:12`가 각자 자기 예외를 다시 설명한다 — 예외 규칙을 바꾸면 **세 파일**이 함께 움직여야 한다. (과거 이 파일에 있던 "fg-merge not built yet" stale 경고 블록은 현재 트리에서 **제거됨** — 해소.)
- **`skills/fg-run/RUN-ALL.md`** (v0.4.2 신설): fg-run의 "Run all" 절차를 progressive disclosure로 분리했다. fg-run의 행동 규칙이 이제 `SKILL.md`+`RUN-ALL.md` **두 파일에 걸쳐** 산다 — fg-ask의 verbatim/integration 분리(4번)와 같은 종류의 드리프트 표면이다. Run-all 관련 규칙(작업별 UAT 후 파킹, failed는 활성 슬롯 잔류)을 고칠 때 두 파일의 정합을 같이 봐야 한다.
- **형식 문서 위치**: `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-learn/RETRO-FORMAT.md` 각 한 벌만 존재(검증됨). `PLAN-FORMAT.md`는 생산자가 fg-ask인데 소비자(fg-run) 디렉터리에 있다 — fg-ask 디렉터리가 verbatim 영역이라서다. 이 비대칭을 모르고 fg-ask 쪽에 plan 형식을 새로 쓰면 정의가 둘로 갈라진다. 루트 `references/`는 폐지됐다.

부수 관찰(경미): `skills/fg-run/FORGE-ROOT.md:3`은 "every loop skill"이라며 루프 밖 스킬(fg-status·fg-next·fg-quick)까지 괄호 안에 나열한다 — 동작 위험은 없지만 "루프 스킬" 용어가 느슨하게 쓰인 지점.

---

## 9. 브랜치별 forge 루트 — gitignore 화이트리스트 비대칭이 미묘하다 (ADR-0011)

`.gitignore`가 `.forge/*`를 기본 제외하되 화이트리스트로 되살린다(`!.forge/CONTEXT.md`·`!.forge/adr/`·`!.forge/retro/`·`!.forge/codebase/`·`!.forge/config.json`·`!.forge/branch/`). 핵심 비대칭:

- **기본 브랜치**의 휘발 상태(plan/run/STATUS/backlog/executed/done/quick)는 **gitignored**.
- **비-기본 브랜치**의 루트(`.forge/branch/<branch>/`)는 `!.forge/branch/`로 **통째로 추적**된다.

이 의도된 비대칭을 모르고 `.gitignore`를 "정리"하면 브랜치 상태가 추적에서 빠지거나(fg-merge가 통합할 게 사라짐) 기본 브랜치 휘발 상태가 커밋을 오염시킨다. fg-merge의 통합 동작(ADR 번호 재부여·교차참조 갱신·retro 이동·CONTEXT 병합·브랜치 폴더 제거)이 이 추적에 의존한다. `config.json`의 `defaultBranch`(없으면 `main`)가 루트 해석의 분기점이라, 이 값이 실제 기본 브랜치와 어긋나면 모든 경로 해석이 틀어진다. (전역 예외 2개가 `CLAUDE.md`·`README.md:107`·`README.ko.md`에도 문서화돼 정의-문서 불일치는 해소됐다 — 단 0번대로 미푸시.)

---

## 10. 회고/검증 게이트의 분기 규율 — 한 스킬만 고치면 봉인이 새거나 막힌다

루프 순서는 `run → verify → learn → done`이며 두 게이트가 봉인을 지킨다:

- **검증 게이트(ADR-0009)**: fg-done이 **검증을 회고보다 먼저** 확인한다(no-seal-without-verification). 봉인 가능 값은 `yes (<evidence>)`/`skipped (<reason>)`/`n/a (<reason>)`, 차단 값은 `pending`/`failed`/누락. `pending`→fg-run 검증 전용 재진입, `failed`→fg-run unpark·fix-and-re-run 또는 fg-ask 재그릴. **`failed`는 waiver로 통과 금지** — fresh re-run 재검증만 인정(`skills/fg-done/SKILL.md:27` 부근에 명시). 파킹/구버전 작업의 `pending`은 fg-done이 봉인 시점에 직접 UAT로 회수한다.
- **회고 게이트(ADR-0002)**: 기본은 회고. 저-divergence 작업만 fg-run 핸드오프가 "건너뛰기"를 제시하고, 선택 시 `retro: skipped (<reason>)` 기록. fg-done은 회고 파일 존재 **또는** `retro: skipped`를 통과로 인정.

위험: 이 규율이 fg-run·fg-done·fg-learn·fg-status·fg-next에 분산돼 있어, 한 스킬에서만 게이트 조건을 바꾸면 **봉인이 새거나(미검증 작업이 done 됨) 영원히 막힌다.** ADR-0009 이전 작업은 `verified: n/a (legacy pre-ADR-0009)`로 백필됐고, fg-status는 `done/`의 `verified:` 누락을 "legacy"로 읽도록 명시한다(`skills/fg-status/SKILL.md:58`) — 이 레거시 처리를 빠뜨리면 옛 작업 판정이 틀어진다. `fg-next all`은 회고를 항상 자동 skip하므로(ADR-0010) 게이트 어휘 변경 시 fg-next의 벽 판정(`skills/fg-next/SKILL.md:81`)도 같이 봐야 한다.

---

## 11. 스킬 본문 비대화 — 컨텍스트 비용이 계속 자란다

`skills/fg-run/SKILL.md`는 RUN-ALL 분리(v0.4.2, 28,061→24,579자) 후에도 **24.6KB로 최대**이고, `skills/fg-done/SKILL.md`(16.0KB)·`skills/fg-ask/SKILL.md`(15.7KB)·`skills/fg-next/SKILL.md`(15.0KB)가 뒤따른다. 스킬 본문은 트리거 시 통째로 컨텍스트에 들어가므로, 게이트·복구 경로가 추가될 때마다 본문이 자라는 추세가 이어지면 progressive disclosure 분리(RUN-ALL 방식)가 더 필요해진다 — 그리고 그 분리는 8번의 드리프트 표면을 하나씩 늘린다. 구조적 트레이드오프이며 자동 감시 없음.

---

## 12. 해소된 과거 우려 (기록용 — 더 이상 활성 위험 아님, 단 0번대로 미푸시분 포함)

- **`forge-prd.md` stale 설계 초안** — 커밋 `0ecd826`에서 삭제됨(현재 트리에 없음 확인).
- **`skills/fg-run/FORGE-ROOT.md`의 "fg-merge is not built yet" 경고 블록** — fg-merge가 실재(v0.4.0)하는데 남아 있던 stale 경고. 제거되고 `skills/fg-merge/SKILL.md` 참조로 대체됨(커밋 `1aecebb`, 미푸시).
- **fg-done의 `verified: yes` evidence 형식 불일치** — fg-run은 `yes (<evidence>)`를 기록하는데 fg-done은 evidence 없는 `yes`를 안내하던 어긋남. fg-done도 `yes (<evidence>)`로 통일됨(커밋 `1aecebb`, 미푸시).
- **전역 예외 2개(`config.json`·`codebase/`) 미문서화** — `CLAUDE.md`·`README.md`·`README.ko.md`에 반영됨(커밋 `1aecebb`, 미푸시).
- **fg-ask·fg-quick·fg-done의 "`.forge/`는 gitignored" 단정** — ADR-0011 이후 브랜치 루트는 추적되므로 부정확했던 서술. 브랜치별 구분 서술로 수정됨(커밋 `1aecebb`, 미푸시).
- **fg-status 핸드오프의 fg-next 동작 서술(승인 후 실행)** — fg-next의 "별도 승인 없이 즉시 실행"과 어긋나던 문구. 일치하게 수정됨(커밋 `1aecebb`, 미푸시).

---

## 우선순위 요약

| # | 우려 | 깨질 때 증상 | 자동 검출 |
| --- | --- | --- | --- |
| 0 | 커밋됨(`1aecebb`)·미푸시 수정 9파일 | 설치본이 수정 전 내용으로 동작 | `git status`로만 |
| 1 | 버전 3곳 동기화 | 설치/업데이트 실패 | JSON 유효성만 (일치 검사 X) |
| 3 | frontmatter `name` 누락 / fg-next description 1,038자 | 스킬 조용히 미탐색 / description 잘림 가능 | `awk '/^name:/'`로 누락만 |
| 5 | 스킬 간 상태 계약 | 루프 흐름 단절, 재실행/봉인 실패 | **없음** |
| 4·8 | fg-ask·fg-run 이중 파일 드리프트, 단일 정의 복붙 | 핸드오프/Run-all/루트 해석 분기 | **없음** |
| 10 | 검증/회고 게이트 분산 규율 | 봉인 누수/봉인 불가 | **없음** |
| 2 | 긴 설명 2벌 + 개수 하드코딩 4곳 | 매니페스트·README 스킬 목록 stale | **없음** |
| 6 | README 이중 언어 동기화 | 두 문서 어긋남 | **없음** |
| 9 | gitignore 화이트리스트 비대칭 | 브랜치 상태 추적 누락/오염 | **없음** |
| 11 | 스킬 본문 비대화 | 컨텍스트 비용 증가 → 분리 → 드리프트 표면 증가 | **없음** |

**관통하는 진실**: 대부분이 자동 검출 불가다. 이 플러그인의 안전망은 컴파일러도 테스트도 아닌 **편집 규율(`CLAUDE.md`)과 사람의 설치-트리거 검증**뿐이다. 관련 결정: `.forge/adr/0002`(회고 스킵)·`0009`(검증 게이트)·`0010`(fg-next all)·`0011`(브랜치 루트)·`0012`(fg-cleanup)·`0013`(서브에이전트 보류).
