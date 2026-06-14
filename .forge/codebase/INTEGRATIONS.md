---
last_mapped_commit: b3b267b7da443c3fbb0ca093c4fc4221a70ef7ab
mapped: 2026-06-14
---

# INTEGRATIONS

forge의 외부 접점은 세 가지뿐이다: 호스트인 **Claude Code**, 배포·설치 경로인 **GitHub 기반 플러그인 마켓플레이스**, 그리고 상태 경로 해석과 스크립트가 쓰는 **git**이다. 데이터베이스·인증 공급자·웹훅·외부 API·메시지 큐 같은 통합은 **존재하지 않는다**(매핑 시점 기준 확인). forge는 자기 리포의 파일시스템(`.forge/`)과 호스트만 읽고 쓴다.

## Claude Code (host integration)

forge는 Claude Code 플러그인이며, 호스트와 세 가지 방식으로 맞물린다.

- **스킬 자동 탐색** — 호스트가 `skills/<name>/SKILL.md`를 자동 탐색해 로드한다. 스킬 식별자는 디렉터리명이 아니라 **frontmatter의 `name` 필드**다. 매니페스트의 `skills` 필드는 생략 가능(자동 탐색이 처리). 배포 후 확인 항목 중 하나가 `awk '/^name:/'`로 frontmatter `name` 누락 여부를 보는 것이다.
- **Dynamic Workflows** — `fg-run`이 정제된 plan을 Claude Code Dynamic Workflow로 실행한다. 워크플로우는 실행 중 사용자 입력을 못 받으므로 그릴링(fg-ask)은 절대 워크플로우 안에 넣지 않고 본 세션 대화로 진행한다(설계 기둥 1). `fg-loop`·`fg-next all`·`fg-adversarial-review`도 위임 서브에이전트/워크플로우 패턴을 쓴다.
- **statusLine 통합** — `settings.json`의 `statusLine` 키로만 설정되는 호스트 기능이다(ADR-0017). 플러그인은 statusLine을 등록할 수 없고, statusLine 명령은 세션 JSON을 stdin으로 받아 텍스트를 출력하는 비대화형 셸 명령이라 스킬을 호출할 수 없다. 그래서 `fg-statusline` 스킬이 `scripts/forge-statusline.sh`(fragment)와 `scripts/forge-statusline-wrapper.sh`(합성 래퍼)를 Claude config 디렉터리(`$CLAUDE_CONFIG_DIR` 또는 `~/.claude`)의 안정적 절대 경로로 복사하고 `settings.json`을 그리로 가리키게 한다. 호스트가 statusLine을 하나만 허용하므로 기존 statusline은 대체하지 않고 원본을 `<CFG>/forge-statusline-orig.sh`로 보존한 뒤 래퍼가 그 출력 아래 forge 행을 덧붙인다. `${CLAUDE_PLUGIN_ROOT}`는 statusLine 셸에서 사용 불가(설치 경로가 업데이트마다 바뀜)하고 `~` 틸드 확장도 보장되지 않으므로, 설정에는 반드시 절대 경로를 쓴다. statusLine은 신뢰된 워크스페이스에서만 돌고 `disableAllHooks` 시 억제된다 — 호스트 동작이지 forge 통제가 아니다.

`fg-statusline`이 읽는 세션 JSON의 필드는 `cwd`(없으면 `workspace.current_dir`, 그것도 없으면 `$PWD` fallback)다. fragment는 이 값으로 프로젝트 디렉터리를 해석해 `cd`한 뒤 `.forge/`를 읽으므로, 호스트가 다른 디렉터리에서 statusLine을 실행해도 올바른 프로젝트를 표시한다.

## GitHub-based marketplace / install flow

배포·설치 경로 전체가 GitHub에 묶여 있다.

- **마켓플레이스 등록** — `/plugin marketplace add gyuha/forge`(또는 로컬 경로). `.claude-plugin/marketplace.json`이 이 리포를 마켓플레이스로 선언하고 `plugins[].source = "./"`로 루트를 플러그인으로 가리킨다.
- **설치는 main 브랜치를 당긴다** — `/plugin install forge@forge`는 GitHub 기본 브랜치(main)를 가져온다. 따라서 설치 테스트를 하려면 변경이 main에 push되어 있어야 한다("배포"의 마지막 단계가 main push인 이유).
- **배포 검증 접점** — `/plugin install`·`/plugin marketplace update`는 대화형이라 에이전트가 실행 못 한다. 에이전트가 검증 가능한 것은 원격 상태뿐: `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`으로 원격 main의 버전 세 곳을 확인한다(GitHub raw 콘텐츠 엔드포인트가 유일한 네트워크 호출 접점).

리포 메타데이터상 homepage·repository는 `https://github.com/gyuha/forge`다.

## git

git은 두 곳에서 직접 쓰인다.

- **브랜치별 forge 루트 해석(ADR-0011)** — 단일 정의는 `skills/fg-run/FORGE-ROOT.md`이고 모든 루프 스킬이 이를 참조한다(복붙 금지). `git rev-parse --abbrev-ref HEAD`로 현재 브랜치를 얻어, 기본 브랜치(`config.json`의 `defaultBranch`, 없으면 `main`)면 루트가 `.forge/`, 그 외면 `.forge/branch/<branch>/`다. detached HEAD나 비-git 리포면 `.forge/`로 fallback. `forge-statusline.sh`도 이 규칙을 자체 구현(`git rev-parse` + `sed`로 `defaultBranch` 추출)해 표시 대상 루트를 정한다.
- **브랜치 통합** — `fg-merge`는 git을 직접 호출하지 **않는다**. 사용자가 먼저 `git merge`로 비-기본 브랜치의 네임스페이스 폴더를 기본 브랜치로 가져온 뒤, fg-merge가 `.forge/branch/<branch>/`를 `.forge/`로 통합한다(ADR 번호 재부여·retro 이동·CONTEXT 병합·done 합침·폴더 제거). git 조작은 사람 몫, forge는 파일 통합만.

배포 절차(commit & push)도 git/GitHub 접점이지만 이는 운영 흐름이지 코드 통합이 아니다.

## Explicitly absent integrations

다음은 매핑 시점 기준 **존재하지 않는다**(있는 척 지어내지 않기 위해 명시):

- 데이터베이스 없음 — 상태는 전부 `.forge/` 안의 평문 Markdown/JSON 파일.
- 인증 공급자·OAuth·시크릿 관리 없음.
- 웹훅·이벤트 콜백·메시지 큐 없음.
- 외부 서비스 API 클라이언트 없음(GitHub raw fetch는 배포 검증용 read-only이고, 코드가 아니라 사람/curl이 친다).
- 텔레메트리·분석·로깅 백엔드 없음.
