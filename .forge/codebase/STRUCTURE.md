---
last_mapped_commit: a7a9c3e474a5717d23294a9cc0bec18ec1158130
mapped: 2026-08-06
---

# STRUCTURE

> **구현 사실만** 담는다. 도메인 용어의 뜻은 `.forge/CONTEXT.md` 소관이며 여기서 정의하지 않는다.
> 모든 개수·행수는 작업 트리에서 직접 셌다(`wc -l`, `ls | wc -l`, `grep -c`). 문서와 트리가 어긋난 지점은 §11에 모아 두었다.
> 매핑 대상은 HEAD(`a7a9c3e4`, v0.6.4)가 아니라 **미커밋 변경을 포함한 작업 트리**다.

## 1. 최상위 레이아웃

리포 루트가 곧 **플러그인 루트이자 마켓플레이스**다(`harness` 플러그인과 같은 단일 리포 패턴).

```
forge/
├── .claude-plugin/          플러그인·마켓플레이스 매니페스트 (2 JSON)
├── skills/                  fg-* 스킬 20개 — 자동 탐색 (마크다운 29파일 3,299행)
├── hooks/                   배포 훅 1개 + polyglot 래퍼 + 래퍼 테스트 (3 파일)
├── scripts/                 결정론 bash/node 트윈 17 + 셸 테스트 15 = 32 파일
├── docs/                    사용자 문서(한국어) 5 + 랜딩 페이지 + 이미지 4 + 예제 1 + .nojekyll
├── .forge/                  forge 자신의 루프 상태 + 영속 문서 (dogfooding)
├── .claude/                 이 리포 개발용 프로젝트 자산 (배포 대상 아님)
├── CLAUDE.md                에이전트용 리포 지침 — 147행 / 36KB (사실상 스펙 문서)
├── README.md (223행) / README.ko.md (222행)   이중언어 쌍
├── CHANGELOG.md             652행 — Keep a Changelog 약식
├── .gitignore               .forge/ 화이트리스트 규칙이 여기 있음 (23행)
├── .graphifyignore          2행 — 외부 도구 graphify에게 `.forge/`를 숨긴다(장부는 코드가 아님)
└── .gitattributes           `*.sh text eol=lf` — Windows CRLF 방어(load-bearing)
```

**빌드 산출물·의존성 디렉터리가 없다**: `package.json`·`node_modules/`·`Makefile`·`.github/` 모두 부재. `.antigravitycli/`(빈 디렉터리)와 `.DS_Store`는 개발 환경 잔여물이다.

`.graphifyignore`(git 추적)와 `.gitignore`의 `graphify-out/` 줄은 **나란히 쓰는 외부 도구**를 위한 것이다 — graphify는 forge를 대체하지 않고(ADR `260801-223500`) 산출물은 커밋하지 않으며, 스캔에서 `.forge/`를 뺀 이유는 봉인된 plan/run·ADR·회고·지도가 **코드가 아니라 장부**라 그래프를 오염시키기 때문이다(실측: `.forge/` 231파일이 그래프의 15%를 차지했다).

`.gitattributes`의 `*.sh text eol=lf`는 장식이 아니다 — CRLF로 체크아웃되면 `\r`이 shebang·인자에 섞여 스크립트가 실행 실패하고, sh/js 트윈 규약(ADR-0022)이 Windows에서 git-bash의 `.sh`를 1순위로 쓰므로 이 가드가 그쪽에서 하중을 받는다.

## 2. `.claude-plugin/` — 매니페스트

| 파일 | 역할 | 확인된 사실 |
| --- | --- | --- |
| `plugin.json` | 플러그인 매니페스트 | 키: `name`·`description`·`version`·`author`·`homepage`·`repository`·`license`·`keywords`. **`skills` 필드 없음** → `skills/` 자동 탐색. **`hooks` 필드도 없음** → `hooks/hooks.json` 자동 탐색 |
| `marketplace.json` | 이 리포를 마켓플레이스로 등록 | `plugins[0].source == "./"` (루트가 곧 플러그인), `category: "workflow"` |

