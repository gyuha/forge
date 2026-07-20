---
last_mapped_commit: 553484ae395d6ca3df973f5b0cf5762029fd94ec
mapped: 2026-07-20
---

# STRUCTURE

## 최상위 디렉터리 레이아웃

```
forge-visual-compose/            (리포 루트 = 플러그인 루트 = 마켓플레이스 루트)
├── .claude-plugin/              매니페스트 2종
│   ├── plugin.json              플러그인 매니페스트 (version 0.5.18, skills 자동탐색)
│   └── marketplace.json         마켓플레이스 등록 (metadata.version + plugins[0].version)
├── skills/                      19개 fg-* 스킬 (각 <name>/SKILL.md + 소유 문서/스크립트)
├── scripts/                     결정론 셸+노드 트윈 스크립트 + 테스트
├── .forge/                      forge 루프 상태 (휘발) + 영속 문서 (git 추적 분리)
├── docs/                        사용자 문서 + GitHub Pages 랜딩(index.html) + 자산
├── .claude/                     이 리포 자신의 Claude 자산 (agents/, skills/)
├── CLAUDE.md                    아키텍처 정본 (권위 문서)
├── README.md / README.ko.md     이중언어 번역 쌍 (동기 갱신 필수)
├── CHANGELOG.md                 Keep a Changelog 약식
├── .gitignore / .gitattributes  forge 화이트리스트 규칙 / .sh LF 강제
└── .git                         (gitdir 파일 — worktree)
```

`references/` 디렉터리는 **폐지됨**(존재하지 않음). 형식 문서는 소유 스킬 디렉터리로 이동했다.

## `skills/` — 19개 스킬 (frontmatter `name:` = 스킬 식별자)

디렉터리명과 frontmatter `name:`이 모두 일치한다(확인함). 각 스킬은 `SKILL.md` 하나 + 자기가 소유한 형식/규율 문서·스크립트를 담는다.

| 디렉터리 | frontmatter name | 동반 소유 파일 |
| --- | --- | --- |
| `skills/fg-ask/` | fg-ask | `CONTEXT-FORMAT.md`, `ADR-FORMAT.md` |
| `skills/fg-run/` | fg-run | `PLAN-FORMAT.md`, `RUN-ALL.md`, `FORGE-ROOT.md` |
| `skills/fg-learn/` | fg-learn | `RETRO-FORMAT.md` |
| `skills/fg-done/` | fg-done | — |
| `skills/fg-map/` | fg-map | — |
| `skills/fg-status/` | fg-status | — |
| `skills/fg-next/` | fg-next | `DRIVE.md` |
| `skills/fg-loop/` | fg-loop | — |
| `skills/fg-merge/` | fg-merge | — |
| `skills/fg-cleanup/` | fg-cleanup | — |
| `skills/fg-quick/` | fg-quick | — |
| `skills/fg-doctor/` | fg-doctor | — |
| `skills/fg-drop/` | fg-drop | — |
| `skills/fg-agents/` | fg-agents | — |
| `skills/fg-tdd/` | fg-tdd | — |
| `skills/fg-eco/` | fg-eco | `ECO.md` |
| `skills/fg-adversarial-review/` | fg-adversarial-review | — |
| `skills/fg-statusline/` | fg-statusline | — |
| `skills/fg-visual/` | fg-visual | `VISUAL.md`, `LICENSE`, `scripts/`(server.cjs·start-server.sh·stop-server.sh·helper.js·frame-template.html) |

**개수 확인:** `ls -1 skills/*/SKILL.md | wc -l` = **19**. 매니페스트(`plugin.json`·`marketplace.json`)도 "Nineteen"으로 일치. (CLAUDE.md 본문·`.claude/agents/manifest-doc-syncer.md`는 "18-스킬"로 남아 있어 fg-visual 추가 후 드리프트 — 정확한 수는 19.)

**루프 4단계:** fg-ask · fg-run · fg-learn · fg-done. **루프 밖 15개:** fg-map · fg-status · fg-next · fg-loop · fg-merge · fg-cleanup · fg-quick · fg-doctor · fg-drop · fg-agents · fg-tdd · fg-eco · fg-adversarial-review · fg-statusline · fg-visual.

## `scripts/` — 결정론 트윈 스크립트 (ADR-0022 dual dispatch)

각 로직은 `<base>.sh`(bash 프라이머리) + `<base>.js`(node 폴백) 트윈이며, 동작 테스트 `<base>.test.sh` + sh/js 동치 테스트 `<base>.parity.test.sh`를 동반한다.

| base 이름 | 용도 |
| --- | --- |
| `forge-done` | 봉인 결정론 로직 (ADR-0030) |
| `forge-status` | 상태 리포트 + 다음 단계 (ADR-0020) |
| `forge-merge` | 브랜치 forge 통합 (git-free, ADR-0011) |
| `forge-doctor` | 무결성 health check (exit 0/1/2, ADR-0019) |
| `forge-statusline` | statusline forge fragment (방법 1) |
| `forge-statusline-full` | 통합 statusline (방법 2, ADR-0029) |
| `forge-statusline-wrapper` | 기존 statusline 래핑 (`.sh`만, 테스트 있음) |
| `resolve-forge-root` | forge 루트 해석 (ADR-0011) |

파일 예: `scripts/forge-done.sh`, `scripts/forge-done.js`, `scripts/forge-done.test.sh`, `scripts/forge-done.parity.test.sh`. (`forge-statusline-wrapper`는 `.js` 트윈 없이 `.sh` + `.test.sh`만 — bash 전용 wrapper.)

