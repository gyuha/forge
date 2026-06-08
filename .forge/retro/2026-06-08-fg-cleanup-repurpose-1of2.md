# 2026-06-08 — fg-cleanup → fg-done 개명 (part 1/2)

## 계획 대비 실제
- 계획대로 된 것: 5슬라이스 전부 완료. 디렉터리 `git mv fg-cleanup→fg-done`, 8개 스킬·CLAUDE.md·README 양 언어·plugin.json의 스킬명 참조를 fg-done으로, 트리거 발화를 새 트리거(`작업 완료`/`봉인`)로. 스킬 자동탐색 10개(fg-done 존재·fg-cleanup 부재), JSON 유효, 역사 기록(retro/done/CHANGELOG/ADR 0002·0003·0009/codebase) 미변경 — 전부 의도대로.
- Divergences: **ADR-0012 내부 모순을 실행 중 발견·해소**. 결정 항목은 "fg-done이 `forge cleanup` alias 흡수", 트레이드오프·옵션 ㄱ는 "`forge cleanup` → 신규 fg-cleanup". 같은 발화를 양쪽에 줄 수 없어, 옵션 ㄱ(사용자 실제 결정)로 정리: fg-done alias에서 `forge cleanup` 제외, ADR-0012 결정 항목 수정. 슬라이스 작업 자체는 계획대로였고 divergence는 이 한 점.

## 학습
- Do differently next time:
  - **ADR를 작성할 때 결정(Decision) 항목과 트레이드오프 항목의 정합을 교차검증하라.** 같은 세션 그릴링에서 옵션 ㄱ를 확정했는데도, ADR-0012 본문을 쓸 때 결정 항목이 트리거 귀속을 트레이드오프와 반대로 적었다(=`forge cleanup`을 양쪽에 부여). 그릴링 합의와 ADR 본문은 따로 움직일 수 있으니, ADR 작성 직후 "결정 ↔ 트레이드오프 ↔ 고려한 대안"이 서로 모순 없는지 한 번 훑을 것. 다행히 실행 중 발견했지만, 못 봤으면 part 2에서 트리거 충돌로 터졌을 것.
  - **개명 sweep은 "스킬명"과 "stage/도메인 단어"를 구분해서 치환하라.** `fg-cleanup`(스킬 식별자)은 `fg-done`으로 전량 치환했지만, 루프 ④의 stage 단어 `cleanup`/`정리`(예: "ask→execute→retro→cleanup", marketplace description의 "cleanup seals the task")는 **유지**했다. `cleanup`을 무분별 일괄치환했으면 루프 단계의 의미 서술까지 깨졌을 것. 토큰 경계(`fg-cleanup` vs `cleanup`)로 sed 범위를 좁힌 게 안전판이 됐다.

## 미해소 후속
- **part 2(#12)가 곧바로 메워야 할 상태**: part 1이 `forge cleanup` 발화를 fg-done에서 비워뒀으므로, part 2 전까지 `forge cleanup`은 미귀속이다. 신규 fg-cleanup(ADR 은퇴)이 이 트리거를 가져가면 해소된다 — soft order(part1→part2)의 실질 이유. (이미 fg-next all 드라이브가 #12로 이어질 예정)

## 문서 갱신
- CONTEXT.md 승급: 없음 (도메인 용어 없음)
- ADR 추가: 없음 (ADR-0012는 신규가 아니라 실행 중 모순 수정 — 결정 항목의 `forge cleanup` 귀속을 옵션 ㄱ에 맞게 정정)
