---
last_mapped_commit: d3c47b5bdc859af54e741f0524f9ed8ce2b61483
mapped: 2026-06-14
---

# CONVENTIONS

forge는 코드를 빌드하는 프로젝트가 아니라 **Claude Code 플러그인**이다. 산출물은 거의 전부 Markdown(`skills/*/SKILL.md`, `*-FORMAT.md`)과 JSON(매니페스트)이며, 최근 처음으로 bash 스크립트(`scripts/`)가 추가됐다. 따라서 이 문서의 "코드 컨벤션"은 대부분 **문서 작성 규약**이고, 스크립트 규약은 마지막에 별도로 둔다. 컨벤션의 단일 정의 출처는 루트 `CLAUDE.md`이며, 이 문서는 그 규약을 구현 사실 중심으로 정리한 지도다.

> 주의(이 문서의 범위): 여기 적힌 규약은 **스킬 문서·플러그인 산출물**에 적용되는 것이고, 사용자 프로젝트에 생성되는 산출 문서(plan·회고·CONTEXT·ADR 등)에는 별도로 명시한 예외가 붙는다(언어·흐름도). 도메인 용어의 정의는 이 문서가 아니라 `CONTEXT.md`의 몫이므로 여기서는 다루지 않는다.

## 1. 언어 — 본문은 영어, 출력은 사용자 언어

스킬 본문(`SKILL.md`)과 형식 문서(`*-FORMAT.md`)는 **영문으로 작성**한다. `skills/fg-ask/`처럼 grill-with-docs 원문을 그대로 옮긴 verbatim 영역은 영문을 손대지 않고 유지한다.

반면 스킬이 **사용자에게 출력하는 언어는 사용자의 언어를 따른다.** 각 스킬에는 "respond in the user's language" 지시를 명시하고, 산출 문서(plan·회고·CONTEXT·ADR 등 사용자 프로젝트에 남는 문서)도 사용자 언어로 쓴다.

요약하면 분리선은 "에이전트가 읽는 지시문(영문) vs 사람에게 가는 산출물(사용자 언어)"이다.

```
지시문(SKILL.md, *-FORMAT.md)          → 영문 고정
사용자 대면 출력 / 산출 문서(plan, retro, CONTEXT, ADR) → 사용자 언어
```

## 2. 흐름도 — 스킬 문서는 텍스트, Mermaid 금지

스킬 문서(`SKILL.md`)에 흐름·상태 전이·분기를 넣을 때는 **Mermaid를 쓰지 않고 텍스트 흐름도로 작성**한다(`A → B → C`, 분기는 들여쓰기·화살표·조건 레이블). 스킬 본문이 영문이므로 텍스트 흐름도도 영문으로 쓴다.

이유: 스킬은 에이전트가 읽고 실행하는 지시문이라 렌더링 없이 그대로 파싱·diff·grep 되어야 하고, Mermaid 블록은 진단을 어렵게 한다. 이 규약은 **스킬 문서 한정**이며, 사용자 프로젝트에 생성되는 산출 문서에는 적용되지 않는다(사용자 글로벌 규약은 복잡 구조에 Mermaid를 권하지만, 그것은 산출물 쪽 규칙이다).

## 3. 형식 문서 단일 정의(single-definition) 규칙

영속 문서의 **형식 정의는 한 벌만 존재**하며 소유 스킬의 디렉터리에 둔다. 다른 스킬은 복사하지 않고 경로로 참조한다.

- `skills/fg-ask/CONTEXT-FORMAT.md`, `skills/fg-ask/ADR-FORMAT.md` — grill-with-docs 원본.
- `skills/fg-run/PLAN-FORMAT.md` — plan.md 형식 + 분할 규칙. 생산자는 fg-ask지만 fg-ask 디렉터리가 verbatim 영역이라 소비자(fg-run) 쪽에 둔다.
- `skills/fg-learn/RETRO-FORMAT.md` — 회고 형식.

다른 스킬(fg-done 포함)은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(상대경로 `../fg-ask/` 등)로 참조하고 **자체 복사하지 않는다**. 루트 `references/` 디렉터리는 폐지됐다. forge 루트 해석 규칙(ADR-0011)의 단일 정의도 같은 패턴으로 `skills/fg-run/FORGE-ROOT.md` 한 곳에만 있고 모든 루프 스킬이 이를 참조한다(복붙 금지).

## 4. 매니페스트 동기화 규칙

버전·스킬 개수·설명은 여러 파일에 중복되므로 함께 갱신해야 한다.

- 매니페스트 JSON을 편집하면 반드시 검증한다(깨지면 설치 실패):

  ```bash
  node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
  ```

- **버전은 3곳을 동기 갱신**: `.claude-plugin/plugin.json`의 `version`, `.claude-plugin/marketplace.json`의 `metadata.version`과 `plugins[0].version`.
- 스킬 개수·설명을 바꾸면 `plugin.json`과 `marketplace.json`을 **함께** 갱신한다(둘 다 사람이 읽는 설명을 담는다).
- 두 description은 역할이 다르다: `marketplace.json`의 `metadata.description`은 루프(ask→run→learn→done)를 정의하는 한 줄 태그라인이라 루프 밖 유틸리티(fg-map류)를 넣지 않는다. `plugins[].description`(과 `plugin.json`의 `description`)은 전체 스킬 목록을 담으므로 루프 밖 스킬도 반영한다.

