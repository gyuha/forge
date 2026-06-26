---
last_mapped_commit: 2059a08bee17a9fbb97e6e938958f5ed813bdb2d
mapped: 2026-06-26
---

# forge 디렉터리 구조

## 리포 루트

```
/Users/gyuha/workspace/forge/
├── .claude-plugin/
│   ├── plugin.json          ← 플러그인 매니페스트 (name, version, description, author)
│   └── marketplace.json     ← 마켓플레이스 등록 (metadata.version + plugins[0].version)
├── skills/                  ← 18개 스킬 (디렉터리별 1개)
│   └── <name>/SKILL.md
├── docs/                    ← 사용자 문서
│   ├── skills.md
│   ├── state-contract.md
│   └── forge-vs-loop-engineering.md
├── scripts/                 ← 결정론적 스크립트 (ADR-0022)
│   ├── resolve-forge-root.sh / .js
│   ├── forge-status.sh / .js
│   └── forge-statusline.sh / .js (+ wrapper, parity tests)
├── README.md                ← 영문 문서
├── README.ko.md             ← 한글 문서 (README.md 번역 쌍 — 항상 동기)
├── CLAUDE.md                ← 프로젝트 지침 (Claude Code용)
└── CHANGELOG.md
```

## `.claude-plugin/` — 플러그인 패키징

- `plugin.json` — `version` 필드 + `description` (전 스킬 목록 포함). `skills/` 는 자동 탐색되므로 `skills` 배열 생략 가능.
- `marketplace.json` — `metadata.version` + `plugins[0].version` + `plugins[0].description`. **버전은 3곳 동기 필수**: `plugin.json:version`, `marketplace.json:metadata.version`, `marketplace.json:plugins[0].version`.
- `marketplace.json:metadata.description` 은 루프 정의 태그라인 (루프 밖 유틸리티 제외).
- 스킬 식별자 = frontmatter `name` (디렉터리명 아님).

## `skills/` — 18개 스킬

### 루프 4단계

| 디렉터리 | frontmatter `name` | 역할 |
|----------|-------------------|------|
| `skills/fg-ask/` | `fg-ask` | 대화형 그릴링 + 계획 작성 — 루프 ① 진입점 |
| `skills/fg-run/` | `fg-run` | Dynamic Workflow 실행 + UAT 검증 — 루프 ② |
| `skills/fg-learn/` | `fg-learn` | 회고 분류 + 학습 승급 — 루프 ③ |
| `skills/fg-done/` | `fg-done` | 봉인·정리·활성 슬롯 비우기 — 루프 ④ |

### 루프 밖 유틸리티 14개

| 디렉터리 | frontmatter `name` | 역할 |
|----------|-------------------|------|
| `skills/fg-map/` | `fg-map` | 코드베이스를 병렬 서브에이전트로 `.forge/codebase/` 7문서에 매핑 |
| `skills/fg-quick/` | `fg-quick` | trivial 작업 경량 차선 — 그릴링 유지, 형식 산출물 없음, `quick/LOG.md` 한 줄만 |
| `skills/fg-status/` | `fg-status` | 읽기 전용 상태 보고 + 다음 단계 도출 — 아무것도 쓰지 않음 |
| `skills/fg-next/` | `fg-next` | fg-status 상태 머신으로 다음 단계 도출 후 즉시 실행. `all` 모드: 벽까지 자동 진행 |
| `skills/fg-loop/` | `fg-loop` | 목표 주도 유한 재계획 루프 — `loop.md` 에 정지 체크·재계획 상한 고정 후 자동 주행 |
| `skills/fg-tdd/` | `fg-tdd` | TDD 모드 토글 — `.forge/config.json:tdd` 읽기/쓰기 |
| `skills/fg-eco/` | `fg-eco` | Eco 모드 토글 — `.forge/config.json:eco` + `ECO.md` 규율 활성화 |
| `skills/fg-merge/` | `fg-merge` | git merge 후 `.forge/branch/<branch>/` 를 `.forge/` 에 통합 (ADR 재번호·CONTEXT 병합) |
| `skills/fg-cleanup/` | `fg-cleanup` | 폐기된 ADR을 `.forge/adr/retired/` 로 은퇴 — 번호 불변·삭제 안 함 |
| `skills/fg-statusline/` | `fg-statusline` | forge 진행 상태를 터미널 statusline에 표시하도록 스크립트 설치 + `settings.json` 연결 |
| `skills/fg-adversarial-review/` | `fg-adversarial-review` | fg-run ↔ fg-learn 사이 선택적 적대적 리뷰 — 6개 렌즈 병렬 팬아웃, `review.md` 기록 |
| `skills/fg-doctor/` | `fg-doctor` | `.forge/` 상태 계약 + 문서/매니페스트 무결성 점검 — 읽기 전용 |
| `skills/fg-drop/` | `fg-drop` | 미완 작업(백로그·활성 슬롯·executed·loop) 폐기 또는 `.forge/dropped/` 보관 |
| `skills/fg-agents/` | `fg-agents` | 대화형 그릴링으로 프로젝트 도메인 에이전트 `.claude/agents/<role>.md` 생성 |

