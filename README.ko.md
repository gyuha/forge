# forge

![forge 루프: ask → run → learn → done](./docs/workflow.png)

> 작업 하나를 **질의·계획 → 실행 → 회고 → 완료**의 한 바퀴로 돌리는 개발 루프.
> 17개의 `fg-` 프리픽스 Claude Code 스킬로 구성된 루프형 워크플로우 플러그인 — 루프를 이루는 4개와, 루프 밖 유틸리티 13개.

[English](./README.md)

계획은 grill-with-docs식 대화형 그릴링으로, 실행은 Claude Code Dynamic Workflow로 수행하고, 회고는 학습을 프로젝트 문서(`CONTEXT.md` · ADR · 회고 로그)에 되돌린 뒤, 완료 단계에서 한 바퀴의 잔여물을 정리하며 작업을 봉인해 같은 작업이 두 번 실행되지 않게 한다.

## 빠른 시작 — 사실 3개만 쓰면 된다

스킬이 17개라 많아 보이지만, 평소엔 **3개**로 굴립니다:

```
/fg-ask   →   /fg-run   →   /fg-next
 (계획)        (실행)        (다음 단계 자동: 검증 → 회고/봉인)
```

- **`/fg-ask`** — *모든* 작업은 여기서 시작. 계획을 한 질문씩 같이 그릴링합니다.
- **`/fg-run`** — 계획을 실행합니다.
- **`/fg-next`** — *다음 한 단계*를 알아서 해줍니다(검증 → 회고 또는 봉인). 또 부르면 계속 진행.

**더 짧게** — 한 번 계획하고, 끝까지 알아서 굴리기:

```
/fg-ask   →   /fg-next all     (실행 → 검증 → 봉인까지, 사람이 필요한 벽에 닿을 때까지 반복)
```

길을 잃으면: **`/fg-status`** 는 *어디까지 했는지 보여만* 주고, **`/fg-next`** 는 *다음 걸 그냥 해*줍니다. 사소한 일회성 변경(오타·버전 범프)이면 **`/fg-quick`**. 결과를 출하하려면 **`배포`** 라고 치면 됩니다.

아래 카탈로그의 나머지는 전부 선택적 보조 — 특정 필요가 생길 때만 꺼내 쓰면 됩니다. 딱 한 줄만 기억한다면: **`/fg-ask` 한 뒤 `/fg-next`(또는 `/fg-next all`)를 계속 부르기.**

## 차선 고르기 — 관찰하고, 보조받고, 무인 주행

주행 스킬 3개는 **신뢰 사다리**를 이룬다 — loop engineering의 L1→L2→L3 배포(보고 → 보조 → 무인)와 같은 점진적 자율성 개념이다. 낮게 시작해, 해당 작업에서 루프를 신뢰하게 되면 올린다:

- **L1 — 관찰 (`/fg-status`)**: 읽기 전용. 모든 작업의 현황과 다음 단계 하나를 *보여주기만* 한다. 아무것도 실행하지 않는다. 결정하기 전에 판을 볼 때.
- **L2 — 보조 (`/fg-next`)**: 다음 *한* 단계만 하고 멈춘다. 단계 사이에 당신이 운전석에 남는다 — 검토하고 다시 부른다. 전환마다 지켜보고 싶을 때.
- **L3 — 무인 (`/fg-loop` 또는 `/fg-next all`)**: 작업 루프를 통째로 완료까지 주행한다. `/fg-next all`은 사람이 그릴링한 백로그를 빌 때까지 비우고, `/fg-loop`은 기계 검증 가능한 goal로 수렴하며 그 과정에서 한정된 fix-forward 작업을 생성한다. 둘 다 벽(검증 실패/불가, 진짜 fork, 무진전)에서 멈추고 full-context로 인계한다.

요령: 먼저 `/fg-ask`로 계획을 그릴링하고 — 그 사람의 판단이 L1이며 절대 자동화되지 않는다 — 편한 가장 낮은 차선을 고른다. `/fg-loop`은 실행 가능한 체크(`grep`/test/build)로 못박을 수 있는 goal의 L3이고, `/fg-next all`은 이미 그릴링한 대기열의 L3이다.

