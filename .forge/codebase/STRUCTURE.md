---
last_mapped_commit: 524c6a3ee40d28bcd90334a9e4f9ca0135fca088
mapped: 2026-09-03
---

# STRUCTURE — forge

## 디렉터리 배치

```
/ (리포 루트 = 플러그인 루트 = 마켓플레이스 — Claude Code + Codex 양쪽 호스트)
├── .claude-plugin/
│   ├── plugin.json              # Claude Code 매니페스트 (version 0.8.0)
│   └── marketplace.json         # 마켓플레이스 등록 (plugins[0].source: "./", 버전 2곳 더)
├── .codex-plugin/
│   └── plugin.json              # Codex 매니페스트 (버전 4번째 지점) — "skills": "./skills/" 로 공유 트리 직접 참조
│                                #   + interface 블록(displayName·category·capabilities·defaultPrompt 3개·brandColor)
├── core/                        # 호스트-중립 계약 3파일 (ADR 260903-080713)
│   ├── HOST.md                  # 어댑터 선택 규칙 + 8-capability 어휘 표 (57줄)
│   ├── EXECUTION.md             # 위임 계약 (9줄)
│   └── INTERACTION.md           # 질문 계약 (6줄)
├── hosts/                       # 호스트별 어댑터 — 각 3파일, 다섯 가지만 소유
│   ├── claude/                  # interaction.md · execution.md · capabilities.json (8개 전부 true)
│   └── codex/                   # interaction.md · execution.md · capabilities.json (spawn_parallel·plugin_root·session_start만 true)
├── skills/                      # 22개 스킬 — skills/<dir>/SKILL.md 자동 탐색 (두 호스트가 이 트리 하나를 공유, 사본 0)
│   ├── fg-ask/                  # SKILL.md + CONTEXT-FORMAT.md + ADR-FORMAT.md (grill-with-docs 자기완결 3파일, 영문 verbatim)
│   ├── fg-run/                  # SKILL.md + PLAN-FORMAT.md + RUN-ALL.md + FORGE-ROOT.md(루트 해석 단일 정의)
│   ├── fg-learn/                # SKILL.md + RETRO-FORMAT.md
│   ├── fg-done/                 # SKILL.md (196줄 — 봉인은 scripts/forge-done.* 위임)
│   ├── fg-next/                 # SKILL.md + HANDOFF.md(핸드오프 표 단일 정의) + DRIVE.md(89줄 — 무인 주행 3부: 턴내 계속·Stop 훅(prevent_stop 조건부)·태스크당 커밋)
│   ├── fg-loop/                 # SKILL.md (264줄 — 최대; waiting·stalled-waiting·blocked-health·budget-exhausted 포함)
│   ├── fg-eco/                  # SKILL.md + ECO.md
│   ├── fg-showme/               # SKILL.md + VISUAL.md + LICENSE + scripts/ (server.cjs·helper.js·frame-template.html·start/stop-server.sh — superpowers vendoring)
│   ├── fg-security/             # SKILL.md(forge glue 98줄) + LICENSE + vendored 12파일 — 진입 파일이 AUDIT.md(SKILL.md 아님!)
│   │                            #   ATTACK-CLASSES/HUNTING/RECONNAISSANCE/WEB-PROTOCOL-AND-AUTH/CLIENT-SIDE/
│   │                            #   AI-AND-LLM/MEMORY-SAFETY-AND-BINARY/VALIDATION-AND-REPORTING .md
│   │                            #   + report-schema.json + validate-findings.cjs (cloudflare, MIT — byte-for-byte 유지)
│   └── fg-{status,quick,map,merge,cleanup,doctor,drop,tdd,statusline,agenda,agents,adversarial-review,help}/  # 각 SKILL.md 단일 파일
├── scripts/                     # 결정론 스크립트 트윈 + 테스트 + 데이터 1 (44파일)
│   ├── forge-{status,done,merge,doctor,hook-session-start,hook-stop,loop-spend,statusline,statusline-full}.{sh,js}
│   ├── release-check.{sh,js}                # 릴리스 게이트 — 버전 4곳 동기 + Codex skills 경로 + hooks.json + 어댑터 6파일
│   ├── resolve-forge-root.{sh,js}
│   ├── forge-statusline-wrapper.sh          # 방법 1(append) 래퍼 — bash 전용(트윈 없음)
│   ├── explaining-forge.rule.txt            # 항상-on 설명 규율 canonical 본문 — forge-doctor B17이 읽음
│   └── *.test.sh / *.parity.test.sh         # 동작 테스트 / sh↔js 출력 동일성 테스트
├── hooks/
│   ├── hooks.json               # 훅 2개 정의 (자동 탐색): SessionStart + Stop — 명령은 ${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}
│   ├── run-hook.cmd             # bash→node polyglot 디스패처 (런타임/미지 이름이면 exit 0)
│   └── run-hook.test.sh
├── docs/                        # 사용자 문서 — 랜딩(정적) + VitePress 사이트
│   ├── index.html               # 랜딩 `/forge/` — 한 파일 KO/EN(data-l span, ADR-0027), VitePress 밖
│   ├── .vitepress/config.mts    # base '/forge/docs/', locales root(ko)+en, mermaid 플러그인
│   ├── index.md · skills.md · state-contract.md · forge-vs-loop-engineering.md · git-workflow.md · team-workflow.md · agenda.md · codex.md   # ko(root locale) — 8개
│   ├── en/                      # 위 8개의 영문 짝 (같은 파일명, 절 구조 1:1) — codex.md 신규
│   ├── public/icon.png          # 사이트 루트로 방출되는 자산
│   └── examples/                # github-actions-forge-check.yml
├── .github/workflows/docs.yml   # 랜딩 + VitePress 빌드를 한 Pages 아티팩트로 배포
├── package.json · package-lock.json  # "forge-docs" — 문서 사이트 도구 + 유일한 wire된 forge 스크립트 `release:check`("type" 필드 금지)
├── .forge/                      # 상태 + 영속 문서 (아래 절)
├── .claude/agents/              # 도메인 에이전트 카드 3장 (skill-author, script-twin-engineer, manifest-doc-syncer)
├── DESIGN.md                    # Claude 제품 디자인 시스템 토큰(색·타입·컴포넌트, 589줄) — fg-showme 화면 리테마의 참조원, 플러그인 계약 아님
├── CLAUDE.md · README.md · README.ko.md · CHANGELOG.md
└── .gitignore                   # .forge/* 제외 + 영속 문서 화이트리스트 + node_modules/·docs/.vitepress/{dist,cache}/
```

