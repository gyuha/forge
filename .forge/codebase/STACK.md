---
last_mapped_commit: 553484ae395d6ca3df973f5b0cf5762029fd94ec
mapped: 2026-07-20
---

# STACK — 언어·런타임·설정

이 리포는 **빌드하는 애플리케이션이 아니라 Claude Code 플러그인**이다. 산출물은 Markdown(`SKILL.md`·`*-FORMAT.md`)과 JSON(매니페스트)이며, 여기에 결정론적 셸/노드 스크립트(`scripts/`)와 vendored zero-dep Node 서버(`skills/fg-visual/scripts/`)가 더해진다. package.json·Makefile·CI·lockfile·번들러가 **없다**. "개발"은 Markdown/JSON 편집이고, 테스트/린트 시스템은 없다.

## 언어·파일 종류

- **Markdown** — 스킬 지시문(`skills/<name>/SKILL.md`)과 형식 문서(`*-FORMAT.md`). 스킬 본문은 영문, 산출 문서는 사용자 언어.
- **JSON** — 플러그인/마켓플레이스 매니페스트(`.claude-plugin/*.json`), `.forge/config.json`.
- **Bash** — 운영 스크립트 1차 구현(`scripts/*.sh`), vendored 런처(`skills/fg-visual/scripts/*.sh`).
- **JavaScript (Node, CommonJS)** — 운영 스크립트 폴백(`scripts/*.js`), vendored 서버(`skills/fg-visual/scripts/server.cjs`·`helper.js`).
- **HTML** — vendored 브라우저 프레임(`skills/fg-visual/scripts/frame-template.html`), 랜딩 페이지(`docs/index.html`).

## 런타임

- **Bash + Node 이중 디스패치 (ADR-0022)** — `.forge/adr/0022-forge-scripts-convention-cross-platform-dual-dispatch.md`. 각 운영 스크립트는 `.sh`(bash, 1차)와 `.js`(node, 폴백) **트윈**으로 제공된다. `.ps1`은 배제(대상 사용 환경 중 하나가 보안 정책상 PowerShell 차단). node는 Claude Code가 항상 보장하는 폴백.
  - **스킬 호출 경로**: `bash scripts/<name>.sh` (Bash 도구가 bash 보장).
  - **statusline 경로**: Bash 도구 밖 시스템 셸 실행. `fg-statusline` 설치 시 bash 가용 여부를 1회 판정해 단일 진입을 확정 — bash 있으면 `.sh`, 없으면 `node ...js`. node 폴백이 실효를 갖는 유일 지점이 statusline(Windows/PowerShell-차단 호스트).
  - **포터블 규칙**: shebang `#!/usr/bin/env bash`(`/bin/bash` 금지), `bash script.sh` 호출(`./script.sh` 금지 — NTFS엔 POSIX exec 비트 없음), `.gitattributes`가 `*.sh`를 LF 강제(`*.sh text eol=lf` — CRLF가 bash 셔뱅/인자를 깨뜨림).
  - **drift 관리**: (1) fg-doctor가 `scripts/*.sh`마다 `.js` 트윈 존재를 정적 검사, (2) 같은 fixture에 두 구현을 돌려 출력 동일성을 단언하는 **패리티 테스트**(`*.parity.test.sh`)가 진짜 동치 가드.
  - **판단은 스크립트로 옮기지 않는다** — grilling·retro 분류·divergence 평가·검증 결정은 산문(LLM), 결정론적 survey/상태 전이만 스크립트화.

### `scripts/` 목록 (트윈 + 테스트)

- `resolve-forge-root.sh` / `.js` — forge 루트 해석(ADR-0011). git top-level에 anchor해 서브디렉터리에서도 동작. `.js`는 `resolveForgeRoot()`를 export해 다른 node 트윈이 재사용(DRY). `.parity.test.sh` 동반.
- `forge-status.sh` / `.js` — fg-status survey/테이블(ADR-0020). `.parity.test.sh` 동반.
- `forge-done.sh` / `.js` — 봉인 기계부(ADR-0030). 세 봉인 경로 공유·게이트-우선-비파괴. `.test.sh` + `.parity.test.sh`.
- `forge-merge.sh` / `.js` — 브랜치 forge 통합(ADR-0011, 260716-16a). git 조작 없음(CI git-free). `.test.sh` + `.parity.test.sh`.
- `forge-doctor.sh` / `.js` — 무결성 health check(ADR-0019). exit 0/1/2로 AI-free CI 게이트 가능. `.test.sh` + `.parity.test.sh`.
- `forge-statusline.sh` / `.js` — forge-전용 statusline fragment(방법 1, ADR-0017). `.test.sh` + `.parity.test.sh`.
- `forge-statusline-full.sh` / `.js` — daleseo식 통합 statusline(방법 2, ADR-0029). `.test.sh` + `.parity.test.sh`.
- `forge-statusline-wrapper.sh` — 원본 statusline 보존 wrapper(bash 전용, 트윈 없음). `.test.sh` 동반.

