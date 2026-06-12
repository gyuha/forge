---
last_mapped_commit: b45521cd5fc2f536cc212e559af52c3939a5b0a5
mapped: 2026-06-12
---

# 작성 규약 (Authoring Conventions)

이 리포는 애플리케이션 코드가 없다. 산출물은 `SKILL.md`, `*-FORMAT.md`, 두 매니페스트(`.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json`), 그리고 이중 언어 README(`README.md` · `README.ko.md`)뿐이다. 따라서 여기서 말하는 "규약"은 코드 스타일이 아니라 **스킬과 문서를 작성하는 규약**(Markdown + JSON)이다. 권위 출처는 루트 `CLAUDE.md`의 "스킬 편집 규약"·"배포 규칙" 섹션이며, 이 문서는 그것을 현재 작업 트리(v0.4.7 + 13번째 스킬 `fg-loop` 추가 미커밋분) 기준으로 지도화한 것이다.

## 언어 정책 (Language Policy)

- **스킬 본문(`SKILL.md`)과 형식 문서(`*-FORMAT.md`)는 영문으로 작성한다.** 대상: `skills/*/SKILL.md`(13개), `skills/fg-ask/CONTEXT-FORMAT.md`, `skills/fg-ask/ADR-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-run/FORGE-ROOT.md`, `skills/fg-run/RUN-ALL.md`, `skills/fg-learn/RETRO-FORMAT.md`. grill-with-docs 원문에서 그대로 옮긴 부분(`skills/fg-ask/SKILL.md` 본문)은 영문 verbatim을 유지한다.
- **사용자 대면 출력은 사용자의 언어를 따른다 — 강행형 MUST 지시문이 13개 스킬 전부에 있다.** 모든 스킬의 본문 상단 **Language** 블록이 같은 핵심 문장을 담는다: *"you MUST write every message shown to the user — questions, menus, status/next-step lines, and handoff text — in the user's language (detect it from the user's own messages), never mirroring this file's English."* 새로 추가된 `skills/fg-loop/SKILL.md`도 같은 블록을 갖췄다(L12). 스킬을 새로 만들거나 고칠 때 이 블록을 빠뜨리면 규약 위반이다.
- **산출 문서도 사용자 언어로 쓴다.** plan·run 노트·회고·`CONTEXT.md` 항목·ADR·핸드오프·`loop.md` 전부. 형식 문서가 정의하는 섹션 제목은 canonical English이지만, 실제 문서를 쓸 때는 사용자 언어로 렌더링한다 — 소비 스킬(`fg-run`, `fg-learn` 등)은 섹션을 문자열이 아니라 **의미와 위치**로 매칭한다.

## 핸드오프 규약 (ADR-0015, 2026-06-11 개정 반영)

근거: `.forge/adr/0015-fg-run-handoff-menu-others-stated.md`(본문 + "개정 (2026-06-11)" 섹션이 현행 계약) + `CLAUDE.md` "스킬 편집 규약" 핸드오프 항목. 핵심은 **state-and-stop** — 전환 허락 질문("진행할까요?")이 규약과 어긋난 드리프트였음을 바로잡은 것이다.

- **전환은 진술형이다.** 각 스킬은 끝에서 "방금 한 것 / 다음 단계 / 시작하는 법"을 자연스러운 대화체로 **알리고 멈춘다**. 핸드오프에 전환 허락 질문을 재추가하는 것은 명시적 금지다.
- **유일한 예외는 fg-run 단일작업 종료의 4지 명시 메뉴다** (`skills/fg-run/SKILL.md` 핸드오프 섹션, UAT로 `verified:` 기록한 *뒤* 제시):
  1. **회고 후 봉인까지** (기본·divergence 무관) — fg-learn으로 회고를 대화로 정상 수행한 뒤 fg-done을 인라인 호출해 봉인까지. 탈출 조건: 회고 중 재그릴 권고(fg-learn 고-divergence 예외)가 나오면 **자동 봉인을 중단**하고 진술형으로 빠진다 — 사전약속은 자물쇠가 아니다.
  2. **회고만** — 회고 후 멈춤(승급 문서를 봉인 전 검토하고 싶을 때).
  3. **바로 종료** — `retro: skipped (사유)` 기록 + fg-done 인라인 봉인. **저-divergence에서만** 제시(ADR-0002 가드 불변).
  4. **프롬프트로 나가기** — 실행만 둔 채 정지.

  네 옵션은 `AskUserQuestion` 옵션 한도(4)에 정확히 부합한다. fg-run만 메뉴인 이유: 루프 최대 분기점이라 한 번의 명시 메뉴가 명료함을 주고, 나머지 경계(ask→run, learn→done, done→새 ask)는 다음 단계가 자명해 진술이면 충분하기 때문.
