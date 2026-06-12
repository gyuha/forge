---
last_mapped_commit: b45521cd5fc2f536cc212e559af52c3939a5b0a5
mapped: 2026-06-12
---

# 테스트 (Testing)

**단위 테스트 프레임워크가 없다.** `package.json`, Makefile, CI 모두 없다. 산출물은 Markdown(`SKILL.md`, `*-FORMAT.md`)과 JSON(매니페스트)이므로, 여기서 "테스트"란 ① 구조 검증(JSON·frontmatter·원격 동기), ② 문서-전용 변경의 정적 grep 재검증(UAT), ③ 설치-트리거 도그푸딩, ④ 정합 감사 워크플로우(사실상의 회귀 테스트), 그리고 이번 작업 트리부터 ⑤ **TDD on의 "검증-선행 체크리스트" 해석**과 ⑥ **fg-loop의 기계 검증 정지 조건**(ADR-0016)을 뜻한다. 단위 테스트 스위트는 없으며, 있는 척하지 않는다.

## 검증 명령 (Validation Commands)

- **매니페스트 JSON 유효성** — 두 매니페스트 중 하나라도 편집한 뒤 반드시 실행한다(JSON이 깨지면 설치가 실패한다). `CLAUDE.md`에 정의된 한 줄:
  ```bash
  node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
  ```
- **스킬 자동 탐색 점검** — 모든 `skills/*/SKILL.md`는 frontmatter `name:`이 있어야 탐색된다(없으면 설치돼도 그 스킬만 누락). 현재 13/13(`fg-loop` 포함):
  ```bash
  awk '/^name:/' skills/*/SKILL.md
  ```
- **원격 릴리스 검증** — 배포(push) 후에 한다. 원격 `main`의 버전 3곳(`plugin.json`의 `version`, `marketplace.json`의 `metadata.version`·`plugins[0].version`)이 반영됐는지 확인:
  ```bash
  curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json
  ```

## 정적 grep 재검증 = 문서-전용 변경의 UAT (evidence-first)

이 리포의 변경은 대부분 지시 문서 편집이라 "실행해 볼" 런타임이 없다. 그래서 사실상의 UAT 표준은 **plan의 완료 기준(completion criterion)을 grep으로 재검증하고, 그 결과를 STATUS `verified:`에 한 줄 증거로 남기는 것**이다 — `skills/fg-run/SKILL.md`의 UAT 규약이 `yes (<evidence>)`에 "실행한 명령/관찰한 출력"을 요구하기 때문이다("사람이 그렇다고 했다"만으로는 부족).

실제 봉인된 예시(`.forge/done/*/STATUS.md`):

- `.forge/done/2026-06-12-add-fg-loop/STATUS.md` — `verified: yes (TDD 검증-선행 체크 전수 통과 — awk name fg-loop·필수 요소 grep 13종·skills 13디렉터리·매니페스트 Thirteen/Nine+metadata 불변+JSON OK·README 양판 13/9 동기·CLAUDE.md ADR-0016)`
- `.forge/done/2026-06-11-consistency-audit-3/STATUS.md` — `verified: yes (정적 — fix-now 8건 grep 재검증 전수 통과 ... / JSON OK / frontmatter name 12/12 / record-only 5건 run.md 기록)`

패턴: "구 문구 grep → 0건, 신 문구 grep → 기대 건수, 보존돼야 할 게이트 grep → 잔존 확인 + JSON 검증". ADR-0009 이전 봉인 작업은 `verified: n/a (legacy pre-ADR-0009)`로 백필됐고, 지시 문서 특성상 UAT가 `n/a`로 떨어지는 경우도 정당하다.

## TDD on의 해석: 검증-선행 체크리스트 (verification-first) — 현행 운용

테스트 프레임워크가 없는 이 Markdown 리포에서 plan 마커 `<!-- tdd: on -->`(ADR-0008)은 "failing test 먼저"를 문자 그대로 적용할 수 없다. 현행 해석은 **검증-선행 체크리스트**다: 각 슬라이스의 완료 기준(grep 단언·awk 점검·node JSON 검증)을 **편집하기 전에 체크 목록으로 먼저 고정**하고, 편집 후 그 체크를 전수 통과시킨다 — "test-first"의 자리에 "check-first"가 들어간 것이다.

