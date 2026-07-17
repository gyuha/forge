---
author: gyuha
decided: 2026-07-17
---
# fg-merge에 opt-in git-merge 모드(인자 유무 분기) — 코어 스크립트·CI는 git-free 유지

## 맥락
ADR-0011은 "통합은 git merge 뒤 fg-merge가"로 2-트랙(코드=`git merge`, forge 문서=`fg-merge`)을 정했고, fg-merge가 git을 **안 돌리는 것**이 핵심이었다. 이유: (1) fg-merge는 네임스페이스된 `.forge/branch/<branch>/`만 만져 **구조적으로 충돌 0** → 결정론 스크립트로 CI에서 AI 없이 돌 수 있음(ADR `260716-16a`), (2) `git merge`의 코드 충돌 해소는 사람 판단 영역.

그러나 대화형 사용에서 `git merge <branch>` → `fg-merge <branch>`의 **두 단계가 번거롭다**는 실사용 고통이 있었다. 편의를 위해 fg-merge가 git merge까지 해주길 원한다.

## 결정
**fg-merge 대화형 스킬에 인자 유무로 분기하는 opt-in git-merge 모드를 둔다. 코어 결정론 스크립트(`forge-merge.sh`/`.js`)와 CI 경로는 git-free 그대로다.**

- `fg-merge` (인자 없음) → **통합만** (현행 불변: 브랜치 루트 자동 해석 후 git-free 스크립트로 통합).
- `fg-merge <branch>` → 스킬이 **`git merge <branch>`를 먼저 실행**한 뒤 그 브랜치 루트를 통합. git merge는 **스킬 계층(Bash 오케스트레이션)에서만** — 코어 스크립트는 호출만 받고 여전히 git을 안 돌린다.
- **충돌 처리**: git merge가 소스 충돌을 내면 **그 자리에 남기고 통합 없이 멈춤** — "충돌 해소·commit 후 `fg-merge`(무인자)로 통합" 안내. 통합은 절대 더럽거나 충돌 상태인 트리에서 돌지 않는다는 불변식 유지.
- **커밋**: 평범한 `git merge`(자동 merge 커밋)만 하고, 통합 변경분은 현행처럼 **미커밋으로 남겨 commit을 안내**한다 — fg-merge는 통합을 자동 커밋하지 않는다.
- **스마트 라우팅**: `<branch>`가 이미 merge됐으면("already up to date") 그대로 통합; git ref가 없지만(PR 후 삭제 등) `.forge/branch/<branch>/` 폴더가 있으면 git 건너뛰고 통합-only + 안내; 둘 다 없으면 에러.
- **전제**: git-merge 모드는 **기본 브랜치에서만**(통합 대상이 최상위 `.forge/`).

## 트레이드오프 / 근거
- **비대칭 유지가 핵심**: git을 스킬 계층에만 두어 코어 스크립트의 git-free·CI-safe 계약을 안 깬다(ADR `260716-16a` 불변). CI는 자기 merge를 하고 `forge-merge.sh`를 직접 부르므로 **무영향**.
- **`fg-merge <branch>` 의미 변경**: 기존엔 인자가 "통합할 브랜치 루트 선택자"였는데 이제 "git merge 트리거"를 겸한다. 스마트 라우팅이 already-merged/deleted-branch를 흡수해 기존 "손 merge 후 `fg-merge <branch>`" 습관도 안 깨진다(중복 merge는 no-op).
- **git-abstinence 경계 완화**: fg-merge가 이제 (인자 모드에서) git merge를 돌린다 — ADR-0011의 "does NOT run git"을 **대화형 편의 경로에 한해** 완화. 단 커밋은 여전히 안 함(merge 커밋은 git이, 통합은 미커밋 리마인드).

## 결과 (Consequences)
- `skills/fg-merge/SKILL.md`가 인자-분기·충돌-정지·스마트-라우팅·기본브랜치-전제·코어-git-free를 기술.
- ADR-0011에 개정 노트(이 ADR로 대화형 경로 완화) 추가.
- 소비자 문서 동기화: `CLAUDE.md`·`docs/team-workflow.md`·`docs/skills.md`·`docs/state-contract.md`·`fg-drop` 교차참조·README(양)·매니페스트.
- `fg-drop`의 "fg-merge not running git과 같은 원칙" 교차참조는 자기모순이 되므로 완화(fg-drop은 여전히 git 안 돌림; fg-merge의 opt-in 모드는 예외).
- 코어 `forge-merge.sh`/`.js`·테스트 트윈은 **불변**(스크립트 로직 변경 없음 → 이 작업은 TDD off).

## 고려한 대안
- **기본 동작 교체**(`fg-merge`가 항상 git merge). 거부: 이미 손-merge 후 통합만 하려는 경로·CI 멘탈모델을 깨고, 삭제된 브랜치 통합이 막힘.
- **별도 스킬(fg-land)**. 거부: 스킬 1개 추가 = 카탈로그·매니페스트·이중언어 유지비. 인자 분기로 충분.
- **`git merge --no-commit` + 한 커밋**. 거부: 'merge 진행중'이라는 새 상태 도입, 현행 미커밋-리마인드 대비 덜 수술적.
- **abort-on-conflict**. 거부: 사용자가 같은 충돌을 다시 만들려 merge를 재실행해야 함 — 진짜 merge 작업을 버림.
