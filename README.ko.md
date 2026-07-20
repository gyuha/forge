# forge

![forge](./docs/icon-sm.png)

> 작업 하나를 **질의·계획 → 실행 → 회고 → 완료**의 한 바퀴로 돌리는 개발 루프.
> 19개의 `fg-` 프리픽스 Claude Code 스킬로 구성된 루프형 워크플로우 플러그인 — 루프를 이루는 4개와, 루프 밖 유틸리티 15개.

[English](./README.md)

계획은 grill-with-docs식 대화형 그릴링으로, 실행은 Claude Code Dynamic Workflow로 수행하고, 회고는 학습을 프로젝트 문서(`CONTEXT.md` · ADR · 회고 로그)에 되돌린 뒤, 완료 단계에서 한 바퀴의 잔여물을 정리하며 작업을 봉인해 같은 작업이 두 번 실행되지 않게 한다.

## 빠른 시작 — 사실 3개만 쓰면 된다

스킬이 19개라 많아 보이지만, 평소엔 **3개**로 굴립니다:

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
- **L3 — 무인 (`/fg-loop` 또는 `/fg-next all`)**: 작업 루프를 통째로 완료까지 주행한다. `/fg-next all`은 사람이 그릴링한 백로그를 빌 때까지 비우고, `/fg-loop`은 기계 검증 가능한 goal로 수렴하며 그 과정에서 한정된 fix-forward 작업을 생성한다. 둘 다 벽(검증 실패/불가, 진짜 fork, 무진전; `/fg-loop`은 추가로 체크 간 tension 진동·비가역/파괴적 액션)에서 멈추고 full-context로 인계한다.
  - **L3를 진짜 무인으로 돌리려면 `/goal`이 필요하다.** 두 차선 모두 진입 시 붙여넣기용 `/goal …` 한 줄을 제시한다 — 붙여넣으면 턴 경계(백그라운드 워크플로우 완료, 일시 정지)를 넘어 완료 또는 벽까지 자동 재개된다. 없으면 한 사이클 후 멈추는데 이는 정상이며, 트리거를 다시 치면 재개된다. (워크플로우 스크립트 승인은 `/goal` 여부와 무관하게 항상 사람이 필요하다.)

요령: 먼저 `/fg-ask`로 계획을 그릴링하고 — 그 사람의 판단이 L1이며 절대 자동화되지 않는다 — 편한 가장 낮은 차선을 고른다. `/fg-loop`은 실행 가능한 체크(`grep`/test/build)로 못박을 수 있는 goal의 L3이고, `/fg-next all`은 이미 그릴링한 대기열의 L3이다.

## 사용 시나리오 — 유형별 흐름

상황에 맞는 순서를 고른다. 일상·무인 행은 위 섹션을 반복하지 않고 가리킨다.

| 상황 | 흐름 |
| --- | --- |
| **처음 셋업** (새 프로젝트/코드베이스) | `fg-map`(코드 지도) → `fg-agents`(도메인 에이전트 생성 — 로드되려면 **세션 재시작**, [ADR-0024](./.forge/adr/0024-fg-agents-and-domain-agent-execution.md)) → `fg-ask`(첫 작업) → 루프 |
| **일상 작업** | `fg-ask → fg-run → fg-next` — 위 *빠른 시작* 참조 |
| **사소한 1회 변경** (오타·버전 범프) | `fg-quick` — 가볍게 그릴링, 형식 산출물 없이 바로 실행 |
| **무인 주행 완료까지** | 그릴된 큐: `fg-ask` ×N → `fg-next all` · 기계 검증 가능 목표: `fg-loop` — *차선 고르기*(L3) 참조 |
| **재진입 / 점검** | *어디까지 했지*: `fg-status`(보여줌) / `fg-next`(다음 단계 실행) · *상태 건강한가*: `fg-doctor` |
| **마무리 / 배포** | (선택 적대적 검토: `fg-adversarial-review`) → `fg-learn`(회고) → `fg-done`(봉인) → `배포` 입력 |
| **유지보수** | 오래된 ADR 은퇴 `fg-cleanup` · 머지된 브랜치 통합 `fg-merge` · 미완 작업 폐기 `fg-drop` · 토글 `fg-tdd`/`fg-eco` · 상태바 `fg-statusline` |
| **팀 사용** (브랜치 + CI) | 브랜치에서 봉인 → `git merge` → `fg-merge`(또는 `fg-merge <branch>`로 둘 다 한 번에; CI에선 `forge-merge.sh`) · `forge-doctor` AI 없는 CI 게이트 — **[docs/team-workflow.md](./docs/team-workflow.md)** 참조 |

