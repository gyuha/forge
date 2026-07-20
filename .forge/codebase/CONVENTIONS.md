---
last_mapped_commit: 553484ae395d6ca3df973f5b0cf5762029fd94ec
mapped: 2026-07-20
---

# CONVENTIONS

forge 리포의 코드/문서 스타일·명명·패턴 규약. 산출물은 전부 Markdown(`SKILL.md`, `*-FORMAT.md`)·JSON(매니페스트)·bash/node 스크립트다. **플러그인 자체를 위한 빌드·테스트·린트 시스템은 없다**(`package.json`·`Makefile`·`.github` 부재를 확인). "개발"은 Markdown/JSON 편집이고, 검증은 `TESTING.md`에 정리한 방법을 쓴다.

## 패키징 (단일 리포 = 플러그인 + 마켓플레이스)

- `.claude-plugin/plugin.json` — 플러그인 매니페스트. `skills/` 자동 탐색이므로 `skills` 필드 생략 가능.
- `.claude-plugin/marketplace.json` — 이 리포를 마켓플레이스로 등록. `plugins[].source` 는 `"./"`.
- 스킬은 `skills/<name>/SKILL.md` 로 자동 탐색된다. **스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name`**.
- 매니페스트의 두 description은 역할이 다르다: `marketplace.json`의 `metadata.description`은 루프 태그라인(루프 밖 유틸리티 제외), `plugins[].description`·`plugin.json`의 `description`은 전체 스킬 목록(루프 밖 스킬도 반영).

## 언어 규약

- **스킬 본문(`skills/*/SKILL.md`)·형식 문서(`*-FORMAT.md`)는 영문으로 작성**한다. `skills/fg-ask/SKILL.md`처럼 grill-with-docs 원문을 옮긴 부분은 영문 verbatim 유지.
- **사용자에게 출력하는 언어는 사용자 언어를 따른다** — 각 스킬에 "respond in the user's language" 지시를 명시하고, 산출 문서(plan·회고·CONTEXT·ADR 등 사용자 프로젝트에 남는 것)도 사용자 언어로 쓴다.
- `.forge/` 내부 문서(ADR 본문·CONTEXT·retro)는 실제로 한글로 작성돼 있다(예: `.forge/adr/0022-*.md`).

## 단일 정의 문서 (복붙 금지, `${CLAUDE_PLUGIN_ROOT}` 참조)

형식·공유 규율 문서는 **한 벌만 존재하며 소유 스킬 디렉터리에 둔다.** 다른 스킬은 자체 복사하지 않고 `${CLAUDE_PLUGIN_ROOT}/skills/<owner>/<file>`(또는 상대경로 `../<owner>/`)로 참조한다. 리포 전체에 이 참조가 20곳 존재한다(`grep -rln CLAUDE_PLUGIN_ROOT skills/`).

- 형식 문서: `skills/fg-ask/CONTEXT-FORMAT.md`, `skills/fg-ask/ADR-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`(생산자는 fg-ask지만 소비자 쪽에 둠), `skills/fg-learn/RETRO-FORMAT.md`. 전부 영문 작성.
- 공유 규율 문서: `skills/fg-run/FORGE-ROOT.md`(forge 루트 해석, ADR-0011 — 모든 루프 스킬 참조), `skills/fg-next/DRIVE.md`(무인 주행 규율, ADR-0028 — fg-next `all`·fg-loop 참조).
- 규율 내장 문서: `skills/fg-eco/ECO.md`(eco 규율, fg-eco가 유일한 활성화 경로), `skills/fg-visual/VISUAL.md`(시각 컴패니언, fg-ask가 파일 참조로 직접 사용).
- 루트 `references/` 디렉터리는 폐지됐다.

## 이중 언어 문서 동기화

- **`README.md`(영문) ↔ `README.ko.md`(한글)** 는 번역 쌍이다. 한쪽을 갱신하면 반드시 다른 쪽도 같은 변경으로 갱신한다. 한쪽만 고치면 어긋난다.
- **`docs/index.html`** 는 한 파일 안에 KO/EN 텍스트를 `data-l="ko"`/`data-l="en"` span으로 나란히 담고 언어 토글로 전환한다(ADR-0027, `.forge/adr/0027-docs-index-single-file-bilingual.md`). 현재 78개 `data-l` span 존재. 한쪽 언어 텍스트를 고치면 짝 span도 함께 갱신한다.

## 스킬 문서 서술 규약

- **흐름도는 텍스트로**(Mermaid 금지). 스킬 본문의 흐름·상태 전이·분기는 `A → B → C`, 분기는 들여쓰기·화살표·조건 레이블로 쓴다(영문). 이유: 스킬은 에이전트가 파싱·실행하는 지시문이고 Mermaid는 diff·grep을 어렵게 한다. (이 규약은 스킬 문서 한정 — 사용자 산출 문서에는 미적용.)
- **핸드오프는 진술형(statement-form)** — "진행할까요?"·"shall I proceed?"로 묻지 않고 다음 스킬·트리거를 알린 뒤 멈춘다(ADR-0015, `.forge/adr/0015-fg-run-handoff-menu-others-stated.md`). 체이닝(동의 시 자동 호출)은 fg-next 전담. "방금 한 것 / 다음 단계 / 시작하는 법"을 자연스러운 대화체로 전한다.
- **절제** — ADR·글로서리 용어는 승급 바를 넘을 때만 영속 문서로 밀어 넣는다. 회고에서 나온 모든 걸 승급하지 않는다.

## bash + node 스크립트 트윈 (ADR-0022)

결정론적·기계적 연산은 스크립트로 추출한다. 근거·대안은 `.forge/adr/0022-forge-scripts-convention-cross-platform-dual-dispatch.md`.

- **각 운영 스크립트는 `.sh`(bash, 1차) + `.js`(node, 폴백) 트윈**으로 제공한다. Windows + PowerShell 차단 환경 때문에 `.ps1`은 배제하고 node를 폴백으로 쓴다(node는 Claude Code가 항상 보장).
- **이중 디스패치 — bash 우선, node 폴백.** 스킬은 "prefer bash, fall back to node" 규약으로 호출한다. 예(`skills/fg-done/SKILL.md`): bash 있으면 `bash "${CLAUDE_PLUGIN_ROOT}/scripts/forge-done.sh" [args]`, 없으면 `node "${CLAUDE_PLUGIN_ROOT}/scripts/forge-done.js" [args]` — 동일 동작(exit code·STATUS 내용·아카이브 레이아웃), 패리티 테스트로 보장.
- statusline 경로는 Bash 도구 밖에서 실행되므로 fg-statusline 설치 시 bash 가용 여부를 한 번 판정해 단일 진입 command를 확정한다(런타임 위임이 아니라 설치 시점 분기).
- **포터블 규칙**: shebang `#!/usr/bin/env bash`(`/bin/bash` 금지 — NixOS), 호출은 `bash script.sh`(`./script.sh` 금지 — NTFS는 POSIX exec 비트 없음), `.gitattributes`가 `*.sh`를 **LF 강제**(CRLF가 bash 셔뱅/인자를 깨뜨림 — load-bearing).
- **판단은 스크립트로 옮기지 않는다.** grilling·retro 분류·divergence 평가·검증 결정 같은 LLM 판단은 산문(SKILL.md)에 남기고, 결정론적 survey·상태 전이만 스크립트화한다.
- **스크립트 수를 의도적으로 작게 유지**한다.

현재 트윈 목록(`scripts/`): `forge-doctor`, `forge-done`, `forge-merge`, `forge-status`, `forge-statusline`, `forge-statusline-full`, `resolve-forge-root` 는 `.sh`+`.js` 트윈. `forge-statusline-wrapper.sh` 는 **bash 전용**(원본 statusline 보존 wrapper라 node 트윈 없음).

### 스크립트는 exit code / 언어중립 토큰으로 라우팅한다

기계적 스크립트가 결정을 내리고, 스킬(LLM)은 exit code만 보고 분기한다. 예:
- `forge-done.sh`: `0` 봉인 OK · `2` 봉인 대상 없음 · `3` verify 게이트(sealable 아님) · `4` retro 게이트(회고 미완) · `5` 중복(이미 done). (`scripts/forge-done.test.sh` 헤더)
- `forge-merge.sh`: `0` 통합 · `2` 없음 · `3` in-flight · `4` conflict(CONTEXT 재정의 / NNNN 충돌) · `6` ambiguous. (`scripts/forge-merge.test.sh` 헤더)
- `forge-doctor.sh`: `0` clean · `1` warnings · `2` errors — AI 없이 CI 게이트로 쓸 수 있음.
- `resolve-forge-root.sh`: 항상 exit 0, stdout에 해석된 루트 경로 출력(`.forge` 또는 `.forge/branch/<branch>`), 폴백 시 stderr에 1줄 경고.

### fg-visual 벤더 스크립트는 예외

`skills/fg-visual/scripts/`(`server.cjs`·`start-server.sh`·`stop-server.sh`·`helper.js`·`frame-template.html`)는 obra/superpowers v6.1.1에서 vendoring됐고 **의도적으로 트윈 규약 밖**이다 — 업스트림 형태(bash launcher + node server)를 유지한다. MIT 귀속을 `skills/fg-visual/LICENSE`(Copyright (c) 2025 Jesse Vincent)와 `SKILL.md`/`VISUAL.md` 상단에 명시. 근거: ADR `260719-224442`.

## ADR 규약

형식 정의: `skills/fg-ask/ADR-FORMAT.md`. 위치: `.forge/adr/<id>-slug.md`, 인용 `ADR-<id>`.

- **ID 스킴 (두 형식 공존)**:
  - **순차 `NNNN`** (grandfather) — `0001`~`0032`. 시간 기반 전환 이전 ADR은 번호를 동결한 채 유지, 재작성·백필 없음. 새 ADR은 이 방식으로 만들지 않는다.
  - **시간 기반** (현행) — `YYMMDD-HH` + 소문자 순번 글자(예: `260716-13a`). 벽시계에서 민팅해 조율 없이 충돌-불가에 가깝고, ID가 생성 시점에 확정돼 교차참조가 안 깨진다. 같은 시(時) 충돌·크로스 브랜치 충돌은 "다음 빈 글자" 단일 규칙으로 해소(cascade 재번호 없음). 근거: `.forge/adr/260716-13a-adr-time-based-id-scheme.md`.
  - **granularity 개정** — 실사용에서 `YYMMDD-HH`(ADR)와 `YYYY-MM-DD`(done/retro) 불일치가 드러나 `YYMMDD-HHMMSS` + 충돌 시에만 시리얼 글자로 상향·통일(예: `260719-161701`). 상세: `.forge/adr/260719-161701-time-precise-naming.md`.
  - frontmatter provenance: `author:`(생성 시 `git config user.name`) + `decided: YYYY-MM-DD`. 파일 본문에 실려 fg-merge 이동에도 보존(git blame과 정반대 장점). grandfather NNNN ADR은 이 frontmatter가 없다.
  - retired ID(어느 형식이든) 재사용 금지(fg-cleanup).
- **ADR 승급 바 (세 조건 모두 참일 때만)**: ① 되돌리기 어렵다 ② 맥락 없이 의아하다("왜 이렇게 했지?") ③ 진짜 트레이드오프(대안이 있었고 이유로 하나를 골랐다). 하나라도 아니면 만들지 않는다.
- 템플릿은 frontmatter + 제목 + 1~3문장이면 충분. Status/Considered Options/Consequences는 진짜 가치 있을 때만.
- fg-ask는 ADR 본문을 전부 안 읽고 앞부분(제목+frontmatter)으로 트리아지한 뒤 관련분만 fetch한다.

## 상태 계약 / git 추적 경계

`.gitignore`가 `.forge/*`를 기본 제외하되 영속 문서만 화이트리스트로 되살린다: `!.forge/CONTEXT.md`·`!.forge/adr/`·`!.forge/retro/`·`!.forge/codebase/`·`!.forge/config.json`·`!.forge/branch/`. 즉 **위치는 `.forge/` 안, 구분은 git 추적 여부**다. 비-기본 브랜치의 forge 루트(`.forge/branch/<branch>/`)는 통째로 추적된다(ADR-0011 — 브랜치별 네임스페이스로 머지 충돌 회피, `git merge` 뒤 fg-merge가 `.forge/`에 통합). 휘발 상태(plan/run/STATUS/backlog/executed/done)는 기본 브랜치에서 gitignored.

## 배포 시 동기화 규약

- 버전은 **3곳을 반드시 동기 갱신**: `plugin.json`의 `version`, `marketplace.json`의 `metadata.version`과 `plugins[0].version`.
- 매니페스트의 스킬 개수·설명을 바꿀 땐 `plugin.json`과 `marketplace.json`을 함께 갱신(둘 다 사람이 읽는 설명).
- 배포 절차: `CHANGELOG.md 작성 → README(이중언어)·docs 갱신 → 버전 3곳 범프 → JSON 검증 → commit → push(main)`. 설치는 GitHub 기본 브랜치(main)를 당기므로 push까지가 배포다.
