# 브랜치별 forge 루트 격리 + fg-merge 통합

## Status
accepted

## 맥락
여러 git 브랜치(worktree 포함)로 동시 작업하면 `.forge/`가 세 가지로 충돌·섞인다: (1) **ADR/task 번호 충돌** — 브랜치마다 `max+1`로 번호를 잡아 같은 번호를 재사용(ADR-0005 단조번호·ADR 순차번호가 병렬 브랜치에서 깨짐), (2) **CONTEXT.md 동시 편집** — 단일 영속 파일의 git 머지 충돌, (3) **휘발 상태 섞임** — 한 작업 디렉터리에서 `git checkout`으로 브랜치를 갈아탈 때 gitignored `plan/run/STATUS/done`이 브랜치 간에 잔류·혼입. (1)(2)는 git이 추적하는 영속 문서의 머지 문제, (3)은 작업 디렉터리 공유 문제다.

## 결정
**기본 브랜치가 아닌 브랜치는 forge 상태를 `.forge/branch/<branch>/` 아래에서 운영하고, `fg-merge` 명령으로 그 내용을 `.forge/`에 통합한다.**

- **forge 루트 해석(공통 규약, 한 곳 정의 → 모든 스킬 참조).** 현재 브랜치를 감지(`git rev-parse --abbrev-ref HEAD`)해 기본 브랜치(`config.json`의 `defaultBranch`, 없으면 `main`)면 `.forge/`를, 아니면 `.forge/branch/<branch>/`를 forge 루트로 쓴다. 슬래시 브랜치명은 중첩 디렉터리로 둔다(`feature/x` → `.forge/branch/feature/x/`). detached HEAD·비-git이면 `.forge/`로 폴백하고 한 줄 경고.
- **브랜치 루트 = 완전한 미니루트, git 추적.** `.forge/branch/<branch>/`는 휘발 상태(plan/run/STATUS/backlog/executed/done)와 브랜치가 만든 새 영속 문서(adr/retro/CONTEXT)를 **모두** 담고, **git이 추적**한다(`.gitignore`에 `!.forge/branch/`). 경로가 브랜치별로 쪼개져 **두 브랜치가 같은 파일을 건드리지 않으므로 git merge 충돌이 원천 차단**된다.
- **전역 예외 두 개 — `.forge/config.json`과 `.forge/codebase/`는 브랜치 루트로 해석하지 않고 항상 최상위 `.forge/`에 둔다.** (1) config는 `defaultBranch`를 담는데, 루트 해석 규칙 자체가 *먼저* 이걸 읽어야 해서 브랜치-로컬이면 부트스트랩 역설이 생긴다(+`tdd`는 프로젝트 전역 설정). (2) codebase 지도는 공유 참조 연료라, 브랜치-로컬로 두면 갓 만든 브랜치의 지도가 비어 fg-ask가 못 읽는다. 따라서 fg-tdd/fg-map은 전역 경로 그대로가 옳고(고치지 말 것), fg-merge도 이 둘은 통합하지 않는다.
- **통합은 git merge 뒤 fg-merge가.** `git merge feature → main`이 네임스페이스 폴더 `.forge/branch/feature/`를 충돌 없이 가져온 **다음**, `fg-merge feature`가 main에서 그 폴더를 읽어 `.forge/`로 통합한다: ADR 번호를 main의 다음 빈 번호로 **재부여**하고 교차참조를 갱신, retro 파일 이동(파일명 충돌 시 구분), CONTEXT 용어 단위 병합, done 이력 합침, 그 뒤 브랜치 폴더 제거. **안전한 기계적 작업은 자동, 진짜 충돌(용어 재정의·결정 모순)에서만 멈춰 사람에게 확인**(머지 시점의 mini fg-learn).

## 결정 근거 / 트레이드오프
- **번호 충돌을 생성→머지 시점으로 미룸.** 충돌의 근본 원인은 "생성 시 `max+1`"이다. fg-merge가 통합 시점에 번호를 재부여하면 병렬 브랜치가 같은 번호를 잡아도 결정적으로 해소된다.
- **git 충돌 0(네임스페이스 격리).** 추적하되 경로가 겹치지 않으므로 git merge는 폴더를 그냥 더한다. 브랜치 문서가 커밋·PR에 함께 남아 가시성도 유지.
- **2-트랙 통합.** 코드는 git merge로, forge 문서는 fg-merge로 통합된다 — 단계가 둘로 늘지만 각자 단순하고 충돌이 없다.
- **비대칭(의도).** 기본 브랜치의 휘발 상태는 지금처럼 gitignored, 브랜치 루트는 통째로 추적된다. 브랜치선 plan/run/STATUS가 커밋되는 비대칭을 감수하는 대신, 충돌 차단과 PR 가시성을 얻는다.
- **침습성.** 모든 루프 스킬(ask/run/learn/cleanup/status/next/quick)이 "forge 루트 해석"을 거쳐야 한다 — forge에서 가장 큰 상태 계약 변경이라 별도 part로 봉인한다.

## 고려한 대안
- **worktree만 권장(새 기계장치 0)** — 휘발 섞임(3)은 풀지만 추적 문서 충돌(1)(2)은 못 푼다. 거부: 사용자의 핵심 고통이 번호·CONTEXT 충돌이라 불충분.
- **휘발 상태만 격리** — (3)만 풀고 (1)(2) 잔존. 거부: fg-merge의 가치가 사라짐.
- **`.forge/branch/` gitignore(완전 분리)** — git 충돌은 막으나 브랜치 문서가 커밋·PR에 안 남고 worktree 제거 시 유실 위험. 거부: 추적이 가시성·안전 면에서 우월.
- **충돌-방지 id(timestamp/branch-prefix ADR 번호)** — 순차번호의 가독성·관례를 깬다. 거부: 번호 재부여가 관례를 보존하면서 충돌만 없앤다.

## 개정 (2026-06-11) — 영속 연료 읽기 오버레이

브랜치 루트는 비어 시작하므로, 비-기본 브랜치의 **영속 그릴링 연료(CONTEXT.md·adr/·retro/) 읽기는 최상위 `.forge/` 베이스 위에 브랜치 루트를 오버레이**한다(둘 다 읽고 충돌 시 브랜치 우선) — codebase/ 예외와 같은 근거(갓 만든 브랜치도 main의 용어·결정 위에서 그릴링한다). **쓰기는 불변**(브랜치 루트에만 — 충돌 차단의 핵심)이고 ADR 채번도 브랜치 루트 `max+1` 그대로다(fg-merge가 통합 시 재부여). **(2026-07-16 개정: ADR 채번은 시간기반 ID(`YYMMDD-HH`+글자)로 전환됨 — ADR `260716-13a` 참조. 위 `max+1` 서술은 그 이전 상태이며, 브랜치 채번은 더 이상 max+1이 아니다.)** `adr/retired/`는 양쪽 모두 읽지 않는다. 단일 정의는 `skills/fg-run/FORGE-ROOT.md`의 "Read overlay" 절.
