---
last_mapped_commit: 48899bdb6b04ad575767885a7c741cb2a09bd9d0
mapped: 2026-08-10
---

# STRUCTURE — forge

## 디렉터리 배치

```
/ (리포 루트 = 플러그인 루트 = 마켓플레이스)
├── .claude-plugin/
│   ├── plugin.json              # 플러그인 매니페스트 (version 0.6.6)
│   └── marketplace.json         # 마켓플레이스 등록 (plugins[0].source: "./", 버전 2곳 더)
├── skills/                      # 20개 스킬 — skills/<dir>/SKILL.md 자동 탐색
│   ├── fg-ask/                  # SKILL.md + CONTEXT-FORMAT.md + ADR-FORMAT.md (grill-with-docs 자기완결 3파일, 영문 verbatim)
│   ├── fg-run/                  # SKILL.md + PLAN-FORMAT.md + RUN-ALL.md + FORGE-ROOT.md(루트 해석 단일 정의)
│   ├── fg-learn/                # SKILL.md + RETRO-FORMAT.md
│   ├── fg-done/                 # SKILL.md (192줄 — 봉인은 scripts/forge-done.* 위임)
│   ├── fg-next/                 # SKILL.md + HANDOFF.md(핸드오프 표 단일 정의) + DRIVE.md(무인 주행 규율)
│   ├── fg-loop/                 # SKILL.md (229줄 — 최대; waiting·stalled-waiting·blocked-health 포함)
│   ├── fg-eco/                  # SKILL.md + ECO.md
│   ├── fg-visual/               # SKILL.md + VISUAL.md + LICENSE + scripts/ (server.cjs·helper.js·frame-template.html·start/stop-server.sh — superpowers vendoring)
│   └── fg-{status,quick,map,merge,cleanup,doctor,drop,tdd,statusline,agenda,agents,adversarial-review}/  # 각 SKILL.md 단일 파일
├── scripts/                     # 결정론 스크립트 트윈 + 테스트 (33파일)
│   ├── forge-{status,done,merge,doctor,hook-session-start,statusline,statusline-full}.{sh,js}
│   ├── resolve-forge-root.{sh,js}
│   ├── forge-statusline-wrapper.sh          # 방법 1(append) 래퍼 — bash 전용
│   └── *.test.sh / *.parity.test.sh         # 동작 테스트 / sh↔js 출력 동일성 테스트
├── hooks/
│   ├── hooks.json               # SessionStart 훅 정의 (자동 탐색)
│   ├── run-hook.cmd             # bash→node polyglot 디스패처 (런타임 없으면 exit 0)
│   └── run-hook.test.sh
├── docs/                        # 사용자 문서 (GitHub Pages)
│   ├── index.html               # 랜딩 — 한 파일 KO/EN(data-l span, ADR-0027)
│   ├── skills.md · state-contract.md · forge-vs-loop-engineering.md · git-workflow.md · team-workflow.md
│   └── examples/                # github-actions-forge-check.yml
├── .forge/                      # 상태 + 영속 문서 (아래 절)
├── .claude/agents/              # 도메인 에이전트 카드 3장 (skill-author, script-twin-engineer, manifest-doc-syncer)
├── CLAUDE.md · README.md · README.ko.md · CHANGELOG.md
└── .gitignore                   # .forge/* 제외 + 영속 문서 화이트리스트
```

## `.forge/` 내부 (해석된 forge 루트 기준 — `skills/fg-run/FORGE-ROOT.md`)

**git 추적(영속, 화이트리스트)**: `CONTEXT.md`, `adr/`(활성 + `retired/`), `retro/`, `codebase/`(fg-map 7문서 — 본 문서 포함), `config.json`(현재 `{"eco": false}`), `branch/`(비기본 브랜치 루트 통째).

**gitignored(휘발)**: `backlog/`(fg-ask 산출 plan), `plan.md`/`run.md`/`STATUS.md`(활성 슬롯), `executed/`(실행-미회고 park), `done/`(봉인 아카이브 — 현재 120+건), `quick/LOG.md`, `dropped/`, `agenda.md`, `loop.md`, `review.md`, `ask.md`, `visual/`.

## 명명 규칙

- **스킬**: 디렉터리·frontmatter `name` 모두 `fg-<verb|noun>`. 식별자는 frontmatter `name`.
- **스크립트**: `forge-<기능>.sh` + `.js` 트윈, 테스트는 `<이름>.test.sh`·패리티는 `<이름>.parity.test.sh`. shebang `#!/usr/bin/env bash`, `bash script.sh`로 호출, `.gitattributes`가 `*.sh` LF 강제.
- **ADR ID**: 시간기반 `YYMMDD-HHMMSS`(같은-초 충돌 시 소문자 글자 접미). 구식 `NNNN`(0001–0032)·`YYMMDD-HH글자`(예: `260716-13a`)는 grandfather 공존 — `.forge/adr/` 실물 확인됨. 은퇴는 `adr/retired/`로 이동(번호 불변).
- **회고**: `.forge/retro/YYMMDD-HHMMSS-slug.md`(신식) — 구식 `YYYY-MM-DD-slug.md` 공존.
- **봉인 폴더**: `.forge/done/<날짜-slug>/`(신식 `260810-084200-slug`, 구식 `2026-06-04-slug` 공존), 각각 `STATUS.md` + plan/run 동반.
- **plan slug**: plan 첫 줄 `<!-- forge-slug: ... -->` 주석이 회고·봉인 짝 맞춤 키. 분할 작업은 `-1of3` 접미(ADR-0004).
- **언어**: SKILL.md·`*-FORMAT.md`·공유 규율 문서는 영문, 화면 출력·산출 문서는 사용자 언어. 스킬 문서 내 흐름도는 Mermaid 금지·텍스트 흐름도(영문).
- **버전 동기 3곳**: `plugin.json` `version` + `marketplace.json` `metadata.version`·`plugins[0].version`.
- **이중언어 쌍**: `README.md`↔`README.ko.md`, `docs/index.html`의 `data-l="ko"`↔`data-l="en"` span — 한쪽 수정 시 반드시 짝 갱신.

## 핵심 위치 빠른 찾기

| 찾는 것 | 위치 |
| --- | --- |
| 루프 정의·상태 계약 원문 | `CLAUDE.md`, `docs/state-contract.md` |
| forge 루트 해석 규칙 | `skills/fg-run/FORGE-ROOT.md` |
| 핸드오프 표 형태 | `skills/fg-next/HANDOFF.md` |
| 무인 주행 규율 | `skills/fg-next/DRIVE.md` |
| plan/회고/CONTEXT/ADR 형식 | `skills/fg-run/PLAN-FORMAT.md` · `skills/fg-learn/RETRO-FORMAT.md` · `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md` |
| 봉인 기계 | `scripts/forge-done.sh`/`.js` |
| 스크립트 규약 근거 | `.forge/adr/0022-...` · `0031-...` |
| fg-loop waiting/벽 정의 | `skills/fg-loop/SKILL.md` (§1 evidence 선언, 원장 `waiting ×N`, `wall:` 값 목록 37행) |
| 세션 시작 훅 | `hooks/hooks.json` → `hooks/run-hook.cmd` → `scripts/forge-hook-session-start.{sh,js}` |
| 배포 절차 | `CLAUDE.md` "배포 규칙" (CHANGELOG→README/docs→버전 3곳→JSON 검증→commit/push) |
