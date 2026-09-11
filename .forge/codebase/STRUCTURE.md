---
last_mapped_commit: 6146cae539151b65850e1e2609bdf8f7e78a1e47
mapped: 2026-09-11
---

# STRUCTURE — forge

## 최상위 배치

```text
forge/
├── .claude-plugin/       Claude Code 플러그인·마켓플레이스 매니페스트
├── .codex-plugin/        Codex 플러그인 매니페스트
├── .claude/              프로젝트 에이전트 카드와 로컬 Claude 설정
├── .forge/               forge 상태, 결정 기록, 회고, 코드베이스 지도
├── .github/workflows/    문서 배포 및 릴리스 검사 CI
├── core/                 호스트 중립 계약
├── hosts/                호스트별 interaction/execution/capability 어댑터
├── skills/               공유 fg-* 스킬 트리
├── scripts/              결정론 Bash/Node 구현과 테스트
├── hooks/                플러그인 훅 선언 및 런타임 디스패처
├── docs/                 랜딩 페이지와 VitePress 문서 사이트
├── AGENTS.md              CLAUDE.md를 저장소 지침으로 지정
├── CLAUDE.md              저장소 개발·검증·릴리스 지침
├── DESIGN.md              설계 설명
├── README.md              영어 프로젝트 안내
├── README.ko.md           한국어 프로젝트 안내
├── CHANGELOG.md           릴리스 변경 기록
├── package.json           문서 사이트와 릴리스 검사 명령
└── package-lock.json      문서 도구 의존성 잠금
```

## 플러그인 메타데이터

`.claude-plugin/`에는 두 JSON 파일이 있다.

- `.claude-plugin/plugin.json` — Claude Code 플러그인 이름, 버전, 설명, 저자, 저장소 정보
- `.claude-plugin/marketplace.json` — 리포지터리 루트를 `source: "./"`로 등록하는 마켓플레이스 항목과 별도 metadata 버전

`.codex-plugin/plugin.json`은 Codex용 이름·버전·설명과 `skills` 경로, 표시용 `interface` 정보를 포함한다. 릴리스 시 동기화되는 버전 위치는 이 파일 1곳, `.claude-plugin/plugin.json` 1곳, `.claude-plugin/marketplace.json` 2곳이다.

## 공유 계약과 호스트 어댑터

`core/`는 세 파일만 둔다.

- `core/HOST.md` — 호스트 선택, 플러그인 경로, 9개 capability 키
- `core/EXECUTION.md` — 슬라이스 의존성과 위임 책임 경계
- `core/INTERACTION.md` — 한 번에 한 질문과 선택 UI 폴백

`hosts/`의 각 호스트 디렉터리는 같은 세 파일 형태를 사용한다.

```text
hosts/
├── claude/
│   ├── capabilities.json
│   ├── execution.md
│   └── interaction.md
├── codex/
│   ├── capabilities.json
│   ├── execution.md
│   └── interaction.md
└── opencode/
    ├── capabilities.json
    ├── execution.md
    └── interaction.md
```

`capabilities.json`은 `core/HOST.md`가 선언한 동일한 9개 키만 사용한다. `execution.md`는 호스트 도구로 실행을 시작·수집·취소하는 방법을, `interaction.md`는 선택 질문을 표시하는 방법을 담는다.

## 스킬 트리

직접 실행 가능한 기능은 `skills/<name>/SKILL.md` 형태다. 현재 최상위 스킬 디렉터리는 22개다.

```text
skills/
├── fg-ask/                 계획 질의; ADR/CONTEXT 형식 포함
├── fg-run/                 실행; 계획 형식·루트·복구·배치 계약 포함
├── fg-learn/               회고; 회고 형식 포함
├── fg-done/                완료 봉인
├── fg-next/                다음 단계 실행; 핸드오프·자동 주행 계약 포함
├── fg-loop/                목표 주행; 신규 질의와 재개 시나리오 fixture 포함
├── fg-map/                 `.forge/codebase/` 지도 생성
├── fg-status/              현재 상태 보고
├── fg-doctor/              상태·문서 무결성 검사
├── fg-config/              전역 설정; eco 규율 포함
├── fg-quick/               경량 작업 경로
├── fg-merge/               브랜치 상태 통합
├── fg-cleanup/             ADR 은퇴
├── fg-drop/                미완료 상태 제거·보관
├── fg-agenda/              의사결정 대기 파일 관리
├── fg-agents/              프로젝트 에이전트 카드 생성
├── fg-statusline/          상태 표시 설치
├── fg-adversarial-review/  실행 결과 다각도 검토
├── fg-debug/               진단 절차와 vendored 자료
├── fg-security/            보안 감사 절차와 스키마
├── fg-showme/              로컬 시각 동반 서버
└── fg-help/                스킬 사용법 보고
```

