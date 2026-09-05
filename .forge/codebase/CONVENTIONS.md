---
last_mapped_commit: 524c6a3ee40d28bcd90334a9e4f9ca0135fca088
mapped: 2026-09-03
---

# CONVENTIONS

이 문서는 **구현 사실만** 다룬다. 도메인 용어 정의는 `.forge/CONTEXT.md` 소관이다. 모든 경로·규칙은 이 커밋의 작업 트리에서 실제 파일로 검증했다.

## 0. 이 리포에서 "코드"란 무엇인가

**플러그인 본체에는 여전히 빌드·린트·테스트 시스템이 없다**(Makefile 없음). 산출물은 다섯 층이다:

1. **산문 스킬** — `skills/<name>/SKILL.md` 22개 + 동반 형식/규율 문서(`*-FORMAT.md`, `HANDOFF.md`, `DRIVE.md`, `FORGE-ROOT.md`, `ECO.md`, `RUN-ALL.md`, `VISUAL.md` 등). 신규 2개는 `skills/fg-help/`(스크립트 트윈 없는 LLM 실행 스킬, ADR `260814-104534`)와 `skills/fg-security/`(업스트림 vendoring, ADR `260820-215004`).
2. **결정론 스크립트 트윈** — `scripts/*.sh` + 동일 출력의 `.js`(ADR-0022). 이름이 전부 `forge-*`는 아니다 — 신규 `scripts/release-check.{sh,js}`가 접두 없는 첫 트윈이다(§2).
3. **매니페스트/훅** — `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, **`.codex-plugin/plugin.json`(신규, ADR `260903-080713`)**, `hooks/hooks.json`, `hooks/run-hook.cmd`. Codex 매니페스트의 `"skills": "./skills/"`가 Claude와 **같은 스킬 트리**를 로드한다(스킬 사본 없음).
4. **호스트 계약(신규, ADR `260903-080713`)** — `core/HOST.md`(57줄)·`core/EXECUTION.md`(9줄)·`core/INTERACTION.md`(6줄) + `hosts/claude/`·`hosts/codex/` 각 3파일(`capabilities.json`·`execution.md`·`interaction.md`). 산문이지만 **스킬이 아니다**(`skills/` 밖이라 자동 탐색되지 않는다) — 스킬이 참조하는 호스트-중립 계약 층이다(§7).
5. **문서 사이트 도구** — 루트 `package.json`(VitePress, `name: forge-docs`)·`package-lock.json`·`.github/workflows/docs.yml`. **대체로 문서 전용이지 플러그인 빌드가 아니다** — `docs/`의 Markdown을 `gyuha.com/forge/docs/`로 빌드·배포한다(ADR `260815-094725`). 단 **예외 하나가 생겼다**: `scripts` 첫 항목이 `"release:check": "node scripts/release-check.js"`로, 문서와 무관한 **플러그인 릴리스 게이트**가 이 `package.json`에 얹혀 있다(§5). 유일한 GitHub Actions 워크플로는 여전히 `docs.yml` 하나이며 **테스트 스위트도 release:check도 CI에서 돌지 않는다**(TESTING.md §8).

> **루트 `package.json`에 `"type"` 필드 금지**(실파일 확인 — 없음). `scripts/*.js` 트윈이 전부 CommonJS(`require`)라 `"type": "module"`이면 리포 전체 `.js`가 ESM으로 해석돼 트윈이 죽는다. VitePress 설정은 `.mts` 확장자만으로 이미 ESM이다(ADR `260815-094725`).

## 1. 스킬 문서 작성 규약 (`CLAUDE.md` "스킬 편집 규약" — 실파일 검증됨)

- **`**Explaining forge**` 상시 규율(신규, ADR `260824-134246`).** `**Language**` 규칙 바로 옆에 같은 문단이 **22개 `skills/*/SKILL.md` 전부**에 박혀 있다(실측: 22/22 verbatim 포함). canonical 본문의 **단일 정의는 `scripts/explaining-forge.rule.txt` 한 파일**이고, 각 SKILL.md에는 그 텍스트를 **그대로 복사**한다 — 이 리포에서 유일하게 *의도된 인라인 중복*이며, 드리프트 가드로 fg-doctor **B17**이 그 canonical 본문을 **containment(부분문자열)로 verbatim 대조**한다(마커만 대조하면 문단을 지우거나 뒤집은 파일이 통과한다). containment라서 예외 목록이 필요 없다 — `skills/fg-ask/SKILL.md`는 canonical + 문장 1개를 덧댄 **superset**이라 그대로 통과한다. 심각도는 **warning**(설치·릴리스를 깨지 않는 산문 드리프트 — B12/B13/B15/B16과 같은 등급), 범위는 **최상위 매니페스트 `name`이 `forge`일 때만**(사용자 프로젝트의 `skills/*/SKILL.md`에 forge 내부 규칙을 요구하지 않기 위한 스코프 가드, 중첩 `"name"`은 문서 순서 첫 항목만 읽어 회피).
- **본문은 영문, 출력은 사용자 언어.** `SKILL.md`·`*-FORMAT.md`는 영문으로 작성하고, 스킬이 화면에 내는 텍스트·산출 문서(plan/회고/ADR)는 사용자 언어를 따른다. "user's language" 지시가 실제로 박힌 파일: `skills/fg-run/SKILL.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-next/SKILL.md`, `skills/fg-next/HANDOFF.md`, `skills/fg-agenda/SKILL.md`, `skills/fg-config/SKILL.md`, `skills/fg-showme/SKILL.md`, `skills/fg-run/RUN-ALL.md` 등.
- **canonical 영문 이름 + 사용자 언어 렌더.** 핸드오프 표의 행 라벨(`Just did`·`Next step`·`How to start`·`Alternative`, 헤더 `Item`·`Detail`)은 영문이 canonical이고 화면 렌더만 번역한다 — 단일 정의는 `skills/fg-next/HANDOFF.md` 하나이며 다음 단계가 실재하는 **14곳**(루프 4 + fg-status·fg-next·fg-loop·fg-quick·fg-map·fg-doctor·fg-agenda·fg-adversarial-review·fg-agents·fg-security)이 참조만 하고 복붙하지 않는다. 나머지 7곳(fg-config·fg-statusline·fg-cleanup·fg-drop·fg-merge·fg-showme·fg-help)은 종전 산문 유지 — `skills/fg-help/SKILL.md`가 `HANDOFF.md`를 언급하는 것은 단일 정의 *선례*로서일 뿐 표를 쓰지 않는다.
- **단일 정의·복붙 금지(shared discipline docs).** `skills/fg-run/FORGE-ROOT.md`(forge 루트 해석, ADR-0011)·`skills/fg-next/DRIVE.md`(무인 주행 규율, ADR-0028)·`skills/fg-next/HANDOFF.md`(핸드오프 표)·`skills/fg-config/ECO.md`(eco 규율)가 그 예이고, **신규로 `core/HOST.md`·`core/EXECUTION.md`·`core/INTERACTION.md`가 같은 가족에 합류했다**(호스트-중립 계약 — §7). 다른 스킬은 `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/<소유 스킬>/<파일>` 또는 상대경로(`../fg-ask/ADR-FORMAT.md`)로 참조한다. 루트 `references/` 디렉터리는 폐지됐다(존재하지 않음 — 확인).
- **플러그인 루트 참조 형식(신규): `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}`** — Codex 우선·Claude fallback. 맨 `${CLAUDE_PLUGIN_ROOT}`를 대체했고, 실측 범위는 **소스 트리(`skills/`·`hooks/`·`core/`·`hosts/`)** 로 고정한다 — 그 안에 **맨 형식이 0건**이고 새 형식이 **24개 파일 64곳**에 있다(`hooks/hooks.json` 두 훅 command 포함). 리포 전체로 세지 말 것: `.forge/codebase/` 문서 자신과 `docs/.vitepress/dist/` 빌드 산출물이 잡혀 **자기참조적으로 부풀고**(지도를 다시 쓸 때마다 값이 바뀐다) 실제로 그렇게 틀린 수치가 한 번 적혔다. 규약 문서 쪽 단일 정의는 `core/HOST.md`의 `FORGE_PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"` 스니펫이고, 스킬 저작 에이전트 카드 `.claude/agents/skill-author.md`도 새 형식을 지시하도록 갱신됐다.
- **frontmatter `description`은 한 줄로 유지한다(신규 — 회귀에서 배운 규약).** 5개 스킬의 `description`이 내용 변경 0으로 YAML folded scalar(`>-`)로 바뀐 적이 있는데, fg-doctor **B16**의 리더가 `sed -n 's/^description:[[:space:]]*//p' | head -1`로 **줄 단위**라 값이 `>-`(2자)로 읽혀 600자 상한 린트가 **조용히 눈이 멀었다**. 전부 한 줄로 복원됐다(실측: `skills/*/SKILL.md`에 `^description: >-` **0건**). B16이 줄 단위 리더인 한 이 규약은 계약이다.
- **형식 문서는 소유 스킬 디렉터리에 한 벌만**: `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-learn/RETRO-FORMAT.md`.
- **흐름도는 Mermaid 금지, 영문 텍스트 흐름도**(`A → B → C`) — 스킬 문서 한정 규약. 사용자 프로젝트 산출 문서에는 비적용.
- **frontmatter `name`이 스킬 식별자**(디렉터리명 아님). 각 `description`에 영문+한글 트리거를 모두 등록(예: `skills/fg-ask/SKILL.md` frontmatter — `"start a new task"`, `'새 작업 시작'` 병기; ADR `260716-22a`). 스킬 본문에 한쪽 언어 트리거를 하드코딩하지 않고, verbatim 유지 대상은 경로·`.forge/` 필드·`/명령`뿐이다.
- **핸드오프는 진술형** — "진행할까요?"로 묻지 않는다. 체이닝은 fg-next 전담(ADR-0015, ADR `260805-231104`).
- **verbatim 영역**: `skills/fg-ask/SKILL.md` 본문은 grill-with-docs 원문 영문 verbatim이고, forge 연결은 맨 아래 "Forge integration (minimal)" 섹션에만 둔다(`CLAUDE.md` "알려진 불일치" 절).
- **vendoring 규약(신규)**: 외부 방법론은 **byte-for-byte 유지**하고 forge 글루만 자기 파일에 둔다. `skills/fg-security/`가 [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill)을 MIT로 vendoring한 실례 — `AUDIT.md`+공격유형 플레이북 9종+`report-schema.json`·`validate-findings.cjs`·`LICENSE`는 편집 금지(원형 유지 → 업스트림 diff가 싸다)이고, 진입 파일만 개명했다(forge 스킬 자동 탐색 충돌·중첩 오탐 회피). `SKILL.md`는 `AUDIT.md`를 **파일 참조로만** 쓰고 재진술하지 않는다(`../fg-config/ECO.md`·`../fg-showme/VISUAL.md`와 같은 관례).

