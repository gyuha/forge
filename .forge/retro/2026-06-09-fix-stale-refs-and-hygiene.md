# 2026-06-09 — 프로젝트 점검: stale 참조·위생 수정 (일괄 승급 2026-06-16)

## Plan vs actual
- What went as planned: 3슬라이스 — S1 forge-prd 처리, S2 fg-map 4-agent 재실행(7문서 HEAD 41c10d7 재생성), S3 `.DS_Store` gitignore.
- Divergences: 1건(경미·범위 내) — S1이 "stale CLAUDE 참조"인 줄 알았으나 실제론 **git-추적 ghost**(working tree에서 삭제됐는데 미커밋, `git status`에 `D forge-prd.md`)였음 → `git rm`까지 필요. plan S1이 "ghost면 git rm" 명시해 둬 범위 내.

## Learnings
- Do differently next time:
  - **"stale 참조"로 보이는 게 실제론 git-추적 ghost(working tree 삭제 미커밋)일 수 있다.** 문서 참조를 고치기 전 `git ls-files`/`git status`로 추적 상태부터 확인하면 "CLAUDE만 고치고 ghost 파일은 남기는" 반쪽 수정을 피한다. 일반화: 파일 참조 정리 작업은 "참조 텍스트"와 "파일의 git 실재" 둘 다 확인할 것 — 계획이 가정한 텍스트/상태가 실제로 그 형태로 존재하는지 슬라이스 작성 전 실측(fg-next-all-skip-retro의 "no-op S4 슬라이스"도 같은 뿌리 — 매니페스트에 없는 텍스트를 고치려 했었음).
  - **코드베이스 지도(`.forge/codebase/`)는 큰 rename/기능 추가 뒤 빠르게 stale해진다**(이번엔 fg-cleanup→fg-done 등). fg-ask가 지도를 연료로 읽으므로, 큰 계약 변경을 봉인한 직후 fg-map 재실행을 루틴으로 고려(fg-done이 봉인 시 비-`.forge/` 변경 + codebase 지도 존재면 fg-map을 제안하는 것도 이 교훈의 자동화).

## Doc updates
- CONTEXT.md promotion: none
- ADR added: none (ADR-0013 "지도 갱신은 fg-map 유틸리티" 원칙 준수, 새 결정 없음)