**버전은 3곳을 반드시 동기 갱신**한다 — 현재 전부 `0.6.4`:

```
plugin.json      : version
marketplace.json : metadata.version
marketplace.json : plugins[0].version
```

두 `description`은 역할이 다르다. `marketplace.json`의 `metadata.description`은 **루프만** 정의하는 한 줄 태그라인(루프 밖 유틸리티 제외), `plugins[].description`과 `plugin.json`의 `description`은 **전체 스킬 목록**을 담는 긴 설명(루프 밖 스킬 포함, "Twenty fg-* skills"로 시작). 이 두 긴 설명은 단일 문자열로 각각 9,289자·10,446자다.

편집 후 유효성 검사(깨지면 설치 실패):

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

## 3. `skills/` — 20개

디렉터리당 `SKILL.md` 1개가 필수이고, 일부는 동반 문서를 함께 둔다.

| 디렉터리 | frontmatter `name` | SKILL.md 행 | 동반 파일 | 루프 위치 |
| --- | --- | --: | --- | --- |
| `fg-ask/` | fg-ask | 136 | `CONTEXT-FORMAT.md`(60), `ADR-FORMAT.md`(63) | ① 질의·그릴링 |
| `fg-run/` | fg-run | 180 | `FORGE-ROOT.md`(62), `PLAN-FORMAT.md`(70), `RUN-ALL.md`(16) | ② 실행 |
| `fg-learn/` | fg-learn | 116 | `RETRO-FORMAT.md`(47) | ③ 회고 |
| `fg-done/` | fg-done | 178 | — | ④ 봉인 |
| `fg-next/` | fg-next | 144 | `DRIVE.md`(38) | 루프 밖 (오케스트레이터) |
| `fg-loop/` | fg-loop | 180 | — | 루프 밖 (goal 주행) |
| `fg-status/` | fg-status | 122 | — | 루프 밖 (읽기 전용 리포터) |
| `fg-agenda/` | fg-agenda | 161 | — | 루프 밖 (결정 대기열) |
| `fg-doctor/` | fg-doctor | 81 | — | 루프 밖 (health check) |
| `fg-map/` | fg-map | 118 | — | 루프 밖 (코드베이스 지도) |
| `fg-quick/` | fg-quick | 66 | — | 루프 밖 (경량 차선) |
| `fg-merge/` | fg-merge | 131 | — | 루프 밖 (브랜치 통합) |
| `fg-cleanup/` | fg-cleanup | 63 | — | 루프 밖 (ADR 은퇴) |
| `fg-drop/` | fg-drop | 102 | — | 루프 밖 (미완 폐기) |
| `fg-agents/` | fg-agents | 140 | — | 루프 밖 (역할 카드 생성) |
| `fg-adversarial-review/` | fg-adversarial-review | 118 | — | 루프 밖 (선택적 리뷰) |
| `fg-statusline/` | fg-statusline | 217 | — | 루프 밖 (설정) |
| `fg-tdd/` | fg-tdd | 47 | — | 루프 밖 (토글) |
| `fg-eco/` | fg-eco | 63 | `ECO.md`(156) | 루프 밖 (토글 + 규율) |
| `fg-visual/` | fg-visual | 53 | `VISUAL.md`(371), `LICENSE`(21), `scripts/`(5파일) | 루프 밖 (시각 컴패니언) |

**20개 전부 디렉터리명 == frontmatter `name`**(일치 확인). 다만 **식별자는 frontmatter의 `name`이지 디렉터리명이 아니다** — 개명 시 둘을 함께 바꿔야 하고, `name:`이 아예 없으면 자동 탐색되지 않는다(`forge-doctor` B10이 error로 잡는다).

### 3-A. `skills/fg-visual/scripts/` — 유일한 벤더링 자산

obra/superpowers v6.1.1의 Visual Companion을 MIT 귀속과 함께 그대로 들여왔다. `skills/fg-visual/LICENSE`가 귀속 파일이며, forge에서 **`LICENSE` 파일을 가진 유일한 스킬**이다.

