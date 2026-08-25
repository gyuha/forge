---
last_mapped_commit: 182175fe02f832806c44148e7036d0dc26d7a55b
mapped: 2026-08-26
---

# INTEGRATIONS — 외부 연동

## 한 줄 요약

데이터베이스·인증 프로바이더·원격 API 호출 코드가 **없다**. 연동 표면은 (1) Claude Code 플러그인 호스트(훅 2종·statusline·트랜스크립트 파일 읽기), (2) GitHub(`gh` CLI·raw 콘텐츠는 문서 규칙으로만, **Actions/Pages는 실제 CI**), (3) 로컬호스트 시각 컴패니언 서버, (4) MIT 코드 vendoring 세 건(+개념 차용 한 건), (5) npm 레지스트리 — **문서 사이트 devDependencies 한정**이다.

## 1. Claude Code 플러그인 표면 (주 연동)

- **마켓플레이스 겸 플러그인**: 리포 루트가 곧 플러그인. `.claude-plugin/marketplace.json`의 `plugins[0].source: "./"`. 설치는 GitHub `main` 브랜치를 당긴다(push까지가 배포).
- **스킬 자동 탐색**: `skills/*/SKILL.md` (frontmatter `name`이 식별자).
- **훅**: `hooks/hooks.json`이 **두 개**를 등록한다. 둘 다 `shell: "bash"`·`async: false`이고 `"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd" <name>`을 부르며, polyglot 래퍼가 `.sh`(bash 우선) → `.js`(node 폴백)로 디스패치하고 런타임이 없으면 exit 0 침묵한다.
  - `SessionStart` (matcher `startup|resume|clear|compact`) → `session-start` → `scripts/forge-hook-session-start.sh`/`.js`. 미봉인 잔여를 세션 진입 컨텍스트에 주입. `CLAUDE_PROJECT_DIR` 환경변수로 프로젝트 디렉터리에 앵커.
  - `Stop` (matcher 없음 = 전부) → `stop` → `scripts/forge-hook-stop.sh`/`.js`. 무인 주행을 턴 경계 너머로 잇는 forge 자체 대체물(`/goal`은 사용자만 칠 수 있는 세션 스코프 훅이라서). 호스트 규약을 그대로 쓴다 — **`exit 2` = 정지 차단 + stderr가 차단 메시지**, `exit 0`/`1` = 정지 허용. 훅 JSON은 stdin으로 들어오고 `session_id`만 뽑아 쓴다. 판정 입력은 주행이 쓰고 지우는 마커 `<forge-root>/drive.md`(`started:` epoch · `blocked:` 카운트 · `session:`)이며, 훅이 쓰는 유일한 상태는 `blocked:` 증가다. **호스트가 Stop 훅에 루프 보호를 제공하지 않으므로**(`stop_hook_active` 류 입력 필드 없음) 스크립트 내부의 두 상한(`MAX_AGE=1800`초, 차단 횟수)이 유일한 폭주 가드다. 벽 판정은 훅이 아니라 주행이 소유한다(마커 삭제 = "정지해도 좋다").
- **트랜스크립트 파일 읽기**: `scripts/forge-loop-spend.sh`/`.js`가 `~/.claude/projects/<cwd-slug>/` 아래 세션·서브에이전트 트랜스크립트를 직접 읽어 `message.usage`의 네 필드(`input_tokens`·`cache_creation_input_tokens`·`cache_read_input_tokens`·`output_tokens`)를 합산한다. 호스트가 남긴 파일을 소비할 뿐 API 호출은 없다. 테스트는 `--transcripts DIR`로 이 루트를 갈아끼운다.
- **statusline**: `fg-statusline`이 사용자 `settings.json`의 `statusLine` command에 절대경로로 wire. 스크립트는 Claude Code가 stdin으로 주는 세션 JSON(cwd·model·cost·context 필드)을 파싱 (`scripts/forge-statusline-full.sh`/`.js`, 래퍼 `scripts/forge-statusline-wrapper.sh`). 환경변수 계약: `FORGE_SL_PREFIX`, `FORGE_SL_SEP`, `FORGE_SL_DENSITY`, 테스트용 `FORGE_SL_NOW`.
- **서브에이전트 카드**: `fg-agents`가 `.claude/agents/<role>.md` 생성 → fg-run이 `agentType`으로 호출(세션 재시작 후 로드). 이 리포 자체도 3장 보유: `.claude/agents/{manifest-doc-syncer,script-twin-engineer,skill-author}.md`.
- **Dynamic Workflow**: fg-run/fg-loop/fg-adversarial-review가 Claude Code 워크플로우·병렬 서브에이전트 기능을 사용(코드 아닌 스킬 지시문 차원).

