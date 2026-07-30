---
last_mapped_commit: c1100b17577529833c68ca5a8c59ee1e310f24d4
mapped: 2026-07-28
---

# INTEGRATIONS.md

## 결론부터 — 외부 통합은 없다

forge는 **외부 API를 호출하지 않고, 데이터베이스가 없고, 인증 공급자를 쓰지 않고, 웹훅을 보내거나 받지 않는다.** 이건 미구현이 아니라 리포의 실제 형태다 — forge는 Markdown 스킬과 bash/node 스크립트로 이루어진 Claude Code 플러그인이고, 유일한 영속 저장소는 로컬 파일시스템의 `.forge/` 디렉터리다.

실측 근거:

- `skills/`·`scripts/`에서 `WebFetch`·`WebSearch`·MCP 도구 호출·HTTP 클라이언트 참조 grep 결과 **0건**(`skills/fg-agents/SKILL.md`의 언급 1건은 "카드에 MCP 도구 이름을 절대 박지 말라"는 **금지** 규칙이다).
- 스킬·스크립트 어디에도 `gh`/`curl`/`fetch` 호출이 없다. 유일한 `gh` 요구자는 리포 로컬 `.claude/skills/issue-triage/SKILL.md`이며 **플러그인으로 배포되지 않는다**.
- 네트워크 리스너는 딱 하나 — `fg-visual`의 로컬 서버가 `127.0.0.1`에 바인드한다(아래 §3). 그 서버조차 외부로 나가는 요청을 하지 않는다.
- 데이터 저장은 `.forge/` 아래 Markdown/JSON 파일 + `.forge/visual/<session>/`의 JSONL 이벤트뿐. 스키마 마이그레이션·ORM·커넥션 문자열이 존재하지 않는다.

그러니 이 문서가 다루는 것은 "forge가 실제로 무엇과 대화하는가"다 — **Claude Code 하네스 표면**, **로컬 프로세스(git·브라우저)**, 그리고 **배포·문서 채널로서의 GitHub**.

## 1. Claude Code 하네스 — 진짜 통합 지점

forge가 붙는 통합점은 전부 하네스 쪽이다. 계약이 깨지면 플러그인이 조용히 로드되지 않거나 훅이 발화하지 않는다.

### 1.1 플러그인·마켓플레이스 매니페스트

| 표면 | 파일 | 하네스가 무엇을 하는가 |
| --- | --- | --- |
| 플러그인 매니페스트 | `.claude-plugin/plugin.json` | `/plugin install forge@forge` 시 읽음. `skills` 필드가 없어 `skills/`를 자동 탐색 |
| 마켓플레이스 매니페스트 | `.claude-plugin/marketplace.json` | `/plugin marketplace add`가 읽음. `plugins[0].source: "./"` = 리포 루트가 곧 플러그인 |

JSON이 깨지면 **설치가 실패**한다. 버전은 3곳(`plugin.json.version`·`metadata.version`·`plugins[0].version`)에 중복 기재되며 현재 전부 `0.5.20`.

### 1.2 스킬 자동 탐색

`skills/<dir>/SKILL.md`의 frontmatter를 하네스가 읽는다. 현재 19개 디렉터리 전부 `name:`·`description:` 두 키만 갖는다. **식별자는 디렉터리명이 아니라 `name`** 이고, `name:`이 없으면 자동 탐색 대상에서 빠진다(`forge-doctor` B10이 error로 잡음). `description`은 `/fg` 슬래시 메뉴 표시와 자동 발동 트리거의 **이중 용도**이며 같은 문자 상한을 공유한다.

스킬은 `/forge:fg-<name>` 형태의 슬래시 경로로도 호출된다 — 훅이 주입하는 텍스트가 사용자에게 안내하는 트리거가 `/forge:fg-next`다.

### 1.3 SessionStart 훅 (`hooks/hooks.json`)

forge가 하네스 **이벤트**에 붙는 유일한 지점이자, 모든 사용자 세션에 개입하는 유일한 자산이다.

| 항목 | 값 |
| --- | --- |
| 이벤트 | `SessionStart` |
| matcher | `startup\|resume\|clear\|compact` |
| command | `"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd" session-start` |
| shell | `bash` |
| async | `false` (컨텍스트 주입은 동기여야 함) |
| 등록 방법 | `hooks/` 자동 탐색 — 사용자 `settings.json` 편집 없음 |

