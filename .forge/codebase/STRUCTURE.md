---
last_mapped_commit: b45521cd5fc2f536cc212e559af52c3939a5b0a5
mapped: 2026-06-12
---

# forge 디렉터리 구조 — 파일 위치와 명명 규약

## 요약

리포 루트가 곧 **플러그인 루트이자 마켓플레이스**다(harness 플러그인과 동일 패턴). 코드 디렉터리는 없고 모든 산출물이 Markdown/JSON이다. 큰 갈래는 셋: `.claude-plugin/`(매니페스트), `skills/`(스킬 13개 + 형식 문서), `.forge/`(루프 상태 + 영속 문서). 루트에 `docs/`(검토 에세이 1편, 추적)가 있다. 현재 작업 트리에는 13번째 스킬 `skills/fg-loop/`와 `​.forge/adr/0016-*` 등 미커밋 변경이 쌓여 있다(v0.4.7 + fg-loop 작업분).

```
forge/
├── .claude-plugin/
│   ├── plugin.json                # 플러그인 매니페스트 (version 0.4.7)
│   └── marketplace.json           # 마켓플레이스 등록, plugins[0].source = "./"
├── skills/                        # 13개 스킬 디렉터리, 각 <name>/SKILL.md
│   ├── fg-ask/                    #   SKILL.md + CONTEXT-FORMAT.md + ADR-FORMAT.md
│   ├── fg-run/                    #   SKILL.md + PLAN-FORMAT.md + FORGE-ROOT.md + RUN-ALL.md
│   ├── fg-learn/                  #   SKILL.md + RETRO-FORMAT.md
│   ├── fg-done/ fg-map/ fg-quick/ fg-status/ fg-next/ fg-loop/
│   └── fg-tdd/ fg-eco/ fg-merge/ fg-cleanup/        # 나머지는 SKILL.md 단일 파일
├── .forge/                        # 루프 상태(휘발·gitignored) + 영속 문서(화이트리스트 추적)
│   ├── adr/        (0001–0016, 16편; retired/ 규약은 아래)
│   ├── retro/      (YYYY-MM-DD-slug.md, 19편)
│   ├── codebase/   (fg-map 7문서 — 이 문서 포함)
│   ├── done/       (봉인 아카이브 36건, 휘발)  ·  quick/LOG.md (휘발)
│   ├── loop.md     (fg-loop goal 계약, 휘발 — 루프 in-flight일 때만 존재)
│   └── config.json (추적; tdd/eco/defaultBranch)
├── docs/
│   └── forge-vs-loop-engineering.md   # Loop Engineering(Addy Osmani) 대응 검토 에세이 (추적)
├── CLAUDE.md  ·  README.md / README.ko.md (번역 쌍)  ·  CHANGELOG.md  ·  .gitignore
└── .claude/worktrees/             # gitignored 잔존 워크트리 (구 fg-execute 시절 스냅샷)
```

## `.claude-plugin/` — 매니페스트

- `.claude-plugin/plugin.json` — 플러그인 매니페스트. `skills/`가 자동 탐색되므로 `skills` 필드는 생략. `version`과 전체 스킬 목록을 담는 `description`(루프 4 + 유틸리티 9 전부 서술 — fg-loop 포함).
- `.claude-plugin/marketplace.json` — 이 리포를 마켓플레이스로 등록. `plugins[0].source`는 `"./"`(루트가 곧 플러그인). 버전은 **3곳 동기**: `plugin.json:version` · `marketplace.json:metadata.version` · `marketplace.json:plugins[0].version` — 현재 모두 `0.4.7`.
- **두 description의 역할이 다르다.** `metadata.description`은 루프(ask→execute→retro→done)만 정의하는 한 줄 태그라인(루프-밖 유틸리티 제외), `plugins[0].description`(과 `plugin.json:description`)은 13개 전체를 반영("Thirteen fg-* skills..." — fg-loop 단락 포함).
- 편집 후 JSON 유효성 확인: `node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"`.

## `skills/` — 13개 스킬과 형식 문서