## 2. GitHub — `gh` CLI(문서 규칙)와 Actions/Pages(실제 CI)

### 2a. `gh` CLI (문서 규칙으로만 — 스크립트에는 없음)

`scripts/`·`skills/`에는 gh/curl 호출 코드가 없다. 전부 `CLAUDE.md`의 에이전트 지시 규칙이다:

- **이슈 연동 봉인** (`CLAUDE.md` "이슈 연동 작업 봉인 규칙"): plan에 `이슈 추적: GitHub 이슈 #N`이 있으면 fg-done 봉인 시 커밋 메시지 `(Fixes #N)` → `git push origin main` → `gh issue comment N` → `gh issue view N --json state` 확인, 필요 시 `gh issue close N`.
- **배포 후 설치 전제 검증**: `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`으로 원격 버전 3곳 확인 (`CLAUDE.md` 배포 규칙).
- **git**: 여러 스킬이 `git` 명령을 지시(브랜치별 forge 루트 판별 `scripts/resolve-forge-root.sh`, `fg-merge <branch>`의 대화형 `git merge` 등). 단 코어 통합 스크립트 `scripts/forge-merge.sh`/`.js`는 의도적으로 git-free(CI에서 AI 없이 사용 가능).

### 2b. GitHub Actions → GitHub Pages (`.github/workflows/docs.yml`)

리포의 **유일한 CI**이며 플러그인이 아니라 문서 사이트만 다룬다(ADR `260815-094725`).

- 트리거: `main` push 중 `docs/**`·`package.json`·`package-lock.json`·`.github/workflows/docs.yml` 경로 변경, 그리고 `workflow_dispatch`.
- 권한 `contents: read`·`pages: write`·`id-token: write`, concurrency group `pages`(취소 안 함).
- build 잡: `actions/checkout@v4`(`fetch-depth: 0` — VitePress `lastUpdated`가 git 이력을 읽는다) → `actions/setup-node@v4`(node 22, `cache: npm`) → `npm ci` → `npm run docs:build` → `_site` 조립 → `actions/configure-pages@v4` → `actions/upload-pages-artifact@v3`.
- 아티팩트는 **두 표면**을 한 번에 싣는다: `docs/index.html`(+`docs/*.png`, `.nojekyll`)은 루트 `/forge/`로 그대로 복사되고, VitePress 산출물 `docs/.vitepress/dist`는 `/forge/docs/`로 마운트된다(`base: '/forge/docs/'`와 일치). 비-VitePress 자산 `docs/examples/`는 `_site/docs/examples/`로 목적지를 **명시해** 복사한다(맨 `cp -R src dst`는 dist가 examples를 내기 시작하는 순간 자기 안에 중첩된다).
- 조립 직후 `test -f`로 5개 파일 존재를 검사한다(`_site/index.html`, `_site/docs/index.html`, `_site/docs/skills.html`, `_site/docs/examples/github-actions-forge-check.yml`, `_site/docs/icon.png`) — 아티팩트 회귀를 잡는 유일한 게이트.
- deploy 잡: `actions/deploy-pages@v4`, environment `github-pages`. **Pages 소스가 "GitHub Actions"로 설정돼 있어야 한다**(레거시 "branch /docs folder" 소스로는 이 아티팩트를 못 서빙 — 워크플로 헤더 주석에 명시).
- **npm 레지스트리**가 유일한 패키지 의존 경로다(`npm ci` + `package-lock.json`). 플러그인 런타임에는 npm 의존성이 하나도 들어가지 않는다.

## 3. 시각 컴패니언 로컬 서버 (`fg-visual`)

