# 2026-06-07 — fg-next 오케스트레이터 스킬 추가

## 계획 대비 실제
- 계획대로 된 것: 5개 슬라이스(SKILL.md 생성 + 매니페스트 2곳·CLAUDE.md·양 README·fg-status 상호참조) 전부 계획대로. Dynamic Workflow 없이 직접 실행(문서 편집뿐). 정적 계약은 grep/node로 실측 확인(frontmatter name 자동탐색, JSON 유효, 7파일 일관 반영, metadata.description 불변).
- 차이: 거의 없음. 유일한 의도적 미수정 — README 양 언어 헤더 한 줄("루프 4개 + fg-map 유틸리티")이 이미 quick/status/tdd를 빠뜨린 stale 상태였으나 이번 범위 밖이라 surgical하게 두었음.

## 학습
- **"보고 vs 행동" 형제 패턴.** 읽기 전용 도출 로직(다음-단계 상태 머신)을 한 곳(fg-status §"Deriving the next step")에 두고, 행동 스킬(fg-next)이 그걸 *참조*해 실행만 덧붙였다. 루프가 바뀌어도 상태 머신은 한 곳만 고치면 된다. 향후 루프-밖 유틸리티(읽기형/행동형 쌍)를 설계할 때 재사용할 구조.
- **소프트 결합의 취약점(다음 루프가 읽을 연료).** fg-next는 fg-status SKILL.md의 *섹션 이름*("Deriving the next step")으로 참조한다. fg-status 본문은 fg-ask처럼 verbatim 영역이 아니라 언제든 리팩터될 수 있어, 그 섹션명/구조가 바뀌면 참조가 조용히 끊긴다. 다음에 fg-status를 손볼 때 이 참조를 함께 점검할 것. 세 번째 소비자가 생기면 상태 머신을 공유 NEXT-STEP.md로 추출하는 게 더 안전(이번엔 소비자 2개라 추출 보류 — 절제).
- **다르게 할 것:** 스킬 본문 섹션을 다른 스킬이 참조할 때는, 참조 측에 "이 섹션명이 바뀌면 끊긴다"는 사실을 명시하는 게 좋다(현재 fg-next는 경로만 가리킴).

## 문서 갱신
- CONTEXT.md 승급: 없음 (새 도메인 용어 아님 — fg-next는 스킬 이름)
- ADR 추가: 없음 (가산형·가역 스킬, fg-status 선례에 따라 ADR 생략 — 그릴링에서 결정, plan "설계 결정" 섹션에 근거 기록)
