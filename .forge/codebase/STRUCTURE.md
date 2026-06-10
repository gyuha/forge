---
last_mapped_commit: 0472a519cbb8275564cdbaa30469f2d0c5472842
mapped: 2026-06-10
---

# forge 디렉터리 구조 — 파일 위치와 명명 규약

## 요약

리포 루트가 곧 **플러그인 루트이자 마켓플레이스**다(harness 플러그인과 동일 패턴). 코드 디렉터리는 없고, 모든 산출물이 Markdown/JSON이다. 큰 갈래는 셋: `.claude-plugin/`(매니페스트), `skills/`(스킬+형식 문서), `.forge/`(루프 상태+영속 문서).

```
forge/
├── .claude-plugin/        # 플러그인 + 마켓플레이스 매니페스트
│   ├── plugin.json
│   └── marketplace.json
├── skills/                # 11개 스킬, 각 <name>/SKILL.md
│   ├── fg-ask/            #   + CONTEXT-FORMAT.md, ADR-FORMAT.md
│   ├── fg-run/            #   + PLAN-FORMAT.md, FORGE-ROOT.md, RUN-ALL.md
│   ├── fg-learn/          #   + RETRO-FORMAT.md
│   ├── fg-done/  fg-map/  fg-quick/  fg-status/  fg-next/  fg-tdd/  fg-merge/  fg-cleanup/
├── .forge/                # 루프 상태(휘발) + 영속 문서(추적)
│   ├── adr/  retro/  codebase/  done/   (+ backlog/ executed/ 휘발, CONTEXT.md, config.json)
├── CLAUDE.md
├── README.md  README.ko.md   # 이중 언어 번역 쌍
├── CHANGELOG.md
└── .gitignore
```

## `.claude-plugin/` — 매니페스트

- `.claude-plugin/plugin.json` — 플러그인 매니페스트. `skills/`가 자동 탐색되므로 `skills` 필드는 생략한다. `version`·전체 스킬 목록을 담는 `description`.
- `.claude-plugin/marketplace.json` — 이 리포를 마켓플레이스로 등록. `plugins[0].source`는 `"./"`(루트가 곧 플러그인). 버전은 **3곳 동기**: `plugin.json:version` · `marketplace.json:metadata.version` · `marketplace.json:plugins[0].version`(현재 모두 `0.4.2`).
- **두 description의 역할이 다르다.** `marketplace.json`의 `metadata.description`은 루프(ask→execute→retro→done)를 정의하는 한 줄 태그라인이라 루프-밖 유틸리티를 넣지 않는다. `plugins[].description`(과 `plugin.json:description`)은 전체 스킬 목록을 담으므로 루프-밖 스킬도 반영한다.
- 편집 후 JSON 유효성 확인: `node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"`.

## `skills/` — 스킬과 형식 문서

