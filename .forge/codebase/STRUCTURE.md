---
last_mapped_commit: 21c8bdbf3b13543c1aec209669ec38b57f8f25e2
mapped: 2026-06-04
---

# forge 디렉터리 구조

## 개요

forge 리포지터리는 동시에 **플러그인 루트이자 마켓플레이스**다. 루트에서 모든 스킬 정의와 플러그인 매니페스트를 관리하며, `.forge/` 디렉터리는 루프의 모든 상태(휘발·영속)를 한곳에 모은다.

```
repo root/
├── .claude-plugin/          ← 플러그인 매니페스트
├── skills/                  ← 7개 스킬 디렉터리
├── .forge/                  ← 루프 상태 + 영속 문서 (통합)
├── .gitignore               ← .forge/ 선별 추적 규칙
├── CLAUDE.md                ← 개발 가이드
├── README.md                ← 영문 설명
├── README.ko.md             ← 한글 설명
└── CHANGELOG.md             ← 릴리스 노트
```

## `.claude-plugin/` 플러그인 매니페스트

```
.claude-plugin/
├── plugin.json              ← 플러그인 정의 (스킬 목록)
└── marketplace.json         ← 마켓플레이스 레지스트리 (이 리포 등록)
```

### `plugin.json`

```json
{
  "name": "forge",
  "description": "7개 스킬...",
  "version": "X.Y.Z",
  "author": {...},
  "homepage": "...",
  "repository": "...",
  "license": "MIT"
}
```

- **skills 필드**: 생략 가능 (`.claude-plugin/` 로더가 `skills/` 자동 탐색)
- **버전**: 배포 시 3곳을 반드시 동기 갱신 (`plugin.json` + `marketplace.json` × 2)

### `marketplace.json`

```json
{
  "plugins": [
    {
      "name": "forge",
      "source": "./",
      "version": "X.Y.Z",
      "description": "7개 스킬...",
      "metadata": {
        "description": "루프 정의: ask→execute→retro→cleanup",
        "version": "X.Y.Z"
      }
    }
  ]
}
```

- **source**: `"./"` (리포 루트가 곧 플러그인 루트)
- **metadata.description**: 루프 4단계만 정의 (루프 밖 유틸리티 언급 금지)
- **plugins[].description**: 모든 스킬 포함 (루프 밖도 포함)

## `skills/` 스킬 디렉터리

```
skills/
├── fg-ask/
│   ├── SKILL.md                 ← 스킬 정의 (verbatim grill-with-docs + forge integration)
│   ├── CONTEXT-FORMAT.md        ← CONTEXT.md 형식 (fg-ask 소유)
│   └── ADR-FORMAT.md            ← ADR 형식 (fg-ask 소유)
├── fg-run/
│   ├── SKILL.md                 ← 스킬 정의
│   └── PLAN-FORMAT.md           ← plan.md 형식 (fg-ask가 생산, fg-run이 소비)
├── fg-learn/
│   ├── SKILL.md                 ← 스킬 정의
│   └── RETRO-FORMAT.md          ← retro/*.md 형식 (fg-learn 소유)
├── fg-cleanup/
│   └── SKILL.md                 ← 스킬 정의
├── fg-map/
│   └── SKILL.md                 ← 스킬 정의 (루프 밖 유틸리티)
├── fg-quick/
│   └── SKILL.md                 ← 스킬 정의 (루프 밖 경량 차선)
└── fg-status/
    └── SKILL.md                 ← 스킬 정의 (루프 밖 리포터)
```

### 스킬 식별자

**스킬 이름은 디렉터리명이 아닌 SKILL.md의 frontmatter `name` 필드로 결정됨**:

```yaml
---
name: fg-ask
description: "..."
---
```

- **디렉터리명**: 조직적 편의 (예: `skills/fg-ask/`)
- **공식 스킬 ID**: `name:` 필드 (예: `fg-ask`)
- 매니페스트 자동 탐색은 `${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md` 경로 규칙

