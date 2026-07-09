# 2026-07-09 — fg-merge 개선 (외부 참조 경고·dropped/ 보존·사소 갭 보정)

## 계획 대비 실행
- 계획대로 된 것:
  - S1 외부 참조 경고 — ADR 재부여 절차에 step 5(merge 유입 non-`.forge/` 파일을 옛 번호로 grep해 warn-only) 추가, 스코핑·warn-only 근거 본문 명시.
  - S2 dropped/ 보존 — "What it integrates"·흐름도·Document impact에 브랜치 `dropped/` → 최상위 `.forge/dropped/` 이동(충돌 `-2`·lazy-create·비-halt) 반영.
  - S3 사소 갭 — 무인자 호출 시 `.forge/branch/` leaf-root 열거(1/多/0 분기)·slash 브랜치 빈 부모 디렉터리 정리 명시.
  - S4 샌드박스 dogfood 3시나리오 전부 PASS, manifest JSON OK, 문서 정합 위반 없음.
- 어긋난 것 (전부 계획이 예견한 정상 분기, divergence 낮음):
  1. 세 요약(frontmatter description·docs/skills.md·CLAUDE.md fg-merge 항목) 미동기화 — 계획의 "어긋나면 동기화, 아니면 그대로" 원칙 적용. 결정적 근거: 기존 통합 대상인 backlog plan folding조차 세 요약 어디에도 없음 → 요약은 exhaustive가 아니라 representative이며 새 동작과 모순 없음(=드리프트 아님).
  2. Dynamic Workflow 대신 직접 실행 — S1~S3가 동일 파일(SKILL.md) 직렬 편집이라 병렬 여지 0, 저위험 문서 작업이라 워크플로우 오버헤드가 이점 없음(fg-run "단일 에이전트로 충분하면 직접" 예외).
  3. fg-merge는 스크립트가 아닌 지시문 → "dogfood"는 코드 테스트가 아니라 실제 git 샌드박스에서 지시하는 기계적 조작(grep/mv/enumerate/rmdir)을 손으로 실행해 지시문의 실행 가능성·정확성을 확인한 것.

## 학습
- 다음에 다르게 할 점:
  - **문서 요약을 무조건 동기화하려 들지 말 것.** frontmatter/docs/CLAUDE.md의 스킬 요약은 representative지 exhaustive가 아니다. 이미 존재하는 동작(예: backlog folding)이 요약에 없다는 사실이, 새 동작을 요약에 안 넣어도 드리프트가 아니라는 판단의 근거가 된다. 새 동작 추가 시 "요약이 새 동작과 *모순*되는가"만 보고, 누락은 드리프트로 취급하지 않는다.
  - **상태 변형 유틸리티는 샌드박스 dogfood가 grep보다 강한 검증**(2026-06-09 e2e 회고 재확인). fg-merge처럼 스크립트가 아닌 지시문도 실제 git 샌드박스에서 지시대로 손으로 조작해봐야 지시문이 실행 가능한지 드러난다.
  - **"타깃 부재 lazy-create를 빠뜨리기 쉽다"는 갭 유형이 반복된다**(같은 e2e 회고 교훈). 이번 dropped/ 이동에도 그대로 적용 — 이동/병합 동작을 명세할 땐 타깃 디렉터리 부재 케이스를 항상 명시할 것.
  - slash 브랜치명(`feat/x`)의 중간 그루핑 디렉터리(`feat/`)를 열거·정리 로직에서 어떻게 다룰지는 앞으로도 반복 이슈 — "leaf-root"(포지 문서를 직접 담은 디렉터리) 개념으로 후보를 좁히고 빈 부모는 별도 정리.

## Doc updates
- CONTEXT.md 승급: none (leaf-root는 SKILL.md에 사는 구현 개념 — 도메인 용어 아님)
- ADR 추가: none (세 변경 모두 ADR-0011 계약 내 보정, warn-only 근거는 SKILL.md 본문에 인라인)
