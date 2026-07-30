<!-- forge-slug: eco-summary-table-1of2 -->
<!-- task: 99 -->
<!-- part: 1/2 -->
<!-- priority: high -->
<!-- tdd: off -->
# eco 요약 표 (1/2) — 규율 정의 + 단일 작업 경로

## Goal / Non-goals
- Goal: `eco: true`일 때 **단일 작업**이 끝나는 두 지점(fg-run 실행 종료·fg-done 단일 봉인)의 산문 핸드오프를 **eco 요약 표로 교체**한다. 표의 재료를 보장하기 위해 run.md에 슬라이스별 한 줄 결과를 규정하고, 규율 정의는 `ECO.md` 한 곳에만 둔다.
- Non-goals:
  - **배치·무인 경로**(Run all·`fg-done all`·`fg-next all`·fg-loop)의 1행 표 — part 2/2 소관.
  - **ADR-0032 개정** — part 2/2 소관(배치 경로 허용이 개정의 본체이므로 그쪽에 붙인다).
  - **실행 *중* narration 압축** — 실시간 가시성 상실 대가로 범위 밖(ADR `260730-230321`에서 거부).
  - **fg-ask 그릴링·fg-learn 회고·생성 문서(plan/run/retro/CONTEXT/ADR)** — 영구 제외(기둥 1·2).
  - **fg-quick** — 영구 제외(슬라이스 없음, 이미 `LOG.md` 한 줄).
  - **eco off 경로의 어떤 동작도 바꾸지 않음** — 상태 계약·검증 게이트(ADR-0009)·봉인 스크립트(ADR-0030)·회고 게이트(ADR-0002) 전부 불변. 이 작업은 화면 출력 계층만 건드린다.
  - **새 config 키·새 `*-FORMAT.md` 파일** — 만들지 않음.

## Source of truth
- Glossary terms: **eco 요약 표**, **봉인 요약** — `.forge/CONTEXT.md`(이 브랜치 루트에 이번 그릴링으로 추가)
- Related ADRs:
  - `.forge/adr/260730-230321-eco-summary-table.md` — 이 작업의 근거 결정(이번 그릴링에서 생성)
  - `.forge/adr/0014-fg-eco-subagent-model-tiering.md` — eco가 유일한 활성화 경로. "활성화하는 것"이 둘 → 셋
  - `.forge/adr/0032-fg-done-single-seal-summary.md` — 봉인 요약의 소유자. 단일 봉인 요약의 *형태*를 eco면 표로 바꾼다
  - `.forge/adr/0015-fg-run-handoff-menu-others-stated.md` — 핸드오프 진술형·고정 양식 금지 규약. eco 게이트가 이를 기본값에서 보존
  - `.forge/adr/0009-verification-gate-before-seal.md` — `verified:`는 표 헤더에 반드시 노출(빠지면 봉인 가능 여부 판단 불가)
- 이슈 추적: GitHub 이슈 #7
- Definition of Done: `eco: true`인 상태에서 단일 작업을 fg-run으로 실행하면 종료 출력이 산문 대신 요약 표로 나오고, 그 작업을 `/fg-done`으로 봉인하면 봉인 요약이 표 형태로 나온다. `eco: false`면 두 지점 모두 종전 산문 그대로다. 규율 정의는 `ECO.md` 한 곳에만 있고 다른 파일은 참조만 한다.

