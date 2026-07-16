# 2026-07-16 — fg-loop §1에 stop-condition 체크 "충실성(faithfulness)" 4-렌즈 적대 그릴링 추가

## 계획 대 실제
- 계획대로 된 것: 순수 additive `+18/-0`(2파일). `skills/fg-loop/SKILL.md` §1에 4-렌즈 충실성 그릴링 + Autonomy contract의 lean 카브아웃 + 라우팅 확장, `.forge/adr/0016-*.md`에 개정(2026-07-16) 절. DoD 4/4 grep 통과. drive·§2/§3/§4·ledger·Reflexion·walls 기계, fg-ask 전부 무변경.
- Divergences: 사실상 없음. 유일한 즉석 결정은 ADR 개정 절에 기각 대안 2건(렌즈4 분리 게이트·per-check faithfulness rationale 필드)을 명문화한 것 — 이미 plan Non-goals에 담긴 결정이라 범위 내, 의미 추가 없음.

## 학습
- 다음에 다르게: **forge-meta 지시문 개선 부류(#74·#75·#76 동형)는 단발 UAT로 문서 구조(grep 가능한 DoD)까지만 검증되고, 진짜 효과 — 여기서는 "체크가 실제로 더 충실해져 무인 주행의 거짓 완료가 줄어듦" — 는 행동 베팅이라 실제 goal loop 주행에서만 드러난다.** 이 부류 작업의 fg-ask는 UAT 범위를 "관측 가능한 문서 구조"로 명시 한정하고(억지 행동 측정 시도 금지), 실효 확인은 후속 실주행에 위임하는 것을 출발점으로 삼는다. 이제 3회 이상 반복된 안정적 패턴.
- 설계 규율 재확인(이번에도 적용됨): 새 능력을 loop.md **새 필드/상태로 만들지 않고** 기존 절(`## Stop-condition checks`)의 강화된 산출물로 흡수 → 소비자 6지점 ripple 회피(2026-06-12 loop-md-contract-gaps 회고와 동일 판단). 렌즈2가 추가하는 anti-regression 체크도 신규 기계 없이 기존 §2/§3 tension/regression 기계에 그대로 먹이가 되도록 설계.

## Doc updates
- CONTEXT.md 승급: none (구현 소유 개념 — fg-loop 본문/ADR-0016이 소유, 글로서리 대상 아님)
- ADR added: none (새 ADR 없음; 기존 ADR-0016에 개정 절 2026-07-16 추가로 처리 — run에서 완료)
