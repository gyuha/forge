---
last_mapped_commit: b3b267b7da443c3fbb0ca093c4fc4221a70ef7ab
mapped: 2026-06-14
---

# STACK

forge는 코드를 빌드하는 애플리케이션이 아니라 **Claude Code 플러그인**이다. 산출물(artifact)은 전부 Markdown과 JSON이며, 실행되는 "프로그램"은 Claude Code 호스트가 해석하는 스킬 지시문이다. 따라서 전통적 의미의 언어/런타임/프레임워크 스택은 거의 없고, 대신 **문서 형식 + 매니페스트 규약 + 단 하나의 bash 보조 스크립트군**이 스택을 구성한다.

## Primary artifacts (languages)

forge의 1차 산출물은 두 가지 텍스트 형식이다.

- **Markdown** — 스킬 본문(`skills/<name>/SKILL.md`)과 형식 정의 문서(`*-FORMAT.md`), 그리고 `.forge/` 영속 문서(ADR·retro·CONTEXT·codebase 지도)가 전부 Markdown이다. 스킬은 frontmatter(YAML) + 본문(영문 지시문) 구조다. 본문 흐름도는 Mermaid가 아니라 텍스트 흐름도(`A → B → C`)로 쓴다(스킬은 에이전트가 파싱해야 하므로).
- **JSON** — 플러그인/마켓플레이스 매니페스트와 런타임 설정 파일. 깨지면 설치가 실패하므로 가장 엄격하게 다뤄지는 형식이다.

`skills/` 디렉터리에는 15개 스킬이 있다: `fg-ask`, `fg-run`, `fg-learn`, `fg-done`(루프 4단계)와 `fg-map`, `fg-quick`, `fg-status`, `fg-next`, `fg-loop`, `fg-merge`, `fg-cleanup`, `fg-tdd`, `fg-eco`, `fg-statusline`, `fg-adversarial-review`(루프 밖 유틸리티).

## Bash scripts (the only executable code)

리포 역사상 첫 실행 코드는 statusline 통합(ADR-0017)으로 들어온 bash 스크립트군이다. `scripts/` 아래 네 파일이 전부다.

- `scripts/forge-statusline.sh` — `.forge/` 상태를 읽어 한 줄짜리 진행 표시 문자열을 출력하는 얇은 표시 전용 reader. `#!/usr/bin/env bash`, `set -u`. 의존성은 **bash + git뿐**이며, JSON은 `jq` 없이 방어적 `sed`로만 파싱한다(세션 JSON의 `cwd`, `config.json`의 `defaultBranch`, `loop.md`의 replan 라운드/cap, `plan.md`의 forge-slug, `STATUS.md`의 verified 값). fg-status의 다음-단계 우선순위 머신은 재현하지 않는다(표시만).
- `scripts/forge-statusline-wrapper.sh` — Claude Code가 statusLine을 하나만 허용하므로 기존 statusline을 대체하지 않고 합성(compose)하는 래퍼. `<CFG>/forge-statusline-orig.sh`에 보존된 원본 명령을 실행한 뒤 forge fragment를 그 아래 별도 행으로 덧붙인다(fragment가 비어 있지 않을 때만). 같은 stdin(세션 JSON)을 두 명령에 동일하게 먹인다.
- `scripts/forge-statusline.test.sh` — fragment용 fixture 기반 bash 테스트 하니스. 각 케이스가 임시 디렉터리에 일회용 `.forge/` 상태를 만들고 스크립트를 그 디렉터리에서 실행해 단일 출력 라인을 기대값과 비교한다. `bash scripts/forge-statusline.test.sh`로 실행, 전부 통과 시 exit 0.
- `scripts/forge-statusline-wrapper.test.sh` — 래퍼용 테스트 하니스. 가짜 CLAUDE config 디렉터리(orig.sh + 실제 fragment)를 만들고 세션 JSON을 파이프해 합성 출력을 검증한다.

