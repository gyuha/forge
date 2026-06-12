# 2026-06-12 — fg-learn 일괄 승급 모드 (CONCERNS #5 모순 해소)

## 계획 대비 실제

- 계획대로 된 것: 3슬라이스 전부 — TDD 기준값 선행 고정, fg-learn에 "Batch promotion mode" 절 신설(명시 진입 / 후보 = done의 `retro: skipped` / 바 넘는 것만 개별 retro 파일 / 봉인 STATUS `retro:` 사후 정정), 배제 규칙 2곳(:20 state error·:22 do not re-offer)에 예외 교차참조, Doc impact의 STATUS 불가침 계약에 batch 예외 명시. fg-next·fg-loop·RUN-ALL의 약속 문구는 어긋남 없어 무수정.
- Divergences: 1건(경미) — 빈 활성 상태 안내문에 "batch는 done/을 읽으므로 예외" 한 구절 추가. 계획 미명시 인접 정합(빈 상태에서 batch 진입의 fg-ask 오라우팅 방지), 모드 신설의 직접 귀결로 범위 내.

## 학습

- Do differently next time:
  - **약속의 수신자 검사.** 이번 모순의 뿌리: 세 문서(fg-next all·fg-loop·fg-run skip 경로)가 같은 약속("추후 fg-learn 일괄 승급")을 반복하는 동안 수신 측 fg-learn에 구현이 없었다. 3차 감사 교훈 "계약은 의무 당사자 본문에"의 변종이되 방향이 반대 — 그건 *생산자*의 침묵, 이건 *수신자*의 부재. 일반화: **핸드오프에 "나중에 X가 해준다"를 적는 순간, X의 본문이 그 경로를 실제로 구현하는지 그 자리에서 확인할 것.** 약속을 N곳에 복제해도 구현은 생기지 않는다 — 오히려 N곳이 같은 공수표를 보증해 모순을 더 그럴듯하게 만든다.

## 문서 갱신

- CONTEXT.md 승급: 없음 — 새 도메인 용어 없음 ("일괄 승급"의 정의는 fg-learn 본문이 소유).
- ADR 추가: 없음 — 이미 약속된 계약(ADR-0010·0016 핸드오프 문구)의 정합 복구로, 새 트레이드오프 없음.
