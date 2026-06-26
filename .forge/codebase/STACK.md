---
last_mapped_commit: 2059a08bee17a9fbb97e6e938958f5ed813bdb2d
mapped: 2026-06-26
---

# STACK.md — forge의 기술 스택과 패키징 모델

forge는 코드를 빌드하는 프로젝트가 아니라 **Claude Code 플러그인**이다. 산출물은 전부 Markdown과 JSON이며, package.json·Makefile·CI·테스트 러너 같은 빌드 시스템이 없다. "개발"은 Markdown/JSON 편집이고, 검증은 매니페스트 JSON 파싱 한 줄과 실제 설치·트리거뿐이다.

## 언어와 포맷

리포에 컴파일·실행되는 애플리케이션 코드는 없다. 구성 요소는 세 종류다.

- **Markdown** — 스킬 본문(`skills/<name>/SKILL.md`), 형식 정의 문서(`*-FORMAT.md`, `FORGE-ROOT.md`), 루트 문서(`README.md`·`README.ko.md`·`CLAUDE.md`·`CHANGELOG.md`), `docs/*.md`. 스킬 본문과 형식 문서는 영문으로 작성하지만, 스킬이 사용자에게 출력하는 언어와 사용자 프로젝트에 남는 산출 문서는 사용자 언어를 따른다.
- **JSON** — 플러그인/마켓플레이스 매니페스트 두 개(`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`). 사용자 프로젝트 런타임에는 `.forge/config.json`도 JSON이지만 그것은 사용자 측 휘발/설정 상태이지 리포 소스가 아니다.
- **Bash + Node.js** — 결정론적 상태 조사와 statusline 표시에 쓰이는 실행 코드. ADR-0022에 따라 각 운영 스크립트는 `.sh`(bash, 1차) + `.js`(node, 폴백) 트윈으로 제공된다.
  - `scripts/forge-status.sh` / `scripts/forge-status.js` — `.forge/` 상태를 결정적으로 조사해 테이블로 출력(ADR-0020). fg-status·fg-next가 호출.
  - `scripts/resolve-forge-root.sh` / `scripts/resolve-forge-root.js` — 브랜치별 forge 루트 경로를 계산해 출력(ADR-0011).
  - `scripts/forge-statusline.sh` / `scripts/forge-statusline.js` — `.forge/`를 읽어 한 줄 진행 상태를 stdout에 찍는 display-only 조각(ADR-0017).
  - `scripts/forge-statusline-wrapper.sh` — 기존 statusLine과 forge 조각을 합성하는 래퍼(bash 전용).
  - `scripts/*.parity.test.sh` — 각 `.sh`·`.js` 트윈의 출력 동일성을 같은 fixture로 검증하는 패리티 테스트. 자동 실행 CI는 없고, 수동으로 돌린다.
  - 스크립트 포터블 규칙: shebang `#!/usr/bin/env bash`(`/bin/bash` 금지), `bash script.sh`로 호출(`./` 금지), `jq` 의존 없이 `sed`로 방어적 JSON 추출.

## 플러그인 패키징 모델 (리포 루트 = 플러그인 루트 = 마켓플레이스)

`harness` 플러그인과 동일한 단일 리포 패턴이다. 리포 루트 하나가 플러그인 루트이면서 동시에 그 자신을 등록하는 마켓플레이스다.

- `.claude-plugin/plugin.json` — 플러그인 매니페스트. `skills/`가 자동 탐색되므로 `skills` 필드는 생략돼 있다.
- `.claude-plugin/marketplace.json` — 이 리포를 마켓플레이스로 등록. `plugins[0].source`가 `"./"`로, 루트가 곧 플러그인임을 가리킨다.

설치 흐름: `/plugin marketplace add gyuha/forge` → `/plugin install forge@forge` (둘 다 사용자가 직접 치는 interactive 명령).

## 스킬 자동 탐색 (식별자 = frontmatter의 `name`)

스킬은 `skills/<dir>/SKILL.md` 경로로 자동 탐색된다. **스킬 식별자는 디렉터리명이 아니라 SKILL.md frontmatter의 `name` 필드**다. 현재 18개 스킬이 있고 각 `SKILL.md`의 `name`이 디렉터리명과 일치한다.

```
skills/fg-adversarial-review/SKILL.md   →  name: fg-adversarial-review
skills/fg-agents/SKILL.md               →  name: fg-agents
skills/fg-ask/SKILL.md                  →  name: fg-ask
skills/fg-cleanup/SKILL.md              →  name: fg-cleanup
skills/fg-doctor/SKILL.md               →  name: fg-doctor
skills/fg-done/SKILL.md                 →  name: fg-done
skills/fg-drop/SKILL.md                 →  name: fg-drop
skills/fg-eco/SKILL.md                  →  name: fg-eco
skills/fg-learn/SKILL.md                →  name: fg-learn
skills/fg-loop/SKILL.md                 →  name: fg-loop
skills/fg-map/SKILL.md                  →  name: fg-map
skills/fg-merge/SKILL.md                →  name: fg-merge
skills/fg-next/SKILL.md                 →  name: fg-next
skills/fg-quick/SKILL.md                →  name: fg-quick
skills/fg-run/SKILL.md                  →  name: fg-run
skills/fg-status/SKILL.md               →  name: fg-status
skills/fg-statusline/SKILL.md           →  name: fg-statusline
skills/fg-tdd/SKILL.md                  →  name: fg-tdd
```

