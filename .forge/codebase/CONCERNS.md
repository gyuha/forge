---
last_mapped_commit: 41c10d7cb477eddab9b7d0f1aa8bd23bbcf34d98
mapped_date: 2026-06-09
---

# Concerns — 알려진 취약점·위험 영역

forge의 산출물은 Markdown(`SKILL.md`·형식 문서)과 JSON(매니페스트)뿐이고 빌드·테스트·린트·CI가 없다. 따라서 위험은 "코드 버그"가 아니라 **수동 동기화 지점, 스킬 간 교차참조 발산, 단어/이름 과부하, 런타임 부재로 인한 검증 사각**의 형태로 나타난다. 아래 항목은 전부 기술부채가 아니라 **설계 의도의 비용**이며, 각각 실제 파일·ADR·회고에 근거한다. 예방책은 "제거"가 아니라 "의식화·검증"이다.

## 1. 스킬 간 교차참조 밀도 — 한 곳을 고치면 흩어진 참조가 어긋난다

**위치:** `skills/*/SKILL.md` 전반, 특히 `skills/fg-run/FORGE-ROOT.md`·`skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`·`skills/fg-run/PLAN-FORMAT.md`·`skills/fg-learn/RETRO-FORMAT.md`

**상황:**
- forge 루트 해석 규약(ADR-0011)은 **단 한 곳** `skills/fg-run/FORGE-ROOT.md`에 정의되고, **11개 스킬 전부**가 이를 참조한다(`fg-ask`·`fg-cleanup`·`fg-done`·`fg-learn`·`fg-map`·`fg-merge`·`fg-next`·`fg-quick`·`fg-run`·`fg-status`·`fg-tdd` 모두 `${CLAUDE_PLUGIN_ROOT}/skills/fg-run/FORGE-ROOT.md` 류로 가리킴). 복붙 금지 원칙(CLAUDE.md)으로 single-definition을 지키는 대신, 이 한 파일의 의미가 바뀌면 11개 스킬의 동작이 동시에 영향받는다.
- 형식 문서도 소유 스킬 디렉터리에만 두고 상대경로로 참조한다: `fg-done`·`fg-learn`·`fg-run`·`fg-cleanup`이 `fg-ask/ADR-FORMAT.md`·`fg-ask/CONTEXT-FORMAT.md`를, `fg-ask`가 `fg-run/PLAN-FORMAT.md`를, `fg-done`·`fg-learn`이 `fg-learn/RETRO-FORMAT.md`를 가리킨다.

**발산 위험:**
- 형식 문서나 FORGE-ROOT를 이동·개명하면 흩어진 참조 경로가 한 번에 깨지는데, 빌드가 없어 **컴파일 에러로 잡히지 않는다** — 설치해서 트리거해보기 전까지 드러나지 않는다.
- `2026-06-04-fg-ask-adr-path-fix.md` 회고가 정확히 이 부류의 사고(verbatim 이식 시 경로/이름이 호스트 계약과 어긋남)를 기록했다.

**예방책:** 형식 문서/FORGE-ROOT 수정 후 `grep -rno "fg-ask/[A-Z]*-FORMAT\|fg-run/PLAN-FORMAT\|fg-learn/RETRO-FORMAT\|fg-run/FORGE-ROOT" skills/` 로 모든 참조 경로 정합 확인.

---

## 2. 런타임 부재로 인한 검증 게이트의 구조적 사각 (ADR-0009)

**위치:** `.forge/done/*/STATUS.md`의 `verified:` 필드, `.forge/adr/0009-verification-gate-before-seal.md`

**상황:**
- ADR-0009는 봉인 전 검증 게이트(run → verify → learn → done)를 강제한다. 그러나 forge 스킬은 **지시문 텍스트일 뿐 런타임이 없다** — `fg-*` 스킬을 편집하는 작업은 실행해서 동작을 검증할 대상이 없다.
- 결과적으로 done STATUS의 `verified:` 값이 자주 `n/a`로 떨어진다. 실측: **16건이 `n/a (legacy pre-ADR-0009)`**(백필), 추가로 다수가 `n/a (런타임 없음 — 정적 검증만: grep/node로 name 자동탐색·JSON 유효·매니페스트 일관성)` 형태다.
- "실제 동작" 검증은 main에 push 후 `/plugin install`로만 가능한데, 이는 interactive 명령이라 에이전트가 못 돌린다(CLAUDE.md 배포 규칙).

