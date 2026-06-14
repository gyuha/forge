---
last_mapped_commit: 74d8c840911bb14b4600e1618d678af158d1ce69
mapped: 2026-06-14
---

# Structure

forge는 단일 리포가 곧 **플러그인 + 마켓플레이스**다(`harness` 플러그인과 동일 패턴: 리포 루트 = 플러그인 루트 = 마켓플레이스). 빌드 시스템·package.json·Makefile·CI가 없다. 산출물은 거의 전부 Markdown과 JSON이며, 유일한 실행 코드는 `scripts/`의 statusline용 bash 스크립트다.

## Top-level layout

```
forge/
├── .claude-plugin/          매니페스트 (플러그인 + 마켓플레이스)
│   ├── plugin.json          플러그인 매니페스트 (skills/ 자동 탐색 → skills 필드 생략 가능)
│   └── marketplace.json     이 리포를 마켓플레이스로 등록 (plugins[].source = "./")
├── skills/                  fg-* 워크플로우 스킬 (15개) — skills/<name>/SKILL.md 자동 탐색
├── scripts/                 statusline용 bash 스크립트 + 테스트 (4개)
├── .forge/                  휘발 상태 + 영속 문서 (자기 자신의 forge 루프 상태)
├── docs/                    부가 산문 문서 (forge-vs-loop-engineering.md)
├── README.md                영문 (사용자용)
├── README.ko.md             한글 (README.md의 번역 쌍 — 함께 갱신 필수)
├── CLAUDE.md                Claude Code 작업 지침 (이 리포의 단일 권위 문서)
├── CHANGELOG.md             Keep a Changelog 약식
└── .gitignore               .forge/ 기본 제외 + 영속 문서/branch 화이트리스트
```

## `.claude-plugin/` — manifests

매니페스트 JSON이 깨지면 설치가 실패하므로 편집 후 반드시 유효성을 확인한다:
```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

- `.claude-plugin/plugin.json` — 플러그인 매니페스트. `version`, `description`(전체 스킬 목록 담음). `skills/`가 자동 탐색되므로 `skills` 필드는 생략.
- `.claude-plugin/marketplace.json` — `metadata.description`(루프 정의 태그라인 — 루프 밖 유틸리티는 넣지 않음)·`metadata.version`·`plugins[0]`(`source: "./"`, `description`, `version`).

**버전은 3곳을 동기 갱신**: `plugin.json`의 `version`, `marketplace.json`의 `metadata.version`과 `plugins[0].version`. 현재 모두 `0.4.12`.

**두 description의 역할 차이** — `marketplace.json`의 `metadata.description`은 루프(ask→execute→retro→done)를 정의하는 한 줄 태그라인이라 루프 밖 유틸리티를 넣지 않는다. `plugins[].description`과 `plugin.json`의 `description`은 전체 15개 스킬 목록을 담으므로 루프 밖 스킬도 반영한다.

## `skills/` — the 15 skills

스킬은 `skills/<name>/SKILL.md`로 자동 탐색된다. **스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name`**이다(현재 모든 디렉터리에서 디렉터리명 == frontmatter name으로 일치). SKILL.md 본문·형식 문서(`*-FORMAT.md`)는 **영문**으로 작성하되, 스킬이 **사용자에게 출력하는 언어는 사용자 언어**를 따른다.

루프 4단계:

| 디렉터리 | frontmatter name | 역할 | 부속 파일 |
| --- | --- | --- | --- |
| `skills/fg-ask/` | `fg-ask` | ①그릴링·계획 적재 (루프 진입점) | `CONTEXT-FORMAT.md`, `ADR-FORMAT.md` |
| `skills/fg-run/` | `fg-run` | ②Dynamic Workflow 실행 + UAT | `PLAN-FORMAT.md`, `FORGE-ROOT.md`, `RUN-ALL.md` |
| `skills/fg-learn/` | `fg-learn` | ③회고·문서 승급 | `RETRO-FORMAT.md` |
| `skills/fg-done/` | `fg-done` | ④봉인·재실행 가드 | (없음) |

루프 밖 11개(모두 `SKILL.md` 단일 파일, 부속 파일 없음):

