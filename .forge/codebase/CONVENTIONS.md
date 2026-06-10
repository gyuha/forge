---
last_mapped_commit: 0472a519cbb8275564cdbaa30469f2d0c5472842
mapped: 2026-06-10
---

# 작성 규약 (Authoring Conventions)

이 리포는 애플리케이션 코드가 없다. 산출물은 `SKILL.md`, `*-FORMAT.md`, 두 매니페스트(`.claude-plugin/plugin.json`·`.claude-plugin/marketplace.json`), 그리고 이중 언어 README(`README.md`·`README.ko.md`)뿐이다. 따라서 여기서 말하는 "규약"은 코드 스타일이 아니라 **스킬과 문서를 작성하는 규약**(Markdown + JSON)이다.

## 언어 정책 (Language Policy)

- **스킬 본문(`SKILL.md`)과 형식 문서(`*-FORMAT.md`)는 영문으로 작성한다.** 대상: `skills/*/SKILL.md`, `skills/fg-ask/CONTEXT-FORMAT.md`, `skills/fg-ask/ADR-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-run/FORGE-ROOT.md`, `skills/fg-learn/RETRO-FORMAT.md`. grill-with-docs 원문에서 그대로 옮긴 부분은 영문 verbatim을 유지한다.
- **스킬이 사용자에게 출력하는 언어는 사용자의 언어를 따른다.** 각 `SKILL.md`는 "respond in the user's language" 지시를 명시적으로 담아야 한다. 이는 스킬이 런타임에 내보내는 모든 것에 적용된다 — 질문, 상태 보고, 핸드오프 메시지, 그리고 생성되는 모든 산출 문서(`.forge/plan.md`, `.forge/run.md`, `.forge/retro/*`, `.forge/CONTEXT.md`, `.forge/adr/*`).
- **산출 문서의 표준 섹션 제목은 사용자 언어로 렌더링한다.** 형식 문서는 영문 제목을 정의하지만(예: "Source of truth", "Work slices", "Plan vs actual"), 스킬이 산출물을 쓸 때 제목을 사용자 언어로 번역한다. 소비 스킬(`fg-run`, `fg-learn` 등)은 섹션을 문자열이 아니라 의미와 위치로 인식한다.

## 흐름도는 Mermaid가 아니라 텍스트로

- `SKILL.md` 안에서 흐름·상태 전이·분기는 **텍스트 흐름도**로 작성한다(`A → B → C`; 분기는 들여쓰기·화살표·조건 레이블로). **Mermaid는 절대 쓰지 않는다.** 스킬 본문은 렌더링 없이 파싱되는 에이전트 지시문이므로, Mermaid 블록은 diff·grep·진단을 어렵게 한다. 스킬 본문이 영문이므로 텍스트 흐름도도 영문으로 쓴다.
- 이 규약은 스킬 문서에 한정된다 — 사용자 프로젝트에 생성되는 산출 문서에는 적용되지 않는다.

## 핸드오프와 대화 스타일

- 각 스킬은 끝에서 **자연스러운 대화체 핸드오프**("방금 한 것 / 다음 단계 / 시작하는 법")로 마무리한다. 정해진 양식을 사무적으로 출력하지 않는다.
- 핸드오프 메시지는 스킬 본문이 영문이더라도 사용자 언어로 쓴다.

## 문서 경계 (Documentation Boundary)

- `.forge/CONTEXT.md`(멀티 컨텍스트면 루트 `CONTEXT-MAP.md`)는 **도메인 글로서리**다 — 용어만, 구현 세부 금지. `fg-ask`가 그릴링 중 인라인으로 갱신한다.
- `.forge/codebase/*.md`(이 파일을 포함한 fg-map의 7개 지도)는 구조·규약 등을 기술하며 도메인 용어가 아니다 — 도메인 정의는 이 문서들에 넣지 않는다.

## 승급 절제 (Promotion Restraint)

