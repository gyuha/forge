# 2026-06-04 — fg-map 스킬 추가 (코드베이스 매핑으로 context rot 감소)

> 이 작업의 휘발 plan/run/STATUS는 fg-done 봉인 없이 폐기되어 `.forge/done/` 항목이 없다 — 이 회고는 봉인 장부 밖의 orphan 기록이다(2026-06-04-fg-ask-adr-path-fix.md와 같은 관례).

## Plan vs actual
- What went as planned:
  - 4슬라이스(S1 SKILL.md / S2 fg-ask 훅 / S3 매니페스트 / S4 README 영·한) 전부 완료. Dynamic Workflow 없이 본 세션 직접 처리 — 계획에서 합의된 방식대로(Markdown/JSON 편집, S1이 나머지의 전제).
  - S2는 fg-ask의 "Forge integration (minimal)" 섹션에만 1줄 추가, verbatim 본문(1~90줄)은 git diff 기준 무손상.
- Divergences:
  - **매니페스트의 두 description을 다르게 다뤘다.** `marketplace.json`의 `metadata.description`은 루프(ask→execute→retro→cleanup) 태그라인이라 fg-map(루프 밖 유틸리티)을 넣지 않았고, `plugins[0].description`에만 "Four→Five skills"로 fg-map을 반영했다. `plugin.json`도 `description` 한 곳만 갱신(skills 자동 탐색이라 별도 목록 필드 없음).
  - 계획 발산이라기보다 계획에 없던 세부 결정. 재그릴링이 필요한 수준은 아니었다.

## Learnings
- Do differently next time:
  - **매니페스트 description 역할 구분을 의식하고 작업한다.** `metadata.description` = 루프를 정의하는 한 줄 태그라인(루프 밖 유틸리티는 넣지 않음), `plugins[].description` = 전체 스킬 목록을 담는 설명. 루프 밖 스킬(fg-map류)을 추가할 때 metadata에 끼우면 루프 정의가 흐려진다. → CLAUDE.md 배포 규칙에 한 줄로 승급(아래 Doc updates 참조).
  - **설치가 전제인 산출물(스킬·플러그인)은 DoD를 '작성 완료'와 '실 동작 검증'으로 나눈다.** 이번 계획의 Definition of Done은 "실제 실행 시 docs/codebase 7문서 생성"까지 적었지만, 실 검증은 main push→설치가 필요해 범위 밖으로 뒀다 — DoD와 실제 검증 범위가 어긋났다. 다음엔 계획 단계에서 후자를 배포 후 별도 작업으로 명시한다.
  - (미검증으로 남은 것) fg-map 실 실행 → docs/codebase 7문서 생성 여부, fg-ask의 `last_mapped_commit` 신선도 판단 동작. 둘 다 배포 후 `/forge:fg-map`을 한 번 돌려 확인해야 한다.

## Doc updates
- CONTEXT.md promotion: none (도메인 용어 아님)
- ADR added: none (되돌리기 어려운 결정 아님 — 신규 스킬 추가는 가역적)
- CLAUDE.md: 배포 규칙에 매니페스트 두 description의 역할 구분 한 줄 추가
