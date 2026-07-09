# 2026-07-09 — fg-statusline 인디케이터 확장 (task #71): task 번호 `#N` · 모드 인디케이터 `Ⓣ`/`Ⓔ` · git ahead/behind `↑N ↓N`

## Plan vs actual
- What went as planned:
  - 표시 계약(형식)은 그릴링 합의에서 한 글자도 변경 없이 그대로 구현됨. fragment 트윈에 `#N`(plan `<!-- task: N -->` 마커 파싱)·`Ⓣ`(`<!-- tdd: on -->`)·`Ⓔ`(최상위 config.json `eco: true`) 맨끝 세그먼트, full 트윈 `⎇` 세그먼트에 `↑N ↓N`(0·upstream 부재 시 생략).
  - TDD red→green 4에이전트 직렬 워크플로우. 테스트 5종 최종 green(30 / PARITY OK / 7 / 25 / PARITY OK), 설치본 4파일 `~/.claude/` 갱신, 라이브 스모크가 계약과 일치.
- Divergences (전부 저-divergence):
  - **S2∥S3 병렬 가정이 직렬로 굳음** — full 스크립트가 fragment에 위임하므로 S3의 green 게이트(5종 전부)가 S2에 실질 의존. 워크플로우 빌드 시점에 직렬(S1→S2→S3→S4)로 확정(#70과 동일 구조). full→fragment 위임 구조에서는 두 트윈 slice가 개념상 병렬이어도 게이트 의존으로 직렬이 된다 — 다음에 이 구조를 또 다루면 처음부터 직렬로 계획할 것.
  - **테스트 5종 중 wrapper 테스트는 실제 변경 불필요** — fixture에 task 마커가 없고 포맷 무관 케이스뿐이라 "확인만"으로 충족(새 세그먼트 통과는 fragment 테스트가 전이적 커버). 전수 특정 자체는 유효했고, 그중 1종이 무변경으로 판명된 것.
  - **`git rev-list --left-right --count '@{upstream}...HEAD'` 출력 순서는 실측으로 `<behind>\t<ahead>`** — 표시 계약(↑ahead ↓behind)에 맞게 스왑. plan이 "정확한 형태는 구현 시 실측"으로 열어둔 그대로 확정.
  - 기타: S1이 "마커 없는 plan → 번호 생략" 중복 케이스를 `tdd:off`+`eco:false` fixture가 plain 줄을 유지하는 가드로 대체(키 존재만으로 인디케이터 켜는 실수 방지). js Ⓔ 판독은 JSON.parse 1차 + malformed용 정규식 폴백(ADR-0022 패리티). ADR 개정 날짜(2026-07-08 합의일)와 실행 완료(2026-07-09, 자정 경과)의 하루 차이는 의도.

## Learnings
- Do differently next time:
  - **"영향 테스트 전수 grep" 규율이 또 통했다** — 그릴링 시점에 영향 테스트 5종을 grep으로 못박은 덕에 누락 0, 기존 케이스 갱신 누락 없음 교차 확인. 회고 3회 반복 교훈의 재확인. 계속 유지할 것.
  - **글리프는 라이브 튜닝** — 2026-07-02 교훈(텍스트 미리보기는 글리프·폭·색 확정에 부적합)을 다시 적용. 표시 계약에서는 메커니즘만 합의하고 실제 터미널 출력으로 육안 확인. 원문자 글리프(Ⓣ U+24C9 · Ⓔ U+24BA) 선택도 라이브 확인 후 확정.
  - **full→fragment 위임 구조의 slice 의존성** — 위임받는 쪽(full)의 green 게이트가 위임하는 쪽(fragment)에 의존하므로, 두 트윈 slice는 병렬로 보여도 직렬이다. 워크플로우를 처음부터 직렬로 계획하면 조정 비용이 없다.

## Doc updates
- CONTEXT.md promotion: none (표시 형식 확장 — 새 도메인 용어 없음)
- ADR added: none (계약 변경은 기존 ADR-0029 한 줄 개정으로 흡수 — 새 결정 아님)