## `.forge/` — 상태 + 영속 문서 (git 추적 분리)

`.gitignore`가 `.forge/*`를 기본 제외하고 영속 문서만 화이트리스트(`!.forge/CONTEXT.md` · `!.forge/adr/` · `!.forge/retro/` · `!.forge/codebase/` · `!.forge/config.json` · `!.forge/branch/`).

```
.forge/
├── config.json                 {"eco": false} — 전역 예외(항상 최상위), defaultBranch/tdd/eco 등
├── adr/                         (git 추적) 아키텍처 결정 — 아래 "ADR 명명" 참고
├── retro/                       (git 추적) 세션 회고 로그 YYYY-MM-DD-slug.md (현재 다수 존재)
├── codebase/                    (git 추적) fg-map 산출 지도 — 이 문서(ARCHITECTURE.md/STRUCTURE.md)의 위치, 전역 예외
├── branch/                      (git 추적) 비-기본 브랜치의 forge 루트
│   └── feature/visual-compose/  현재 브랜치 루트 (ADR-0011)
│       ├── CONTEXT.md
│       ├── adr/260719-224442-vendor-superpowers-visual-companion.md
│       └── done/260720-074407-fg-visual-companion/  (STATUS.md·plan.md·run.md·review.md)
└── visual/                      (휘발·gitignore, 전역 예외) fg-visual 세션 <포트>-<타임스탬프>/
```

**휘발 상태(gitignore)**: `.forge/ask.md`, `.forge/backlog/<slug>.md`, `.forge/plan.md`, `.forge/run.md`, `.forge/review.md`, `.forge/STATUS.md`, `.forge/executed/<slug>/`, `.forge/done/<날짜-slug>/`, `.forge/loop.md`, `.forge/quick/LOG.md`, `.forge/dropped/<slug>/`. (기본 브랜치에선 없음, 브랜치 루트에선 통째 추적.) 현재 기본 `.forge/`에는 활성 휘발 상태가 없음(진행 중 작업 없음). `.forge/CONTEXT.md`·루트 `CONTEXT-MAP.md`는 현재 미존재(lazy 생성).

## ADR 명명 — 두 스킴 공존

`.forge/adr/<id>-slug.md`. 두 ID 스킴이 grandfather로 공존한다(형식 정의: `skills/fg-ask/ADR-FORMAT.md`).

- **순차 `NNNN`**: `0001-docs-into-forge.md` ~ `0032-fg-done-single-seal-summary.md` (32개).
- **시간기반 `YYMMDD-HH`+소문자 글자 / `YYMMDD-HHMMSS`**: `260716-13a-adr-time-based-id-scheme.md`, `260716-16a-...`, `260716-22a-...`, `260717-10a-fg-merge-optin-git-merge-mode.md`, `260719-161701-time-precise-naming.md` (5개). 브랜치 루트에도 `260719-224442-...` 1개.

번호·ID는 불변·재사용 금지. 은퇴 ADR은 `.forge/adr/retired/<id>-slug.md`로 이동(fg-cleanup, 현재 `retired/` 미존재). 시간ID 충돌 시 다음 글자(cascade 재번호 없음).

## `docs/` — 사용자 문서 + 랜딩 페이지

```
docs/
├── index.html                  GitHub Pages 랜딩 (단일 파일 이중언어 data-l="ko"/"en" 토글, ADR-0027)
├── skills.md                   스킬 카탈로그
├── state-contract.md           상태 계약 문서
├── forge-vs-loop-engineering.md
├── team-workflow.md
├── examples/github-actions-forge-check.yml   forge-doctor CI 게이트 예시
├── .nojekyll                   Pages Jekyll 비활성
└── icon.png · icon-sm.png · workflow.png · footer-forge-bg.png   자산
```

## `.claude/` — 이 리포 자신의 Claude 자산

```
.claude/
├── agents/manifest-doc-syncer.md   매니페스트·이중언어 문서 동기화 서브에이전트
├── agents/skill-author.md          SKILL.md 작성 서브에이전트
└── skills/issue-triage/SKILL.md    이슈 트리아지(프로젝트 로컬 스킬)
```

## 명명·동기화 규약

- **스킬 식별자 = frontmatter `name:`** (디렉터리명 아님, 자동 탐색은 `awk '/^name:/'`로 확인).
- **버전 3곳 동기**: `plugin.json`의 `version`, `marketplace.json`의 `metadata.version`·`plugins[0].version` (현재 전부 `0.5.18`).
- **README 이중언어 쌍**: `README.md`(영문) ↔ `README.ko.md`(한글) 동시 갱신. `docs/index.html`도 KO/EN span 쌍 동시 갱신.
- **스킬 본문 언어**: `SKILL.md`·`*-FORMAT.md`는 영문(grill-with-docs verbatim 포함), 사용자 출력·산출 문서는 사용자 언어.
- **스킬 문서 흐름도는 텍스트 흐름도**(`A → B → C`), Mermaid 금지(파싱·grep·diff 용이성).
- **`.sh` 스크립트는 LF 강제**(`.gitattributes`의 `*.sh text eol=lf` — Windows git-bash 실행 보장).
- **매니페스트 두 description 역할 차이**: `marketplace.json`의 `metadata.description`은 루프 태그라인(루프 밖 스킬 제외), `plugins[].description`·`plugin.json`의 `description`은 전체 스킬 목록.
- **매니페스트 JSON 검증**: `node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8')))"`.
