# 2026-07-20 — forge-done DEST의 slug 경로 탈출 가드 (#87 적대적 리뷰 fix-forward)

## Plan vs actual
- **계획대로**: S1(slug 가드 — forge-done 두 트윈이 `/`·`\`·`..`·선행 `.` slug를 mutation 전 exit 64로 거부)·S2(테스트 대칭 — merge letter-skip parity, doctor B14 특정-id assert) 명세대로. TDD red→green. 재현됐던 `x/../../../../PWNED` 탈출이 수정 후 두 트윈 차단.
- **Divergences**: 없음(저-divergence). 경로 정규화 대신 문자 denylist는 plan 명시대로(bash realpath 비이식성 회피 + sealed-id 제약과 결합해 DEST 내부 보장).

## Learnings
- **Do differently next time (핵심)**:
  1. **조립된 경로는 모든 조각을 방어하라 — 티켓의 한 조각만이 아니라.** #87은 `done/<sealed-id>-<slug>/`의 `sealed-id`만 검증하고 `slug`를 남겼는데, 나는 원 plan의 DoD("최종 DEST가 done/ 내부")에 있던 DEST-containment 검사를 "엄격 정규식이 포함하니 dead code"라며 뺐다. 그 논리는 **한 조각만 봤을 때만 참**이었다 — slug라는 두 번째 미검증 조각이 같은 경로로 탈출했다. 내가 뺀 그 검사가 정확히 backstop이었다. → 경로/명령/식별자를 조립할 때 **모든 사용자-영향 입력**을 열거하고 각각 가드했는지 확인하라.
  2. **자기가 쓴 테스트는 자기 맹점을 체계적으로 못 잡는다.** #87의 traversal 테스트는 전부 valid slug + bad sealed-id라, "경로 탈출 방어됨"이라는 거짓 확신을 줬다(#86 "parity ≠ 정확성"의 새 형태 — both-wrong이 아니라 both-narrow). 방어를 주장하는 테스트는 방어 대상의 **각 벡터**를 독립적으로 쳐야 한다.
- **Keep(확인된 것)**: 적대적 리뷰(결과가 틀렸다 가정·6렌즈 독립·서브에이전트가 실제로 스크립트를 실행해 익스플로잇 재현)가 TDD와 live fg-doctor가 둘 다 놓친 MAJOR를 잡았고, 보안·요구사항 두 렌즈가 **독립적으로 같은 결함에 수렴**했다. 보안/정확성 변경엔 적대 리뷰가 명백히 값을 한다.

## Doc updates
- **CONTEXT.md promotion**: none (새 도메인 용어 없음).
- **ADR added**: none — 위 학습은 되돌리기 쉬운 코딩/테스트 규율이라 3게이트 미달(retro 종착).
- **Note (승급 안 함, 별도 그릴링 사안)**: 이번 결함은 **무인 goal 드라이브(`/fg-next`)가 auto-skip-retro로 #87을 봉인**한 뒤, 사용자가 **명시적으로 요청한 적대적 리뷰**라야 드러났다. 이는 ADR-0018(드라이브는 리뷰 항상 skip)·ADR-0010과의 긴장 — "보안-민감 변경은 드라이브 중에도 리뷰를 강제/권고"가 검토 가치가 있으나, 기존 ADR과 배치되어 unilateral 승급 대신 별도 fg-ask 그릴링 대상으로만 기록.
- **Follow-up**: forge-merge/forge-status 등 다른 스크립트의 slug 경유 경로는 리포-내부 sealed 데이터 출처라 이번 리뷰가 미지적 — 필요 시 별도 점검 여지(현재 통증 없음, 억지 생성 금지).
