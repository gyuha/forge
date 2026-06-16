# 2026-06-16 — `/goal` 페어링을 "운용 전제 + 정직한 fallback"으로 격상 (fg-loop·fg-next all)

## Plan vs actual
- What went as planned: 4슬라이스 — fg-loop SKILL 4지점·fg-next SKILL `all` 모드·ADR-0016 개정 노트·무-stale-ref 검증. 검증-선행 grep 체크 전수 green, 변경 파일 정확히 3개(스코프 크립 없음). 본 세션 직접 실행(워크플로우 미사용).
- Divergences: 1건(경미) — S1c·S2a "정직한 fallback 문구" grep 기준선이 기존 문구(이미 있던 "one cycle then stall"·"re-trigger")에 오염돼 깨끗한 0→1 신호가 안 나옴. 즉석 보완: 신규 framing에만 등장하는 sentinel(`expected, not a failure`)로 타깃 검증.

## Learnings
- Do differently next time:
  - **하드 제약이 약속을 거짓으로 만들면, 고침은 코드가 아니라 framing이다.** 이번 문제(fg-loop이 한 작업 후 멈춤)의 본질은 버그가 아니라 "unattended" 약속 ↔ "스킬은 `/goal`을 못 켠다"는 하니스 제약의 간극. 무인 루프류 기능을 설계할 땐 "스킬이 강제할 수 없는 것"을 정직한 fallback으로 명문화하는 패턴(운용 전제 제시 + 미사용 시 정직한 동작 + 재출력으로 망각 방지)을 기본 골격으로 — 프로즈를 더 세게 미는 건 이미 실패한 레버(모델이 위임 핸드오프의 "멈춤"을 따라 턴을 yield).
  - **위임 핸드오프의 "진술형 멈춤"(ADR-0015)과 오케스트레이터의 "멈추지 마라"는 본질적 긴장**이고, 이를 봉합하는 유일한 신뢰 메커니즘이 `/goal` Stop hook이다. fg-next all·fg-loop 양쪽에 동형으로 존재하므로 한쪽 수정 시 다른 쪽 동기화 필수(이번에 동시 처리). 위임 스킬 본문의 근접 지시가 오케스트레이터의 먼 지시를 이긴다는 모델 행동을 설계 전제로 삼을 것.
  - **검증-선행 grep 기준선은 신규 문구가 기존 문구와 어휘를 공유하면 오염된다.** 다음엔 (a) 신규 framing에만 쓸 sentinel을 편집 전 미리 정하거나 (b) 제거되는 문구의 count→0 같은 결정적 체크에 무게를 둘 것.

## Doc updates
- CONTEXT.md promotion: none (새 도메인 용어 없음)
- ADR added: none (스탠스 전환은 작업 중 ADR-0016 개정 노트 2026-06-15로 기록됨)