## Work slices
- [ ] S1. `skills/fg-eco/ECO.md`에 **"eco summary table"** 섹션을 신설해 규율을 **단일 정의**한다 — 교체(추가 아님) 원칙, 헤더 한 줄(제목·`#task`·`verified`·divergence) + `▸ 요청`/`▸ 수행`(슬라이스 표)/`▸ 다음` 챕터, 슬라이스 표 열(`#`·슬라이스·결과·계획 대비), 챕터별 한 줄 상한, 슬라이스 1개면 표 없이 한 줄, 배치 1행 표의 형태(part 2가 참조할 자리), 그리고 제외 경계(그릴링·회고·생성 문서·fg-quick)가 ECO.md 기존 `Terse communication` 예외와 동일함을 명시 — completion criterion: ECO.md에 섹션이 존재하고, 단일 작업 표와 배치 1행 표 두 형태가 예시로 제시되며, 다른 어떤 파일도 이 형태를 복제하지 않는다(`grep`으로 확인)
- [ ] S2. `skills/fg-run/SKILL.md` step 4(`### 4. Record divergences in run.md…`)에 **run.md 슬라이스별 한 줄 결과** 규정을 추가한다(`S1 ✅ 계획대로` / `S2 ⚠ 경로 변경` 형태) — eco 여부와 무관하게 항상 기록(재료 보장이 목적이며, ADR-0032 기존 요약의 약한 고리도 이때 메워진다). `RUN-FORMAT.md`는 신설하지 않는다 — completion criterion: step 4가 슬라이스별 한 줄을 요구하고, 그 기록이 eco off에서도 적용됨이 명시된다
- [ ] S3. `skills/fg-run/SKILL.md` `## Next-flow handoff`(L138~)에 **eco 분기**를 추가한다 — `eco: true`면 진술형 산문을 요약 표로 **교체**(ECO.md 참조, 형태 복붙 금지)하고, 검증 게이트(step 0의 `verified:` 기록)·divergence에 따른 조건부 안내(저면 skip+봉인, 고면 재그릴 권고)·적대적 리뷰 포인터의 **내용은 보존**하되 표의 `▸ 다음` 한 줄로 접는다. `eco: false`면 종전 산문 그대로 — completion criterion: eco on/off 두 경로가 모두 서술되고, ADR-0015의 진술형(메뉴 없음·`AskUserQuestion` 없음) 원칙이 표 경로에서도 유지됨이 명시된다
- [ ] S4. `skills/fg-done/SKILL.md` 봉인 요약 블록(L103~124)에 **eco 분기**를 추가한다 — `eco: true`면 기존 `▸ Requirements`/`▸ What was done`/`▸ Retro`/meta 챕터를 표 형태로 렌더(`▸ 수행`이 슬라이스 표, 회고 챕터는 종전대로 retro 파일이 있을 때만, meta는 헤더 한 줄로 접음). 재료는 종전 계약대로 아카이브된 plan/run/STATUS + STATUS `retro:` 경로의 retro에서 읽는다(회고 F1 교훈 — 경로를 재구성하지 말고 스크립트가 emit한 `dest=`를 쓴다). `all` 모드와 위임 경로는 이 slice의 범위 밖(part 2) — completion criterion: 명시적 단일 `/fg-done`에서 eco on이면 표, off면 종전 산문이 나오도록 서술되고, 봉인 스크립트·검증 게이트·회고 게이트는 손대지 않았음이 확인된다
- [ ] S5. `skills/fg-eco/SKILL.md`를 갱신한다 — frontmatter `description`과 본문의 "eco가 활성화하는 것" 목록을 **둘 → 셋**으로(① 서브에이전트 sonnet 캡 ② Eco laziness-first 규율 ③ **eco 요약 표**), 그리고 "누가 eco를 읽는가" 목록(L47~48)에 **fg-done**을 추가한다(fg-next는 part 2) — completion criterion: description과 본문이 세 가지를 일관되게 열거하고, 읽는 주체 목록에 fg-done이 있다
- [ ] S6. 이 part가 바꾼 범위에 맞춰 사용자 문서를 동기화한다 — `CLAUDE.md`의 fg-eco 서술("두 가지를 활성화" → 세 가지) + 핸드오프 규약에 "eco on이면 요약 표로 교체(경계 있는 예외)" 한 줄, `docs/skills.md`의 fg-eco 항목, `README.md`와 `README.ko.md`의 fg-eco 설명(**이중언어 동기 필수**), 그리고 `.claude-plugin/plugin.json`·`.claude-plugin/marketplace.json`의 `description`에 fg-eco 설명이 들어 있으면 함께 갱신(버전 범프는 하지 않음 — 배포는 별건) — completion criterion: `node -e`로 두 매니페스트 JSON이 유효하고, README 두 파일이 같은 변경을 담고 있으며, `fg-doctor`가 이 part에 대한 정합 위반을 보고하지 않는다

## Notes
- **왜 eco 게이트인가**: 기본값(eco off)에서 CLAUDE.md의 "핸드오프는 대화체, 정해진 양식 금지" 규약이 그대로 유지되므로, 고정 양식 출력이 정면충돌이 아니라 **모드 안의 경계 있는 예외**가 된다(fg-quick의 기둥 2 완화, fg-loop의 기둥 1 완화와 같은 계열).
- **왜 압축이 아니라 구조화인가**: ECO.md의 `Terse communication`은 이미 존재하지만 사용자가 켜본 뒤에도 부족했다. 스타일 지시는 지킴 여부가 안 보여 cosmetic-on-forget이고, 표는 형태라서 누락이 보인다.
- **경로 열거 주의**: 회고 `2026-07-06-fg-done-seal-summary` F2의 교훈 — 게이트 동작을 여러 호출 경로에 걸 땐 상태머신의 모든 분기를 종단까지 추적해 빠짐없이 열거하라. 이 part는 **단일 경로만** 다루고 위임/배치 경로는 part 2가 책임진다. part 2 완료 전까지는 배치 경로가 종전 산문으로 남는 것이 **의도된 중간 상태**다.
