---
last_mapped_commit: 847fa4208a8ef8b709da41d36d106a3f3f92af29
mapped: 2026-06-11
---

# 테스트 (Testing)

**단위 테스트 프레임워크가 없다.** `package.json`, Makefile, CI 모두 없다. 산출물은 Markdown(`SKILL.md`, `*-FORMAT.md`)과 JSON(매니페스트)이므로, 여기서 "테스트"란 ① 구조 검증(JSON·frontmatter·원격 동기), ② 문서-전용 변경의 정적 grep 재검증(UAT), ③ 설치-트리거 도그푸딩, ④ 정합 감사 워크플로우(사실상의 회귀 테스트)를 뜻한다. 단위 테스트 스위트는 없으며, 있는 척하지 않는다.

## 검증 명령 (Validation Commands)

- **매니페스트 JSON 유효성** — 두 매니페스트 중 하나라도 편집한 뒤 반드시 실행한다(JSON이 깨지면 설치가 실패한다). `CLAUDE.md`에 정의된 한 줄:
  ```bash
  node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
  ```
- **스킬 자동 탐색 점검** — 모든 `skills/*/SKILL.md`는 frontmatter `name:`이 있어야 탐색된다(없으면 설치돼도 그 스킬만 누락). 현재 12/12:
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

- `.forge/done/2026-06-11-handoff-state-not-ask/STATUS.md` — `verified: yes (정적 — S1 3옵션·divergence가드·바로종료→fg-done·Under fg-next grep 확인, ... 4스킬 전환질문 전수 0)`
- `.forge/done/2026-06-11-consistency-audit-3/STATUS.md` — `verified: yes (정적 — fix-now 8건 grep 재검증 전수 통과 ... / JSON OK / frontmatter name 12/12 / record-only 5건 run.md 기록)`

패턴: "구 문구 grep → 0건, 신 문구 grep → 기대 건수, 보존돼야 할 게이트 grep → 잔존 확인 + JSON 검증". ADR-0009 이전 봉인 작업은 `verified: n/a (legacy pre-ADR-0009)`로 백필됐고, 지시 문서 특성상 UAT가 `n/a`로 떨어지는 경우도 정당하다.

## 동작/설치 테스트 (Behavioral / Install Testing)

- 유일한 실제 런타임 테스트는 **플러그인을 설치해 스킬을 트리거해 보는 것**이다: `/plugin marketplace add gyuha/forge`(또는 로컬 경로) 후 `/plugin install forge@forge`. 설치는 GitHub 기본 브랜치(`main`)를 당기므로, 변경을 설치-테스트하려면 먼저 `main`에 push되어 있어야 한다.
- `/plugin install`과 `/plugin marketplace update`는 **interactive 명령이라 에이전트가 실행할 수 없다** — 사용자가 직접 친다. 에이전트가 검증할 수 있는 것은 설치 *전제조건*뿐이다(위의 원격 버전 필드 + frontmatter `name:` 존재 여부).
- 진짜 엔드투엔드 동작 테스트가 필요했던 유일한 사례는 fg-merge 생애주기의 **샌드박스 도그푸딩**이다 — `.forge/done/2026-06-09-fg-merge-lifecycle-e2e/` 참조(브랜치 격리 상태를 실제 merge-and-integrate 사이클로 돌려본 것이지, 산문으로 단언한 게 아니다).

검증 흐름:
```
매니페스트/스킬 편집 → node JSON 검증 → awk name 점검 → 완료기준 grep 재검증(UAT, verified: 기록)
  → push(main) → curl 원격 버전 확인 → (사용자) /plugin install → 스킬 트리거
```

## 정합 감사 워크플로우 — 사실상의 회귀 테스트

규약/ADR과 스킬 본문이 **조용히 드리프트하는 것**이 이 리포의 반복 실패 모드다(`.forge/retro/2026-06-11-handoff-state-not-ask.md`). 회귀를 잡는 사실상의 메커니즘은 주기적 **정합 감사**이며, 지금까지 3차례 수행됐다:

1. **1차** (2026-06-09, `.forge/done/2026-06-09-fix-stale-refs-and-hygiene/`) — stale 참조·위생 정리.
2. **2차** (커밋 d54dbf의 d54dd9c 계열, "2차 심층 감사") — 시나리오 워크스루로 설계 공백·드리프트 20건 해소.
3. **3차** (2026-06-11, `.forge/done/2026-06-11-consistency-audit-3/`) — v0.4.5 변경분(ADR-0015 핸드오프 재설계·fg-eco·Language 강화) 한정 점검. **하이브리드 실행: 감사 = 병렬 5 에이전트 워크플로우, 수정 = 메인 세션.** 발견 47건을 fix-now 8 · record-only 5 · by-design 5 · ok 29로 분류 — 기계적·저위험 항목만 즉시 수정하고, 트레이드오프가 있는 설계 이슈는 run.md에 기록만(백로그 진입은 fg-ask 그릴링을 거쳐야 하므로 자동 plan 생성 금지). 그 수정분이 현재 작업 트리의 미커밋 변경이다.

감사의 점검 카테고리(3차 plan, `.forge/done/2026-06-11-consistency-audit-3/plan.md`): A 매니페스트·README 하드코딩(스킬 개수/목록/긴 description 동기) · B 상태 계약 어휘(`status:`/`verified:`/`retro:` 허용값과 `forge-slug`/`task:` 마커가 스킬 간 일치) · D 교차 참조 경로 실존(`../fg-ask/CONTEXT-FORMAT.md` 류) · E 변경분 시나리오 워크스루 · F README 번역 쌍 동기. DoD는 "발견 전 항목이 수정됨/기록됨 처리 + grep 재검증·JSON 검증 통과".

3차 회고의 방법론 교훈(`.forge/retro/2026-06-11-consistency-audit-3.md`): **감사 시드는 가설로 적되 결론을 예단하지 말 것** — "X가 누락됐을 것"처럼 수정을 전제하면 감사를 편향시킨다. "X 지점을 검증하라"로 적고 by-design 판정을 허용해야 한다.

## 루프 자체의 검증 게이트 (참고)

- **ADR-0009 (봉인 전 검증)**: 루프 순서는 run → verify → learn → done. `fg-run` 핸드오프가 plan 목표에 대고 UAT를 수행해 STATUS `verified:`를 기록한다 — 봉인 가능 `yes`/`skipped`/`n/a`, 차단 `pending`/`failed`. `fg-done`은 검증 게이트를 회고 게이트보다 먼저 확인하며, `failed`는 waiver 없이 fresh re-run 재검증으로만 봉인된다.
- **ADR-0002 (회고 skip)**: 회고가 기본값. `.forge/run.md`의 계획↔실제 divergence가 없거나 미미할 때만 skip을 제시하고, 고르면 `retro: skipped (사유)`를 기록한다. (`fg-next all`은 예외 — divergence 무관 항상 자동 skip, ADR-0010.)
