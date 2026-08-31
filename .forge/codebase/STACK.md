---
last_mapped_commit: 182175fe02f832806c44148e7036d0dc26d7a55b
mapped: 2026-08-26
---

# STACK — 기술 스택

## 한 줄 요약

forge는 Claude Code **플러그인**이다. 산출물은 Markdown(스킬 문서)·JSON(매니페스트)이고, 결정론 로직만 bash + Node 트윈 스크립트로 존재한다. **플러그인 본체에는 여전히 빌드 시스템·의존성이 없다** — Makefile 없고, 스킬 Markdown·매니페스트 JSON을 빌드하는 단계도 없다. **예외는 문서 사이트 하나뿐**: 루트 `package.json`(VitePress)과 `.github/workflows/docs.yml`이 `docs/`를 GitHub Pages로 빌드·배포한다. 이 package.json은 **문서 도구이지 플러그인 빌드가 아니다**(ADR `260815-094725`).

## 언어·런타임

| 층 | 기술 | 위치 |
| --- | --- | --- |
| 스킬 본문 | Markdown (영문) | `skills/<name>/SKILL.md` × 22 + 동반 문서(`PLAN-FORMAT.md`, `FORGE-ROOT.md`, `HANDOFF.md`, `DRIVE.md`, `ECO.md`, `VISUAL.md` 등) |
| 매니페스트 | JSON | `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` |
| 결정론 스크립트 | bash (`#!/usr/bin/env bash`) — **주 경로** | `scripts/forge-*.sh`, `scripts/resolve-forge-root.sh` |
| 결정론 스크립트 | Node (CommonJS, `'use strict'`) — **폴백 트윈** | `scripts/forge-*.js`, `scripts/resolve-forge-root.js` (10개, 총 ~1,778줄) |
| 규율 데이터 파일 | plain text (마크다운 아님 — verbatim 대조용 단일 정의) | `scripts/explaining-forge.rule.txt` (1줄; `forge-doctor.sh`/`.js` 둘 다 런타임에 읽어 각 `SKILL.md`에 그 문단이 그대로 있는지 검사 — ADR `260824-134246`) |
| 훅 디스패처 | bash/cmd polyglot (한 파일이 batch+shell 겸용) | `hooks/run-hook.cmd` |
| 보안 감사 검증기 | Node CommonJS zero-dependency (`.cjs`, JSON Schema 부분집합을 직접 해석) | `skills/fg-security/validate-findings.cjs` + `skills/fg-security/report-schema.json` (vendored, 원형 유지) |
| 시각 컴패니언 서버 | Node zero-dependency (내장 모듈 `http`/`crypto`/`fs`/`path`/`child_process`만, WebSocket RFC 6455 직접 구현) | `skills/fg-showme/scripts/server.cjs` (+`helper.js`, `start-server.sh`, `stop-server.sh`, `frame-template.html`) |
| 문서 사이트 | VitePress 1.x + `vitepress-plugin-mermaid` + `mermaid` 11.x (설정은 TypeScript ESM) | `docs/.vitepress/config.mts`, 소스는 `docs/*.md`(한글 = root locale) ↔ `docs/en/*.md`(영문) 7쌍, `base: '/forge/docs/'` |
| 랜딩 페이지 | 정적 단일 HTML (KO/EN `data-l` span 토글) | `docs/index.html` (VitePress 밖 — 워크플로가 아티팩트 루트로 따로 복사) |

## 스크립트 트윈 패턴 (ADR-0022)

모든 결정론 기계는 `.sh`/`.js` 쌍으로 존재하고 출력·exit code가 byte-identical해야 한다:

- 쌍(10): `forge-status`, `forge-done`, `forge-merge`, `forge-doctor`, `forge-hook-session-start`, **`forge-hook-stop`**, **`forge-loop-spend`**, `forge-statusline`, `forge-statusline-full`, `resolve-forge-root` (예: `scripts/forge-status.sh` ↔ `scripts/forge-status.js`)
- `forge-statusline-wrapper.sh`는 bash 전용(트윈 없음 — append 모드 래퍼).
- `.js` 트윈은 다른 `.js`를 `require`로 재사용한다 (`scripts/forge-status.js`가 `./resolve-forge-root.js`를 require).
- 외부 의존 없음: 스크립트는 jq-free(`scripts/forge-statusline-full.sh` 주석 "jq-free (defensive sed)"), git+bash 또는 node만 요구.
- **패리티는 복붙이 아니라 교차 검증**(ADR-0022 개정 2026-08-20): `forge-hook-stop`은 bash가 원시 텍스트를 grep/sed하고 node가 구조를 파싱해 **다른 경로로 같은 판정**에 도달하도록 의도적으로 갈라 두었다(`scripts/forge-hook-stop.sh` 헤더 주석).
- 두 신규 쌍의 계약은 **exit code**다 — `scripts/forge-hook-stop.sh`는 Stop 훅 규약(`2` = 정지 차단·stderr가 메시지, `0` = 정지 허용, 실패·모호한 경로는 전부 `0`으로 fail-safe), `scripts/forge-loop-spend.sh`는 예산 판정(`0` OK/NONE · `2` no-loop-md · `3` EXHAUSTED · `4` PREFLIGHT-HALT · `5` BLOCKED · `64` usage error).

