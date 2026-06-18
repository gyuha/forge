# 2026-06-17 — README를 골격만 남기고 상세를 docs/로 분리

## Plan vs actual
- What went as planned: 4슬라이스 모두 계획대로. docs 2개(skills·state-contract) 생성 → README.md 슬림화(148→85줄) → README.ko.md 동기화(147→84줄). 검증: 섹션 6:6, 16/16 스킬 보존, ADR 링크 11/11 실존, mermaid 양 README 0.
- Divergences: 없음. Dynamic Workflow 대신 직접 실행 — 슬라이스가 직렬 의존이고 "정보 손실 없는 이동"은 한 맥락 일관 판단이 안전해 단일 에이전트가 더 적합(fg-run 비용 규약 적용). 실행 방식 선택일 뿐 범위 변경 아님.

## Learnings
- Do differently next time:
  - **이중언어 README → 단일언어 docs 링크는 언어 비대칭을 명시하라.** README.md(영문)가 한글 docs를 가리키므로 링크에 "(Korean)"을 붙여 영어권 독자 혼란을 줄였다. 다음에 같은 분리를 할 때 기본으로 적용.
  - **docs 하위로 옮긴 내용의 상대 링크는 `../`로 리베이스하라.** 루트 README의 `./.forge/adr/...`를 docs/로 옮기면 `../.forge/adr/...`가 되어야 한다. grep으로 `./.forge/adr` 잔존(0이어야)을 검증하는 게 확실.
  - **거대 산문 문단을 docs로 옮길 때 스킬별 `###` 소제목으로 분해하면 가독성이 크게 오른다.** 원문 문장은 보존(재배치이지 재집필 아님)하되 헤더만 추가.

## Doc updates
- CONTEXT.md promotion: none (새 도메인 용어 없음)
- ADR added: none (문서 재구성은 되돌리기 쉽고 진짜 트레이드오프 없음 — 3조건 미충족)