주고받는 것:

- **하네스 → forge**: `${CLAUDE_PLUGIN_ROOT}`(command 문자열 안에서 확장), `CLAUDE_PROJECT_DIR`(래퍼가 여기로 `cd` — 훅 본체는 cwd 기준으로 상태를 읽으므로 상속 cwd를 신뢰하지 않는다).
- **forge → 하네스**: **stdout 텍스트**가 세션 컨텍스트로 주입된다. 형식은 `<forge-state>` … `</forge-state>` 블록이고, 부채 항목 최대 3건 + `(+N more parked …)` + 선택적 goal-loop 줄 + 선택적 백로그 개수 + 고정 지시 문단("한 줄로 사용자에게 알리고 마감 여부를 물어라. 자동 실행·자동 봉인 금지"). 부채가 없으면 **stdout을 완전히 비우고** exit 0.
- **실패 모드는 무해**: 본체는 항상 exit 0이고, bash·node 둘 다 없거나 훅 이름을 모르면 래퍼가 조용히 exit 0 한다. 훅이 안 뜨는 것 = 훅 도입 이전 현상 유지.
- **`hooks/run-hook.cmd`는 exec 비트(`100755`)가 필수** — 하네스가 명령 문자열을 `/bin/sh`에 넘겨 파일을 직접 실행하므로, 비트가 없으면 Permission denied로 훅이 조용히 죽는다.

훅은 세션 시작 시 로드되므로 **추가·수정은 다음 세션부터** 적용된다.

### 1.4 statusLine (사용자 `settings.json`)

forge가 **사용자 설정 파일을 쓰는** 유일한 지점이다(`fg-statusline`이 확인 게이트를 거쳐 대화형으로 수정).

- 배선되는 값: `{"statusLine": {"type": "command", "command": "<절대경로>"}}`. `~` 금지.
- 하네스는 그 명령을 **시스템 셸**에서 실행하고 **세션 JSON을 stdin으로** 준다. Bash 도구 밖 환경이라 Windows에서는 `node <CFG>/forge-statusline-full.js`로 배선한다.
- **소비하는 세션 JSON 필드**(전부 없으면 우아하게 생략): `model.display_name`, `effort.level`, `cwd` → `workspace.current_dir` → `current_dir`(순차 폴백), `context_window.{used_percentage,context_window_size}`, `rate_limits.five_hour.{used_percentage,resets_at}`, `rate_limits.seven_day.{used_percentage,resets_at}`, `cost.{total_cost_usd,total_duration_ms,total_lines_added,total_lines_removed}`.
- `statusLine`은 하나만 허용되므로 "추가"가 불가능하다 → 기존 서드파티 statusline이 있으면 방법 1(원본을 `<CFG>/forge-statusline-orig.sh`에 verbatim 보존한 뒤 wrapper가 합성)이나 방법 2(교체 + 복원 경로 안내)로 갈린다.

### 1.5 도구·서브에이전트 표면

스킬 본문이 이름으로 참조하는 하네스 기능(등장 횟수는 `skills/` grep 실측):

| 표면 | 횟수 | 쓰는 곳 |
| --- | --- | --- |
| Dynamic Workflow | 14 | fg-run(계획 실행), fg-adversarial-review(6개 렌즈 병렬 팬아웃), fg-map(병렬 매퍼) |
| `AskUserQuestion` | 11 | 백로그 선택 메뉴, fg-drop 체크박스, fg-eco/fg-statusline 선택 |
| `agentType` | 9 | fg-run이 slice↔role 매핑으로 `.claude/agents/` 카드를 디스패치 |
| Bash 도구 | 4 | 스킬이 `bash "${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh"`를 호출하는 경로(= bash 보장의 근거) |
| Skill 도구 | 1 | fg-next가 도출한 다음 스킬을 위임 호출 |