```
skills/fg-visual/scripts/
├── server.cjs           677행 / 24KB — zero-dependency Node 서버
├── helper.js            209행 — 에이전트 측 헬퍼
├── frame-template.html  218행 — 브라우저 프레임 템플릿
├── start-server.sh      214행 (실행 권한 있음)
└── stop-server.sh       124행 (실행 권한 있음)
```

이 `scripts/`는 루트 `scripts/`(결정론 트윈)와 **완전히 별개**다 — 명명 규칙(`forge-*` 접두 없음)·언어(`.cjs`)·테스트 유무·계약이 모두 다르다. 세션 파일은 모든 브랜치에서 최상위 `.forge/visual/<세션>/`에 쓴다(휘발·gitignore — 브랜치 루트 아님). 벤더링 원본은 **byte-identical 유지**가 방침이라, 확장 기능은 전부 호출 측에서 우회한다: 텍스트·확정 이벤트는 서버의 `choice` 가드를 통과하도록 `choice: "text:<field>"`/`"confirm:<sel>"`를 함께 싣고, 확정 버튼은 push하는 화면 HTML의 **인라인 `onclick`**이지 `helper.js`/`frame-template.html` 수정이 아니다.

### 3-B. 크기 감각 (참고)

가장 긴 것들: `fg-visual/VISUAL.md` 371행, `fg-statusline/SKILL.md` 217행, `fg-run/SKILL.md`·`fg-loop/SKILL.md` 각 180행, `fg-done/SKILL.md` 178행, `fg-agenda/SKILL.md` 161행, `fg-eco/ECO.md` 156행, `fg-next/SKILL.md` 144행. 가장 짧은 것: `fg-run/RUN-ALL.md` 16행(progressive disclosure 분리 조각), `fg-tdd/SKILL.md` 47행. `skills/` 전체 마크다운(29파일) 합계 **3,299행**.

## 4. `hooks/` — 배포 훅 (3 파일)

```
hooks/
├── hooks.json          341B — SessionStart 훅 선언 (자동 탐색 — 매니페스트 등록 불필요)
├── run-hook.cmd        89행 — polyglot 래퍼 (batch + Unix 셸 한 파일, 실행 권한 있음)
└── run-hook.test.sh    113행 — 래퍼 동작 테스트
```

`run-hook.cmd`는 인자 `<name>`을 `scripts/forge-hook-<name>.{sh,js}`로 해석한다 — 즉 **훅 본체는 `hooks/`가 아니라 `scripts/`에 산다**. 현재 유일한 이름은 `session-start`. 훅 파일은 세션 시작 시 로드되므로 이 디렉터리를 고치면 **다음 세션부터** 적용된다.

## 5. `scripts/` — 결정론 레이어 (32 파일)

### 5-A. 명명 규칙

| 패턴 | 뜻 | 예 |
| --- | --- | --- |
| `forge-<name>.sh` | bash 원본(1순위 디스패치) | `forge-done.sh` |
| `forge-<name>.js` | node 트윈(폴백, `#!/usr/bin/env node`) | `forge-done.js` |
| `forge-<name>.test.sh` | behavior 테스트 | `forge-done.test.sh` |
| `forge-<name>.parity.test.sh` | sh↔js 동치 테스트 | `forge-done.parity.test.sh` |
| `forge-hook-<event>.{sh,js}` | 훅 본체(래퍼가 이름으로 해석) | `forge-hook-session-start.sh` |
| `resolve-<thing>.{sh,js}` | `forge-` 접두 없는 공용 프리미티브 | `resolve-forge-root.sh` |

호출은 항상 `bash <path>` / `node <path>` 형태이므로 실행 권한은 계약이 아니다 — 실제로 13파일만 `u+x`이고 19파일은 아니다(`forge-doctor.sh`·`forge-merge.sh`·`forge-hook-session-start.sh`가 비실행). 새 스크립트를 만들 때 `chmod +x`는 필수가 아니다.

### 5-B. 트윈 페어링 실측