## 5. README 이중 언어 동기화

`README.md`(영문)와 `README.ko.md`(한글)는 같은 내용의 번역 쌍이다. **한쪽을 갱신하면 반드시 다른 쪽도 같은 변경으로 함께 갱신**한다(양방향). 한쪽만 고치면 두 문서가 어긋난다. 두 파일은 루트에 있고 분량이 거의 같다(현재 각각 약 22KB / 24KB).

## 6. 절제(restraint) — ADR / CONTEXT / 회고 승급 규율

영속 문서는 루프의 "연료"이지 산출물이 아니므로, 바를 넘을 때만 승급한다.

- **ADR** (`.forge/adr/NNNN-slug.md`): 세 조건(되돌리기 어렵다 / 맥락 없이 의아하다 / 진짜 트레이드오프) **모두** 충족 시에만 작성. 번호는 불변·재사용 금지. 은퇴는 삭제가 아니라 `.forge/adr/retired/`로 이동(fg-cleanup, ADR-0012).
- **CONTEXT** (`.forge/CONTEXT.md`): 도메인 용어만. **구현 세부 금지.** fg-ask가 그릴링 중 인라인 갱신.
- **회고** (`.forge/retro/YYYY-MM-DD-slug.md`): 승급 바를 못 넘는 학습의 종착지. 회고에서 나온 모든 걸 영속 문서로 밀어 넣지 않는다.

전부 **lazy 생성**(쓸 내용이 생길 때만). 위치는 `.forge/` 안이지만 git 추적 여부로 휘발 상태와 구분되며, `.gitignore`가 `.forge/*`를 제외하되 영속 문서(`!.forge/CONTEXT.md`, `!.forge/adr/`, `!.forge/retro/`, `!.forge/codebase/`, `!.forge/config.json`)와 브랜치 루트(`!.forge/branch/`)만 화이트리스트로 되살린다.

## 7. 핸드오프 스타일 — 진술형, "진행할까요?" 금지

각 스킬은 끝에서 "방금 한 것 / 다음 단계 / 시작하는 법"을 **자연스러운 대화체**로 전한다(정해진 양식을 사무적으로 출력하지 않는다). 핵심은 **전환이 진술형**이라는 것이다 — "진행할까요?"로 다음 단계 진입을 *묻지 않고* 다음 스킬·트리거를 알리고 멈춘다.

체이닝(동의 시 다음 스킬 자동 호출)은 **fg-next 전담**이다. 예외는 fg-run 단일작업 종료뿐 — 분기가 많아 4지 명시 메뉴를 제시한다. 핸드오프에 "진행할까요?"를 재추가하지 말 것(근거: ADR-0015, 개정 2026-06-11).

## 8. 표면적 변경(surgical changes)

스킬을 편집할 땐 입출력 상태 계약(`.forge/`의 파일 흐름)을 깨지 않아야 흐름이 이어진다. 특히 `skills/fg-ask/`는 grill-with-docs 원본의 자기완결 3파일이고, verbatim 본문과 맨 아래 "Forge integration (minimal)" 섹션은 따로 움직이므로 둘 중 하나만 고치면 계약이 깨진다.

## 9. bash 스크립트 컨벤션 (신규)

`scripts/`에 처음 도입된 bash 스크립트(`scripts/forge-statusline.sh`)가 정립한 규약:

- **POSIX 지향 bash.** 셔뱅은 `#!/usr/bin/env bash`, `set -u`로 미정의 변수 차단(`set -e`는 쓰지 않음 — 빈/없음 상태를 정상 종료 0으로 다뤄야 하므로).
- **의존성은 git + bash 뿐.** `jq`나 node 런타임을 쓰지 않는다. JSON·Markdown은 `sed`로 패턴 추출해 읽는다(예: `config.json`의 `defaultBranch`, plan의 `forge-slug` 주석, `STATUS.md`의 `verified:`, `loop.md`의 `replan-round`/`replan-cap`).
- **cwd 상대 읽기.** 스크립트는 현재 작업 디렉터리 기준으로 `.forge/`(또는 ADR-0011 브랜치 루트 `.forge/branch/<branch>/`)를 해석한다. 절대경로를 박지 않아 statusline·테스트 양쪽에서 임의 디렉터리를 cwd로 줘 동작시킬 수 있다.
- **display-only.** 이 스크립트는 forge 상태를 읽어 표시만 하며 아무것도 쓰지 않는다. fg-status의 next-step 우선순위 기계를 재현하지 않는다(ADR-0017) — "다음에 뭘 할지"의 단일 출처는 fg-status, 스크립트는 "지금 어디인지"만 보여준다.
- **테스트 동반.** 새 스크립트에는 fixture 기반 동반 테스트(`scripts/<name>.test.sh`)를 둔다(아래 TESTING.md 참조).
