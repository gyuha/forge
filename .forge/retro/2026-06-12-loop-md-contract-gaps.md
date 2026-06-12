# 2026-06-12 — loop.md 인지 격차 5건 봉합 (CONCERNS #4, 멤버십 목록)

## 계획 대비 실제

- 계획대로 된 것: 8슬라이스 전부 — TDD 기준값 선행 고정(B1~B7 전부 0), fg-loop 멤버십(`## Tasks` 템플릿 절 + 드라이브·재개 필터 + §3 생성 시 등재), fg-ask (1b) 벽 경고, fg-merge in-flight 가드에 branch loop.md, fg-status `(loop)` 출처 태그(generated-by 마커의 첫 소비자), fg-next all의 loop.md 주행 양보, CLAUDE.md 상태 계약 표 loop.md 행 + fg-loop 서술 멤버십 구절, ADR-0016 개정 절. README 양판 무변경(기존 서술이 거짓이 되지 않음 확인).
- Divergences: 2건(경미·범위 내) — ① 재개 경로에 pre-membership loop.md 마이그레이션 규칙(Tasks 절 없는 기존 loop.md → 재개 시 사용자에게 1회 질문으로 절 추가; 없으면 필터가 공집합이 되는 구멍), ② CLAUDE.md done/ 행에 일괄 승급 한 구절(#25의 인접 정합 — 표가 "회고 대상 제외"만 말하면 batch 모드와 어긋남).

## 학습

- Do differently next time:
  - **상태 표면 추가의 ripple 체크리스트.** 이번 5건 격차의 공통 뿌리 = 새 상태 파일(loop.md)이 소비자·가드 전수 점검 없이 출시됨. 스킬 추가의 "6지점 산문 동기화" 체크리스트(#19·#23 회고에서 2회 실증)와 나란한 **상태 파일 추가 전용 ripple 표면**: ① CLAUDE.md 상태 계약 표 행 ② fg-status 보고 ③ 진입 스킬 경고(fg-ask) ④ 오케스트레이터 상호작용(fg-next) ⑤ fg-merge in-flight 가드 ⑥ 새 마커의 소비자 실재 여부. 다음에 새 상태 파일·마커가 생기면 이 6지점을 plan 슬라이스 완료 기준에 박을 것 — 생산자만 적고 끝내면 이번처럼 다음 매핑/감사 때까지 격차가 숨는다.

## 문서 갱신

- CONTEXT.md 승급: 없음 — 새 도메인 용어 없음 (멤버십·Tasks 절의 정의는 fg-loop 본문과 ADR-0016 개정이 소유).
- ADR 추가: 없음(회고에서) — 핵심 결정(멤버십 목록·기각 대안 2건)은 작업 중 ADR-0016 개정 절로 이미 기록됨.