- **Run-all 배치 핸드오프도 진술형이다** (같은 개정). "N개가 `executed/`에 회고 대기로 파킹됨 → 다음은 fg-learn 또는 fg-next"를 진술-후-정지. **"어느 것부터?"는 fg-learn이 소유한 질문**이라 배치 핸드오프가 중복하면 단일 정의 위반이다(`skills/fg-run/RUN-ALL.md`).
- **체이닝(다음 스킬 자동 호출)은 fg-next 전담이다.** 스킬은 마크다운 지시문이라 호출자를 런타임에 감지할 수 없으므로, "fg-next가 부르면 자동" 같은 스킬 내 분기는 불가능하다 — 대신 fg-next가 오케스트레이터로서 흐름을 쥔다. 인라인 fg-done 호출(메뉴 1·3번)은 체이닝이 아니라 **사용자가 메뉴에서 명시 선택한 종료의 이행**이다.
- **fg-status는 보고만, fg-next는 행동까지.** `skills/fg-status/SKILL.md`는 next-step을 한 줄로 알리되 묻지도 호출하지도 않고, `skills/fg-next/SKILL.md`는 한 줄 알린 뒤 같은 턴에 곧바로 호출한다. fg-loop의 종료 보고도 진술형이다 — `skills/fg-loop/SKILL.md` Handoff 절: "Statement form — no 'shall I continue?' (ADR-0015)".

## 흐름도는 Mermaid가 아니라 텍스트로

- `SKILL.md` 안에서 흐름·상태 전이·분기는 **텍스트 흐름도**로 작성한다(`A → B → C`; 분기는 들여쓰기·화살표·조건 레이블). **Mermaid 금지.** 스킬 본문은 렌더링 없이 그대로 파싱되는 에이전트 지시문이라, Mermaid 블록은 diff·grep·진단을 어렵게 한다. 스킬 본문이 영문이므로 텍스트 흐름도도 영문이다. 최신 예: `skills/fg-loop/SKILL.md`의 drive 루프 전체가 텍스트 박스-화살표 도식이다(L77–98).
- 이 규약은 스킬 문서 한정이다 — 사용자 프로젝트에 생성되는 산출 문서에는 적용되지 않는다.

## 단일 출처 형식 문서 (Single-Source Format Docs)

