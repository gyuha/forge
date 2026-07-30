---
last_mapped_commit: c1100b17577529833c68ca5a8c59ee1e310f24d4
mapped: 2026-07-28
---

# STRUCTURE

> **구현 사실만** 담는다. 도메인 용어의 뜻은 `.forge/CONTEXT.md` 소관이며 여기서 정의하지 않는다.
> 모든 개수는 트리에서 직접 셌다. 문서와 트리가 어긋난 지점은 §7에 모아 두었다.

## 1. 최상위 레이아웃

리포 루트가 곧 **플러그인 루트이자 마켓플레이스**다(`harness` 플러그인과 같은 단일 리포 패턴).

```
forge/
├── .claude-plugin/          플러그인·마켓플레이스 매니페스트 (2 JSON)
├── skills/                  fg-* 스킬 19개 — 자동 탐색
├── hooks/                   배포 훅 1개 + polyglot 래퍼 — 자동 탐색  ★신규
├── scripts/                 결정론 bash/node 트윈 + 테스트 (33 파일)
├── docs/                    사용자 문서(한국어) + 랜딩 페이지 + 예제
├── .forge/                  forge 자신의 루프 상태 + 영속 문서 (dogfooding)
├── .claude/                 이 리포 개발용 프로젝트 자산 (배포 대상 아님)
├── CLAUDE.md                에이전트용 리포 지침 (35KB — 사실상 스펙 문서)
├── README.md / README.ko.md 이중언어 쌍
├── CHANGELOG.md             Keep a Changelog 약식 (85KB)
├── .gitignore               .forge/ 화이트리스트 규칙이 여기 있음
└── .gitattributes           `*.sh text eol=lf` — Windows CRLF 방어(load-bearing)
```

**빌드 산출물·의존성 디렉터리가 없다**: `package.json`·`node_modules/`·`Makefile`·`.github/` 모두 부재.

## 2. `.claude-plugin/` — 매니페스트

| 파일 | 역할 | 확인된 사실 |
| --- | --- | --- |
| `plugin.json` | 플러그인 매니페스트 | 키: `name`·`description`·`version`·`author`·`homepage`·`repository`·`license`·`keywords`. **`skills` 필드 없음** → `skills/` 자동 탐색. **`hooks` 필드도 없음** → `hooks/hooks.json` 자동 탐색 |
| `marketplace.json` | 이 리포를 마켓플레이스로 등록 | `plugins[0].source == "./"` (루트가 곧 플러그인) |

**버전은 3곳을 반드시 동기 갱신**한다 — 현재 전부 `0.5.20`:

```
plugin.json      : version
marketplace.json : metadata.version
marketplace.json : plugins[0].version
```

두 `description`은 역할이 다르다. `marketplace.json`의 `metadata.description`은 **루프만** 정의하는 태그라인(루프 밖 유틸리티 제외), `plugins[].description`과 `plugin.json`의 `description`은 **전체 스킬 목록**을 담는 긴 설명(루프 밖 스킬 포함).

편집 후 유효성 검사:

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

## 3. `skills/` — 19개

디렉터리당 `SKILL.md` 1개가 필수이고, 일부는 동반 문서를 함께 둔다.

