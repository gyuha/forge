---
last_mapped_commit: 524c6a3ee40d28bcd90334a9e4f9ca0135fca088
mapped: 2026-09-03
---

# STACK — 기술 스택

## 한 줄 요약

forge는 **두 에이전트 호스트(Claude Code + Codex)용 플러그인**이다 — 더 이상 Claude Code 전용이 아니다. 산출물은 Markdown(스킬 문서)·JSON(매니페스트)이고, 결정론 로직만 bash + Node 트윈 스크립트로 존재한다. **플러그인 본체에는 여전히 빌드 시스템·의존성이 없다** — Makefile 없고, 스킬 Markdown·매니페스트 JSON을 빌드하는 단계도 없다. **예외는 문서 사이트 하나뿐**: 루트 `package.json`(VitePress)과 `.github/workflows/docs.yml`이 `docs/`를 GitHub Pages로 빌드·배포한다. 이 package.json은 **문서 도구이지 플러그인 빌드가 아니다**(ADR `260815-094725`) — 다만 이제 `release:check`라는 **비-VitePress 스크립트 하나**가 이 package.json에 얹혀 있다(아래 "릴리스 게이트").

## 언어·런타임

| 층 | 기술 | 위치 |
| --- | --- | --- |
| 스킬 본문 | Markdown (영문) | `skills/<name>/SKILL.md` × 22 + 동반 문서(`PLAN-FORMAT.md`, `FORGE-ROOT.md`, `HANDOFF.md`, `DRIVE.md`, `ECO.md`, `VISUAL.md` 등) |
| 매니페스트 | JSON | `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, **`.codex-plugin/plugin.json`** |
| 호스트 중립 계약 | Markdown (영문, 짧음) | `core/HOST.md`(어댑터 선택 규칙 + 8능력 표), `core/EXECUTION.md`, `core/INTERACTION.md` |
| 호스트 어댑터 | Markdown ×2 + JSON ×1 (호스트마다) | `hosts/claude/{interaction.md,execution.md,capabilities.json}`, `hosts/codex/{...}` |
| 결정론 스크립트 | bash (`#!/usr/bin/env bash`) — **주 경로** | `scripts/forge-*.sh`, `scripts/resolve-forge-root.sh`, `scripts/release-check.sh` |
| 결정론 스크립트 | Node (CommonJS, `'use strict'`) — **폴백 트윈** | `scripts/forge-*.js`, `scripts/resolve-forge-root.js`, `scripts/release-check.js` (11개, 총 ~1,814줄) |
| 규율 데이터 파일 | plain text (마크다운 아님 — verbatim 대조용 단일 정의) | `scripts/explaining-forge.rule.txt` (1줄; `forge-doctor.sh`/`.js` 둘 다 런타임에 읽어 각 `SKILL.md`에 그 문단이 그대로 있는지 검사 — ADR `260824-134246`) |
| 훅 디스패처 | bash/cmd polyglot (한 파일이 batch+shell 겸용) | `hooks/run-hook.cmd` |
| 보안 감사 검증기 | Node CommonJS zero-dependency (`.cjs`, JSON Schema 부분집합을 직접 해석) | `skills/fg-security/validate-findings.cjs` + `skills/fg-security/report-schema.json` (vendored, 원형 유지) |
| 시각 컴패니언 서버 | Node zero-dependency (내장 모듈 `http`/`crypto`/`fs`/`path`/`child_process`만, WebSocket RFC 6455 직접 구현) | `skills/fg-showme/scripts/server.cjs` (+`helper.js`, `start-server.sh`, `stop-server.sh`, `frame-template.html`) |
| 문서 사이트 | VitePress 1.x + `vitepress-plugin-mermaid` + `mermaid` 11.x (설정은 TypeScript ESM) | `docs/.vitepress/config.mts`, 소스는 `docs/*.md`(한글 = root locale) ↔ `docs/en/*.md`(영문) **8쌍**(`codex.md` 추가 — 사이드바 「가이드/Guides」 첫 항목), `base: '/forge/docs/'` |
| 랜딩 페이지 | 정적 단일 HTML (KO/EN `data-l` span 토글) | `docs/index.html` (VitePress 밖 — 워크플로가 아티팩트 루트로 따로 복사) |