이 스크립트들은 플러그인 컴포넌트가 아니다. statusLine은 `settings.json`의 `statusLine` 키로만 설정되고 비대화형 셸 명령으로 실행되므로 스킬을 호출할 수 없다. 그래서 `fg-statusline` 스킬이 두 스크립트를 Claude config 디렉터리(`$CLAUDE_CONFIG_DIR` 또는 `~/.claude`)의 안정적 절대 경로로 복사해 설치한다.

## Manifest files

단일 리포가 곧 플러그인이자 마켓플레이스다(`harness` 플러그인과 동일 패턴).

- `.claude-plugin/plugin.json` — 플러그인 매니페스트. `name`, `description`(전체 스킬 목록 포함), `version`, `author`, `license`(MIT), `keywords`. `skills/`가 자동 탐색되므로 `skills` 필드는 생략한다.
- `.claude-plugin/marketplace.json` — 이 리포를 마켓플레이스로 등록. `plugins[].source`는 `"./"`(루트가 곧 플러그인). 버전은 `metadata.version`과 `plugins[0].version` 두 곳에 들어간다.

두 매니페스트의 description은 역할이 다르다. `marketplace.json`의 `metadata.description`은 루프(ask→execute→retro→done)를 정의하는 한 줄 태그라인(루프 밖 유틸리티 제외), `plugins[].description`과 `plugin.json`의 `description`은 전체 스킬 목록을 담는다. 버전은 **세 곳**(`plugin.json`의 `version`, `marketplace.json`의 `metadata.version`·`plugins[0].version`)을 동기 갱신해야 한다. 현재 버전은 0.4.12.

## Configuration files

- `.forge/config.json` — 프로젝트 전역 설정 파일. 키는 `defaultBranch`(forge 루트 분기 해석의 기준 — 없으면 `main`), `tdd`(영속 TDD 모드 토글, `fg-tdd`가 기록·`fg-ask`/`fg-run`이 소비), `eco`(위임 모델 티어링 토글, `fg-eco`가 기록·`fg-run`이 소비). **lazy 생성**이라 현재 리포에는 아직 존재하지 않는다(매핑 시점 기준 부재 확인). 브랜치별 forge 루트(ADR-0011)에서도 이 파일은 항상 최상위 `.forge/`에 둔다(`codebase/`와 함께 전역 예외).
- `.gitignore` — `.forge/*`로 휘발 상태(plan/run/STATUS/backlog/executed/done)를 기본 제외하되 영속 문서만 화이트리스트로 추적(`!.forge/CONTEXT.md`·`!.forge/adr/`·`!.forge/retro/`·`!.forge/codebase/`·`!.forge/config.json`·`!.forge/branch/`). 비-기본 브랜치 루트(`.forge/branch/`)는 통째로 추적되는 의도된 비대칭.

## Validation approach (no build/test/lint system)

`package.json`·`Makefile`·CI(`.github/workflows`)가 **없다**(매핑 시점에 부재 확인). "개발"은 Markdown/JSON 편집이며 검증은 두 갈래다.

- **매니페스트 JSON 유효성** — node 한 줄로 확인(깨지면 설치 실패):
  ```bash
  node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
  ```
  여기서 node는 빌드 도구가 아니라 일회성 JSON 린터로만 쓰인다(런타임 의존성 아님).
- **bash 스크립트** — 위의 두 `*.test.sh` 하니스로 검증. 외부 테스트 프레임워크 없이 순수 bash assert 함수만 쓴다. node 의존 없음.
- **실제 동작 테스트** — 단위 테스트가 없으므로 설치해서 스킬을 트리거하는 수밖에 없다(`/plugin marketplace add`, `/plugin install`). 설치는 GitHub 기본 브랜치(main)를 당기므로 테스트하려면 main에 push되어 있어야 한다.

## Runtime / hosting

런타임은 **Claude Code 호스트 자체**다. 스킬은 호스트가 frontmatter `name`으로 자동 탐색·로드하는 지시문이고, statusLine 스크립트는 호스트가 세션 JSON을 stdin으로 먹여 실행하는 비대화형 셸 명령이다. 별도 서버·프로세스·데몬은 없다. bash와 git만이 스크립트의 시스템 의존성이다.
