---
last_mapped_commit: 0be20755431c3864dd25f295e8f1af45425445c2
mapped: 2026-09-07
---

# INTEGRATIONS — 외부 연동

## 한 줄 요약

데이터베이스·인증 프로바이더·원격 API 호출 코드가 **없다**. 연동 표면은 (1) **두 에이전트 호스트**(Claude Code + Codex — 훅 2종·statusline·트랜스크립트 파일 읽기, 차이는 `core/`+`hosts/` 어댑터 경계에만), (2) GitHub(`gh` CLI·raw 콘텐츠는 문서 규칙으로만, **Actions/Pages는 실제 CI — 이제 워크플로가 둘**: 문서 배포 + 릴리스 게이트), (3) 로컬호스트 시각 컴패니언 서버, (4) MIT 코드 vendoring **네 건**(+개념 차용 한 건), (5) npm 레지스트리 — **문서 사이트 devDependencies 한정**이다.

## 1. 호스트 플러그인 표면 (주 연동 — Claude Code + Codex)

두 호스트가 같은 `skills/`·`scripts/`·`.forge/`를 쓴다. 매니페스트는 `.claude-plugin/`(plugin+marketplace)과 `.codex-plugin/plugin.json` 둘이고, 호스트마다 다른 부분만 `core/`(중립 계약 3파일)와 `hosts/<claude|codex>/`(어댑터 3파일씩) 경계에 산다 — 어댑터가 소유하는 것은 질문·위임·프로젝트 에이전트 로드·주행 계속·상태 UI 다섯뿐이고, 능력 선언은 `hosts/<host>/capabilities.json`의 8개 키다(ADR `260903-080713`).

