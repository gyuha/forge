# RUN — README 이중언어 + 매니페스트 설명에 opencode 반영

실행 방식: 워크플로우 없이 직접 실행. 번역 쌍 동시 편집이라 한 사람이 양쪽을 같은 diff로 고쳐야 어긋나지 않는다.

## 슬라이스별 결과
- S1 `README.md` — ✅ 계획대로. 손댄 곳은 6군데로 한정: 태그라인, 공유 계약 문장(+opencode 가이드 링크), 호출 방법 한 줄, 신설 `### opencode` 설치 절, 비교표의 "대상 플랫폼 폭" 셀, 정직한 트레이드오프 불릿.
- S2 `README.ko.md` — ✅ 계획대로. 같은 6군데를 같은 구조로. codex 언급 수가 양쪽 15로 동일하게 유지됨(구조 대칭 확인).
- S3 매니페스트 — ⚠ 계획은 "호스트를 열거하는 문장이 있으면 갱신"이었고, 실제로 **셋 중 하나만** 해당했다. `.codex-plugin/plugin.json`의 `"for Claude Code and Codex"`만 `"for Claude Code, Codex, and opencode"`로 고쳤다. `.claude-plugin/plugin.json`과 `marketplace.json`의 `plugins[].description`은 "for Claude Code"인데 이는 **설치 대상 호스트**를 말하는 것이라 사실이며(opencode는 매니페스트로 설치되지 않는다), `metadata.description`은 루프 정의 태그라인이라 호스트를 넣지 않는 것이 규약이다. 셋 다 손대지 않는 것이 맞다.

## DoD baseline → after
1. `grep -ci opencode README.md`: 0 → 9 ✅
2. `grep -ci opencode README.ko.md`: 0 → 9 ✅
3. codex 언급 수 대칭: 15 = 15 → 15 = 15 ✅
4. 매니페스트 3종 JSON 파싱: OK → OK ✅
5. `release:check` exit 0 · `forge-doctor` 0 errors ✅ (regression guard)
6. 테스트 스위트 21/21 ✅ (regression guard)

## 계획↔실제 차이 (divergence)
- **DoD 6 측정 중 전체 테스트 루프가 한 번 420초 타임아웃**했다. 개별 실행(테스트당 90초 alarm)으로 재측정하니 21개 전부 통과 — 즉 스위트가 깨진 것이 아니라 한 번에 몰아 돌린 복합 명령이 느렸던 것이다. **측정 도구를 측정 대상보다 먼저 의심하라**는 CLAUDE.md의 규칙(경로를 기억으로 짚어 "테스트가 깨졌다"고 오판한 전례)이 그대로 재현됐다. 이후 대량 검증은 항목별 타임아웃을 걸어 돌릴 것.
- S3이 "조건부 갱신"으로 쓰여 있었던 덕에 세 매니페스트 중 하나만 고치는 판단이 계획 안에서 이뤄졌다. 조건 없이 "매니페스트를 갱신하라"였다면 사실인 문장(`for Claude Code`)까지 고쳤을 것이다.