## 2. 스크립트 규약 (ADR-0022, `.forge/adr/0022-*.md`)

- **sh/js 트윈**: 운영 스크립트마다 `.sh`(bash, 1차) + `.js`(node, 폴백) 쌍 — `scripts/`에 **11쌍** 존재(forge-doctor·forge-done·forge-hook-session-start·forge-hook-stop·forge-loop-spend·forge-merge·forge-status·forge-statusline·forge-statusline-full·**release-check**·resolve-forge-root; `forge-statusline-wrapper.sh`만 bash 전용 예외로, fg-doctor B15 검사도 `*-wrapper.sh`를 제외). B15는 `scripts/*.sh`·`scripts/*.js` 전체를 훑으므로 `forge-` 접두가 없는 `release-check`도 트윈 검사 대상이다.
- **"트윈"은 두 개의 실제 구현을 뜻한다 — shim은 트윈이 아니다(신규 규약, 실사례).** `scripts/release-check.sh`는 처음 `exec node …`로 js를 호출하는 shim이었는데, 그러면 ADR-0022의 존재 이유(**node 없는 bash-only 환경**)가 정확히 무력화된다 — 파일은 두 개지만 런타임 의존은 하나다. 현재는 37줄의 실제 bash 구현이고(`grep -oE '"version"…' | sed`로 문서 순서대로 버전을 뽑는 — fg-doctor B8과 **같은 리더**), `scripts/release-check.parity.test.sh`가 sh↔js 동치를 강제한다(TESTING.md §2·§3).
- **`.js` 트윈은 CommonJS**(`require`) — 루트 `package.json`의 `"type"` 금지가 여기서 나온다(§0). 예외적으로 vendoring된 `skills/fg-security/validate-findings.cjs`는 확장자 `.cjs`로 모듈 종류를 자기가 못 박는다(zero-dependency, exit 0/1).
- **포터블 규칙**: shebang은 `#!/usr/bin/env bash`(`/bin/bash` 금지), 호출은 `bash script.sh`(`./script.sh` 금지 — NTFS exec 비트 없음), `.gitattributes`가 `*.sh text eol=lf`로 LF 강제(루트 `.gitattributes` 확인).
- **판단은 스크립트로 옮기지 않는다** — 결정론적 survey/상태 전이만 스크립트화, LLM 판단(그릴링·회고 분류·divergence 평가)은 산문에 남김(ADR-0020/0031 분할).
- **훅 디스패치**: `hooks/run-hook.cmd`는 bash→node 순 polyglot 래퍼, 런타임 없으면 exit 0 침묵(superpowers 패턴 MIT 차용). `hooks/hooks.json`에 훅이 **둘**이다 — `SessionStart`(매처 `startup|resume|clear|compact`, 본체 `scripts/forge-hook-session-start.sh`/`.js`)와 `Stop`(매처 없음, 본체 `scripts/forge-hook-stop.sh`/`.js`). 둘 다 `"shell": "bash"` · `"async": false`, command는 이제 `"${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/hooks/run-hook.cmd" <이름>`(§1의 새 참조 형식 — `hooks/run-hook.test.sh`가 이 문자열을 단언한다).
- **Stop 훅의 안전 규약(신규)**: 모든 실패·모호 경로는 **정지 허용(exit 0, 침묵)**이고, 정지를 막는 `exit 2`는 marker 존재 + 양쪽 상한(30분·50회) 이내 + 세션 일치인 좁은 한 경우뿐이다. 하네스 쪽 루프 보호가 없으므로 이 상한이 유일한 폭주 가드다(`scripts/forge-hook-stop.test.sh` 헤더 주석).