| 디렉터리 | frontmatter `name` | 동반 파일 | 루프 위치 |
| --- | --- | --- | --- |
| `fg-ask/` | fg-ask | `CONTEXT-FORMAT.md`, `ADR-FORMAT.md` | ① 질의·그릴링 |
| `fg-run/` | fg-run | `FORGE-ROOT.md`, `PLAN-FORMAT.md`, `RUN-ALL.md` | ② 실행 |
| `fg-learn/` | fg-learn | `RETRO-FORMAT.md` | ③ 회고 |
| `fg-done/` | fg-done | — | ④ 봉인 |
| `fg-next/` | fg-next | `DRIVE.md` | 루프 밖 (오케스트레이터) |
| `fg-loop/` | fg-loop | — | 루프 밖 (goal 주행) |
| `fg-status/` | fg-status | — | 루프 밖 (읽기 전용 리포터) |
| `fg-doctor/` | fg-doctor | — | 루프 밖 (health check) |
| `fg-map/` | fg-map | — | 루프 밖 (코드베이스 지도) |
| `fg-quick/` | fg-quick | — | 루프 밖 (경량 차선) |
| `fg-merge/` | fg-merge | — | 루프 밖 (브랜치 통합) |
| `fg-cleanup/` | fg-cleanup | — | 루프 밖 (ADR 은퇴) |
| `fg-drop/` | fg-drop | — | 루프 밖 (미완 폐기) |
| `fg-agents/` | fg-agents | — | 루프 밖 (역할 카드 생성) |
| `fg-adversarial-review/` | fg-adversarial-review | — | 루프 밖 (선택적 리뷰) |
| `fg-statusline/` | fg-statusline | — | 루프 밖 (설정) |
| `fg-tdd/` | fg-tdd | — | 루프 밖 (토글) |
| `fg-eco/` | fg-eco | `ECO.md` | 루프 밖 (토글 + 규율) |
| `fg-visual/` | fg-visual | `VISUAL.md`, `LICENSE`, `scripts/` | 루프 밖 (시각 컴패니언) |

**19개 전부 디렉터리명 == frontmatter `name`** (일치 확인). 다만 **식별자는 frontmatter의 `name`이지 디렉터리명이 아니다** — 개명 시 둘을 함께 바꿔야 한다.

### 3-A. `skills/fg-visual/scripts/` — 유일한 벤더링 자산

obra/superpowers v6.1.1의 Visual Companion을 MIT 귀속과 함께 그대로 들여왔다. `skills/fg-visual/LICENSE`가 귀속 파일이며, forge에서 **`LICENSE` 파일을 가진 유일한 스킬**이다.

```
skills/fg-visual/scripts/
├── server.cjs           (24KB) zero-dependency Node 서버
├── helper.js            에이전트 측 헬퍼
├── frame-template.html  브라우저 프레임 템플릿
├── start-server.sh
└── stop-server.sh
```

이 `scripts/`는 루트 `scripts/`(결정론 트윈)와 **완전히 별개**다. 세션 파일은 모든 브랜치에서 최상위 `.forge/visual/<세션>/`에 쓴다(휘발·gitignore — 브랜치 루트 아님).

### 3-B. 크기 감각 (참고)

가장 긴 것들: `fg-visual/VISUAL.md` 278행, `fg-statusline/SKILL.md` 217행, `fg-loop/SKILL.md` 180행, `fg-done/SKILL.md` 175행, `fg-run/SKILL.md` 169행. 가장 짧은 것: `fg-run/RUN-ALL.md` 15행(progressive disclosure 분리 조각). `skills/` 전체 마크다운 합계 2,904행.

## 4. `hooks/` — 배포 훅 (★ 신규 최상위 디렉터리)

```
hooks/
├── hooks.json          SessionStart 훅 선언 (자동 탐색 — 매니페스트 등록 불필요)
├── run-hook.cmd        polyglot 래퍼 (batch + Unix 셸 한 파일, 실행 권한 있음)
└── run-hook.test.sh    래퍼 동작 테스트
```

`run-hook.cmd`는 인자 `<name>`을 `scripts/forge-hook-<name>.{sh,js}`로 해석한다 — 즉 **훅 본체는 `hooks/`가 아니라 `scripts/`에 산다**. 현재 유일한 이름은 `session-start`.

## 5. `scripts/` — 결정론 레이어 (33 파일)

### 5-A. 명명 규칙

