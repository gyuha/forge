# 2026-06-10 — fg-done 봉인 후 fg-map 제안 (codebase 지도 stale 감지)

## 계획 대비 실제
- 계획대로 된 것: fg-done/SKILL.md에 스텝 3a(조건부 fg-map 제안) + 흐름도 노드 + wrap-up 불릿 3편집. 게이트 (a)`.forge/codebase/` 존재 AND (b)`git status`상 `.forge/` 밖 변경(M·??)일 때만 한 줄 제안, y→fg-map 호출·미해당→침묵. offer-not-auto·핸드오프 포인터(의존 아님)·커밋 lag 허용 명시. 봉인 가드·archive→empty→notify 순서 불변. fg-done 단독.
- Divergences: 없음.

## 학습
- Do differently next time:
  - **forge 핸드오프의 일관된 형 = "싸구려 게이트 → (해당 시) 제안 → 아니면 침묵", 비싼 건 자동 실행 안 함.** 루프 진입(fg-ask #15: executed-미봉인 감지→마치기 제안)과 종료(fg-done #18: 코드 변경+지도 존재 감지→fg-map 제안) 양쪽에 같은 패턴이 자리잡았다. deep-research(ADR-0006)·fg-map의 offer-not-auto와 한 결. 새 핸드오프를 보강할 땐 이 형(조건부·저비용 감지 → offer → 미해당 침묵)을 재사용하고, 자동 실행은 "사람이 비용을 안 물어도 되는 비대화적 결정"에만 한정.
  - **직접 겪은 통증이면 그릴링 초점은 "할까말까"가 아니라 "어떻게".** 이번 통증(이번 세션의 지도 stale)은 ADR-0013 바를 명백히 넘어서, 그릴은 도입 여부가 아니라 메커니즘(자동→제안)을 forge답게 다듬는 데 집중했다. 반면 직전 세 요청(서브에이전트·fg-run순차·perf)은 통증이 막연해 "안 함"으로 수렴 — **통증의 구체성이 그릴 모드를 가른다.**

## 문서 갱신
- CONTEXT.md 승급: 없음 (도메인 용어 없음)
- ADR 추가: 없음 (offer-not-auto는 ADR-0006의 기존 원칙 적용 — 새 결정 아님)