## 3. 네이밍·ID 규약

- **스킬**: `fg-<verb|noun>` 디렉터리 + frontmatter `name` 동일.
- **호스트 계약 파일(신규)**: `core/`는 **대문자**(`HOST.md`·`EXECUTION.md`·`INTERACTION.md` — 공유 규율 문서 관례), `hosts/<host>/`는 **소문자**(`execution.md`·`interaction.md`·`capabilities.json`). 호스트 디렉터리명은 `claude`·`codex`로, 매니페스트 디렉터리(`.claude-plugin/`·`.codex-plugin/`)와 같은 어휘를 쓴다.
- **ADR ID** (`skills/fg-ask/ADR-FORMAT.md` L5–43, `.forge/adr/` 51개 파일로 검증):
  - 현행 — `YYMMDD-HHMMSS`(벽시계, 같은-초 충돌 시에만 소문자 글자 접미), 예 `260805-231104-handoff-table.md`.
  - grandfather 1 — `YYMMDD-HH`+항상 글자(예 `260716-14a-*.md`), 동결.
  - grandfather 2 — 순차 `NNNN`(`0001`–`0032` 존재), 동결. 재번호·재사용 금지, 은퇴는 `.forge/adr/retired/`로 이동만(fg-cleanup).
- **상태 파일 slug**: plan 첫 줄 `<!-- forge-slug: ... -->` 주석이 짝 맞춤 식별자, `<!-- task: N -->`은 단조 증가(ADR-0005). done 아카이브는 `.forge/done/<YYYY-MM-DD-slug>/`.
- **테스트 파일**: `<script>.test.sh`(behavior) / `<script>.parity.test.sh`(sh↔js 동치) — TESTING.md 참조.