## `.forge/` 내부 (해석된 forge 루트 기준 — `skills/fg-run/FORGE-ROOT.md`)

**git 추적(영속, 화이트리스트)**: `CONTEXT.md`, `adr/`(활성 + `retired/` — 현재 은퇴 1건: `0025-claude-code-only-defer-codex-port.md`, Codex 호스트 지원 ADR `260903-080713`이 supersede), `retro/`, `codebase/`(fg-map 7문서 — 본 문서 포함), `config.json`(현재 `{"eco": false}` — 인식되는 키는 `tdd`·`eco`·`driveCommit`·`driveCommitMessage` 넷이고 미기재는 기본값), `branch/`(비기본 브랜치 루트 통째).

**gitignored(휘발)**: `backlog/`(fg-ask 산출 plan), `plan.md`/`run.md`/`STATUS.md`(활성 슬롯), `executed/`(실행-미회고 park), `done/`(봉인 아카이브 — 현재 143건), `quick/LOG.md`, `dropped/`, `agenda.md`, `loop.md`, `review.md`, `ask.md`, `drive.md`(무인 주행 마커 — Stop 훅이 읽고 주행이 지움), `showme/`(fg-showme 세션 — **최상위 전역 예외**이고 루트 `.gitignore`가 아니라 `start-server.sh`가 써 주는 자체-ignore `.forge/showme/.gitignore`(`*` 한 줄)로 제외되며, 마지막 세션 종료 시 디렉터리 자체가 사라진다).

## 명명 규칙