**발산 위험:**
- `n/a`가 관례가 되면 검증 게이트가 형식만 남고 실효를 잃는다. "정적 grep만 했는데 sealable"이 기본값이 되기 쉽다.

**완화(이미 적용):**
- ADR-0013이 이 통증의 정체를 명시한다 — "verifier 서브에이전트는 없는 런타임을 만들어내지 못한다." 사각을 실제로 메운 것은 **샌드박스 dogfood**다: `.forge/done/2026-06-09-fg-merge-lifecycle-e2e/`의 `verified: yes (샌드박스 e2e — A 기계적·B 충돌-멈춤·C 전제가드 전부 PASS …)`가 fg-merge 라이프사이클을 실제로 돌려 검증한 사례다.
- `2026-06-07-evidence-first-uat.md` 회고가 "증거 우선 UAT"를 강화했다.

**예방책:** 비-trivial 스킬 변경(특히 새 상태 계약)은 정적 grep을 넘어 샌드박스 dogfood로 검증. `n/a` 사유에 "왜 런타임이 없는지 + 정적으로 무엇을 실측했는지"를 항상 남긴다.

---

## 3. README.md ↔ README.ko.md 수동 동기화 부담

**위치:** `README.md`(영문, 140줄) ↔ `README.ko.md`(한글, 139줄)

**상황:**
- CLAUDE.md: "README.md를 갱신하면 반드시 README.ko.md도 같은 변경으로 함께 갱신한다(역방향도 동일)." 두 문서는 번역 쌍이고, 자동 동기화 장치가 없다.
- 현재 줄 수가 140 vs 139로 1줄 차이 — 정상 번역 차이일 수 있으나, **둘이 구조적으로 어긋났는지 자동으로 검출할 방법이 없다**.

**발산 위험:**
- 스킬 추가·이름 변경·상태 계약 변경 때마다 양쪽을 손대야 한다. 최근 변경(스킬 7→11개, `fg-complete→fg-cleanup→fg-done` 개명 사슬, ADR-0011 브랜치 격리, ④단계 단어 done화)은 전부 README 양쪽 동기화를 요구했다. 한쪽만 고치면 두 문서가 영구히 갈린다.

**예방책:** README 변경 커밋은 항상 두 파일을 함께 touch. 배포 전 두 README의 섹션 목차가 일치하는지 육안 대조.

---

## 4. "단계 단어 vs 스킬 이름" 과부하 — cleanup/done 충돌 (ADR-0012)

**위치:** `skills/fg-cleanup/`, `skills/fg-done/`, ADR-0012, 두 스킬의 핸드오프 가드

**상황:**
- 봉인 ④단계 스킬은 `fg-complete → fg-cleanup → fg-done`으로 두 번 개명됐다. 비어난 `fg-cleanup` 이름에는 **완전히 다른 기능**(오래된 ADR 은퇴, 루프 밖 유틸리티)이 새로 들어왔다(ADR-0012).
- ADR-0012의 2026-06-09 개정은 ④단계를 가리키는 *단어*까지 "cleanup/정리"에서 **"done/완료"**로 통일했다. 흐름 표기는 `ask·plan → execute → retro → done`. "cleanup"은 이제 `fg-cleanup`(ADR 은퇴) 전용 단어다.

**발산 위험:**
- **근육기억 역전 사고.** `forge cleanup` 트리거가 봉인이 아니라 ADR 은퇴로 라우팅된다. 사용자가 "정리"라고 치면 어느 쪽을 의도했는지 모호하다.
- 문서를 편집할 때 "cleanup"이라는 단어가 봉인 단계를 가리키는 잔재가 남아 있으면 두 의미가 충돌한다.

