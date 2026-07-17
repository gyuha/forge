# 2026-07-17 — fg-merge에 opt-in git-merge 모드 추가 (인자 유무 분기)

## Plan vs actual
- **What went as planned**: S1(`skills/fg-merge/SKILL.md` 재작성: 인자-분기·충돌 그자리-정지·스마트 라우팅·기본브랜치 전제·코어 git-free 명시)·S2(자기모순 소비자 6곳 정합)·S3(README 이중언어 + 매니페스트 2곳) 전부 계획대로. 결정 ADR `260717-10a` + ADR-0011 개정 노트는 그릴링 단계에서 생성. 코어 `forge-merge.sh`/`.js` **로직 무변경**(헤더 주석 명료화만). Dynamic Workflow 없이 직접 실행 — 한 작성자가 SKILL↔소비자 정합을 맞추는 게 병렬보다 나은 정합성 작업.
- **Divergences (낮음)**: (1) `forge-merge.js` 헤더가 이미 ".sh 헤더 참조"라 git-free 명료화가 자동 상속 → `.js` 무편집(계획의 "스크립트 주석"은 `.sh`만으로 충족). (2) `fg-drop:68` "fg-drop still does not run git"은 fg-drop 자신에 대한 참인 단정이라 유지 — 완화 대상은 교차참조인 `:93`("same principle as fg-merge not running git")뿐.

## Learnings
- **Do differently next time**: **"does NOT run X" 같은 부정 단정(negative invariant)을 완화할 때는, 그 규칙을 단정하던 소비자 문서가 전부 조용히 자기모순이 된다** — 긍정 규칙 변경(기능 추가)보다 위험하다. 추가는 기존 문장을 그대로 두지만, 부정 단정 완화는 기존 단언 자체를 거짓으로 만들기 때문. 이번엔 `grep -riE "does not run git|git 조작은 안 함|..."`로 6곳(CLAUDE.md·docs/team-workflow·docs/skills·docs/state-contract·fg-drop 교차참조·forge-merge.sh 헤더)을 먼저 세고 "**코어는 여전히 git-free / 대화형 인자모드만 git merge**"의 2-layer로 갈라 서술했다. → 코어 원칙을 완화할 땐, 그 원칙을 단정하는 모든 문장을 grep으로 먼저 열거하고 **완화 경로와 불변 경로를 명시적으로 분리**해 각 소비자를 고친다.
- **grep 결과를 기계적으로 다 고치지 말고 주어를 봐야 한다**: "fg-drop이 git을 안 한다"(참·유지)와 "fg-merge와 같은 원칙"(교차참조·완화)은 같은 grep에 걸리지만 조치가 반대다. 매칭의 주어가 완화된 대상인지 확인하고 선별한다.

## Doc updates
- **CONTEXT.md promotion**: none (새 도메인 용어 없음).
- **ADR added**: none new — 결정 ADR `260717-10a`(+ ADR-0011 개정 노트)는 그릴링 단계에서 이미 생성(이 회고가 아님). "bounded relaxation(코어 불변 + 한 경로만 완화)" 메타패턴은 fg-quick(기둥2)·fg-loop(기둥1) 선례로 이미 확립돼 별도 승급 불필요.