## 플러그인 패키징 (단일 리포 = 플러그인 + 마켓플레이스)

리포 루트가 곧 플러그인 루트이자 마켓플레이스(harness 플러그인과 동일 패턴).

- `.claude-plugin/plugin.json` — 플러그인 매니페스트. `name`(=`forge`)·`description`(전체 스킬 목록을 담는 긴 산문)·`version`·`author`·`license`(MIT)·`keywords`. `skills/`가 자동 탐색되므로 `skills` 필드는 생략.
- `.claude-plugin/marketplace.json` — 이 리포를 마켓플레이스로 등록. `owner`·`metadata.description`(루프 태그라인)·`metadata.version`·`plugins[0].source`(`"./"` — 루트가 곧 플러그인)·`plugins[0].description`(전체 스킬 목록)·`plugins[0].version`·`category`·`tags`.
- **매니페스트 두 description의 역할 차이**: `marketplace.json`의 `metadata.description`은 루프(ask→execute→retro→done) 태그라인이라 루프 밖 유틸리티를 넣지 않는다. `plugins[].description`(및 `plugin.json`의 `description`)은 전체 스킬 목록이라 루프 밖 스킬도 반영.

## 스킬 자동 탐색

- 스킬은 `skills/<name>/SKILL.md`로 **자동 탐색**된다. **스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name`** 이다(`awk '/^name:/'`로 누락 확인).
- 현재 19개 스킬: `fg-ask`·`fg-run`·`fg-learn`·`fg-done`(4단계 루프) + `fg-map`·`fg-quick`·`fg-status`·`fg-next`·`fg-loop`·`fg-merge`·`fg-cleanup`·`fg-tdd`·`fg-eco`·`fg-adversarial-review`·`fg-statusline`·`fg-doctor`·`fg-drop`·`fg-agents`·`fg-visual`(루프 밖).
- 형식/규율 문서는 소유 스킬 디렉터리에 단일 정의로 둔다: `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-run/FORGE-ROOT.md`, `skills/fg-learn/RETRO-FORMAT.md`, `skills/fg-next/DRIVE.md`, `skills/fg-eco/ECO.md`, `skills/fg-visual/VISUAL.md`. 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<owner>/<file>`(상대경로 `../fg-ask/` 등)로 참조하고 복사하지 않는다. 루트 `references/` 디렉터리는 폐지됨.

## 버전 관리 — 3곳 동기 (배포 규칙)

버전은 **반드시 3곳을 동기 갱신**한다:

1. `.claude-plugin/plugin.json`의 `version`
2. `.claude-plugin/marketplace.json`의 `metadata.version`
3. `.claude-plugin/marketplace.json`의 `plugins[0].version`

현재 셋 다 `0.5.18`. fg-doctor가 이 3곳 드리프트를 검사한다. 배포 절차: `CHANGELOG.md 작성 → README(이중언어)·docs 갱신 → 버전 3곳 범프 → JSON 검증 → commit → push`(기본 patch). CHANGELOG는 Keep a Changelog 약식(`CHANGELOG.md`, 81KB).

## 매니페스트 JSON 검증 (유일한 CI-급 체크)

편집 후 반드시 확인(깨지면 설치 실패):

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

## `.gitignore` 화이트리스트 패턴 (`.forge/` 상태 계약)

`.forge/`는 기본 제외(`.forge/*`)하되 **영속 문서만 화이트리스트로 되살려 추적**한다. 파일 `.gitignore`:

```
.forge/*
!.forge/CONTEXT.md
!.forge/adr/
!.forge/retro/
!.forge/codebase/
!.forge/config.json
!.forge/branch/
.claude/worktrees

.planning/
!.planning/codebase/

.omx
.DS_Store
```

- **휘발 상태(git 미추적)**: `plan.md`·`run.md`·`STATUS.md`·`review.md`·`backlog/`·`executed/`·`done/`·`loop.md`·`ask.md`·`quick/`·`dropped/`·`visual/`.
- **영속 문서(git 추적)**: `CONTEXT.md`·`adr/`·`retro/`·`codebase/`·`config.json`.
- **비-기본 브랜치 예외(ADR-0011)**: `!.forge/branch/`로 브랜치 forge 루트(`.forge/branch/<branch>/`)를 **통째로 추적**한다 — 경로가 브랜치별 네임스페이스라 머지 충돌이 없고, `git merge` 뒤 `fg-merge`가 `.forge/`로 통합한다. 기본 브랜치 휘발 상태는 종전대로 gitignored(의도된 비대칭).
- **`.forge/visual/`는 전역 예외** — `!.forge/branch/`가 브랜치 루트를 화이트리스트해도, 세션 파일은 최상위 `.forge/visual/`에 두어(브랜치 루트 아님) `.forge/*` 기본 제외가 그대로 커버(mockup HTML이 커밋에 안 섞임).