- 스킬은 `skills/<name>/SKILL.md`로 **자동 탐색**된다. **스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name`**이다(현재 둘은 전부 일치). frontmatter는 `name` + `description`(트리거 발화 포함, 한/영 혼재).
- 13개 디렉터리: `fg-ask` `fg-run` `fg-learn` `fg-done`(루프 4) + `fg-map` `fg-quick` `fg-status` `fg-next` `fg-loop` `fg-tdd` `fg-eco` `fg-merge` `fg-cleanup`(루프 밖 9). `skills/fg-loop/`는 SKILL.md 단일 파일이며 형제 형식 문서가 없다 — goal 계약(`loop.md`) 골격은 SKILL.md 본문 §1에 인라인으로 정의돼 있다.
- 스킬 본문·형식 문서는 **영문 작성**(사용자 출력·산출 문서는 사용자 언어 — 각 SKILL.md에 Language 절 명시). 흐름도는 Mermaid 금지, 텍스트 흐름도만.

### 형식 문서 단일 정의 규칙 (한 벌만, 소유 스킬 디렉터리에)

| 형식 문서 | 위치 | 정의하는 것 |
| --- | --- | --- |
| `skills/fg-ask/CONTEXT-FORMAT.md` | fg-ask (grill-with-docs 원본) | CONTEXT.md 글로서리 형식 |
| `skills/fg-ask/ADR-FORMAT.md` | fg-ask (grill-with-docs 원본) | ADR 형식 |
| `skills/fg-run/PLAN-FORMAT.md` | fg-run | plan.md 골격 + 마커(`forge-slug`/`task`/`tdd`/`priority`/`part`/`retro-hint`) + 분할 규칙. 생산자는 fg-ask(와 fg-loop의 생성 plan)지만 fg-ask 디렉터리는 verbatim 영역이라 소비자 쪽에 둔다 |
| `skills/fg-run/FORGE-ROOT.md` | fg-run | 브랜치별 forge 루트 해석 규칙 + 전역 예외 + 읽기 오버레이 (ADR-0011) — 모든 루프 스킬과 fg-loop가 참조 |
| `skills/fg-run/RUN-ALL.md` | fg-run | "Run all" 배치 절차 — 토큰 효율을 위해 SKILL.md에서 분리, 선택 시에만 로드. 4단계 핸드오프는 진술형(ADR-0015 개정) |
| `skills/fg-learn/RETRO-FORMAT.md` | fg-learn | 회고 로그 형식 |

다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(또는 상대경로 `../fg-ask/` 등)로 참조하고 **자체 복사하지 않는다**. 루트 `references/` 디렉터리는 폐지됐다. 형식 문서 외에 **로직의 단일 정의처**도 같은 규칙을 따른다: 다음-단계 상태 머신은 `skills/fg-status/SKILL.md`(fg-next가 참조, `loop.md` 존재 시 0순위로 fg-loop resume을 가리킴), fg-next all 주행 기계는 `skills/fg-next/SKILL.md`(fg-loop가 참조).

- **`skills/fg-ask/`의 특수성**: SKILL.md 본문은 grill-with-docs 원본의 영문 verbatim, forge 루프 연결(백로그 산출·핸드오프·retro 환류·codebase 지도 읽기 등)은 맨 아래 "Forge integration (minimal)" 섹션에만 둔다. 둘은 따로 움직이므로 한쪽만 고치면 계약이 깨진다(`CLAUDE.md` "알려진 불일치").

## `.forge/` — 휘발 vs 영속 (git 추적이 구분선)

`.gitignore`가 `.forge/*`로 기본 제외하되 영속 문서만 화이트리스트로 되살린다:

```
.forge/*
!.forge/CONTEXT.md   !.forge/adr/   !.forge/retro/   !.forge/codebase/   !.forge/config.json
!.forge/branch/      ← 비-기본 브랜치 루트는 통째로 추적 (ADR-0011)
```

- **휘발(gitignored, 기본 브랜치)**: `backlog/` · 활성 슬롯 `plan.md`/`run.md`/`STATUS.md` · `executed/` · `done/` · `quick/LOG.md` · **`loop.md`**(fg-loop goal 계약 — `.forge/*` 패턴으로 자동 제외, goal-met 종료 시 fg-loop가 삭제하고 벽에서 halt하면 남는다). 전부 lazy 생성.
- **영속(추적)**: `CONTEXT.md`(도메인 글로서리 — 현재 이 리포에는 없음, lazy), `adr/NNNN-slug.md`(현재 `0001`–`0016` 16편, 전부 활성 — `retired/`는 아직 없음; `0016`은 미커밋), `retro/YYYY-MM-DD-slug.md`(19편 — `2026-06-12-add-fg-loop.md` 미커밋), `codebase/*.md`(fg-map 7문서), `config.json`.
- **`adr/retired/` 규약** (ADR-0012): fg-cleanup이 은퇴 ADR을 `adr/retired/<NNNN>-slug.md`로 옮기고 머리에 `Status: Superseded by ADR-NNNN` 또는 `Status: Retired (사유)`를 한 줄 표기. 번호 불변·재사용 금지(다음 ADR은 여전히 전체 `max+1` — `retired/` 포함해 계산), 교차참조 재작성 없음, 삭제 없음. fg-ask는 `retired/`를 그릴링 연료로 읽지 않는다. `adr/` 하위라 `!.forge/adr/` 화이트리스트로 그대로 추적된다.
- **`codebase/` 7문서**: `STACK.md` `INTEGRATIONS.md`(tech) · `ARCHITECTURE.md` `STRUCTURE.md`(arch) · `CONVENTIONS.md` `TESTING.md`(quality) · `CONCERNS.md`(concerns). 각 문서는 `last_mapped_commit` frontmatter 스탬프 필수. **구현 사실만, 도메인 용어 정의 금지**(CONTEXT.md와의 경계).
- **`config.json` 키**: `tdd`(fg-tdd), `eco`(fg-eco), `defaultBranch`(FORGE-ROOT 해석). 쓰는 스킬은 기존 키를 보존하며 자기 키만 갱신. 전역 예외라 브랜치 무관 항상 최상위 `.forge/`.
- 비-기본 브랜치에서는 위 휘발/영속 전부가 `.forge/branch/<branch>/` 아래로 들어가고 통째로 추적된다. 전역 예외(`config.json`·`codebase/`)만 항상 최상위.

## `docs/` — 검토 에세이

`docs/forge-vs-loop-engineering.md`(39줄, 추적) — Addy Osmani의 Loop Engineering(2026)에 forge를 대응시킨 검토 문서. 6개 프리미티브 대응표와 경고의 제도화 표. 작성 시점(v0.4.4)에는 "검증 가능한 정지 조건까지의 무인 재개"가 유일 갭으로 기록됐고, 그 갭을 메운 것이 이번 작업 트리의 `skills/fg-loop/`(ADR-0016)다. 영속 루프 문서가 아니라 리포 자체에 대한 에세이라 `.forge/`가 아닌 루트 `docs/`에 있다.

## 루트 키 파일

- `CLAUDE.md` — 이 리포 작업 시의 단일 안내서: 루프·상태 계약·두 기둥·스킬 편집 규약·배포 절차("배포" 트리거, 버전 3곳 동기)·알려진 불일치. (작업 트리에서 fg-loop 반영으로 수정 중.)
- `README.md` / `README.ko.md` — **같은 내용의 번역 쌍. 한쪽을 고치면 반드시 다른 쪽도 동일 변경**(스킬 편집 규약). (둘 다 fg-loop 반영으로 수정 중.)
- `CHANGELOG.md` — Keep a Changelog 약식. 배포 절차의 1단계. 최신 항목 `0.4.7`.
- `.gitignore` — 위 `.forge/` 화이트리스트의 단일 정의처. `.claude/worktrees`·`.DS_Store`·`.planning/`(단 `!.planning/codebase/`)도 제외.
- `.claude/worktrees/feature+260604-init-skill/` — gitignored 잔존 워크트리. `skills/fg-execute/` 등 **개명 전(현 fg-run) 시절의 옛 스냅샷**이므로 grep 시 현재 트리와 혼동하지 말 것.

## 명명 규약

- 스킬 접두사 `fg-*`, 디렉터리명 = frontmatter `name`.
- 형식 문서는 `<주제>-FORMAT.md`(대문자), 참조 문서는 `FORGE-ROOT.md`/`RUN-ALL.md`처럼 대문자.
- ADR 파일 `NNNN-slug.md`(4자리, 단조증가·재사용 금지), retro 파일 `YYYY-MM-DD-slug.md`, 봉인 디렉터리 `done/<YYYY-MM-DD-slug>/`.
- plan 마커는 HTML 주석: `<!-- forge-slug: ... -->` `<!-- task: N -->` `<!-- tdd: on|off -->` `<!-- priority: high|medium|low -->` `<!-- part: N/M -->` `<!-- retro-hint: optional -->`(정의: `skills/fg-run/PLAN-FORMAT.md`) + **`<!-- generated-by: fg-loop -->`**(fg-loop가 한정 재계획에서 생성한 fix-forward plan의 출처 마커 — 정의: `skills/fg-loop/SKILL.md` §3). 분할 part slug는 `<base>-NofM`, 충돌 시 `-2` 접미.
- slug는 작업 제목의 kebab-case. `.forge/loop.md`는 슬롯형 고정 이름(활성 슬롯 `plan.md`/`run.md`/`STATUS.md`와 같은 패턴 — 한 번에 하나).
