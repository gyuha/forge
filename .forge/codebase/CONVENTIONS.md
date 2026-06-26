---
last_mapped_commit: 2059a08bee17a9fbb97e6e938958f5ed813bdb2d
mapped: 2026-06-26
---

# CONVENTIONS

forge는 코드를 빌드하는 프로젝트가 아니라 **Claude Code 플러그인**이다. 산출물은 거의 전부 Markdown(`SKILL.md`, `*-FORMAT.md`)과 JSON(매니페스트)이며, 유일한 실행 코드는 `scripts/` 아래 bash/node 스크립트(statusline fragment·wrapper, `forge-status.sh/.js`, `resolve-forge-root.sh/.js`)뿐이다. 따라서 여기서 말하는 "컨벤션"은 전통적 코드 스타일이 아니라 `/Users/gyuha/workspace/forge/CLAUDE.md`에 명문화된 **저술(authoring) 규약**이다.

## Language: skill body English, output in user's language

스킬 본문(`skills/<name>/SKILL.md`)과 형식 문서(`*-FORMAT.md`)는 **영문으로 작성**한다(`CLAUDE.md` "스킬 편집 규약 > 언어"). grill-with-docs 원문을 그대로 옮긴 부분은 영문 verbatim을 유지한다.

반대로 스킬이 **사용자에게 출력하는 언어는 사용자 언어를 따른다**. 각 스킬은 "respond in the user's language" 지시를 본문에 명시해야 하고, 사용자 프로젝트에 남는 산출 문서(plan, 회고, `CONTEXT.md`, ADR 등)도 사용자 언어로 쓴다. 실제 예: `skills/fg-doctor/SKILL.md`는 영문 본문에 "you MUST write every message shown to the user ... in the user's language" 지시를 박아 두고, 섹션·severity 라벨만 canonical 영문으로 두되 렌더링은 사용자 언어로 한다.

