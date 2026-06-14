---
last_mapped_commit: d3c47b5bdc859af54e741f0524f9ed8ce2b61483
mapped: 2026-06-14
---

# forge 디렉터리 구조

## 최상위 레이아웃

```
forge/
├── .claude-plugin/
│   ├── plugin.json          # 플러그인 매니페스트 (skills/ 자동 탐색, skills 필드 생략)
│   └── marketplace.json     # 이 리포를 마켓플레이스로 등록 (plugins[].source = "./")
├── skills/                  # fg-* 스킬 14개 (각 디렉터리에 SKILL.md)
├── scripts/                 # 신규 — forge 최초의 실행 코드
│   ├── forge-statusline.sh        # statusline 조각 스크립트 (bash, 실행 권한)
│   └── forge-statusline.test.sh   # fixture 기반 bash 테스트
├── .forge/                  # forge 자신의 루프 상태 (도그푸딩)
├── README.md / README.ko.md # 영문/한글 번역 쌍 (동기화 필수)
├── CHANGELOG.md
└── CLAUDE.md
```

리포 루트가 곧 플러그인 루트이자 마켓플레이스다(`harness` 플러그인과 동일 패턴). `marketplace.json`의 `plugins[].source`는 `"./"`.

## skills/ — fg-* 스킬 14개

이번에 `fg-statusline` 추가로 13개 → **14개**가 됐다. 디렉터리 목록(`skills/`):

```
fg-ask  fg-cleanup  fg-done  fg-eco  fg-learn  fg-loop  fg-map
fg-merge  fg-next  fg-quick  fg-run  fg-status  fg-statusline  fg-tdd
```

스킬 식별자는 디렉터리명이 아니라 `SKILL.md` frontmatter의 `name` 필드다(현재는 디렉터리명과 일치). `plugin.json`이 `skills/`를 자동 탐색하므로 매니페스트에 스킬 경로를 나열하지 않는다.

### 형식 문서를 곁들인 스킬 (소유 = 형식 정의처)

대부분 스킬은 `SKILL.md` 단일 파일이지만, 일부는 형식 정의(`*-FORMAT.md`)나 공유 규칙 문서를 동반한다. 형식 정의는 **한 벌만** 존재하며 소유 스킬 디렉터리에 둔다:

- `skills/fg-ask/` — `SKILL.md` + `CONTEXT-FORMAT.md` + `ADR-FORMAT.md` (grill-with-docs 원본의 자기완결 3파일, 영문 verbatim)
- `skills/fg-run/` — `SKILL.md` + `PLAN-FORMAT.md`(plan 형식·분할 규칙) + `RUN-ALL.md`(배치 실행 규약) + `FORGE-ROOT.md`(브랜치별 루트 해석 규칙의 단일 정의처)
- `skills/fg-learn/` — `SKILL.md` + `RETRO-FORMAT.md`
- 나머지(`fg-done`·`fg-statusline`·루프 밖 유틸리티 등) — `SKILL.md` 단일 파일

다른 스킬은 이 형식·규칙 문서를 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(상대경로 `../fg-ask/` 등)로 참조하고 자체 복사하지 않는다. 루트 `references/` 디렉터리는 폐지됐다.

**PLAN-FORMAT.md 위치 주의:** plan.md의 생산자는 fg-ask지만 fg-ask 디렉터리는 grill-with-docs verbatim 영역이라, 형식 정의는 소비자 쪽인 `skills/fg-run/`에 둔다.

**FORGE-ROOT.md는 fg-run 소유의 공유 규칙** — 브랜치별 forge 루트 해석(ADR-0011)을 단 한 곳에 정의하고, 모든 루프 스킬(fg-ask·fg-run·fg-learn·fg-done·fg-status·fg-next·fg-quick)이 참조한다. (statusline 스크립트는 셸이라 이를 참조 못 해 로직을 자체 복제한다.)

## scripts/ — 신규 실행 코드

forge 최초로 실제 실행되는 코드가 들어간 디렉터리(ADR-0017). 빌드·CI 없는 리포의 예외다.

- `scripts/forge-statusline.sh` — statusline 조각. bash+git만 의존(node·jq 없음). cwd 기준 forge 루트를 풀어 `.forge/` 상태를 직접 읽고 한 줄 출력. JSON 파싱 없이 `sed`로 `key: value` 줄을 읽는다. `chmod +x`. `fg-statusline` 스킬이 이를 `~/.claude/forge-statusline.sh`로 복사해 설치(`${CLAUDE_PLUGIN_ROOT}`가 statusLine 셸에 없고 플러그인 경로가 업데이트마다 바뀌므로 안정 경로 복사가 필요).
- `scripts/forge-statusline.test.sh` — fixture 기반 테스트. 임시 디렉터리에 가짜 `.forge/` 상태를 만들고 스크립트를 그 cwd로 실행해 출력 한 줄을 기대값과 비교. `bash scripts/forge-statusline.test.sh`로 실행, 전부 통과 시 exit 0.

