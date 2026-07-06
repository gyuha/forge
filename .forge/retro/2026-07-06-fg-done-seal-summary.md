# 2026-07-06 — fg-done 단일 봉인 요약 (task #69)

## Plan vs actual
- What went as planned: 계획(그릴링 결정)은 건전. S1~S4 슬라이스대로 — fg-done SKILL 요약 블록+게이트, fg-next/DRIVE 위임-간결 규율, ADR-0032, docs/skills.md 동기, 스크립트·상태 계약·검증 게이트 불변. Dynamic Workflow 대신 직접 순차 실행(같은 영역 2026-07-05 회고의 fork-failed 교훈).
- Divergences (저 — 재그릴 불필요, 계획 전제 아님 실행 품질):
  - **첫 패스 prose에 결함 5건.** 적대적 리뷰(6렌즈 Task 팬아웃)가 잡아 봉인 전 in-place 수정. 계획이 틀린 게 아니라 실행이 틀린 것 → fix-forward 별도 plan 대신 같은 파일 교정, fg-ask 재그릴 불필요, 목표는 수정 후 달성.
    - F1(major): 요약이 retro를 `done/`에서 읽으라 지시했으나 스크립트는 `.forge/retro/`에 남겨둠 → STATUS `retro:` 경로 읽기로 교정.
    - F2(major): terse 규율이 autochain·drive만 커버, fg-next 원샷 *직접* 봉인 사각 → fg-next §2 절 추가·열거 확장.
    - F3~F5(minor): 'Confirmed' 헤딩 스펙 부재→hedge, `{date-slug}` 재구성→dest= 토큰, 3b/3a 번호·중복 렌더→정리.
    - F6(design): cross-file prose 강제의 cosmetic-on-forget 한계를 ADR-0032에 정직 명시.

## Learnings
- Do differently next time:
  - **LLM 지시 prose가 다른 포맷 문서의 헤딩/필드를 참조하면, 그 헤딩이 포맷 문서에 실제 정의됐는지 확인하라.** 'Confirmed'는 관행 회고에만 있고 RETRO-FORMAT.md엔 없어(정의된 건 'Do differently next time'뿐) "유지" 줄이 빌 뻔했다. 관행이 아닌 스펙-보장 헤딩을 참조하거나 graceful hedge.
  - **게이트 동작을 여러 호출 경로에 걸 땐 상태머신의 모든 분기를 종단(fg-done)까지 추적해 빠짐없이 열거하라.** 뻔한 위임 경로(autochain·all·loop)만 커버하고 fg-status 상태머신이 "회고 이미 충족→fg-done 직접" 도출하는 fg-next 원샷 직접 봉인을 놓쳤다. "obvious 경로"가 아니라 "상태머신이 그 스킬로 가는 모든 길"을 세어라.
  - **지시 prose는 실제 기계 계약(스크립트가 뭘 옮기고 뭘 남기는지)과 일치해야 한다.** retro는 done/으로 아카이브되지 않는다(스크립트가 제자리에서 읽고 경로만 STATUS에 기록). 봉인 후 산출물 읽는 위치를 쓸 땐 스크립트 소스를 확인.
  - **스크립트가 진실을 emit하면(예: `SEALED … dest=<path>`) 그걸 소비하라 — 템플릿에서 경로를 재구성하지 마라.** `{date-slug}` 재구성은 봉인일과 회고일을 혼동해 크로스데이에 없는 경로를 만든다.
- Confirmed (계속 유지):
  - **"사소해 보이는" doc/지시 변경에도 적대적 리뷰가 실제 결함을 캔다** — 이번에 5건. instruction-doc 변경에 fg-adversarial-review를 돌리는 값이 확인됐다.
  - **이 환경에선 리뷰 팬아웃도 Workflow(fork 실패) 대신 Task 서브에이전트로.** 2026-07-05 회고의 "직접 실행 기본" 패턴이 적대적 리뷰의 6렌즈 병렬 팬아웃까지 확장 확인 — Task 팬아웃은 정상 동작.
  - **cross-file prose 강제는 잊으면 stall하는 self-enforcing(ADR-0015)과 달리 잊어도 verbose할 뿐인 cosmetic-on-forget.** 선례를 인용할 때 강제력의 종류를 구분하고, 완화는 "전 경로 prose 커버 + 방어적 기본값"으로.

## Doc updates
- CONTEXT.md promotion: none (신규 도메인 용어 없음; `.forge/CONTEXT.md` 부재).
- ADR added: none — 설계 결정은 fg-ask 그릴링에서 이미 **ADR-0032**로 생성됐고, 적대적 리뷰 F6에서 강제력 한계·트레이드오프를 보강했다. 위 학습들은 실행/프로세스 교훈이라 ADR 바(3충족)를 넘지 않아 이 retro log에 남긴다.