- **어댑터 선택**(`core/HOST.md`): 명시적 호스트 메타데이터 → `PLUGIN_ROOT`(=Codex) → `CLAUDE_PLUGIN_ROOT` 단독(=Claude Code) → 식별 불가면 **순차 폴백**. 두 환경변수 모두 **단독으로는 증거가 못 된다** — Codex가 호환용으로 `CLAUDE_PLUGIN_ROOT`를 함께 줄 수 있고, `PLUGIN_ROOT`는 다른 도구도 export할 수 있는 일반 이름이다. 그래서 신호가 약하면 추측하지 않고 폴백을 택한다.
- **호스트별 능력 선언**(`hosts/<host>/capabilities.json`, 8키 고정): Claude Code는 8개 전부 `true`. **Codex는 `spawn_parallel`·`plugin_root`·`session_start`만 `true`**이고 `structured_choice`·`spawn_role`·`prevent_stop`·`project_agents`·`status_display`는 `false` — 즉 Codex에서는 구조화 질문(→번호 목록 폴백)·역할 위임·**Stop 훅으로 턴을 잇는 무인 주행**·`.claude/agents/` 카드·statusline이 모두 안 걸린다. 미확인은 `false`가 기본이므로 이 `false`들은 "불가"가 아니라 "미관측"일 수 있다. **`docs/codex.md`의 지원 표와 이 JSON은 같은 주장의 두 형태라 항상 함께 갱신한다**(`core/HOST.md`가 명시).
- **마켓플레이스 겸 플러그인**: 리포 루트가 곧 플러그인. `.claude-plugin/marketplace.json`의 `plugins[0].source: "./"`. 설치는 GitHub `main` 브랜치를 당긴다(push까지가 배포). Codex 쪽도 이 저장소를 로컬 Marketplace에 추가해 설치하며, **플러그인 훅은 설치만으로 신뢰되지 않아 사용자가 내용을 검토·허용해야 한다**(`docs/codex.md`).
- **스킬 자동 탐색**: `skills/*/SKILL.md` (frontmatter `name`이 식별자). Codex 매니페스트는 `"skills": "./skills/"`로 같은 트리를 명시하고, 이 값은 릴리스 게이트가 고정 검사한다(§2c). 호출 문법만 다르다 — Claude `/forge:fg-ask` ↔ Codex `$fg-ask`(자연어 트리거는 동일).
- **훅**: `hooks/hooks.json`이 **두 개**를 등록한다. 둘 다 `shell: "bash"`·`async: false`이고 `"${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT}}/hooks/run-hook.cmd" <name>`을 부르며 — **이 우선순위가 이번 구간에 뒤집혔다: Claude 우선·Codex fallback**(종전 반대) — polyglot 래퍼가 `.sh`(bash 우선) → `.js`(node 폴백)로 디스패치하고 런타임이 없으면 exit 0 침묵한다. 뒤집은 근거는 두 메커니즘이 다르다는 것이다(`core/HOST.md`의 「두 메커니즘」 문단): **셸 형식 훅 명령**(`args` 없음)은 치환되지 않고 호스트가 변수를 훅 자식 프로세스 **env**에 넣으므로 셸이 확장하고, 따라서 뒤집어도 안전하며 일반적 이름인 `PLUGIN_ROOT`가 이미 옳게 해석되는 경로를 가로채는 것을 막는다. 반대로 **스킬 본문**은 텍스트 치환 메커니즘이라 `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}` 형태를 그대로 유지한다 — **한쪽을 다른 쪽에 맞춰 "고치지" 말 것**(같은 문단이 명령). 어댑터 *선택*에서 `PLUGIN_ROOT`를 Codex 신호로 보는 것은 여전히 별개 문제다.
  - `SessionStart` (matcher `startup|resume|clear|compact`) → `session-start` → `scripts/forge-hook-session-start.sh`/`.js`. 미봉인 잔여를 세션 진입 컨텍스트에 주입. `CLAUDE_PROJECT_DIR` 환경변수로 프로젝트 디렉터리에 앵커.
  - `Stop` (matcher 없음 = 전부) → `stop` → `scripts/forge-hook-stop.sh`/`.js`. 무인 주행을 턴 경계 너머로 잇는 forge 자체 대체물(`/goal`은 사용자만 칠 수 있는 세션 스코프 훅이라서). 호스트 규약을 그대로 쓴다 — **`exit 2` = 정지 차단 + stderr가 차단 메시지**, `exit 0`/`1` = 정지 허용. 훅 JSON은 stdin으로 들어오고 `session_id`만 뽑아 쓴다. 판정 입력은 주행이 쓰고 지우는 마커 `<forge-root>/drive.md`(`started:` epoch · `blocked:` 카운트 · `session:`)이며, 훅이 쓰는 유일한 상태는 `blocked:` 증가다. **호스트가 Stop 훅에 루프 보호를 제공하지 않으므로**(`stop_hook_active` 류 입력 필드 없음) 스크립트 내부의 두 상한(`MAX_AGE=1800`초, 차단 횟수)이 유일한 폭주 가드다. 벽 판정은 훅이 아니라 주행이 소유한다(마커 삭제 = "정지해도 좋다").
- **트랜스크립트 파일 읽기**: `scripts/forge-loop-spend.sh`/`.js`가 `~/.claude/projects/<cwd-slug>/` 아래 세션·서브에이전트 트랜스크립트를 직접 읽어 `message.usage`의 네 필드(`input_tokens`·`cache_creation_input_tokens`·`cache_read_input_tokens`·`output_tokens`)를 합산한다. 호스트가 남긴 파일을 소비할 뿐 API 호출은 없다. 테스트는 `--transcripts DIR`로 이 루트를 갈아끼운다. **이 경로는 Claude Code 전용으로 하드코딩돼 있고 Codex 대응 경로가 없다** — Codex는 `prevent_stop: false`라 애초에 무인 주행이 턴을 못 잇기 때문에 지금은 드러나지 않는 갭이다.
- **statusline**: `fg-statusline`이 사용자 `settings.json`의 `statusLine` command에 절대경로로 wire. 스크립트는 Claude Code가 stdin으로 주는 세션 JSON(cwd·model·cost·context 필드)을 파싱 (`scripts/forge-statusline-full.sh`/`.js`, 래퍼 `scripts/forge-statusline-wrapper.sh`). 환경변수 계약은 불변(`FORGE_SL_PREFIX`, `FORGE_SL_SEP`, `FORGE_SL_DENSITY`, 테스트용 `FORGE_SL_NOW`)이고, 렌더가 바뀌었다 — `verified:` 토큰을 소문자화해 판정하고(`Yes`/`N/A`가 `yes`/`n/a`와 같게 결정), `executed/` park을 회고 가능한 것과 `verified: failed`로 갈라 후자를 별도 `✗ N failed` 조각으로 낸다(막힌 상태를 "회고 대기"로 부르면 게이트가 거부하는 행동을 사용자에게 지시하게 된다).
- **서브에이전트 카드**: `fg-agents`가 `.claude/agents/<role>.md` 생성 → fg-run이 `agentType`으로 호출(세션 재시작 후 로드). 이 리포 자체도 3장 보유: `.claude/agents/{manifest-doc-syncer,script-twin-engineer,skill-author}.md`.
- **Dynamic Workflow**: fg-run/fg-loop/fg-adversarial-review가 Claude Code 워크플로우·병렬 서브에이전트 기능을 사용(코드 아닌 스킬 지시문 차원).

