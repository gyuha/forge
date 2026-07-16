# 2026-07-16 — ADR ID 시간기반 전환 + provenance + fg-ask 트리아지 읽기

## Plan vs actual
- 계획대로 된 것: DoD 1~5 전부 통과. ADR-FORMAT(시간ID+author/decided+grandfather)·fg-ask(민팅+트리아지)·fg-cleanup(공존) 편집 + 새 스킴 dogfood ADR `260716-13a`. Dynamic Workflow 없이 직접 실행(프로즈 편집 규모).
- Divergences: 계획↔실제 자체는 낮음. 그러나 **봉인 전 적대적 리뷰(fg-adversarial-review)가 계획이 놓친 소비자를 잡음** — 3건 제자리 수정(T1·T2·T4), 1건 #79 이관(T3). 변경 파일이 계획의 3개+ADR에서 `FORGE-ROOT.md`·`ADR-0011`까지 5개+ADR로 늘어남. 실제 결함은 "계획대로 안 됨"이 아니라 **"규칙을 바꾸며 그 규칙의 소비자 전수를 안 찾은 것"**이었다.

## Learnings
- Do differently next time:
  - **규칙(rule) 변경 작업은 "그 규칙을 grep"으로 소비자를 전수 조사해 DoD에 넣어라 — 형식 문서만 지명하면 사각지대가 남는다.** 이번엔 ADR 채번 규칙을 바꾸며 ADR-FORMAT만 잡고, 같은 규칙을 재진술하는 **단일 정의 문서 `FORGE-ROOT.md`(fg-run 소유)**·검증기 `fg-doctor`·통합기 `fg-merge`·핸드오프 문구를 놓쳤다. 기능 추가와 달리 규칙 변경은 파급 소비자가 코드 전역에 흩어진다. 후속 규칙-변경 작업(#78/#79)의 fg-ask는 "이 규칙을 참조·재진술하는 모든 곳 grep"을 명시 DoD로 넣을 것.
  - **저-divergence라도 "규칙 변경" 작업이면 봉인 전 적대적 리뷰가 값을 한다.** 단발 UAT(문서 구조 grep)는 T2 같은 **교차-문서 모순**을 원리상 못 잡는다 — 리뷰의 misread-requirements/where-it-fails 렌즈가 정확히 그걸 팠다. forge-meta 규칙 변경엔 리뷰를 기본 고려.
  - (반박된 findings는 `.forge/review.md`에 보존·아카이브 — hour vs 초 정밀도는 hour+suffix가 방어 가능으로 재확인, date 명령 미지정·YAML 인용·author=committer blur·ADR-0011 supersede는 과대/범위밖/cosmetic으로 기각.)

## Doc updates
- CONTEXT.md 승급: none (ID 스킴·provenance는 ADR-FORMAT/fg-ask 소유 구현 개념, 글로서리 대상 아님)
- ADR added: none (스킴 결정은 실행 중 생성된 `260716-13a`가 이미 기록; 리뷰 반영 T2는 그 ADR의 "ADR-0011 부분 개정" 노트 + FORGE-ROOT 갱신으로 흡수 — 새 결정 아님)