## .forge/ — forge 자신의 루프 상태 (도그푸딩)

forge 리포가 자기 자신의 워크플로우를 사용한다. 현재 실재하는 하위 디렉터리:

```
.forge/
├── adr/                  # 0001~0017 + retired/ (영속, git 추적)
├── backlog/              # 미실행 plan 대기열 (휘발, gitignored)
├── branch/               # 비-기본 브랜치 forge 루트 (git 추적, ADR-0011)
├── codebase/             # fg-map 지도 (영속, git 추적 — 이 문서 포함)
├── done/                 # 봉인된 작업 (휘발, gitignored)
├── quick/                # fg-quick LOG.md (gitignored)
└── retro/                # 세션 회고 (영속, git 추적)
```

휘발 상태(`backlog`/`plan.md`/`run.md`/`STATUS.md`/`executed/`/`done/`/`loop.md`/`quick/`)는 gitignored. 영속 문서(`adr/`·`retro/`·`codebase/`·`CONTEXT.md`·`config.json`)와 `branch/`만 `.gitignore` 화이트리스트로 추적.

## 명명 규약

- **스킬 디렉터리/식별자**: `fg-<단어>` (예: `fg-ask`, `fg-statusline`). 식별자의 정본은 `SKILL.md` frontmatter `name`.
- **형식 문서**: `<TYPE>-FORMAT.md` (대문자, 예: `PLAN-FORMAT.md`). 공유 규칙은 `<TYPE>.md`(예: `FORGE-ROOT.md`·`RUN-ALL.md`). 전부 영문.
- **ADR**: `NNNN-slug.md` (4자리 제로패딩 순번 + 케밥 slug, 예: `0017-statusline-integration.md`). 번호 단조 증가, 재사용 금지. 은퇴 ADR은 `.forge/adr/retired/<NNNN>-slug.md`로 이동(번호 불변).
- **회고**: `YYYY-MM-DD-slug.md` (`.forge/retro/`).
- **봉인 작업**: `.forge/done/<날짜-slug>/` 디렉터리 (plan/run/STATUS 동반).
- **백로그/plan slug**: plan 첫 줄 `<!-- forge-slug: ... -->` 주석이 짝 맞춤 식별자(파일 이동에도 영속).
- **statusline 설치 경로**: `~/.claude/forge-statusline.sh`(조각), `~/.claude/forge-statusline-wrapper.sh`(auto-wrap 래퍼).

## 매니페스트 동기화 규칙

스킬 개수·설명을 바꿀 땐 `plugin.json`과 `marketplace.json`을 함께 갱신(둘 다 사람이 읽는 설명을 담음). 버전은 3곳 동기: `plugin.json`의 `version`, `marketplace.json`의 `metadata.version`과 `plugins[0].version`(현재 0.4.10).

**두 description의 역할 차이:** `marketplace.json`의 `metadata.description`은 루프(ask→execute→retro→done)를 정의하는 태그라인이므로 루프 밖 유틸리티는 넣지 않는다. `plugins[].description`(과 `plugin.json`의 `description`)은 전체 스킬 목록을 담으므로 루프 밖 스킬(fg-statusline 포함)도 반영한다.

`README.md`(영문)와 `README.ko.md`(한글)는 번역 쌍 — 한쪽 갱신 시 반드시 다른 쪽도 같은 변경으로 동기화.

## 언어 규약

- 스킬 본문(`SKILL.md`)·형식 문서(`*-FORMAT.md`)는 **영문**으로 작성(grill-with-docs verbatim 부분은 영문 유지).
- 스킬이 **사용자에게 출력하는 언어는 사용자 언어**를 따른다(각 스킬에 "respond in the user's language" 명시). 산출 문서(plan·회고·CONTEXT·ADR 등)도 사용자 언어.
- 스킬 문서의 흐름도는 **Mermaid 금지, 텍스트 흐름도**(`A → B → C`)로 — 에이전트가 렌더링 없이 파싱·grep·diff 해야 하므로. (사용자 프로젝트 산출 문서에는 미적용.)

## 검증 방법 (빌드·테스트·린트 시스템 없음)

```bash
# 매니페스트 JSON 유효성
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"

# statusline 스크립트 테스트 (신규)
bash scripts/forge-statusline.test.sh

# 스킬 frontmatter name 누락 확인 (자동 탐색 대상)
awk '/^name:/' skills/*/SKILL.md
```

실제 동작 테스트는 설치 후 트리거해보는 것뿐(단위 테스트는 statusline 스크립트 한정). 설치는 GitHub 기본 브랜치(main)를 당기므로, 설치 테스트하려면 main에 push돼 있어야 한다.