## 2. GitHub — `gh` CLI(문서 규칙)와 Actions/Pages(실제 CI)

### 2a. `gh` CLI (문서 규칙으로만 — 스크립트에는 없음)

`scripts/`·`skills/`에는 gh/curl 호출 코드가 없다. 전부 `CLAUDE.md`의 에이전트 지시 규칙이다:

- **이슈 연동 봉인** (`CLAUDE.md` "이슈 연동 작업 봉인 규칙"): plan에 `이슈 추적: GitHub 이슈 #N`이 있으면 fg-done 봉인 시 커밋 메시지 `(Fixes #N)` → `git push origin main` → `gh issue comment N` → `gh issue view N --json state` 확인, 필요 시 `gh issue close N`.
- **배포 후 설치 전제 검증**: `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json` 과 `.../main/.codex-plugin/plugin.json`으로 원격 main의 **버전 4곳**을 확인한다(`CLAUDE.md` 배포 규칙 — 4곳 체제에 맞춰 갱신됨). 로컬 게이트(§2c)와 이 원격 확인이 같은 4곳을 본다.
- **git**: 여러 스킬이 `git` 명령을 지시(브랜치별 forge 루트 판별 `scripts/resolve-forge-root.sh`, `fg-merge <branch>`의 대화형 `git merge` 등). 단 코어 통합 스크립트 `scripts/forge-merge.sh`/`.js`는 의도적으로 git-free(CI에서 AI 없이 사용 가능).

### 2b. GitHub Actions → GitHub Pages (`.github/workflows/docs.yml`)

**리포의 CI는 이제 둘이다**(§2c의 릴리스 게이트가 합류) — 이쪽은 플러그인이 아니라 문서 사이트만 다룬다(ADR `260815-094725`).

- 트리거: `main` push 중 `docs/**`·`package.json`·`package-lock.json`·`.github/workflows/docs.yml` 경로 변경, 그리고 `workflow_dispatch`.
- 권한 `contents: read`·`pages: write`·`id-token: write`, concurrency group `pages`(취소 안 함).
- build 잡: `actions/checkout@v4`(`fetch-depth: 0` — VitePress `lastUpdated`가 git 이력을 읽는다) → `actions/setup-node@v4`(node 22, `cache: npm`) → `npm ci` → `npm run docs:build` → `_site` 조립 → `actions/configure-pages@v4` → `actions/upload-pages-artifact@v3`.
- 아티팩트는 **두 표면**을 한 번에 싣는다: `docs/index.html`(+`docs/*.png`, `.nojekyll`)은 루트 `/forge/`로 그대로 복사되고, VitePress 산출물 `docs/.vitepress/dist`는 `/forge/docs/`로 마운트된다(`base: '/forge/docs/'`와 일치). 비-VitePress 자산 `docs/examples/`는 `_site/docs/examples/`로 목적지를 **명시해** 복사한다(맨 `cp -R src dst`는 dist가 examples를 내기 시작하는 순간 자기 안에 중첩된다).
- 조립 직후 `test -f`로 **7개** 파일 존재를 검사한다(`_site/index.html`, `_site/docs/index.html`, `_site/docs/skills.html`, **`_site/docs/codex.html`**, **`_site/docs/en/codex.html`**, `_site/docs/examples/github-actions-forge-check.yml`, `_site/docs/icon.png`) — 아티팩트 회귀를 잡는 유일한 게이트. 신규 두 항목이 **양 로케일**을 짚는 것이 요점이다(root locale만 검사하면 `/en/` 트리 누락이 조용히 통과한다).
- deploy 잡: `actions/deploy-pages@v4`, environment `github-pages`. **Pages 소스가 "GitHub Actions"로 설정돼 있어야 한다**(레거시 "branch /docs folder" 소스로는 이 아티팩트를 못 서빙 — 워크플로 헤더 주석에 명시).
- **npm 레지스트리**가 유일한 패키지 의존 경로다(`npm ci` + `package-lock.json`). 플러그인 런타임에는 npm 의존성이 하나도 들어가지 않는다.
- 신규 `docs/config-modes.md` ↔ `docs/en/config-modes.md` 쌍(사이드바 「가이드/Guides」)이 들어와 문서 쌍은 **9쌍**이 됐다. 이 쌍은 `test -f` 목록에 **없다**(VitePress dist 전체가 실려 커버되지만 명시 게이트는 아니다 — 명시 게이트를 받은 것은 `codex` 쌍뿐).

