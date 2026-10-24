<!-- auto-retro: fg-done all -->
# 2026-10-24 — 회고를 봉인에 흡수 ④: README·docs·도움말의 3단계 루프 반영

## Plan vs actual
- What went as planned: 루프 단계 문구 38→0, 개수 문구 10→0, docs 빌드·다크모드 명암비·자산·ADR 링크 확인.
- Divergences:
  - 위임한 docs 작업이 탐색 목록에 없던 config-modes·codex·opencode·pi·index 쌍과 VitePress 설정까지 고쳐야 했다.
  - 스킬 본문 6곳의 4단계 표기와 훅 안내문 잔재도 정리.
  - config-modes의 "여섯 키" 수정은 페이지가 monitorRetention을 다루지 않아 되돌림(후속 fu-3e1a8884964b). og-image는 미확인(후속 fu-a296177faba3).

## Learnings
- Do differently next time: 루프 단계 문구를 찾을 때 문서 목록을 손으로 정하지 말고 리포 전체를 grep한 결과를 영향 위치로 삼는다. 이미지 자산(og-image)은 텍스트 grep에 잡히지 않으므로 따로 확인 항목에 넣는다.

## Doc updates
- 미검토(자동 회고)
- CONTEXT.md promotion: none
- ADR added: none