| 이름 | sh | js | behavior test | parity test |
| --- | :-: | :-: | :-: | :-: |
| `forge-status` | ✓ (190) | ✓ (184) | **—** | ✓ (159) |
| `forge-done` | ✓ (185) | ✓ (171) | ✓ (254) | ✓ (84) |
| `forge-doctor` | ✓ (187) | ✓ (181) | ✓ (88) | ✓ (55) |
| `forge-merge` | ✓ (354) | ✓ (329) | ✓ (155) | ✓ (74) |
| `forge-hook-session-start` | ✓ (233) | ✓ (188) | ✓ (399) | ✓ (188) |
| `forge-statusline` | ✓ (212) | ✓ (186) | ✓ (248) | ✓ (126) |
| `forge-statusline-full` | ✓ (213) | ✓ (170) | ✓ (311) | ✓ (126) |
| `forge-statusline-wrapper` | ✓ (46) | **—** | ✓ (113) | — |
| `resolve-forge-root` | ✓ (38) | ✓ (57) | **—** | ✓ (68) |

합계: 구현 17파일 3,124행 + 테스트 15파일 2,448행. `forge-statusline-wrapper`에 js 트윈이 없는 것은 의도된 예외(bash 전용 합성 경로)이며 `forge-doctor.sh`의 B15 검사가 `*-wrapper.sh`를 명시 제외한다. `forge-status`·`resolve-forge-root`의 behavior 테스트 부재는 커버리지 공백이다.

### 5-C. 스크립트 헤더 관례

모든 `forge-*.sh` 첫 블록이 고정 구조를 따른다: **왜 존재하는가(근거 ADR) → Usage → Output/Exit codes → Dependencies**. 변경 스크립트는 여기에 "GATE-FIRST, NON-DESTRUCTIVE-ON-REFUSE"와 "이 스크립트는 라우팅하지 않는다"를 명시한다. 의존성은 예외 없이 `bash + coreutils + awk/sed/grep`(+ 선택적 `git`/`node`) 수준으로 제한된다 — jq 없음, 패키지 없음.

## 6. `.forge/` — 상태 + 영속 문서

**같은 지붕 아래 두 성격이 섞여 있고, 구분 기준은 위치가 아니라 git 추적 여부다.** `.gitignore`가 `.forge/*`로 통째 제외한 뒤 화이트리스트로 되살린다.

```
.forge/
├── config.json          [추적] 전역 예외 — 모든 브랜치에서 최상위. 현재 {"eco": false}
├── CONTEXT.md           [추적] 도메인 글로서리
├── adr/                 [추적] 47개 (retired/ 아직 없음)
├── retro/               [추적] 58개
├── codebase/            [추적] 전역 예외 — fg-map 산출 7문서 (이 파일 포함).
│                        각 문서 frontmatter의 last_mapped_commit이 신선도 신호이자
│                        증분 Update의 diff 기준점 (ADR 260801-020258)
├── branch/              [추적] 비-기본 브랜치 루트 (현재 비어 있음)
│
├── agenda.md            [휘발] fg-agenda 결정 대기열 — 현재 1건(31행). 브랜치별(전역 예외 아님),
│                        상태 기계 밖 — fg-status가 한 줄로만 보고하고 다음 단계로 도출하지 않음
├── backlog/             [휘발] 미실행 대기열 — 현재 1건 (handoff-table)
├── executed/            [휘발] 실행됨·미회고 park — 현재 0건
├── done/                [휘발] 봉인 아카이브 — 현재 118건, 각 dir = plan.md+run.md+STATUS.md
├── quick/LOG.md         [휘발] fg-quick 한 줄 로그 (현재 40행)
├── dropped/             [휘발] fg-drop 보관 — 현재 1건 (기본 브랜치에선 gitignore)
└── visual/              [휘발] fg-visual 세션 5건 + .last-port/.last-token — 전역 예외(항상 최상위)
```

현재 트리에 **없는** 휘발 파일(조건부 lazy 생성): 활성 슬롯 3종(`plan.md`·`run.md`·`STATUS.md` — 슬롯이 비어 있다), `ask.md`(fg-ask 그릴링 표시 마커), `review.md`(적대적 리뷰 findings), `loop.md`(goal 계약).