### 2c. 릴리스 게이트 — `npm run release:check` (**이제 CI에 연결됨**: `.github/workflows/release-check.yml`)

`package.json`의 `release:check` → `node scripts/release-check.js`(bash 트윈은 `scripts/release-check.sh`). 네트워크·API 없이 리포 자신의 파일만 읽어 배포 전 7가지를 확인한다: 매니페스트 3개 존재, **버전 4곳 동기**(`.claude-plugin/plugin.json` · `marketplace.json`의 `metadata.version`·`plugins[0].version` · `.codex-plugin/plugin.json` — 현재 **0.8.5**), **Codex 매니페스트의 `skills`가 `"./skills/"`**, `hooks/hooks.json` 존재, `hosts/{claude,codex}/{interaction.md,execution.md,capabilities.json}` 6파일 완전성, 그리고 **신규 2건** — `core/HOST.md`의 표에서 **파싱해 도출한** capability 어휘로 두 `capabilities.json`이 평평한 불리언 객체이며 키가 정확히 그 8개인지, `docs/codex.md`·`docs/en/codex.md`가 존재하며 그 8개 키를 **모두 이름 짓는지**. 어휘를 스크립트에 하드코딩하지 않은 이유가 주석에 있다 — 사본을 두면 그게 바로 이 검사가 막으려는 드리프트다.

**CI 배선(신규)**: `.github/workflows/release-check.yml`(잡 `gate`, `permissions: contents: read`, node 20, **`npm ci` 없음** — 게이트가 zero-dependency 설계라서)이 `main` push·PR·`workflow_dispatch`에 발동한다. 경로 필터는 `.claude-plugin/**`·`.codex-plugin/**`·`core/**`·`hosts/**`·`hooks/**`·`scripts/release-check.*`·`docs/codex.md`·`docs/en/codex.md`·자기 자신. 스텝 셋을 순서대로 돌린다 — `bash scripts/release-check.sh` → `node scripts/release-check.js` → `bash scripts/release-check.parity.test.sh`(stdout·stderr·exit code·**에러 순서**까지). **이것을 `docs.yml`의 스텝으로 넣지 않은 이유가 워크플로 헤더에 박혀 있다**: 그쪽은 `docs/**`·`package.json`에만 발동하므로 정작 지켜야 할 `.codex-plugin/`·`hosts/`·`core/` 변경에 발동하지 않는 fail-open 게이트가 된다(*"a gate that looks wired but cannot fire is worse than no gate"*). 두 트윈을 다 돌리는 이유도 명시돼 있다 — 조용한 갈라짐이 드러나는 자리가 CI라서(ADR-0022).

같은 4-way 버전 검사가 `forge-doctor`의 **B8**에도, Codex 매니페스트 JSON 유효성이 **B9**에도 있다(독립 발동 경로). `forge-doctor` 자신은 여전히 어느 워크플로에도 안 걸려 있다.

## 3. 시각 컴패니언 로컬 서버 (`fg-showme`)