**완화(이미 적용):**
- `skills/fg-cleanup/SKILL.md`에 명시적 가드: "this retires ADRs; sealing a task is fg-done … wanted to seal? → point to fg-done → stop." description에도 "sealing a finished task is fg-done, not this."
- ADR-0012가 "개명 sweep은 살아있는 기능 문서만, 역사 기록(retro·done·CHANGELOG·옛 ADR 언급)은 불변"이라고 못박았다.

**예방책:** 역사 문서(retro/done/CHANGELOG)에서 "fg-cleanup"이 봉인을 뜻하던 과거 언급은 고치지 말 것 — 고치면 역사가 왜곡된다. 신규 문서에서는 ④단계를 "done"으로만 표기.

---

## 5. 서브에이전트 의도적 보류 (ADR-0013) — 재제안 압력

**위치:** `.forge/adr/0013-defer-subagents-fg-map-and-stage-separation-suffice.md`

**상황:**
- explorer/retro-analyzer/verifier 3종 서브에이전트 도입이 제안됐으나 **셋 다 보류**됐다. 근거: explorer는 fg-map과 중복, retro-analyzer가 겨냥한 컨텍스트 오염은 단계별 스킬 분리로 이미 완화, verifier는 ADR-0009의 진짜 통증(런타임 부재)을 못 고침.

**발산 위험:**
- "당연한 최적화"로 보여 누군가(또는 미래의 같은 분석)가 재제안하기 쉽다 — 이것이 ADR-0013이 명문화된 이유다.

**예방책(이미 ADR에 내장):** 재검토는 **구체적·재현된 통증**이 생길 때 *해당하는 하나만* — 거대 run.md로 fg-learn 컨텍스트가 실제 압박받으면 retro-analyzer, UAT 출력이 수천 줄이면 verifier. 투기적 일반론으로는 다시 만들지 않는다. 재제안 전 ADR-0013을 먼저 읽을 것.

---

## 6. 회고 skip의 침식 위험 (ADR-0002)

**위치:** `.forge/done/*/STATUS.md`의 `retro:` 필드

**상황:**
- ADR-0002는 저-divergence 사소한 작업에 한해 회고를 skip할 수 있게 했다. 실측 done STATUS에서 **다수가 `retro: skipped`**다 — 사유는 "divergence 없음 / 핵심은 ADR에 기록됨 / 사용자 판단 / fg-next all 자동 진행" 등으로 다양하다.
- 특히 `2026-06-08-branch-isolation-2of2`는 **"고-divergence였으나 핵심 학습이 이미 승급됨"**으로 skip됐다. ADR-0002가 "divergence 크면 skip 미제시"라 한 원칙과 긴장 관계.
- `fg-next all` 모드(ADR-0010)는 회고를 **항상 자동 skip**한다(`2026-06-09-fg-next-all-unattended-goal.md` 회고). 무인 진행이 늘면 skip이 기본값이 된다.

**발산 위험:**
- 기둥 2("문서는 루프의 연료")가 침식된다 — skip이 관례가 되면 회고가 다음 계획의 출발점 역할을 못 한다. "핵심은 ADR/run.md에 있으니 회고 불요"는 회고와 ADR의 역할 혼동 신호이기도 하다.

**예방책:** skip 사유에 "학습이 어디에 보존됐는지(run.md/ADR)"를 명시하고, `fg-next all`로 쌓인 skip은 추후 fg-learn으로 승급 검토. divergence가 크면 skip 게이트가 실제로 막는지 점검.

---

## 7. 코드베이스 지도 자신의 staleness (바로 이 재생성)

**위치:** `.forge/codebase/*.md`(STACK·INTEGRATIONS·ARCHITECTURE·STRUCTURE·CONVENTIONS·TESTING·CONCERNS 7문서)

