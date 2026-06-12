# 2026-06-12 — fg-loop 신설 (goal 주도 한정 재계획 루프, 13번째 스킬)

## 계획 대비 실제
- 계획대로 된 것: 5슬라이스(S1 fg-loop SKILL.md / S2 fg-status 3곳 통합 / S3 매니페스트 2벌 / S4 README 양판 / S5 CLAUDE.md) 전부 완료. TDD on의 "검증-선행" 해석대로 체크리스트를 편집 전 고정, 편집 후 전수 통과(`verified: yes`). ADR-0016·plan은 그릴링 시점에 fg-ask 인라인으로 작성됨.
- Divergences: 3건, 전부 plan 미지정 영역의 즉석 결정 — ① Dynamic Workflow 대신 본 세션 직접 실행(#19 add-fg-eco 선례 + fg-run 비용 추정 원칙), ② fg-loop의 README/카탈로그 배치를 fg-next 직후로(오케스트레이터 형제 그룹핑), ③ frontmatter description ~700자 절제(CONCERNS #3의 fg-next 한도 초과 의심 회피).

## 학습
- Do differently next time:
  - **스킬 추가 작업의 ripple 표면은 CONCERNS #2 체크리스트 그대로다 — 두 번째 실증.** 매니페스트 description 2벌·README 양판(헤더 카운트+테이블+산문)·CLAUDE.md 목록, 총 6지점. #19 회고의 "체크리스트로 쓸 것" 지침이 재검증됨; 스킬 추가 plan은 이 6지점을 슬라이스 완료 기준에 박는 것이 맞다.
  - **기둥 완화 차선의 설계 패턴이 정착됐다**: fg-quick(기둥 2 완화, ADR-0003) → fg-next all(게이트 2개 완화, ADR-0010) → fg-loop(기둥 1 완화, ADR-0016) — 전부 "완화 범위를 사전 명시 + ADR로 기록 + 안전 벽 보존" 동형. 다음에 원칙 완화 요청이 오면 이 3요소를 기본 골격으로 그릴링하면 된다(새 ADR로 중복 기록하지 않음 — 결정은 각 ADR에 이미 분산 존재).
  - **Markdown 리포에서 `tdd: on`은 "검증-선행 체크리스트"로 해석한 첫 사례.** 테스트 프레임워크가 없으면 grep/JSON 체크를 편집 전에 고정하는 방식으로 작동했다. 같은 해석이 반복되면 PLAN-FORMAT.md/fg-tdd에 명문화할 후속 후보(이번엔 plan 본문에 해석 각주로만 남김).

## 문서 갱신
- CONTEXT.md 승급: 없음 (goal 계약·한정 재계획·fix-forward의 정의는 ADR-0016이 소유 — 글로서리 오염 방지)
- ADR 추가: 없음(회고에서) — 핵심 결정은 그릴링 시점에 ADR-0016(`.forge/adr/0016-fg-loop-goal-driven-bounded-replan.md`)으로 이미 기록됨