| 패턴 | 뜻 | 예 |
| --- | --- | --- |
| `forge-<name>.sh` | bash 원본(1순위 디스패치) | `forge-done.sh` |
| `forge-<name>.js` | node 트윈(폴백) | `forge-done.js` |
| `forge-<name>.test.sh` | behavior 테스트 | `forge-done.test.sh` |
| `forge-<name>.parity.test.sh` | sh↔js 동치 테스트 | `forge-done.parity.test.sh` |
| `forge-hook-<event>.{sh,js}` | 훅 본체(래퍼가 이름으로 해석) | `forge-hook-session-start.sh` |
| `resolve-<thing>.{sh,js}` | forge- 접두 없는 공용 프리미티브 | `resolve-forge-root.sh` |

### 5-B. 트윈 페어링 실측

| 이름 | sh | js | test | parity |
| --- | :-: | :-: | :-: | :-: |
| `forge-status` | ✓ | ✓ | — | ✓ |
| `forge-done` | ✓ | ✓ | ✓ | ✓ |
| `forge-doctor` | ✓ | ✓ | ✓ | ✓ |
| `forge-merge` | ✓ | ✓ | ✓ | ✓ |
| `forge-hook-session-start` | ✓ | ✓ | ✓ | ✓ |
| `forge-statusline` | ✓ | ✓ | ✓ | ✓ |
| `forge-statusline-full` | ✓ | ✓ | ✓ | ✓ |
| `forge-statusline-wrapper` | ✓ | **—** | ✓ | — |
| `resolve-forge-root` | ✓ | ✓ | — | ✓ |

`forge-statusline-wrapper`에 js 트윈이 없는 것은 의도된 예외다(bash 전용 합성 경로 — 그래서 `fg-statusline`이 Windows+기존 statusline 조합에서는 방법 2만 제시한다). `forge-status`·`resolve-forge-root`의 behavior 테스트 부재는 커버리지 공백이다.

### 5-C. 스크립트 헤더 관례

모든 `forge-*.sh` 첫 블록이 고정 구조를 따른다: **왜 존재하는가(근거 ADR) → Usage → Output/Exit codes → Dependencies**. 변경 스크립트는 여기에 "GATE-FIRST, NON-DESTRUCTIVE-ON-REFUSE"를 명시한다. 의존성은 예외 없이 `bash + coreutils + awk/sed/grep`(+ 선택적 `git`/`node`) 수준으로 제한된다.

## 6. `.forge/` — 상태 + 영속 문서

**같은 지붕 아래 두 성격이 섞여 있고, 구분 기준은 위치가 아니라 git 추적 여부다.** `.gitignore`가 `.forge/*`로 통째 제외한 뒤 화이트리스트로 되살린다.

```
.forge/
├── config.json          [추적] 전역 예외 — 모든 브랜치에서 최상위. 현재 {"eco": false}
├── CONTEXT.md           [추적] 도메인 글로서리
├── adr/                 [추적] 40개 (retired/ 아직 없음)
├── retro/               [추적] 52개
├── codebase/            [추적] 전역 예외 — fg-map 산출 7문서 (이 파일 포함)
├── branch/              [추적] 비-기본 브랜치 루트 (현재 비어 있음)
│
├── backlog/             [휘발] 미실행 대기열 — 현재 1건
├── plan.md              [휘발] 활성 슬롯 (현재 없음)
├── run.md               [휘발] 활성 슬롯 (현재 없음)
├── STATUS.md            [휘발] 활성 슬롯 동반 마커 (현재 없음)
├── ask.md               [휘발] fg-ask 그릴링 표시 마커
├── review.md            [휘발] 적대적 리뷰 findings
├── loop.md              [휘발] goal 계약
├── executed/            [휘발] 실행됨·미회고 park (현재 비어 있음)
├── done/                [휘발] 봉인 아카이브 — 현재 107건
├── quick/LOG.md         [휘발] fg-quick 한 줄 로그
├── dropped/             [휘발] fg-drop 보관 (기본 브랜치에선 gitignore)
└── visual/              [휘발] fg-visual 세션 — 전역 예외(항상 최상위)
```

