---
last_mapped_commit: 48899bdb6b04ad575767885a7c741cb2a09bd9d0
mapped: 2026-08-10
---

# STACK — 기술 스택

## 한 줄 요약

forge는 Claude Code **플러그인**이다. 산출물은 Markdown(스킬 문서)·JSON(매니페스트)이고, 결정론 로직만 bash + Node 트윈 스크립트로 존재한다. **빌드 시스템·패키지 매니저·의존성이 전혀 없다** — package.json, Makefile, CI, node_modules 없음.

## 언어·런타임

| 층 | 기술 | 위치 |
| --- | --- | --- |
| 스킬 본문 | Markdown (영문) | `skills/<name>/SKILL.md` × 20 + 동반 문서(`PLAN-FORMAT.md`, `FORGE-ROOT.md`, `HANDOFF.md`, `ECO.md`, `VISUAL.md` 등) |
| 매니페스트 | JSON | `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` |
| 결정론 스크립트 | bash (`#!/usr/bin/env bash`) — **주 경로** | `scripts/forge-*.sh`, `scripts/resolve-forge-root.sh` |
| 결정론 스크립트 | Node (CommonJS, `'use strict'`) — **폴백 트윈** | `scripts/forge-*.js`, `scripts/resolve-forge-root.js` (총 ~1,466줄) |
| 훅 디스패처 | bash/cmd polyglot (한 파일이 batch+shell 겸용) | `hooks/run-hook.cmd` |
| 시각 컴패니언 서버 | Node zero-dependency (내장 모듈 `http`/`crypto`/`fs`/`path`/`child_process`만, WebSocket RFC 6455 직접 구현) | `skills/fg-visual/scripts/server.cjs` (+`helper.js`, `start-server.sh`, `stop-server.sh`, `frame-template.html`) |
| 랜딩 페이지 | 정적 단일 HTML (KO/EN `data-l` span 토글) | `docs/index.html` |

## 스크립트 트윈 패턴 (ADR-0022)

모든 결정론 기계는 `.sh`/`.js` 쌍으로 존재하고 출력·exit code가 byte-identical해야 한다:

- 쌍: `forge-status`, `forge-done`, `forge-merge`, `forge-doctor`, `forge-hook-session-start`, `forge-statusline`, `forge-statusline-full`, `resolve-forge-root` (예: `scripts/forge-status.sh` ↔ `scripts/forge-status.js`)
- `forge-statusline-wrapper.sh`는 bash 전용(트윈 없음 — append 모드 래퍼).
- `.js` 트윈은 다른 `.js`를 `require`로 재사용한다 (`scripts/forge-status.js`가 `./resolve-forge-root.js`를 require).
- 외부 의존 없음: 스크립트는 jq-free(`scripts/forge-statusline-full.sh` 주석 "jq-free (defensive sed)"), git+bash 또는 node만 요구.

## 테스트 (자체 제작 bash 하니스)

테스트 프레임워크 없음. 각 스크립트에 두 종류의 bash 테스트가 붙는다:

- **behavior**: `scripts/forge-<name>.test.sh` — mktemp 샌드박스에 상태를 seed하고 출력/exit code 검증
- **parity**: `scripts/forge-<name>.parity.test.sh` — 같은 입력에 대해 sh↔js가 동일 결과(파일 변이 스크립트는 결과 `.forge/` 트리까지 비교, `scripts/forge-done.parity.test.sh` 참조)
- 훅 래퍼도 자체 테스트: `hooks/run-hook.test.sh`
- 실행은 `bash scripts/<file>.test.sh` 직접 호출 (러너 없음)

## 설정

- **플러그인 버전은 3곳 동기**: `plugin.json`의 `version`, `marketplace.json`의 `metadata.version`과 `plugins[0].version` (현재 0.6.6).
- 사용자 프로젝트 측 영속 설정: `.forge/config.json` (`tdd`, `eco`, `defaultBranch` 키 — 이 리포 자체의 것은 `{"eco": false}`).
- `.gitignore`: `.forge/*` 기본 제외 + 영속 문서 화이트리스트(`!.forge/CONTEXT.md`, `!.forge/adr/`, `!.forge/retro/`, `!.forge/codebase/`, `!.forge/config.json`, `!.forge/branch/`).
- `.gitattributes`: `*.sh text eol=lf` — Windows git-bash에서 `.sh`가 CRLF로 깨지지 않게 하는 load-bearing 가드.
- 검증 유일 수단: `node -e "JSON.parse(...)"` 매니페스트 유효성 한 줄 + 설치 실측(`/plugin install`).

## 스킬 탐색 규약

- 스킬은 `skills/<dir>/SKILL.md`로 자동 탐색되며 식별자는 frontmatter `name`(디렉터리명 아님). 매니페스트에 `skills` 필드 없음.
- 훅도 `hooks/hooks.json` 자동 탐색(매니페스트 미등록).