## 스킬 카탈로그

루프 4단계, 그다음 루프 밖 유틸리티 13개:

| 스킬 | 단계 | 한 줄 역할 |
| --- | --- | --- |
| `fg-ask` | ① 질의·계획 | grill-with-docs 원문 그대로 — 계획을 도메인·용어·결정에 대고 그릴링 |
| `fg-run` | ② 실행 | 계획을 Dynamic Workflow로 실행(plan 하나면 즉시, 여럿이면 선택 메뉴) |
| `fg-learn` | ③ 회고 | 학습을 문서로 승급, 다음 질의 도출 |
| `fg-done` | ④ 완료 | 한 바퀴 정리 — 회고 확인, `STATUS.md` 마감, 아카이브, 활성 상태 비우기, 봉인; `all` 모드는 이미 실행된 작업을 일괄 봉인(회고 skip·백로그 불가침·검증 게이트 유지) |
| `fg-map` | 유틸리티 | 코드베이스를 `.forge/codebase/`에 매핑해, 그릴링이 코드 재탐색 대신 지도를 읽게 함 |
| `fg-quick` | 유틸리티 | 사소한 작업용 경량 차선 — 가볍게 그릴링한 뒤 형식 산출물 없이 바로 실행 |
| `fg-status` | 유틸리티 | 읽기 전용 — `.forge/`를 조사해 모든 작업의 현황과 다음 단계 하나를 출력 |
| `fg-next` | 유틸리티 | fg-status의 상태 머신으로 다음 단계 하나를 도출해 실행; `all` 모드는 벽까지 주행 |
| `fg-loop` | 유틸리티 | goal 주도 한정 재계획 루프 — 기계 검증 체크가 통과할 때까지 run → UAT → 봉인 주행 |
| `fg-tdd` | 유틸리티 | `.forge/config.json`의 영속 TDD 모드 토글 |
| `fg-eco` | 유틸리티 | eco 모드 토글 — 위임 워크플로우 서브에이전트를 `sonnet`으로 캡 |
| `fg-merge` | 유틸리티 | `git merge` 뒤 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합 |
| `fg-cleanup` | 유틸리티 | 오래된/대체된 ADR을 활성 집합에서 `.forge/adr/retired/`로 은퇴 |
| `fg-statusline` | 유틸리티 | forge 루프 진행 상태를 띄우는 statusline 조각 설치 |
| `fg-adversarial-review` | 유틸리티 | fg-run↔fg-learn 사이 선택적 적대적 검토 — 6개 렌즈, fix-forward findings |
| `fg-doctor` | 유틸리티 | `.forge/` 상태 계약과 문서/매니페스트 정합의 읽기 전용 무결성 검사 |
| `fg-drop` | 유틸리티 | 미완 작업(backlog/활성/executed/멈춘 루프) 폐기 — 위험도 표기 목록, 하드 삭제 또는 `.forge/dropped/` 보관 |

스킬별 상세 — 입력·출력·다음 단계, 트리거, 근거 ADR — 은 **[docs/skills.md](./docs/skills.md)** 에 있다. `fg-ask`가 루프의 진입점이며("forge 시작", "새 작업", "계획 다듬자" 등에서 트리거), 유틸리티는 각자 고유 발화로 트리거되는 온디맨드 스킬이다.

## 전체 흐름

