---
last_mapped_commit: 41c10d7cb477eddab9b7d0f1aa8bd23bbcf34d98
mapped_date: 2026-06-09
---

# forge 디렉터리 구조

## 개요

forge 리포지터리는 동시에 **플러그인 루트이자 마켓플레이스**다(harness 플러그인과 동일 패턴). 루트에서 모든 스킬 정의와 플러그인 매니페스트를 관리하며, `.forge/` 디렉터리는 루프의 모든 상태(휘발·영속)를 한곳에 모은다. **빌드·테스트·린트 시스템이 없다** — 산출물은 전부 Markdown(SKILL.md, 형식 문서)과 JSON(매니페스트)이다.

```
repo root/
├── .claude-plugin/          ← 플러그인 매니페스트
├── skills/                  ← 11개 스킬 디렉터리
├── .forge/                  ← 루프 상태 + 영속 문서 (통합)
├── .gitignore               ← .forge/ 선별 추적 규칙
├── CLAUDE.md                ← 개발 가이드 (한글)
├── README.md                ← 영문 설명
├── README.ko.md             ← 한글 설명
├── CHANGELOG.md             ← 릴리스 노트
└── forge-prd.md             ← 옛 설계 초안 (신뢰 금지)
```

## `.claude-plugin/` 플러그인 매니페스트

```
.claude-plugin/
├── plugin.json              ← 플러그인 정의 (스킬 목록 설명 포함)
└── marketplace.json         ← 마켓플레이스 레지스트리 (이 리포 등록)
```

### `plugin.json`

```json
{
  "name": "forge",
  "description": "11개 스킬...",
  "version": "X.Y.Z",
  "author": {...},
  "homepage": "...",
  "repository": "...",
  "license": "MIT",
  "keywords": [...]
}
```

- **skills 필드**: 생략 가능 (`skills/` 자동 탐색)
- **버전**: 배포 시 3곳을 반드시 동기 갱신 (`plugin.json`의 `version` + `marketplace.json`의 `metadata.version`·`plugins[0].version`)

### `marketplace.json`

```json
{
  "name": "forge",
  "owner": {...},
  "metadata": {
    "description": "루프 정의: ask·plan → execute → retro → done",
    "version": "X.Y.Z"
  },
  "plugins": [
    {
      "name": "forge",
      "source": "./",
      "description": "11개 스킬 (루프 4 + 루프 밖 7)...",
      "version": "X.Y.Z",
      "category": "workflow",
      "tags": [...]
    }
  ]
}
```

- **source**: `"./"` (리포 루트가 곧 플러그인 루트)
- **metadata.description**: 루프 4단계만 정의 (루프 밖 유틸리티 언급 금지 — 루프 정의를 흐리지 않기 위해)
- **plugins[].description**: 모든 스킬 포함 (루프 밖 7개도 포함)

## `skills/` 스킬 디렉터리 (11개)

```
skills/
├── fg-ask/
│   ├── SKILL.md                 ← 스킬 정의 (verbatim grill-with-docs + forge integration)
│   ├── CONTEXT-FORMAT.md        ← CONTEXT.md 형식 (fg-ask 소유)
│   └── ADR-FORMAT.md            ← ADR 형식 (fg-ask 소유)
├── fg-run/
│   ├── SKILL.md                 ← 스킬 정의
│   ├── PLAN-FORMAT.md           ← plan.md 형식 (생산: fg-ask, 소비: fg-run)
│   └── FORGE-ROOT.md            ← forge 루트 해석 규칙 단일 정의 (ADR-0011, 모든 루프 스킬 참조)
├── fg-learn/
│   ├── SKILL.md                 ← 스킬 정의
│   └── RETRO-FORMAT.md          ← retro/*.md 형식 (fg-learn 소유)
├── fg-done/
│   └── SKILL.md                 ← ④봉인 단계 (구 fg-cleanup, ADR-0012로 개명)
├── fg-cleanup/
│   └── SKILL.md                 ← ADR 은퇴 유틸리티 (루프 밖, ADR-0012)
├── fg-map/
│   └── SKILL.md                 ← 코드베이스 지도 (루프 밖)
├── fg-quick/
│   └── SKILL.md                 ← 경량 차선 (루프 밖)
├── fg-status/
│   └── SKILL.md                 ← 읽기 전용 리포터 (루프 밖)
├── fg-next/
│   └── SKILL.md                 ← 오케스트레이터 (루프 밖, ADR-0010)
├── fg-tdd/
│   └── SKILL.md                 ← TDD 모드 토글 (루프 밖, ADR-0008)
└── fg-merge/
    └── SKILL.md                 ← 브랜치 통합 (루프 밖, ADR-0011)
```