## 이중 호스트 경계 (`core/` + `hosts/`)

호스트 지원이 스킬 본문으로 번지지 않게 하는 얇은 경계다 — 스킬·스크립트·`.forge/` 상태는 **한 벌만** 존재하고, 호스트마다 다른 부분만 여기 산다(스킬을 Codex용으로 복제하지 않는다).

- `core/HOST.md` — 어댑터 선택 규칙(명시적 호스트 메타데이터 우선 → `PLUGIN_ROOT`=Codex → `CLAUDE_PLUGIN_ROOT`=Claude Code → 식별 불가면 **순차 폴백**: 평문 질문·역할 위임 없음·호스트 UI 변경 없음)과 **8능력 표**(단일 어휘). 셸에서 플러그인 루트는 `FORGE_PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"`로 정규화한다.
- `core/EXECUTION.md` — 선택·승격·의존성 분류·결과 수집·UAT·`run.md`는 공유 스킬이 소유하고, 어댑터는 **위임만** 소유한다. 위임 불가면 의미를 바꾸지 않고 직렬 실행.
- `core/INTERACTION.md` — 한 번에 한 질문. 구조화 선택 도구가 있고 옵션 수가 맞으면 그것, 아니면 번호 목록. 확인 게이트·기본값은 호스트 간 동일.
- `hosts/<host>/capabilities.json` — 표의 8개 키 **정확히 그대로**(`structured_choice`·`spawn_parallel`·`spawn_role`·`plugin_root`·`session_start`·`prevent_stop`·`project_agents`·`status_display`). 값은 **관측된 것만 `true`**이고 미확인은 `false`가 기본(모든 능력에 정의된 폴백이 있어 "도는 폴백"이 "없는 도구 호출"보다 싸다). 현재 Claude는 8개 전부 `true`, Codex는 `spawn_parallel`·`plugin_root`·`session_start`만 `true`. **이 JSON과 `docs/codex.md`의 지원 표는 같은 주장의 두 형태라 항상 함께 갱신한다.**
- `hosts/claude/execution.md`는 Dynamic Workflow + 병렬 `agent()` + `agentType`, `hosts/codex/execution.md`는 Codex collaboration/subagent 도구(없으면 직렬). `interaction.md`는 각각 `AskUserQuestion`(최대 4옵션)과 Codex 모드의 입력 facility(도구 이름을 발명하지 않음).

## 릴리스 게이트 (`npm run release:check`)

`scripts/release-check.sh`/`.js` 트윈이 배포 전 5가지를 검사한다(exit 0 = ok, 1 = 위반, 위반은 stderr 한 줄씩):

1. **매니페스트 버전 4곳 동기** — `.claude-plugin/plugin.json`의 `version`, `.claude-plugin/marketplace.json`의 `metadata.version`·`plugins[0].version`, **`.codex-plugin/plugin.json`의 `version`**. 리더는 forge-doctor B8과 같은 방식(정규식으로 문서 순서대로 `"version"` 값 추출 — JSON 파서 아님).
2. **Codex 매니페스트의 `skills` 필드가 `"./skills/"`** — 두 호스트가 같은 스킬 트리를 로드한다는 계약.
3. **기본 훅 파일 존재** — `hooks/hooks.json`.
4. **어댑터 완전성** — `hosts/{claude,codex}/{interaction.md,execution.md,capabilities.json}` 6파일 전부.
5. 매니페스트 3개 중 하나라도 없으면 즉시 exit 1.

`package.json`의 `scripts.release:check`는 **node 트윈**(`node scripts/release-check.js`)을 부른다 — npm 경로라 bash를 전제하지 않는 쪽을 골랐다. CI에는 아직 안 걸려 있다(`.github/workflows/docs.yml`은 문서 전용).

## 스크립트 트윈 패턴 (ADR-0022)

모든 결정론 기계는 `.sh`/`.js` 쌍으로 존재하고 출력·exit code가 byte-identical해야 한다:

