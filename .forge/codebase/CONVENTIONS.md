---
last_mapped_commit: 6146cae539151b65850e1e2609bdf8f7e78a1e47
mapped: 2026-09-11
---

# CONVENTIONS

이 문서는 현재 작업 트리에서 확인한 구현 규약만 기록한다.

## 저장소 산출물

- 플러그인의 주 산출물은 `skills/*/SKILL.md`, 그 형제 Markdown 계약 문서, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`이다. `skills/` 아래에는 `SKILL.md`가 22개 있다.
- 결정론적 동작은 최상위 `scripts/`에 둔다. 운영 스크립트는 Bash/Node 트윈 11쌍이며, `scripts/forge-statusline-wrapper.sh`만 최상위 Bash 전용 구현이다.
- `package.json`은 `docs/`의 VitePress 사이트와 릴리스 검사 명령을 제공한다. 플러그인 Markdown이나 JSON을 컴파일하는 빌드 단계는 없다.
- `package.json`에는 `"type"` 필드가 없다. `scripts/*.js`는 `require(...)`를 사용하는 CommonJS이며 파일 시작에 `'use strict';`를 둔다.

## 스킬과 계약 문서

- 스킬은 `skills/fg-<이름>/SKILL.md` 형태로 배치하며, 식별자는 디렉터리명이 아니라 YAML frontmatter의 `name`이다.
- `SKILL.md`의 `description`은 한 줄 값이다. `scripts/forge-doctor.sh`와 `scripts/forge-doctor.js`는 누락된 `name`, 600자를 넘는 `description`, folded-scalar 형태를 검사한다.
- 스킬 본문과 `skills/fg-ask/ADR-FORMAT.md`, `skills/fg-ask/CONTEXT-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-learn/RETRO-FORMAT.md`는 영문으로 작성된다. 사용자에게 표시하는 문구와 프로젝트 산출물은 사용자의 언어로 렌더하도록 각 스킬이 지시한다.
- 모든 `skills/*/SKILL.md`는 `scripts/explaining-forge.rule.txt`의 표준 문단을 포함한다. `skills/fg-ask/SKILL.md`는 원본 본문과 Forge 연결 절을 분리한 상위집합 형태다.
- 공유 계약은 소유 파일 하나에 두고 다른 스킬에서 경로로 참조한다. 실제 공유 파일은 `core/HOST.md`, `core/EXECUTION.md`, `core/INTERACTION.md`, `skills/fg-run/FORGE-ROOT.md`, `skills/fg-next/DRIVE.md`, `skills/fg-next/HANDOFF.md`, `skills/fg-config/ECO.md`다.
- 조건부로 읽는 동반 문서는 `skills/fg-run/RUN-ALL.md`, `skills/fg-run/RECOVERY.md`, `skills/fg-next/ALL-MODE.md`, `skills/fg-loop/INQUIRY.md`처럼 소유 스킬과 함께 둔다. 조건부 분할 시 조건 밖에서도 필요한 하위 절을 본문에 남기도록 `CLAUDE.md`가 규정한다.
- `CLAUDE.md`는 그 조건부 분할의 판정 단위를 헤딩이 아니라 **문단**(빈 줄로 구분된 최상위 블록, 코드펜스 1단위·목록 최상위 항목별·blockquote 머리말 1단위)으로 규정하고, 검증을 두 단계 체크리스트로 요구한다 — 남는 문서와 옮긴 문서 양쪽의 상호참조(`§N`·"above"·절 이름)를 모두 열거한 뒤, 가리키는 내용이 그 절에 실재하는지 확인한다.
- 위 체크리스트의 기계로 잡히는 절반은 `scripts/forge-doctor.sh`·`.js`의 검사 B21이다. `skills/*/SKILL.md`에서 섹션 N 안에 있는 `§N` 인용을 warning으로 보고하며, `§12`처럼 숫자가 이어지는 경우는 제외한다. 의미 판단이 필요한 나머지 절반(대상 절이 남아 있지만 규칙이 사라진 경우)은 계속 산문 규약이 소유한다.
- 스킬 문서의 흐름과 분기는 Mermaid가 아니라 텍스트 화살표와 들여쓰기로 표현한다. 둘 이상의 결과를 기술할 때는 같은 문단에 판정 기준도 둔다.
- 다음 단계가 있는 스킬의 출력 표 형식은 `skills/fg-next/HANDOFF.md`가 소유한다. 다른 스킬은 그 파일을 참조하며 표 정의를 복사하지 않는다.

## Markdown과 사용자 문서

- `README.md`와 `README.ko.md`는 영문/한글 번역 쌍으로 함께 변경한다.
- `docs/*.md`의 한국어 문서와 `docs/en/*.md`의 영문 문서는 10쌍이며, 대응 문서의 `##` 절 순서와 표의 행·열 구조를 맞춘다.
- `docs/index.html`은 한 파일 안에서 `data-l="ko"`와 `data-l="en"` 요소를 짝지어 관리한다.
- `docs/.vitepress/config.mts`는 TypeScript ESM 문법과 작은따옴표를 사용하며, 한국어/영문 sidebar와 locale 구성을 별도 상수와 객체로 둔다.
- 스킬의 영속 문서 형식은 소유 파일을 따른다. 계획은 `skills/fg-run/PLAN-FORMAT.md`, 회고는 `skills/fg-learn/RETRO-FORMAT.md`, ADR과 컨텍스트는 `skills/fg-ask/*-FORMAT.md`가 형식을 정의한다.

## Bash 구현

- 최상위 운영 셸 파일은 `#!/usr/bin/env bash`와 `set -u`를 사용한다. 명령 실패를 자동 전파하는 전역 `set -e` 대신 분기별 exit code와 조건문으로 실패를 처리한다.
- 운영 스크립트는 절을 `# --- ... ---` 주석으로 나누고, 파일 머리말에 목적·사용법·출력 또는 exit-code 계약을 기록한다. 예시는 `scripts/forge-done.sh`, `scripts/forge-status.sh`, `scripts/forge-hook-stop.sh`다.
- 함수와 지역 변수는 `snake_case`를 쓴다. 상한처럼 파일 전역의 고정값은 `MAX_AGE`, `MAX_BLOCKED`, `DONE_ROWS`처럼 대문자를 쓴다.
- 경로와 사용자/저장소 값은 큰따옴표로 감싼다. 빈 글롭을 순회할 때 `[ -e "$f" ] || continue` 또는 `[ -d "$dir" ] || continue`로 실제 항목 여부를 확인한다.
- 임시 작업은 `mktemp -d` 또는 대상 옆의 PID 접미 임시 파일을 사용한다. 상태 변경 스크립트는 검증을 먼저 수행하고, 임시 파일·복사본을 준비한 뒤 rename/move하며, 실패 시 원본을 보존하거나 복원한다. `scripts/forge-done.sh`와 `scripts/forge-hook-stop.sh`가 이 형태를 사용한다.
- `.forge/` 위치는 직접 가정하지 않고 `scripts/resolve-forge-root.sh`를 호출한다. 저장소 하위 디렉터리에서도 git 최상위에 고정하며, 비기본 브랜치에서는 브랜치별 경로를 반환한다.
- 상태 필드 파서는 일반 `field:`와 과거의 `- field:` 형태 및 CRLF를 함께 처리한다. 판정 전에 대소문자와 뒤 설명을 정규화하는 함수가 `scripts/forge-status.sh`, `scripts/forge-done.sh` 등에 있다.
- 기계가 소비하는 stdout, stderr, exit code는 공개 계약으로 취급한다. 예를 들어 `scripts/forge-hook-stop.sh`는 허용 경로를 exit 0·무출력으로 끝내고, 유효한 계속 경로만 stderr 지시문과 exit 2를 낸다.
- Bash 호출은 실행 비트에 기대지 않고 `bash scripts/<파일>.sh` 형태를 사용한다. 예외인 `hooks/run-hook.cmd`는 Unix에서 직접 실행되므로 실행 비트를 유지한다.
- macOS 기본 BSD 구현과 GNU 구현이 갈리는 기능은 피하고, 피한 이유를 코드 주석에 남긴다. `scripts/forge-doctor.sh`의 B21은 BSD `awk`에 3-인자 `match()`가 없어 조용히 0건을 보고했던 사실을 주석에 적고 `grep`과 셸 산술로 구현했다.
- `.gitattributes`는 경로 전체의 `*.sh`를 LF로 고정한다.

## Node 구현

- 최상위 `scripts/*.js` 트윈은 `fs`, `path`, `child_process` 같은 Node 내장 모듈만 사용한다. 대응 Bash 파일과 외부 의존성 없이 실행된다.
- 변수와 함수는 `camelCase`, 파일 전역 상수는 `UPPER_SNAKE_CASE`를 쓴다. `const`를 기본으로 사용하고 재할당이 필요한 값만 `let`으로 둔다.
- 파일 읽기·존재 확인처럼 정상적인 부재가 가능한 동작은 작은 helper가 예외를 잡아 빈 값이나 false로 변환한다. 계약 위반은 메시지를 쓴 뒤 명시적 `process.exit(code)`로 끝낸다.
- Bash/Node 트윈은 구현 방법까지 동일할 필요는 없지만, 동일 입력에 대해 stdout·stderr·exit code와 파일 변경 결과가 같아야 한다. `scripts/forge-loop-spend.sh`의 원문 필터와 `scripts/forge-loop-spend.js`의 구조 파싱처럼 독립 구현을 유지하는 경우도 있다.
- 공유되는 Node 로직은 `scripts/resolve-forge-root.js`에서 `resolveForgeRoot`를 export하는 방식처럼 CommonJS export로 재사용한다.

## JSON, 경로, 이름

- JSON 매니페스트는 2칸 들여쓰기를 사용한다. `.codex-plugin/plugin.json`의 짧은 배열은 한 줄로 쓰기도 하며, 유효 JSON과 필드 계약이 우선이다.
- 플러그인 버전은 `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`의 두 위치, `.codex-plugin/plugin.json`의 총 네 값에 동기화한다.
- 호스트 공통 계약 파일은 `core/HOST.md`, `core/EXECUTION.md`, `core/INTERACTION.md`처럼 대문자이며, 호스트별 구현은 `hosts/<host>/interaction.md`, `hosts/<host>/execution.md`, `hosts/<host>/capabilities.json`처럼 소문자다.
- `hosts/*/capabilities.json`은 boolean 값만 담은 평면 객체다. 키 집합은 `core/HOST.md`의 표에서 파생된다.
- 스킬 본문의 플러그인 루트 토큰은 `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}` 순서를 사용한다. 셸이 직접 확장하는 `hooks/hooks.json`의 command는 `${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT}}` 순서를 사용한다.
- 외부 방법론을 포함한 `skills/fg-security/`와 `skills/fg-debug/`는 원본 파일·`LICENSE`를 유지하고, forge 연결은 각 디렉터리의 `SKILL.md`에 둔다. `skills/fg-debug/scripts/hitl-loop.template.sh`는 최상위 `scripts/` 트윈 규약의 대상이 아니다.

## 변경과 오류 처리 원칙

- 읽기 전용 도구는 상태를 수정하지 않는다. `scripts/forge-status.*`와 `scripts/forge-doctor.*`는 조사·출력만 수행한다.
- 상태를 바꾸는 도구는 검증 실패와 파일 작업 실패를 서로 다른 exit code로 구분한다. `scripts/forge-done.*`, `scripts/forge-merge.*`, `scripts/forge-loop-spend.*`의 머리말에 해당 계약이 적혀 있다.
- 누락·모호·파싱 실패가 자동 주행을 지속시키는 근거가 되지 않도록 보수적으로 종료한다. 특히 `scripts/forge-hook-stop.*`는 세션·시간·횟수·marker가 모두 확인된 경우에만 정지를 막는다.
- 사용자가 만든 값이 지시문이나 태그 경계를 깨지 않도록 제어 문자, 개행, 태그 구분자, 길이를 제한한다. 이 처리는 `scripts/forge-hook-session-start.*`에서 구현되고 fixture와 parity 테스트로 고정된다.