**서브에이전트 카드 계약(`.claude/agents/<role>.md`)** — `fg-agents`가 생성하고 `fg-run`이 소비한다. 카드 `description`의 "언제 쓰이나"가 자동 매핑의 입력이고, 읽기 전용 역할만 `tools: Read, Grep, Glob, Bash`를 고정한다. **MCP 도구 이름은 절대 카드에 박지 않는다** — 환경 의존적이고, 해석 실패 시 카드 전체가 launch-fail 한다. 카드는 세션 시작 시 1회 로드되므로 생성 → **세션 재시작** → 활용 순서가 강제된다.

## 2. 로컬 프로세스·파일시스템

### 2.1 git CLI

forge는 git 라이브러리를 쓰지 않고 `git` 실행 파일을 셸아웃한다. **코어 스크립트는 저장소를 변형하지 않는다**(조회 전용):

| 호출 | 어디서 | 목적 |
| --- | --- | --- |
| `git rev-parse --show-toplevel` | `resolve-forge-root.{sh,js}`, `forge-doctor`, `forge-status`, 훅 본체 | 리포 루트 앵커 |
| `git rev-parse --abbrev-ref HEAD` | 같음 | 현재 브랜치 → forge 루트 해석 |
| `git diff --cached --name-only` / `git diff --name-only` / `git ls-files --others --exclude-standard` / `git rev-list --left-right --count @{upstream}...HEAD` | `forge-statusline-full.{sh,js}` | statusline의 `⎇` 브랜치·상태 표시 |
| `git merge <branch>` | **`fg-merge <branch>` 대화형 인자 모드에서만** | 편의 기능. 코어 `forge-merge.{sh,js}`는 git을 전혀 돌리지 않으며(git-free), 그 성질이 AI 없는 CI 사용을 가능하게 한다 |

git이 없거나 비-git 디렉터리면 루트가 CWD 상대 `.forge`로 폴백하고 경고 한 줄을 stderr에 낸다(exit 0). commit/push/branch는 forge의 소관이 아니다 — 예외는 `CLAUDE.md`에 정의된 두 절차(배포·이슈 연동 봉인)이며 그건 리포 운영 규칙이지 스킬 코드가 아니다.

### 2.2 파일시스템 (유일한 "데이터 저장소")

`.forge/` 아래 Markdown·JSON 파일뿐이고 네트워크 전송이 없다. 비-기본 브랜치에서는 `.forge/branch/<branch>/`로 네임스페이스된다. `.forge/config.json`·`.forge/codebase/`·`.forge/visual/`는 브랜치 무관 전역 예외로 항상 최상위다.

## 3. `fg-visual` 로컬 서버 — 유일한 네트워크 리스너

`skills/fg-visual/scripts/server.cjs`(zero-dependency Node)가 브라우저에 목업·다이어그램을 띄우고 클릭을 JSONL로 수집한다. **로컬 전용이며 외부와 통신하지 않는다.**

| 항목 | 실측 값 |
| --- | --- |
| 바인드 | `BRAINSTORM_HOST`, 기본 `127.0.0.1`(원격/컨테이너에서 `--host 0.0.0.0` 옵트인 가능) |
| 포트 | 랜덤 고포트. 프로젝트별 `.forge/visual/.last-port`에 기록해 재시작 시 재사용(열린 탭 재연결) |
| 프로토콜 | 자체 구현 HTTP + WebSocket(RFC 6455 직접 인코딩/디코딩, 프레임 페이로드 상한 10MB) |
| 인증 | 세션 키를 URL 쿼리(`/?key=<TOKEN>`)로 전달 후 쿠키(`brainstorm-key-<PORT>`)로 유지. `.last-token`은 `umask 077` + `chmod 600` |
| 크로스오리진 방어 | WebSocket `Origin`이 `http://<host>`와 정확히 일치해야 함 |
| 수명 | 유휴 4시간(`--idle-timeout-minutes`, 기본 240) 자동 종료 + 하네스 PID 워치독(Windows/MSYS는 PID 검증 불가로 워치독 비활성, 유휴 타임아웃만) |
| 브라우저 실행 | `child_process.execFile`로 플랫폼 런처에 URL을 argv로 전달(셸 미개입). `127.0.0.1`/`localhost` 바인드가 아니면 실행 자체를 건너뜀 |
| 원격 자원 | **없음**. `frame-template.html`에 외부 URL 0건, `server.cjs`의 `https?://` 등장 3곳은 (a) 브랜딩 링크 `https://github.com/gyuha/forge`, (b) 자기 URL 조립, (c) Origin 비교 문자열뿐. `fetch`·`net`·`dns` 사용 없음 |
| 텔레메트리 | 없음(superpowers 벤더링 시 브랜딩·텔레메트리 제거) |