**비대칭 주의**: 기본 브랜치의 휘발 상태는 gitignore되지만, `!.forge/branch/` 화이트리스트 때문에 **비-기본 브랜치 루트는 휘발 파일까지 통째로 추적**된다. 의도된 설계다 — 브랜치 forge 상태를 커밋해야 `git merge`로 넘어오고, `fg-merge`가 통합할 수 있다. 미커밋 브랜치 루트는 기본 브랜치에 도달하지 못한다.

## 7. 명명 규칙 총정리

| 대상 | 규칙 | 실례 |
| --- | --- | --- |
| 스킬 디렉터리 | `fg-<verb-or-noun>` (전부 소문자·하이픈) | `fg-adversarial-review/` |
| 스킬 식별자 | frontmatter `name` — 디렉터리명과 동일하게 유지 | `name: fg-run` |
| 형식 문서 | `<THING>-FORMAT.md` 대문자 | `PLAN-FORMAT.md` |
| 규율·공유 문서 | 대문자 명사 | `DRIVE.md`, `ECO.md`, `VISUAL.md`, `FORGE-ROOT.md`, `RUN-ALL.md` |
| ADR — 현행 | `YYMMDD-HHMMSS-slug.md` (같은 초 충돌 시에만 소문자 글자) | `260801-020258-fg-map-diff-incremental-update.md` |
| ADR — 레거시 시간ID | `YYMMDD-HH<letter>-slug.md` (4개) | `260717-10a-fg-merge-optin-git-merge-mode.md` |
| ADR — grandfathered 순차 | `NNNN-slug.md` (0001–0032, 동결·재사용 금지) | `0030-fg-done-deterministic-seal-script.md` |
| ADR 은퇴 | `adr/retired/<원래ID>-slug.md`로 **이동** — 번호 불변, 삭제 없음 | (현재 `retired/` 미생성) |
| 회고 — 현행 | `YYMMDD-HHMMSS-slug.md` (9개) | `260805-212943-fg-agenda-decision-queue.md` |
| 회고 — 레거시 | `YYYY-MM-DD-slug.md` (49개) | `2026-07-06-fg-done-seal-summary.md` |
| 봉인 디렉터리 — 현행 | `done/<YYMMDD-HHMMSS>-<slug>/` (같은 초·같은 slug 충돌 시 serial letter) — 21개 | `done/260731-154221-forge-merge-context-term-parser/` |
| 봉인 디렉터리 — 레거시 | `done/<YYYY-MM-DD>-<slug>/` — 97개 | `done/2026-06-04-add-fg-quick/` |
| 폐기 보관 | `dropped/<slug>/<slug>.md` | `dropped/docs-forge-vs-graph-engineering/` |
| plan slug 마커 | 첫 줄 `<!-- forge-slug: <slug> -->` — 파일이 이동해도 영속하는 짝 맞춤 키 | |
| plan 부가 마커 | `<!-- task: N -->`, `<!-- priority: high\|medium\|low -->`, `<!-- part: N/M -->`, `<!-- tdd: on\|off -->`, `<!-- retro-hint: optional -->`, `<!-- generated-by: fg-loop -->`, `<!-- repaired-by: fg-loop -->` | |
| 슬라이스 id | `S1`, `S2`, … (`(depends: S1)`로 직렬 표기) | |
| 커밋 | Conventional Commits + 한국어 요지 | `fix(hooks,fg-visual,fg-merge): …`, `chore(release): vX.Y.Z` |

**시간ID 스킴 세 형식이 공존한다.** 순차 `NNNN`은 동결(더 이상 발급 안 함, 32개에서 멈춤), `YYMMDD-HH<letter>`는 과도기(4개), 현행은 `YYMMDD-HHMMSS`(11개)다. 근거: `.forge/adr/260716-13a-adr-time-based-id-scheme.md`, `.forge/adr/260719-161701-time-precise-naming.md`. 시계 기반이라 병렬 브랜치가 공유 카운터에서 충돌하지 않는 것이 요점이고, `forge-doctor` B14가 두 형식 모두의 ID 유일성을 검사한다.

## 8. `docs/` — 사용자 문서