- 스킬은 `skills/<name>/SKILL.md`로 **자동 탐색**된다. **스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name`** 이다(둘은 현재 일치하지만 계약상 동일성은 보장 안 됨). frontmatter는 `name` + `description`(트리거 발화 포함).
- 11개 스킬 디렉터리: `fg-ask` `fg-run` `fg-learn` `fg-done` `fg-map` `fg-quick` `fg-status` `fg-next` `fg-tdd` `fg-merge` `fg-cleanup`.

### 형식 문서 — 소유 스킬 디렉터리에 한 벌만 (복붙 금지)

형식 정의는 한 벌만 존재하며 소유 스킬 디렉터리에 둔다. 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(또는 상대경로 `../fg-ask/` 등)로 참조하고 자체 복사하지 않는다. 폐지된 루트 `references/` 디렉터리는 없다.

| 형식 문서 | 위치 | 정의 대상 | 생산자 |
| --- | --- | --- | --- |
| `CONTEXT-FORMAT.md` | `skills/fg-ask/` | CONTEXT.md(도메인 글로서리) | fg-ask |
| `ADR-FORMAT.md` | `skills/fg-ask/` | ADR | fg-ask |
| `PLAN-FORMAT.md` | `skills/fg-run/` | plan.md 형식 + 분할 규칙 | fg-ask(생산), fg-run(소비) |
| `RETRO-FORMAT.md` | `skills/fg-learn/` | retro 로그 | fg-learn |

- `PLAN-FORMAT.md`는 생산자가 fg-ask지만, fg-ask 디렉터리는 grill-with-docs 영문 verbatim 영역이라 소비자(fg-run) 쪽에 둔다.
- 형식 문서·`SKILL.md` 본문은 **영문**으로 작성한다(grill-with-docs verbatim 유지). 단 스킬이 **사용자에게 출력하는 언어와 생성 문서(plan·retro·CONTEXT·ADR 등)는 사용자 언어**를 따른다.

### fg-run 디렉터리의 단일-정의 파일

- `skills/fg-run/FORGE-ROOT.md` — 브랜치별 forge 루트 해석 규칙의 **단일 정의처**(fg-run 소유). 모든 루프 스킬이 참조(ADR-0011).
- `skills/fg-run/RUN-ALL.md` — "Run all" execute-only 배치 절차. progressive disclosure로 `SKILL.md`에서 추출돼 메뉴에서 실제 "Run all"을 고를 때만 on-demand 로드된다.

### fg-ask 디렉터리의 자기완결 3파일

`skills/fg-ask/`는 grill-with-docs 원본의 자기완결 3파일이다: `SKILL.md`(영문 verbatim 본문) + 형제 `CONTEXT-FORMAT.md`/`ADR-FORMAT.md`. forge 루프 연결(백로그 산출·fg-run 핸드오프·회고 환류)은 SKILL.md 맨 아래 "Forge integration" 섹션에만 있다.

## `.forge/` — 루프 상태 + 영속 문서 (추적 분기)

`.gitignore`가 `.forge/*`로 기본 제외하되 영속 문서만 화이트리스트로 되살린다. 즉 **위치는 둘 다 `.forge/` 안, 구분은 git 추적 여부**다.

```
.gitignore:
  .forge/*                  # 기본 제외(휘발 상태)
  !.forge/CONTEXT.md        # ↓ 화이트리스트(추적 = 영속 연료)
  !.forge/adr/
  !.forge/retro/
  !.forge/codebase/
  !.forge/config.json
  !.forge/branch/           # 비-기본 브랜치 루트는 통째로 추적(ADR-0011)
```

- **휘발(gitignored, 기본 브랜치)**: `backlog/<slug>.md` · `plan.md` · `run.md` · `STATUS.md` · `executed/<slug>/` · `done/<날짜-slug>/` · `quick/LOG.md`.
- **영속(추적)**: `CONTEXT.md`(단일 컨텍스트 글로서리) · `adr/NNNN-slug.md` · `retro/YYYY-MM-DD-slug.md` · `codebase/*.md`(fg-map 7문서) · `config.json`(전역 설정).
- 전부 **lazy 생성**(쓸 내용이 생길 때만).

### 명명 규약

- ADR: `.forge/adr/NNNN-slug.md` — 4자리 단조 증가 번호(현재 0001–0013), 번호 불변·재사용 금지. 은퇴 ADR은 `.forge/adr/retired/<NNNN>-slug.md`로 이동(fg-cleanup, ADR-0012).
- retro: `.forge/retro/YYYY-MM-DD-slug.md`.
- done 아카이브: `.forge/done/<YYYY-MM-DD>-<slug>/`(안에 plan.md/run.md/STATUS.md). slug 충돌 시 `-2` 접미사.
- plan 짝 맞춤: plan 첫 줄 `<!-- forge-slug: <slug> -->` 주석으로 retro·봉인을 매칭(파일 이동에도 영속).
- 멀티 컨텍스트 예외: 컨텍스트별 `CONTEXT.md`는 코드 옆(`src/<context>/`), `CONTEXT-MAP.md`는 루트에 둔다(`.forge/` 통합 대상 아님). 단일 컨텍스트만 `.forge/CONTEXT.md`.

### `.forge/codebase/` — fg-map 7문서

fg-map이 생성하는 코드베이스 지도: `ARCHITECTURE.md` · `STRUCTURE.md` · `STACK.md` · `CONVENTIONS.md` · `INTEGRATIONS.md` · `TESTING.md` · `CONCERNS.md`. 각 문서는 `last_mapped_commit` / `mapped` frontmatter를 갖는다. 브랜치 무관 top-level `.forge/codebase/`에 공유(전역 예외, ADR-0011).

## 루트 문서

- `CLAUDE.md` — 리포 작업 지침(상태 계약·설계 원칙·편집 규약·배포 규칙).
- `README.md`(영문) / `README.ko.md`(한글) — **번역 쌍**. 한쪽을 고치면 반드시 다른 쪽도 같은 변경으로 동기화한다(한쪽만 고치면 어긋남).
- `CHANGELOG.md` — Keep a Changelog 약식. 배포 시 새 버전 섹션을 맨 위에 추가.
- `.gitignore` — `.forge/` 추적 분기 정의(위 참조) + `.claude/worktrees`, `.planning/`, `.DS_Store`.

## 빌드/테스트 부재

package.json·Makefile·CI 없음. "개발"은 Markdown/JSON 편집이고, 검증은 (1) 매니페스트 JSON 유효성 1줄, (2) 설치 후 트리거(설치는 GitHub main을 당김) 두 가지뿐이다. 단위 테스트 없음.