**상황:**
- fg-map이 생성하는 지도는 각 문서 frontmatter에 `last_mapped_commit`을 갖는다. fg-ask가 그릴링 전 이 지도를 읽어 context rot를 줄인다.
- 그러나 지도는 **on-demand**라 코드가 바뀌어도 자동 갱신되지 않는다. 직전 매핑 이후 스킬이 7→11개로 늘고, `fg-complete→fg-cleanup→fg-done` 개명 사슬·ADR-0011/0012/0013 추가·`forge-prd.md` 제거가 있었다 — 옛 지도(특히 옛 CONCERNS.md가 가리키던 "forge-prd.md", "5→7 skills", "fg-complete")는 **이미 stale**했고 이 재생성이 그 부채를 갚는 행위다.
- ADR-0011에서 codebase 지도는 **전역 예외**로 항상 최상위 `.forge/codebase/`에 둔다(브랜치-로컬 아님) — 갓 만든 브랜치의 지도가 비어 fg-ask가 못 읽는 것을 막기 위함. 즉 지도는 브랜치 간 공유되므로, 한 브랜치에서 stale해지면 모든 브랜치가 stale한 지도를 본다.

**발산 위험:** 개명·구조 변경 후 fg-map을 다시 돌리지 않으면 fg-ask가 틀린 이름·없는 파일을 사실로 읽는다(예: 이번처럼 옛 CONCERNS.md가 제거된 forge-prd.md를 권위 문서로 서술).

**예방책:** 스킬 추가·개명·상태 계약 변경 후 `fg-map` 재실행. fg-ask의 stale 경고가 실제 트리거되는지 확인.

---

## 8. .gitignore 화이트리스트의 정교함 — 영속/휘발 비대칭 (ADR-0011)

**위치:** `.gitignore`(`.forge/*` 제외 후 화이트리스트로 되살림)

**상황:**
- 현재 규칙: `.forge/*`로 전부 제외한 뒤 `!.forge/CONTEXT.md`·`!.forge/adr/`·`!.forge/retro/`·`!.forge/codebase/`·`!.forge/config.json`·`!.forge/branch/`만 추적으로 되살린다.
- **의도된 비대칭(ADR-0011):** 기본 브랜치의 휘발 상태(plan/run/STATUS/backlog/executed/done)는 gitignored, 그러나 비-기본 브랜치의 forge 루트 `.forge/branch/<branch>/`는 **통째로 git 추적**된다. 즉 같은 종류의 파일(plan/run/STATUS)이 브랜치에 따라 추적/비추적이 갈린다.

**발산 위험:**
- 새 영속 문서 종류를 추가하면 화이트리스트에 `!` 줄을 빠뜨리기 쉽고, 그러면 조용히 untracked가 된다(에러 없음).
- `.forge/branch/` 전체 추적은 plan/run/STATUS가 커밋·PR에 남는 비대칭을 감수한 것 — 이를 모르고 "왜 브랜치에선 휘발 상태가 커밋되지?"라는 혼란이 생길 수 있다.
- 통합은 `git merge` 후 **fg-merge**가 별도로 돌아야 완성된다(2-트랙). git merge만 하고 fg-merge를 잊으면 `.forge/branch/<branch>/`가 main에 잔류한다.

**예방책:** 새 영속 문서 추가 시 `.gitignore`에 `!` 줄 동반. 브랜치 작업 후 `git merge` → `fg-merge <branch>` 2단계를 한 묶음으로 기억.

---

## 9. 매니페스트 3중 동기화 + description 역할 분화

**위치:** `.claude-plugin/plugin.json`·`.claude-plugin/marketplace.json`

**상황(검증 완료, 현재 0.4.1로 3곳 일치):**
- 버전 3곳 동기화: `plugin.json` `version` / `marketplace.json` `metadata.version` / `plugins[0].version` — 현재 모두 `0.4.1`.
- **description 역할 분화(CLAUDE.md 배포 규칙):**
  - `marketplace.json` `metadata.description` = 루프(`ask·plan → execute → retro → done`)만 정의하는 한 줄 태그라인 → **루프 밖 유틸리티(fg-map·fg-quick·fg-status·fg-next·fg-tdd·fg-merge·fg-cleanup)는 넣지 않는다**. 현재 정합 ✓.
  - `plugins[].description`·`plugin.json` `description` = 11개 스킬 전부 나열 → 루프 밖 스킬도 반영. 현재 "Eleven fg-* skills" / "Seven more sit outside the loop"로 정합 ✓.