## 4. 이중 언어 동기화

- `README.md`(영문) ↔ `README.ko.md`(한글)는 번역 쌍 — 한쪽 갱신 시 반드시 다른 쪽도(fg-doctor B13이 스킬 행 패리티를 warning으로 검사).
- **`docs/<name>.md`(한글, root locale) ↔ `docs/en/<name>.md`(영문)는 8쌍의 번역 쌍**(agenda·**codex**(신규)·forge-vs-loop-engineering·git-workflow·index·skills·state-contract·team-workflow — 실측: 쌍 누락 0건). README 1쌍까지 합쳐 9쌍이므로 **번역문은 절 구조를 1:1로 유지**한다(`##` 헤딩 개수·순서, 표의 행·열 수 일치 → diff로 동기 확인 가능). 쌍 누락 확인은 `for f in docs/*.md; do [ -f "docs/en/$(basename "$f")" ] || echo "missing: ..."; done`. 영문판 링크는 영문판끼리 닫히되 예외 둘 — `README.ko.md` 절대 URL은 `README.md`로, `./examples/…`는 `../examples/…`로.
- `docs/index.html`은 한 파일에 `data-l="ko"`/`data-l="en"` span 병기(ADR-0027) — 한쪽 span 수정 시 짝 span도 함께.
- 버전은 **4곳 동기**(3곳 → 4곳으로 확장): `.claude-plugin/plugin.json` `version`, `.claude-plugin/marketplace.json` `metadata.version`·`plugins[0].version`, **`.codex-plugin/plugin.json` `version`**. fg-doctor **B8**이 4-way로 error 검사하고, 배포 절차에 `npm run release:check`가 추가됐다(§5). 실측 현재값 `0.8.0` 4곳 일치.
- `CLAUDE.md` 스킬 목록 완전성은 fg-doctor B12(warning).