## 테스트 (자체 제작 bash 하니스)

테스트 프레임워크 없음. 각 스크립트에 두 종류의 bash 테스트가 붙는다:

- **behavior**: `scripts/forge-<name>.test.sh` — mktemp 샌드박스에 상태를 seed하고 출력/exit code 검증
- **parity**: `scripts/forge-<name>.parity.test.sh` — 같은 입력에 대해 sh↔js가 동일 결과(파일 변이 스크립트는 결과 `.forge/` 트리까지 비교, `scripts/forge-done.parity.test.sh` 참조)
- 신규 두 쌍도 같은 하니스: `scripts/forge-hook-stop.test.sh`/`.parity.test.sh`, `scripts/forge-loop-spend.test.sh`/`.parity.test.sh`. 둘 다 시간·경로를 주입해 결정론을 확보한다 — 훅은 `--now <epoch>`, spend는 `--transcripts DIR`/`--now ISO`.
- 훅 래퍼도 자체 테스트: `hooks/run-hook.test.sh`
- 실행은 `bash scripts/<file>.test.sh` 직접 호출 (러너 없음)

문서 사이트만 별도 검증 경로를 갖는다: `npm run docs:build`(VitePress dead-link 검사가 빌드 실패로 드러난다). 플러그인 본체에는 여전히 단위 테스트가 없고 검증은 설치 실측뿐이다.

## 설정

- **플러그인 버전은 3곳 동기**: `plugin.json`의 `version`, `marketplace.json`의 `metadata.version`과 `plugins[0].version` (현재 0.6.16).
- 사용자 프로젝트 측 영속 설정: `.forge/config.json` (`tdd`, `eco`, `defaultBranch` 키 — 이 리포 자체의 것은 `{"eco": false}`).
- **루트 `package.json`에 `"type"` 필드를 넣으면 안 된다** — `name: "forge-docs"`, `private: true`, `scripts`는 `docs:dev`/`docs:build`/`docs:preview` 셋뿐이고 devDependencies는 `vitepress`·`mermaid`·`vitepress-plugin-mermaid`. `scripts/*.js` 트윈 10개가 CommonJS(`require`)라 `"type": "module"`이면 리포 전체 `.js`가 ESM으로 해석돼 전부 죽는다. VitePress 설정은 `.mts` 확장자만으로 이미 ESM이라 이 필드가 필요 없다 (ADR `260815-094725`).
- `.gitignore`: `.forge/*` 기본 제외 + 영속 문서 화이트리스트(`!.forge/CONTEXT.md`, `!.forge/adr/`, `!.forge/retro/`, `!.forge/codebase/`, `!.forge/config.json`, `!.forge/branch/`). 문서 사이트 몫으로 `node_modules/`·`docs/.vitepress/dist/`·`docs/.vitepress/cache/`가 추가됐다(문서 소스 `docs/*.md`와 `package-lock.json`은 추적).
- `.gitattributes`: `*.sh text eol=lf` — Windows git-bash에서 `.sh`가 CRLF로 깨지지 않게 하는 load-bearing 가드.
- 검증 수단: `node -e "JSON.parse(...)"` 매니페스트 유효성 한 줄, 문서 편집 시 `npm run docs:build`, 그리고 설치 실측(`/plugin install`).

## 스킬 탐색 규약

- 스킬은 `skills/<dir>/SKILL.md`로 자동 탐색되며 식별자는 frontmatter `name`(디렉터리명 아님). 매니페스트에 `skills` 필드 없음. 현재 22개.
- 훅도 `hooks/hooks.json` 자동 탐색(매니페스트 미등록). **이제 두 개** — `SessionStart`와 `Stop`(상세는 INTEGRATIONS.md §1).
- `skills/fg-security/`는 vendored 파일 12개(9개 플레이북 Markdown + `LICENSE` + `report-schema.json` + `validate-findings.cjs`)를 **원형 그대로** 두고, 진입 파일만 `AUDIT.md`로 개명해 forge 자동 탐색과 충돌하지 않게 했다. forge 자신의 글루는 `skills/fg-security/SKILL.md` 하나뿐이다.