처음 셋업은 *빠른 시작*이 건너뛰는 유일한 순서다: 새 프로젝트에선 코드를 매핑하고 (선택적으로) 도메인 에이전트를 첫 `fg-ask` **전에** 만든다 — `fg-agents` 카드는 세션 시작 시에만 로드되므로 생성 후 한 번 재시작한다(ADR-0024).

## 스킬 카탈로그

루프 4단계, 그다음 루프 밖 유틸리티 15개:

| 스킬 | 단계 | 한 줄 역할 |
| --- | --- | --- |
| `fg-ask` | ① 질의·계획 | grill-with-docs 원문 그대로 — 계획을 도메인·용어·결정에 대고 그릴링 |
| `fg-run` | ② 실행 | 계획을 Dynamic Workflow로 실행(plan 하나면 즉시, 여럿이면 우선순위 선택 목록) |
| `fg-learn` | ③ 회고 | 학습을 문서로 승급, 다음 질의 도출 |
| `fg-done` | ④ 완료 | 한 바퀴 정리 — 회고 확인, `STATUS.md` 마감, 아카이브, 활성 상태 비우기, 봉인; 기계적 봉인은 세 봉인 경로가 공유하는 결정론 스크립트(`forge-done.sh`/`.js`)가 처리([ADR-0030](./.forge/adr/0030-fg-done-deterministic-seal-script.md)). `all` 모드는 이미 실행된 작업을 일괄 봉인(회고 skip·백로그 불가침·검증 게이트 유지) |
| `fg-map` | 유틸리티 | 코드베이스를 `.forge/codebase/`에 매핑해, 그릴링이 코드 재탐색 대신 지도를 읽게 함 |
| `fg-quick` | 유틸리티 | 사소한 작업용 경량 차선 — 가볍게 그릴링한 뒤 형식 산출물 없이 바로 실행 |
| `fg-status` | 유틸리티 | 읽기 전용 — `.forge/`를 조사해 모든 작업의 현황과 다음 단계 하나를 출력 |
| `fg-next` | 유틸리티 | fg-status의 상태 머신으로 다음 단계 하나를 도출해 실행; `all` 모드는 벽까지 주행 |
| `fg-loop` | 유틸리티 | goal 주도 한정 재계획 루프 — 기계 검증 체크가 통과할 때까지 run → UAT → 봉인 주행 |
| `fg-tdd` | 유틸리티 | `.forge/config.json`의 영속 TDD 모드 토글 |
| `fg-eco` | 유틸리티 | eco 모드 토글 — 켜면 위임 서브에이전트를 `sonnet`으로 캡하고, 임베드된 Eco laziness-first 규율(`ECO.md` — 코드 단순성 + 출력 prose 압축)을 활성화(fg-run 주입·fg-ask YAGNI 렌즈·현 세션 채택) |
| `fg-merge` | 유틸리티 | `git merge` 뒤 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합 — `fg-merge <branch>`면 그 `git merge`까지 대신 실행(대화형·기본 브랜치). 스크립트-백킹(`forge-merge.sh`/`.js`), AI 없이 CI에서 동작 |
| `fg-cleanup` | 유틸리티 | 오래된/대체된 ADR을 활성 집합에서 `.forge/adr/retired/`로 은퇴 |
| `fg-statusline` | 유틸리티 | statusline에 forge 루프 진행 상태 표시 — 방법 1(append)은 기존 statusline을 별도 줄로 래핑, 방법 2(merge)는 daleseo식 시스템 정보 + forge 진행을 담은 통합 스크립트 설치 |
| `fg-adversarial-review` | 유틸리티 | fg-run↔fg-learn 사이 선택적 적대적 검토 — 6개 렌즈, fix-forward findings |
| `fg-doctor` | 유틸리티 | `.forge/` 상태 계약과 문서/매니페스트 정합의 읽기 전용 무결성 검사 — 스크립트-백킹, AI 없는 CI 게이트로 사용 가능 |
| `fg-drop` | 유틸리티 | 미완 작업(backlog/활성/executed/멈춘 루프) 폐기 — 위험도 표기 목록, 하드 삭제 또는 `.forge/dropped/` 보관 |
| `fg-agents` | 유틸리티 | 대화형 그릴링으로 프로젝트 도메인 에이전트(`.claude/agents/<role>.md`) 생성 — 세션 재시작 후 fg-run이 매칭 role을 `agentType`으로 호출 |
| `fg-visual` | 유틸리티 | 브라우저 시각 컴패니언(superpowers vendoring, MIT) — zero-dependency 로컬 서버가 에이전트가 push하는 HTML(목업·다이어그램·A/B 시각 비교)을 표시하고 클릭을 이벤트로 수집해 되읽음; fg-ask 그릴링 중 just-in-time 1회 제안, `fg-visual stop`으로 종료 |

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