**비대칭 주의**: 기본 브랜치의 휘발 상태는 gitignore되지만, `!.forge/branch/` 화이트리스트 때문에 **비-기본 브랜치 루트는 휘발 파일까지 통째로 추적**된다. 의도된 설계다 — 브랜치 forge 상태를 커밋해야 `git merge`로 넘어오고, `fg-merge`가 통합할 수 있다.

## 7. 명명 규칙 총정리

| 대상 | 규칙 | 실례 |
| --- | --- | --- |
| 스킬 디렉터리 | `fg-<verb-or-noun>` (전부 소문자·하이픈) | `fg-adversarial-review/` |
| 스킬 식별자 | frontmatter `name` — 디렉터리명과 동일하게 유지 | `name: fg-run` |
| 형식 문서 | `<THING>-FORMAT.md` 대문자 | `PLAN-FORMAT.md` |
| 규율 문서 | 대문자 명사 1단어 | `DRIVE.md`, `ECO.md`, `VISUAL.md`, `FORGE-ROOT.md`, `RUN-ALL.md` |
| ADR — 현행 | `YYMMDD-HHMMSS-slug.md` (같은 초 충돌 시에만 소문자 글자) | `260727-201115-fg-ask-auto-close-sealable-tail.md` |
| ADR — 레거시 시간ID | `YYMMDD-HH<letter>-slug.md` | `260717-10a-fg-merge-optin-git-merge-mode.md` |
| ADR — grandfathered 순차 | `NNNN-slug.md` (0001–0032, 동결·재사용 금지) | `0030-fg-done-deterministic-seal-script.md` |
| ADR 은퇴 | `adr/retired/<원래ID>-slug.md`로 **이동** — 번호 불변, 삭제 없음 | (현재 `retired/` 미생성) |
| 회고 — 현행 | `YYMMDD-HHMMSS-slug.md` | `260722-194710-fg-agents-update-and-retro-fuel.md` |
| 회고 — 레거시 | `YYYY-MM-DD-slug.md` | `2026-07-17-fg-merge-run-git.md` |
| 봉인 디렉터리 — 현행 | `done/<YYMMDD-HHMMSS>-<slug>/` (같은 초·같은 slug 충돌 시 serial letter) | `done/260728-001632-fg-visual-click-feedback-and-event-label/` |
| 봉인 디렉터리 — 레거시 | `done/<YYYY-MM-DD>-<slug>/` | `done/2026-06-04-add-fg-quick/` |
| plan slug 마커 | 첫 줄 `<!-- forge-slug: <slug> -->` — 파일이 이동해도 영속하는 짝 맞춤 키 | |
| plan 부가 마커 | `<!-- task: N -->`, `<!-- priority: high\|medium\|low -->`, `<!-- tdd: on -->`, `<!-- retro-hint: optional -->`, `<!-- generated-by: … -->`, `<!-- repaired-by: fg-loop -->` | |
| 커밋 | Conventional Commits + 한국어 요지 | `feat(hooks,fg-ask): …`, `chore(release): vX.Y.Z` |

**시간ID 스킴 세 형식이 공존한다.** 순차 `NNNN`은 동결(더 이상 발급 안 함), `YYMMDD-HH<letter>`는 과도기, 현행은 `YYMMDD-HHMMSS`다. 근거: `.forge/adr/260716-13a-adr-time-based-id-scheme.md`, `.forge/adr/260719-161701-time-precise-naming.md`. 시계 기반이라 병렬 브랜치가 공유 카운터에서 충돌하지 않는 것이 요점이다.

## 8. `docs/` — 사용자 문서

```
docs/
├── index.html                          574행 — 랜딩 페이지. KO/EN을 한 파일에
│                                       data-l="ko" / data-l="en" span으로 병기
├── skills.md                           127행 — 19행 스킬 카탈로그(6열)
├── state-contract.md                   143행
├── git-workflow.md                     177행
├── team-workflow.md                     65행
├── forge-vs-loop-engineering.md         48행
├── examples/github-actions-forge-check.yml   사용자 프로젝트용 CI 예제
└── icon.png · icon-sm.png · workflow.png · footer-forge-bg.png
```