설치 전제 검증 시 `awk '/^name:/'`로 `skills/*/SKILL.md`의 frontmatter `name` 누락 여부를 확인한다.

형식 정의 문서는 소유 스킬 디렉터리에 한 벌만 둔다: `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-run/FORGE-ROOT.md`, `skills/fg-run/RUN-ALL.md`, `skills/fg-learn/RETRO-FORMAT.md`. 다른 스킬은 복사하지 않고 `${CLAUDE_PLUGIN_ROOT}/skills/<owner>/<file>`로 참조한다.

## 매니페스트 필드

`plugin.json`: `name`·`description`(전체 스킬 목록을 담는 긴 설명)·`version`·`author`·`homepage`·`repository`·`license`·`keywords`.

`marketplace.json`: `name`·`owner`·`metadata`(`description`+`version`)·`plugins[]`(`name`·`source: "./"`·`description`·`version`·`category`·`tags`).

두 description은 역할이 다르다. `marketplace.json`의 `metadata.description`은 루프(ask→execute→retro→done)를 정의하는 한 줄 태그라인이라 루프 밖 유틸리티를 넣지 않는다. `plugins[].description`과 `plugin.json`의 `description`은 전체 스킬 목록을 담으므로 루프 밖 스킬도 반영한다.

## 검증 방법 (매니페스트 JSON 파싱 한 줄)

빌드/린트가 없으므로 편집 후 유일한 정적 검증은 두 매니페스트가 유효한 JSON인지 확인하는 것이다. 깨지면 설치가 실패한다.

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

동작 검증은 설치해서 트리거해보는 것뿐(단위 테스트 없음). 설치는 GitHub 기본 브랜치(`main`)를 당기므로, 설치 테스트를 하려면 `main`에 push돼 있어야 한다.

## 버전 동기화 (3곳)

버전은 **세 곳을 반드시 함께 갱신**한다. 어긋나면 fg-doctor가 drift로 잡는다.

1. `.claude-plugin/plugin.json`의 `version`
2. `.claude-plugin/marketplace.json`의 `metadata.version`
3. `.claude-plugin/marketplace.json`의 `plugins[0].version`

현재 세 곳 모두 `0.4.28`. 배포 절차는 CHANGELOG 갱신 → README(이중언어)·docs 갱신 → 버전 3곳 범프(기본 patch) → JSON 검증 → `chore(release): vX.Y.Z` 커밋 → `main` push 순이다.

## `.gitignore` 화이트리스트 모델 (`.forge/`)

휘발 상태와 영속 문서가 같은 `.forge/` 지붕 아래 섞여 있어, `.gitignore`가 `.forge/`를 기본 제외(`.forge/*`)한 뒤 영속 문서만 화이트리스트로 되살려 추적한다. 구분 기준은 위치가 아니라 git 추적 여부다.

```
.forge/*                 (기본 제외 — 휘발 상태 plan/run/STATUS/backlog/executed/done)
!.forge/CONTEXT.md       (추적 — 도메인 글로서리)
!.forge/adr/             (추적 — 아키텍처 결정)
!.forge/retro/           (추적 — 회고 로그)
!.forge/codebase/        (추적 — fg-map 코드베이스 지도)
!.forge/config.json      (추적 — defaultBranch·tdd·eco 등 프로젝트 설정)
!.forge/branch/          (추적 — 비-기본 브랜치의 forge 루트 통째)
```

비-기본 브랜치의 forge 루트(`.forge/branch/<branch>/`)는 통째로 추적된다(ADR-0011). 경로가 브랜치별로 네임스페이스돼 머지 충돌이 없고, `git merge` 뒤 fg-merge가 `.forge/`로 통합한다. 기본 브랜치의 휘발 상태는 종전대로 gitignored인 의도된 비대칭이다. 그 밖에 `.claude/worktrees`, `.planning/`(단 `!.planning/codebase/`), `.omx`, `.DS_Store`도 제외된다.

## 브랜치별 forge 루트 해석 규칙

모든 `.forge/...` 경로는 해석된 forge 루트 기준이다. 단일 정의는 `skills/fg-run/FORGE-ROOT.md`이며(복붙 금지), 모든 루프 스킬이 이를 참조한다. 현재 브랜치가 기본 브랜치(`config.json`의 `defaultBranch`, 없으면 `main`)면 `.forge/`, 그 외면 `.forge/branch/<branch>/`. 전역 예외 두 개(`.forge/config.json`·`.forge/codebase/`)는 모든 브랜치에서 항상 최상위 `.forge/`다.
