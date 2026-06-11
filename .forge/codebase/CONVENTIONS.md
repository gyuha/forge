---
last_mapped_commit: 847fa4208a8ef8b709da41d36d106a3f3f92af29
mapped: 2026-06-11
---

# 작성 규약 (Authoring Conventions)

이 리포는 애플리케이션 코드가 없다. 산출물은 `SKILL.md`, `*-FORMAT.md`, 두 매니페스트(`.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json`), 그리고 이중 언어 README(`README.md` · `README.ko.md`)뿐이다. 따라서 여기서 말하는 "규약"은 코드 스타일이 아니라 **스킬과 문서를 작성하는 규약**(Markdown + JSON)이다. 권위 출처는 루트 `CLAUDE.md`의 "스킬 편집 규약"·"배포 규칙" 섹션이며, 이 문서는 그것을 현재 작업 트리(v0.4.5 + 3차 감사 미커밋 수정분) 기준으로 지도화한 것이다.

## 언어 정책 (Language Policy)

- **스킬 본문(`SKILL.md`)과 형식 문서(`*-FORMAT.md`)는 영문으로 작성한다.** 대상: `skills/*/SKILL.md`(12개), `skills/fg-ask/CONTEXT-FORMAT.md`, `skills/fg-ask/ADR-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-run/FORGE-ROOT.md`, `skills/fg-learn/RETRO-FORMAT.md`. grill-with-docs 원문에서 그대로 옮긴 부분(`skills/fg-ask/SKILL.md` 본문)은 영문 verbatim을 유지한다.
- **사용자 대면 출력은 사용자의 언어를 따른다 — 강화된 MUST 지시문이 12개 스킬 전부에 있다.** v0.4.5(커밋 523f04c)에서 권고형 "respond in the user's language"가 강행형으로 격상됐다. 모든 스킬의 본문 상단 **Language** 블록이 같은 핵심 문장을 담는다: *"you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English."* 스킬을 새로 만들거나 고칠 때 이 블록을 빠뜨리면 규약 위반이다.
- **산출 문서도 사용자 언어로 쓴다.** plan·run 노트·회고·`CONTEXT.md` 항목·ADR·핸드오프 전부. 형식 문서가 정의하는 섹션 제목은 canonical English이지만, 실제 문서를 쓸 때는 사용자 언어로 렌더링한다 — 소비 스킬(`fg-run`, `fg-learn` 등)은 섹션을 문자열이 아니라 **의미와 위치**로 매칭한다(`skills/fg-ask/SKILL.md` Language 블록에 명시).

## 핸드오프 규약 (ADR-0015 이후)

근거: `.forge/adr/0015-fg-run-handoff-menu-others-stated.md` + `CLAUDE.md` "스킬 편집 규약" 핸드오프 항목. 핵심은 **state-and-stop** — 전환 허락 질문이 규약과 어긋난 드리프트였음을 바로잡은 것이다.

- **전환은 진술형이다.** 각 스킬은 끝에서 "방금 한 것 / 다음 단계 / 시작하는 법"을 자연스러운 대화체로 **알리고 멈춘다**. "진행할까요?"로 다음 단계 진입을 묻지 않는다. 핸드오프에 전환 허락 질문을 재추가하는 것은 명시적 금지다.
- **유일한 예외는 fg-run 종료의 3지 명시 메뉴다** (`skills/fg-run/SKILL.md` 핸드오프 섹션): ① 회고 → fg-learn(기본) ② 바로 종료 → `retro: skipped (사유)` 기록 후 fg-done을 인라인 호출해 봉인까지 ③ 프롬프트로 나가기 → 실행만 둔 채 정지. 단 "바로 종료"는 **저-divergence일 때만** 제시한다(ADR-0002의 회고 skip 가드 유지). fg-run만 메뉴인 이유: 루프 최대 분기점(3갈래)이라 한 번의 명시 메뉴가 명료함을 주고, 나머지 경계(ask→run, learn→done, done→새 ask)는 다음 단계가 자명해 진술이면 충분하기 때문.
- **체이닝(다음 스킬 자동 호출)은 fg-next 전담이다.** 스킬은 마크다운 지시문이라 호출자를 런타임에 감지할 수 없으므로, "fg-next가 부르면 자동" 같은 스킬 내 분기는 불가능하다 — 대신 fg-next가 오케스트레이터로서 흐름을 쥔다. 예외는 fg-run "바로 종료"의 fg-done 인라인 호출뿐(사용자가 명시 선택한 종료의 이행이지 나그가 아님).
- **fg-status는 보고만, fg-next는 행동까지.** `skills/fg-status/SKILL.md`는 next-step을 한 줄로 알리되 "진행 여부를 묻지도, 호출하지도 않는다"고 명시하고, `skills/fg-next/SKILL.md`는 "한 줄 알린 뒤 같은 턴에 Skill tool로 호출 — 별도 go-ahead를 기다리지 않는다"고 명시한다.