| 디렉터리 | frontmatter name | 역할 |
| --- | --- | --- |
| `skills/fg-map/` | `fg-map` | 코드베이스 → `.forge/codebase/` 매핑 (이 문서 생성) |
| `skills/fg-quick/` | `fg-quick` | trivial 작업 경량 차선 (형식 산출물 없음) |
| `skills/fg-status/` | `fg-status` | 읽기 전용 상태 리포터 |
| `skills/fg-next/` | `fg-next` | 다음 단계 도출·실행 오케스트레이터 (+`all` 모드) |
| `skills/fg-loop/` | `fg-loop` | goal 주도 한정 재계획 무인 루프 |
| `skills/fg-adversarial-review/` | `fg-adversarial-review` | 선택적 적대적 리뷰 (run↔learn 사이, 활성 슬롯 전용) |
| `skills/fg-merge/` | `fg-merge` | 브랜치 forge 루트 통합 |
| `skills/fg-cleanup/` | `fg-cleanup` | 오래된 ADR 은퇴 |
| `skills/fg-tdd/` | `fg-tdd` | TDD 모드 토글 (`config.json`) |
| `skills/fg-eco/` | `fg-eco` | 위임 모델 티어링 토글 (`config.json`) |
| `skills/fg-statusline/` | `fg-statusline` | statusline 설치·연결 |

### Format docs ownership

형식 정의는 한 벌만 존재하며 **소유 스킬 디렉터리**에 둔다. 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(상대경로 `../fg-ask/` 등)로 참조하고 자체 복사하지 않는다(루트 `references/` 디렉터리는 폐지).

- `skills/fg-ask/CONTEXT-FORMAT.md` — CONTEXT.md(글로서리) 형식. grill-with-docs 원본 verbatim.
- `skills/fg-ask/ADR-FORMAT.md` — ADR 형식. grill-with-docs 원본 verbatim.
- `skills/fg-run/PLAN-FORMAT.md` — plan.md 형식 + 분할 규칙. 생산자는 fg-ask지만 fg-ask 디렉터리가 verbatim 영역이라 소비자(fg-run) 쪽에 둠.
- `skills/fg-run/FORGE-ROOT.md` — 브랜치별 forge 루트 해석 규칙의 단일 정의(ADR-0011). 모든 루프 스킬이 참조.
- `skills/fg-run/RUN-ALL.md` — Run all 배치 실행 규약.
- `skills/fg-learn/RETRO-FORMAT.md` — 회고 형식.

알려진 불일치(편집 전 인지): `skills/fg-ask/`는 grill-with-docs 원본의 자기완결 영문 verbatim 본문이고, forge 루프 연결은 SKILL.md 맨 아래 "Forge integration (minimal)" 섹션에만 둔다. 둘 중 하나만 고치면 계약이 깨진다.

## `scripts/` — statusline (forge의 유일한 실행 코드)

fg-statusline이 설치하는 자기완결 bash 스크립트와 그 테스트. forge에서 유일하게 실행되는 코드이며 fixture 기반 bash 테스트를 갖는다(ADR-0017 — 두 기둥의 의도적·경계 있는 예외).

- `scripts/forge-statusline.sh` — `.forge/`를 읽어 루프 진행 상태 한 줄 출력(stdin 세션 JSON의 `cwd`를 jq 없이 방어적 `sed`로 파싱; stdin이 tty가 아닐 때만 읽음).
- `scripts/forge-statusline.test.sh` — 위 fragment 테스트(stdin-cwd 케이스 포함).
- `scripts/forge-statusline-wrapper.sh` — 기존 statusLine을 래핑해 forge 행을 추가(Claude Code는 statusLine 하나만 허용 → 대체 안 하고 합성). 원본 명령은 별도 파일 `forge-statusline-orig.sh`에 verbatim 보존. 같은 JSON을 원본과 fragment 양쪽 stdin으로 흘리고, 원본을 먼저 출력한 뒤 fragment를 별도 행으로(비어 있지 않을 때만) 붙인다. **동반 파일(`forge-statusline-orig.sh`·`forge-statusline.sh`)을 자기 스크립트 위치(`$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`)에서 해석한다 — 런타임 `CLAUDE_CONFIG_DIR`에 의존하지 않음**(statusLine 프로세스가 그 변수를 export 안 하는 custom config dir 환경에서 동반 파일을 못 찾아 전체 statusline이 조용히 공백이 되는 결함 제거; ADR-0017 개정 2026-06-14). 동반 파일은 래퍼와 같은 디렉터리에 복사되므로 자기 위치 해석이 항상 옳다.
- `scripts/forge-statusline-wrapper.test.sh` — 래퍼 테스트(원본 보존·forge 행 추가·idle 무행·stdin 재공급·custom config dir/`CLAUDE_CONFIG_DIR` 미설정 회귀).

