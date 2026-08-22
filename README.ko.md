# forge

![forge](./docs/icon-sm.png)

> 에이전트 엔지니어링을 위한 Claude Code 워크플로우 플러그인 — 작업 하나를 **질의·계획 → 실행 → 회고 → 완료**의 한 바퀴로.
> 22개의 `fg-` 프리픽스 Claude Code 스킬로 구성된 루프형 워크플로우 플러그인 — 루프를 이루는 4개와, 루프 밖 유틸리티 18개.

[English](./README.md)

아래 문서들은 **[gyuha.com/forge/docs](https://gyuha.com/forge/docs/)** 에 문서 사이트로도 배포돼 있다 — 사이드바 네비·검색·다크모드 (English: [gyuha.com/forge/docs/en](https://gyuha.com/forge/docs/en/)).

계획은 grill-with-docs식 대화형 그릴링으로, 실행은 Claude Code Dynamic Workflow로 수행하고, 회고는 학습을 프로젝트 문서(`CONTEXT.md` · ADR · 회고 로그)에 되돌린 뒤, 완료 단계에서 한 바퀴의 잔여물을 정리하며 작업을 봉인해 같은 작업이 두 번 실행되지 않게 한다.

## 빠른 시작 — 사실 3개만 쓰면 된다

스킬이 22개라 많아 보이지만, 평소엔 **3개**로 굴립니다:

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
- **L3 — 무인 (`/fg-loop` 또는 `/fg-next all`)**: 작업 루프를 통째로 완료까지 주행한다. `/fg-next all`은 사람이 그릴링한 백로그를 빌 때까지 비우고, `/fg-loop`은 기계 검증 가능한 goal로 수렴하며 그 과정에서 한정된 fix-forward 작업을 생성한다. 둘 다 벽(검증 실패/불가, 진짜 fork, 무진전; `/fg-loop`은 추가로 체크 간 tension 진동·비가역/파괴적 액션·정체된 대기·실행 불가한 체크 명령)에서 멈추고 full-context로 인계한다. `/fg-loop`은 외부 증거(CI·배포)를 **기다리는 상태**를 실패와 구분한다 — 사람에게 아무것도 요구하지 않고 다음 트리거에서 그대로 재개한다.
  - **L3를 무인으로 돌리는 데 사용자 조작이 필요하지 않다 — forge가 자기 `Stop` 훅을 배포한다**([ADR-0028](./.forge/adr/0028-unattended-drive-continuation-and-goal-pairing.md), 2026-08-22 개정). 턴은 모델이 도구 호출을 멈추면 끝나고, 그것을 막을 수 있는 메커니즘은 Stop 훅뿐이라 예전에는 `/goal`이 필요했다. 이제 주행이 진입 시 `drive.md` 마커를 쓰고 forge의 훅이 그 마커가 사는 동안 `exit 2`를 내므로, 주행이 스스로 턴 경계(백그라운드 워크플로우 완료, 일시 정지)를 넘어 완료 또는 벽까지 간다. **마커를 지우는 것이 주행이 "이제 멈춰도 된다"고 말하는 방법**이며, 모든 벽·종료 상태·사람만 끝낼 수 있는 대기(워크플로우 스크립트 승인은 여전히 사람이 필요하다) 직전에 지워진다. 상한 둘(**30분**·**차단 50회**)이 죽거나 도는 주행이 세션을 가두는 것을 막고, 훅의 모든 실패 경로는 정지를 허용한다. `/goal`은 **폴백**으로 남는다 — 훅은 세션 시작 시 로드되므로 forge를 설치·갱신하기 전에 시작된 세션에는 훅이 없고, 거기서는 종전 동작(한 사이클 후 트리거 재발행)이 그대로다.

요령: 먼저 `/fg-ask`로 계획을 그릴링하고 — 그 사람의 판단이 L1이며 절대 자동화되지 않는다 — 편한 가장 낮은 차선을 고른다. `/fg-loop`은 실행 가능한 체크(`grep`/test/build)로 못박을 수 있는 goal의 L3이고, `/fg-next all`은 이미 그릴링한 대기열의 L3이다.

## 무엇에 일을 담는가 — `fg-ask`·`fg-loop`·`fg-agenda`

한 단계보다 오래 사는 일을 담는 스킬이 셋이고, **셋 다 대화로 시작하기 때문에** 헷갈리기 쉽다. 다른 것은 *그 대화가 무엇을 못 박느냐*다:

> **`fg-agenda`는 계획의 상류에 있고 · `fg-ask`가 계획을 만들고 · `fg-loop`은 계획 하류를 주행한다.**

| 축 | `fg-ask` | `fg-loop` | `fg-agenda` |
| --- | --- | --- | --- |
| 위치 | 루프 ① 단계 | 루프 밖 — L3 무인 주행 | 루프 밖 — 계획 유틸리티 |
| 첫 대화가 못 박는 것 | Work slices + 완료 기준 | **기계 검증 가능한** 정지 체크 + 재계획 상한 | 목적지 + 열린 질문 |
| 담는 파일 | `backlog/<slug>.md` | `loop.md` | `agenda.md` |
| 답하는 사람 | 당신, 모든 질문 | 없음 — 무인으로 돈다 | 당신, 모든 질문 (에이전트는 *찾기*만 한다) |
| 끝나는 조건 | 실행 가능한 계획이 나오면 | 체크 전부 통과 (기계 판정) | 더 결정할 것이 없으면 (판단) |
| 진행할 수 없을 때 | 다음 질문을 한다 | 벽에서 멈추고 맥락과 함께 넘긴다 | fog에 적고 넘어간다 |
| 수명 | 한 세션 | 여러 세션 — goal 충족 시 `loop.md` 삭제 | 여러 세션 — 비면 `agenda.md` 삭제 |

**선택 기준 — 지금 무엇을 댈 수 있나?**

- 대략이라도 Work slices를 댈 수 있다 → **`fg-ask`**. 이것이 기본이고 나머지 둘이 예외다.
- "완료"를 통과/실패하는 명령으로 표현할 수 있다 → **`fg-loop`**.
- 둘 다 못 하고, *"무엇부터?"*에 대한 정직한 답이 *"뭘 결정해야 하는지도 모르겠다"*다 → **`fg-agenda`**.

셋은 경쟁하지 않고 이어진다 — 의제는 질문을 하나씩 그릴링으로 해소하고, 결정이 빌드 가능해지는 순간 그 줄은 백로그로 떠난다:

```
fg-agenda ──질문 하나──▶ (fg-ask의 그릴링) ──▶ "결정된 것"에 한 줄
    └──결정이 빌드 가능해지면──▶ fg-ask ──▶ backlog ──▶ fg-run ──▶ …
                                              └── 또는 fg-loop / fg-next all이 주행
```

`fg-agenda`는 스스로 `fg-ask`에 양보한다 — breadth-first로 훑어 **안개가 나오지 않으면** 의제를 만들지 않고 `fg-ask`를 가리킨다. 그러니 길이 정말 아직 안 보일 때만 꺼내면 된다. 그리고 `fg-loop`은 `fg-agenda`의 거울상이다 — 기계 정지 조건으로 무인 주행하는 쪽과, 판단 정지 조건으로 사람이 답하는 쪽. 그래서 둘이 하나가 아니라 둘이다.

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
| **보안 점검** (코드베이스 전체) | `fg-security`(감사) → 심각도 게이트 통과분 승인 → `fg-run`(수정 plan 실행) → 재감사(업스트림이 복수 실행 권장) |
| **유지보수** | 오래된 ADR 은퇴 `fg-cleanup` · 머지된 브랜치 통합 `fg-merge` · 미완 작업 폐기 `fg-drop` · 토글 `fg-tdd`/`fg-eco` · 상태바 `fg-statusline` |
| **팀 사용** (브랜치 + CI) | 브랜치에서 봉인 → `git merge` → `fg-merge`(또는 `fg-merge <branch>`로 둘 다 한 번에; CI에선 `forge-merge.sh`) · `forge-doctor` AI 없는 CI 게이트 — **[docs/team-workflow.md](./docs/team-workflow.md)** 참조 |

처음 셋업은 *빠른 시작*이 건너뛰는 유일한 순서다: 새 프로젝트에선 코드를 매핑하고 (선택적으로) 도메인 에이전트를 첫 `fg-ask` **전에** 만든다 — `fg-agents` 카드는 세션 시작 시에만 로드되므로 생성 후 한 번 재시작한다(ADR-0024).

## 스킬 카탈로그

루프 4단계, 그다음 루프 밖 유틸리티 18개:

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
| `fg-eco` | 유틸리티 | eco 모드 토글 — 켜면 위임 서브에이전트를 `sonnet`으로 캡하고, 임베드된 Eco laziness-first 규율(`ECO.md` — 코드 단순성 + 출력 prose 압축)을 활성화(fg-run 주입·fg-ask YAGNI 렌즈·현 세션 채택)하며, **작업 종료 핸드오프를 요약 표로 교체**(fg-run 핸드오프·fg-done 단일 봉인·배치/무인 경로). 실행 *중* narration은 불변 |
| `fg-merge` | 유틸리티 | `git merge` 뒤 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합 — `fg-merge <branch>`면 그 `git merge`까지 대신 실행(대화형·기본 브랜치). 스크립트-백킹(`forge-merge.sh`/`.js`), AI 없이 CI에서 동작 |
| `fg-cleanup` | 유틸리티 | 오래된/대체된 ADR을 활성 집합에서 `.forge/adr/retired/`로 은퇴 |
| `fg-statusline` | 유틸리티 | statusline에 forge 루프 진행 상태 표시 — 방법 1(append)은 기존 statusline을 별도 줄로 래핑, 방법 2(merge)는 daleseo식 시스템 정보 + forge 진행을 담은 통합 스크립트 설치 |
| `fg-adversarial-review` | 유틸리티 | fg-run↔fg-learn 사이 선택적 적대적 검토 — 6개 렌즈, fix-forward findings |
| `fg-doctor` | 유틸리티 | `.forge/` 상태 계약과 문서/매니페스트 정합의 읽기 전용 무결성 검사 — 스크립트-백킹, AI 없는 CI 게이트로 사용 가능 |
| `fg-help` | 유틸리티 | 읽기 전용 사용법 도움말 — `/fg-help`는 forge 스킬 전체를 루프 단계 + 루프 밖 유틸리티로 그룹핑한 개요를, `/fg-help <명령>`은 4줄 상세를 출력; 각 스킬의 `description`을 단일 소스로 읽어 사용자 언어로 LLM 렌더(스크립트 트윈 없음) |
| `fg-drop` | 유틸리티 | 미완 작업(backlog/활성/executed/멈춘 루프) 폐기 — 위험도 표기 목록, 하드 삭제 또는 `.forge/dropped/` 보관 |
| `fg-agents` | 유틸리티 | 대화형 그릴링으로 프로젝트 도메인 에이전트(`.claude/agents/<role>.md`) 생성 — 세션 재시작 후 fg-run이 매칭 role을 `agentType`으로 호출 |
| `fg-visual` | 유틸리티 | 브라우저 시각 컴패니언(superpowers vendoring, MIT) — zero-dependency 로컬 서버가 에이전트가 push하는 HTML(목업·다이어그램·A/B 시각 비교)을 표시하고 당신의 답을 이벤트로 되읽음 — 선택형 화면의 필수 확정 버튼을 누르면 터미널 턴 없이 바로 당신을 깨우고, 탐색 클릭만으로는 깨우지 않음; fg-ask 그릴링 중 just-in-time 1회 제안, `fg-visual stop`으로 종료 |
| `fg-agenda` | 유틸리티 | 안개 속 작업의 결정 대기열 — 목적지를 함께 정한 뒤 무엇을 결정해야 하는지 캐내 `.forge/agenda.md`에 담고, 길이 밝아질 때까지 한 번에 하나씩 해소한 다음 스스로 삭제; 결정을 찾는 것은 에이전트, **답은 당신**이 하며, 빌드 가능해진 것은 백로그로 떠난다 |
| `fg-security` | 유틸리티 | 코드베이스 보안 감사(방법론은 cloudflare/security-audit-skill vendoring, MIT) — 공격 유형별 다중 에이전트 다단계 hunting, 산출물은 **리포 밖**(업스트림 `~/security-audit-skill/`)에 남아 커밋 경로가 애초에 없고, 심각도 게이트와 당신의 승인을 통과한 findings가 fix-forward 백로그 plan이 된다 |

스킬별 상세 — 입력·출력·다음 단계, 트리거, 근거 ADR — 은 **[docs/skills.md](./docs/skills.md)** 에 있다. `fg-ask`가 루프의 진입점이며("forge 시작", "새 작업", "계획 다듬자" 등에서 트리거), 유틸리티는 각자 고유 발화로 트리거되는 온디맨드 스킬이다.

## 전체 흐름

한 스킬이 끝나면 다음 스킬로 가는 길을 고정 4행 **핸드오프 표** — *방금 한 것 · 다음 단계 · 시작하는 법 · 대안* — 로 **알리고 멈춘다**. 가리킬 다음 단계가 실재하는 **13곳**에 적용되며(나머지 여덟은 가리킬 것이 없는 토글·유틸리티라 산문을 유지한다), 그래서 다음 단계가 문단 중간에 묻히지 않고 매번 같은 자리에 있다 — 이것이 고치는 통증은 **길이가 아니라 찾기 어려움**이다 ([ADR `260805-231104`](./.forge/adr/260805-231104-handoff-table.md)). `eco` 요약 표와는 다른 것이다 — 그쪽은 *무엇을 했나*에 답하고, 이 표는 *다음에 무엇을*에 답하며 `eco` on/off 무관하게 렌더된다. **진술형은 변하지 않았다** — 표는 텍스트 출력이고 결코 메뉴가 아니다: "이어갈까요?"라고 묻지 않으며, 다음 단계로 잇는 것은 여전히 `fg-next`의 몫이다 ([ADR-0015](./.forge/adr/0015-fg-run-handoff-menu-others-stated.md), 개정 2026-06-15 — fg-run의 과거 4지 메뉴는 변하지 않은 활성 슬롯 상태에서 다시 떠 반복되는 버그로 폐지됐다). 이는 `fg-run`의 단일작업 종료를 포함한 **모든** 핸드오프에 적용된다: 기본은 `fg-learn` 회고, divergence가 낮을 때만 `fg-done`으로 skip+봉인, 높으면 `fg-ask` 재그릴 — 알리고 멈춘다. 루프는 `fg-done`이 작업을 봉인한 뒤, **새 작업**으로서만 `fg-ask`에서 다시 시작된다 — 같은 작업을 다시 실행하지 않는다. 두 유틸리티가 루프 밖에서 이 연료를 돌본다: `fg-map`은 `fg-ask`가 읽는 코드베이스 지도를 작성하고, `fg-cleanup`은 `fg-ask`가 읽는 ADR 집합을 정비한다.

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

**그리고 다음 질문에서 닫는다.** 지난 작업이 봉인 안 된 채 남아 있는데 새 작업을 시작하면, fg-ask의 STEP 0이 남은 판단의 양으로 갈린다 — 판단이 없으면(검증이 봉인 가능값이고 회고도 해결됨, 또는 회고만 밀렸는데 divergence가 미미함) **묻지 않고 봉인**하고 한 줄 보고한 뒤 같은 턴에 그릴링을 계속한다. 판단이 남았으면(고-divergence·`verified: pending`/`failed`·멈춘 goal 루프) 묻지만, **당신의 요청을 붙들고 있다가 잔여를 닫은 뒤 그 자리로 돌아온다** — fg-ask를 다시 칠 필요가 없다. 사정거리는 활성 슬롯 1건이며, `executed/`에 park된 작업은 잔여가 아니라 의도된 대기이므로 보고만 하고 건드리지 않는다 ([ADR 260727-201115](./.forge/adr/260727-201115-fg-ask-auto-close-sealable-tail.md)).

**봉인을 까먹는 것은 세션 진입에서 잡는다.** forge는 훅 **둘**을 배포한다(`hooks/hooks.json` — 플러그인 설치만으로 걸리고 설정 편집이 필요 없다). 첫째는 `SessionStart`에서 **미봉인 잔여**(실행됐지만 봉인 안 된 작업·회고 대기로 park된 작업·멈춘 goal 루프)를 확인하고, 있을 때만 짧은 알림을 주입해 에이전트가 새 작업을 시작하기 전에 당신에게 알리도록 한다. 사용자가 답하기 전에 스스로 판단해 실행·봉인하지 않으며(fg-ask STEP 0의 자동 마감이 유일한 승인된 예외) 결정은 당신 몫이다. 깨끗한 리포나 백로그만 대기 중인 리포에서는 아무것도 뜨지 않는다. 둘째는 `Stop`에서, 무인 주행이 `/goal` 없이 턴 경계를 넘게 해 준다 — 주행의 `drive.md` 마커가 살아 있고 상한 안일 때만 막으므로 주행하지 않는 세션은 무영향이다([ADR-0028](./.forge/adr/0028-unattended-drive-continuation-and-goal-pairing.md)). 훅은 세션 시작 시 로드되므로, 새로 설치·수정한 훅은 **다음** 세션부터 적용된다([ADR 260727-201031](./.forge/adr/260727-201031-forge-ships-session-start-hook.md)).

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
| 보안 감사 전용 스킬 | ✓ (`fg-security` — cloudflare 방법론 vendoring; 산출물은 리포 밖) | — | ✓ (`/cso`) | — |
| 대상 플랫폼 폭 | Claude Code 전용 | 10+ 런타임 | 10개 에이전트 | 9개 이상 에이전트 |

범례: ✓ 명시적으로 지원 · △ 비슷한 것은 있으나 형태·엄격도가 다름 · — 공개 문서에서 확인 안 됨(없다고 단정하지 않음)

### forge의 강점

- 문서는 산출물이 아니라 루프의 연료다 — ADR은 세 조건(비가역·의아함·진짜 트레이드오프)을 모두 충족할 때만 만들어 문서 인플레이션을 구조적으로 막는다.
- 검증 없이는 봉인 없다 — pending/failed(사유)/skipped(사유)/n·a(사유)를 정직하게 구분해, 검증 안 된 작업이 조용히 "완료"로 둔갑하지 못한다.
- 무인 자동화도 사람이 정의한 벽(실패한 검증·해소 불가한 분기·tension 핑퐁·안전 등급 액션·외부 증거를 기다리다 정체된 대기·도구나 인증 부재로 막힌 체크 명령)에서 스스로 멈춘다.
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

## 크레딧

`fg-ask`의 그릴링·문서화 패턴(원문 포함)과 `CONTEXT-FORMAT.md`/`ADR-FORMAT.md`는 [mattpocock/skills의 grill-with-docs](https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs)를 계승했다.

**eco 모드**(`fg-eco`)가 쓰는 코드 단순성 규율 — `skills/fg-eco/ECO.md`에 임베드되어 fg-run 서브에이전트·fg-ask 그릴링에 주입되는 laziness-first 결정 사다리 — 은 [DietrichGebert의 Ponytail 스킬](https://github.com/DietrichGebert/ponytail)에서 차용·각색했다.

같은 `ECO.md`의 출력 prose 압축 규칙 — 코드/에러는 verbatim으로 두고 그릴링 질문·생성 문서는 full로 보존하되 실행·보고 prose를 간결화해 컨텍스트를 아낀다 — 은 [JuliusBrussee의 caveman 스킬](https://github.com/JuliusBrussee/caveman)에서 차용·각색했다.

랜딩 페이지(`docs/index.html`)는 [Superpowers(Jesse Vincent, obra)](https://github.com/obra/superpowers/blob/main/skills/brainstorming/visual-companion.md)의 **Visual Companion** — 코드를 짜기 전에 목업·레이아웃·색상 옵션을 브라우저 미리보기로 펼쳐 보여주는 디자인 도구 — 로 제작했다.

`fg-security`의 **보안 감사 방법론**은 [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill)을 MIT 라이선스로 **vendoring**한 것이다 — 진입 파일과 공격 유형별 플레이북 9종, `report-schema.json`·`validate-findings.cjs`가 `skills/fg-security/`에 있고 라이선스 사본은 `skills/fg-security/LICENSE`다. 개명한 것은 진입 파일 하나뿐이며(`SKILL.md` → `AUDIT.md` — forge의 스킬 자동 탐색 경로와 충돌하지 않도록), 나머지 11개는 업스트림과 **바이트 동일**로 두어 이후 diff가 싸게 유지된다. forge가 더한 것은 루프 통합뿐이다 — 심각도 게이트, 승인 시 fix-forward plan, 그리고 산출물을 리포 밖에 두는 것.
