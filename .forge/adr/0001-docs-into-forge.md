---
status: accepted
---

# 모든 forge 문서를 .forge/ 하위에 두고 영속 문서만 git 선별 추적한다

forge가 생성하는 모든 문서 — 휘발 루프 상태(plan/run/STATUS/backlog/executed/done)와 영속 문서(CONTEXT.md/adr/retro/codebase) — 를 표준 위치(루트 `CONTEXT.md`, `docs/adr/`, `docs/retro/`, `docs/codebase/`)가 아니라 **단일 `.forge/` 디렉터리 안에 모은다.** `.gitignore`는 `.forge/`를 기본 제외(`​.forge/*`)하되 영속 문서 4종만 화이트리스트(`!.forge/CONTEXT.md` 등)로 되살려 추적한다. 그래서 **위치는 전부 `.forge/` 안이고, 휘발/영속의 구분은 git 추적 여부**가 된다. forge 관련 산출물을 한 폴더에서 보고 싶다는 요구에서 출발했다.

## Considered Options

- **(채택) `.forge/` 통합 + 화이트리스트 추적** — 모든 산출물이 한 지붕 아래. 휘발 상태는 자동 제외(미래에 새 휘발 항목이 생겨도 화이트리스트 밖이라 실수 커밋이 구조적으로 차단됨), 영속 4종만 명시 추적.
- **(기각) 표준 위치 유지** — grill-with-docs 원본·관행대로 루트 `CONTEXT.md` + `docs/adr|retro|codebase/`. forge 산출물이 프로젝트 곳곳에 흩어져 "한 폴더에서 본다"는 요구를 못 채움.
- **(기각) `.forge/` 전체 추적 또는 전체 제외** — 전체 추적은 휘발 임시 상태(개발 중 plan/run)까지 커밋돼 이력이 더러워지고, 전체 제외(기존 방식)는 영속 문서가 git에 안 남아 루프의 "연료"가 휘발됨.

## Consequences

- **멀티 컨텍스트는 예외.** 컨텍스트별 `CONTEXT.md`는 코드 옆(`src/<context>/`) 배치가 본질이라 `.forge/` 통합 대상이 아니다. `CONTEXT-MAP.md`도 루트에 둔다. 단일 컨텍스트 `CONTEXT.md`만 `.forge/CONTEXT.md`.
- **gitignore는 `.forge/*`여야 한다(`.forge/` 아님).** 디렉터리 자체를 ignore하면 git 규칙상 내부를 `!`로 되살릴 수 없다. 이 패턴을 깨면 영속 문서가 조용히 추적에서 빠진다.
- 새 영속 문서 종류가 생기면 화이트리스트에 한 줄 추가해야 한다(영속 종류는 4종으로 거의 고정이라 부담은 작다).
- grill-with-docs 원본과 경로가 달라지므로, fg-ask의 verbatim 본문(원문 경로 예시)과 실제 forge 경로(`.forge/` 하위) 사이에 의도적 표면 불일치가 생긴다 — 경로 권위는 Forge integration 섹션과 형식 문서가 가진다.