요약: 작성 언어(English) ≠ 출력 언어(user's). 둘을 혼동하지 말 것.

## Handoff style (statement-form, no "shall I proceed?", chaining = fg-next)

각 스킬은 끝에서 "방금 한 것 / 다음 단계 / 시작하는 법"을 **자연스러운 대화체**로 전한다 — 정해진 양식을 사무적으로 출력하지 않는다(`CLAUDE.md` "스킬 편집 규약 > 핸드오프").

- **전환은 진술형**이다. "진행할까요?"로 다음 단계 진입을 *묻지 않고*, 다음 스킬·트리거를 알린 뒤 멈춘다.
- 체이닝(동의 시 다음 스킬 자동 호출)은 **fg-next 전담**이다. 개별 스킬은 체이닝하지 않는다.
- **전 루프 핸드오프가 진술형이다.** fg-run 단일작업 종료도 진술형으로 다음 단계(기본=회고 fg-learn)·트리거를 알리고 멈춘다 — 저-divergence면 skip+봉인 안내, 고-divergence면 재그릴 권고. 과거 fg-run 종료의 `AskUserQuestion` 메뉴는 "선택해도 같은 메뉴가 다시 뜨는 반복 버그"로 **폐지**됐다(ADR-0015 개정 2026-06-15). 단 fg-run *시작* 시 백로그 2+ 작업 선택 메뉴는 별개로 유지된다(선택→실행으로 진행, 반복 없음).
- Run-all 배치 핸드오프도 진술형이다. "어느 것부터?"는 fg-learn 소유 질문이라 중복 금지.
- 핸드오프에 "진행할까요?"를 재추가하지 말 것.

근거 ADR: `.forge/adr/0015-fg-run-handoff-menu-others-stated.md`(개정 2026-06-15).

## Flow diagrams: TEXT, not Mermaid (in skill docs)

스킬 문서(`SKILL.md`)에 흐름·상태 전이·분기를 넣을 때는 **Mermaid를 쓰지 말고 텍스트 흐름도로 작성한다**(`CLAUDE.md` "스킬 편집 규약 > 흐름도는 텍스트로"). `A → B → C` 형태, 분기는 들여쓰기·화살표·조건 레이블로. 스킬 본문이 영문이므로 텍스트 흐름도도 영문으로 쓴다.

이유: 스킬은 에이전트가 읽고 실행하는 지시문이라 렌더링 없이 그대로 파싱되어야 하고, Mermaid 블록은 진단·diff·grep을 어렵게 한다.

주의: 이 규약은 **스킬 문서 한정**이다. 사용자 프로젝트에 생성되는 산출 문서에는 적용되지 않는다. `scripts/` 상단 주석의 출력 흐름도(precedence order 등)도 이 텍스트 규약을 따른다.

## README bilingual sync

`/Users/gyuha/workspace/forge/README.md`(영문)와 `/Users/gyuha/workspace/forge/README.ko.md`(한글)는 같은 내용의 번역 쌍이다. **한쪽을 갱신하면 반드시 다른 쪽도 같은 변경으로 함께 갱신한다**(양방향). 한쪽만 고치면 두 문서가 어긋난다(`CLAUDE.md` "스킬 편집 규약 > README 이중 언어 동기화"). fg-doctor의 B12 체크가 두 파일의 스킬 행·목록 항목이 어긋나면 warning으로 잡는다.

## Restraint discipline (promote only past the bar)

영속 문서로의 승급은 바를 넘을 때만 한다(`CLAUDE.md` "스킬 편집 규약 > 절제", "설계 원칙").

- **ADR**(`.forge/adr/NNNN-slug.md`)은 세 조건을 **모두** 충족할 때만 작성한다: 되돌리기 어렵다 / 맥락 없이 의아하다 / 진짜 트레이드오프가 있다.
- **글로서리 용어**(`.forge/CONTEXT.md`)는 바를 넘는 용어만 등재하고, 용어만 담되 구현 세부는 금지한다(구현 세부는 이 codebase 문서들의 몫).
- 회고에서 나온 모든 학습을 영속 문서로 밀어 넣지 않는다. 바를 못 넘는 학습의 종착지는 `.forge/retro/`다.

## Manifest: two descriptions, different roles

매니페스트는 두 곳이며 각 description의 역할이 다르다(`CLAUDE.md` "배포 규칙" 말미).

- `.claude-plugin/marketplace.json`의 `metadata.description` — 루프(ask→execute→retro→done)를 정의하는 한 줄 태그라인. **루프 밖 유틸리티(fg-map류)는 넣지 않는다.**
- `.claude-plugin/plugin.json`의 `description`과 `marketplace.json`의 `plugins[].description` — 전체 스킬 목록을 담는 설명이므로 **루프 밖 스킬도 반영한다.**

루프 밖 스킬을 metadata에 끼우면 루프 정의가 흐려진다. 스킬 개수·설명을 바꿀 땐 `plugin.json`과 `marketplace.json`을 함께 갱신해야 한다(둘 다 사람이 읽는 설명을 담는다). 버전은 **3곳을 반드시 동기 갱신**한다: `.claude-plugin/plugin.json`의 `version`, `.claude-plugin/marketplace.json`의 `metadata.version`, `.claude-plugin/marketplace.json`의 `plugins[0].version`. 매니페스트 description의 개수 단어(예: "Seventeen … Thirteen more")가 `skills/*/SKILL.md` 실제 개수와 어긋나면 fg-doctor B10이 warning으로 잡는다.

## Lazy file creation

영속 문서(`.forge/CONTEXT.md`, `.forge/adr/`, `.forge/retro/`, `.forge/codebase/`, `.forge/config.json`)는 전부 **lazy 생성**이다 — 쓸 내용이 생길 때만 만든다(`CLAUDE.md` "영속 문서 모델"). `CHANGELOG.md`도 없으면 헤더와 함께 새로 만드는 lazy 생성이다(배포 규칙 1). `.forge/config.json`도 첫 쓰기(`fg-tdd`/`fg-eco`) 때 lazy 생성된다.

## Format docs live with the owning skill (single owner, referenced not copied)

형식 정의는 한 벌만 존재하며 소유 스킬 디렉터리에 둔다:
- `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md` — grill-with-docs 원본. fg-ask 디렉터리가 verbatim 영역이라 SKILL.md 본문과 "Forge integration (minimal)" 섹션이 따로 움직인다(알려진 불일치).
- `skills/fg-run/PLAN-FORMAT.md` — plan.md 형식 + 분할 규칙. 생산자는 fg-ask지만 소비자(fg-run) 쪽에 둔다.
- `skills/fg-run/FORGE-ROOT.md` — 브랜치별 forge-root 단일 정의. 모든 루프 스킬이 참조하고 복붙 금지.
- `skills/fg-learn/RETRO-FORMAT.md` — 회고 형식.

다른 스킬(fg-done 포함)은 자체 복사하지 않고 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(상대경로 `../fg-ask/` 등)로 참조한다. 루트 `references/` 디렉터리는 폐지됐다.

## Scripts convention: dual-dispatch .sh + .js (ADR-0022)

`scripts/` 아래 각 운영 스크립트는 `.sh`(bash, 1차) + `.js`(node, 폴백) 트윈으로 제공한다. PowerShell 차단 환경을 위해 `.ps1` 대신 node를 폴백으로 쓴다(node는 Claude Code가 항상 보장).

현재 트윈 쌍:
- `scripts/forge-status.sh` + `scripts/forge-status.js` — fg-status용 결정론적 survey + 6열 task 테이블(ADR-0020)
- `scripts/forge-statusline.sh` + `scripts/forge-statusline.js` — statusline 한 줄 fragment
- `scripts/forge-statusline-wrapper.sh` — bash 전용 wrapper(no-bash 호스트에서는 단독 연결만 지원)
- `scripts/resolve-forge-root.sh` + `scripts/resolve-forge-root.js` — 브랜치별 forge-root 경로 해석(ADR-0011)

포터블 규칙: shebang `#!/usr/bin/env bash`(`/bin/bash` 금지 — NixOS 등), `bash script.sh`로 호출(`./script.sh` 금지 — NTFS는 POSIX exec 비트가 없음), `.gitattributes`로 `*.sh`를 LF 강제(CRLF가 bash를 깨뜨림).

판단은 스크립트로 옮기지 않는다 — grilling·retro 분류·divergence 평가 같은 LLM 판단은 산문에 남기고, 결정론적 survey/상태 전이만 스크립트화한다(ADR-0020의 "survey=스크립트, next-step=산문" 분할).

## Deploy procedure (trigger: "배포")

흐름: `CHANGELOG.md 작성 → README(이중언어)·docs 갱신 → 버전 3곳 범프 → JSON 검증 → commit → push(main)`

1. **CHANGELOG.md 갱신** — 마지막 배포 이후 커밋을 요약해 새 버전 섹션을 맨 위에 추가(Keep a Changelog 약식). 파일이 없으면 lazy 생성.
2. **README·docs 갱신** — 릴리스 내용에 맞춰 `README.md`+`README.ko.md`(이중언어 동기) 및 관련 `docs/` 문서를 갱신. 변경이 사용자 문서에 영향 없으면 생략.
3. **버전 범프** — 기본 patch. 버전은 3곳 동기 갱신(위 참조).
4. **JSON 검증** — 매니페스트 유효성 node 한 줄(`TESTING.md` 참조).
5. **commit & push** — `chore(release): vX.Y.Z` 형식, `main`에 push. 설치는 main을 당기므로 push까지가 배포다.

가드:
- 배포와 무관한 변경이 섞여 있으면 멈추고 확인받는다.
- 마지막 배포 이후 커밋이 없으면 배포할 것이 없다고 알리고 멈춘다.
- 미커밋 변경이 곧 릴리스 내용이면 먼저 `feat` 커밋으로 묶은 뒤 릴리스 절차를 돈다(릴리스 커밋엔 CHANGELOG+버전 범프만).

## Known inconsistency (편집 전 인지)

`skills/fg-ask/`는 grill-with-docs 원본의 자기완결 3파일(`SKILL.md` + 형제 `CONTEXT-FORMAT.md`/`ADR-FORMAT.md`, 영문)이며, SKILL.md 본문은 영문 verbatim이고 forge 루프 연결(백로그 산출, fg-run 핸드오프, 회고 환류)은 맨 아래 "Forge integration (minimal)" 섹션에만 둔다. verbatim 본문과 Forge integration 섹션은 따로 움직이므로, 둘 중 하나만 고치면 계약이 깨진다(`CLAUDE.md` "현재 상태의 알려진 불일치").
