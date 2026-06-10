---
last_mapped_commit: 0472a519cbb8275564cdbaa30469f2d0c5472842
mapped: 2026-06-10
---

# 테스트 (Testing)

**단위 테스트 프레임워크가 없다.** `package.json`, Makefile, CI 모두 없다. 산출물은 Markdown(`SKILL.md`, `*-FORMAT.md`)과 JSON(매니페스트)이므로, 여기서 "테스트"란 구조 검증과 설치-트리거 도그푸딩(behavioral dogfooding)을 뜻한다. 단위 테스트 스위트는 없으며, 있는 척하지 않는다.

## 검증 명령 (Validation Commands)

- **매니페스트 JSON 유효성** — 두 매니페스트 중 하나라도 편집한 뒤 반드시 실행한다(JSON이 깨지면 설치가 실패한다):
  ```bash
  node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
  ```
- **스킬 자동 탐색 점검** — 모든 `skills/*/SKILL.md`는 frontmatter `name:`이 있어야 탐색된다(없으면 탐색에서 누락):
  ```bash
  awk '/^name:/' skills/*/SKILL.md
  ```
- **원격 릴리스 검증** — 배포 후에 한다(`/plugin` 명령 자체는 interactive라 에이전트가 실행 못 함). 세 버전 필드가 원격 `main`에 반영됐는지 확인:
  ```bash
  curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json
  ```

## 동작/설치 테스트 (Behavioral / Install Testing)

- 유일한 실제 런타임 테스트는 **플러그인을 설치해 스킬을 트리거해 보는 것**이다: `/plugin marketplace add gyuha/forge`(또는 로컬 경로) 후 `/plugin install forge@forge`. 설치는 GitHub 기본 브랜치(`main`)를 당기므로, 변경을 설치-테스트하려면 먼저 `main`에 push되어 있어야 한다.
- `/plugin install`과 `/plugin marketplace update`는 **interactive 명령**이라 에이전트가 실행할 수 없다 — 사용자가 직접 친다. 에이전트가 검증할 수 있는 것은 설치 *전제조건*뿐이다(위의 원격 버전 필드 + frontmatter `name:` 존재 여부).

검증 흐름:
```
매니페스트 편집 → node JSON 검증 → awk name 점검 → push(main) → (사용자) /plugin install → 스킬 트리거
```

## 지시-스킬의 검증 게이트 (ADR-0009)

- 루프 순서는 run → verify → learn → done이다. `fg-run`의 핸드오프가 plan 목표에 대고 UAT를 수행해 STATUS `verified:`를 기록한다 — 봉인 가능 값은 `yes` / `skipped (사유)` / `n/a (사유)`, 차단 값은 `pending`(미검증) / `failed (사유)`(검증했으나 깨짐). `fg-done`은 검증 게이트를 회고 게이트보다 **먼저** 확인하며, 봉인 가능 값이 아니면 봉인하지 않는다.
- 이 스킬들은 **실행 가능한 런타임이 없는 지시 문서**라서, "실행"할 것이 없는 경우가 많다 — UAT가 자주 `verified: n/a`로 떨어진다. ADR-0009 이전 봉인 작업은 `verified: n/a (legacy pre-ADR-0009)`로 백필됐다.
- 진짜 엔드투엔드 동작 테스트는 fg-merge 생애주기에 대해 **샌드박스 도그푸딩**으로 수행됐다 — `.forge/done/2026-06-09-fg-merge-lifecycle-e2e/` 참조(브랜치 격리 상태를 실제 merge-and-integrate 사이클로 돌려본 것이지, 산문으로 단언한 게 아니다).

## 회고 게이트 (ADR-0002)

- 회고가 기본값이다. `fg-run`의 핸드오프는 `.forge/run.md`의 계획↔실제 divergence가 없거나 미미할 때만 "회고 / 건너뛰기"를 제시한다. 건너뛰기를 고르면 STATUS.md에 `retro: skipped (사유)`를 기록하고 회고 파일은 남기지 않는다. `fg-done`의 봉인 가드는 회고 파일 존재 **또는** `retro: skipped`를 통과 조건으로 인정한다. divergence가 크면 건너뛰기를 제시하지 않는다. (`fg-next all`은 예외로, divergence 무관 항상 회고를 자동 skip한다 — ADR-0010.)