루프 4단계: `fg-ask` → `fg-run` → `fg-learn` → `fg-done`. 루프 밖 7개: `fg-map`, `fg-quick`, `fg-status`, `fg-next`, `fg-tdd`, `fg-merge`, `fg-cleanup`.

### 스킬 식별자

**스킬 이름은 디렉터리명이 아닌 SKILL.md frontmatter의 `name` 필드로 결정됨**:

```yaml
---
name: fg-ask
description: "..."
---
```

- **디렉터리명**: 조직적 편의
- **공식 스킬 ID**: `name:` 필드
- 자동 탐색은 `${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md` 경로 규칙

### 형식 문서 소유권

형식 정의는 **한 벌만 존재**하며 소유 스킬 디렉터리에 둔다. 다른 스킬은 복사하지 않고 참조한다:

| 형식 | 소유 스킬 | 파일 |
|------|----------|------|
| CONTEXT.md | fg-ask | `skills/fg-ask/CONTEXT-FORMAT.md` |
| ADR | fg-ask | `skills/fg-ask/ADR-FORMAT.md` |
| plan.md | fg-run (생산: fg-ask, 소비: fg-run) | `skills/fg-run/PLAN-FORMAT.md` |
| retro | fg-learn | `skills/fg-learn/RETRO-FORMAT.md` |
| forge 루트 해석 | fg-run | `skills/fg-run/FORGE-ROOT.md` |

**참조 방식**: 상대 경로 `../fg-ask/CONTEXT-FORMAT.md` 또는 절대 `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/CONTEXT-FORMAT.md`. 자체 복사 금지. 루트 `references/` 디렉터리는 폐지됨.

### SKILL.md 구조

```markdown
---
name: fg-ask
description: "..."
---

# <what-to-do> ... </what-to-do>
# <supporting-info> ... </supporting-info>

---

## Forge integration (minimal)
...
```

**규칙**:
- **언어**: SKILL.md·형식 문서는 영문 (grill-with-docs 원문 포함)
- **출력 언어**: 스킬이 사용자에게 내보내는 모든 문서(plan, retro, CONTEXT, ADR, 핸드오프)는 사용자 언어
- **흐름도**: SKILL.md 안에서는 Mermaid 금지, 텍스트 흐름도(`A → B → C`)로만 작성 (에이전트가 파싱·diff·grep)
- **Forge integration**: fg-ask는 verbatim 본문 아래 "Forge integration (minimal)" 섹션에 루프 연결을 둠

## forge 루트의 위치 — 브랜치 격리 (ADR-0011)

아래 트리는 **기본 브랜치(`.forge/`)** 기준이다. 비-기본 브랜치에서는 backlog/plan/run/STATUS/executed/done/adr/retro/CONTEXT.md가 모두 `.forge/branch/<branch>/` 아래로 네임스페이스된다(슬래시 브랜치명은 중첩 디렉터리: `feature/x` → `.forge/branch/feature/x/`). **두 전역 예외** — `.forge/config.json`과 `.forge/codebase/` — 는 어느 브랜치에서도 항상 최상위 `.forge/`에 있다.

