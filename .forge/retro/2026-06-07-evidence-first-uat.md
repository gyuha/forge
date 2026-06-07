# 2026-06-07 — 증거-우선 검증 (UAT yes에 한 줄 증거 의무)

## 계획 대비 실제
- 계획대로 된 것: 3슬라이스(fg-run SKILL `yes` bullet → `yes (<evidence>)` + TDD 특례 / ADR-0009 보강 단락 / 양 README 동기) 전부 계획대로. grep으로 n/a·skipped·failed bullet 불변 확인.
- 차이: 없음. 실질 변화는 `yes`에 한 줄 증거 요구뿐(비목표대로 다른 상태·새 단계·새 필드 없음).

## 학습
- **외부 규율을 새 기능이 아니라 기존 게이트의 "결 강화"로 흡수.** superpowers `verification-before-completion`(증거 먼저)을 새 단계/필드 없이 ADR-0009의 `yes` 형식 한 줄로 빨아들였다 — forge가 GSD화(단계·필드 비대)되는 걸 막는 패턴. "남의 좋은 규율을 들일 때, 새 구조 대신 기존 구조의 표현을 조이는 쪽을 먼저 본다."
- **다르게 할 것:** 특별히 없음. 저-div·단일 ADR 보강.

## 문서 갱신
- CONTEXT.md 승급: 없음
- ADR 추가: 없음 (ADR-0009에 단락 보강 — 신규 결정 아님)
