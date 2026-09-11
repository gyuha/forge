---
last_mapped_commit: 6146cae539151b65850e1e2609bdf8f7e78a1e47
mapped: 2026-09-11
---

# STACK — 기술 스택

## 저장소 성격

- forge 본체는 Claude Code, Codex, opencode가 공유하는 에이전트 워크플로 플러그인이다. 실행 규칙은 `skills/`, 호스트 중립 계약은 `core/`, 호스트별 어댑터는 `hosts/`에 있다.
- 주 산출물은 Markdown과 JSON이다. 스킬은 `skills/<name>/SKILL.md`, Claude 플러그인 메타데이터는 `.claude-plugin/plugin.json`과 `.claude-plugin/marketplace.json`, Codex 메타데이터는 `.codex-plugin/plugin.json`에 있다.
- 플러그인 본체를 컴파일하거나 번들링하는 단계는 없다. 루트 `package.json`은 `docs/`의 VitePress 사이트와 릴리스 검사 명령만 제공한다.

## 언어와 파일 형식

| 용도 | 기술 | 구현 위치 |
| --- | --- | --- |
| 스킬·계약·사용자 문서 | Markdown | `skills/**/*.md`, `core/*.md`, `hosts/*/*.md`, `README.md`, `README.ko.md`, `docs/*.md`, `docs/en/*.md` |
| 플러그인·호스트·상태 설정 | JSON | `.claude-plugin/*.json`, `.codex-plugin/plugin.json`, `hosts/*/capabilities.json`, `hooks/hooks.json`, `.forge/config.json` |
| 결정론 로직의 기본 구현 | Bash | `scripts/*.sh` |
| 결정론 로직의 교차 플랫폼 트윈 | Node.js CommonJS | `scripts/*.js` |
| 독립 검증기와 로컬 서버 | Node.js CommonJS | `skills/fg-security/validate-findings.cjs`, `skills/fg-showme/scripts/server.cjs` |
| 브라우저 클라이언트·랜딩 | HTML, CSS, 브라우저 JavaScript | `docs/index.html`, `skills/fg-showme/scripts/frame-template.html`, `skills/fg-showme/scripts/helper.js` |
| 문서 사이트 설정 | TypeScript ESM | `docs/.vitepress/config.mts` |
| 자동화 | GitHub Actions YAML | `.github/workflows/docs.yml`, `.github/workflows/release-check.yml` |

## 런타임

### 플러그인 실행

- 각 `SKILL.md`는 호스트가 직접 읽고 실행한다. 현재 `skills/` 아래에는 22개의 `SKILL.md`가 있다.
- 결정론 작업은 Bash 구현과 Node.js 구현을 쌍으로 제공한다. `scripts/forge-status.sh`와 `scripts/forge-status.js`처럼 같은 basename의 트윈이 상태 조사, 봉인, 병합, 상태줄, 훅, 예산 계측을 담당한다.
- `scripts/`에는 11개의 Node.js 실행 파일과 그에 대응하는 11개의 Bash 구현이 있다. Node 구현은 외부 패키지 없이 `fs`, `path`, `os`, `child_process` 같은 내장 모듈을 사용한다.
- `hooks/run-hook.cmd`는 Windows batch와 Unix shell을 한 파일에 담은 polyglot 디스패처다. Windows에서는 Git Bash를 먼저 찾고 Node.js로 폴백하며, Unix에서는 Bash 구현을 먼저 실행하고 Node.js로 폴백한다.
- Git 저장소·브랜치 판정이 필요한 스크립트는 시스템 `git` 명령을 호출한다. 공통 루트 판정은 `scripts/resolve-forge-root.sh`와 `scripts/resolve-forge-root.js`가 제공한다.

### 문서 사이트

- `package.json`은 VitePress `^1.5.0`, Mermaid `^11.4.1`, `vitepress-plugin-mermaid` `^2.0.17`을 개발 의존성으로 선언한다.
- 현재 `package-lock.json`에 고정된 직접 의존성 버전은 VitePress 1.6.4, Mermaid 11.16.1, `vitepress-plugin-mermaid` 2.0.17이다.
- `docs/.vitepress/config.mts`는 한국어를 루트 locale, 영어를 `/en/` locale로 구성하고 배포 base를 `/forge/docs/`로 설정한다. 절대 URL 기준은 같은 파일의 `SITE_URL`(`https://gyuha.com/forge/docs/`) 상수 하나로 파생되며, `sitemap.hostname`과 소셜 이미지 URL이 이를 공유한다.
- 사이트 공통 메타데이터는 `head` 배열(favicon, `theme-color`, `og:type`/`og:site_name`/`og:image` 계열, `twitter:card`)에, 페이지별 메타데이터는 `transformHead` 훅(`canonical`, `og:title`/`og:description`/`og:url`, `twitter:title`/`twitter:description`)에 있다. `transformHead`는 `index.md`를 디렉터리 경로로, 나머지를 `.html`로 변환해 URL을 만들고 404 페이지는 건너뛴다.
- `docs/public/`의 자산은 빌드 시 사이트 루트로 방출된다. 현재 `docs/public/icon.png`와 `docs/public/og-image.png`(1200×630 소셜 프리뷰 이미지)가 있으며 배포 후 `/forge/docs/` 아래에서 해결된다.
- `docs/index.html`은 VitePress 밖에서 제공되는 정적 랜딩 페이지다. 자체 `<head>`에 canonical·OG·Twitter 메타 태그를 하드코딩하며, 소셜 이미지는 VitePress가 방출하는 `/forge/docs/og-image.png`를 가리킨다(아티팩트 경계를 넘는 참조). 문서 빌드 결과는 `docs/.vitepress/dist/`에 생성되며 `.gitignore`로 제외된다.
- 루트 `package.json`에는 `type` 필드가 없다. 따라서 `scripts/*.js`는 CommonJS로 실행되고, VitePress 설정만 `.mts` 확장자로 ESM을 사용한다.

