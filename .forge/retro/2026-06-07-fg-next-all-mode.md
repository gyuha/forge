# 2026-06-07 — fg-next `all` 모드 (백로그 빌 때까지 대화 벽까지 자동 주행)

## 계획 대비 실제
- 계획대로 된 것: 6슬라이스(fg-next SKILL all 모드 섹션 + description + fg-run 교차참조 + 매니페스트 + 양 README + CLAUDE) 전부 계획대로. ADR-0010은 그릴링 중 생성. 정적 계약 grep/node 실측(개수 nine·metadata 불변·JSON 유효).
- 차이: 거의 없음.

## 학습
- **forge에 "무인 주행(momentum mode)" 개념을 처음 도입.** 핵심은 기둥 #1(그릴링·회고는 대화)을 깨지 않고 자동화하는 방식 — 대화를 자동으로 *치지* 않고, 비대화적 결정(저-div retro skip·n/a verify·cleanup)만 자동화하며, 대화가 필요한 지점(고-div 회고·새 작업 그릴링·fork·failed)에서 **멈춘다**. "자동화 = 벽까지만, 벽에서 멈춤"이 forge식 자동화의 선례.
- **게이트 완화는 ADR로 남긴다.** fg-next 본체(가산·가역)는 ADR 생략했지만, all 모드는 confirm-then-delegate·retro-default 두 게이트를 *완화*하므로 ADR-0010으로 남겼다. "기능 추가"가 아니라 "원칙 완화"일 때가 ADR 기준선이라는 판단 기준이 이번에 명확해짐.
- **다르게 할 것:** all 모드의 "공격적 UAT 자동 시도"는 봉인 가능 값(`yes`/`n/a`)에 못 닿으면 halt하도록 설계했는데, 실제로 어떤 검증이 "사람만 가능"인지의 경계는 실사용에서 드러날 것 — 첫 실사용 후 halt 빈도를 보고 경계를 조정할 것.

## 문서 갱신
- CONTEXT.md 승급: 없음 (새 도메인 용어 아님)
- ADR 추가: ADR-0010 (그릴링 중 생성 — momentum mode·게이트 2개 완화·halt 5조건·저-div 자동skip 트레이드오프)