- `skills/fg-showme/scripts/server.cjs` — zero-dependency Node HTTP+WebSocket(RFC 6455 직접 구현) 서버. **원격 요청·텔레메트리 없음**(파일 헤더에 명시, superpowers 브랜딩/텔레메트리 제거됨).
- 랜덤 하이 포트에 기동(`start-server.sh`), 세션 키 URL 인증(`?key=` 토큰), Origin 검사, 포트/키를 `<project>/.forge/showme/.last-port`에 영속해 재시작 시 재사용. 유휴 자동 종료는 `BRAINSTORM_IDLE_TIMEOUT_MS` 환경변수(기본 4시간).
- 세션 파일은 모든 브랜치에서 최상위 `.forge/showme/<세션>/` (휘발). **git 진입 경로가 구조적으로 없다** — 루트 `.gitignore`가 `.forge/*`로 이미 덮지만 거기에 의존하지 않고, `start-server.sh`(약 136행)가 `.forge/showme/.gitignore`에 `*` 한 줄을 **자체-ignore**로 써 준다(없을 때만). 사용자 자신의 `.gitignore`는 불가침이며 이것이 유일한 예외다.
- **수명 종료 시 흔적을 지운다**: `stop-server.sh`가 세션 디렉터리를 `rm -rf`하고, 그게 `.forge/showme/` 아래 마지막이면 그 디렉터리를 `.last-*`·`.gitignore`까지 통째로 제거한다. stopped 마커를 먼저 남기므로 삭제가 실패해도 다음 기동 때 `start-server.sh`의 **sweep**이 회수한다 — `state/server-stopped` 마커가 있거나 `state/server.pid`가 없거나 `kill -0`에 죽은 세션 폴더를 `rm -rf`하고, **살아 있는 동시 세션과 `.last-port`/`.last-token`은 건드리지 않는다**(크래시한 서버의 열린 탭이 재접속할 수 있게). `--project-dir` 없이 기동하면 세션이 리포 밖 `/tmp/forge-showme-<세션ID>`에 살고 `.forge/`를 아예 안 쓴다. 전 경로 `umask 077`.
- 사용자 입력(클릭·텍스트)은 JSONL 이벤트로 에이전트에 회수 — 보조 답변 채널.

## 4. Vendored / 개념 차용 (외부 코드 유입 경로)

| 출처 | 라이선스 | 유입 형태 | 위치 |
| --- | --- | --- | --- |
| obra/superpowers v6.1.1 Visual Companion | MIT (LICENSE 동봉) | 코드 vendoring (5파일) | `skills/fg-showme/scripts/`, `skills/fg-showme/LICENSE` |
| obra/superpowers `run-hook.cmd` polyglot 패턴 | MIT (파일 헤더 귀속) | 코드 차용 + node 폴백 확장 | `hooks/run-hook.cmd` |
| cloudflare/security-audit-skill | MIT (LICENSE 동봉, Copyright 2025-2026 Cloudflare, Inc.) | 코드 vendoring (12파일, **원형 유지**·진입 파일만 `SKILL.md`→`AUDIT.md` 개명) | `skills/fg-security/{AUDIT,ATTACK-CLASSES,HUNTING,RECONNAISSANCE,VALIDATION-AND-REPORTING,WEB-PROTOCOL-AND-AUTH,CLIENT-SIDE,AI-AND-LLM,MEMORY-SAFETY-AND-BINARY}.md`, `report-schema.json`, `validate-findings.cjs`, `LICENSE` |
| mattpocock/skills `diagnosing-bugs` | MIT (LICENSE 동봉, Copyright 2026 Matt Pocock) | 코드 vendoring (3파일, **바이트 보존**·진입 파일만 `SKILL.md`→`DIAGNOSE.md` 개명 — fg-security 선례) | `skills/fg-debug/DIAGNOSE.md`, `skills/fg-debug/scripts/hitl-loop.template.sh`, `skills/fg-debug/LICENSE` |
| mattpocock/skills Wayfinder | MIT | **개념만** 각색 (파일 복사 없음) | `skills/fg-agenda/SKILL.md` |
| daleseo statusline 스타일 | — | 스타일 참조 | `scripts/forge-statusline-full.sh` |

