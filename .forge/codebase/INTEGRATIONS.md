---
last_mapped_commit: 6146cae539151b65850e1e2609bdf8f7e78a1e47
mapped: 2026-09-11
---

# INTEGRATIONS — 외부 연동

## 에이전트 호스트

### Claude Code

- `.claude-plugin/plugin.json`이 Claude Code 플러그인 메타데이터를 제공하고 `.claude-plugin/marketplace.json`이 저장소 루트를 marketplace source `./`로 노출한다.
- Claude Code는 `skills/<name>/SKILL.md`를 자동 탐색한다. 저장소 자체의 프로젝트 역할 카드는 `.claude/agents/*.md`, 로컬 이슈 분류 스킬은 `.claude/skills/issue-triage/SKILL.md`에 있다.
- `hooks/hooks.json`은 `SessionStart`와 `Stop` 이벤트를 Claude Code 훅 명령에 연결한다. 두 이벤트 모두 `hooks/run-hook.cmd`를 거쳐 `scripts/forge-hook-session-start.*` 또는 `scripts/forge-hook-stop.*`를 실행한다.
- `SessionStart`는 `startup|resume|clear|compact`에 동기 실행돼 미완료 Forge 상태를 세션 문맥으로 출력한다. `Stop`은 활성 무인 drive의 좁은 조건에서 종료 코드 2와 stderr 지시문으로 정지를 막는다.
- `skills/fg-statusline/SKILL.md`는 Claude Code의 단일 `statusLine` 명령과 통합한다. 얇은 표시기는 `scripts/forge-statusline.*`, 통합 표시는 `scripts/forge-statusline-full.*`, 기존 명령 보존은 `scripts/forge-statusline-wrapper.sh`가 담당한다.

### Codex

- `.codex-plugin/plugin.json`이 Codex용 플러그인 메타데이터와 `skills: "./skills/"`를 선언한다. Claude Code와 별도 스킬 사본을 두지 않는다.
- `hosts/codex/interaction.md`와 `hosts/codex/execution.md`가 텍스트 선택과 collaboration/subagent 실행 방식을 설명하고, `hosts/codex/capabilities.json`이 관측된 지원 범위를 기계 판독 형식으로 제공한다.
- Codex에서는 `PLUGIN_ROOT`가 설치된 플러그인 파일 경로 신호로 사용된다. 정확한 선택과 폴백 규칙은 `core/HOST.md`에 있다.
- Codex에 상태 표시 capability가 없다고 선언돼 있어 `fg-statusline`은 설정 파일을 변경하지 않고 `fg-status` 사용으로 안내한다. 이 분기는 `skills/fg-statusline/SKILL.md`에 있다.

### opencode

- opencode 전용 플러그인 매니페스트는 없다. 설치와 탐색은 `docs/opencode.md`와 `docs/en/opencode.md`에 기록된 `SKILL.md` 검색 경로 및 symlink 방식에 의존한다.
- 호스트별 폴백은 `hosts/opencode/interaction.md`, `hosts/opencode/execution.md`, `hosts/opencode/capabilities.json`에 있다. 현재 모든 capability 값이 `false`이므로 평문 질문과 직렬 실행 경로를 사용한다.
- opencode 식별에는 안정적인 환경 변수 대신 명시적 호스트 메타데이터만 사용한다. 이 판정은 `core/HOST.md`에 정의돼 있다.

## Git과 GitHub