세션 파일은 `.forge/visual/<pid>-<epoch>/{content,state}/`에 남고 휘발(gitignore)이다.

## 4. GitHub — 배포·문서 채널 (런타임 통합 아님)

플러그인 코드가 GitHub API를 부르는 일은 없다. 관계는 셋뿐이다.

| 채널 | 실체 | 확인 |
| --- | --- | --- |
| 배포 | `/plugin marketplace add gyuha/forge` → `/plugin install forge@forge`. 설치는 **기본 브랜치 `main`을 당긴다** → 변경을 설치로 검증하려면 먼저 push해야 함 | `git remote -v` = `https://github.com/gyuha/forge.git` |
| 랜딩 페이지 | `docs/index.html` + `docs/.nojekyll` → GitHub Pages(`docs/` 서브 디렉터리 서빙). 한 파일에 KO/EN을 `data-l` span으로 담고 토글 | `docs/.nojekyll`이 추적됨 |
| CI 템플릿 | `docs/examples/github-actions-forge-check.yml` — `actions/checkout@v4`로 체크아웃해 `forge-doctor.sh`(exit 0/1/2)와 테스트 스위트를 게이트로 돌리는 **복사용 예제**. 이 리포에는 `.github/`가 없어 실행되지 않음 | `git ls-files`에 `.github/` 없음 |

`gh` CLI는 **리포 운영에만** 등장한다: `CLAUDE.md`의 이슈 연동 봉인 규칙(`gh issue comment`·`gh issue view --json state`·`gh issue close`)과 리포 로컬 `.claude/skills/issue-triage`(`gh auth status`·`gh issue list/view`, 읽기 전용). 둘 다 플러그인 페이로드가 아니므로 forge 사용자는 `gh` 없이도 모든 스킬을 쓴다.

**리포 산출물 중 외부 네트워크에 의존하는 것은 딱 하나** — `docs/index.html`이 Google Fonts를 로드한다(`fonts.googleapis.com` preconnect + `css2?family=Inter…&family=JetBrains+Mono…` 스타일시트, `fonts.gstatic.com` preconnect). 랜딩 페이지 한정이며 플러그인 동작과 무관하다.

## 5. 코드 유입 경로 — 벤더링 (MIT 귀속)

외부 코드가 들어오는 통로는 패키지 매니저가 아니라 vendoring이다. 잠금 파일도 갱신 자동화도 없으므로, 업스트림 변경은 사람이 수동으로 반영한다.

| 출처 | 무엇 | 어디 |
| --- | --- | --- |
| obra/superpowers v6.1.1 (MIT, © Jesse Vincent) | Visual Companion 5파일 — `server.cjs`·`helper.js`·`frame-template.html`·`start-server.sh`·`stop-server.sh` | `skills/fg-visual/scripts/` (+ `skills/fg-visual/LICENSE`) |
| obra/superpowers (MIT) | `hooks/run-hook.cmd` polyglot 래퍼 패턴 — forge가 node 폴백을 추가 | `hooks/run-hook.cmd` 헤더에 귀속 명기 |

벤더링된 `skills/fg-visual/scripts/`는 업스트림 형태를 유지하며 `scripts/`의 sh+js 트윈 규약·패리티 테스트 대상이 **아니다**.

## 6. 명시적으로 없는 것

혹시 찾고 있다면: REST/GraphQL 클라이언트, 데이터베이스(SQL·NoSQL·SQLite 포함), ORM/마이그레이션, 캐시·큐·메시지 브로커, OAuth/OIDC/API 키 저장소, 시크릿 관리, 웹훅 송수신 엔드포인트, 결제·이메일·분석·에러 리포팅 SDK, MCP 서버 정의, 컨테이너·배포 인프라 — **하나도 없다.** forge는 로컬 파일과 로컬 프로세스만 만지며, 유일한 원격 관계는 "GitHub에서 설치된다"는 것이다.