- 쌍(11): `forge-status`, `forge-done`, `forge-merge`, `forge-doctor`, `forge-hook-session-start`, `forge-hook-stop`, `forge-loop-spend`, `forge-statusline`, `forge-statusline-full`, `resolve-forge-root`, **`release-check`** (예: `scripts/forge-status.sh` ↔ `scripts/forge-status.js`). `release-check`만 `forge-` 접두가 없다 — 루프 상태 기계가 아니라 리포 릴리스 도구라서.
- `forge-statusline-wrapper.sh`는 bash 전용(트윈 없음 — append 모드 래퍼).
- `.js` 트윈은 다른 `.js`를 `require`로 재사용한다 (`scripts/forge-status.js`가 `./resolve-forge-root.js`를 require).
- 외부 의존 없음: 스크립트는 jq-free(`scripts/forge-statusline-full.sh` 주석 "jq-free (defensive sed)"), git+bash 또는 node만 요구.
- **패리티는 복붙이 아니라 교차 검증**(ADR-0022 개정 2026-08-20): `forge-hook-stop`은 bash가 원시 텍스트를 grep/sed하고 node가 구조를 파싱해 **다른 경로로 같은 판정**에 도달하도록 의도적으로 갈라 두었다(`scripts/forge-hook-stop.sh` 헤더 주석).
- 두 신규 쌍의 계약은 **exit code**다 — `scripts/forge-hook-stop.sh`는 Stop 훅 규약(`2` = 정지 차단·stderr가 메시지, `0` = 정지 허용, 실패·모호한 경로는 전부 `0`으로 fail-safe), `scripts/forge-loop-spend.sh`는 예산 판정(`0` OK/NONE · `2` no-loop-md · `3` EXHAUSTED · `4` PREFLIGHT-HALT · `5` BLOCKED · `64` usage error).

## 테스트 (자체 제작 bash 하니스)

테스트 프레임워크 없음. 각 스크립트에 두 종류의 bash 테스트가 붙는다:

- **behavior**: `scripts/forge-<name>.test.sh` — mktemp 샌드박스에 상태를 seed하고 출력/exit code 검증
- **parity**: `scripts/forge-<name>.parity.test.sh` — 같은 입력에 대해 sh↔js가 동일 결과(파일 변이 스크립트는 결과 `.forge/` 트리까지 비교, `scripts/forge-done.parity.test.sh` 참조)
- `forge-hook-stop`·`forge-loop-spend`도 같은 하니스: `scripts/forge-hook-stop.test.sh`/`.parity.test.sh`, `scripts/forge-loop-spend.test.sh`/`.parity.test.sh`. 둘 다 시간·경로를 주입해 결정론을 확보한다 — 훅은 `--now <epoch>`, spend는 `--transcripts DIR`/`--now ISO`.
- **`release-check`만 behavior 테스트 파일이 없다** — `scripts/release-check.parity.test.sh`만 있고 `.test.sh`는 없다. 다만 그 parity 테스트가 mktemp에 **버려지는 가짜 리포**(두 스크립트를 그 리포의 `scripts/`에 복사 — 스크립트가 자기 위치로 리포 루트를 잡으므로)를 케이스마다 조립하고 각 케이스가 sentinel 부분문자열까지 단정하므로, 실질적으로 behavior까지 덮는다. `set -euo pipefail`이 걸려 있어 "둘 다 아무것도 안 냈으니 같다"가 통과로 새지 않는다.
- 훅 래퍼도 자체 테스트: `hooks/run-hook.test.sh`
- 실행은 `bash scripts/<file>.test.sh` 직접 호출 (러너 없음)

문서 사이트만 별도 검증 경로를 갖는다: `npm run docs:build`(VitePress dead-link 검사가 빌드 실패로 드러난다). 플러그인 본체에는 여전히 단위 테스트가 없고 검증은 설치 실측뿐이다.

## 설정