forge를 쓰면서 git·브랜치를 운영하는 법 — git-abstinence 모델, 커밋 시점, 피처 브랜치 단계별 git CLI 워크스루 — 은 **[docs/git-workflow.md](./docs/git-workflow.md)** 에 있다.

## 두 기둥

1. **그릴링(계획)은 Dynamic Workflow 밖의 대화형으로.** Dynamic Workflow는 실행 중 사용자 입력을 못 받으므로, 한 질문씩 주고받는 그릴링을 워크플로우 안에 넣지 않는다.
2. **문서는 산출물이 아니라 루프의 연료.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.

## forge와 다른 하네스 비교

| 항목 | forge | GSD Core | GStack | Superpowers |
| --- | --- | --- | --- | --- |
| 순수 파일 기반 영속 상태(DB 불필요) | ✓ (`.forge/` 마크다운+JSON, git 추적) | ✓ (`STATE.md`/`CONTEXT.md`) | △ (GBrain은 기본적으로 DB 지향 — PGLite/Supabase/원격 MCP) | △ (설계 문서는 저장하나 구조화된 상태 계약은 미문서화) |
| 문서 승급에 명시적 절제 게이트 | ✓ (비가역·의아함·진짜 트레이드오프 셋 다 충족할 때만 ADR) | — | — | — |
| 회고 학습이 다음 계획 그릴링에 자동 환류 | ✓ | — | — | — |
| 증거-우선 다상태 검증 게이트(봉인 차단) | ✓ (5상태: yes/skipped/n·a/pending/failed) | △ (Verify 단계 존재) | △ (`/qa`, `/canary`) | △ (`verification-before-completion` 스킬) |
| 봉인 후 동일 작업 영구 재실행 방지 | ✓ (`done/` 아카이브) | — | — | — |
| 단계적 자율성(관찰→보조→무인) + 자동 정지 벽(tension·oscillation 감지 포함) | ✓ | — | — | — |
| TDD를 프로젝트/작업 단위로 켜고 끄는 토글 | ✓ (config 기본값 + 작업별 오버라이드) | — | — | △ (상시 강제, 끌 수 없음) |
| 프로젝트 전용 도메인 에이전트를 필요할 때만 생성 | ✓ (그릴링 기반, 자격 갖춘 역할만) | — | △ (25개 이상 고정 내장 전문가 스킬) | — |
| 비용 절감 내장 규율(서브에이전트 모델 캡+단순성 규율) | ✓ (eco 모드) | — | △ (모델 벤치마킹 도구, 결이 다름) | — |
| 대상 플랫폼 폭 | Claude Code 전용 | 10+ 런타임 | 10개 에이전트 | 9개 이상 에이전트 |

범례: ✓ 명시적으로 지원 · △ 비슷한 것은 있으나 형태·엄격도가 다름 · — 공개 문서에서 확인 안 됨(없다고 단정하지 않음)

### forge의 강점