`docs/*.md`는 **한국어**로 쓰여 있다(README 이중언어 쌍과 다른 정책).

## 9. `.claude/` — 이 리포 개발용 자산 (배포 대상 아님)

```
.claude/
├── agents/manifest-doc-syncer.md    매니페스트·버전·이중언어 동기 전문가
├── agents/script-twin-engineer.md   forge-*.{sh,js} 트윈 + 테스트 전문가
├── agents/skill-author.md           SKILL.md·형식문서 저술 전문가
├── skills/issue-triage/SKILL.md     로컬 스킬 (플러그인 `skills/`와 무관)
└── settings.local.json
```

`.claude/agents/`는 **세션 시작 시 1회 로드**되므로 세션 중 만든 카드는 그 세션에서 쓸 수 없다(`hooks/`와 같은 성질). `fg-agents`가 사용자 프로젝트에 생성하는 카드도 같은 위치·같은 제약이다.

## 10. 동기 지점 — 한 곳을 고치면 함께 고쳐야 하는 짝

| 고치는 곳 | 함께 고쳐야 하는 곳 |
| --- | --- |
| 스킬 추가/개명/삭제 | `plugin.json` description · `marketplace.json` plugins[].description · `CLAUDE.md` 스킬 목록 · `README.md` **+** `README.ko.md` · `docs/skills.md` |
| 버전 범프 | `plugin.json`.version · `marketplace.json`.metadata.version · `marketplace.json`.plugins[0].version (**3곳**) |
| `README.md` 수정 | `README.ko.md` 동일 변경 (역방향도) |
| `docs/index.html` 한쪽 언어 | 짝이 되는 `data-l` span |
| 상태 계약·게이트 변경 | `docs/state-contract.md` · 관련 SKILL.md · 해당 스크립트 + 테스트 |
| `forge-*.sh` 변경 | `.js` 트윈 · `*.test.sh` · `*.parity.test.sh` |
| forge 루트 규칙 | `skills/fg-run/FORGE-ROOT.md` **한 곳만** (+ `resolve-forge-root.{sh,js}`) — 복붙 금지 |
| `fg-ask/SKILL.md` | verbatim 본문과 하단 "Forge integration (minimal)" 섹션이 따로 움직임 — 둘의 정합 확인 |

`fg-doctor`가 이 정합 위반 다수(버전 3곳 드리프트·README 이중언어 드리프트·`CLAUDE.md` 스킬 목록 누락·ADR ID 유일성·트윈 누락)를 exit 0/1/2로 검사한다.

## 11. 스킬 문서 작성 규약 (편집 시 지켜야 할 것)

- **언어**: `SKILL.md`·`*-FORMAT.md` 본문은 **영문**. 단 스킬이 사용자에게 **출력하는** 언어는 사용자 언어를 따르고, 사용자 프로젝트에 남는 산출 문서(plan·회고·CONTEXT·ADR)도 사용자 언어로 쓴다. 이 지시가 각 SKILL.md 상단에 "**Language**:" 문단으로 반복 명시돼 있다.
- **흐름도**: 스킬 문서에는 **Mermaid 금지**, 텍스트 흐름도(`A → B → C`)만 쓴다. 에이전트가 렌더링 없이 파싱하고 diff·grep이 가능해야 하기 때문이다. (이 규약은 스킬 문서 한정 — `.forge/codebase/`·사용자 산출 문서에는 적용되지 않는다.)
- **핸드오프**: 끝에서 "방금 한 것 / 다음 단계 / 시작하는 법"을 **진술형** 대화체로. "진행할까요?" 금지.
- **참조**: 다른 스킬의 문서는 `${CLAUDE_PLUGIN_ROOT}/skills/<owner>/<file>` 또는 상대경로(`../fg-run/FORGE-ROOT.md`)로 참조하고 **자체 복사하지 않는다**. 루트 `references/` 디렉터리는 폐지됐다(트리에 없음 — 확인).