**발산 위험:**
- 빌드/CI가 없어 버전 불일치·개수 불일치를 자동으로 못 잡는다. 스킬을 추가하면 두 description의 "Eleven"·"Seven more" 같은 **하드코딩된 개수 단어**까지 손으로 고쳐야 한다.
- 루프 밖 스킬을 metadata.description에 끼우면 루프 정의가 흐려진다(`2026-06-04-fg-map-skill.md` 회고가 이 구분의 기원).

**예방책:** 배포 전 `node -e "JSON.parse(...)"` JSON 유효성 + 3곳 버전 일치 확인. 스킬 개수 변경 시 두 description의 개수 단어 동기. `curl raw.githubusercontent.com/.../main/...`으로 원격 main 버전 실측(설치는 main을 당김).

---

## 10. fg-ask의 verbatim 분할 (grill-with-docs 원문 ↔ Forge 통합)

**위치:** `skills/fg-ask/SKILL.md`

**상황:**
- `skills/fg-ask/SKILL.md`는 grill-with-docs 원문(Matt Pocock)을 **영문 그대로 이식**한 verbatim 본문과, forge 루프에 연결하는 "Forge integration" 글루(backlog 산출·retro 환류·codebase 지도 읽기·핸드오프)가 한 파일에 공존한다.
- CLAUDE.md: "verbatim 본문과 Forge integration 섹션은 따로 움직이므로, 둘 중 하나만 고치면 계약이 깨진다."

**발산 위험:**
- verbatim 본문을 수정하면 Forge integration의 참조(형식 문서 경로 등)가 어긋나고, Forge integration을 수정하면 원문 방법론과 불일치할 수 있다.
- upstream 원문이 갱신되면 경로는 `.forge/` 계약에 정합하되 본문은 원문 유지 — 정합 누락이 쉽다(항목 1과 연결).

**예방책:** 수정 전 분할 경계 확인. Forge integration 편집 후 형식 문서 경로 grep(항목 1의 grep). upstream 동기화 시 경로 정합이 되돌려지지 않게 diff 검증.

---

## 11. 빌드·테스트·CI 부재 — 검증은 전적으로 수동·설치 후

**위치:** 리포 전역 (package.json/Makefile/CI 없음)

**상황:**
- 유일한 자동 검증은 매니페스트 JSON 유효성 한 줄(`node -e "...JSON.parse..."`)과 `awk '/^name:/'`로 SKILL.md frontmatter `name` 누락 확인뿐이다. 단위 테스트가 없다.
- 실동작 검증은 `/plugin marketplace add` → `/plugin install`로 설치해 트리거해보는 것뿐인데, 둘 다 interactive라 에이전트가 못 돌린다. 게다가 설치는 **GitHub 기본 브랜치(main)를 당긴다** — 로컬에서 검증할 수 없고 push 후에야 가능.

**발산 위험:**
- 스킬 frontmatter `name` 오타·매니페스트 깨짐·경로 참조 어긋남이 모두 **설치 실패 또는 스킬 미탐색**으로만 드러나며, 그 시점은 push 후다.

**예방책:** 편집 후 항상 JSON 유효성 + `name:` frontmatter 존재를 grep으로 실측. 비-trivial 변경은 샌드박스 dogfood(항목 2)로 보강.

---

## 참고: 의도적 설계, 비용이지 부채가 아님

위 11항목은 forge의 두 기둥(대화형 그릴링·문서=연료)과 4단계 루프(`ask·plan → execute → retro → done`)를 지키기 위한 **불가피한 비용**이다. 빌드 시스템이 없는 것조차 "산출물이 Markdown/JSON뿐"이라는 설계의 귀결이다. 따라서 대응은 제거가 아니라 **의식화·grep 검증·샌드박스 dogfood**다.