- **스킬**: 디렉터리·frontmatter `name` 모두 `fg-<verb|noun>`. 식별자는 frontmatter `name`.
- **vendored 자산**: 원형 유지가 원칙이되 **진입 파일만 개명**한다 — `skills/fg-security/AUDIT.md`가 업스트림에서 `SKILL.md`였다. `skills/*/SKILL.md` 자동 탐색이 vendored 본문을 중첩 스킬로 잡는 것을 막기 위한 것이고(같은 이유로 `fg-showme/scripts/`는 `.cjs`/`.js`뿐), forge 자신의 glue만 그 디렉터리의 `SKILL.md`를 차지한다. 나머지 파일은 diff를 싸게 유지하려 손대지 않는다.
- **스크립트**: `forge-<기능>.sh` + `.js` 트윈, 테스트는 `<이름>.test.sh`·패리티는 `<이름>.parity.test.sh`. shebang `#!/usr/bin/env bash`, `bash script.sh`로 호출, `.gitattributes`가 `*.sh` LF 강제.
- **ADR ID**: 시간기반 `YYMMDD-HHMMSS`(같은-초 충돌 시 소문자 글자 접미). 구식 `NNNN`(0001–0032)·`YYMMDD-HH글자`(예: `260716-13a`)는 grandfather 공존 — `.forge/adr/` 실물 확인됨. 은퇴는 `adr/retired/`로 이동(번호 불변).
- **회고**: `.forge/retro/YYMMDD-HHMMSS-slug.md`(신식) — 구식 `YYYY-MM-DD-slug.md` 공존.
- **봉인 폴더**: `.forge/done/<날짜-slug>/`(신식 `260810-084200-slug`, 구식 `2026-06-04-slug` 공존), 각각 `STATUS.md` + plan/run 동반.
- **plan slug**: plan 첫 줄 `<!-- forge-slug: ... -->` 주석이 회고·봉인 짝 맞춤 키. 분할 작업은 `-1of3` 접미(ADR-0004).
- **언어**: SKILL.md·`*-FORMAT.md`·공유 규율 문서는 영문, 화면 출력·산출 문서는 사용자 언어. 스킬 문서 내 흐름도는 Mermaid 금지·텍스트 흐름도(영문).
- **버전 동기 4곳**(3곳에서 늘었다): `.claude-plugin/plugin.json` `version` + `.claude-plugin/marketplace.json` `metadata.version`·`plugins[0].version` + **`.codex-plugin/plugin.json` `version`**. 현재 전부 `0.8.0`. 기계 검증은 `scripts/release-check.{sh,js}`(`npm run release:check`)와 `forge-doctor` B8.
- **호스트 capability 키**: `hosts/<host>/capabilities.json`은 `core/HOST.md` 표의 **8개 키만** 사용(`structured_choice`·`spawn_parallel`·`spawn_role`·`plugin_root`·`session_start`·`prevent_stop`·`project_agents`·`status_display`). 값은 관측 기반이며 미검증은 `false`. 어댑터 파일명은 소문자 고정(`interaction.md`·`execution.md`·`capabilities.json`) — `release-check`가 6파일 존재를 검사한다.
- **플러그인 루트 참조**: 스킬·훅 본문에서 `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}` 형태로만 쓴다(bare `${CLAUDE_PLUGIN_ROOT}`는 남기지 않음). 스킬 간 참조는 가능하면 디렉터리 상대경로(`../fg-run/FORGE-ROOT.md`), `core/`·`hosts/` 참조는 `../../core/HOST.md` 상대 링크.
- **호출 접두**: Claude Code `/forge:fg-*` / Codex `$fg-*` — 사용자 안내 문구에는 둘 다 적는다.
- **이중언어 쌍(3계열)**: `README.md`↔`README.ko.md` / `docs/<name>.md`↔`docs/en/<name>.md`(**8쌍** — `codex.md` 추가, 파일명 동일·절 구조 1:1 유지가 규약) / `docs/index.html` 안의 `data-l="ko"`↔`data-l="en"` span — 어느 쪽이든 한쪽 수정 시 반드시 짝 갱신. 쌍 누락 확인은 `for f in docs/*.md; do [ -f "docs/en/$(basename "$f")" ] || echo missing; done`.

## 핵심 위치 빠른 찾기

| 찾는 것 | 위치 |
| --- | --- |
| 루프 정의·상태 계약 원문 | `CLAUDE.md`, `docs/state-contract.md` |
| 호스트 어댑터 선택·capability 어휘 | `core/HOST.md` (위임 계약 `core/EXECUTION.md` · 질문 계약 `core/INTERACTION.md`) |
| 특정 호스트가 무엇을 지원하나 | `hosts/claude/capabilities.json` · `hosts/codex/capabilities.json` (사람용 표는 `docs/codex.md`·`docs/en/codex.md`) |
| Codex 매니페스트·표현 계층 | `.codex-plugin/plugin.json` (`skills: "./skills/"` + `interface` 블록) |
| 릴리스 게이트(버전 4곳·어댑터 완전성) | `scripts/release-check.{sh,js}` · `npm run release:check` |
| forge 루트 해석 규칙 | `skills/fg-run/FORGE-ROOT.md` |
| 핸드오프 표 형태 | `skills/fg-next/HANDOFF.md` |
| 무인 주행 규율 | `skills/fg-next/DRIVE.md` |
| plan/회고/CONTEXT/ADR 형식 | `skills/fg-run/PLAN-FORMAT.md` · `skills/fg-learn/RETRO-FORMAT.md` · `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md` |
| 봉인 기계 | `scripts/forge-done.sh`/`.js` |
| 스크립트 규약 근거 | `.forge/adr/0022-...` · `0031-...` |
| fg-loop waiting/벽 정의 | `skills/fg-loop/SKILL.md` (`evidence: external` 선언 46행, 원장 `waiting ×N` 66행, `wall:` 값 목록 41행) |
| 세션 시작 훅 | `hooks/hooks.json` → `hooks/run-hook.cmd` → `scripts/forge-hook-session-start.{sh,js}` |
| 무인 주행 Stop 훅 | `hooks/hooks.json` → `hooks/run-hook.cmd` → `scripts/forge-hook-stop.{sh,js}` (마커 `<forge-root>/drive.md`, exit 2 = 정지 차단) |
| 토큰 지출 판정 | `scripts/forge-loop-spend.{sh,js}` (exit 3 초과 / 4 사전예측 / 5 측정불가) |
| 항상-on 설명 규율 원본 | `scripts/explaining-forge.rule.txt` (사본 검사는 `forge-doctor` B17) |
| 보안 감사 절차 원문 | `skills/fg-security/AUDIT.md` (vendored, 편집 금지) — forge glue는 `skills/fg-security/SKILL.md` |
| 문서 사이트 빌드·배포 | `docs/.vitepress/config.mts` · `package.json`(`npm run docs:build`) · `.github/workflows/docs.yml` |
| 배포 절차 | `CLAUDE.md` "배포 규칙" (CHANGELOG→README/docs→버전 4곳→JSON 검증·`npm run release:check`→commit/push) |