**같은 업스트림이 표에 두 번 나오는 것은 오류가 아니다** — `mattpocock/skills`에서 Wayfinder는 **개념만**(파일 0개) 왔고 `diagnosing-bugs`는 **파일째로** 왔다. 두 행은 유입 형태가 달라 갱신 방식도 다르다: 개념 행은 forge 어휘로 다시 쓰인 것이라 자유롭게 편집하고, vendoring 행 3파일은 편집 금지다(`skills/fg-debug/SKILL.md`가 명시 — 미래 diff를 싸게 유지하기 위한 바이트 보존).

## 5. 보안 감사 산출물 — 리포 **밖** (`fg-security`)

연동이라기보다 **의도적 경계**다. 감사 산출물은 업스트림 기본값 `~/security-audit-skill/<repo-name>/run-<N>/`(`architecture.md`·`REPORT.md`·`FINDINGS-DETAIL.md`·`findings.json`)에 남고, forge는 감사를 위해 리포 안에 **아무것도 쓰지 않는다** — `.gitignore` 관례에 기대지 않고 커밋 경로 자체를 없앤 것(ADR `260820-215004`). 생성되는 fix-forward plan도 finding을 run+index로만 참조하고 익스플로잇을 인라인하지 않는다. `findings.json` 검증은 로컬 `node skills/fg-security/validate-findings.cjs <path>`(zero-dependency, exit 0/1).

### 5b. 진단 캡처도 워킹 트리 **밖** (`fg-debug`, 신규)

같은 부류의 경계이고 메커니즘만 다르다. `fg-debug`는 **새 `.forge/` 상태를 만들지 않는다**(`.forge/debug/` 같은 디렉터리 없음 — ADR `260907-140655` 결정 3). 원본 트레이스·HAR·로그·인증 헤더·개인정보 등 민감할 수 있는 캡처는 **프로젝트 워킹 트리 밖 OS 임시 위치**에서만 수집·검사하고, 워킹 트리에 남을 수 있는 것은 **비밀 제거가 확인된 fixture**와 **영속 테스트/체크** 둘뿐이다. **모든** 종료 경로(확정·불확정 2종·활성 작업 복귀·생성 plan 핸드오프·`fg-quick` 이관)에서 원본 캡처·임시 계측·일회성 하니스를 삭제하며, 남기기로 한 안전 산출물은 활성 수리·생성 plan·`fg-quick` 범위의 Phase 6 정리로 **소유자를 지정**한다. 사람이 클릭해야만 재현되는 버그는 vendored `skills/fg-debug/scripts/hitl-loop.template.sh`(bash, 외부 의존 0)를 복사·편집해 돌리고, 로그인 같은 행위는 `step`으로 사람에게 남기고 관찰값만 `capture`로 받아 `KEY=VALUE`로 회수한다 — 브라우저·원격 자동화 도구를 끌어오지 않는 것이 이 경로의 핵심이다.

## 6. 문서 사이트·랜딩 페이지 외부 자원

- `docs/index.html`이 원격 자원을 참조: Google Fonts CDN(`fonts.googleapis.com` — Inter·JetBrains Mono). 그 외 링크는 `github.com/gyuha/forge` 이동뿐.
- VitePress 사이트는 `https://gyuha.com/forge/docs/`로 서빙되고, 랜딩(`https://gyuha.com/forge/`)은 `base` 밖이라 nav에서 **절대 URL**로 링크해야 한다(root-relative로 쓰면 VitePress가 base를 붙여 사이트 안으로 되돌린다 — `docs/.vitepress/config.mts`의 `LANDING_URL`).
- Mermaid는 빌드 타임 플러그인(`vitepress-plugin-mermaid`)이지 런타임 CDN이 아니다.

## 없는 것 (명시적 부재)

- 데이터베이스, 인증 프로바이더, 웹훅 수신, 원격 API 클라이언트 — 전부 없음. 상태는 로컬 `.forge/` 파일 시스템이 전부다.
- **npm 의존성은 여전히 문서 사이트 전용이지만, CI는 더 이상 그렇지 않다.** `release-check.yml`(§2c)이 플러그인 매니페스트·어댑터·훅을 검사하는 **플러그인 본체용 CI**다 — 다만 그 게이트조차 `npm ci`를 안 돌린다. 즉 정확한 진술은 "플러그인 본체는 여전히 **의존성 0**이고, 파이프라인은 0이 아니라 **의존성 없는 게이트 하나**"다.