```
.forge/
├── 휘발 상태 (기본 브랜치: git 제외)
│   ├── backlog/                    ← 미실행 계획 대기열
│   │   ├── settlement-payout-split.md
│   │   └── update-auth-schema.md
│   ├── plan.md                     ← 활성 슬롯 (현재 진행 중인 계획)
│   ├── run.md                      ← 활성 슬롯 (실행 결과)
│   ├── STATUS.md                   ← 활성 슬롯 (상태 마커)
│   ├── executed/
│   │   └── <slug>/                 ← Run all 임시 주차 (plan/run/STATUS)
│   ├── done/
│   │   └── YYYY-MM-DD-<slug>/       ← 봉인 아카이브 (plan/run/STATUS, status: done)
│   ├── quick/
│   │   └── LOG.md                  ← fg-quick 로그 (휘발)
│   └── branch/                     ← 비-기본 브랜치의 forge 루트 (git 추적!)
│       └── <branch>/               ← backlog/plan/run/STATUS/executed/done/adr/retro/CONTEXT.md
│
└── 영속 문서 (git 추적, .gitignore 화이트리스트)
    ├── CONTEXT.md                  ← 도메인 용어 글로서리 (단일 컨텍스트)
    ├── config.json                 ← 전역 설정 (defaultBranch, tdd) — 전역 경로
    ├── adr/
    │   ├── 0001-docs-into-forge.md
    │   ├── ...
    │   ├── 0013-defer-subagents-fg-map-and-stage-separation-suffice.md
    │   └── retired/                ← fg-cleanup이 은퇴시킨 ADR (ADR-0012)
    ├── retro/
    │   └── YYYY-MM-DD-<slug>.md
    └── codebase/                   ← fg-map 산출 (7개 문서) — 전역 경로
        ├── STACK.md
        ├── INTEGRATIONS.md
        ├── ARCHITECTURE.md
        ├── STRUCTURE.md
        ├── CONVENTIONS.md
        ├── TESTING.md
        └── CONCERNS.md
```

현재 ADR은 `0001`–`0013` 13개(`.forge/adr/`). 멀티 컨텍스트 시 `CONTEXT-MAP.md`는 루트, 컨텍스트별 `CONTEXT.md`는 `src/<context>/`에 둠(`.forge/` 통합 대상 아님).

### .gitignore 선별 추적 패턴

```gitignore
.forge/*
!.forge/CONTEXT.md
!.forge/adr/
!.forge/retro/
!.forge/codebase/
!.forge/config.json
!.forge/branch/
.claude/worktrees

.planning/
!.planning/codebase/

.DS_Store
```

**설명**:
- `.forge/*` — 모든 `.forge/` 내 항목을 기본 제외
- `!.forge/CONTEXT.md` · `!.forge/adr/` · `!.forge/retro/` · `!.forge/codebase/` · `!.forge/config.json` — 영속 문서·설정 화이트리스트
- `!.forge/branch/` — **비-기본 브랜치의 forge 루트 전체를 화이트리스트** (휘발 상태 포함 통째로 추적, ADR-0011). 경로가 브랜치별로 네임스페이스되어 머지 충돌이 없고 fg-merge로 `.forge/`에 통합. 기본 브랜치 휘발 상태는 gitignored 유지 — 의도된 비대칭

### 휘발 상태의 생명주기

