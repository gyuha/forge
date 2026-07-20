# 2026-07-19 — ADR·done·retro 명명을 초 단위 시각(YYMMDD-HHMMSS)으로 통일

> 이 회고 파일 자체가 신 명명 스킴의 **첫 dogfood**다(파일명 `260719-195917-…`, bare).

## Plan vs actual
- **What went as planned**: S1(형식 문서)·S2(forge-done/doctor/merge 스크립트, TDD)·S3(문서 정합 sweep) 3슬라이스 구조 그대로. forge-status는 STATUS 날짜 필드를 읽어 "무영향"으로 간주. grandfather(무손실)·3형식 공존. 스킴 자체는 계획대로 착지.
- **Divergences (중간 — 전부 구현 버그 발견, plan 구조는 불변)**: 구현 중/리뷰 중 **버그 6건**이 드러남 — TDD 3건(forge-doctor.js B14 미동기, `[a-z]*` glob 최소-1글자, parity 플래키) + 내 적대적 리뷰 1건(forge-status done-행 `${name:0:10}` dirname 파싱) + Codex 2건(retired ID 비대칭, `--sealed-id` 경로 미검증 → #87 fix-forward).

## Learnings
- **Do differently next time (핵심)**:
  1. **parity ≠ 정확성**: dual-dispatch(.sh/.js) parity 테스트는 **쌍-일치**만 보장한다. 양 트윈이 **동일하게 틀리면**(both-wrong) parity는 통과하며 버그를 숨긴다 — forge-status `.slice(0,10)`가 정확히 그랬고, forge-status엔 **behavior 테스트가 아예 없어** 값-검증 자체가 부재했다. → 각 스크립트는 parity 외에 **값을 단언하는 behavior 테스트**를 가져야 한다. (후속 아이디어: fg-doctor가 `*.test.sh` 없이 `*.parity.test.sh`만 있는 스크립트를 경고하는 체크.)
  2. **고정폭 명명 형식 변경 = 위치-기반 파싱 전수 점검**: 형식의 **폭이 바뀌면**(`YYYY-MM-DD` 10자 → `YYMMDD-HHMMSS` 13자) `:0:10`·`.slice(0,10)`·`${name:11}` 같은 "날짜를 인덱스로" 쓰는 코드가 조용히 깨진다. 규칙 소비자 grep(T2)에 더해 **위치-슬라이스·고정폭 정규식**을 별도로 grep하라. 가능하면 위치 파싱 대신 **필드(STATUS)에서 값을 읽어** format-agnostic하게.
  3. **새 ID 형식 추가 시 모든 가드를 대칭으로**: 구 NNNN 경로는 collision·dup 검사에서 `adr/retired/`를 포함하는데 신 시간ID 경로는 안 해서 유일성 불변식이 깨졌다(Codex 발견). 형식별 코드 경로가 갈릴 때 **한쪽에만 있는 가드(retired 포함·collision·dup)**가 버그의 서식지 — 새 경로는 기존 경로의 가드를 전수 미러링하라.
  4. **bash glob `[a-z]*`는 "최소 1글자"**(`[a-z]`+`*`)라 optional-letter가 아니다. bare(글자 없는) 토큰엔 별도 글로브가 필요. regex `[a-z]?`(.js)와의 비대칭이 버그를 노출했다.
- **Keep(확인된 것)**: TDD가 실 버그 3건을 실행 전에 잡았고, 층위 리뷰(자체 집중 리뷰 + Codex 외부 리뷰)가 TDD·서로가 놓친 다른 클래스를 각각 잡았다 — 핵심 스킴 변경엔 TDD + 이중 적대 리뷰가 값을 한다.

## Doc updates
- **CONTEXT.md promotion**: none (새 도메인 용어 없음).
- **ADR added**: none — 위 학습들은 되돌리기 쉬운 **테스트/구현 규율**이라 3게이트 미달(retro 종착). 스킴 결정 ADR `260719-161701`은 그릴링에서 이미 생성.
- **Follow-up**: Codex 2×[high]는 `time-precise-naming-fix`(#87, fix-forward) — #86 봉인 후 fg-run. "parity-only 스크립트 경고" doctor 체크는 아이디어로만 기록(별도 fg-ask 대상 여지).