보조 파일은 소비 스킬과 같은 디렉터리에 둔다. 주요 예는 다음과 같다.

- `skills/fg-ask/ADR-FORMAT.md`, `skills/fg-ask/CONTEXT-FORMAT.md`
- `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-run/FORGE-ROOT.md`, `skills/fg-run/RECOVERY.md`, `skills/fg-run/RUN-ALL.md`
- `skills/fg-next/HANDOFF.md`, `skills/fg-next/DRIVE.md`, `skills/fg-next/ALL-MODE.md`
- `skills/fg-loop/INQUIRY.md`(신규 목표 계약 확정 전용 — `loop.md`가 없을 때만 읽음), `skills/fg-loop/tests/resume-scenarios.md`
- `skills/fg-learn/RETRO-FORMAT.md`
- `skills/fg-config/ECO.md`
- `skills/fg-debug/DIAGNOSE.md`, `skills/fg-debug/scripts/hitl-loop.template.sh`
- `skills/fg-security/AUDIT.md`, `skills/fg-security/ATTACK-CLASSES.md`, `skills/fg-security/report-schema.json`, `skills/fg-security/validate-findings.cjs`
- `skills/fg-showme/VISUAL.md`, `skills/fg-showme/scripts/`

스킬 디렉터리는 kebab-case `fg-<name>`을 사용한다. 실행 식별자는 각 `SKILL.md` 첫 YAML 블록의 `name` 값이다.

## 결정론 스크립트와 테스트

`scripts/`의 기능 구현은 대체로 다음 네 파일 집합을 사용한다.

```text
forge-<feature>.sh
forge-<feature>.js
forge-<feature>.test.sh
forge-<feature>.parity.test.sh
```

Bash/Node 트윈을 가진 기능은 다음 basename으로 묶인다.

- `scripts/forge-doctor.*`
- `scripts/forge-done.*`
- `scripts/forge-hook-session-start.*`
- `scripts/forge-hook-stop.*`
- `scripts/forge-loop-spend.*`
- `scripts/forge-merge.*`
- `scripts/forge-status.*`
- `scripts/forge-statusline.*`
- `scripts/forge-statusline-full.*`
- `scripts/release-check.*`
- `scripts/resolve-forge-root.*`

추가 Bash 보조는 `scripts/forge-statusline-wrapper.sh`이며 자체 검사 `scripts/forge-statusline-wrapper.test.sh`가 있다. 모든 스킬의 설명 규칙을 검사하는 기준 텍스트는 `scripts/explaining-forge.rule.txt`다.

파일명 접미사는 역할을 구분한다.

- `.sh` — Bash 기본 구현
- `.js` — Node 대체 구현; CommonJS 사용
- `.test.sh` — fixture 기반 동작 검사
- `.parity.test.sh` — Bash와 Node 결과 비교

## 훅

`hooks/hooks.json`은 `SessionStart`와 `Stop`을 선언하고 둘 다 `hooks/run-hook.cmd`를 호출한다. `hooks/run-hook.cmd`는 이벤트 이름에 따라 `scripts/forge-hook-<event>.sh` 또는 `.js`를 실행한다.

훅 전용 검사는 다음 위치에 있다.

- `hooks/run-hook.test.sh`
- `hooks/run-hook.windows.test.js`
- `scripts/forge-hook-session-start.test.sh`
- `scripts/forge-hook-session-start.parity.test.sh`
- `scripts/forge-hook-stop.test.sh`
- `scripts/forge-hook-stop.parity.test.sh`

## `.forge/` 상태 배치

기본 브랜치의 최상위 `.forge/`는 다음 경로를 사용한다.

