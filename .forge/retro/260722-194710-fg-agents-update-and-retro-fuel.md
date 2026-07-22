# 2026-07-22 — fg-agents: retro 참고 fuel + update-aware 재실행 (이슈 #6)

## Plan vs actual
- What went as planned: 두 slice(S1 ADR-0024 개정, S2 fg-agents/SKILL.md 편집)를 계획대로 직접 실행(워크플로우 없이 — docs-only·직렬 의존이라 병렬성 이득 0). retro=reference fuel(fg-ask 대칭)·informed rewrite(merge 엔진 없음) 설계는 적대적 리뷰의 12건 반박을 견딤. 비목표(fg-run 디스패치·retro truth 격상·ADR fuel·새 CONTEXT 용어) 전부 준수.
- Divergences: 적대적 리뷰(6렌즈+verify, 16→refute 12→생존 1)가 **초판 개정의 스펙 갭**을 잡음 — 그릴링/plan S2에서 "update/add/**retire**"를 세 델타로 열거했으나, 실행 시 §4·흐름도 write·핸드오프·Document impact를 **new/update만** 구현. retire가 제안 타입으로만 떠 있고 실행·보고 경로가 없어, 승인된 retire가 조용한 no-op 또는 게이트 밖 즉흥 삭제로 갈리는 결함. 사용자 승인 하에 active slot에서 즉시 배선(§4 retire 제거 문단·흐름도 RETIRE 분기·핸드오프 created/updated/retired·Document impact removes·ADR-0024 "세 델타의 실행" 조항).

## Learnings
- Do differently next time:
  - **열거한 결과 집합은 끝까지 관통시켜라.** 승인 가능한 결과를 N개로 열거(new/update/retire)하면 N개 전부를 **제안→실행→보고**까지 배선한다. 하나라도 제안 단계에만 있고 실행·보고가 비면, 에이전트가 no-op 또는 즉흥 파괴 액션으로 갈린다. 스킬 편집 시 "제안 타입 목록"과 "실행/흐름도/핸드오프/Document impact"를 grep으로 대조해 dangling 분기가 없는지 확인.
  - **적대적 리뷰의 렌즈 수렴은 강한 신호.** 4개 독립 렌즈가 동일 결함으로 수렴하면 그 자체가 "진짜"의 증거. 반대로 다수 findings가 refute로 탈락하면 그 영역 설계는 견고하다는 신호 — 리뷰가 "무엇이 갭이고 무엇이 견고한지"를 갈라주는 용도로 유효.
  - **이슈 요구를 액면 그대로 받지 마라.** 이슈 #6의 "ADR 참고"는 이미 구현돼 있었고, triage/그릴링 Q1에서 현재 구현 상태부터 대조해 rework를 피함. 이슈의 전제는 작성 시점 지식일 뿐 — 코드로 먼저 검증.

## Doc updates
- CONTEXT.md promotion: none (retire/informed rewrite는 implementation 표현 — 글로서리 대상 아님)
- ADR added: none (retire 배선 결정은 실행 중 ADR-0024 개정 "세 델타의 실행"에 이미 승급 — 신규 ADR 불필요)
