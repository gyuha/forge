# 2026-07-16 — fg-merge 기계 코어를 결정론 스크립트로 추출 (AI 없는 CI merge)

## Plan vs actual
- 계획대로 된 것: S1~S5 완주. `forge-merge.{sh,js}` + behavior 34(.sh·.js) + parity 12 전부 green, fg-merge SKILL 스크립트-백킹 재작성, dogfood ADR `260716-16a`. 직접 순차 TDD(트윈 parity·슬라이스 순차라 병렬 부적합).
- Divergences(전부 추적 가능·저-중): (a) **incoming NNNN 처리 결정** — 시범이 표면화, 사용자 승인(충돌 없으면 이동·frozen 충돌 시 halt, cascade 재건 없음). (b) **T2 학습 적용으로 계획 지명 밖 내부 계약 문서 2곳 수정**(FORGE-ROOT:62·ADR-FORMAT:42) — 규칙 변경 정합이라 범위 내. (c) 사용자 선택으로 S1 시범 체크포인트 1회.

## Learnings
- Do differently next time:
  - **대형 TDD/스크립트 작업은 "시범 슬라이스 먼저"가 실효.** S1(테스트+골격)이 ~900줄 커밋 전에 형태·비용을 재고, **NNNN 설계 구멍을 잘못 굳기 전에** 표면화했다. 다음 대형 구현도 exit-code 계약+핵심 동작을 담은 시범 슬라이스로 시작해 나머지를 잇는다.
  - **직전 회고 학습(T2)이 닫힌 고리로 작동함을 확인.** "규칙 변경 시 그 규칙의 소비자를 전수 grep"이 이번엔 `FORGE-ROOT.md:62`·`ADR-FORMAT.md:42`를 잡아 #77이 남긴 전이 상태를 닫았다 — 회고 규율이 실제로 다음 작업의 실수를 사전 차단. 규칙-변경 작업의 DoD에 "소비자 grep"을 명시하는 습관을 유지.
  - **문서 소비자를 두 부류로 나눠 대응**: 내부 계약 문서(FORGE-ROOT·ADR-FORMAT·스킬 — 에이전트가 실행 기준으로 읽음)는 stale하면 오작동(T2 실패 모드)이라 **작업 중 즉시 수정**; 사용자 카탈로그 문서(docs/·README·매니페스트 — 사람이 읽음)는 **배포 규칙이 소유하니 배포 동기로 위임**. 이번에 후자(docs/skills.md·index.html·state-contract·매니페스트 fg-merge 설명)는 다음 배포 대상으로 run.md에 명기.
  - (dual-dispatch 스크립트는 forge-done/status/resolve-root 템플릿을 미러하면 저비용·저위험. parity 테스트가 .sh↔.js 트리 동일성을 강제해 트윈 divergence를 원천 차단.)

## Doc updates
- CONTEXT.md 승급: none
- ADR added: none 추가 (scriptify 결정은 실행 중 생성된 `260716-16a`가 기록; NNNN 처리는 그 ADR+스크립트+테스트의 기계 디테일이라 별도 ADR 불요)
