---
last_mapped_commit: 21c8bdbf3b13543c1aec209669ec38b57f8f25e2
mapped: 2026-06-04
---

# Authoring Conventions & Language Policy

## Skill Bodies and Format Documentation

- **스킬 SKILL.md는 영문으로 작성한다.** 내용은 grill-with-docs 원문을 그대로 따르거나(예: `skills/fg-ask/SKILL.md`의 1~90줄), 각 스킬의 업무 맥락을 영문으로 설명한다. 형식 문서(CONTEXT-FORMAT.md, ADR-FORMAT.md, PLAN-FORMAT.md, RETRO-FORMAT.md)도 영문이며, 단일 소유 스킬 디렉터리에 둔다.
- **스킬이 사용자에게 출력하는 내용은 사용자 언어(한글)를 따른다.** 각 SKILL.md 본문에 명시 지시 "respond in the user's language" 또는 동등한 문장을 포함한다. 이 지시는 스킬이 생성하는 모든 산출 문서(`.forge/plan.md`, `.forge/run.md`, `.forge/retro/`, `.forge/CONTEXT.md`, `.forge/adr/`, 회고·그릴링 중 대사)에 적용된다.
- **산출 문서의 섹션 제목은 canonical English로 렌더링한다.** 형식 문서가 정의한 제목(예: "Source of truth", "Work slices", "Plan vs actual")은 영문이지만, 각 스킬이 산출 문서를 쓸 때는 이 제목을 **사용자 언어로 번역하여 렌더링**한다(예: "계획 vs 실제", "작업 슬라이스"). 소비자(fg-run, fg-learn 등)는 문자열이 아닌 의미와 위치로 섹션을 인식한다.

## Handoff & Conversation Style

- **각 스킬의 끝은 자연스러운 대화체로 핸드오프한다.** 다음 단계를 정해진 양식으로 출력하지 않는다. 예: "방금 plan을 백로그에 적재했어. 다음은 fg-run이 이걸 실행하는 건데, 지금 바로 시작할까? 아니면 나중에 해도 괜찮아."
- **핸드오프 메시지는 사용자 언어로 작성한다.** 스킬 본문이 영문이어도, 사용자와 대화하는 부분(질문, 결과 보고, 다음 단계 제시)은 한글이다.

## Domain & Implementation Documentation Boundary

- **`CONTEXT.md`는 도메인 글로서리이며, 구현 세부를 포함하지 않는다.** 용어만 정의한다(예: "Order = 고객이 주문한 상품 목록"). "고객 정보는 이 컨텍스트에 소유되고, 다른 컨텍스트는 ID로만 참조한다" 같은 경계 정의는 가능하지만, "Order는 PostgreSQL의 orders 테이블에 저장된다" 같은 구현 사실은 포함하지 않는다.
- **`.forge/codebase/` 문서는 구현 사실만 담는다.** STACK.md(기술·런타임·프레임워크·의존성), INTEGRATIONS.md(외부 API·DB·인증), ARCHITECTURE.md(패턴·계층·데이터 흐름), STRUCTURE.md(디렉터리 레이아웃·주요 위치), CONVENTIONS.md(코드 스타일·네이밍·패턴·에러 처리), TESTING.md(프레임워크·구조·모킹·커버리지), CONCERNS.md(기술 부채·버그·보안·성능·취약 영역). 도메인 용어 정의를 이곳에 밀어 넣지 않는다.
- **`fg-ask`는 `CONTEXT.md`와 `.forge/codebase/`를 모두 읽는다.** 그릴링 전 관련 지도 문서를 읽어(있으면) context rot을 줄이고, 용어 충돌이나 구현 가정을 교차 검증한다.

## README 이중 언어 동기화

- **README.md(영문)와 README.ko.md(한글)은 번역 쌍이며, 두 파일을 함께 갱신해야 한다.** 한쪽을 수정하면 반드시 다른 쪽도 같은 변경으로 함께 업데이트한다. 예를 들어, README.md의 스킬 카탈로그 테이블을 수정했으면, README.ko.md의 해당 표도 같은 구조·내용으로 갱신한다(항목 순서·칼럼·설명까지).
- **내용 변경이 한쪽에만 적용되면 두 문서가 어긋난다.** 이는 결국 독자(사용자)에게 모순된 정보를 제공한다.

## Format Documents Ownership & References

