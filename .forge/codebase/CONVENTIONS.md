---
last_mapped_commit: c1100b17577529833c68ca5a8c59ee1e310f24d4
mapped: 2026-07-28
---

# CONVENTIONS

이 문서는 **구현 사실만** 다룬다. 도메인 용어의 정의는 `.forge/CONTEXT.md` 소관이고, 여기서는 "무엇을 어떻게 쓰기로 되어 있는가 + 실제 파일에서 그게 지켜지는가"만 기록한다. 모든 주장은 이 커밋 시점의 실제 파일에 대고 확인했으며, 근거 경로를 백틱으로 붙였다.

## 0. 이 리포에서 "코드"란 무엇인가

빌드·테스트 러너·린터·포매터가 **없다**. `package.json`·`Makefile`·CI 워크플로가 없고, `.github/` 디렉터리 자체가 존재하지 않는다(확인: `ls .github` → 없음). 따라서 컨벤션은 툴이 아니라 **문서화된 규율 + 두 개의 자동 검사**로만 강제된다.

산출물은 네 종류다.

| 종류 | 경로 | 언어/형식 |
| --- | --- | --- |
| 스킬 지시문 (산문) | `skills/<name>/SKILL.md` 19개 + 공유 문서 9개 | 영문 Markdown |
| 결정론 스크립트 트윈 | `scripts/forge-*.{sh,js}`, `scripts/resolve-forge-root.{sh,js}` | bash + node |
| 매니페스트 | `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `hooks/hooks.json` | JSON |
| 플러그인 훅 | `hooks/run-hook.cmd` (polyglot 래퍼) + `scripts/forge-hook-session-start.{sh,js}` | cmd/bash polyglot + bash/node |

vendoring 예외 한 곳: `skills/fg-visual/scripts/`(`server.cjs`·`helper.js`·`start-server.sh`·`stop-server.sh`)는 obra/superpowers v6.1.1에서 MIT 귀속과 함께 그대로 가져온 코드다. 파일 상단에 vendoring 출처·라이선스·forge 수정점이 주석으로 명시되어 있고(`skills/fg-visual/scripts/start-server.sh:1-5`), **트윈 규약·패리티 대상이 아니다** — `.claude/agents/script-twin-engineer.md`가 이를 명시적 범위 밖으로 선언한다.

자동 검사는 둘뿐이다.

1. `bash scripts/forge-doctor.sh` — 상태 계약 + 문서/매니페스트 정합. 현재 이 리포에서 **0 errors, 0 warnings, 0 info**.
2. `bash <파일>.test.sh` / `<파일>.parity.test.sh` — 스크립트 동작·패리티. 상세는 `TESTING.md`.

흐름: `편집 → forge-doctor.sh → 관련 *.test.sh → (스크립트라면) *.parity.test.sh`

---

## 1. 언어 규약

### 1.1 "본문은 영문, 출력은 사용자 언어"

`SKILL.md` 본문과 `*-FORMAT.md`는 영문으로 쓰되, **스킬이 사용자에게 내보내는 모든 텍스트는 사용자 언어**다. 이 지시는 각 스킬에 명문화되어 있고, 실측으로 19개 SKILL.md **전부**가 "user's language" 문구를 최소 1회 포함한다(fg-status 6회, fg-done 5회, fg-loop 4회, fg-ask·fg-doctor·fg-merge·fg-next·fg-run 3회, 나머지 1~2회).

정본 문구는 `skills/fg-done/SKILL.md:9`의 **Language** 블록이다:

> This skill file is authored in English, but **you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English.**

같은 블록이 산출 문서(plan·run notes·retro·CONTEXT 엔트리·ADR·핸드오프)도 사용자 언어로 쓰라고 규정하고, **형식 문서의 섹션 제목은 영문 정본 이름이지만 렌더링은 사용자 언어이고 소비자는 문자열이 아니라 의미·위치로 매칭한다**고 못 박는다. 이게 "형식 문서는 영문인데 생성된 문서는 한국어"라는 겉보기 모순의 해소 규칙이다.

### 1.2 예외적으로 언어가 고정된 두 곳

- **훅 본체 출력은 영문 고정.** `scripts/forge-hook-session-start.sh:22-24`가 이유를 명시한다 — 이 텍스트는 사용자가 아니라 **에이전트가 읽고**, 에이전트가 사용자 언어로 중계한다. 스킬 본문/사용자 출력 분리와 같은 논리.
- **`.claude/agents/*.md` role 카드 본문은 한국어.** 3장(`manifest-doc-syncer`·`script-twin-engineer`·`skill-author`) 모두 description·본문이 한국어다. 이건 위반이 아니라 범주 차이다 — role 카드는 플러그인이 배포하는 산문이 아니라 **이 프로젝트의 자산**(git 커밋 대상)이므로 배포 산문의 영문 규약 밖이다.

### 1.3 문서(docs/)의 언어

- `README.md`(영문) ↔ `README.ko.md`(한국어)는 번역 쌍.
- `docs/*.md` 5개(`forge-vs-loop-engineering`·`git-workflow`·`skills`·`state-contract`·`team-workflow`)는 **한국어 단일 언어**다. 이중언어 쌍이 아니다.
- `docs/index.html`은 한 파일 안에 KO/EN을 나란히 담는다(ADR-0027).
- `.forge/adr/*.md`·`.forge/retro/*.md`는 한국어(생성 문서 = 사용자 언어 규칙의 결과).

---

## 2. 스킬 산문 컨벤션

### 2.1 frontmatter

필드는 `name`과 `description` 둘뿐이다.

- **`name`이 스킬 식별자**이고 디렉터리명이 아니다 — 다만 실측으로 19/19가 디렉터리명과 일치한다(드리프트 없음).
- `name:` 누락은 자동 탐색 실패로 직결하므로 fg-doctor **B10이 error**로 잡는다(`scripts/forge-doctor.sh:116`).
- `description`은 "트리거 코어" — `/fg` 메뉴 가독성을 위해 **600 코드포인트** 상한을 fg-doctor **B16이 warning**으로 감시한다(`scripts/forge-doctor.sh:169`, `scripts/forge-doctor.js:172`, ADR `260716-22a`). 코드포인트 기준이라 한글 트리거 문구가 들어간 description도 바이트 수보다 여유가 있다(예: `skills/fg-doctor/SKILL.md`는 612 **바이트**지만 코드포인트로는 상한 이하라 clean).
- description에는 영문 + 한국어 트리거 발화가 함께 들어간다(예: `'forge doctor', '무결성 검사', '상태 점검', 'health check'`).

### 2.2 Mermaid 금지 — 텍스트 흐름도만

스킬 문서 안의 흐름·상태 전이·분기는 Mermaid가 아니라 텍스트 흐름도로 쓴다. 이유는 스킬이 렌더링 없이 파싱되는 실행 지시문이고 Mermaid 블록이 diff·grep을 방해한다는 것.

**검증: `grep -rn "mermaid" skills/` → 0건.** 위반 없음. 대신 `→` 화살표 흐름과 백틱 펜스 블록으로 흐름을 표현한다(예: `skills/fg-status/SKILL.md:95-97`의 우선순위 상태 머신).

이 규약은 **스킬 문서 한정**이다 — 사용자 프로젝트에 생성되는 산출 문서에는 적용되지 않고, 사용자 전역 지침(`~/.claude/CLAUDE.md`)은 오히려 복잡한 흐름에 Mermaid를 요구한다. 두 규칙은 대상이 달라 충돌하지 않는다.

### 2.3 핸드오프는 진술형 (statement-form)

각 스킬은 끝에서 "방금 한 것 / 다음 단계 / 시작하는 법"을 대화체로 전하되, **다음 단계 진입을 묻지 않는다.** 정본은 `skills/fg-run/SKILL.md:155`:

> Then **stop** — do not ask "shall I proceed?" and do not auto-invoke fg-learn/fg-done (chaining is `fg-next`'s job — ADR-0015).

배경은 ADR-0015(개정 2026-06-15): 과거 fg-run 종료의 4지 `AskUserQuestion` 메뉴가 영속 상태 + 멱등 가드 부재로 **선택해도 같은 메뉴가 다시 뜨는 반복 버그**를 냈고, 그래서 폐지됐다. 체이닝은 fg-next 전담이며 `skills/fg-next/SKILL.md:87`이 그 유일한 예외 조건(무인 주행 중 orchestrator가 caller일 때 위임 스킬의 stop을 삼킨다)을 규정한다.

**실측으로 스킬 본문에 남은 물음표 3건 — 셋 다 핸드오프 게이트가 아니다:**

| 위치 | 내용 | 판정 |
| --- | --- | --- |
| `skills/fg-run/SKILL.md:155` | 규칙 자체를 서술하는 문장 안의 인용 | 위반 아님 |
| `skills/fg-next/SKILL.md:50` | 진짜 fork(`verified: failed` → fg-run vs fg-ask) 선택 요구. 본문이 *"This is a needed choice, not a 'shall I proceed?' gate."*로 자기 구분 | 위반 아님 |
| `skills/fg-cleanup/SKILL.md:16` | 진입 시 오해 방지 문구 끝의 `Proceed?` | **핸드오프가 아니라 진입 disambiguation** — 핸드오프 규약 적용 대상 밖이지만, 스킬 본문에 문자 그대로 남은 유일한 확인 질문이다. 편집 시 인지할 것 |

또한 fg-run *시작* 시 백로그 2+ 작업 선택 메뉴는 별개로 유지된다(선택→실행으로 상태가 바뀌므로 반복 없음).

### 2.4 단일 정의 · 복붙 금지

형식 문서와 공유 규율 문서는 **소유 스킬의 디렉터리에 한 벌만** 두고, 다른 스킬은 참조한다. 실측 9개:

| 문서 | 소유 | 성격 |
| --- | --- | --- |
| `skills/fg-ask/ADR-FORMAT.md` | fg-ask | ADR 형식·ID 체계 |
| `skills/fg-ask/CONTEXT-FORMAT.md` | fg-ask | 글로서리 형식 |
| `skills/fg-learn/RETRO-FORMAT.md` | fg-learn | 회고 형식 |
| `skills/fg-run/PLAN-FORMAT.md` | fg-run | plan 형식 (생산자는 fg-ask지만 fg-ask 디렉터리가 verbatim 영역이라 소비자 쪽 소유) |
| `skills/fg-run/FORGE-ROOT.md` | fg-run | 브랜치별 forge 루트 해석 (ADR-0011) |
| `skills/fg-run/RUN-ALL.md` | fg-run | run-all 배치 규율 |
| `skills/fg-next/DRIVE.md` | fg-next | 무인 주행 규율 (ADR-0028) |
| `skills/fg-eco/ECO.md` | fg-eco | Eco laziness-first 규율 (ADR-0014) |
| `skills/fg-visual/VISUAL.md` | fg-visual | Visual Companion 사용법 |

참조 형식은 `${CLAUDE_PLUGIN_ROOT}/skills/<owner>/<FILE>.md`(같은 리포 안에서는 상대경로 `../fg-run/FORGE-ROOT.md`도 병기). 실측 27개 참조 조합이 있고 자체 복사본은 없다. 최다 참조는 `FORGE-ROOT.md`(17개 스킬). 루트 `references/` 디렉터리는 폐지됐고 실제로 존재하지 않는다.

`FORGE-ROOT.md:3` 자체가 규율을 선언한다: *"This rule is defined **once, here** ... Do not duplicate the logic — reference this file."*

### 2.5 절제

ADR은 세 조건(되돌리기 어렵다 / 맥락 없이 의아하다 / 진짜 트레이드오프)을 **모두** 충족할 때만 승급한다. ADR 본문 템플릿은 `맥락 → 결정 → 고려한 대안 → 결과` 4절 고정이며(`skills/fg-ask/ADR-FORMAT.md`), frontmatter에 `author`(생성 시점 `git config user.name`)와 `decided`(`YYYY-MM-DD HH:MM`, 분까지)를 담는다.

ADR ID는 세 형식이 공존한다 — 현재 `YYMMDD-HHMMSS`(같은-초 충돌 시에만 소문자 글자), grandfather된 `YYMMDD-HH`+글자, grandfather된 순차 `NNNN`. 실측 40개 ADR 중 32개가 `NNNN`, 8개가 시간기반이다(`.forge/adr/retired/`는 아직 생성되지 않았다 — lazy 생성). fg-doctor **B14**가 시간ID 중복(error)과 `NNNN` 구간 gap(warning)을 형식별로 분리해 검사한다(`scripts/forge-doctor.sh:132-151`) — `NNNN` 연속성은 `NNNN` 집합 안에서만 따지므로 시간기반 ADR이 거짓 gap을 만들지 않는다.

---

## 3. 이중언어 · 매니페스트 동기 규율

### 3.1 README 쌍

`README.md`(190줄) ↔ `README.ko.md`(189줄)은 같은 내용의 번역 쌍이고 한쪽을 고치면 반드시 다른 쪽도 같은 변경으로 고쳐야 한다. 서로를 첫 화면에서 링크한다(`README.md:8` → `[한국어]`, `README.ko.md:8` → `[English]`).

자동 검사는 **줄 수가 아니라 스킬-행 개수 parity**만 본다 — fg-doctor **B13**(warning, `scripts/forge-doctor.sh:126-130`). 즉 산문 문장이 한쪽만 갱신된 드리프트는 자동으로 잡히지 않는다. 수동 규율이다.

### 3.2 `docs/index.html`

한 파일 안에 KO/EN 텍스트를 `data-l="ko"` / `data-l="en"` span으로 나란히 담고 언어 토글로 전환한다(ADR-0027). **실측 `data-l="ko"` 77개 / `data-l="en"` 77개 — 정확히 일치.**

이건 **완전 수동 규율**이다. fg-doctor는 `docs/index.html`을 검사하지 않으므로, 한쪽 span만 고치면 아무도 잡아주지 않는다.

### 3.3 버전 3곳 동기

버전은 세 곳을 함께 갱신한다: `plugin.json`의 `version`, `marketplace.json`의 `metadata.version`, `marketplace.json`의 `plugins[0].version`. 실측 현재 세 곳 모두 `0.5.20`. fg-doctor **B8이 error**로 드리프트를 잡고(`scripts/forge-doctor.sh:105-108`), **B9**가 두 매니페스트의 JSON 유효성을 error로 검사한다(깨지면 설치 실패).

### 3.4 CLAUDE.md 스킬 목록

디스크에 있는 스킬이 `CLAUDE.md`의 스킬 목록에 없으면 fg-doctor **B12가 warning**을 낸다(`scripts/forge-doctor.sh:118-123`). 즉 스킬 추가 시 `CLAUDE.md` 갱신이 반강제다.

### 3.5 매니페스트 description의 역할 분리

`marketplace.json`의 `metadata.description`은 **루프(ask→execute→retro→done)를 정의하는 한 줄 태그라인**이라 루프 밖 유틸리티를 넣지 않는다. `plugins[].description`과 `plugin.json`의 `description`은 **전체 스킬 목록**을 담으므로 루프 밖 스킬도 반영한다. 실측 `plugin.json`의 description은 19개 스킬 + 훅까지 전부 열거하는 초장문 단일 문자열이다.

---

## 4. 셸 스크립트 컨벤션 (`scripts/`, `hooks/`)

### 4.1 포터빌리티 (ADR-0022)

- **shebang은 `#!/usr/bin/env bash`** — `/bin/bash` 금지(NixOS 등). 실측: `scripts/*.sh` 24개 전부 `#!/usr/bin/env bash`, `scripts/*.js` 8개 전부 `#!/usr/bin/env node`. 예외 0건.
- **호출은 `bash script.sh`** — `./script.sh` 금지(NTFS에 POSIX exec 비트가 없음). 단 훅 래퍼는 예외이며 오히려 exec 비트가 **필수**다(§4.6).
- **`.gitattributes`가 `*.sh`를 LF 강제.** 파일 상단 주석이 이유를 적는다 — CRLF의 `\r`이 shebang/인자에 들어가면 bash가 깨지고, Windows에서 `.sh`가 git-bash로 돌아가는 게 이중 디스패치의 전제라 이 가드가 load-bearing이다.

### 4.2 `set` 플래그 — 운영 스크립트는 `set -u`, 일부 테스트는 `set -euo pipefail`

**운영 스크립트 9개 전부 `set -u`만** 쓴다(`forge-doctor`·`forge-done`·`forge-merge`·`forge-status`·`forge-statusline`·`forge-statusline-full`·`forge-statusline-wrapper`·`forge-hook-session-start`·`resolve-forge-root`). `set -e`를 쓰지 않는 것은 의도적이다 — 이 스크립트들은 `grep`/`find`의 비-0 종료를 정상 흐름으로 쓰고, 자체 exit-code 계약(§4.5)으로 실패를 표현한다.

**테스트는 갈린다:**

| `set -euo pipefail` | `set -u` |
| --- | --- |
| `forge-hook-session-start.parity.test.sh`, `forge-status.parity.test.sh`, `forge-statusline.parity.test.sh`, `forge-statusline-full.parity.test.sh`, `resolve-forge-root.parity.test.sh` | 나머지 11개 (behavior 전부 + `forge-doctor`/`forge-done`/`forge-merge` parity) |

강화한 5개는 주석에 이유를 남겼다 — `scripts/forge-status.parity.test.sh:7-10`: *"a failed mktemp / fixture build now ABORTS instead of letting 'both produced empty output, so they're equal' pass as PARITY OK."* **`forge-doctor`/`forge-done`/`forge-merge`의 parity 테스트는 아직 `set -u`만이라 이 강화가 적용되지 않은 상태다** — 다만 이 셋은 파일 트리 diff / 출력 diff + rc 비교라 빈-출력 위양성 형태가 다르다.

### 4.3 필드 추출기 — `field:`와 `- field:` 둘 다 수용, CR 제거

STATUS/plan 필드 파싱은 **레거시 대시-리스트 형식(`- field:`)까지 수용**하고, **CRLF 체크아웃을 위해 `\r`을 벗긴다.** 실측 4개 스크립트가 동일 정규식을 쓴다:

```
sed -n "s/^[[:space:]]*-\{0,1\}[[:space:]]*$2:[[:space:]]*\([^ ]*\).*/\1/p" "$1" | head -1 | tr -d '\r'
```

- `scripts/forge-doctor.sh:32` `field()`
- `scripts/forge-status.sh:47`
- `scripts/forge-done.sh:72` `field()` / `:73` `fullfield()`
- `scripts/forge-hook-session-start.sh:58-63` `field()`

**첫 토큰만 vs 전체 값**이 두 변종으로 갈린다. `field()`는 `\([^ ]*\)`로 첫 토큰만 잡고, `fullfield()`(forge-done)와 hook의 `field()`는 콜론 뒤 **전체 값**을 잡는다. 후자의 이유는 `scripts/forge-hook-session-start.sh:54-56` 주석에 있다 — `failed (button dead)` 같은 사유가 바로 그 알림을 actionable하게 만드는 것이므로 첫 토큰만 잘라선 안 된다.

`.js` 트윈은 파일을 읽는 순간 `\r`을 전부 제거해 같은 결과를 낸다(`scripts/forge-hook-session-start.js:37`: `read(p) { ... .replace(/\r/g, '') }`). `tr -d '\r'` 사용 횟수: `forge-status.sh` 5회, `forge-doctor.sh`·`forge-hook-session-start.sh` 각 4회, `forge-done.sh` 3회, `forge-merge.sh` 2회.

### 4.4 `LC_ALL=C` — 바이트 순서 결정론

정렬·패딩이 로케일에 흔들리면 `.sh`↔`.js` 패리티가 깨지므로 바이트 기준으로 고정한다.

- `scripts/forge-hook-session-start.sh:38` — `export LC_ALL=C`(스크립트 전역). 주석(`:33-37`)이 근거를 적는다: node 트윈은 `Buffer.compare`로 바이트 정렬하는데, UTF-8 로케일에서는 **한글 slug가 다르게 정렬되어 패리티가 깨진다**. 안전한 이유도 명시 — 문자 단위 연산은 모두 ASCII(필드명·숫자)이고 값은 바이트째로 통과시킨다.
- `scripts/forge-status.sh:110` — `LC_ALL=C sort`(backlog 순서).
- `scripts/forge-status.sh:155` — `LC_ALL=C awk`(표 정렬). `awk`의 `length()`가 바이트를 세므로 node 트윈도 UTF-8 **바이트**로 패딩해야 한다(`scripts/forge-status.js:147-149` 주석).
- `scripts/forge-doctor.sh:173` — `LC_ALL=C tr -dc '\200-\277' | wc -c`로 UTF-8 continuation byte를 세어 **코드포인트 길이**를 로케일 독립적으로 구한다(B16 description 길이 검사).

### 4.5 exit-code가 스크립트↔스킬 인터페이스

스크립트는 **라우팅하지 않고**, 사유를 exit code로만 알린다. 판단·라우팅은 SKILL.md 산문의 몫이다(ADR-0031). 실측 계약:

| 스크립트 | exit code |
| --- | --- |
| `forge-done.sh/.js` | `0` 봉인 OK(half-sealed 완료도 멱등) · `2` 봉인할 것 없음 · `3` **검증 게이트** 미통과 · `4` **회고 게이트** 미통과 · `5` 중복(이미 `status: done`) · `64` 인자/형식 오류(unknown arg, 잘못된 `--sealed-id`, slug 경로 탈출) |
| `forge-merge.sh/.js` | `0` 통합 OK · `2` 통합할 것 없음 · `3` in-flight 브랜치 상태 · `4` 진짜 충돌(CONTEXT 용어 재정의, incoming `NNNN` 충돌) · `6` 모호(브랜치 루트 여럿 + 인자 없음) |
| `forge-doctor.sh/.js` | `0` clean · `1` warning만 · `2` error 1개 이상 (CI 게이트: strict면 비-0, errors-only면 `>=2`) |
| `forge-status.sh/.js` | 항상 `0` (읽기 전용 리포터) |
| `forge-statusline*.sh/.js` | 항상 `0` (statusline은 실패해선 안 됨) |
| `forge-hook-session-start.sh/.js` | **항상 `0`** (§4.6) |

`forge-doctor.sh:12-13` 주석이 CI 사용법까지 명시한다. `forge-merge.sh:33` 주석은 검출 불가 영역도 정직하게 적는다 — *"Semantic ADR contradictions are NOT script-detectable — left to PR review."*

### 4.6 훅 본체는 무조건 exit 0, 그리고 조용하다

`scripts/forge-hook-session-start.sh:20`: *"ALWAYS exits 0 — a hook must never fail a session start."* 실측 `.js` 트윈도 세 갈래 전부 `process.exit(0)`(`:25` 루트 없음 / `:111` 갚을 게 없음 / `:137` 정상 출력 후).

polyglot 래퍼 `hooks/run-hook.cmd`도 같은 규율이다 — 인자 없음·미지 훅 이름·런타임 없음 전부 **조용히 exit 0**. 주석(`:14-16`)이 트레이드오프를 적는다: 훅 알림이 없는 건 무해하지만(훅 도입 전 상태로 degrade) 실패하는 훅은 세션 시작을 깨뜨린다.

디스패치 순서는 **bash → node → 침묵**이다(`hooks/run-hook.cmd:82-88`, Windows 경로는 `:32-61`). 그리고 `CLAUDE_PROJECT_DIR`이 설정돼 있으면 그 디렉터리로 `cd`한다 — 훅 본체가 상태를 cwd에서 읽으므로 상속받은 cwd를 믿지 않는다(`:76-80`).

**exec 비트는 필수다.** Claude Code는 `bash <wrapper>`로 부르지 않고 커맨드 문자열을 `/bin/sh`에 넘겨 **파일을 직접 실행**하므로, `755`가 아니면 Permission denied로 훅이 조용히 발화하지 않는다(c1100b1 커밋 메시지에 UAT 실측으로 기록됨). 실측 현재 `hooks/run-hook.cmd`는 `-rwxr-xr-x`. `hooks/run-hook.test.sh:43`이 이 비트를 직접 단언한다.

`hooks/hooks.json`은 자동 탐색되므로 매니페스트에 등록하지 않는다. 계약 필드는 `SessionStart` 이벤트, 매처 `startup|resume|clear|compact`, 커맨드에 `${CLAUDE_PLUGIN_ROOT}` 사용, `"async": false` — 다섯 개 전부 `hooks/run-hook.test.sh:31-35`가 문자열로 단언한다(오타 하나로 훅이 조용히 죽는데 어디에도 에러가 안 나므로).

### 4.7 파괴적 스크립트는 게이트-우선 · 비파괴-거절 (ADR-0030)

파일을 옮기는 스크립트(`forge-done`·`forge-merge`)는 **모든 사전점검·게이트가 통과할 때까지 아무것도 건드리지 않고**, 막히면 사유 + 비-0 exit로 거절한다. 원문:

- `scripts/forge-done.sh:14-16` — *"GATE-FIRST, NON-DESTRUCTIVE-ON-REFUSE: it touches nothing until every pre-check and gate passes, then closes out STATUS in place and moves atomically."*
- `scripts/forge-merge.sh:25-26` — 동일 문구.

`forge-doctor`·`forge-status`는 반대편 극이다 — 읽기 전용을 계약으로 선언하고 아무것도 쓰지 않는다(`scripts/forge-doctor.sh:5-8`).

`forge-merge` 코어는 **git을 실행하지 않는다**(`:9-12`) — 그게 AI 없이 CI에서 돌 수 있게 하는 속성이다. `git merge`를 대신 돌리는 건 스킬 계층의 대화형 편의 모드뿐(ADR `260717-10a`).

### 4.8 결정론 주입 — 시간·랜덤을 인자/환경으로

테스트가 결정론이려면 시각이 주입 가능해야 한다.

- `forge-done.sh`는 `--completed <YYYY-MM-DD>`와 `--sealed-id <YYMMDD-HHMMSS>`를 인자로 받는다. 헤더 주석이 목적을 명시한다 — *"An arg so tests are deterministic."*
- statusline 트윈은 `FORGE_SL_NOW`(epoch 초)로 시각을 고정한다.
- 표시 계층 위임 환경변수: `FORGE_SL_SEP`(구분자)·`FORGE_SL_DENSITY`(compact/full)·`FORGE_SL_PREFIX`(접두). 실측 사용 횟수 `FORGE_SL_SEP` 13 / `FORGE_SL_DENSITY` 13 / `FORGE_SL_NOW` 10 / `FORGE_SL_PREFIX` 4. 이 위임 덕에 방법 2의 통합 스크립트가 단계 로직을 fragment에 맡기고 3중 복제를 피한다(ADR-0029).

### 4.9 bash 3.2 호환 (macOS 기본 bash)

`set -u`에서 **빈 배열 전개**(`"${arr[@]}"`)는 bash 3.2에서 unbound 오류를 낸다. `scripts/forge-hook-session-start.sh`가 유일하게 배열을 쓰는데, 전개를 개수 가드 안에 넣어 이를 회피한다:

```
n_items=${#items[@]}            # :127 — 빈 배열에도 안전
if [ "$n_items" -eq 0 ] && [ -z "$loop_line" ]; then exit 0; fi   # :128
...
if [ "$n_items" -gt 0 ]; then   # :140 — 가드
  for it in "${items[@]}"; do   # :143 — 가드 안에서만 전개
```

또 하나의 실전 gotcha가 회고에 남아 있다 — `.forge/retro/2026-07-16-forge-doctor-script-extract.md:11`: **`set -u`에서 멀티바이트 문자(`→`)에 인접한 `$var`는 변수명 경계가 모호해져 unbound 오류가 난다 → `${var}` 중괄호로 명시.** 스크립트 메시지에 유니코드 화살표를 쓸 때 걸린다. 같은 패턴의 방어적 브레이스가 여러 곳에 쓰인다(예: `scripts/forge-hook-session-start.sh:51` `disp="${root#${top}/}"`, `scripts/forge-statusline.sh:102` `root="${prefix}.forge"`).

### 4.10 자기 위치 기준 경로 해석

스크립트는 동반 파일을 `$CLAUDE_CONFIG_DIR` 같은 외부 환경변수가 아니라 **자기 위치**에서 찾는다 — bash는 `BASH_SOURCE`/`dirname "$0"`, node는 `__dirname`.

```
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"      # forge-hook-session-start.sh:42
root="$(bash "$SCRIPT_DIR/resolve-forge-root.sh" 2>/dev/null)"   # :43
```

`scripts/forge-statusline-wrapper.test.sh:5-9`가 이 계약을 명문화하며 테스트한다 — 세 파일을 가짜 config 디렉터리에 설치하고 **`CLAUDE_CONFIG_DIR`를 export하지 않은 채** 돌려서 해석이 그 환경변수에 의존하지 않음을 증명한다(ADR-0017).

브랜치별 루트 해석은 반드시 `resolve-forge-root.sh`/`.js`를 재사용한다(ADR-0011, ADR-0031 필수 조건 5). 실패 시 폴백은 `.forge`(`forge-hook-session-start.sh:44`).

### 4.11 트윈 규약 (ADR-0022) — 요약

- 운영 스크립트마다 `.sh`(bash, 1차) + `.js`(node, 폴백) 트윈. PowerShell 차단 환경 때문에 `.ps1`은 배제.
- `.js` 트윈 존재를 fg-doctor **B15가 정적 검사**(warning). 검사 제외 패턴: `*.test.sh`·`*.parity.test.sh`·`*-wrapper.sh`.
- 진짜 동치 가드는 **패리티 테스트**다(정적 검사보다 강력) — `TESTING.md` 참조.
- 트윈 없는 예외 하나: `scripts/forge-statusline-wrapper.sh`. 원본 statusline 보존 래퍼라 bash 전용이며 fg-doctor B15 제외 패턴에 명시적으로 들어 있다.

---

## 5. 오류 처리 패턴

이 리포에 예외 계층이나 로깅 프레임워크는 없다. 실측 패턴은 네 가지다.

1. **exit code로 사유를 알리고 라우팅은 호출자에게** — §4.5. 스크립트가 스스로 파괴적 재시도나 자동 라우팅을 하지 않는다(ADR-0020/0030이 명시적으로 기각한 설계).
2. **없는 입력에 대한 조용한 무동작.** 필드 추출기는 파일이 없으면 빈 문자열을 돌려준다(`[ -f "$1" ] || return 0`). 훅은 루트가 없으면 exit 0. statusline은 `[ -d "$root" ] || exit 0`(`scripts/forge-statusline.sh:107`). 즉 "상태 없음"은 에러가 아니라 정상 경로다.
3. **stderr + 비-0은 인자/형식 오류에만.** `forge-done`이 유일하게 stderr를 쓴다 — unknown arg / 잘못된 `--sealed-id` / slug 경로 탈출 3곳 모두 `exit 64`(`scripts/forge-done.sh:52,62,105`; `.js` 트윈 `:25,41,103` 동일).
4. **경고는 있어도 rewrite는 안 한다.** `forge-merge`는 merge로 바뀐 비-`.forge/` 파일의 ADR 교차참조를 grep해 **경고만** 하고 절대 고치지 않는다(`scripts/forge-merge.sh:22-23`).

보안 가드는 하나 명시적으로 존재한다 — slug 경로 탈출 방어. `scripts/forge-done.sh:105`가 `*/*`·`*\*`·`*..*`·`.*` 패턴을 거부해 `DEST`가 `done/` 내부임을 보장한다(커밋 `ab1d014`, 회고 `.forge/retro/260720-185950-forge-done-slug-guard.md`).

---

## 6. 편집 시 반드시 인지할 어긋남

- **`skills/fg-ask/`는 grill-with-docs 원본의 자기완결 3파일**(`SKILL.md` + 형제 `CONTEXT-FORMAT.md`/`ADR-FORMAT.md`)이고 SKILL.md 본문은 **영문 verbatim**이다. forge 루프 연결(백로그 산출·fg-run 핸드오프·회고 환류)은 맨 아래 "Forge integration (minimal)" 섹션에만 둔다. verbatim 본문과 이 섹션은 따로 움직이므로 **둘 중 하나만 고치면 계약이 깨진다.**
- **`skills/fg-cleanup/SKILL.md:16`의 `Proceed?`** — §2.3 표 참조.
- **`docs/index.html`의 KO/EN span 동기는 자동 검사가 전혀 없다** — §3.2.
- **`forge-doctor`/`forge-done`/`forge-merge` parity 테스트는 아직 `set -u`만**이고 나머지 5개는 `set -euo pipefail`로 강화됐다 — §4.2.
- **`.forge/codebase/` 문서 7개는 fg-doctor 검사 대상이 아니다** — 이 파일들이 지워진 상태에서도 `forge-doctor.sh`는 0 findings로 clean이었다. 지도의 신선도는 수동 관리다.
