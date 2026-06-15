# fg-doctor — 상태·문서 무결성 health check (읽기 전용·검출보고전용·on-demand)

## Status
accepted

## 맥락
harness engineering(walkinglabs/learn-harness-engineering) 5원칙 — Instructions·State·Verification·Scope·Session Lifecycle — 에 forge를 대조하면, forge는 이들을 의식적으로 구현한 드문 케이스다(SKILL.md/CLAUDE.md = Instructions, `.forge/` 계약 = State, ADR-0009 = Verification, 활성 슬롯 1개 = Scope, 4단계 루프+봉인 = Lifecycle). 그러나 가장 약한 고리가 하나 있다 — 리포가 `init.sh` health check로 강조하는 **능동적 무결성 검증**이다.

forge의 상태 계약은 **손으로 편집되는 Markdown 파일**들이라 조용히 깨질 수 있다: 고아 `run.md`(plan 없음), STATUS 필드 손상, slug 페어링 불일치(plan↔STATUS↔retro), half-sealed `done/`, 매니페스트 버전 3곳 drift, README 이중언어 어긋남, CLAUDE.md 스킬 목록 누락. `fg-status`는 현황을 **보고**할 뿐 무결성을 **검증**하지 않는다. 실제로 이번 세션에서 발견된 결함(CLAUDE.md의 fg-statusline 누락)이 정확히 이 부류 — 사람이 우연히 발견했지 자동 검출된 게 아니다.

## 결정
**`fg-doctor`를 루프 밖 읽기 전용 유틸리티로 신설한다.** `.forge/` 상태 계약 무결성과 영속 문서/매니페스트 정합을 검사해 위반을 severity와 함께 보고한다.

- **검출·보고 전용 (읽기 전용).** 자동 수정하지 않는다 — 위반의 "올바른 수정"은 맥락 의존(slug 불일치는 어느 쪽이 정답인지 사람 판단)이고 자동 수정은 손상을 악화시킬 위험이 있다. 보고는 항목별 actionable 수정 안내만 주고, 실제 수정은 사람이 fg-quick/fg-ask로.
- **on-demand 전용.** 다른 스킬이 자동 호출하지 않는다(forge 자동 최소 철학, fg-map 선례).
- **실행 스크립트 없음.** fg-doctor는 대화형 스킬 컨텍스트라 에이전트가 Bash/Grep/Read로 직접 검사한다(fg-status 동형). statusline 같은 비대화형 셸 제약이 없어 별도 bash 스크립트가 불필요.
- **검사 범위는 상태 계약 + 문서/매니페스트 정합 둘 다.** 상태만 검사하면 실제 발견되는 부류(문서 결함)를 놓친다.

## 고려한 대안
- **fg-status 확장** — 거부: fg-status는 "어디까지 했나(진행+다음 단계)", fg-doctor는 "상태가 건강한가(무결성)". 섞으면 "보고+무결성+다음단계" 3책임으로 비대. 단일 책임으로 분리.
- **자동 수정(또는 사람 승인 후 수정, fg-cleanup 패턴)** — 거부: 맥락 의존 수정의 오류 위험 + 읽기 전용 일관성(fg-status·fg-map). actionable 안내로 충분.
- **자동 실행(세션/봉인 시점)** — 거부: forge 자동 최소 철학, fg-map의 offer-not-auto 선례. on-demand.
- **상태 계약만 / 문서만 검사** — 거부: 둘 다 무결성이 중요하고, 실제 발견 결함은 문서 부류였다.
- **실행 스크립트로 구현** — 거부: 대화형 스킬이라 Bash 직접 호출 가능. statusline의 비대화형 제약이 없다.

## Consequences
- 루프 밖 스킬이 12개로(루프 4 + 밖 12 = 총 16).
- 상태 머신을 읽는 스킬이 둘이 된다: fg-status(진행·다음 단계)와 fg-doctor(무결성). 관심사가 달라 의도된 분리지만, `.forge/` 상태 계약이 바뀌면 양쪽 검사/보고를 함께 고려해야 한다.
- 읽기 전용이라 되돌리기 쉽다(스킬 삭제로 충분, 상태 불변).
- dogfooding — fg-doctor가 검출하는 결함(CLAUDE.md 누락 등)을 fg-doctor 자신으로 잡아 고치는 흐름이 가능해진다.