## 형식 문서 위치

각 형식은 소유 스킬 디렉터리에 단일본으로 존재한다. 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유-스킬>/<파일>` 로 참조하고 복사하지 않는다.

| 파일 | 소유 스킬 | 역할 |
|------|----------|------|
| `skills/fg-ask/CONTEXT-FORMAT.md` | fg-ask | CONTEXT.md 용어 항목 형식 |
| `skills/fg-ask/ADR-FORMAT.md` | fg-ask | ADR 문서 형식 |
| `skills/fg-run/PLAN-FORMAT.md` | fg-run | plan.md 형식 + 분할 규칙 |
| `skills/fg-run/FORGE-ROOT.md` | fg-run | forge root 분기 결정론적 규칙 (단일 정의) |
| `skills/fg-run/RUN-ALL.md` | fg-run | "Run all" 배치 모드 절차 |
| `skills/fg-learn/RETRO-FORMAT.md` | fg-learn | 회고 문서 형식 |
| `skills/fg-eco/ECO.md` | fg-eco | Eco laziness-first 규율 (fg-run 서브에이전트 주입용) |

루트 `references/` 디렉터리는 폐지됐다. 모든 형식 문서는 소유 스킬 디렉터리에만 있다.

## `.forge/` — 상태 + 영속 문서

`.gitignore` 가 `.forge/*` 를 기본 제외하고, 영속 문서만 화이트리스트로 git 추적한다.

```
.forge/
├── config.json              ← 전역 설정 (tdd, eco, defaultBranch) — 모든 브랜치 공유
├── codebase/                ← fg-map 생성 맵 7문서 — 모든 브랜치 공유
│   ├── ARCHITECTURE.md
│   ├── STRUCTURE.md
│   ├── STACK.md
│   ├── CONVENTIONS.md
│   ├── INTEGRATIONS.md
│   ├── CONCERNS.md
│   └── TESTING.md
├── CONTEXT.md               ← 도메인 글로서리 (git 추적)
├── adr/                     ← 아키텍처 결정 (git 추적)
│   ├── NNNN-slug.md
│   └── retired/NNNN-slug.md
├── retro/                   ← 회고 로그 (git 추적)
│   └── YYYY-MM-DD-slug.md
│
├── backlog/                 ← 미실행 계획 대기열 (gitignored)
│   └── <slug>.md
├── plan.md                  ← 활성 슬롯 (gitignored)
├── run.md                   ← 실행 기록 (gitignored)
├── review.md                ← 적대적 리뷰 findings (gitignored, 선택적)
├── STATUS.md                ← 활성 슬롯 동반 마커 (gitignored)
├── executed/                ← 실행됐으나 미회고 (gitignored)
│   └── <slug>/plan.md, run.md, STATUS.md
├── done/                    ← 봉인 완료 아카이브 (gitignored)
│   └── <날짜-slug>/plan.md, run.md, STATUS.md
├── quick/                   ← fg-quick 경량 로그 (gitignored)
│   └── LOG.md
├── dropped/                 ← fg-drop 보관 (gitignored)
│   └── <slug>/
└── branch/                  ← 비-기본 브랜치 forge root (git 추적)
    └── <branch>/            ← 구조 동일 (backlog/plan/run/STATUS/executed/done/adr/retro/CONTEXT.md)
```

## 명명 규칙

| 대상 | 규칙 | 예시 |
|------|------|------|
| 스킬 식별자 | frontmatter `name` (디렉터리명 아님) | `fg-run` |
| plan slug | kebab-case, `<!-- forge-slug: ... -->` 로 고정 | `add-oauth-login` |
| ADR 파일 | `NNNN-slug.md` (4자리 단조 증가, 재사용 금지) | `0024-fg-agents-and-domain-agent-execution.md` |
| done 디렉터리 | `YYYY-MM-DD-<slug>/` | `2026-06-26-add-oauth-login/` |
| retro 파일 | `YYYY-MM-DD-<slug>.md` | `2026-06-26-add-oauth-login.md` |
| 도메인 에이전트 | `.claude/agents/<role>.md`, frontmatter `name` = kebab-case ASCII | `backend-api.md` |

## 버전 관리

배포 시 3곳 동기 필수:
- `.claude-plugin/plugin.json` — `version`
- `.claude-plugin/marketplace.json` — `metadata.version`
- `.claude-plugin/marketplace.json` — `plugins[0].version`

검증 명령:
```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

## `scripts/` — 결정론적 구현 (ADR-0022)

이중 디스패치: bash 우선, node 폴백 (PowerShell 환경 호환).

| 스크립트 | 역할 |
|----------|------|
| `resolve-forge-root.sh` / `.js` | forge root 분기 결정 — 모든 루프 스킬이 참조 |
| `forge-status.sh` / `.js` | `.forge/` 상태 한 줄 출력 (fg-statusline이 호출) |
| `forge-statusline.sh` / `.js` | 터미널 statusline 출력 |
| `forge-statusline-wrapper.sh` | 기존 statusLine 래핑 (덮어쓰기 방지) |
| `*.parity.test.sh` | bash ↔ node 동등성 검증 |