**backlog/ → plan.md → run.md → (verify) → executed/ 또는 done/**

1. **fg-ask**: `.forge/backlog/<slug>.md` 생성 (미실행 계획)
2. **fg-run**: `backlog/<slug>.md` → `.forge/plan.md` 승격 (활성 슬롯)
3. **fg-run**: `.forge/run.md` 기록 (실행 결과)
4. **fg-run**: `.forge/STATUS.md` 기록 (`status: executed`, `verified: pending`, `retro: pending`)
5. **fg-run (verify)**: 핸드오프 UAT로 `verified:`를 `yes`/`skipped`/`n/a`(봉인 가능) 또는 `failed`(차단)로 기록 (순서 run → verify → learn → done, ADR-0009)
6. **[Run all]**: 각 작업 UAT 후 sealable만 plan/run/STATUS → `.forge/executed/<slug>/` 주차 (활성 슬롯 비움); `failed`은 주차 안 하고 active slot에 남겨 fix-and-re-run
7. **fg-learn**: (sealable일 때만) 회고 기록 → `.forge/retro/YYYY-MM-DD-<slug>.md`
8. **fg-done**: (검증 가드 통과 후) plan/run/STATUS → `.forge/done/YYYY-MM-DD-<slug>/`, `status: done` 마감
9. **fg-done**: `.forge/plan.md` 삭제 (활성 슬롯 비움, 재실행 방지)

### 영속 문서의 이름 규칙

| 문서 타입 | 파일명 패턴 | 예시 |
|----------|-----------|------|
| CONTEXT | `CONTEXT.md` (고정) | `.forge/CONTEXT.md` |
| ADR | `NNNN-slug.md` (4자리 + slug) | `.forge/adr/0001-docs-into-forge.md` |
| 은퇴 ADR | `NNNN-slug.md` (번호 불변) | `.forge/adr/retired/0003-fg-quick-lightweight-lane.md` |
| Retro | `YYYY-MM-DD-slug.md` | `.forge/retro/2026-06-04-settlement-payout.md` |
| 코드베이스 지도 | 영문 고정명 | `.forge/codebase/STACK.md` 등 |
| 설정 | `config.json` (고정) | `.forge/config.json` |
| Quick LOG | `LOG.md` (고정) | `.forge/quick/LOG.md` |

**slug 이름 규칙**: kebab-case 소문자, 충돌 시 `-2`/`-3` 접미. ADR 번호는 단조 증가하며 재사용·재배열하지 않음 (ADR-0005, 은퇴해도 번호 불변 ADR-0012).

### 멀티 컨텍스트 예외

단일 컨텍스트(일반): `.forge/CONTEXT.md` 하나.

멀티 컨텍스트:
```
src/
├── ordering/CONTEXT.md      ← ordering 컨텍스트 용어 (코드 옆)
└── billing/CONTEXT.md       ← billing 컨텍스트 용어 (코드 옆)

CONTEXT-MAP.md               ← 루트 (컨텍스트별 위치 지도)

.forge/
├── adr/                     ← 모든 ADR (단일 위치)
└── retro/                   ← 모든 retro (단일 위치)
```

## 루트 레벨 문서

```
forge/
├── CLAUDE.md            ← 개발 가이드 (한글): 리포 소개·패키징·아키텍처·상태 계약·설계 원칙·편집 규약·배포 규칙·알려진 불일치
├── README.md            ← 영문 사용자 가이드
├── README.ko.md         ← 한글 사용자 가이드 (README.md 번역 쌍)
│                          [동기화 유지: 한쪽 갱신 시 반드시 다른 쪽도]
├── CHANGELOG.md         ← 릴리스 노트 (Keep a Changelog 약식, 배포 시 갱신)
├── forge-prd.md         ← 옛 설계 초안 (스킬 5개·fg-complete 등 옛 이름 — 신뢰 금지)
├── .gitignore           ← git 추적 규칙
└── .claude-plugin/
    ├── plugin.json
    └── marketplace.json
```

- **forge-prd.md**는 옛 설계 초안이다 — 본문은 "스킬 5개"라 하고 다이어그램은 4단계만(fg-ask→fg-run→fg-learn→**fg-complete**) 나열하며 ④를 옛 이름 `fg-complete`로 가리킨다. 명세로 신뢰하지 말 것. 실제 기준은 `skills/`와 `README.md`.

## 내부 명명 규칙

- **스킬 디렉터리**: `fg-<stage-or-utility>` (kebab-case, `fg-` 프리픽스)
- **작업 slug**: 작업 제목의 kebab-case 축약, 충돌 시 숫자 접미
- **파일명 시간 접미**: `YYYY-MM-DD-slug` (ISO 8601 날짜 + slug) — `.forge/retro/`·`.forge/done/`
- **ADR 번호**: `NNNN-slug.md` (4자리 0-패딩) — `.forge/adr/`, 단조 증가

## 코드베이스 지도의 경로 포함 규칙

`.forge/codebase/` 7개 문서는 **실제 파일 경로를 항상 백틱 포함**(`src/services/auth.ts`). 지도는 참고 자료이므로 구체적 위치가 중요. 도메인 용어 정의는 하지 않음(CONTEXT.md의 역할).

## 검증 명령어 (빌드/테스트 없음)

```bash
# JSON 매니페스트 유효성 (편집 후 반드시 — 깨지면 설치 실패)
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"

# .forge/ 파일 구조 / git 추적 / ignore 규칙 확인
ls -la .forge/
git status .forge/
git check-ignore -v .forge/*

# 배포 후 원격 main 버전 3곳 확인 + SKILL.md frontmatter name 누락 확인
curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/plugin.json
awk '/^name:/' skills/*/SKILL.md
```

## 배포 아티팩트 (3곳 버전 동기)

| 파일 | 필드 |
|------|------|
| `.claude-plugin/plugin.json` | `version` |
| `.claude-plugin/marketplace.json` | `plugins[0].version` |
| `.claude-plugin/marketplace.json` | `metadata.version` |

**절차**: CHANGELOG.md 갱신 → 버전 3곳 범프(기본 patch) → JSON 검증 → 커밋(`chore(release): vX.Y.Z`) → main push (설치가 main을 당기므로 push까지가 배포).