- `scripts/resolve-forge-root.*`, `scripts/forge-merge.*`, `scripts/forge-statusline*`, `scripts/forge-hook-session-start.*`는 로컬 Git CLI를 사용해 저장소 루트, 현재 브랜치, 상태 또는 병합 조건을 판정한다.
- 무인 실행의 선택적 로컬 커밋 절차는 `skills/fg-next/DRIVE.md`에 있다. `git status`, `git add -A`, `git commit`을 사용하지만 push는 하지 않는다.
- 브랜치 병합 편의 경로는 `skills/fg-merge/SKILL.md`가 `git merge`를 실행하고, Forge 상태 통합은 `scripts/forge-merge.sh` 또는 `scripts/forge-merge.js`가 처리한다.
- 저장소 유지보수 규칙에는 GitHub CLI를 통한 이슈 코멘트·닫힘 확인과 `git push origin main` 절차가 `CLAUDE.md`에 기록돼 있다. 이는 일반 스킬 런타임에서 자동 호출되는 API 클라이언트가 아니다.
- 문서와 매니페스트의 저장소·홈페이지 링크는 `https://github.com/gyuha/forge`를 가리킨다. `.codex-plugin/plugin.json`, `docs/.vitepress/config.mts`, `README.md`에 해당 URL이 있다.

## GitHub Actions와 Pages

- `.github/workflows/docs.yml`은 `main`의 문서 관련 변경 또는 수동 실행에 반응한다. `actions/checkout@v4`, `actions/setup-node@v4`, `actions/configure-pages@v4`, `actions/upload-pages-artifact@v3`, `actions/deploy-pages@v4`를 사용한다.
- 문서 워크플로는 `docs/index.html`과 루트 이미지 자산을 Pages 아티팩트의 `/forge/`에, VitePress 결과를 `/forge/docs/`에 배치한다. 배포 URL은 GitHub Pages environment에서 받는다.
- `docs/public/`의 자산은 VitePress 빌드를 거쳐 `/forge/docs/`로 나온다. 랜딩(`/forge/`)의 소셜 이미지 태그가 `/forge/docs/og-image.png`를 참조하므로, 두 아티팩트 구획이 배포 후 같은 사이트에서 합쳐진다는 전제에 의존한다.
- `.github/workflows/release-check.yml`은 `main` push, pull request, 수동 실행에 반응한다. Linux에서 릴리스 게이트를, Windows에서 `hooks/run-hook.windows.test.js`를 실행한다.
- 두 워크플로 모두 저장소 contents를 읽는다. 문서 배포 job만 `pages: write`와 `id-token: write` 권한을 요청한다.

## npm과 문서 렌더링

- npm은 `package-lock.json`을 사용해 VitePress, Mermaid, `vitepress-plugin-mermaid`와 전이 의존성을 설치한다. 이 패키지들은 `docs/` 빌드에만 필요하다.
- `docs/.vitepress/config.mts`는 `withMermaid`로 Mermaid를 VitePress에 연결하고 로컬 검색을 사용한다.
- 같은 설정이 `sitemap.hostname`을 `https://gyuha.com/forge/docs/`로 지정해 빌드 시 사이트맵을 방출하고, `transformHead`로 페이지마다 canonical URL과 Open Graph·Twitter Card 메타 태그를 생성한다. 이는 검색 엔진·소셜 미리보기 크롤러를 향한 정적 출력이며, 빌드나 런타임에 외부 서비스를 호출하지 않는다.
- 소셜 미리보기 이미지는 저장소 안의 `docs/public/og-image.png`이고 절대 URL로 참조된다. 배포 호스트 이름이 바뀌면 `config.mts`의 `SITE_URL` 상수와 `docs/index.html`의 하드코딩된 절대 URL을 함께 고쳐야 한다.
- 외부 CDN, 분석·텔레메트리 스크립트는 문서 사이트 설정에 없다. 랜딩과 시각 컴패니언 자산은 저장소 파일에서 제공된다. 단 `docs/index.html`은 Google Fonts(`fonts.googleapis.com`, `fonts.gstatic.com`)에 `preconnect`하는 원격 글꼴 참조를 가진다.

## 로컬 브라우저 연동

