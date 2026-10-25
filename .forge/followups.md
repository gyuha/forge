# Follow-ups

<!-- followup: fu-3e1a8884964b | source: fold-retro-into-seal-4of4 | task: 173 | date: 2026-10-24 | status: open | taken: - -->
- `docs/config-modes.md` 쌍에 `monitorRetention`을 추가하고 키 개수를 일곱으로 맞춘다.
  근거: 페이지가 `monitorRetention`을 다루지 않아 "여섯 키"로 남아 있다.

<!-- followup: fu-a296177faba3 | source: fold-retro-into-seal-4of4 | task: 173 | date: 2026-10-24 | status: open | taken: - -->
- `docs/og-image.png`가 4단계 루프를 그리는지 확인하고 필요하면 다시 만든다.
  근거: 루프가 3단계로 바뀌었지만 공유 미리보기 이미지는 확인하지 않았다.

<!-- followup: fu-9e860205cc53 | source: verify-skill-adoption-1of2 | task: 180 | date: 2026-10-25 | status: open | taken: - -->
- 구동 가능한 앱이 있는 실제 프로젝트에서 세션을 재시작한 뒤 `fg-verify`를 실행해, 생성·자기 증명·갱신이 실제로 동작하는지 확인한다.
  Evidence: forge 리포에는 구동할 앱이 없어 이번 UAT는 문서·카탈로그 정합까지만 확인했다(계획 Non-goals).

<!-- followup: fu-e5194ef221b8 | source: verify-skill-adoption-1of2 | task: 180 | date: 2026-10-25 | status: open | taken: - -->
- Pi의 프로젝트 로컬 스킬 경로를 확인하고, 확인되면 `verify-<app>` 링크 위치를 fg-verify에 추가한다.
  Evidence: ADR `261025-090138`이 Pi를 "경로 미확인"으로 범위에서 뺐다.

<!-- followup: fu-a8902c518a5d | source: verify-skill-adoption-1of2 | task: 180 | date: 2026-10-26 | status: open | taken: - -->
- 스킬 개수·루프 밖 유틸리티 개수·핸드오프 적용 지점 수를 문서에 하드코딩하지 않거나, `skills/*/SKILL.md` 실측과 대조하는 fg-doctor 검사를 둔다.
  Evidence: 이번 작업에서 finder가 대소문자·숫자 리터럴·헤딩 형태를 놓쳐 9곳이 남았고, B18은 HANDOFF·CONTEXT가 함께 낡으면 통과한다.
