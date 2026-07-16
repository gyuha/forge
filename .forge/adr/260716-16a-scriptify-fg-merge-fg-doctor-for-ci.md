---
author: gyuha
decided: 2026-07-16
---
# fg-merge·fg-doctor 기계 코어를 결정론 스크립트로 추출 (AI 없는 CI)

## 맥락
forge를 팀에서 쓰려면 브랜치 통합(fg-merge)과 상태 무결성 검사(fg-doctor)가 **AI 없이 CI에서** 돌 수 있어야 한다 — CI는 Claude를 실행하지 않는다. 그런데 이 둘은 forge의 마지막 남은 **AI 전용 스킬**이었다(fg-status는 ADR-0020, fg-done은 ADR-0030에서 이미 결정론 스크립트로 백킹됨). LLM이 긴 산문 스킬을 해석해 `mv`/`sed`를 손으로 여러 번 돌리는 방식은 느리고 CI에서 불가능하다. #77이 ADR ID를 시간기반으로 바꿔 fg-merge의 재번호가 cascade에서 "충돌 시 다음 글자"라는 결정론 규칙이 된 것도, 이제 스크립트화가 자연스러워진 계기다.

## 결정
fg-merge와 fg-doctor의 **기계 부분**을 dual-dispatch 결정론 스크립트로 추출한다(ADR-0022 bash+node 트윈 + behavior·parity 테스트, ADR-0020/0030 패턴):
- **`forge-merge.sh`/`.js`** (이 작업 `forge-merge-script-extract`): 브랜치 root 통합 — 시간ID ADR 이동(충돌→다음 글자)·retro·CONTEXT term 병합·done/backlog fold+task remap·dropped·브랜치 폴더 제거. **gate-first 비파괴**로 in-flight(exit 3)·구조 충돌(CONTEXT 재정의·NNNN 충돌, exit 4)에서 아무것도 안 옮기고 nonzero exit.
- **`forge-doctor.sh`/`.js`** (후속 `forge-doctor-script-extract`): 상태·문서 무결성 검사를 스크립트로, 위반 시 nonzero exit로 CI 게이트.

스킬(fg-merge·fg-doctor)은 **스크립트를 실행하고 exit code로 라우팅**하며, 판단(의미 충돌 대화·수정 안내·핸드오프)만 남긴다. CI는 스크립트를 직접 돌려 nonzero면 build fail → 사람이 로컬에서 해결.

## 트레이드오프 · 경계
- **스크립트는 구조 충돌만 감지한다.** fg-merge의 **ADR 의미 모순**("이 incoming ADR이 기존 결정과 배치되나")은 의미 판단이라 스크립트로 불가 → **PR 리뷰(사람) 또는 로컬 fg-merge(AI)**가 담당. CI가 이를 하는 척하지 않는 것이 정직한 분업. 마찬가지로 fg-doctor는 기계 판정 가능한 검사만 스크립트화하고 의미 정합은 스킬/사람에 남긴다.
- **read-only/비파괴 계약 불변**: fg-doctor는 아무것도 안 고침(ADR-0019), fg-merge는 git 안 돌림·global exemption(config/codebase) 불변(ADR-0011).
- 기각: 통합/검사를 CI가 **자동 커밋**까지 하는 안 — 봇 자격증명·push 루프 복잡성으로 기각(CI는 fail만, 통합·커밋은 사람).

## 결과 (Consequences)
- fg-merge는 이 작업에서 스크립트-백킹됨(`forge-merge.{sh,js}` + behavior 34 + parity 12 테스트). fg-doctor는 후속 `forge-doctor-script-extract`에서 같은 패턴으로 추출 예정 — 그 작업 완료 전까지 fg-doctor는 여전히 AI 전용(계획된 순차 의존).
- CI wiring 예제(GitHub Actions YAML)와 팀 merge 정책 문서는 별도 작업 `team-ci-workflow-merge-policy-docs`가 제공.
- 이 ADR은 `260716-13a`(ID 스킴)에 이은 forge의 두 번째 시간기반 ID로, 같은 날 다른 시(16시)에 조율 없이 `260716-16a`로 민팅됐다 — 스킴의 조율-프리 유일성을 그대로 시연.
