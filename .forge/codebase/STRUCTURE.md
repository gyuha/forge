---
last_mapped_commit: 54877b368a1025c44da1e1ca669880c2f955ac45
mapped: 2026-06-18
---

# STRUCTURE

리포 루트가 곧 **플러그인 루트이자 마켓플레이스**다(harness 플러그인과 동일 패턴). 산출물은 전부 Markdown과 JSON이며 소스 코드 디렉터리(`src/` 등)는 없다.

## 디렉터리 레이아웃

```
forge/
├── .claude-plugin/
│   ├── plugin.json          # 플러그인 매니페스트 (skills/ 자동 탐색 → skills 필드 생략)
│   └── marketplace.json     # 이 리포를 마켓플레이스로 등록 (plugins[].source = "./")
├── skills/<name>/
│   ├── SKILL.md             # 스킬 본문 (frontmatter name = 정식 식별자, 영문)
│   └── *-FORMAT.md          # 일부 스킬만 보유하는 형식 문서 (단일 소유 사본)
├── scripts/
│   ├── forge-status.sh                  # fg-status 결정적 상태 스크립트 (ADR-0020)
│   ├── forge-statusline.sh              # fg-statusline 설치용 fragment 원본
│   ├── forge-statusline-wrapper.sh      # 기존 statusLine 래핑 원본
│   └── *.test.sh                        # 위 두 statusline 스크립트의 bash 테스트
├── docs/
│   ├── skills.md                        # 스킬 카탈로그
│   ├── state-contract.md                # 상태 계약·디렉터리·흐름 상세 (기록의 아키텍처)
│   └── forge-vs-loop-engineering.md
├── .forge/                  # 자기 자신의 forge 상태·영속 문서 (ARCHITECTURE.md 참조)
│   ├── adr/NNNN-*.md         # 이 리포 자신의 결정 기록 (adr/retired/ 포함)
│   ├── retro/                # 회고 로그
│   └── codebase/*.md         # 이 지도 문서들(ARCHITECTURE.md / STRUCTURE.md 등)
├── CLAUDE.md                # 프로젝트 지침 (스킬 목록·설계 원칙·배포 규칙)
├── CHANGELOG.md
├── README.md                # 영문
└── README.ko.md             # 한글 — README.md와 번역 쌍, 함께 갱신해야 함
```

## 17개 스킬 (한 줄 역할)

**루프 4단계:**

- `skills/fg-ask` — ① 대화형 그릴링. plan을 도메인·용어에 대고 검증해 `backlog/<slug>.md`로 적재. CONTEXT.md·ADR 인라인 갱신.
- `skills/fg-run` — ② plan을 Dynamic Workflow로 실행, `run.md`에 계획↔실제 기록, 핸드오프에서 UAT로 `verified:` 기록.
- `skills/fg-learn` — ③ 학습을 CONTEXT.md·ADR로 승급, 나머지는 `retro/`에 기록. 항상 대화형.
- `skills/fg-done` — ④ 회고 확인 → STATUS `done` 마감 → `done/`로 봉인 → 활성 상태 비움(재실행 차단).

**루프 밖 유틸리티:**

- `skills/fg-status` — 읽기 전용 상태 리포터(현황 + 다음 단계 한 줄). 아무것도 안 씀.
- `skills/fg-next` — 다음 단계 하나를 도출해 곧바로 실행하는 오케스트레이터. `all` 모드는 백로그 소진까지 자동 주행.
- `skills/fg-loop` — goal 주도 한정 재계획 무인 루프. `loop.md`에 정지 체크·범위·상한을 못 박고 벽까지 주행(ADR-0016).
- `skills/fg-map` — 코드베이스를 병렬 서브에이전트로 `.forge/codebase/` 지도로 만든다.
- `skills/fg-quick` — 사소한 작업 경량 차선. 형식 산출물 없이 `quick/LOG.md` 한 줄 + 직접 실행, 활성 슬롯 미접촉(ADR-0003).
- `skills/fg-merge` — `git merge` 뒤 브랜치 forge 루트를 `.forge/`로 통합(ADR-0011). git 조작 안 함.
- `skills/fg-cleanup` — 오래된/대체된 ADR을 `adr/retired/`로 은퇴(ADR-0012). 번호 불변·삭제 안 함.
- `skills/fg-doctor` — 읽기 전용 무결성 health check(상태 계약 + 문서/매니페스트 정합, ADR-0019). 자동 수정 안 함.
- `skills/fg-drop` — 미봉인 작업 폐기(hard-delete 또는 `dropped/` 보관, ADR-0021). git·코드 미접촉.
- `skills/fg-tdd` — 영속 TDD 모드 토글(`config.json`의 `tdd`, ADR-0008).
- `skills/fg-eco` — 위임 모델 티어링 토글(`config.json`의 `eco`, ADR-0014).
- `skills/fg-statusline` — statusline에 forge 진행 상태를 띄우는 설정 유틸리티(ADR-0017).
- `skills/fg-adversarial-review` — fg-run↔fg-learn 사이 선택적 적대적 리뷰(6렌즈 팬아웃, ADR-0018). 비-게이트.

## 형식 문서 위치 (단일 소유 사본)

형식 정의는 한 벌만 존재하며 소유 스킬 디렉터리에 둔다. 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(상대경로 `../fg-ask/` 등)로 참조하고 자체 복사하지 않는다. 루트 `references/` 디렉터리는 폐지됐다.

- `skills/fg-ask/CONTEXT-FORMAT.md` · `skills/fg-ask/ADR-FORMAT.md` — grill-with-docs 원본(영문 verbatim). fg-ask가 소유.
- `skills/fg-run/PLAN-FORMAT.md` — `plan.md` 형식 + 분할 규칙. 생산자는 fg-ask지만 fg-ask 디렉터리가 verbatim 영역이라 소비자(fg-run) 쪽에 둠.
- `skills/fg-run/FORGE-ROOT.md` — 브랜치별 forge 루트 해석 규칙의 단일 정의(ADR-0011). 모든 루프 스킬이 참조.
- `skills/fg-run/RUN-ALL.md` — "모두 실행" 배치 절차.
- `skills/fg-learn/RETRO-FORMAT.md` — 회고 파일 형식. fg-learn이 소유.

## 명명 규약

- 스킬 정식 식별자 = `SKILL.md` frontmatter의 `name`(디렉터리명이 아님). 관례상 둘은 일치하며 전부 `fg-` 접두.
- 백로그 plan: `backlog/<slug>.md`. 봉인 아카이브: `done/<날짜-slug>/`(예: `2026-06-17-...`). 회고: `retro/YYYY-MM-DD-slug.md`. ADR: `adr/NNNN-slug.md`(zero-padded 4자리, 번호 불변·재사용 금지).
- 스킬 본문(`SKILL.md`)·형식 문서(`*-FORMAT.md`)는 영문 작성. 단 사용자에게 출력하는 언어와 산출 문서(plan·회고·CONTEXT·ADR)는 사용자 언어를 따른다.
- 매니페스트 버전은 3곳 동기: `plugin.json`의 `version`, `marketplace.json`의 `metadata.version`과 `plugins[0].version`.
- `README.md`(영문)와 `README.ko.md`(한글)는 번역 쌍 — 한쪽 갱신 시 반드시 함께 갱신.
- 스킬 문서의 흐름도는 Mermaid가 아니라 텍스트 흐름도(`A → B → C`)로 작성(에이전트가 렌더링 없이 파싱·grep·diff하기 위함). 이 규약은 스킬 문서 한정이며 사용자 산출 문서엔 적용 안 됨.