## 의존성 경계

- 플러그인의 스킬·상태 스크립트에는 npm 런타임 의존성이 없다. npm 패키지는 문서 사이트 빌드에만 사용된다.
- `skills/fg-showme/scripts/server.cjs`는 `http`, `crypto`, `fs`, `path`만으로 HTTP와 RFC 6455 WebSocket을 구현한다. 브라우저 자동 열기는 `child_process.execFile`로 OS 런처에 URL을 인자로 전달한다.
- `skills/fg-security/validate-findings.cjs`는 외부 JSON Schema 라이브러리 없이 `skills/fg-security/report-schema.json`의 필요한 부분집합을 검사한다.
- `scripts/forge-statusline-full.sh`는 `jq` 없이 JSON 입력을 방어적으로 파싱한다. 대응 파일 `scripts/forge-statusline-full.js`는 `JSON.parse`를 사용한다.
- `skills/fg-debug/scripts/hitl-loop.template.sh`, `skills/fg-security/`, `skills/fg-showme/`의 일부는 저장소 안에 라이선스와 함께 vendoring된 자산이다.

## 호스트 계약과 설정

- `core/HOST.md`가 호스트 선택 규칙과 capability 어휘를 소유한다. 현재 capability 키는 9개이며 `structured_choice`, `spawn_parallel`, `spawn_role`, `plugin_root`, `session_start`, `prevent_stop`, `project_agents`, `status_display`, `event_wake`다.
- 각 호스트는 `hosts/claude/`, `hosts/codex/`, `hosts/opencode/` 아래에 `interaction.md`, `execution.md`, `capabilities.json`을 한 벌씩 둔다.
- `hosts/claude/capabilities.json`은 9개 capability를 모두 `true`로 선언한다. `hosts/codex/capabilities.json`은 `spawn_parallel`, `plugin_root`, `session_start`만 `true`이고, `hosts/opencode/capabilities.json`은 모두 `false`다.
- 설치된 플러그인 경로는 셸 명령에서 `CLAUDE_PLUGIN_ROOT`와 `PLUGIN_ROOT`로 전달된다. 경로 우선순위와 텍스트 치환의 차이는 `core/HOST.md`에 구현 계약으로 기록돼 있다.
- 프로젝트별 Forge 설정은 `.forge/config.json`에 저장된다. 지원 키의 읽기·쓰기 진입점은 `skills/fg-config/SKILL.md`이며, 현재 저장소 설정은 `eco: false`만 명시한다.
- 상태줄 스크립트는 `FORGE_SL_SEP`, `FORGE_SL_DENSITY`, `FORGE_SL_PREFIX` 환경 변수로 출력 일부를 조정한다. 구현은 `scripts/forge-statusline.sh`, `scripts/forge-statusline.js`, `scripts/forge-statusline-full.sh`, `scripts/forge-statusline-full.js`에 있다.

## 빌드·검증 명령

| 명령 | 역할 | 구현 |
| --- | --- | --- |
| `npm run docs:dev` | VitePress 개발 서버 | `package.json` |
| `npm run docs:build` | 정적 문서 사이트 빌드와 내부 링크 검사 | `package.json`, `docs/.vitepress/config.mts` |
| `npm run docs:preview` | 빌드 결과 미리보기 | `package.json` |
| `npm run release:check` | 매니페스트·호스트 어댑터·capability 계약 검사 | `scripts/release-check.js` |
| `bash scripts/<name>.test.sh` | 개별 Bash 기반 동작 테스트 | `scripts/*.test.sh` |
| `bash scripts/<name>.parity.test.sh` | Bash와 Node 트윈의 출력·종료 코드·파일 결과 비교 | `scripts/*.parity.test.sh` |

- `scripts/`에는 동작 테스트와 패리티 테스트를 합쳐 20개의 `*.test.sh`가 있다. 훅 디스패처는 `hooks/run-hook.test.sh`와 `hooks/run-hook.windows.test.js`에서 별도로 검사한다.
- `skills/fg-loop/tests/resume-scenarios.md`는 `fg-loop` 재개 동작을 점검하는 Markdown 시나리오 모음이다.
- 중앙 테스트 러너나 범용 린터 설정은 없다. 각 테스트 스크립트와 문서 빌드, 릴리스 검사를 직접 실행한다.

## CI와 배포 도구

- `.github/workflows/docs.yml`은 Node.js 22에서 `npm ci`와 `npm run docs:build`를 실행하고 GitHub Pages 아티팩트를 조립한다.
- `.github/workflows/release-check.yml`은 Node.js 20에서 Bash·Node 릴리스 게이트와 패리티 테스트를 실행한다. 이 잡은 npm 패키지를 설치하지 않는다.
- `.gitattributes`는 `*.sh`를 LF로 고정해 Windows Git Bash에서도 shebang과 인자가 CRLF로 깨지지 않게 한다.
- `.gitignore`는 `node_modules/`, VitePress 캐시·빌드 결과, 휘발성 `.forge/` 상태를 제외하고 `.forge/CONTEXT.md`, `.forge/adr/`, `.forge/retro/`, `.forge/codebase/`, `.forge/config.json`, `.forge/branch/`를 다시 추적 대상으로 포함한다.