- `skills/fg-visual/scripts/server.cjs` — zero-dependency Node HTTP+WebSocket(RFC 6455 직접 구현) 서버. **원격 요청·텔레메트리 없음**(파일 헤더에 명시, superpowers 브랜딩/텔레메트리 제거됨).
- 랜덤 하이 포트에 기동(`start-server.sh`), 세션 키 URL 인증(`?key=` 토큰), Origin 검사, 포트/키를 `<project>/.forge/visual/.last-port`에 영속해 재시작 시 재사용. 유휴 자동 종료는 `BRAINSTORM_IDLE_TIMEOUT_MS` 환경변수(기본 4시간).
- 세션 파일은 모든 브랜치에서 최상위 `.forge/visual/<세션>/` (휘발·gitignore).
- 사용자 입력(클릭·텍스트)은 JSONL 이벤트로 에이전트에 회수 — 보조 답변 채널.

## 4. Vendored / 개념 차용 (외부 코드 유입 경로)

| 출처 | 라이선스 | 유입 형태 | 위치 |
| --- | --- | --- | --- |
| obra/superpowers v6.1.1 Visual Companion | MIT (LICENSE 동봉) | 코드 vendoring (5파일) | `skills/fg-visual/scripts/`, `skills/fg-visual/LICENSE` |
| obra/superpowers `run-hook.cmd` polyglot 패턴 | MIT (파일 헤더 귀속) | 코드 차용 + node 폴백 확장 | `hooks/run-hook.cmd` |
| cloudflare/security-audit-skill | MIT (LICENSE 동봉, Copyright 2025-2026 Cloudflare, Inc.) | 코드 vendoring (12파일, **원형 유지**·진입 파일만 `SKILL.md`→`AUDIT.md` 개명) | `skills/fg-security/{AUDIT,ATTACK-CLASSES,HUNTING,RECONNAISSANCE,VALIDATION-AND-REPORTING,WEB-PROTOCOL-AND-AUTH,CLIENT-SIDE,AI-AND-LLM,MEMORY-SAFETY-AND-BINARY}.md`, `report-schema.json`, `validate-findings.cjs`, `LICENSE` |
| mattpocock/skills Wayfinder | MIT | **개념만** 각색 (파일 복사 없음) | `skills/fg-agenda/SKILL.md` |
| daleseo statusline 스타일 | — | 스타일 참조 | `scripts/forge-statusline-full.sh` |

## 5. 보안 감사 산출물 — 리포 **밖** (`fg-security`)

연동이라기보다 **의도적 경계**다. 감사 산출물은 업스트림 기본값 `~/security-audit-skill/<repo-name>/run-<N>/`(`architecture.md`·`REPORT.md`·`FINDINGS-DETAIL.md`·`findings.json`)에 남고, forge는 감사를 위해 리포 안에 **아무것도 쓰지 않는다** — `.gitignore` 관례에 기대지 않고 커밋 경로 자체를 없앤 것(ADR `260820-215004`). 생성되는 fix-forward plan도 finding을 run+index로만 참조하고 익스플로잇을 인라인하지 않는다. `findings.json` 검증은 로컬 `node skills/fg-security/validate-findings.cjs <path>`(zero-dependency, exit 0/1).

## 6. 문서 사이트·랜딩 페이지 외부 자원

- `docs/index.html`이 원격 자원을 참조: Google Fonts CDN(`fonts.googleapis.com` — Inter·JetBrains Mono). 그 외 링크는 `github.com/gyuha/forge` 이동뿐.
- VitePress 사이트는 `https://gyuha.com/forge/docs/`로 서빙되고, 랜딩(`https://gyuha.com/forge/`)은 `base` 밖이라 nav에서 **절대 URL**로 링크해야 한다(root-relative로 쓰면 VitePress가 base를 붙여 사이트 안으로 되돌린다 — `docs/.vitepress/config.mts`의 `LANDING_URL`).
- Mermaid는 빌드 타임 플러그인(`vitepress-plugin-mermaid`)이지 런타임 CDN이 아니다.

## 없는 것 (명시적 부재)

- 데이터베이스, 인증 프로바이더, 웹훅 수신, 원격 API 클라이언트 — 전부 없음. 상태는 로컬 `.forge/` 파일 시스템이 전부다.
- **npm 의존성과 CI는 이제 존재하지만 문서 사이트 전용이다**(§2b). 플러그인 본체는 여전히 의존성 0·파이프라인 0이며, 이 경계를 흐리지 말 것.