## 5. 에러 처리·안전 패턴 (스킬 계층)

- **게이트-우선-비파괴**: fg-done 봉인 스크립트(`scripts/forge-done.sh`/`.js`)는 검증 게이트(ADR-0009 — `verified:` 봉인가능 값) → 회고 게이트 순으로 확인하고 실패 시 아무것도 옮기지 않으며 exit code로 스킬이 라우팅(ADR-0030).
- **읽기 전용 계열**: fg-status·fg-doctor는 아무것도 쓰지 않는다. fg-doctor exit 0/1/2(clean/warning/error)로 CI 게이트 겸용.
- **불가역 액션 앞 확인 게이트**: fg-drop 하드 삭제 전 경고, fg-loop safety 벽(비가역 액션 클래스 정지).
- 매니페스트 편집 후 JSON 유효성 확인은 `CLAUDE.md`의 node 한 줄이 canonical(이제 `.codex-plugin/plugin.json`까지 **3개 매니페스트**를 파싱한다).
- **릴리스 게이트(신규)**: `npm run release:check`(= `scripts/release-check.{sh,js}`)가 배포 전 네 가지를 error로 잡는다 — ① 매니페스트 버전 4곳 동기, ② Codex 매니페스트의 `skills`가 `"./skills/"`인지(공유 스킬 트리 이탈 방지), ③ `hooks/hooks.json` 존재, ④ `hosts/{claude,codex}/{interaction.md,execution.md,capabilities.json}` 6파일 완비. 계약은 **exit 0 = ok / 1 = 위반 1건 이상**이고 위반은 stderr에 한 줄씩·**여러 위반은 고정 순서**로 나온다(파일 부재 매니페스트만 즉시 exit 1로 단축). fg-doctor와 달리 warning 등급이 없다.

## 6. git 규약

- `.gitignore`: `.forge/*` 기본 제외 + 화이트리스트(`!.forge/CONTEXT.md`·`!.forge/adr/`·`!.forge/retro/`·`!.forge/codebase/`·`!.forge/config.json`·`!.forge/branch/`). 비-기본 브랜치 forge 루트는 통째로 추적, `dropped/`·`visual/`은 휘발. 문서 사이트 항목이 추가됐다 — `node_modules/`·`docs/.vitepress/dist/`·`docs/.vitepress/cache/`는 제외하되 **문서 소스 `docs/*.md`는 추적**(ADR `260815-094725`).
- 릴리스 커밋은 `chore(release): vX.Y.Z`, 기능은 `feat`/`fix` — `git log` 실측(`d373e22 chore(release): v0.7.1`, `fe15785 feat(drive): ...`). 이슈 연동 봉인 시 `(Fixes #N)` 포함.

## 7. 호스트-중립 규약 (신규, ADR `260903-080713`)