- ADR과 글로서리 용어는 **바를 넘을 때만** 승급한다. ADR은 세 조건을 모두 충족해야 한다: 되돌리기 어렵다 / 맥락 없이 의아하다 / 진짜 트레이드오프. 회고에서 나온 모든 학습이 영속 문서가 되지는 않으며, 바를 못 넘는 학습은 `.forge/retro/`에 남는다.
- ADR 파일은 `.forge/adr/NNNN-slug.md`로 단조 증가 번호를 쓴다(현재 0001–0013). 번호는 재사용하지 않는다. `fg-cleanup`이 오래된/대체된 ADR을 삭제가 아니라 `.forge/adr/retired/<NNNN>-slug.md`로 은퇴시키며 supersede/retire 마킹을 남긴다 — 번호는 고정된다. (`retired/` 디렉터리는 lazy 생성이며 현재 존재하지 않는다.)

## 매니페스트: 두 description, 두 역할

두 매니페스트(`.claude-plugin/plugin.json`·`.claude-plugin/marketplace.json`)는 모두 사람이 읽는 description을 담지만, 역할이 다르며 서로 호환되지 않는다.

- `marketplace.json`의 `metadata.description`은 **루프를 정의하는 한 줄 태그라인**이다(ask·plan → execute → retro → done). 루프 밖 유틸리티(fg-map류)는 의도적으로 빼서 루프 정의를 선명하게 유지한다.
- `plugins[].description`(과 `plugin.json`의 `description`)은 **전체 스킬 목록**이다 — 루프 밖 스킬도 여기에 담는다. 버전은 동기 유지가 필요한 세 곳에 산다: `plugin.json`의 `version`, `marketplace.json`의 `metadata.version`, `plugins[0].version`(이 커밋 기준 모두 `0.4.2`).
- 스킬은 `skills/<dir>/SKILL.md`에서 자동 탐색된다. **스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name`**이다(현재는 우연히 일치 — 11개 스킬: fg-ask, fg-cleanup, fg-done, fg-learn, fg-map, fg-merge, fg-next, fg-quick, fg-run, fg-status, fg-tdd). 탐색이 자동이므로 `plugin.json`은 `skills` 필드를 생략한다.

## README 이중 언어 동기화

- `README.md`(영문)와 `README.ko.md`(한글)는 **번역 쌍**이다. 한쪽을 고치면 같은 커밋에서 다른 쪽도 같은 변경으로 갱신해야 한다. 한쪽만 고치면 두 문서가 어긋난다.

## 단일 출처 형식 문서 (Single-Source Format Docs)

- 각 형식 정의는 소유 스킬의 디렉터리에 단 한 벌만 존재하며, 다른 스킬은 복사가 아니라 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(상대경로 `../fg-ask/` 등)로 참조한다. `skills/fg-run/PLAN-FORMAT.md`는 plan을 `fg-ask`가 생산하지만 소비자 쪽이 소유한다 — `fg-ask` 디렉터리는 grill-with-docs verbatim 영역이기 때문이다. 루트 `references/` 디렉터리는 폐지됐다.

## 배포 절차 ("배포")

사용자가 **"배포"**라고 치면 순서대로 수행한다: `CHANGELOG.md` 작성(Keep a Changelog 약식, 새 버전 섹션을 맨 위에 — 없으면 lazy 생성) → 위 세 곳의 버전 범프(기본 patch, "배포 minor"/"배포 major"로 재정의) → 매니페스트 JSON 유효성 검증(`TESTING.md`의 node 한 줄) → `chore(release): vX.Y.Z` 커밋 후 `main`에 push(설치는 `main`을 당기므로 push까지가 릴리스다).

절차 흐름:
```
CHANGELOG.md 작성 → 버전 3곳 범프 → JSON 검증 → commit → push(main)
```

- 배포와 무관한 작업 트리 변경을 릴리스 커밋에 끼워 넣지 않는다 — 멈추고 먼저 확인받는다.
- 미커밋 변경이 *곧* 릴리스 내용이면(커밋 0개인데 기능 작업이 스테이징됨), 먼저 별도 `feat` 커밋으로 묶은 뒤 릴리스를 돈다(릴리스 커밋엔 CHANGELOG + 버전 범프만). 이 리포의 정상 흐름이다.

## 두 기둥 (불변 설계 원칙)

스킬을 수정할 때 이 둘을 깨면 forge가 forge가 아니게 된다:

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** 워크플로우는 실행 중 사용자 입력을 받을 수 없다. 한 질문씩 주고받는 그릴링(fg-ask)은 반드시 워크플로우 밖 대화로 진행한다.
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.