```
docs/
├── index.html                          693행 — 랜딩 페이지. KO/EN을 한 파일에
│                                       data-l="ko" / data-l="en" span으로 병기 (각 117개, 균형)
├── skills.md                           137행 — 6열 스킬 카탈로그(20행) + 스킬별 상세
├── state-contract.md                   144행 — 상태 계약·게이트 문서
├── git-workflow.md                     177행
├── team-workflow.md                     65행
├── forge-vs-loop-engineering.md         48행
├── examples/github-actions-forge-check.yml   59행 — 사용자 프로젝트용 CI 예제
└── icon.png · icon-sm.png · workflow.png · footer-forge-bg.png
```

`docs/*.md`는 **한국어**로 쓰여 있다(README 이중언어 쌍과 다른 정책 — README는 en/ko 두 파일, docs는 한국어 단일). `docs/index.html`만 한 파일 안에서 언어 토글로 전환한다(ADR-0027).

## 9. `.claude/` — 이 리포 개발용 자산 (배포 대상 아님)

```
.claude/
├── agents/manifest-doc-syncer.md    34행 — 매니페스트·버전·이중언어 동기 전문가
├── agents/script-twin-engineer.md   34행 — forge-*.{sh,js} 트윈 + 테스트 전문가
├── agents/skill-author.md           33행 — SKILL.md·형식문서 저술 전문가
├── skills/issue-triage/SKILL.md     74행 — 로컬 스킬 (플러그인 `skills/`와 무관)
└── settings.local.json              로컬 권한 설정
```

`.claude/agents/`는 **세션 시작 시 1회 로드**되므로 세션 중 만든 카드는 그 세션에서 쓸 수 없다(`hooks/`와 같은 성질 — ADR-0024). `fg-agents`가 사용자 프로젝트에 생성하는 카드도 같은 위치·같은 제약이고, 카드는 forge 상태가 아니라 프로젝트 자산이라 git 커밋 대상이다. 카드 3장의 `description`은 fg-run의 slice↔role 자동 매핑 입력이므로 "언제 쓰이나"를 담는다.

## 10. 동기 지점 — 한 곳을 고치면 함께 고쳐야 하는 짝

| 고치는 곳 | 함께 고쳐야 하는 곳 |
| --- | --- |
| 스킬 추가/개명/삭제 | `plugin.json` description · `marketplace.json` plugins[].description(+"Twenty…" 개수 문구) · `CLAUDE.md` 스킬 목록 · `README.md` **+** `README.ko.md` · `docs/skills.md` · `docs/index.html`(KO/EN 두 span) |
| 버전 범프 | `plugin.json`.version · `marketplace.json`.metadata.version · `marketplace.json`.plugins[0].version (**3곳**) |
| `README.md` 수정 | `README.ko.md` 동일 변경 (역방향도) |
| `docs/index.html` 한쪽 언어 | 짝이 되는 `data-l` span |
| 상태 계약·게이트 변경 | `docs/state-contract.md` · 관련 SKILL.md · 해당 스크립트 + `*.test.sh` + `*.parity.test.sh` |
| `forge-*.sh` 변경 | `.js` 트윈 · behavior 테스트 · parity 테스트 |
| forge 루트 규칙 | `skills/fg-run/FORGE-ROOT.md` **한 곳만** (+ `resolve-forge-root.{sh,js}`) — 복붙 금지 |
| eco 요약 표 형태 | `skills/fg-eco/ECO.md` **한 곳만** — fg-run·fg-done·DRIVE.md는 참조만 |
| 무인 주행 규율 | `skills/fg-next/DRIVE.md` **한 곳만** — 벽 집합만 각 레인(fg-next all·fg-loop)이 채움 |
| `fg-ask/SKILL.md` | verbatim 본문과 하단 "Forge integration (minimal)" 섹션이 따로 움직임 — 둘의 정합 확인 |
| 릴리스 | `CHANGELOG.md` 새 섹션 → README(이중언어)·docs → 버전 3곳 → JSON 검증 → `chore(release): vX.Y.Z` 커밋 + main push |

