# 2026-07-16 — fg-doctor 검사를 결정론 스크립트로 추출 (CI 게이트) + 고아 브랜치 + T3

## Plan vs actual
- 계획대로 된 것: `forge-doctor.{sh,js}` + behavior 26(.sh·.js) + parity 4 전부 green, fg-doctor SKILL 스크립트-백킹 재작성(read-only 계약 불변), A8 고아 브랜치·T3 두-형식 B14 포함. #78 dual-dispatch 패턴 미러라 시범 없이 전체 구현.
- Divergences(저-divergence·TDD 정상): TDD/parity가 `.sh` 버그 2건을 잡아 수정 — B9 `[ -f ]` 가드 누락, B8 jver 단일라인 JSON 다중 `"version"` 오추출. `set -u`+`→` 인접 변수 `${}` 브레이스.

## Learnings
- Do differently next time:
  - **체커(checker) 스크립트는 parity(독립 구현 교차검증)가 behavior 테스트의 느슨한 단언을 보완한다.** B8 버그: behavior 테스트가 "drift finding이 떴다"만 assert하고 *어느 버전 번호인지*는 안 봐서 통과했는데, parity(.sh↔.js 출력 정확 비교)가 불일치를 잡았다. **교훈 두 개**: (1) dual-dispatch 스크립트는 parity 테스트가 필수 안전망 — 한쪽 구현의 미묘한 버그를 다른 쪽이 드러낸다. (2) behavior 픽스처는 "finding이 발생했다"가 아니라 **구체적 출력 내용**을 단언해야 이런 버그를 자체적으로도 잡는다. 향후 forge 스크립트 개발에 적용.
  - **패턴 한 번 확립 → 미러**: #78에서 검증된 dual-dispatch(sh+js+behavior+parity, gate-first/exit-code) 패턴 덕에 #79는 시범 슬라이스 없이 전체 구현 직행. 대칭 작업은 앞 작업의 산출물을 템플릿으로.
  - **bash gotcha**: `set -u`에서 멀티바이트 문자(`→`)에 인접한 `$var`는 변수명 경계가 모호해져 unbound 오류 → `${var}` 중괄호로 명시. 스크립트 메시지에 유니코드 화살표를 쓸 때 주의.
  - **T2 학습(소비자 grep) 계속 적용**: fg-doctor 동작 변경의 stale 내부 소비자를 grep(없음 확인), 사용자 카탈로그(docs/·README·매니페스트)는 배포 동기로 위임 — #78과 동일 분업.

## Doc updates
- CONTEXT.md 승급: none
- ADR added: none (fg-merge·fg-doctor 스크립트화 결정은 #78의 `260716-16a`가 공유 기록, #79는 참조)