- **첫 실증: 작업 #23 add-fg-loop** (`.forge/done/2026-06-12-add-fg-loop/`). plan(`plan.md` 첫머리 `<!-- tdd: on -->`, 말미 각주)이 해석을 명문으로 못 박았다: *"각 슬라이스는 위 완료 기준(grep 단언·JSON 검증)을 편집 전에 체크 목록으로 먼저 고정하고, 편집 후 그 체크를 통과시키는 검증-선행 방식으로 수행한다."* 실행 기록(`run.md`)과 회고(`.forge/retro/2026-06-12-add-fg-loop.md`)가 "체크리스트 고정 → 5슬라이스 편집 → 전수 통과(`verified: yes`)"로 작동을 확인했다.
- **지위: plan 본문의 해석 각주일 뿐, 아직 형식 문서에 명문화되지 않았다.** 같은 해석이 반복되면 `skills/fg-run/PLAN-FORMAT.md`(tdd 마커 규칙)나 `skills/fg-tdd/SKILL.md`에 승급할 후속 후보다(회고의 명시 판단). 현재 `PLAN-FORMAT.md`의 tdd 규칙은 코드 리포 전제의 "failing test before the implementation" 서술 그대로다.
- **한계(회고 자평)**: 이번 작업엔 편집 누락이 없어서, 체크 선-고정이 누락을 *실제로 잡는지*는 아직 미검증이다.

검증-선행 흐름:
```
plan 그릴링(tdd: on) → 슬라이스별 완료 기준을 grep/JSON 체크로 사전 고정
  → 편집 수행 → 체크 전수 재실행 → 전수 통과 → STATUS verified: yes (<체크 증거>)
                     ↓ 실패
                해당 슬라이스 수정 후 재실행
```

## fg-loop의 기계 검증 정지 조건 — 새 goal 검증 표면 (ADR-0016)

13번째 스킬 `fg-loop`(`skills/fg-loop/SKILL.md`, 미커밋 작업 트리)가 **작업 단위 UAT 위에 goal 단위 검증 층**을 추가했다. 기초 질의(대화)가 정지 조건을 `.forge/loop.md`(goal 계약, 휘발)에 체크 목록으로 못 박는데, **모든 체크는 에이전트가 실행 가능해야 한다** — grep 단언(`grep -c X file` ≥ 1)·테스트·빌드·JSON 파스 등, fg-run의 공격적 UAT와 같은 형태(`skills/fg-loop/SKILL.md` §1). "AI가 만족되었다고 생각함"은 정지 조건으로 인정하지 않는다(`.forge/adr/0016-fg-loop-goal-driven-bounded-replan.md` 결정 1). 체크로 못 박을 수 없는 모호한 goal은 주행을 시작하지 않고 정식 루프(fg-ask)로 돌린다.

- **실행 시점**: 매 봉인 직후와 백로그가 빌 때마다 정지 조건 체크를 전수 실행해 `loop.md`의 체크박스를 갱신한다(§2). 전부 통과 → 요약 보고 후 `loop.md` 삭제(goal 충족). 일부 실패 + 백로그 빔 → 상한(기본 3라운드) 내에서 실패 체크에 직접 추적되는 fix-forward plan을 자동 생성(`<!-- generated-by: fg-loop -->` 마커)한다.
- **검증 게이트 불변**: 작업 단위의 ADR-0009(검증 없는 봉인 금지)는 그대로다 — fg-loop도 `verified: failed`를 절대 봉인하지 않고 fg-run의 failed-처리(fix-and-re-run → 재검증)에 맡긴다. 무진전 가드: 같은 체크가 2연속 실패·무진전이면 상한 전이라도 조기 중단한다(§3).
- **의미**: 종전까지 검증 표면은 "슬라이스 완료 기준 → 작업 UAT(`verified:`)" 2층이었다. fg-loop가 그 위에 "goal 정지 체크" 3층을 얹었고, 세 층 모두 같은 기계 검증 어휘(grep/test/JSON)를 쓴다.

## 동작/설치 테스트 (Behavioral / Install Testing)

