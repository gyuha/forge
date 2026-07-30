<!-- forge-slug: eco-summary-table-2of2 -->
<!-- task: 100 -->
<!-- part: 2/2 -->
<!-- priority: high -->
<!-- tdd: off -->
# eco 요약 표 (2/2) — 배치·무인 경로 1행 표 + ADR-0032 개정

## Goal / Non-goals
- Goal: `eco: true`일 때 배치·무인 경로(Run all·`fg-done all`·`fg-next` 위임 봉인·`fg-next all`·fg-loop)가 **작업당 1행 표**로 보고하게 하고, 그것이 ADR-0032의 "위임/배치는 요약 금지"를 **되돌리는 게 아님**을 그 ADR 개정에 명시한다.
- Non-goals:
  - part 1/2의 범위(ECO.md 정의·fg-run 종료·run.md 슬라이스 한 줄·fg-done 단일 봉인) — **선행 완료 전제**.
  - **eco off 경로** — ADR-0032가 문구 그대로 유효하고, 배치·무인 경로는 종전 간결 notice만 낸다. 개정은 eco on 경로만 추가한다.
  - 검증 게이트(ADR-0009)·회고 자동 skip 규율(ADR-0010)·봉인 스크립트(ADR-0030)·`all` 모드의 확인 게이트 — 전부 불변. 이 작업은 화면 출력 계층만 건드린다.
  - 새 표 형태의 발명 — 1행 표 형태는 part 1의 `ECO.md` 섹션이 이미 정의했고 여기서는 **참조**만 한다(복붙 금지).

## Source of truth
- Glossary terms: **eco 요약 표**, **봉인 요약** — `.forge/CONTEXT.md`
- Related ADRs:
  - `.forge/adr/260730-230321-eco-summary-table.md` — 근거 결정. "ADR-0032와의 관계" 절이 이 part의 논거
  - `.forge/adr/0032-fg-done-single-seal-summary.md` — **개정 대상**
  - `.forge/adr/0010-fg-next-all-momentum-mode.md` / `.forge/adr/0016-fg-loop-goal-driven-bounded-replan.md` — 무인 주행의 momentum 원칙(1행 표가 이를 해치지 않아야 함)
  - `.forge/adr/0023-fg-done-all-batch-seal.md` — `all` 모드의 경계
  - `.forge/adr/0028-unattended-drive-continuation-and-goal-pairing.md` — `DRIVE.md`의 공유 주행 규율
- 이슈 추적: GitHub 이슈 #7
- Definition of Done: `eco: true`에서 `fg-next all`(또는 Run all / `fg-done all`)을 돌리면 작업당 1행 표로 누적 보고되고, `eco: false`면 종전 간결 notice 그대로다. ADR-0032에 개정 절이 있어 "왜 이것이 되돌림이 아닌지"를 후속 독자가 읽을 수 있다.

