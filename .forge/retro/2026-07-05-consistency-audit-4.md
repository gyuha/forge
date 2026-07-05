# 2026-07-05 — 4차 정합 감사(전 스킬 전수 + 핫스팟 가중) + 기계적 수정

## Plan vs actual
- What went as planned: 기계적 전수 체크(매니페스트 JSON·버전 3곳·SKILL.md `name:` 18개·README 이중언어 토큰 대조·테스트 스크립트 5종)와 핫스팟 4개 계약면(DRIVE.md 배선·ask.md 4자 마커·이슈 연동 봉인 규칙·statusline 게이팅) 리뷰가 계획대로 완료됐다. Definition of Done(발견 전 항목 처리 + 재검증 green + 감사 범위 밖 변경 없음) 충족.
- Divergences:
  - **subagent 팬아웃 환경 실패**: 계획은 팬아웃을 전제했으나 로컬 pane 생성이 `fork failed: Device not configured`로 반복 실패. 살아 있는 subagent도 확보 안 됨 → S2/S3를 deterministic grep/파서 + 필요한 파일 읽기로 메인 세션에서 완료. 감사 자체는 읽기 전용이라 결과 품질에 영향 없었다.
  - **fg-doctor는 read-only 리포트**라 계획 문구 "fg-doctor 체크 목록 실행"을 그대로 수행할 수 없었다 → 동일 계약을 따르는 deterministic 스크립트로 검사를 대체했다.
  - **S0 사전 커밋 불필요**: 시작 시 `git status` 깨끗, task #64·#65 결과물이 이미 최근 커밋에 포함 → 추가 커밋 없이 진행.

## Learnings
- Do differently next time:
  - **감사·리뷰류 계획에 "팬아웃 실패 시 deterministic 스크립트 폴백"을 기본 대비책으로 명시하라.** 이 환경에서 subagent pane 생성이 `fork failed: Device not configured`로 실패하는 사례가 있다. 읽기 전용 정합 감사는 grep/파서/파일 확인으로 메인 세션에서 동등하게 수행 가능하므로, 팬아웃은 "가능하면"이지 하드 전제가 아니다.
  - **봉인된 done/ 아카이브도 손상된다 — 감사 범위에 done plan↔STATUS↔run slug pairing을 항상 포함하라.** 이번에 `.forge/done/2026-06-17-fg-ask-refine-pending-plan/plan.md`가 같은 폴더의 STATUS/run과 다른 작업(`fg-status-deterministic-script`)의 plan 본문을 담고 있었다(slug pairing 깨짐). "단일 정의가 본문과 갈라지는 게 이 리포의 반복 실패 모드"(3차 회고)가 done 아카이브에서도 재확인됐다. 원본 plan은 git 이력에 없어 완전 복구원이 없었고, slug·task·title·goal·slice 정합을 회복하는 최소 plan으로 복원했다. 완전 복구원이 없는 아카이브 손상은 "최소 정합 복원 + 회고에 근거 기록"이 현실적 처리다.
  - 레거시 done plan 중 `task:` marker 없는 파일은 synthetic 검사에서 warning처럼 보이나, fg-doctor 계약상 `task:` marker는 backlog 필수·done은 uniqueness 대상이라 수정 대상이 아니다 — 감사 시 이 경계를 혼동하지 말 것.

## Doc updates
- CONTEXT.md promotion: none (신규 도메인 용어 없음; `.forge/CONTEXT.md` 부재)
- ADR added: none (감사는 리뷰지 되돌리기 어려운 설계 결정이 아님 — 승급 3조건 미충족)