### 형식 문서 소유권

형식 정의는 **한 벌만 존재**, 소비자가 아닌 생산자 또는 스킬이 정의하는 쪽에 배치:

| 형식 | 소유 스킬 | 파일 |
|------|----------|------|
| CONTEXT.md | fg-ask | `skills/fg-ask/CONTEXT-FORMAT.md` |
| ADR | fg-ask | `skills/fg-ask/ADR-FORMAT.md` |
| plan.md | fg-run (생산: fg-ask, 소비: fg-run) | `skills/fg-run/PLAN-FORMAT.md` |
| retro | fg-learn | `skills/fg-learn/RETRO-FORMAT.md` |

**다른 스킬에서 참조할 때**:
- 상대 경로 (skill 디렉터리 기준): `../fg-ask/CONTEXT-FORMAT.md`
- 절대 경로: `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/CONTEXT-FORMAT.md`
- 자체 복사하지 않음 (형식 정의는 한 곳에서만 유지)

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
- **언어**: SKILL.md 파일 자체는 영문으로 작성 (grill-with-docs 원문 포함)
- **출력 언어**: 스킬이 사용자에게 내보내는 모든 문서(plan, retro, CONTEXT 갱신, ADR, 핸드오프)는 사용자 언어로 출력
- **Forge integration**: 루프 연결 로직(백로그 산출, 핸드오프, 상태 확인, re-grill 환류)을 명시적인 "Forge integration" 섹션에 정리

## `.forge/` 루프 상태 + 영속 문서 (단일 디렉터리)

모든 forge 산출물이 한곳에 모임. git 추적은 선별적:

```
.forge/
├── 휘발 상태 (git 제외, .gitignore)
│   ├── backlog/                    ← 미실행 계획 대기열
│   │   ├── settlement-payout-split.md
│   │   └── update-auth-schema.md
│   ├── plan.md                     ← 활성 슬롯 (현재 진행 중인 계획)
│   ├── run.md                      ← 활성 슬롯 (실행 결과)
│   ├── STATUS.md                   ← 활성 슬롯 (상태 마커)
│   ├── executed/
│   │   ├── add-logging-2026-06-04/
│   │   │   ├── plan.md
│   │   │   ├── run.md
│   │   │   └── STATUS.md
│   │   └── ...
│   └── done/
│       ├── 2026-06-04-add-feature/
│       │   ├── plan.md
│       │   ├── run.md
│       │   └── STATUS.md
│       ├── 2026-06-04-fix-auth/
│       └── ...
│
├── 영속 문서 (git 추적, .gitignore 화이트리스트)
│   ├── CONTEXT.md                  ← 도메인 용어 글로서리 (단일 컨텍스트)
│   ├── adr/
│   │   ├── 0001-docs-into-forge.md
│   │   ├── 0002-optional-retro-skip.md
│   │   └── 0003-fg-quick-lightweight-lane.md
│   ├── retro/
│   │   ├── 2026-06-04-fg-ask-adr-path-fix.md
│   │   └── 2026-06-04-optional-retro-skip.md
│   ├── codebase/                   ← fg-map 산출 (7개 문서)
│   │   ├── STACK.md
│   │   ├── INTEGRATIONS.md
│   │   ├── ARCHITECTURE.md
│   │   ├── STRUCTURE.md
│   │   ├── CONVENTIONS.md
│   │   ├── TESTING.md
│   │   └── CONCERNS.md
│   └── (CONTEXT-MAP.md — 멀티 컨텍스트 시에만, 루트에 위치)
│
└── quick/                          ← fg-quick 로그 (git 제외, 휘발)
    └── LOG.md
```

### .gitignore 선별 추적 패턴

```gitignore
.forge/*
!.forge/CONTEXT.md
!.forge/adr/
!.forge/retro/
!.forge/codebase/
```