## Work slices
- [ ] S1. `.forge/adr/0032-fg-done-single-seal-summary.md`에 **개정 절**을 추가한다 — (a) eco on이면 단일 봉인 요약이 표 형태로 렌더되고(part 1에서 구현), (b) eco on이면 배치/무인 경로가 **작업당 1행 표**를 내며, (c) 이것이 ADR-0032가 경고한 "일관성 수정으로 되돌리기"가 **아닌** 이유 — 금지의 근거는 "작업마다 요약이면 wall of text"였고 1행 표는 현행 산문 notice보다 **짧으므로** 그 취지를 위반이 아니라 이행한다, (d) **eco off에서는 원 문구가 그대로 유효**하다. 기존 본문·2026-07-27 개정은 역사 기록으로 보존한다(ADR-0015/0010의 개정 선례와 동형) — completion criterion: 개정 절이 네 항목을 담고, eco off 동작이 불변임이 명시되며, 기존 본문이 삭제되지 않았다
- [ ] S2. `skills/fg-run/RUN-ALL.md`에 eco 분기를 추가한다 — `eco: true`면 배치 종료 보고를 작업당 1행 표(`#`·작업·검증·회고·결과)로 교체(ECO.md 참조). 파킹 규칙(sealable만 파킹, `failed`은 active slot에 남김)과 진술형 배치 핸드오프(ADR-0015 2026-06-11 개정: "어느 것부터?"는 fg-learn 소유 질문이므로 중복 금지)는 **불변** — completion criterion: eco on/off 두 경로가 서술되고, 파킹 규칙과 "어느 것부터? 금지"가 그대로 유지된다
- [ ] S3. `skills/fg-done/SKILL.md` `all` 모드의 "The notice stays terse."(L141)를 개정한다 — `eco: false`면 종전대로 요약 챕터 금지, `eco: true`면 작업당 1행 표로 보고(단일-봉인 요약 챕터는 여전히 금지 — 1행 표와 요약 챕터는 다른 것). 업프론트 확인 게이트 1회·검증 게이트·set-aside 목록은 **불변** — completion criterion: 두 경로가 명확히 갈리고, "1행 표 ≠ 단일-봉인 요약 챕터"가 명시되며, 확인 게이트와 검증 게이트 서술이 손상되지 않았다
- [ ] S4. `skills/fg-next/DRIVE.md`의 "A delegated seal stays terse."(L14)를 개정한다 — 위임 봉인은 여전히 단일-봉인 요약을 내지 않되, `eco: true`면 작업당 1행 표로 누적 보고한다(ECO.md 참조). 같은 파일의 "Do not relay a delegated skill's retro recommendation."(L13)과 턴 내 계속·`/goal` 페어링 규율은 **불변**. `fg-loop`은 DRIVE.md를 상속하므로 자체 서술이 필요한지 확인하고, 필요 없으면 **건드리지 않는다**(중복 정의 금지) — completion criterion: DRIVE.md가 eco 분기를 담고, `fg-loop/SKILL.md`에 중복 정의를 넣지 않았음이 확인된다(상속으로 충분한지 실제로 읽어 판단)
- [ ] S5. `skills/fg-next/SKILL.md`의 위임 봉인 서술(L30 부근)에 eco 분기를 반영하고, `skills/fg-eco/SKILL.md`의 "누가 eco를 읽는가" 목록에 **fg-next**를 추가한다(fg-done은 part 1에서 추가됨) — completion criterion: fg-next의 위임 봉인 서술이 DRIVE.md와 어긋나지 않고, fg-eco의 독자 목록이 완전하다(fg-ask·fg-run·fg-done·fg-next)
- [ ] S6. **경로 완전성 감사** — `grep`으로 "위임 봉인/간결 유지/terse" 계열 서술이 있는 모든 지점을 재열거해 eco 분기가 빠진 곳이 없는지 확인하고, 이 part가 바꾼 범위에 맞춰 `docs/skills.md`·`docs/state-contract.md`(run.md 형식 규정이 상태 계약 표에 반영될 필요가 있으면)·`README.md`+`README.ko.md`를 동기화한다 — completion criterion: `grep -rn "간결 유지\|stays terse\|delegated seal" skills/`의 모든 히트가 eco 분기를 갖거나 의도적으로 무관함이 확인되고, 매니페스트 JSON이 유효하며 `fg-doctor`가 정합 위반을 보고하지 않는다

## Notes
- **이 part의 핵심 위험은 경로 누락이다.** 회고 `2026-07-06-fg-done-seal-summary` F2가 정확히 이 실패를 기록했다 — 뻔한 위임 경로(autochain·all·loop)만 커버하고 fg-status 상태머신이 "회고 이미 충족 → fg-done 직접"으로 도출하는 **fg-next 원샷 직접 봉인**을 놓쳤다. 교훈: *"obvious 경로가 아니라 상태머신이 그 스킬로 가는 모든 길을 세어라."* S6이 그 감사를 담당한다.
- **강제력의 성격을 정직히 유지한다.** ADR-0032가 스스로 진단한 대로 이 계열의 prose 강제는 잊으면 verbose해질 뿐인 cosmetic-on-forget이다. 표는 형태라 누락이 더 잘 보이지만 기계 게이트는 여전히 없다 — 개정 절에서 이 점을 과장하지 말 것.
- **part 1 선행 전제**: 1행 표 형태의 정의가 `ECO.md`(part 1 S1)에 있으므로, part 1 없이 이 part만 실행하면 참조 대상이 없다. 소프트 순서가 아니라 실질 의존이다.