- `skills/fg-showme/scripts/start-server.sh`가 로컬 시각 컴패니언을 시작한다. 기본 bind 주소는 `127.0.0.1`, 기본 유휴 종료 시간은 240분이며 프로젝트 모드의 세션 파일은 `.forge/showme/<session>/`에 둔다.
- `skills/fg-showme/scripts/server.cjs`는 내장 HTTP 서버와 WebSocket 연결을 제공한다. 화면 HTML과 이벤트 JSONL은 세션 디렉터리에서 읽고 쓰며, 원격 서비스로 요청하지 않는다.
- 서버 접근은 세션별 무작위 키를 URL query와 same-origin cookie로 전달해 검사한다. WebSocket은 키와 Origin을 함께 검사하고, 키 비교에는 `crypto.timingSafeEqual` 기반 처리를 사용한다.
- `skills/fg-showme/scripts/helper.js`는 브라우저에서 WebSocket 재연결, 화면 갱신, 사용자 이벤트 큐를 처리한다.
- `skills/fg-showme/scripts/server.cjs`의 브라우저 열기 경로는 macOS `open`, Windows `cmd /c start`, Linux `xdg-open` 중 플랫폼별 실행 파일을 shell 없이 호출한다.
- `skills/fg-showme/scripts/stop-server.sh`는 해당 프로세스를 확인해 종료하고 세션 디렉터리를 삭제한다.

## 파일 시스템과 프로세스 경계

- Forge의 영속·휘발 상태는 프로젝트 로컬 `.forge/` 파일에 저장된다. 별도 데이터베이스나 원격 상태 저장소는 없다.
- 기본 브랜치 상태는 `.forge/`, 비기본 브랜치 상태는 `.forge/branch/<branch>/`에 둔다. 예외인 전역 지도는 `.forge/codebase/`, 시각 컴패니언 임시 상태는 `.forge/showme/`에 둔다.
- `hooks/run-hook.cmd`는 `CLAUDE_PROJECT_DIR`가 있으면 그 경로로 이동한 뒤 훅 본체를 실행한다. Unix에서는 Bash 우선·Node 폴백, Windows에서는 Git Bash 우선·Node 폴백이다.
- `scripts/forge-loop-spend.*`는 Claude Code transcript 파일을 읽어 선택적 토큰 예산을 계측한다. 다른 호스트에서는 transcript 경로를 명시하지 않으면 해당 기능을 사용할 수 없다는 제한이 `docs/codex.md`와 `docs/opencode.md`에 기록돼 있다.

## 인증·비밀·원격 데이터 서비스

- 애플리케이션 수준의 사용자 계정, OAuth 공급자, 결제 공급자, 외부 데이터베이스, 메시지 큐, 객체 저장소, HTTP webhook 수신기는 구현돼 있지 않다.
- 저장소에는 외부 SaaS API SDK가 런타임 의존성으로 선언돼 있지 않다. `package.json`의 직접 의존성은 문서 빌드 도구뿐이다.
- GitHub Actions 인증은 GitHub가 제공하는 workflow token과 Pages OIDC 권한에 의존하며, 저장소 코드에 자격 증명을 하드코딩하지 않는다. 관련 권한은 `.github/workflows/docs.yml`과 `.github/workflows/release-check.yml`에 명시돼 있다.
- 시각 컴패니언의 세션 키는 `.forge/showme/` 내부 파일과 로컬 URL에만 존재하며, `skills/fg-showme/scripts/start-server.sh`가 해당 디렉터리에 자기 자신을 무시하는 `.gitignore`를 만든다.

## 공급망과 vendoring

- `skills/fg-security/`는 Cloudflare의 `security-audit-skill`을 MIT 라이선스와 함께 vendoring한다. 출처 표기는 `skills/fg-security/AUDIT.md`와 `skills/fg-security/LICENSE`에 있다.
- `skills/fg-debug/`는 `mattpocock/skills`의 진단 자료를 MIT 라이선스와 함께 vendoring한다. 출처와 수정 경계는 `skills/fg-debug/SKILL.md`와 `skills/fg-debug/LICENSE`에 있다.
- `skills/fg-showme/`와 `hooks/run-hook.cmd`는 obra/superpowers 계열 코드를 MIT 고지와 함께 포함한다. 라이선스는 `skills/fg-showme/LICENSE`, 변경 내역은 각 소스 파일 머리말에 있다.