```text
.forge/
├── config.json             전역 설정
├── codebase/               7개 구현 지도 문서
├── CONTEXT.md              영속 문서
├── adr/                    활성 결정 기록
│   └── retired/            은퇴한 결정 기록
├── retro/                  회고 기록
├── backlog/                실행 전 계획
├── plan.md                 활성 계획
├── running.md              위임 시작 후 결과 수집 전 표식
├── run.md                  실행 결과
├── STATUS.md               활성 작업 상태
├── executed/<slug>/        실행 후 회고 대기 작업
├── done/<timestamp-slug>/  완료된 plan/run/STATUS 묶음
├── dropped/                보관 방식으로 버린 상태
├── quick/LOG.md            경량 작업 기록
├── agenda.md               열린 의사결정 작업 파일
├── ask.md                  중단된 질의 초안
├── loop.md                 목표 주행 계약
├── drive.md                Stop 훅용 일시 표식
├── review.md               선택적 적대 검토 결과
├── branch/<branch>/        비기본 브랜치의 forge 루트
└── showme/<session>/       시각 동반 세션 파일
```

이 중 `.forge/config.json`과 `.forge/codebase/`는 모든 브랜치가 공유한다. `.forge/showme/`는 시각 기능의 전역 휘발 저장소다. 나머지 루프 상태는 `skills/fg-run/FORGE-ROOT.md`가 정한 현재 브랜치 루트를 따른다.

계획 파일은 첫 줄에 `<!-- forge-slug: <slug> -->` 표식을 사용하고 `<!-- task: N -->`, `<!-- priority: high|medium|low -->`, 필요 시 `<!-- part: N/M -->` 같은 HTML 주석 메타데이터를 둔다. 완료 디렉터리는 `YYMMDD-HHMMSS-<slug>` 형태이며 같은 초·slug 충돌 때 문자 접미사가 붙는다. 신규 ADR은 `YYMMDD-HHMMSS` 기반 ID를 사용하고 같은 초 충돌 때 문자 접미사를 붙는다. 기존의 4자리 ADR 파일도 `.forge/adr/`에 함께 남아 있다.

## 프로젝트 에이전트 카드

`.claude/agents/`에는 저장소 작업을 위한 카드가 있다.

- `.claude/agents/manifest-doc-syncer.md`
- `.claude/agents/script-twin-engineer.md`
- `.claude/agents/skill-author.md`

`.claude/skills/issue-triage/SKILL.md`는 저장소 로컬 스킬이다. `.claude/settings.local.json`은 로컬 Claude 설정이며 플러그인 배포 매니페스트와 분리된다.

## 문서 사이트

문서 소스는 `docs/`에 있다.

- `docs/index.html` — 수기 작성 이중언어 랜딩 페이지
- `docs/*.md` — 한국어 VitePress 페이지
- `docs/en/*.md` — 영어 VitePress 페이지
- `docs/.vitepress/config.mts` — 사이트 base, locale, nav, sidebar, Mermaid 설정과 sitemap·소셜 메타(`transformHead`) 구성
- `docs/public/icon.png`, `docs/public/og-image.png` — VitePress public 자산(사이트 루트로 방출)
- `docs/examples/github-actions-forge-check.yml` — 복사 가능한 CI 예시
- `docs/icon.png`, `docs/icon-sm.png`, `docs/footer-forge-bg.png`, `docs/workflow.png` — 랜딩·문서 이미지

`docs/.vitepress/dist/`와 `docs/.vitepress/cache/`는 빌드 산출물이며 `.gitignore`가 제외한다. 루트 `node_modules/`도 추적하지 않는다.

## 자동화와 검증 진입점

- `.github/workflows/docs.yml` — `docs/**`, `package.json`, `package-lock.json` 변경 시 VitePress를 빌드하고 Pages artifact를 조립
- `.github/workflows/release-check.yml` — 매니페스트, `core/`, `hosts/`, `hooks/`, 릴리스 검사 파일, 호스트 문서 변경 시 릴리스 계약 검사
- `package.json`의 `docs:dev`, `docs:build`, `docs:preview` — 문서 사이트 로컬 명령
- `package.json`의 `release:check` — `node scripts/release-check.js` 실행

저장소 루트에는 플러그인 Markdown/JSON을 변환하는 빌드 디렉터리나 애플리케이션 소스 디렉터리가 없다. `package.json`은 `docs/` 사이트 도구만 관리한다.

## 추적 제외 디렉터리

`.gitignore`는 다음 로컬 산출물을 제외한다.

- `node_modules/`
- `docs/.vitepress/dist/`
- `docs/.vitepress/cache/`
- `graphify-out/`
- `.claude/worktrees/`
- `.planning/` 중 `.planning/codebase/`를 제외한 경로
- `.omx`
- `.DS_Store`

기본 브랜치 `.forge/`의 휘발 상태도 기본적으로 제외하며, 영속 경로만 whitelist로 다시 추적한다. `.forge/branch/`는 전체가 추적 대상이다.
