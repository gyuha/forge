# 팀에서 forge 쓰기 — merge 정책과 CI

forge는 원래 1인 루프 도구지만, 브랜치 격리(ADR-0011)와 AI 없이 도는 결정론 스크립트(`forge-merge.sh`·`forge-doctor.sh`) 덕에 팀(3~20명)에서도 쓸 수 있다. 이 문서는 팀이 지켜야 할 **merge 규약**과 이를 **CI에 붙이는 법**을 정리한다.

## 경계 — forge는 git 정책을 소유하지 않는다

가장 먼저 못 박을 것: **forge는 git을 실행하지도, 강제하지도 않는다.** PR 승인 규칙·브랜치 보호·머지 타이밍은 GitHub(또는 너희 호스트)의 몫이다. forge가 하는 일은 오직 브랜치가 합쳐질 때 **`.forge/` 공유 문서(ADR·CONTEXT·retro·done)를 화해**시키는 것뿐이다. `fg-merge`는 명시적으로 `git merge`를 돌리지 않는다 — 사람이 먼저 `git merge`하고, 그 뒤 forge가 forge 상태만 통합한다.

이 경계를 흐리지 마라. forge에 PR 워크플로를 얹으려 하지 말고, git 협업은 git 도구에 맡겨라.

## merge 의식 (ritual)

브랜치 작업을 default 브랜치로 가져올 때 이 순서를 지킨다:

```
브랜치에서 작업 봉인 (fg-done)
   → git merge <branch>   (사람이, 또는 PR 머지)
   → forge 상태 통합:  로컬은 fg-merge (AI, 대화형 충돌 해결)
                       CI는 forge-merge.sh (AI 없이, 충돌 시 build fail)
   → 통합 결과 커밋
```

- **브랜치에서 먼저 봉인.** 브랜치의 작업은 그 브랜치 루트(`.forge/branch/<branch>/`)에서 `fg-done`으로 봉인해 `done/`에 넣는다. 미완(활성 슬롯·`executed/`·멈춘 `loop.md`) 상태로 merge하면 `forge-merge.sh`가 in-flight halt(exit 3)로 막는다.
- **`git merge`는 충돌 없이 들어온다.** 브랜치 forge 상태가 `.forge/branch/<branch>/`로 네임스페이스되어 default 브랜치엔 그 경로가 없으므로 git이 폴더를 그대로 가져온다.
- **그 다음 통합.** `fg-merge <branch>`(로컬) 또는 `forge-merge.sh <branch>`(CI)가 브랜치 루트를 `.forge/`로 합친다 — 시간기반 ADR ID를 그대로 옮기고(같은-시 충돌만 다음 글자로 국소 해소, cascade 재번호 없음), retro 이동, CONTEXT 용어 병합, done/backlog task 번호 재부여, 그 뒤 브랜치 폴더 제거.

## 충돌 권한 (누가 결정하나)

`forge-merge.sh`는 **구조 충돌**에서 nonzero exit로 멈춘다 — 아무것도 안 옮기고(gate-first 비파괴):

| 충돌 | exit | 누가 어떻게 |
|------|------|------------|
| in-flight 브랜치 상태(미봉인 작업) | 3 | **브랜치 소유자**가 브랜치에서 봉인/회수/루프 종료 후 재시도 |
| CONTEXT 용어 재정의(같은 용어, 다른 정의) | 4 | **브랜치 소유자 + 리뷰어**가 어느 정의가 맞는지 합의해 한쪽 문서를 고친 뒤 재시도 |
| incoming NNNN이 frozen 타깃과 충돌(레거시) | 4 | 사람이 수동 해소(드묾 — 시간ID 전환 후엔 거의 없음) |
| **ADR 의미 모순**(incoming 결정이 기존과 배치) | — 스크립트가 못 잡음 | **PR 리뷰(사람)**가 잡는다. CI가 하는 척하지 않는다 |

원칙: **기계로 판정 가능한 충돌만 스크립트가 막고, 의미 판단은 사람(PR 리뷰)에게 남긴다.** CI 게이트가 통과했다고 "결정이 서로 안 부딪힌다"는 뜻은 아니다 — 그건 리뷰어가 본다.

## 공유(top-level) ADR 개정 경로

브랜치는 자기 루트(`.forge/branch/<branch>/adr/`)에만 쓴다. 그래서 **이미 default 브랜치에 있는 top-level ADR을 브랜치에서 개정**하려면:

1. 브랜치에서 그 ADR에 대한 **개정을 새 (브랜치) ADR 또는 amendment 노트**로 남긴다(브랜치 루트에). 기존 top-level ADR 파일을 브랜치에서 직접 고치지 말 것 — merge 충돌·이중 편집의 원인이다.
2. `fg-merge`가 그 브랜치 ADR을 top-level로 통합한다. 원 ADR과의 관계(개정·supersede)는 새 ADR 본문에서 ID로 교차참조한다.
3. 정말 사소한 오타 수정 등은 default 브랜치에서 직접 고치는 게 낫다(브랜치를 거칠 것 없이).

시간기반 ID(`YYMMDD-HH`+글자)라 브랜치가 만든 ADR은 조율 없이 유일하고, merge에서 ID가 안 바뀌므로 교차참조가 안 깨진다(같은-시 우연 충돌만 예외 — 그때만 글자 하나 bump).

## 다중 브랜치 merge 순서

여러 브랜치를 연달아 통합할 때:

- **한 번에 하나씩**, 각 `git merge` **직후** `fg-merge`(또는 `forge-merge.sh`)를 돌린다. 여러 브랜치를 몰아서 merge한 뒤 한꺼번에 통합하려 하지 마라 — 통합은 브랜치별로 순차 처리하는 게 결정적이다.
- **순서는 git merge 순서.** task 번호·ADR ID 재부여는 통합 시점의 target 상태 기준이므로, 먼저 통합된 브랜치가 낮은 번호를 갖는다(결정적).
- 통합을 잊으면(= `git merge`만 하고 `fg-merge`를 안 돌림) `.forge/branch/<branch>/`가 default 브랜치에 방치된다 — `forge-doctor`의 **A8 검사가 "고아 브랜치 루트 = fg-merge 잊었나?"**로 잡아준다. CI에 doctor 게이트를 걸면 이 실수가 자동 감지된다.

## CI에 붙이기

`forge-merge.sh`·`forge-doctor.sh`는 AI 없이 exit code로 동작하므로 CI 게이트로 쓸 수 있다. 복사용 예제: [`examples/github-actions-forge-check.yml`](./examples/github-actions-forge-check.yml).

- **`forge-doctor.sh`** — 상태·문서 무결성 게이트. `exit 0` clean · `1` warnings · `2` errors. 엄격하게(경고도 불허) 걸려면 nonzero에서 fail, 느슨하게 걸려면 errors(≥2)에서만 fail. 고아 브랜치·버전 드리프트·깨진 STATUS·중복 ADR ID 등을 잡는다.
- **`forge-merge.sh`** — 브랜치 forge 상태 통합. `git merge` 후 실행, 충돌/미완 시 nonzero → build fail → 개발자가 로컬 `fg-merge`로 해결 후 재푸시.

CI는 **막기만** 한다 — 통합·수정은 사람이. 특히 의미 ADR 모순은 CI 밖(PR 리뷰)의 일이다.