- 유일한 실제 런타임 테스트는 **플러그인을 설치해 스킬을 트리거해 보는 것**이다: `/plugin marketplace add gyuha/forge`(또는 로컬 경로) 후 `/plugin install forge@forge`. 설치는 GitHub 기본 브랜치(`main`)를 당기므로, 변경을 설치-테스트하려면 먼저 `main`에 push되어 있어야 한다.
- `/plugin install`과 `/plugin marketplace update`는 **interactive 명령이라 에이전트가 실행할 수 없다** — 사용자가 직접 친다. 에이전트가 검증할 수 있는 것은 설치 *전제조건*뿐이다(위의 원격 버전 필드 + frontmatter `name:` 존재 여부).
- 진짜 엔드투엔드 동작 테스트가 필요했던 유일한 사례는 fg-merge 생애주기의 **샌드박스 도그푸딩**이다 — `.forge/done/2026-06-09-fg-merge-lifecycle-e2e/` 참조.

검증 흐름:
```
매니페스트/스킬 편집 → node JSON 검증 → awk name 점검(13/13) → 완료기준 grep 재검증(UAT, verified: 기록)
  → push(main) → curl 원격 버전 확인 → (사용자) /plugin install → 스킬 트리거
```

## 정합 감사 워크플로우 — 사실상의 회귀 테스트

규약/ADR과 스킬 본문이 **조용히 드리프트하는 것**이 이 리포의 반복 실패 모드다(`.forge/retro/2026-06-11-handoff-state-not-ask.md`). 회귀를 잡는 사실상의 메커니즘은 주기적 **정합 감사**이며, 지금까지 3차례 수행됐다:

1. **1차** (2026-06-09, `.forge/done/2026-06-09-fix-stale-refs-and-hygiene/`) — stale 참조·위생 정리.
2. **2차** ("2차 심층 감사") — 시나리오 워크스루로 설계 공백·드리프트 20건 해소.
3. **3차** (2026-06-11, `.forge/done/2026-06-11-consistency-audit-3/`) — v0.4.5 변경분 한정 점검. **하이브리드 실행: 감사 = 병렬 5 에이전트 워크플로우, 수정 = 메인 세션.** 발견 47건을 fix-now 8 · record-only 5 · by-design 5 · ok 29로 분류. 그 수정분은 v0.4.6으로 커밋됐다.

감사의 점검 카테고리(3차 plan, `.forge/done/2026-06-11-consistency-audit-3/plan.md`): A 매니페스트·README 하드코딩(스킬 개수/목록/긴 description 동기) · B 상태 계약 어휘(`status:`/`verified:`/`retro:` 허용값과 `forge-slug`/`task:` 마커가 스킬 간 일치) · D 교차 참조 경로 실존(`../fg-ask/CONTEXT-FORMAT.md` 류) · E 변경분 시나리오 워크스루 · F README 번역 쌍 동기. DoD는 "발견 전 항목이 수정됨/기록됨 처리 + grep 재검증·JSON 검증 통과".

3차 회고의 방법론 교훈(`.forge/retro/2026-06-11-consistency-audit-3.md`): **감사 시드는 가설로 적되 결론을 예단하지 말 것** — "X가 누락됐을 것"처럼 수정을 전제하면 감사를 편향시킨다. "X 지점을 검증하라"로 적고 by-design 판정을 허용해야 한다.

## 루프 자체의 검증 게이트 (참고)

- **ADR-0009 (봉인 전 검증)**: 루프 순서는 run → verify → learn → done. `fg-run` 핸드오프가 plan 목표에 대고 UAT를 수행해 STATUS `verified:`를 기록한다 — 봉인 가능 `yes`/`skipped`/`n/a`, 차단 `pending`/`failed`. `fg-done`은 검증 게이트를 회고 게이트보다 먼저 확인하며, `failed`는 waiver 없이 fresh re-run 재검증으로만 봉인된다. `verified: failed`는 fg-next all에서는 벽이지만, **fg-loop에서는 상한 내 자동 fix-forward 대상**이다 — 이 벽 완화가 fg-loop의 존재 이유다(ADR-0016).
- **ADR-0002 (회고 skip)**: 회고가 기본값. `.forge/run.md`의 계획↔실제 divergence가 없거나 미미할 때만 skip을 제시하고, 고르면 `retro: skipped (사유)`를 기록한다. (`fg-next all`과 `fg-loop`는 예외 — divergence 무관 항상 자동 skip, 학습은 보관된 run.md에 보존돼 추후 사람의 fg-learn 일괄 승급으로 환류. ADR-0010·ADR-0016.)