- 문서는 산출물이 아니라 루프의 연료다 — ADR은 세 조건(비가역·의아함·진짜 트레이드오프)을 모두 충족할 때만 만들어 문서 인플레이션을 구조적으로 막는다.
- 검증 없이는 봉인 없다 — pending/failed(사유)/skipped(사유)/n·a(사유)를 정직하게 구분해, 검증 안 된 작업이 조용히 "완료"로 둔갑하지 못한다.
- 무인 자동화도 사람이 정의한 벽(실패한 검증·해소 불가한 분기·tension 핑퐁·안전 등급 액션)에서 스스로 멈춘다.
- 봉인이 진짜 끝을 의미한다 — 봉인된 작업은 같은 작업이 다시 실행되는 걸 구조적으로 막는다.
- 인프라가 필요 없다 — DB도 서버도 npm도 없이 `/plugin install` 한 줄로 끝난다.
- 고정된 전문가 세트를 들이미는 대신, 이 프로젝트에 실제로 반복되는 역할이 무엇인지 그릴링으로 찾아 그만큼만 에이전트 카드를 만든다.
- 정직한 트레이드오프: forge는 Claude Code 전용이라 넷 중 플랫폼 폭이 가장 좁다. 대신 그 자리에서 Dynamic Workflow·AskUserQuestion·Skill 체이닝 같은 Claude Code 고유 기능을 최소공통분모로 깎지 않고 깊게 판다.

### forge가 하지 않는 것

- **크로스모델 벤치마킹** — GStack은 있음(`/codex`, `gstack-model-benchmark`), forge는 없음 (의도적: 모델 선택은 Claude Code 자체의 영역이지 forge의 영역이 아님)
- **브라우저 자동화·iOS QA·디자인 생성** — GStack은 있음(`/browse`, `/ios-qa`, `/design-*`), forge는 없음 (의도적: forge는 SDLC 전체가 아니라 계획→실행→회고→완료 루프에만 집중)
- **팀 공유 검색형 지식베이스** — GStack GBrain(Supabase 기반)은 프로젝트 간 공유·검색을 지원, forge의 `.forge/`는 리포 하나에 국한
- **상시 강제 TDD** — Superpowers는 테스트 없이 짠 코드를 삭제할 정도로 강제, forge의 TDD는 선택적 토글(프로젝트가 안 쓸 수도 있음)
- **작업별 git worktree 자동 격리** — Superpowers는 자동 생성, forge는 브랜치별 상태 격리(ADR-0011)만 하고 worktree 자동화는 안 함
- **계획 문서의 점수제 품질 게이트** — GStack `/spec`은 Codex 점수 7/10 미만이면 차단, forge의 ADR 게이트는 정성적 3조건이지 점수제 아님
- **보안 감사 전용 내장 스킬(OWASP/STRIDE)** — GStack `/cso`가 이를 수행, forge의 적대적 리뷰는 일반 6렌즈지 보안 특화 아님

## 크레딧

`fg-ask`의 그릴링·문서화 패턴(원문 포함)과 `CONTEXT-FORMAT.md`/`ADR-FORMAT.md`는 [mattpocock/skills의 grill-with-docs](https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs)를 계승했다.

**eco 모드**(`fg-eco`)가 쓰는 코드 단순성 규율 — `skills/fg-eco/ECO.md`에 임베드되어 fg-run 서브에이전트·fg-ask 그릴링에 주입되는 laziness-first 결정 사다리 — 은 [DietrichGebert의 Ponytail 스킬](https://github.com/DietrichGebert/ponytail)에서 차용·각색했다.

같은 `ECO.md`의 출력 prose 압축 규칙 — 코드/에러는 verbatim으로 두고 그릴링 질문·생성 문서는 full로 보존하되 실행·보고 prose를 간결화해 컨텍스트를 아낀다 — 은 [JuliusBrussee의 caveman 스킬](https://github.com/JuliusBrussee/caveman)에서 차용·각색했다.

랜딩 페이지(`docs/index.html`)는 [Superpowers(Jesse Vincent, obra)](https://github.com/obra/superpowers/blob/main/skills/brainstorming/visual-companion.md)의 **Visual Companion** — 코드를 짜기 전에 목업·레이아웃·색상 옵션을 브라우저 미리보기로 펼쳐 보여주는 디자인 도구 — 로 제작했다.