## 흐름도는 Mermaid가 아니라 텍스트로

- `SKILL.md` 안에서 흐름·상태 전이·분기는 **텍스트 흐름도**로 작성한다(`A → B → C`; 분기는 들여쓰기·화살표·조건 레이블). **Mermaid 금지.** 스킬 본문은 렌더링 없이 그대로 파싱되는 에이전트 지시문이라, Mermaid 블록은 diff·grep·진단을 어렵게 한다. 스킬 본문이 영문이므로 텍스트 흐름도도 영문이다.
- 이 규약은 스킬 문서 한정이다 — 사용자 프로젝트에 생성되는 산출 문서에는 적용되지 않는다(사용자 전역 지침이 산출물에 Mermaid를 허용하더라도 스킬 본문과는 무관).

## 단일 출처 형식 문서 (Single-Source Format Docs)

- 각 형식 정의는 **소유 스킬의 디렉터리에 단 한 벌만** 존재한다: `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`(grill-with-docs 원본), `skills/fg-run/PLAN-FORMAT.md`(plan 형식 + 분할 규칙 — 생산자는 fg-ask지만 fg-ask 디렉터리는 verbatim 영역이라 소비자 쪽 소유), `skills/fg-run/FORGE-ROOT.md`(브랜치별 forge 루트 해석의 단일 정의, ADR-0011), `skills/fg-learn/RETRO-FORMAT.md`.
- 다른 스킬은 **복사하지 않고** `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(상대경로 `../fg-ask/` 등)로 참조한다. 루트 `references/` 디렉터리는 폐지됐다. 단일 정의가 스킬 본문과 갈라지는 것이 이 리포의 반복 실패 모드라서(`.forge/retro/2026-06-11-handoff-state-not-ask.md`), 복붙 금지는 엄격하다.

## README 이중 언어 동기화

- `README.md`(영문)와 `README.ko.md`(한글)는 **같은 내용의 번역 쌍**이다. 한쪽을 고치면 반드시 다른 쪽도 같은 변경으로 함께 갱신한다(역방향 동일). 한쪽만 고치면 두 문서가 어긋난다 — 정합 감사의 단골 점검 항목(F 카테고리)이다.

## 매니페스트: 두 description, 두 역할

- `marketplace.json`의 `metadata.description`은 **루프를 정의하는 한 줄 태그라인**(ask → execute → retro → done)이다. 루프 밖 유틸리티(fg-map류)는 의도적으로 빼서 루프 정의를 선명하게 유지한다 — 끼우면 루프 정의가 흐려진다.
- `plugins[].description`(과 `plugin.json`의 `description`)은 **전체 스킬 목록**이다 — 루프 밖 스킬도 여기에 담는다.
- 버전은 **세 곳을 반드시 동기 갱신**한다: `plugin.json`의 `version`, `marketplace.json`의 `metadata.version`과 `plugins[0].version`(현재 모두 `0.4.5`).
- 스킬은 `skills/<dir>/SKILL.md`에서 자동 탐색되므로 `plugin.json`은 `skills` 필드를 생략한다. **스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name`**이다(현재 12개 스킬에서 우연히 일치: fg-ask, fg-cleanup, fg-done, fg-eco, fg-learn, fg-map, fg-merge, fg-next, fg-quick, fg-run, fg-status, fg-tdd).

## 승급 절제 (Promotion Restraint)

