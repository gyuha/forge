---
last_mapped_commit: 21c8bdbf3b13543c1aec209669ec38b57f8f25e2
mapped: 2026-06-04
---

# Testing & Validation

## No Unit-Test Framework

이 저장소는 **단위 테스트 프레임워크가 없다.** package.json, Makefile, CI 파이프라인, 린팅 도구가 없다. 산출물이 전부 Markdown과 JSON이고, 실행 가능한 코드가 없기 때문이다.

"개발" = Markdown (SKILL.md, 형식 문서) 및 JSON (매니페스트) 편집. "검증" = (a) 매니페스트 유효성, (b) 실제 동작 테스트.

## Validation Method 1: Manifest JSON Validity

매니페스트를 수정한 후 **반드시** 유효성을 확인한다.

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

이 한 줄이 "OK"를 출력하면 JSON 유효성 통과. 만약 파일이 깨져 있으면 설치 시 실패한다.

## Validation Method 2: Real Testing = Install + Trigger Skills

**단위 테스트 없음.** 실제 검증은 플러그인을 설치하고 각 스킬을 손으로 트리거해본다.

### Installation for Testing

```bash
# 마켓플레이스 추가 (GitHub)
/plugin marketplace add gyuha/forge

# 플러그인 설치
/plugin install forge@forge
```

플러그인은 GitHub의 **main 브랜치를 당긴다.** 따라서 **설치 테스트하려면 변경사항이 main에 push되어 있어야 한다.**

### Testing Each Skill

플러그인 설치 후, 각 스킬을 트리거하여 동작을 확인한다:

- **fg-ask** — `"새 작업 시작"` 또는 `"forge로 시작"` 등으로 시작. 그릴링 흐름이 진행되고, 계획이 `.forge/backlog/<slug>.md`에 생성되는지 확인.
- **fg-run** — `"계획 실행"` 또는 `"forge run"`으로 트리거. 백로그 메뉴(여럿일 경우)가 나타나고, 선택한 plan이 `.forge/plan.md`로 승격되고 Dynamic Workflow로 실행되는지 확인.
- **fg-learn** — `"회고하자"` 또는 `"forge learn"`으로 트리거. run.md와 plan.md를 읽어 회고 질문을 하고, `.forge/retro/YYYY-MM-DD-<slug>.md`에 회고가 기록되는지 확인.
- **fg-cleanup** — `"작업 정리"` 또는 `"forge cleanup"`으로 트리거. 활성 슬롯의 파일들이 `.forge/done/<date-slug>/`로 이동되고, 활성 상태가 비워지는지 확인.
- **fg-map** — `"코드베이스 분석"` 또는 `"코드베이스 지도"`로 트리거. `.forge/codebase/STACK.md`, `ARCHITECTURE.md` 등 7개 문서가 생성되는지 확인.
- **fg-quick** — `"빠르게 처리"` 또는 `"forge quick"`으로 트리거. 변경사항이 바로 실행되고, `.forge/quick/LOG.md`에 한 줄이 기록되는지 확인.
- **fg-status** — `"어디까지 했지"` 또는 `"forge status"`로 트리거. 현황 테이블이 출력되는지 확인(파일 쓰기는 없음).

### Dogfooding Pattern: Forge Develops Itself

forge는 **자신의 `.forge/` 루프로 자신을 개발한다.** 새 스킬을 추가하거나 기존 스킬을 개선할 때:

1. **fg-ask** — "fg-map 스킬 추가" 같은 작업을 그릴링하고, 계획을 `.forge/backlog/`에 적재.
2. **fg-run** — 계획(Markdown/JSON 편집)을 실행. 실제로는 본 세션에서 직접 편집하거나, Dynamic Workflow로 병렬 서브에이전트를 띄움.
3. **fg-learn** — 회고하면서, 새 스킬 추가로 얻은 학습(매니페스트 두 description의 역할 구분 등)을 CLAUDE.md에 승격.
4. **fg-cleanup** — 작업 완료, 회고 기록, 활성 상태 비우기.

실제 사례: `.forge/retro/2026-06-04-fg-map-skill.md` 참조. fg-map 스킬 추가 작업이 이 4단계를 거쳐 완료되었으며, 회고에서 도출된 학습(매니페스트 description 역할 구분)이 CLAUDE.md에 승격되었다.