**설명**:
- `.forge/*` — 모든 `.forge/` 내 항목을 기본 제외
- `!.forge/CONTEXT.md` — 단일 파일 화이트리스트 (CONTEXT.md만)
- `!.forge/adr/` — 디렉터리 화이트리스트 (adr 안의 모든 파일)
- `!.forge/retro/` — 디렉터리 화이트리스트 (retro 안의 모든 파일)
- `!.forge/codebase/` — 디렉터리 화이트리스트 (codebase 안의 모든 파일)

**중요**: `.forge/` 자체를 ignore하면 (`.forge/` 아닌 `.forge/*`) 내부 `!` 화이트리스트가 작동함.

### 휘발 상태의 생명주기

**backlog/ → plan.md → run.md → executed/ 또는 done/**

1. **fg-ask**: `.forge/backlog/<slug>.md` 생성 (미실행 계획)
2. **fg-run**: `backlog/<slug>.md` → `.forge/plan.md` 승격 (활성 슬롯)
3. **fg-run**: `.forge/run.md` 기록 (실행 결과)
4. **fg-run**: `.forge/STATUS.md` 기록 (`status: executed`)
5. **[Run all 경우]**: plan/run/STATUS → `.forge/executed/<slug>/` 주차 (활성 슬롯 비움)
6. **fg-learn**: 회고 기록 → `.forge/retro/YYYY-MM-DD-<slug>.md`
7. **fg-cleanup**: plan/run/STATUS → `.forge/done/YYYY-MM-DD-<slug>/` 이동
8. **fg-cleanup**: `.forge/plan.md` 삭제 (활성 슬롯 비움, 재실행 방지)

### 영속 문서의 이름 규칙

| 문서 타입 | 파일명 패턴 | 예시 |
|----------|-----------|------|
| CONTEXT | `CONTEXT.md` (고정) | `.forge/CONTEXT.md` |
| ADR | `NNNN-slug.md` (4자리 + slug) | `.forge/adr/0001-docs-into-forge.md` |
| Retro | `YYYY-MM-DD-slug.md` (날짜 + slug) | `.forge/retro/2026-06-04-settlement-payout.md` |
| 코드베이스 지도 | 영문 고정명 | `.forge/codebase/STACK.md`, `ARCHITECTURE.md` 등 |
| Quick LOG | `LOG.md` (고정) | `.forge/quick/LOG.md` |

**slug 이름 규칙**:
- **kebab-case**: 소문자, 하이픈 구분자
- **충돌 시**: `-2`, `-3` 등 접미사 추가
- **예**: `settlement-payout-split`, `update-auth-schema-2`

### 멀티 컨텍스트 예외

단일 컨텍스트 (가장 일반적):
```
.forge/
└── CONTEXT.md          ← 도메인 글로서리
```

멀티 컨텍스트:
```
src/
├── ordering/
│   └── CONTEXT.md      ← ordering 컨텍스트 용어
├── billing/
│   └── CONTEXT.md      ← billing 컨텍스트 용어

.forge/
├── adr/                ← 모든 ADR (단일 위치)
└── retro/              ← 모든 retro (단일 위치)

CONTEXT-MAP.md          ← 루트 (컨텍스트별 CONTEXT.md 위치 지도)
```

**규칙**:
- **컨텍스트 CONTEXT.md**: 각 컨텍스트 코드 옆에 배치 (`.forge/` 외)
- **통합 맵**: `CONTEXT-MAP.md` (루트에만, `.forge/` 제외)
- **ADR/retro**: `.forge/adr/`, `.forge/retro/` (모든 컨텍스트 통합)

## 루트 레벨 문서

```
forge/
├── CLAUDE.md            ← 개발 가이드 (한글)
│                          - 리포 소개
│                          - 패키징 구조
│                          - 핵심 아키텍처 (루프 요약)
│                          - 상태 계약
│                          - 설계 원칙
│                          - 스킬 편집 규약
│                          - 배포 규칙
│                          - 현재 알려진 불일치
│
├── README.md            ← 영문 사용자 가이드
├── README.ko.md         ← 한글 사용자 가이드 (README.md 번역)
│                          [동기화 유지: 하나 갱신 → 반드시 다른 쪽도]
│
├── forge-prd.md         ← 옛 설계 초안 (신뢰 금지)
│
├── CHANGELOG.md         ← 릴리스 노트 (배포 시 갱신)
│
├── .gitignore           ← git 추적 규칙
│                          - .forge/* 제외, 영속 문서만 화이트리스트
│
└── .claude-plugin/      ← 플러그인 매니페스트
    ├── plugin.json
    └── marketplace.json
```

### 문서 유지 규칙

- **CLAUDE.md**: 개발자용. forge의 작동·계약·규약을 정의
- **README.md / README.ko.md**: 사용자용. 한 쪽 갱신 시 다른 쪽도 동일하게 갱신 (이중언어 동기화)
- **forge-prd.md**: 옛 설계. 신뢰하지 말 것
- **CHANGELOG.md**: Keep a Changelog 형식. 배포마다 수동 갱신

## 배포 아티팩트

배포 과정에서 갱신되는 파일들 (3곳 버전 동기):

| 파일 | 필드 | 규칙 |
|------|------|------|
| `.claude-plugin/plugin.json` | `version` | `X.Y.Z` |
| `.claude-plugin/marketplace.json` | `plugins[0].version` | `X.Y.Z` |
| `.claude-plugin/marketplace.json` | `metadata.version` | `X.Y.Z` |

**배포 절차**:
1. CHANGELOG.md 갱신
2. 버전 3곳 범프 (patch/minor/major)
3. JSON 유효성 검증
4. 커밋 (`chore(release): vX.Y.Z`)
5. main 브랜치로 push

## 내부 명명 규칙

### 스킬 디렉터리

- **명명**: `fg-<stage-or-utility>` (kebab-case)
- **예**: `fg-ask`, `fg-run`, `fg-learn`, `fg-cleanup`, `fg-map`, `fg-quick`, `fg-status`
- **프리픽스**: `fg-` (forge 스킬 표시)

### 작업 slug

- **명명**: 작업 제목의 kebab-case 축약
- **예**: `settlement-payout-split`, `update-auth-schema`, `fix-cors-issue`
- **충돌**: `-2`, `-3` 등 숫자 접미사 추가

### 파일명 시간 접미사

- **형식**: `YYYY-MM-DD-slug` (ISO 8601 날짜 + slug)
- **사용처**: `.forge/retro/`, `.forge/done/`
- **예**: `2026-06-04-settlement-payout.md`, `2026-06-04-fix-cors-issue/`

### 아키텍처 결정 번호

- **형식**: `NNNN-slug.md` (4자리 0-패딩 + slug)
- **예**: `0001-docs-into-forge.md`, `0002-optional-retro-skip.md`
- **위치**: `.forge/adr/`

## 파일 참조 규칙

### 절대 경로 vs 상대 경로

**SKILL.md 내에서**:
- 절대: `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/CONTEXT-FORMAT.md`
- 상대: `../fg-ask/CONTEXT-FORMAT.md` (같은 skills/ 안에서)

**형식 문서 참조**:
- 항상 한 벌 존재, 생산자/소유자 위치 참조
- 자체 복사 금지 (중복 유지의 부담)

### 코드베이스 지도의 경로 포함 규칙

`.forge/codebase/` 7개 문서는 **실제 파일 경로를 항상 백틱 포함**:
```markdown
`src/services/auth.ts`
`config/database.yml`
```

이유: 지도는 참고 자료이므로 구체적인 위치가 중요.

## 상태 검사 명령어

개발 시 수동 검증:

```bash
# JSON 매니페스트 유효성
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"

# .forge/ 파일 구조 확인
ls -la .forge/

# git 추적 확인 (영속 문서만)
git status .forge/

# .gitignore 규칙 확인
git check-ignore -v .forge/*
```