- **형식 문서는 한 벌만 존재하며, 소유 스킬 디렉터리에 둔다.**
  - `skills/fg-ask/CONTEXT-FORMAT.md` — CONTEXT.md 작성 형식
  - `skills/fg-ask/ADR-FORMAT.md` — ADR 작성 형식
  - `skills/fg-run/PLAN-FORMAT.md` — plan.md 작성 형식 및 분할 규칙
  - `skills/fg-learn/RETRO-FORMAT.md` — 회고 로그 작성 형식
- **다른 스킬이 이 형식을 참조할 때는 복사하지 않는다.** 스킬 상대 경로(예: `../fg-ask/CONTEXT-FORMAT.md`)로 참조하거나, `${CLAUDE_PLUGIN_ROOT}/skills/fg-ask/` 절대 경로로 읽는다. 자체 복사본을 만들면 업데이트가 분산되어 일관성이 깨진다. fg-cleanup도 fg-ask의 형식 문서를 직접 복사하지 않고 참조한다.
- **형식 문서 자체는 영문이다.** 이는 스킬들이 구현하면서 참고할 명세이며, 실제 생성되는 문서(plan, retro 등)는 사용자 언어이다.

## ADR & CONTEXT.md Promotion Discipline

- **ADR은 세 조건을 모두 만족할 때만 작성한다:** (1) 되돌리기 어렵다, (2) 맥락 없이 의아하다, (3) 진정한 트레이드오프가 있었다. 세 가지 중 하나라도 빠지면 ADR을 제시하지 않는다.
- **CONTEXT.md에는 도메인 개념만 승급한다.** 회고에서 나온 모든 학습을 승격하지 않는다. 예: 구현 세부(테이블 이름, API 응답 구조), 일반 프로그래밍 개념(타임아웃, 에러 타입), 도구 사용법은 CONTEXT.md로 올리지 않는다.
- **승격 판단은 자동이 아니라 대화형이다.** fg-learn이 후보를 제시하고 사용자의 확인을 받은 뒤 CONTEXT.md나 ADR에 반영한다.

## Manifest Description Role Distinction

- **`plugin.json`의 `description` vs `marketplace.json`의 `metadata.description`은 역할이 다르다.**
  - `plugin.json` → `description`: 플러그인에 포함된 **모든 스킬**을 나열한다. 루프를 이루는 4개 스킬(fg-ask, fg-run, fg-learn, fg-cleanup) + 루프 밖 유틸리티(fg-map, fg-quick, fg-status) 전부를 기술한다. 이를 통해 "이 플러그인에는 몇 개의 스킬이 들어 있고, 각각 뭘 하는가"를 전체적으로 본다.
  - `marketplace.json` → `metadata.description`: **forge 루프(ask → plan → execute → retro → cleanup)를 정의하는 한 줄 태그라인**이다. 루프 밖 유틸리티(fg-map, fg-quick, fg-status)는 여기에 포함하지 않는다. 이를 포함하면 "forge의 정체"인 4단계 루프 정의가 흐려진다.

## Deploy Rules ("배포" 명령)

- **사용자가 프롬프트에 "배포"라고 치면 아래 순서대로 실행한다:**
  1. **CHANGELOG.md 갱신** — 마지막 배포(마지막 버전 범프 커밋) 이후의 커밋들을 요약해 새 버전 섹션(`## [X.Y.Z] - YYYY-MM-DD`)을 맨 위에 추가. 형식은 Keep a Changelog 약식(Added / Changed / Fixed). 파일이 없으면 새로 생성.
  2. **3곳 버전 범프** — 기본은 patch. 사용자 지정(minor/major)은 따름. 반드시 동기 갱신:
     - `plugin.json` → `version`
     - `marketplace.json` → `metadata.version`
     - `marketplace.json` → `plugins[0].version`
  3. **매니페스트 JSON 유효성 확인** — `node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"`
  4. **commit & push** — 커밋 메시지 `chore(release): vX.Y.Z`, main 브랜치로 push. 설치는 main을 당기므로 push까지가 배포.
- **선행 확인:**
  - 작업 트리에 배포와 무관한 변경이 섞여 있으면 멈추고 먼저 확인받는다.
  - 마지막 배포 이후 커밋이 없으면 배포할 것이 없다고 통지하고 멈춘다.
- **참고:** 설치는 main 브랜치를 당기므로, 배포 후 변경사항이 마켓플레이스에 반영되려면 main에 push되어 있어야 한다.

## Key File Paths & Locations