- **플러그인 버전은 이제 4곳 동기**(종전 3곳): `.claude-plugin/plugin.json`의 `version`, `.claude-plugin/marketplace.json`의 `metadata.version`과 `plugins[0].version`, **`.codex-plugin/plugin.json`의 `version`** (현재 0.8.0). 검사 지점도 둘 — `scripts/release-check.sh`/`.js`와 `forge-doctor`의 **B8**(둘 다 4-way), 그리고 `forge-doctor` **B9**가 Codex 매니페스트까지 JSON 유효성을 검사한다(존재할 때만 — `existsSync` 가드).
- 사용자 프로젝트 측 영속 설정: `.forge/config.json`. 스크립트가 실제로 읽는 키는 `eco`와 `defaultBranch` 둘이고, `tdd`·`driveCommit`·`driveCommitMessage`는 스킬 지시문 층에서만 소비된다. 이 리포 자체의 것은 `{"eco": false}`.
- **루트 `package.json`에 `"type"` 필드를 넣으면 안 된다** — `name: "forge-docs"`, `private: true`, `scripts`는 `release:check`/`docs:dev`/`docs:build`/`docs:preview` 넷이고 devDependencies는 `vitepress`·`mermaid`·`vitepress-plugin-mermaid`. `scripts/*.js` 트윈 11개가 CommonJS(`require`)라 `"type": "module"`이면 리포 전체 `.js`가 ESM으로 해석돼 전부 죽는다(`release:check`가 node 트윈을 부르므로 이제 릴리스 게이트 자신도 같이 죽는다). VitePress 설정은 `.mts` 확장자만으로 이미 ESM이라 이 필드가 필요 없다 (ADR `260815-094725`).
- `.gitignore`: `.forge/*` 기본 제외 + 영속 문서 화이트리스트(`!.forge/CONTEXT.md`, `!.forge/adr/`, `!.forge/retro/`, `!.forge/codebase/`, `!.forge/config.json`, `!.forge/branch/`). 문서 사이트 몫으로 `node_modules/`·`docs/.vitepress/dist/`·`docs/.vitepress/cache/`가 추가됐다(문서 소스 `docs/*.md`와 `package-lock.json`은 추적).
- `.gitattributes`: `*.sh text eol=lf` — Windows git-bash에서 `.sh`가 CRLF로 깨지지 않게 하는 load-bearing 가드.
- 검증 수단: `node -e "JSON.parse(...)"` 매니페스트 유효성 한 줄, 배포 전 `npm run release:check`, 문서 편집 시 `npm run docs:build`, 그리고 설치 실측(`/plugin install`).

## 스킬 탐색 규약

- 스킬은 `skills/<dir>/SKILL.md`로 자동 탐색되며 식별자는 frontmatter `name`(디렉터리명 아님). 현재 22개. **Claude 매니페스트에는 `skills` 필드가 없고(자동 탐색), Codex 매니페스트는 `"skills": "./skills/"`로 명시**해 같은 트리를 가리킨다 — 이 값은 `release:check`가 고정으로 검사한다.
- `.codex-plugin/plugin.json`은 Claude 매니페스트에 없는 `interface` 블록(`displayName`·`shortDescription`·`longDescription`·`category`·`capabilities: ["Interactive","Write"]`·`websiteURL`·`defaultPrompt` 3개·`brandColor: "#D97757"`)을 갖는다. 설명 문구도 Claude 쪽처럼 전체 스킬 목록을 담지 않고 짧다 — 두 매니페스트가 같은 값을 갖는 것은 `version`뿐이다.
- 훅도 `hooks/hooks.json` 자동 탐색(매니페스트 미등록). **두 개** — `SessionStart`와 `Stop`. 커맨드의 플러그인 루트 해석이 `"${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}"`로 **Codex 우선·Claude 폴백**이 됐다(상세는 INTEGRATIONS.md §1).
- `skills/fg-security/`는 vendored 파일 12개(9개 플레이북 Markdown + `LICENSE` + `report-schema.json` + `validate-findings.cjs`)를 **원형 그대로** 두고, 진입 파일만 `AUDIT.md`로 개명해 forge 자동 탐색과 충돌하지 않게 했다. forge 자신의 글루는 `skills/fg-security/SKILL.md` 하나뿐이다.