- 각 형식 정의는 **소유 스킬의 디렉터리에 단 한 벌만** 존재한다: `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`(grill-with-docs 원본), `skills/fg-run/PLAN-FORMAT.md`(plan 형식 + 분할 규칙 — 생산자는 fg-ask지만 fg-ask 디렉터리는 verbatim 영역이라 소비자 쪽 소유), `skills/fg-run/FORGE-ROOT.md`(브랜치별 forge 루트 해석의 단일 정의, ADR-0011), `skills/fg-run/RUN-ALL.md`(Run all 배치 절차 — 토큰 효율을 위해 선택 시에만 로드), `skills/fg-learn/RETRO-FORMAT.md`.
- 다른 스킬은 **복사하지 않고** `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(상대경로 `../fg-ask/` 등)로 참조한다. 루트 `references/` 디렉터리는 폐지됐다. fg-loop가 이 규약의 최신 실증이다 — fg-ask의 그릴링 방식(`../fg-ask/SKILL.md`), PLAN-FORMAT(`../fg-run/PLAN-FORMAT.md`), forge 루트(`../fg-run/FORGE-ROOT.md`), fg-next all의 주행 기계(`../fg-next/SKILL.md` "all mode")를 전부 **참조로 재사용**하고 한 줄도 복붙하지 않았다(`skills/fg-loop/SKILL.md` L47: "do not duplicate its rules here"). 단일 정의가 스킬 본문과 갈라지는 것이 이 리포의 반복 실패 모드라서(`.forge/retro/2026-06-11-handoff-state-not-ask.md`), 복붙 금지는 엄격하다.

## README 이중 언어 동기화

- `README.md`(영문)와 `README.ko.md`(한글)는 **같은 내용의 번역 쌍**이다. 한쪽을 고치면 반드시 다른 쪽도 같은 변경으로 함께 갱신한다(역방향 동일). 정합 감사의 단골 점검 항목(F 카테고리)이며, fg-loop 추가 작업(#23)에서도 양판 동기(13스킬 카운트·테이블·산문)가 별도 슬라이스(S4)의 완료 기준이었다(`.forge/done/2026-06-12-add-fg-loop/plan.md`).

## 매니페스트: 두 description, 두 역할

- `marketplace.json`의 `metadata.description`은 **루프를 정의하는 한 줄 태그라인**(ask·plan → execute → retro → done)이다. 루프 밖 유틸리티(fg-map·fg-loop류)는 의도적으로 빼서 루프 정의를 선명하게 유지한다 — 끼우면 루프 정의가 흐려진다. fg-loop 추가에서도 `metadata.description`은 불변이었다(plan S3의 명시 완료 기준).
- `plugins[].description`(과 `plugin.json`의 `description`)은 **전체 스킬 목록**이다 — 루프 밖 스킬도 여기에 담는다. 현재 두 곳 모두 fg-loop 포함 13스킬("Thirteen"/"Nine" 워딩)로 동기돼 있다.
- 버전은 **세 곳을 반드시 동기 갱신**한다: `plugin.json`의 `version`, `marketplace.json`의 `metadata.version`과 `plugins[0].version`(현재 모두 `0.4.7`).
- 스킬 1개를 추가하면 손으로 동기해야 하는 ripple 표면이 6지점이다(매니페스트 description 2벌 · README 양판의 카운트+테이블+산문 · `CLAUDE.md` 목록) — `.forge/codebase/CONCERNS.md` #2의 체크리스트가 #19(fg-eco)와 #23(fg-loop) 두 작업에서 그대로 실증됐다(`.forge/retro/2026-06-12-add-fg-loop.md`).

## 스킬 식별자와 frontmatter description

- 스킬은 `skills/<dir>/SKILL.md`에서 자동 탐색되므로 `plugin.json`은 `skills` 필드를 생략한다. **스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name`**이다(현재 13개 스킬에서 우연히 일치: fg-ask, fg-cleanup, fg-done, fg-eco, fg-learn, fg-loop, fg-map, fg-merge, fg-next, fg-quick, fg-run, fg-status, fg-tdd). `name:`이 없거나 오타면 그 스킬만 조용히 미탐색된다 — 점검은 `awk '/^name:/' skills/*/SKILL.md`.
- **frontmatter `description` 길이를 경계하라(~1,024자 권장 한도 의심).** `skills/fg-next/SKILL.md`의 description이 약 1,084자로 흔히 문서화되는 권장 한도(~1,024자)를 넘는 것으로 의심된다 [중간 — 한도 수치·강제 여부 공식 확인 미완, `.forge/codebase/CONCERNS.md` #3]. 이 때문에 fg-loop의 description은 **의도적으로 ~700자로 절제**해 작성됐다(`.forge/retro/2026-06-12-add-fg-loop.md` divergence ③). 나머지 11개는 352–722자로 여유 있다. 새 스킬의 description은 한도 아래로 짧게 쓰는 것이 현행 관행이다.

## 승급 절제 (Promotion Restraint)

- ADR과 글로서리 용어는 **바를 넘을 때만** 승급한다. ADR은 세 조건을 모두 충족해야 한다: 되돌리기 어렵다 / 맥락 없이 의아하다 / 진짜 트레이드오프. 회고에서 나온 모든 학습을 영속 문서로 밀어 넣지 않는다 — 바를 못 넘는 학습은 `.forge/retro/`에 남는 것으로 충분하다. 최신 실증: fg-loop의 "goal 계약·한정 재계획·fix-forward" 용어는 `CONTEXT.md`로 승급하지 않고 ADR-0016이 소유하는 것으로 절제했다(글로서리 오염 방지, `.forge/retro/2026-06-12-add-fg-loop.md`).
- ADR 번호는 단조 증가(현재 `0001`–`0016`)이며 재사용·변경 금지. `fg-cleanup`이 오래된/대체된 ADR을 삭제가 아니라 `.forge/adr/retired/<NNNN>-slug.md`로 은퇴시킨다(ADR-0012). `retired/`는 lazy 생성이며 현재 존재하지 않는다. 결정의 개정은 새 ADR이 아니라 **기존 ADR에 개정 섹션 추가**가 선례다(ADR-0015의 "개정 (2026-06-08/06-11)" 패턴 — 핸드오프 계약을 한 문서에 유지).

## plan 마커 주석 어휘 (Marker-Comment Vocabulary)

plan 파일 머리의 HTML 주석 마커가 루프 전체의 짝 맞춤·표시·실행 모드를 계약한다. 정의는 `skills/fg-run/PLAN-FORMAT.md`가 단일 소유:

- `<!-- forge-slug: ... -->` — 영속 식별자(첫 줄 필수). backlog → 활성 슬롯 → done 이동에도 유지되며 회고(`.forge/retro/*-<slug>.md`)·봉인(`.forge/done/<date-slug>/`)의 짝 맞춤 키.
- `<!-- task: N -->` — 단조 증가 작업 번호(ADR-0005). 표시·선택용 식별자이지 정렬 신호가 아니다. fg-quick 차선은 범위 밖.
- `<!-- tdd: on|off -->` — 실행 모드 마커(ADR-0008). fg-ask가 그릴링 시작에 `.forge/config.json`의 `tdd`를 기본으로 묻고 기록; `on`이면 fg-run이 test-first로 실행(Markdown 리포에서의 해석은 `.forge/codebase/TESTING.md` 참조).
- `<!-- retro-hint: optional -->` — 비구속 힌트(기본 생략). fg-run 핸드오프가 어떤 옵션을 앞세울지에만 영향; skip 결정 자체는 divergence 게이트가 한다.
- `<!-- priority: high|medium|low -->` — 표시/실행 순서 마커(기본 생략 = medium). 자동 선택 아님.
- `<!-- part: N/M -->` — 분할 작업의 soft 순서 힌트. 각 part는 여전히 독립 봉인 가능해야 한다(하드 의존이면 분할점이 아니었던 것).
- `<!-- generated-by: fg-loop -->` — **신규(ADR-0016)**: fg-loop가 한정 재계획으로 자동 생성한 fix-forward plan의 출처 마커. fg-status와 감사 추적이 사람-그릴링 plan과 구분하는 데 쓴다(`skills/fg-loop/SKILL.md` §3). 자동 생성 plan도 PLAN-FORMAT·단조 번호를 그대로 따른다.

## 기둥 완화 차선의 설계 패턴 (신규 정착)

원칙(두 기둥)을 완화하는 차선을 만들 때의 골격이 세 차례 반복으로 정착됐다(`.forge/retro/2026-06-12-add-fg-loop.md`): **① 완화 범위를 사전 명시 ② ADR로 기록 ③ 안전 벽 보존**. 계보 — fg-quick(기둥 2 완화, trivial 한정, ADR-0003) → fg-next all(게이트 2개 완화, ADR-0010) → fg-loop(기둥 1 완화: 사전 승인 범위·상한 내 fix-forward 자동 계획만, ADR-0016). 다음에 원칙 완화 요청이 오면 이 3요소를 기본 골격으로 그릴링한다.

## 배포 절차 ("배포")

사용자가 **"배포"**라고 치면 순서대로 수행한다(`CLAUDE.md` 배포 규칙):

```
CHANGELOG.md 작성 → 버전 3곳 범프 → JSON 검증 → commit → push(main)
```

- `CHANGELOG.md`는 Keep a Changelog 약식으로 새 버전 섹션을 맨 위에 추가(없으면 lazy 생성). 버전 범프 기본은 patch("배포 minor"/"배포 major"로 재정의). 커밋 메시지는 `chore(release): vX.Y.Z`. 설치는 GitHub `main`을 당기므로 **push까지가 배포**다.
- 배포와 무관한 작업 트리 변경은 릴리스 커밋에 끼워 넣지 않는다 — 멈추고 먼저 확인받는다. 마지막 배포 이후 커밋이 0개면 배포할 것이 없다고 알리고 멈춘다.
- **미커밋 변경이 곧 릴리스 내용이면**(커밋 0개 + 작업 트리에 그 릴리스의 기능 작업) 먼저 별도 `feat` 커밋으로 묶은 뒤 릴리스를 돈다(릴리스 커밋엔 CHANGELOG + 버전 범프만). 현재 작업 트리의 fg-loop 추가분이 정확히 이 상태다.

## 두 기둥 (불변 설계 원칙)

스킬을 수정할 때 이 둘을 깨면 forge가 forge가 아니게 된다:

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** 워크플로우는 실행 중 사용자 입력을 받을 수 없다. 한 질문씩 주고받는 그릴링(fg-ask, fg-loop의 기초 질의 포함)은 반드시 워크플로우 밖 대화로 진행한다.
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.

fg-loop는 기둥 1의 *문장*을 바꾸지 않는다 — 자동화되는 것은 기초 질의(대화)에서 사용자가 사전 승인한 범위 안의 fix-forward 계획뿐이고, 범위 승인 자체가 대화의 산출물이다(`.forge/adr/0016-fg-loop-goal-driven-bounded-replan.md`).