스킬과 형식 문서의 정규 위치:
- `skills/fg-ask/SKILL.md` — 그릴링 스킬, grill-with-docs 원문 포함, Forge integration 섹션으로 루프 연결
- `skills/fg-ask/CONTEXT-FORMAT.md` — CONTEXT.md 형식 문서, 유일한 정의본
- `skills/fg-ask/ADR-FORMAT.md` — ADR 형식 문서, 유일한 정의본
- `skills/fg-run/PLAN-FORMAT.md` — plan.md 형식 및 분할 규칙, 유일한 정의본
- `skills/fg-learn/SKILL.md` — 회고 스킬
- `skills/fg-learn/RETRO-FORMAT.md` — 회고 형식 문서, 유일한 정의본
- `skills/fg-cleanup/SKILL.md` — 정리 스킬
- `skills/fg-map/SKILL.md` — 코드베이스 매핑 유틸리티
- `skills/fg-quick/SKILL.md` — 경량 차선 유틸리티
- `skills/fg-status/SKILL.md` — 읽기 전용 상태 리포터
- `.claude-plugin/plugin.json` — 플러그인 매니페스트, 모든 스킬 설명 포함
- `.claude-plugin/marketplace.json` — 마켓플레이스 등록 설정, 루프 태그라인 정의
- `CLAUDE.md` — 이 리포지터리의 개발 가이드, 통역(this file) 역할
- `README.md` / `README.ko.md` — 사용자 위임 문서, 이중 언어 번역 쌍

산출 문서 위치 (`.forge/` 하위, git 추적은 선별):
- `.forge/CONTEXT.md` — 도메인 글로서리 (단일 컨텍스트 전용; 멀티는 `src/<context>/CONTEXT.md` + 루트 `CONTEXT-MAP.md`)
- `.forge/adr/NNNN-slug.md` — 아키텍처 결정 (모든 컨텍스트가 여기에 공유)
- `.forge/retro/YYYY-MM-DD-slug.md` — 세션 회고 로그
- `.forge/codebase/*.md` — 코드베이스 지도 (7개 구조 문서)
- `.forge/backlog/<slug>.md` — 미실행 계획 (휘발)
- `.forge/plan.md` — 활성 슬롯 (휘발)
- `.forge/run.md` — 실행 기록 (휘발)
- `.forge/STATUS.md` — 상태 마커 (휘발)
- `.forge/quick/LOG.md` — 경량 작업 로그 (휘발)

## Volatile vs Permanent Docs (.forge/ git Policy)

- **.gitignore는 `.forge/*`로 설정한다** (`.forge/` 아님). 디렉터리 자체를 ignore하면 내부를 `!`로 되살릴 수 없다.
- **영속 문서만 화이트리스트로 되살려 추적한다:** `!.forge/CONTEXT.md`, `!.forge/adr/`, `!.forge/retro/`, `!.forge/codebase/`
- **휘발 상태는 제외된다:** plan.md, run.md, STATUS.md, backlog/, executed/, done/, quick/LOG.md 등. 개발 중 임시 파일은 커밋 대상이 아니다.
- **새 영속 문서 종류가 생기면 화이트리스트에 한 줄 추가한다** (현재 4종이 대부분이라 변경은 드물다).

## Known Inconsistencies (Before Editing, Be Aware)

현재 상태에서 의도적 반복으로 생긴 표면 어긋남:

- **`skills/fg-ask/SKILL.md` 본문(1~90줄)은 grill-with-docs 영문 원본 verbatim이며, Forge integration 섹션(90줄 이후)만 forge 루프 연결을 담는다.** 둘 중 하나만 고치면 계약이 깨진다. SKILL.md 수정 시 두 부분의 경계를 명확히 한다.
- **`forge-prd.md`는 옛 설계 초안이다.** 스킬 5개라고 하면서 다이어그램은 4단계만 나열하고, 현재 `fg-cleanup`을 옛 이름 `fg-complete`로 가리킨다. 명세로 신뢰하지 말 것 — 실제는 `skills/` 디렉터리와 `README.md`가 기준이다.
- **다중 컨텍스트는 예외다.** 컨텍스트별 `CONTEXT.md`는 코드 옆(`src/<context>/`)에 둔다. 루트 `CONTEXT-MAP.md`도 마찬가지. `.forge/` 통합 규칙은 단일 컨텍스트 `CONTEXT.md`에만 적용된다.