forge가 Claude Code 전용에서 **Claude Code + Codex** 두 호스트로 넓어지면서 생긴 규약 층이다(은퇴한 ADR-0025 "Claude Code only, defer Codex port"의 반대 결정 — `.forge/adr/retired/0025-*.md`). 핵심 원칙: **워크플로 의미와 `.forge/` 상태 의미는 공유 `skills/`·`scripts/`가 소유하고, 호스트 어댑터는 "어떻게 묻고·위임하고·에이전트를 로드하고·주행을 잇고·상태를 표시하는지"만 서술한다.** 스킬을 Codex용으로 두 벌 만들지 않는다(`core/HOST.md` 명문 금지 — "must not fork the state model or maintain a second Codex-specific copy of a skill").

- **어댑터 선택 순서**(`core/HOST.md`): ① 명시적 호스트 메타데이터 → ② `PLUGIN_ROOT` = Codex → ③ Codex 메타데이터 없는 `CLAUDE_PLUGIN_ROOT` = Claude Code → ④ **식별 불가 시 순차 폴백**(평문 질문·역할 위임 없음·호스트 UI 미변경). 두 환경변수 모두 *증거일 뿐 증명이 아님*을 계약이 스스로 명시한다(Codex도 호환성으로 `CLAUDE_PLUGIN_ROOT`를 줄 수 있고, `PLUGIN_ROOT`는 남이 export할 수 있는 흔한 이름). **모호할 때 추측하지 않고 폴백을 택하는 것**이 규약이고, 폴백 경로는 전부 정의되어 있어 안전하다.
- **capability 어휘는 단일 정의**: `core/HOST.md`의 표 8개 키(`structured_choice`·`spawn_parallel`·`spawn_role`·`plugin_root`·`session_start`·`prevent_stop`·`project_agents`·`status_display`)가 **유일한 어휘**이고 `hosts/<host>/capabilities.json`은 정확히 그 8개 키만 담는다(실측: 양쪽 파일 8/8, 여분 키 0) → 스킬이 capability 이름을 적어 기계적으로 조회할 수 있다.
- **`true`는 관측, `false`는 기본값**: capability는 **그 호스트가 제공한다고 *관측된* 때만 `true`**다. 미확인은 `false`로 두는데, 모든 capability에 정의된 폴백(순차 실행·번호 텍스트 목록·명시적 정지)이 있고 **도는 폴백이 없는 도구 호출보다 항상 싸기** 때문이다. 실측 현재값 — `hosts/claude/capabilities.json`은 8개 전부 `true`, `hosts/codex/capabilities.json`은 `spawn_parallel`·`plugin_root`·`session_start` 셋만 `true`. **`false`→`true` 뒤집기는 관측이지 가정이 아니며, 같은 변경에서 `docs/codex.md`의 "현재 지원 범위" 표를 함께 갱신해야 한다**(같은 주장의 두 표현 — 그 표는 지원/제한적/미확인/미지원 4등급으로 서술하며 `structured_choice`가 "미확인 → 번호 텍스트 목록 fallback"에 해당).
- **기둥 1의 근거가 호스트-중립으로 복원됐다**: "그릴링은 실행 워크플로우 안에 넣지 않는다"에 이유가 다시 붙었다 — **위임 실행은 실행 중 사용자 입력을 못 받는다**. Claude Code Dynamic Workflow와 Codex collaboration/subagent를 나란히 들어 호스트가 늘어도 근거가 사라지지 않음을 명시하며, `CLAUDE.md` L114·`README.md` L194·`README.ko.md` L193·`docs/index.md` L53·`docs/en/index.md` L53 **다섯 곳이 같은 문장 구조**로 동기화되어 있다(이중언어 쌍 규약이 여기에도 적용된다).
- **위임 실행 계약**(`core/EXECUTION.md`, 9줄): 공유 스킬이 선택·승격·의존성 분류·결과 수집·UAT·`.forge/run.md`를 소유하고 어댑터는 **위임만** 소유한다. 의존 슬라이스는 직렬, 독립·한정 슬라이스는 병렬 가능, 통합과 상태 쓰기는 primary agent 책임, **위임 불가 시 의미를 바꾸지 않고 직렬 실행**.
- **대화 계약**(`core/INTERACTION.md`, 6줄): 한 번에 한 질문, 호스트의 structured-choice 도구가 있고 선택지 수가 맞으면 그것을, 아니면 번호 목록 + 안정 식별자 하나. **확인 게이트와 기본값은 호스트 간 동일**하다.
