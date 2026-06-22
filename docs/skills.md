# forge 스킬 상세

> README의 「스킬 카탈로그」를 풀어 쓴 문서. 각 스킬의 입력·출력·다음 단계, 그리고 트리거·동작·근거 ADR을 담는다. 한눈에 보는 요약 표는 [README](../README.ko.md#스킬-카탈로그)를 보라.

## 스킬 카탈로그 (전체 6열)

| 스킬 | 단계 | 한 줄 역할 | 입력 | 출력 | 다음 |
| --- | --- | --- | --- | --- | --- |
| `fg-ask` | ① 질의·계획 | grill-with-docs 원문 그대로 — 계획을 도메인·용어·결정에 대고 그릴링 | 사용자 요청 | `.forge/backlog/<slug>.md` + CONTEXT/ADR | `fg-run` |
| `fg-run` | ② 실행 | 계획을 Dynamic Workflow로 실행 — 미실행 plan이 하나면 메뉴 없이 즉시 실행, 여럿이면 선택 메뉴 제시(마지막 옵션 "모두 실행") | `.forge/backlog/`, `plan.md` | 결과 + `.forge/run.md` + `STATUS.md` (또는 `executed/`) | `fg-learn` |
| `fg-learn` | ③ 회고 | 학습을 문서로 승급, 다음 질의 도출 | `.forge/run.md`, `plan.md`, `executed/` | `.forge/retro/*.md` + 승급 | `fg-done` (크게 어긋났으면 `fg-ask`로 재그릴링) |
| `fg-done` | ④ 완료 | 한 바퀴 정리 — 회고 확인, `STATUS.md`를 done으로 마감, 아카이브, 활성 상태 비우기, 루프 닫기. `all` 모드는 실행된 작업 일괄 봉인(회고 skip·백로그 불가침) | `.forge/*` | `.forge/done/<날짜-slug>/` | `fg-ask` / 종료 |
| `fg-map` | 유틸리티(루프 밖) | 병렬 서브에이전트로 코드베이스를 `.forge/codebase/`에 매핑해, 그릴링이 코드를 다시 탐색하지 않고 지도를 읽게 한다(context rot 감소) | 코드베이스 | `.forge/codebase/*.md` (7개 문서) | — (`fg-ask`가 소비) |
| `fg-quick` | 경량 차선(루프 밖) | 사소한 작업용 — 가볍게 그릴링한 뒤 형식 산출물(ADR/plan/회고) 없이 바로 실행; 비-trivial로 드러나면 `fg-ask`로 bail | 사용자 요청 | `.forge/quick/LOG.md`에 항목 하나 | — (자체 완결) |
| `fg-status` | 리포터(루프 밖) | 읽기 전용 — `.forge/`를 조사해 모든 작업의 현황과 지금 필요한 다음 단계 하나를 출력; 아무것도 쓰지 않고 자동 실행도 안 함 | `.forge/*` (읽기 전용) | 출력 보고(파일 없음) | — (다음 단계 제안) |
| `fg-next` | 오케스트레이터(루프 밖) | fg-status의 상태 머신으로 다음 단계 하나를 도출해 한 줄로 알린 뒤 그 스킬을 곧바로 실행 — 보고만 하지 않음, one-shot; fg-status는 보고, fg-next는 행동 | `.forge/*` (자신은 읽기 전용) | 없음 — 호출한 스킬에 위임 | — (다음 스킬을 호출) |
| `fg-loop` | 오케스트레이터(루프 밖) | goal 주도 한정 재계획 루프 — 기초 질의로 기계 검증 가능한 정지 체크·fix-forward 재계획 범위·상한(기본 3라운드)을 `.forge/loop.md`에 못 박고, 체크가 전부 통과할 때까지 run → UAT → 회고 자동 skip → 봉인을 주행; 벽에서 멈춤 | goal(질의), `.forge/loop.md`, `backlog/` | 봉인된 작업들 + 생성된 fix-forward plan(`generated-by: fg-loop`) | — (종료 보고; 추후 `fg-learn`으로 일괄 승급) |
| `fg-tdd` | 토글(루프 밖) | `.forge/config.json`의 TDD 모드를 켜고 끔 — `fg-ask`가 작업마다 이 설정을 기본 답으로 질문하고, plan의 marker가 켜져 있으면 `fg-run`이 test-first로 실행 | `on`/`off`/(없음) | `.forge/config.json`(`tdd`) | — (설정만) |
| `fg-eco` | 토글(루프 밖) | eco 모드 토글 — 켜면 (1) `fg-run` 위임 서브에이전트를 `sonnet`으로 캡(내리기만; 세션 모델 불변), (2) Eco laziness-first 절제 규율(`ECO.md`)을 fg-run 서브에이전트·fg-ask 그릴링·현 세션에 주입 | `on`/`off`/(없음) | `.forge/config.json`(`eco`) | — (설정만) |
| `fg-merge` | 통합기(루프 밖) | `git merge` 뒤 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합 — ADR 번호 재부여(+교차참조)·CONTEXT 용어 병합·done 합침·브랜치 폴더 제거, 진짜 충돌 시 멈춤. git은 직접 안 돌림 | `.forge/branch/<branch>/` | 통합된 `.forge/` 문서 | — (통합 단계) |
| `fg-cleanup` | 은퇴기(루프 밖) | 오래된/대체된 ADR을 활성 결정 집합에서 은퇴 — 후보를 근거와 함께 제시하고, 승인 시 각 ADR을 `.forge/adr/retired/<NNNN>-slug.md`로 이동+supersede/retire 마킹. 번호 불변·재사용 금지·삭제 안 함. fg-ask는 `retired/`를 정답소스로 안 읽음 | `.forge/adr/*.md` | `.forge/adr/retired/*` | — (ADR 정비) |
| `fg-statusline` | 설정 유틸리티(루프 밖) | `.forge/`를 읽어 한 줄 진행 상태를 출력하는 bash 조각 스크립트를 설치하고 `settings.json`에 연결 — statusLine은 하나뿐이라 기존 것을 교체하지 않고 아래 별도 줄로 자동 래핑 | 기존 `settings.json` | `~/.claude/forge-statusline.sh` + `statusLine` 설정 | — (터미널 표시) |
| `fg-adversarial-review` | 리뷰 유틸리티(루프 밖) | fg-run↔fg-learn 사이 선택적 적대적 리뷰 — 결과가 틀렸다고 가정하고 6개 렌즈를 워크플로우 서브에이전트로 병렬 팬아웃, findings를 `.forge/review.md`에 기록하고 수정 필요 건은 승인 후 fix-forward plan으로; 봉인 게이트 아님, 무인 주행에선 자동 skip | `plan.md`·`run.md`·작업트리 diff·CONTEXT/ADR | `.forge/review.md` + (승인 시) fix-forward backlog plan | — (`fg-learn`/`fg-run`으로 복귀) |
| `fg-doctor` | health check(루프 밖) | 읽기 전용 무결성 검사 — `.forge/` 상태 계약(고아·STATUS 필드·slug 페어링·half-sealed)과 문서/매니페스트 정합(버전 3곳 동기·README 이중언어·CLAUDE.md 스킬 목록)을 검사해 위반을 severity·actionable 수정 안내와 함께 보고; 아무것도 안 쓰고 자동 수정 안 함 | `.forge/*`·매니페스트·README·CLAUDE.md (읽기 전용) | 출력 보고(파일 없음) | — (`fg-quick`/`fg-ask`로 수정) |
| `fg-drop` | 폐기 유틸리티(루프 밖) | 미완(미봉인) 작업 폐기 — backlog/활성 슬롯/`executed/` 회고대기/멈춘 goal 루프를 항목별 위험도와 함께 제시한 뒤 하드 삭제(기본·흔적 없음) 또는 `.forge/dropped/`로 보관; forge 상태만 지움(git·코드 불변) | `.forge/*`(미봉인) | 하드 삭제 또는 `.forge/dropped/<slug>/` | — (자체 완결) |

## 루프 스킬 (4단계)

### fg-ask — ① 질의·계획

`fg-ask`가 루프의 진입점이다 — 질의·분류와 그릴링을 함께 맡는다(기존 별도 `fg-plan` 단계를 `fg-ask`로 통합). "forge 시작", "새 작업", "이거 작업하자", "계획 다듬자" 같은 발화에서 트리거된다.

### fg-run — ② 실행

계획(`.forge/plan.md`, 또는 `.forge/backlog/`의 대기 plan)을 Claude Code Dynamic Workflow로 실행한다. 백로그에 미실행 plan이 정확히 하나면 확인 질문 없이 바로 실행하고, 여럿이면 미완료 목록을 선택 메뉴(마지막 옵션 "모두 실행")로 제시한 뒤 고른 작업을 활성 슬롯으로 승격해 실행한다. "forge run", "계획 실행", "이거 워크플로우로 돌려줘"에서 트리거된다(기존 "forge execute"도 alias). 실행할 plan이 없으면 돌지 않고, 이미 실행된 plan의 재실행을 경고한다.

### fg-learn — ③ 회고

실행 뒤 학습을 분류해 `CONTEXT.md`·ADR·회고 로그(`.forge/retro`)로 승급하고 다음 질의를 드러낸다. "forge learn", "회고하자", "이번 작업 정리해줘"에서 트리거된다. 항상 대화형이며 승급 절제를 지킨다.

### fg-done — ④ 완료

한 바퀴의 잔여물을 정리한다 — 회고를 확인하고, `STATUS.md`를 done으로 마킹하고, 작업을 아카이브하고, 활성 `.forge` 상태를 비워 루프를 닫는다. "작업 완료", "봉인", "이거 마무리"에서 트리거된다(기존 "작업 정리"·"forge complete"도 alias로 인식; 단 "forge cleanup"은 이제 별개의 ADR 은퇴 스킬로 라우팅된다). 활성 상태를 비우는 것이 같은 plan의 재실행을 막는다.

`all` 인자(`fg-done all`, "봉인 all"·"모두 봉인")는 **봉인 전용 batch 모드**다 — 이미 실행된 작업(활성 슬롯 + `.forge/executed/` 전부)의 회고를 무조건 일괄 skip하고 각자 개별 `done/`으로 봉인한다. `fg-next all`의 봉인 전용 사촌으로, **백로그의 미실행 작업은 promote·run하지 않는다**(그게 유일한 구분점). 검증 게이트(ADR-0009)는 불가침이라 `verified:` 봉인 가능값만 봉인하고 `failed`는 fg-run 수리로 라우팅하며, `pending`은 단일 경로와 같은 봉인 시점 UAT를 작업마다 반복한다. 봉인 직전 대상·제외 목록을 한 번 보여주고 go-ahead 하나를 받은 뒤 작업당 질문 없이 일괄 봉인한다. 회고 skip은 `retro: skipped (fg-done all — …)`로 감사 가능하게 남고 학습은 run.md에 보존된다 ([ADR-0023](../.forge/adr/0023-fg-done-all-batch-seal.md)).

## 루프 밖 유틸리티 (13개)

### fg-map

`fg-map`은 **루프 단계가 아니다** — 코드베이스가 크게 바뀌어 지도가 낡았을 때 돌리는 온디맨드 유틸리티로, "코드베이스 분석", "코드베이스 지도" 같은 발화에서 트리거된다.

### fg-quick

`fg-quick`도 **루프 밖**이다 — 사소한 작업(오타·작은 rename·버전 범프)용 경량 차선으로, 그릴링은 하되 가볍게 하고 형식 산출물(ADR/plan/회고) 없이 바로 실행하며 `.forge/quick/LOG.md`에 한 줄 기록한다. 그릴링 중 비-trivial로 드러나면 `fg-ask`(정식 루프)로 bail한다. "forge quick", "quick task", "이거 빨리 해줘" 같은 발화에서 트리거된다.

### fg-status

`fg-status`도 **루프 밖 읽기 전용 리포터**다 — 아무 때나 돌려 모든 작업의 현황(active slot·backlog·회고 대기·완료 이력·빠른 작업 로그)과 지금 필요한 다음 단계 하나를 본다; 아무것도 쓰지 않고 자동 실행도 하지 않는다. "forge status", "where am I", "어디까지 했지" 같은 발화에서 트리거된다.

### fg-next

`fg-next`는 **fg-status의 행동하는 형제로, 역시 루프 밖**이다 — 같은 다음 단계 하나를 (fg-status의 상태 머신을 재사용해 — 재구현하지 않고) 도출하되, 한 줄로 알린 뒤 그 스킬을 곧바로 **실행**한다 — 보고만 하고 멈추지 않으며 별도 승인을 기다리지 않는다. one-shot(한 단계만, 이후는 호출된 스킬 자체 핸드오프가 이어받음)이며 자신은 아무것도 쓰지 않고 모든 행동을 해당 스킬에 위임한다. "어디까지 했는지 기억 안 날 때 그냥 다음 걸 해줘"라는 차가운 재진입 진입점이다. **`all` 모드**(`fg-next all`)에서는 백로그가 빌 때까지 작업을 하나씩 끝까지 몰며 진행한다 — 선형 기계적 단계는 자동 추천 진행하고 **회고는 (divergence 무관) 항상 자동 skip**하되, **대화의 벽**(실패/검증불가 UAT·진짜 fork·빈 상태)에서는 멈춰 사람에게 넘긴다. `fg-run`의 "Run all"을 verify→done까지 확장한 모멘텀 상위집합이다 ([ADR-0010](../.forge/adr/0010-fg-next-all-momentum-mode.md)). "forge next", "다음 단계", "이어서 해줘", "fg-next all", "다음 전부 진행" 같은 발화에서 트리거된다.

### fg-loop

`fg-loop`는 **goal 주도의 세 번째 차선으로, 역시 루프 밖**이다 — 기초 질의(대화)로 **기계 검증 가능한 정지 조건**(에이전트가 실행 가능한 체크 — "AI가 만족되었다고 생각함"은 인정 안 됨), **승인된 fix-forward 재계획 범위**, **재계획 상한**(기본 3라운드)을 `.forge/loop.md`에 못 박고 초기 백로그 plan을 적재한 뒤, 체크가 전부 통과할 때까지 작업 루프 전체(run → UAT → 회고 항상 자동 skip → 봉인, `fg-next all`의 기계를 참조로 재사용)를 주행한다 — 실패한 체크에 직접 추적되는 fix-forward 작업을 승인 범위·상한 안에서만 자동 생성하고(각각 `generated-by: fg-loop` 마커가 달린 정상 PLAN-FORMAT plan), `verified: failed`는 단단한 벽 대신 자동 fix-forward 케이스가 된다. 벽 — 검증 불가 UAT·진짜 fork(범위 밖 수정 포함)·상한 소진·같은 체크 2연속 무진전 — 에서는 멈춰 사람에게 넘기고, goal 충족 시 요약을 보고하고 `loop.md`를 삭제한다. 기둥 1의 의도적·경계 있는 완화다 ([ADR-0016](../.forge/adr/0016-fg-loop-goal-driven-bounded-replan.md)); 회고 학습은 아카이브된 run.md에 남아 추후 사람이 `fg-learn`으로 일괄 승급한다. `loop.md`는 체크별 진행 원장(`## Check progress` — 결과·`×N` 연속 무진전·last-evidence·시도 slug·**`reflection`**)과 `wall:` 필드를 영속화한다: **Reflexion**(실패를 언어화해 다음 fix-forward에 주입 — fg-loop은 stateless 재개라 영속 필수)으로 다음 fix-forward가 *같은 접근을 반복하지 않고 다르게* 시도하게 만들고, no-progress 벽은 in-session 기억이 아닌 원장의 `×N≥2`로 판정하며, `fg-status`는 이 필드들을 읽어 *왜* 멈췄는지(맨 "재개"가 아니라) 보고한다(ADR-0016 2026-06-18 개정 2건). `reflection`은 드라이브 내 휘발 작업기억이지 회고가 아니다. "forge loop", "루프 시작", "조건 충족까지 반복" 같은 발화에서 트리거된다.

### fg-tdd

`fg-tdd`도 **루프 밖**이다 — `.forge/config.json`의 영속 TDD 모드 토글(`fg-tdd on|off`, 인자 없으면 상태 표시). `fg-ask`가 작업마다 이 설정을 기본 답으로 "이 작업 TDD로?"를 묻고, plan의 tdd marker가 켜져 있으면 `fg-run`이 test-first로 실행한다. "forge tdd", "tdd on/off", "TDD 켜/꺼" 같은 발화에서 트리거된다.

### fg-eco

`fg-eco`도 **루프 밖**이다 — `.forge/config.json`에 저장되는 eco 모드 토글(`fg-eco on|off`, 인자 없으면 상태 표시 + 켜기/끄기 선택). eco는 binary on/off이며, 켜지면 "forge 루프에서 낭비하지 않는다"는 한 원칙의 **두 효율 동작**이 활성화된다 ([ADR-0014](../.forge/adr/0014-fg-eco-subagent-model-tiering.md) 개정).

1. **모델 캡 (비용 절약).** `fg-run`이 위임 Dynamic Workflow 서브에이전트를 `sonnet`으로 캡한다 — **내리기만** 하고(티어를 올리지 않음, 이미 sonnet 이하면 상속 그대로), 사용자의 명시적 모델 지시가 우선하며, **메인 세션 모델은 건드리지 않는다**. 스킬은 세션 모델을 바꿀 수 없으므로(그래서 자동 단계별 모델 전환은 불가능 — ADR-0014의 전제) 설계(fg-ask)·완료(fg-done)는 사용자가 고른 모델 그대로이고, 결과는 **강력=메인 세션 · 일반=위임 실행**의 2단 티어다. `fg-map`은 의도적으로 범위 밖이다(지도 품질=그릴링 연료라 절감 폭 대비 리스크가 크다).
2. **Eco laziness-first 규율 (코드·계획 복잡도 절약).** 임베드된 절제 규율(`skills/fg-eco/ECO.md` — "가장 좋은 코드는 쓰지 않은 코드")이 세 곳에 적용된다: (a) **fg-run** 각 위임 서브에이전트 프롬프트에 6단 사다리(YAGNI → stdlib → 네이티브 → 기존 의존성 → 한 줄 → 최소 코드)와 핵심 제약이 prepend되고, (b) **fg-ask** 그릴링에 조용한 YAGNI 렌즈("이게 꼭 필요한가? 최소 버전은? 기존 메커니즘이 커버하나?")로 녹아들며, (c) **현 세션**도 `eco: true`를 **관측할 때마다** 그 규율을 채택한다 — 토글뿐 아니라 no-arg가 on 유지·fg-run 직접 실행·fg-ask 핸드오프 등 main-session eco-read에서 발동하는 **상태 기반**(모델은 여전히 불변; 단 어떤 스킬도 안 돈 새 세션 첫 시점은 세션 시작 훅이 없어 자가 채택 불가 — 처음 eco를 읽는 스킬이 집어감). 신뢰 경계 검증·데이터 손실 방지·보안·접근성·명시 요청은 절대 단순화하지 않으며, 비-trivial 로직은 runnable check 하나를 남긴다. 이 규율은 독립 스킬이 아니라 eco의 일부이고(별도 토글 없음), DietrichGebert의 Ponytail에서 차용·각색했다(크레딧은 README). 여기에 더해 ECO.md는 **출력 prose 압축**(실행·보고 prose 간결화 — 코드/명령/에러는 verbatim, 그릴링 질문·생성 문서·명시 요청 설명은 압축 제외; JuliusBrussee의 caveman 차용)도 담아 소통 토큰을 아낀다(ADR-0014 2차 개정).

"forge eco", "eco on/off", "에코 모드", "경제 모드", "lazy mode", "게으른 모드" 같은 발화에서 트리거된다.

### fg-merge

`fg-merge`는 **브랜치 격리의 통합 유틸리티로, 역시 루프 밖**이다 — 피처 브랜치를 `git merge`한 뒤, 그 브랜치의 `.forge/branch/<branch>/`를 기본 브랜치의 `.forge/`로 합친다: 브랜치 ADR을 다음 빈 번호로 재부여(교차참조 갱신)하고 CONTEXT 용어를 병합하며 `done/` 이력을 합치고 브랜치 폴더를 제거한다. 기계적 부분은 자동, 진짜 충돌(용어 재정의·ADR 모순)에서만 멈춰 묻고, git은 직접 돌리지 않는다. "forge merge", "fg-merge \<branch\>", "브랜치 통합" 같은 발화에서 트리거된다 ([ADR-0011](../.forge/adr/0011-branch-isolated-forge-root.md)).

### fg-cleanup

`fg-cleanup`은 **ADR 은퇴 유틸리티로, 역시 루프 밖**이다 — 오래된/대체된 ADR을 활성 결정 집합에서 은퇴시킨다: 은퇴 후보를 근거와 함께 제시하고, 사람이 승인하면 각 ADR을 `.forge/adr/retired/<NNNN>-slug.md`로 옮기며 `Superseded by ADR-NNNN` / `Retired (사유)` 한 줄을 단다. 번호는 절대 바뀌지 않고 재사용도 없으며, 아무것도 삭제하지 않는다(왜는 디스크에 남는다). `fg-ask`는 `retired/`를 정답소스로 읽지 않아 은퇴된 결정이 그릴링 연료에서 빠진다. 은퇴는 사람 승인이 원칙이고 자동이 아니며, 작업 봉인은 이 스킬이 아니라 `fg-done`이다. "forge cleanup", "ADR 정리", "ADR 은퇴", "오래된 ADR 치워" 같은 발화에서 트리거된다 ([ADR-0012](../.forge/adr/0012-fg-cleanup-renamed-to-fg-done-cleanup-retires-adrs.md)).

### fg-statusline

`fg-statusline`은 **일회성 설정 유틸리티로, 역시 루프 밖**이다 — 터미널 statusline에 forge 루프의 현재 위치를 띄운다. 자기완결 `bash` 조각(`scripts/forge-statusline.sh`)을 안정 경로(`~/.claude/forge-statusline.sh`)에 설치하는데, 이 스크립트는 `.forge/`를 읽어 한 줄을 출력한다 — 활성 작업과 그 단계, `🔁` goal 루프 지표, 또는 백로그 개수(idle이면 아무것도 안 띄움) — 그리고 `settings.json`에 연결한다. Claude Code는 statusLine을 **하나만** 허용하므로(플러그인이 등록할 수 없고 쌓기도 없음) 기존 statusline을 교체하지 않고, 현재 명령을 **자동 래핑**해 forge를 그 아래 별도 줄로 덧붙인다(기존 출력 보존). 의도적으로 얇은 표시 전용 판독자이며 — 다음 단계의 정답소스는 여전히 `fg-status`다. forge 업데이트 후 스크립트를 갱신하려면 다시 실행하면 된다. "forge statusline", "상태바", "statusline 설정" 같은 발화에서 트리거된다 ([ADR-0017](../.forge/adr/0017-statusline-integration.md)).

### fg-adversarial-review

`fg-adversarial-review`는 **선택적 리뷰 유틸리티로, 역시 루프 밖**이다 — `fg-run`과 `fg-learn` 사이에서 봉인 전 의도적으로 적대적인 두 번째 검토를 돌린다. 검토자는 공격자·반대자 입장을 취해 "이 결과가 틀렸다고 가정하고 증거를 찾자"에서 출발하며, 6개 렌즈 — 실패 지점·숨은 가정·요구사항 오해·보안/성능/데이터 손실·예상 못한 오용·약하거나 미검증된 근거 — 를 Dynamic Workflow의 서브에이전트로 병렬 팬아웃한다(실행 중 사람 입력이 필요 없어 기둥 1에 걸리지 않는다). findings는 `.forge/review.md`에 기록되고, 핸드오프에서 사람이 각 건을 판단한다 — 코드 결함은 (승인 후) fix-forward backlog plan(`generated-by: fg-adversarial-review`)이 되어 `fg-run`이 집어가고, 설계·요구사항 결함은 `fg-ask` 재그릴링으로 돌아가며, 수용된 findings는 회고로 들어간다. 순수 선택이고 봉인 게이트가 아니며(게이트는 `verified:`와 회고뿐), `fg-next all`·`fg-loop`는 findings 판단이 사람 몫이라 항상 skip한다. "adversarial review", "적대적 리뷰", "허점 찾아줘" 같은 발화에서 트리거된다 ([ADR-0018](../.forge/adr/0018-fg-adversarial-review.md)).

### fg-doctor

`fg-doctor`는 **읽기 전용 무결성 health check로, 역시 루프 밖**이다 — harness engineering의 `init.sh` health check를 forge에 적용한 것이다. `fg-status`가 *어디까지 했나*를 보고한다면, `fg-doctor`는 *상태가 건강한가*를 보고한다: `.forge/` 상태 계약(고아 `run.md`·STATUS 필드 손상·plan↔STATUS↔retro slug 페어링 불일치·half-sealed `done/`·backlog 마커와 task 번호 유일성)과 영속 문서/매니페스트(버전 3곳 동기·JSON 유효성·스킬 `name` frontmatter·스킬 개수 정합·CLAUDE.md 스킬 목록 완전성·README 이중언어 동기·ADR 번호/상호참조)를 검사해 각 위반을 error/warning/info로 분류하고 항목별 actionable 수정 안내를 출력한다. **아무것도 쓰지 않고 자동 수정도 하지 않는다** — 수정은 사람이 `fg-quick`(사소) 또는 `fg-ask`(비사소)로 하며, 다른 스킬이 자동 호출하지 않는다. "forge doctor", "무결성 검사", "상태 점검", "forge 진단", "health check", "정합성 확인", "check forge state" 같은 발화에서 트리거된다 ([ADR-0019](../.forge/adr/0019-fg-doctor-integrity-check.md)).

### fg-drop

`fg-drop`은 **폐기 유틸리티로, 역시 루프 밖**이다 — 더 이상 원하지 않는 **미완(미봉인) 작업**을 지운다: backlog plan·활성 슬롯·`executed/`의 회고 대기 작업·멈춘 goal `loop.md`가 대상이다(봉인된 `done/`은 대상 아님 — 그건 `fg-done`의 영역). 먼저 미완 항목을 **항목별 위험도**와 함께 제시하고(≤4개면 체크박스 대화, ≥5개면 번호 텍스트 목록), 별도 후속 질문으로 **하드 삭제**(기본·흔적 없음)와 `.forge/dropped/<slug>/` **보관** 중 하나를 고르게 한다. 불가역 삭제 전 확인 게이트가 한 번 더 막고, **이미 실행된 작업의 바뀐 코드는 되돌리지 않음**을 경고한다 — fg-drop은 forge 상태만 지우고 git·코드는 건드리지 않는다. 멈춘 goal 루프는 **통째로만** drop하며 멤버 task를 개별 제외하지 않는다(loop.md 멤버십 재동기화 로직을 만들지 않기 위함). `.forge/dropped/`는 휘발(gitignore)이라 `fg-doctor`는 관용하고 `fg-status`는 무시한다. "forge drop", "fg-drop", "작업 버리기", "이 작업 취소", "계획 지워", "백로그 비워", "drop task", "discard plan" 같은 발화에서 트리거된다 ([ADR-0021](../.forge/adr/0021-fg-drop-discard-incomplete-work.md)).