한 스킬이 끝나면 다음 스킬로 가는 길(무엇을 했고, 다음은 무엇이며, 어떻게 시작하는지)을 **알리고 멈춘다** — "이어갈까요?"라고 묻지 않으며, 다음 단계로 잇는 것은 `fg-next`의 몫이다. 이제 이는 `fg-run`의 단일작업 종료를 포함한 **모든** 핸드오프에 적용된다: 다음 단계만 알리고 멈춘다 — 기본은 `fg-learn` 회고, divergence가 낮으면 `fg-done`으로 skip+봉인, 높으면 `fg-ask` 재그릴. (fg-run의 과거 4지 메뉴는 폐지됐다 — 변하지 않은 활성 슬롯 상태에서 다시 떠 반복되는 버그 때문에; [ADR-0015](./.forge/adr/0015-fg-run-handoff-menu-others-stated.md), 개정 2026-06-15.) 루프는 `fg-done`이 작업을 봉인한 뒤, **새 작업**으로서만 `fg-ask`에서 다시 시작된다 — 같은 작업을 다시 실행하지 않는다. 두 유틸리티가 루프 밖에서 이 연료를 돌본다: `fg-map`은 `fg-ask`가 읽는 코드베이스 지도를 작성하고, `fg-cleanup`은 `fg-ask`가 읽는 ADR 집합을 정비한다.

```
fg-ask ───▶ fg-run ───▶ fg-learn ───▶ fg-done
① 질의/계획     ② 실행          ③ 회고        ④ 완료
(그릴링·대화형) (Dynamic WF)   (문서 반영)    (봉인·재실행 방지)
```

루프와 문서 산출물의 관계를 그린 상세 흐름도는 [docs/state-contract.md](./docs/state-contract.md)에 있다.

## 설치

Claude Code 세션에서 GitHub 마켓플레이스로 추가한 뒤 플러그인을 설치한다.

```
/plugin marketplace add gyuha/forge
/plugin install forge@forge
```

로컬 클론에서 설치하려면(예: 개발 중) 리포 루트 경로를 넘긴다:

```
/plugin marketplace add /path/to/forge
/plugin install forge@forge
```

참고:

- GitHub 설치는 리포의 기본 브랜치(`main`)를 당긴다 — 변경을 설치로 테스트하려면 먼저 `main`에 push되어 있어야 한다.
- 스킬은 `skills/<name>/SKILL.md`에서 자동 탐색되므로 추가 설정이 필요 없다.
- 이후 업데이트는 `/plugin marketplace update forge`, 제거는 `/plugin uninstall forge@forge`.

설치 후 Claude Code 세션에서 `fg-ask`부터 트리거되거나, "forge로 시작" 같은 발화로 루프가 시작된다.

## 공유 상태와 디렉터리

단계를 독립적으로 호출해도 흐름이 이어지도록 상태를 파일로 넘긴다. 모든 것을 `.forge/` 한 디렉터리에 둔다 — 휘발 루프 상태와 git 추적되는 영속 문서가 함께 산다(`.gitignore`가 `.forge/`를 기본 제외하고 영속 문서만 화이트리스트로 추적). 활성 슬롯은 항상 1개 — 한 `plan.md` = 한 `run.md` = 한 봉인. 비-기본 브랜치에서는 forge 루트 전체가 `.forge/branch/<branch>/`(git 추적)로 옮겨가 병렬 브랜치가 충돌하지 않는다 ([ADR-0011](./.forge/adr/0011-branch-isolated-forge-root.md)).

전체 디렉터리 구조, `.gitignore` 패턴, 브랜치 격리, 회고 스킵 규칙([ADR-0002](./.forge/adr/0002-optional-retro-skip.md)), 봉인 전 검증 게이트([ADR-0009](./.forge/adr/0009-verification-gate-before-seal.md))는 **[docs/state-contract.md](./docs/state-contract.md)** 에 문서화돼 있다.

## 두 기둥

1. **그릴링(계획)은 Dynamic Workflow 밖의 대화형으로.** Dynamic Workflow는 실행 중 사용자 입력을 못 받으므로, 한 질문씩 주고받는 그릴링을 워크플로우 안에 넣지 않는다.
2. **문서는 산출물이 아니라 루프의 연료.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.

## 크레딧

`fg-ask`의 그릴링·문서화 패턴(원문 포함)과 `CONTEXT-FORMAT.md`/`ADR-FORMAT.md`는 [mattpocock/skills의 grill-with-docs](https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs)를 계승했다.