설치 시 `settings.json`의 `statusLine.command`는 **절대경로**로 기록한다(`~`/`$CLAUDE_CONFIG_DIR` 금지 — 호스트의 tilde 확장 미보장으로 전체 statusline이 공백이 되는 장애 회피; ADR-0017).

## `.forge/` — state + persistent docs

이 리포는 자기 자신의 forge 루프를 돌린다. `.gitignore`가 `.forge/*`를 기본 제외하되 영속 문서만 화이트리스트로 추적한다.

영속(git 추적):
- `.forge/adr/NNNN-slug.md` — 아키텍처 결정. 현재 `0001`~`0018`.
  - `.forge/adr/retired/` — fg-cleanup이 은퇴시킨 ADR(번호 불변, 삭제 안 함).
- `.forge/retro/YYYY-MM-DD-slug.md` — 세션 회고 로그.
- `.forge/codebase/*.md` — fg-map 생성 코드베이스 지도(이 문서가 그 일부).
- `.forge/config.json` — `defaultBranch`·`tdd`·`eco` 등 프로젝트 전역 설정(전역 예외: 항상 최상위, 브랜치 무관).
- `.forge/CONTEXT.md` — 도메인 글로서리(lazy 생성, 현재 미존재).

휘발(git 미추적, lazy 생성):
- `.forge/backlog/<slug>.md` — fg-ask가 적재한 미실행 대기 plan.
- `.forge/plan.md` · `.forge/run.md` · `.forge/review.md` · `.forge/STATUS.md` — 활성 슬롯(항상 1개). `review.md`는 활성 슬롯 전용(fg-adversarial-review 생성, 선택적).
- `.forge/executed/<slug>/` — 실행됐으나 미회고(여기엔 review.md를 두지 않음).
- `.forge/done/<날짜-slug>/` — 봉인 완료 작업 아카이브.
- `.forge/loop.md` — fg-loop의 goal 계약.
- `.forge/quick/LOG.md` — fg-quick 한 줄 로그.

브랜치별(ADR-0011): 비-기본 브랜치는 위 휘발+영속이 통째로 `.forge/branch/<branch>/` 아래로 이동하며 **git 추적**된다(`.gitignore`가 `!.forge/branch/`로 화이트리스트). 단 `.forge/config.json`·`.forge/codebase/`는 예외로 항상 최상위.

## Naming conventions

- **스킬 식별자 = frontmatter `name`**, 디렉터리명 아님(둘이 일치하도록 유지하는 게 관례).
- **ADR** — `NNNN-slug.md`(4자리 0패딩, 단조 증가, 번호 재사용 금지).
- **회고** — `YYYY-MM-DD-slug.md`.
- **done 아카이브** — `done/<날짜-slug>/`.
- **plan 식별자** — plan 첫 줄 `<!-- forge-slug: <slug> -->`(회고·봉인 짝 맞춤). fix-forward plan은 `<!-- generated-by: ... -->` 마커 + 단조 `<!-- task: N -->`.
- **버전** — `vX.Y.Z`, 릴리스 커밋은 `chore(release): vX.Y.Z`.

## Verification (no test/build system)

- 매니페스트 JSON 유효성 — 위 node 한 줄.
- 스킬 frontmatter `name` 누락 검사 — `for f in skills/*/SKILL.md; do awk '/^name:/' "$f"; done`.
- statusline 스크립트만 `*.test.sh` 보유(fixture 기반). 그 외 실제 동작은 설치해서 트리거해보는 것뿐(단위 테스트 없음).