## forge 루트 해석 (ADR-0011)

모든 `.forge/...` 경로는 **해석된 forge 루트** 기준이다. 단일 정의는 `skills/fg-run/FORGE-ROOT.md`, 스크립트 구현은 `scripts/resolve-forge-root.{sh,js}`.

- 기본 브랜치(`config.json`의 `defaultBranch`, 없으면 `main`) → `.forge/`.
- 그 외 브랜치 → `.forge/branch/<branch>/`.
- **전역 예외 2개**(`config.json`·`codebase/`)와 `visual/`은 모든 브랜치에서 항상 최상위 `.forge/`.
- detached HEAD / 非-git → 기본 `.forge/`로 폴백(stderr 경고 1줄).

현 워킹트리는 브랜치 `feature/visual-compose`(`.git`은 `gitdir: .../forge/.git/worktrees/forge-visual-compose` — git worktree), 그래서 이 브랜치의 forge 상태는 `.forge/branch/feature/visual-compose/`에 있다.

## `.forge/config.json` 스키마

영속(git 추적, lazy 생성). 현재 파일 내용은 `{"eco": false}`뿐이지만 스크립트/스킬이 참조하는 키는 3개:

- `eco` (boolean) — eco 모드 토글(ADR-0014). `fg-eco`가 set, `fg-run`이 서브에이전트 sonnet 캡 + ECO.md 규율 주입에 read. (코드 12곳 참조)
- `tdd` (boolean) — 영속 TDD 모드(ADR-0008). `fg-tdd`가 set, `fg-ask`가 작업별 기본 답으로 read.
- `defaultBranch` (string) — 기본 브랜치명(ADR-0011). 없으면 `main`. `resolve-forge-root.{sh,js}` 등이 read. (코드 7곳 참조)

## Vendored zero-dep Node 서버 (`skills/fg-visual/scripts/`)

obra/superpowers v6.1.1의 Visual Companion을 MIT 귀속과 함께 vendoring(ADR `260719-224442`, `LICENSE` 사본 + 파일 헤더). **ADR-0022 트윈 관례의 명시적 예외** — 업스트림 원형 유지(bash 런처 + node 서버, 트윈 안 만듦). 5개 파일:

- `server.cjs` (24KB) — **zero-dependency** Node HTTP + WebSocket 서버. `require`는 Node 내장만(`crypto`·`http`·`fs`·`path`). WebSocket을 RFC 6455 프레임 인코딩/디코딩까지 직접 구현(라이브러리 없음). 프레임 payload 상한 10MB.
- `start-server.sh` (7KB, bash 런처) — 랜덤 high port(49152–65534)에 바인드, 세션 디렉터리 생성, 서버 기동 후 URL JSON 출력. 인자: `--project-dir`·`--host`(기본 `127.0.0.1`)·`--url-host`·`--idle-timeout-minutes`·`--open`·`--foreground`/`--background`. `umask 077`(세션 파일 owner-only). Windows/Git-Bash·Codex CI 환경은 nohup background를 reap하므로 자동 foreground.
- `stop-server.sh` (3KB, bash) — `stop-server.sh <session_dir>`. per-start instance id(`--brainstorm-server-id`)로 PID 소유권 검증 후 SIGTERM→SIGKILL, `/tmp/*` 세션만 삭제(`.forge/visual/`는 mockup 보존).
- `helper.js` (6KB) — 브라우저측 클라이언트. WebSocket 재연결(지수 backoff 500ms→30s), 15s 후 tombstone 오버레이, `[data-choice]` 클릭 캡처. `module.exports`로 `nextReconnectDelay` 등 순수함수 export(단위테스트용).
- `frame-template.html` (8KB) — 브라우저 프레임 템플릿.

**환경변수 인터페이스**(런처→서버): `BRAINSTORM_DIR`(세션 디렉터리)·`BRAINSTORM_HOST`·`BRAINSTORM_URL_HOST`·`BRAINSTORM_OWNER_PID`·`BRAINSTORM_PORT_FILE`·`BRAINSTORM_TOKEN_FILE`·`BRAINSTORM_IDLE_TIMEOUT_MS`·`BRAINSTORM_OPEN`. 세션 파일 레이아웃: `.forge/visual/<pid-epoch>/{content,state}/`, 재시작 재사용용 `.forge/visual/.last-port`·`.last-token`.

세션·인증·수명은 INTEGRATIONS.md(외부 접점)에 상술.