- ADR과 글로서리 용어는 **바를 넘을 때만** 승급한다. ADR은 세 조건을 모두 충족해야 한다: 되돌리기 어렵다 / 맥락 없이 의아하다 / 진짜 트레이드오프. 회고에서 나온 모든 학습을 영속 문서로 밀어 넣지 않는다 — 바를 못 넘는 학습은 `.forge/retro/`에 남는 것으로 충분하다.
- ADR 번호는 단조 증가(현재 `0001`–`0015`)이며 재사용·변경 금지. `fg-cleanup`이 오래된/대체된 ADR을 삭제가 아니라 `.forge/adr/retired/<NNNN>-slug.md`로 은퇴시킨다(supersede/retire 마킹, ADR-0012). `retired/` 디렉터리는 lazy 생성이며 현재 존재하지 않는다. fg-ask는 `retired/`를 정답 출처로 읽지 않는다.

## STATUS.md 어휘 (상태 마커 규약)

`STATUS.md`는 plan/run과 함께 이동하는 동반 마커다(이중 장부 아님 — 상태의 원천은 파일 위치). 필드 어휘는 `skills/fg-run/SKILL.md`(생산)과 `skills/fg-done/SKILL.md`(마감)이 계약한다:

- `status:` — `executed`(fg-run 기록) → `done`(fg-done 마감).
- `verified:` — **봉인 가능 값**: `yes (<evidence>)` / `skipped (<사유>)` / `n/a (<사유>)`. **차단 값**: `pending`(미검증) / `failed (<사유>)`(검증했으나 깨짐). `yes`는 반드시 한 줄 증거를 동반한다 — 실행한 명령/관찰한 출력(예: `yes (npm test → 42 passing)`), "사람이 그렇다고 했다"만으로는 부족(evidence-first, `skills/fg-run/SKILL.md` UAT 섹션). `failed`는 waiver 불가 — fresh re-run으로 재검증될 때만 봉인된다(ADR-0009).
- `retro:` — `pending`(실행 직후) → 회고 경로(`.forge/retro/YYYY-MM-DD-<slug>.md`) 또는 `skipped (<사유>)`(저-divergence 한정 의도적 skip, ADR-0002). fg-done의 봉인 가드는 회고 파일 존재 **또는** `retro: skipped`를 통과로 인정한다.
- plan 첫 줄의 `<!-- forge-slug: ... -->` 주석이 회고·봉인의 짝 맞춤 식별자(파일 이동에도 영속), `<!-- task: N -->`은 단조 증가 작업 번호(ADR-0005), `<!-- tdd: on|off -->`는 TDD 모드 마커(ADR-0008)다.

## 배포 절차 ("배포")

사용자가 **"배포"**라고 치면 순서대로 수행한다(`CLAUDE.md` 배포 규칙):

```
CHANGELOG.md 작성 → 버전 3곳 범프 → JSON 검증 → commit → push(main)
```

- `CHANGELOG.md`는 Keep a Changelog 약식으로 새 버전 섹션을 맨 위에 추가(없으면 lazy 생성). 버전 범프 기본은 patch("배포 minor"/"배포 major"로 재정의). 커밋 메시지는 `chore(release): vX.Y.Z`. 설치는 GitHub `main`을 당기므로 **push까지가 배포**다.
- 배포와 무관한 작업 트리 변경은 릴리스 커밋에 끼워 넣지 않는다 — 멈추고 먼저 확인받는다. 마지막 배포 이후 커밋이 0개면 배포할 것이 없다고 알리고 멈춘다.
- **미커밋 변경이 곧 릴리스 내용이면**(커밋 0개 + 작업 트리에 그 릴리스의 기능 작업) 먼저 별도 `feat` 커밋으로 묶은 뒤 릴리스를 돈다(릴리스 커밋엔 CHANGELOG + 버전 범프만). 이 리포의 정상 흐름이다.

## 두 기둥 (불변 설계 원칙)

스킬을 수정할 때 이 둘을 깨면 forge가 forge가 아니게 된다:

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** 워크플로우는 실행 중 사용자 입력을 받을 수 없다. 한 질문씩 주고받는 그릴링(fg-ask)은 반드시 워크플로우 밖 대화로 진행한다.
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.