## Absence of CI

**CI 파이프라인이 없다.** GitHub Actions, pre-commit hook, 자동 린팅이 없다.

이유:
- 산출물이 Markdown/JSON이라 실행 가능한 코드가 없다.
- 매니페스트 유효성만 기계적으로 확인할 수 있는데, 이는 간단한 한 줄 node 커맨드로 충분하다.
- 실제 동작 검증은 손으로 한다(플러그인 설치 + 스킬 트리거).

## When to Validate

다음 시점에 검증을 실행한다:

1. **매니페스트 편집 후** — JSON 유효성 확인 (`node` 한 줄)
2. **스킬 SKILL.md 또는 형식 문서 편집 후** — 실제 설치하여 해당 스킬 트리거, 산출 문서 확인
3. **배포 전** — CHANGELOG.md 작성 → 버전 범프(3곳) → JSON 유효성 확인 → commit/push
4. **배포 후(선택)** — 마켓플레이스에서 설치해본 뒤, 변경된 스킬을 트리거하여 실제 동작 재확인

## Example: How a Skill Change is Validated

fg-run을 수정했다고 하자.

1. `skills/fg-run/SKILL.md` 편집 (또는 `PLAN-FORMAT.md`)
2. 변경사항을 main으로 commit/push
3. 테스트 세션에서 `/plugin marketplace add gyuha/forge` (또는 로컬 경로) → `/plugin install forge@forge`
4. `"계획 실행"` / `"forge run"`으로 스킬 트리거
5. 실제 동작 확인:
   - 백로그 메뉴가 올바르게 나타나는가
   - plan.md가 `.forge/plan.md`로 올바르게 승격되는가
   - Dynamic Workflow가 올바르게 빌드되고 실행되는가
   - run.md와 STATUS.md가 올바르게 생성되는가

문제가 발견되면 다시 2번부터 반복.

## Known Testing Gaps

현재 검증 범위의 한계:

- **fg-map 실 실행 검증 미완료** — `.forge/codebase/` 7개 문서가 실제로 생성되는지, `last_mapped_commit` 신선도 판단이 작동하는지는 배포 후 실 트리거로 확인 필요. (`.forge/retro/2026-06-04-fg-map-skill.md` 참조)
- **멀티 컨텍스트 구조 검증 미완료** — fg-ask가 `CONTEXT-MAP.md`와 컨텍스트별 `CONTEXT.md`를 제대로 찾고 읽는지는 멀티 컨텍스트 프로젝트에서 실제 테스트 필요.
- **장기 상태 추적 검증** — 여러 작업이 동시에 backlog/executed에 있을 때 fg-learn, fg-cleanup이 정확히 진행하는지는 복잡한 시나리오에서만 드러남.

## Skill Verification Checklist (Before Deploy)

배포 전, 각 수정된 스킬에 대해:

- [ ] Markdown 문법 확인 (frontmatter, 코드 블록, 링크)
- [ ] 영문 본문 / 사용자 언어 출력의 구분 명확한가
- [ ] 형식 문서 참조 경로 정확한가 (`../fg-ask/` 등 상대경로 또는 절대경로)
- [ ] CLAUDE.md의 상태 계약 (`.forge/` 파일 입출력)과 일치하는가
- [ ] 핸드오프 메시지가 자연스러운 대화체인가
- [ ] 배포 후 실제 플러그인 설치로 트리거 테스트

## Manifest Verification Checklist (Before Deploy)

- [ ] `plugin.json`에서 `version` 필드 업데이트 (X.Y.Z 형식)
- [ ] `marketplace.json`에서 `metadata.version`과 `plugins[0].version` 모두 업데이트 (3곳 동기)
- [ ] JSON 유효성 확인: `node -e "..."`
- [ ] CHANGELOG.md 최상단에 새 버전 섹션 추가 (## [X.Y.Z] - YYYY-MM-DD)
- [ ] commit 메시지 `chore(release): vX.Y.Z` 형식
- [ ] main 브랜치로 push 완료 (설치는 main을 당기므로 필수)