`fg-doctor`(= `scripts/forge-doctor.sh`)가 이 정합 위반 다수를 exit 0/1/2로 검사한다 — 버전 3곳 드리프트(B8), 매니페스트 JSON 파싱(B9), SKILL `name:` 누락(B10), `CLAUDE.md` 스킬 목록 누락(B12), README 이중언어 스킬 행 수 불일치(B13), ADR ID 중복·NNNN 갭(B14), 트윈 누락(B15), description 길이 600 초과(B16). 매핑 시점 실행 결과는 `0 errors, 0 warnings, 0 info`(exit 0)다.

## 11. 스킬 문서 작성 규약 (편집 시 지켜야 할 것)

- **언어**: `SKILL.md`·`*-FORMAT.md` 본문은 **영문**. 단 스킬이 사용자에게 **출력하는** 언어는 사용자 언어를 따르고, 사용자 프로젝트에 남는 산출 문서(plan·회고·CONTEXT·ADR·STATUS)도 사용자 언어로 쓴다. 이 지시가 각 SKILL.md 상단에 "**Language**:" 문단으로 반복 명시돼 있다.
- **흐름도**: 스킬 문서에는 **Mermaid 금지**, 텍스트 흐름도(`A → B → C`, 분기는 들여쓰기·`──▶`·조건 레이블)만 쓴다. 에이전트가 렌더링 없이 파싱하고 diff·grep이 가능해야 하기 때문이다. (이 규약은 스킬 문서 한정 — `.forge/codebase/`·사용자 산출 문서에는 적용되지 않는다.)
- **핸드오프**: 끝에서 "방금 한 것 / 다음 단계 / 시작하는 법"을 **진술형** 대화체로. "진행할까요?" 금지(체이닝은 fg-next 전담).
- **참조**: 다른 스킬의 문서는 `${CLAUDE_PLUGIN_ROOT}/skills/<owner>/<file>` 또는 상대경로(`../fg-run/FORGE-ROOT.md`)로 참조하고 **자체 복사하지 않는다**. 루트 `references/` 디렉터리는 폐지됐다(트리에 없음 — 확인).
- **`description` 길이**: frontmatter `description`은 트리거 문구이자 `/fg` 메뉴 표시라서 600 코드포인트 상한을 넘기면 `forge-doctor` B16이 경고한다.

## 12. 문서-트리 불일치 (구조 관점)

- **스킬 개수**: 트리 20 · `docs/skills.md` 카탈로그 20행 · `README.md`/`README.ko.md` 스킬 행 각 20 · `marketplace.json` "Twenty" — 일치. 단 `.claude/agents/manifest-doc-syncer.md`의 `description`만 **"18-스킬"**로 남아 있다(개발용 카드라 doctor B12 범위 밖). 트리가 정답이고, 격차는 1에서 2로 벌어졌다.
- **`CLAUDE.md`의 공유 정의 목록에 `skills/fg-run/RUN-ALL.md`가 없다**(`grep -c "RUN-ALL" CLAUDE.md` → 0). 트리에 실재하고 fg-run이 참조한다.
- **결정됐지만 트리에 없는 파일 1건**: `skills/fg-next/HANDOFF.md`. ADR `260805-231104`(고정 4행 핸드오프 표)가 단일 정의로 지목했으나 아직 미구현이고, 계획은 `.forge/backlog/handoff-table.md`(task 108)로 대기 중이다 — 드리프트가 아니라 **미착수**다. 착수하면 §10의 동기 지점에 "핸드오프 표 형태 → `skills/fg-next/HANDOFF.md` 한 곳"이 추가된다.
- **behavior 테스트 공백 2건**: `forge-status`·`resolve-forge-root`(§5-B).
- **`README.md` 223행 vs `README.ko.md` 222행** — 행수 자체는 번역 길이 차이로 정상 범위이고, doctor B13은 행수가 아니라 **스킬 행 개수**로 드리프트를 판정한다(현재 통과: 20 == 20).
- 매핑 시점 `bash scripts/forge-doctor.sh` → `0 errors, 0 warnings, 0 info`(exit 0).
