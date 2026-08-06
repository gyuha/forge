# forge 스킬 상세

> README의 「스킬 카탈로그」를 풀어 쓴 문서. 각 스킬의 입력·출력·다음 단계, 그리고 트리거·동작·근거 ADR을 담는다. 한눈에 보는 요약 표는 [README](../README.ko.md#스킬-카탈로그)를 보라.

## 스킬 카탈로그 (전체 6열)

| 스킬 | 단계 | 한 줄 역할 | 입력 | 출력 | 다음 |
| --- | --- | --- | --- | --- | --- |
| `fg-ask` | ① 질의·계획 | grill-with-docs 원문 그대로 — 계획을 도메인·용어·결정에 대고 그릴링 | 사용자 요청 | `.forge/backlog/<slug>.md` + CONTEXT/ADR | `fg-run` |
| `fg-run` | ② 실행 | 계획을 Dynamic Workflow로 실행 — 미실행 plan이 하나면 즉시 실행, 2–3개면 선택 메뉴, 4개 이상이면 번호 목록(모두 실행 포함) | `.forge/backlog/`, `plan.md` | 결과 + `.forge/run.md` + `STATUS.md` (또는 `executed/`) | `fg-learn` |
| `fg-learn` | ③ 회고 | 학습을 문서로 승급, 다음 질의 도출 | `.forge/run.md`, `plan.md`, `executed/` | `.forge/retro/*.md` + 승급 | `fg-done` (크게 어긋났으면 `fg-ask`로 재그릴링) |
| `fg-done` | ④ 완료 | 한 바퀴 정리 — 회고 확인, `STATUS.md`를 done으로 마감, 아카이브, 활성 상태 비우기, 루프 닫기. 기계적 봉인은 결정론 스크립트(`forge-done.sh`/`.js`)가 처리(ADR-0030). `all` 모드는 실행된 작업 일괄 봉인(회고 skip·백로그 불가침) | `.forge/*` | `.forge/done/<날짜-slug>/` | `fg-ask` / 종료 |
| `fg-map` | 유틸리티(루프 밖) | 병렬 서브에이전트로 코드베이스를 `.forge/codebase/`에 매핑해, 그릴링이 코드를 다시 탐색하지 않고 지도를 읽게 한다(context rot 감소) | 코드베이스 | `.forge/codebase/*.md` (7개 문서) | — (`fg-ask`가 소비) |
| `fg-quick` | 경량 차선(루프 밖) | 사소한 작업용 — 가볍게 그릴링한 뒤 형식 산출물(ADR/plan/회고) 없이 바로 실행; 비-trivial로 드러나면 `fg-ask`로 bail | 사용자 요청 | `.forge/quick/LOG.md`에 항목 하나 | — (자체 완결) |
| `fg-status` | 리포터(루프 밖) | 읽기 전용 — `.forge/`를 조사해 모든 작업의 현황과 지금 필요한 다음 단계 하나를 출력; 아무것도 쓰지 않고 자동 실행도 안 함 | `.forge/*` (읽기 전용) | 출력 보고(파일 없음) | — (다음 단계 제안) |
| `fg-next` | 오케스트레이터(루프 밖) | fg-status의 상태 머신으로 다음 단계 하나를 도출해 한 줄로 알린 뒤 그 스킬을 곧바로 실행 — 보고만 하지 않음, one-shot; fg-status는 보고, fg-next는 행동 | `.forge/*` (자신은 읽기 전용) | 없음 — 호출한 스킬에 위임 | — (다음 스킬을 호출) |
| `fg-loop` | 오케스트레이터(루프 밖) | goal 주도 한정 재계획 루프 — 정지 체크·fix-forward 범위·상한을 못 박고 run → UAT → 회고 skip → 봉인을 주행; failed active task는 제자리 수리, 빈 슬롯의 실패 체크는 새 plan 생성 | goal(질의), `.forge/loop.md`, `backlog/` | 봉인된 작업들 + `repaired-by` 제자리 수리 / `generated-by` fix-forward plan | — (종료 보고; 추후 `fg-learn`으로 일괄 승급) |
| `fg-tdd` | 토글(루프 밖) | `.forge/config.json`의 TDD 모드를 켜고 끔 — `fg-ask`가 작업마다 이 설정을 기본 답으로 질문하고, plan의 marker가 켜져 있으면 `fg-run`이 test-first로 실행 | `on`/`off`/(없음) | `.forge/config.json`(`tdd`) | — (설정만) |
| `fg-eco` | 토글(루프 밖) | eco 모드 토글 — 켜면 (1) `fg-run` 위임 서브에이전트를 `sonnet`으로 캡(내리기만; 세션 모델 불변), (2) Eco laziness-first 절제 규율(`ECO.md`)을 fg-run 서브에이전트·fg-ask 그릴링·현 세션에 주입, (3) **eco 요약 표** — 작업 종료 지점(fg-run 핸드오프·fg-done 단일 봉인·배치/무인)의 산문을 요약+슬라이스 표로 교체 | `on`/`off`/(없음) | `.forge/config.json`(`eco`) | — (설정만) |
| `fg-merge` | 통합기(루프 밖) | `git merge` 뒤 브랜치 forge root 통합 — **결정론 스크립트(forge-merge.sh/.js)**가 시간ID ADR을 그대로 이동(충돌 시 다음 글자, cascade 재번호 없음)·task 번호 재부여·CONTEXT/retro/done/backlog 병합, 구조 충돌 시 nonzero exit(**AI 없이 CI 게이트 가능**). 코어 스크립트는 git-free(CI)·`fg-merge <branch>`는 대화형에서 git merge 대행(ADR `260717-10a`) | `.forge/branch/<branch>/` | 통합된 `.forge/` 문서 | — (통합 단계) |
| `fg-cleanup` | 은퇴기(루프 밖) | 오래된/대체된 ADR을 활성 결정 집합에서 은퇴 — 후보를 근거와 함께 제시하고, 승인 시 각 ADR을 `.forge/adr/retired/<NNNN>-slug.md`로 이동+supersede/retire 마킹. 번호 불변·재사용 금지·삭제 안 함. fg-ask는 `retired/`를 정답소스로 안 읽음 | `.forge/adr/*.md` | `.forge/adr/retired/*` | — (ADR 정비) |
| `fg-statusline` | 설정 유틸리티(루프 밖) | statusline에 forge 진행 상태를 두 모드 중 하나로 표시 — 방법 1(append)은 기존 statusline을 아래 별도 줄로 자동 래핑(얇은 forge fragment, ADR-0017), 방법 2(merge)는 daleseo식 시스템 정보(모델·디렉터리·⎇git·Context/크기+그라디언트 바+$비용/±라인/경과)+forge 진행을 의미 단위 그룹 대괄호로 한 스크립트에 출력하며 compact/full 밀도 토글(command 인자)까지 갖춘 통합 스크립트 설치(ADR-0029) | 기존 `settings.json` | `~/.claude/`의 statusline 스크립트 + `statusLine` 설정 | — (터미널 표시) |
| `fg-adversarial-review` | 리뷰 유틸리티(루프 밖) | fg-run↔fg-learn 사이 선택적 적대적 리뷰 — findings 기록, 승인된 코드 결함은 fix-forward plan으로 적재; 원 작업을 회고·봉인해 슬롯을 비운 뒤 fix plan 실행 | active `plan.md`·`run.md`·작업트리 diff·CONTEXT/ADR | `.forge/review.md` + (승인 시) fix-forward backlog plan | `fg-learn` → `fg-done` → `fg-run` |
| `fg-doctor` | health check(루프 밖) | 읽기 전용 무결성 검사 — **결정론 스크립트(forge-doctor.sh/.js, exit 0/1/2로 AI 없이 CI 게이트)**가 `.forge/` 상태 계약(고아·STATUS 필드·slug 페어링·half-sealed·**고아 브랜치 루트=fg-merge 잊음**)과 문서/매니페스트 정합(버전 3곳 동기·README 이중언어·CLAUDE.md 스킬 목록·**두 형식 ADR ID 유일성**)을 검사해 위반을 severity·수정 안내와 함께 보고; 아무것도 안 쓰고 자동 수정 안 함 | `.forge/*`·매니페스트·README·CLAUDE.md (읽기 전용) | 출력 보고(파일 없음) | — (`fg-quick`/`fg-ask`로 수정) |
| `fg-drop` | 폐기 유틸리티(루프 밖) | 미완 작업 폐기 — 단일/소수/다수에 맞는 선택 UI, goal 루프는 loop.md+멤버 미완 상태를 통째로 삭제/보관(done·비멤버 불변); forge 상태만 지움 | `.forge/*`(미봉인) | 하드 삭제 또는 `.forge/dropped/<slug>/` | — (자체 완결) |
| `fg-agents` | 생성 유틸리티(루프 밖) | 대화형 그릴링으로 프로젝트 도메인을 캐 역할을 도출하고 표준 `.claude/agents/<role>.md` 카드 생성(`description`에 "언제 쓰이나" 포함 → fg-run이 slice↔role 자동 매핑). 활성 ADR을 연료로 읽어 카드에 프로젝트 결정을 가볍게 반영. 카드는 세션 시작 시 로드되므로 생성 후 **재시작 필요**(ADR-0024). graceful·선택적 | `.forge/codebase/`·`CONTEXT.md`·활성 `.forge/adr/`(선택 연료) | `.claude/agents/<role>.md` 카드 | — (재시작 후 fg-run이 활용) |
| `fg-visual` | 시각 유틸리티(루프 밖) | 브라우저 시각 컴패니언 — obra/superpowers v6.1.1 Visual Companion vendoring(MIT 귀속). zero-dependency Node 서버가 에이전트가 push하는 HTML(목업·다이어그램·A/B 시각 비교)을 브라우저 탭에 실시간 표시하고, 사용자의 클릭·텍스트 입력을 이벤트(JSONL)로 받아 에이전트가 **답으로** 되읽음. 선택형 화면의 **필수 확정 버튼**을 누르면 터미널 턴 없이 바로 에이전트를 깨우며(탐색 클릭은 깨우지 않음), fg-ask 그릴링 중 시각적 질문에서 just-in-time 1회 제안(거절 시 재제안 없음), 이 스킬은 단독 진입점(ADR `260719-224442`·`260730-224259`·`260805-005436`) | 에이전트가 push하는 HTML | 모든 브랜치 최상위 `.forge/visual/<세션>/`(휘발·전역 예외) + 클릭 이벤트(JSONL) | — (`fg-visual stop`으로 종료) |
| `fg-agenda` | 계획 유틸리티(루프 밖) | 결정 대기열 — **아직 내리지 않은 결정**이 사는 자리. 목적지를 사람과 먼저 정하고 breadth-first 그릴링으로 결정해야 할 것을 캐내 `.forge/agenda.md` 한 파일(목적지·결정된 것·열린 질문·아직 또렷하지 않은 것(fog)·범위 밖)에 담은 뒤, 질문을 하나씩 `fg-ask`의 방법으로 해소하고 열린 질문이 0이면 스스로 삭제한다. **캐내는 것은 에이전트, 답은 전부 사람**(기둥 1) | 느슨한 아이디어(open) 또는 기존 `.forge/agenda.md`(working) | `.forge/agenda.md` + 해소가 낳은 조건부 ADR (빌드 가능해진 결정은 `fg-ask`가 백로그 plan으로) | — (`fg-agenda` 재트리거로 다음 질문; 빌드 가능해지면 `fg-ask`) |

## 핸드오프 표 — 모든 다음 단계 안내의 공통 형태

스킬이 끝에서 내는 다음 단계 안내는 고정 4행 **핸드오프 표**(`방금 한 것` · `다음 단계` · `시작하는 법` · `대안`)로 렌더된다. 다음 단계가 산문 사이에 묻혀 안 보이던 문제를 형태로 고친 것이며(통증은 **길이가 아니라 찾기 어려움**이었다), `eco` 게이트와 무관하게 **항상** 적용된다 — ADR `260805-231104`.

- **표는 사용자 언어로 렌더된다.** 라벨의 canonical 이름은 영문(`Just did` · `Next step` · `How to start` · `Alternative`)이고 — 스킬 문서가 영문이므로 셀을 가리킬 때 쓰는 이름이다 — 화면에 나갈 때 사용자 언어로 번역된다(한국어 세션이면 위 네 라벨). 경로·`.forge/` 필드·`/명령`만 verbatim이며, **자연어 트리거는 verbatim이 아니라** 스킬 `description`에 등록된 한/영 트리거 중 사용자 언어에 맞는 것을 골라 채운다.

- **적용 13곳** — 루프 4단계(`fg-ask`·`fg-run`·`fg-learn`·`fg-done`) + 가리킬 다음 단계가 실재하는 유틸리티 9개(`fg-status`·`fg-next`·`fg-loop`·`fg-quick`·`fg-map`·`fg-doctor`·`fg-agenda`·`fg-adversarial-review`·`fg-agents`).
- **제외 7곳** — `fg-tdd`·`fg-eco`·`fg-statusline`은 토글·설정이라 가리킬 다음이 없고 본문 한 줄이 표보다 짧다. `fg-cleanup`·`fg-drop`·`fg-visual`은 다음 단계 안내를 애초에 내지 않는다. `fg-merge`는 가장 좁은 근거로 제외됐다 — 그것이 내는 것은 **git 상태 복구 지시**("충돌 해소 → `git commit` → `fg-merge` 재실행")이지 루프 핸드오프가 아니다.
- **표는 메뉴가 아니다.** 진술형은 불변이다(ADR-0015) — `AskUserQuestion`으로 내지 않고, `대안` 행은 고르라는 질문이 아니며, 알리고 멈춘다. 체이닝은 여전히 `fg-next`의 몫이다.
- **조건부 다음 단계는 우선순위 규칙으로 채운다.** 한 분기를 행에 못 박고 나머지를 `대안`으로 밀면 표가 스킬이 방금 하지 말라고 한 것을 지시하게 된다(`fg-run`·`fg-learn`의 divergence 규칙이 그 예다).
- **무인 주행에서는 위임 스킬이 표를 렌더하지 않는다** — `fg-next all`·`fg-loop`에서 주행자가 억제하고 자기 단계(벽·완료)에만 낸다. 위임된 "fg-learn 실행" 안내가 사용자에게 새어 나가면 주행이 정지한다(`DRIVE.md`).
- **[`eco` 요약 표](#fg-eco)와는 다른 것**이다 — 그쪽은 *무엇을 했나*(축은 슬라이스, `eco: true`에서만), 이쪽은 *다음에 무엇을*. 둘이 함께 뜨는 지점에서는 각자 상대가 소유한 행을 뺀다.

단일 정의는 `skills/fg-next/HANDOFF.md` 하나이며 13곳이 이를 **참조**한다(복붙 금지 — `skills/fg-run/FORGE-ROOT.md`·`skills/fg-next/DRIVE.md`와 같은 관례).

## 루프 스킬 (4단계)

### fg-ask — ① 질의·계획

`fg-ask`가 루프의 진입점이다 — 질의·분류와 그릴링을 함께 맡는다(기존 별도 `fg-plan` 단계를 `fg-ask`로 통합). "forge 시작", "새 작업", "이거 작업하자", "계획 다듬자" 같은 발화에서 트리거된다.

**시작 시 미봉인 잔여를 닫는다 (STEP 0).** 새 작업을 시작하려는데 지난 작업이 봉인 안 된 채 남아 있으면, 남은 판단의 양에 따라 갈린다 — 판단이 없으면(검증이 봉인 가능값이고 회고도 해결됨, 또는 회고만 밀렸는데 `run.md`의 divergence가 미미함) **묻지 않고 봉인**하고 한 줄만 보고한 뒤 **같은 턴에 그릴링을 계속**한다. 판단이 남았으면(고-divergence·`verified: pending`·`verified: failed`·멈춘 goal 루프) 종전처럼 묻지만, **당신의 새 요청을 붙들고 있다가 마감 후 그 자리로 돌아온다** — "끝낸 뒤 fg-ask를 다시 치라"는 요구는 폐기됐다(그게 흐름을 끊던 본체였다). 사정거리는 **활성 슬롯 1건**이며 `.forge/executed/`의 park은 까먹은 잔여가 아니라 의도된 대기라 개수만 보고하고 손대지 않는다(`fg-done all`/`fg-learn` 소관). 검증 게이트([ADR-0009](../.forge/adr/0009-verification-gate-before-seal.md))는 불가침이고 fg-ask는 UAT를 직접 하지 않는다 ([ADR 260727-201115](../.forge/adr/260727-201115-fg-ask-auto-close-sealable-tail.md)).

### fg-run — ② 실행

계획(`.forge/plan.md`, 또는 `.forge/backlog/`의 대기 plan)을 Claude Code Dynamic Workflow로 실행한다. 백로그에 미실행 plan이 정확히 하나면 확인 질문 없이 바로 실행한다. 2–3개면 `AskUserQuestion` 선택 메뉴(마지막 옵션 "모두 실행"), 4개 이상이면 우선순위대로 번호 텍스트 목록+`all` 입력을 사용한다 — 도구의 4옵션 상한 때문에 후보를 잘라내지 않는다. 고른 작업만 활성 슬롯으로 승격해 실행한다. "forge run", "계획 실행", "이거 워크플로우로 돌려줘"에서 트리거된다(기존 "forge execute"도 alias). 실행할 plan이 없으면 돌지 않고, 이미 실행된 plan의 재실행을 경고한다.

프로젝트에 도메인 에이전트(`.claude/agents/`, 예: `fg-agents`가 생성)가 있으면 워크플로가 slice에 맞는 role을 `agentType`으로 호출해 실행한다 — role 카드 `description`의 "언제 쓰이나"로 매핑한다. **없으면 기존과 100% 동일**(기본 워크플로 서브에이전트, graceful). 단 `.claude/agents/`는 **세션 시작 시 1회 로드**되므로 세션 중 새로 만든 카드는 재시작해야 호출 가능하고, eco가 켜지면 `agentType` 호출도 sonnet 캡·ECO.md 주입을 받되 role 카드의 `model:` 명시가 우선한다([ADR-0024](../.forge/adr/0024-fg-agents-and-domain-agent-execution.md)).

### fg-learn — ③ 회고

실행 뒤 학습을 분류해 `CONTEXT.md`·ADR·회고 로그(`.forge/retro`)로 승급하고 다음 질의를 드러낸다. "forge learn", "회고하자", "이번 작업 정리해줘"에서 트리거된다. 항상 대화형이며 승급 절제를 지킨다.

### fg-done — ④ 완료

한 바퀴의 잔여물을 정리한다 — 회고를 확인하고, `STATUS.md`를 done으로 마킹하고, 작업을 아카이브하고, 활성 `.forge` 상태를 비워 루프를 닫는다. "작업 완료", "봉인", "이거 마무리"에서 트리거된다(기존 "작업 정리"·"forge complete"도 alias로 인식; 단 "forge cleanup"은 이제 별개의 ADR 은퇴 스킬로 라우팅된다). 활성 상태를 비우는 것이 같은 plan의 재실행을 막는다.

기계적 봉인(사전점검·게이트 강제·`STATUS.md` 마감·아카이브·슬롯 비우기)은 **결정론 스크립트 `forge-done.sh`/`.js`** 가 한 번에 처리하고, 스킬은 그 exit code로 라우팅만 한다 — fg-status([ADR-0020](../.forge/adr/0020-fg-status-deterministic-script.md))에 이어 스크립트 백킹된 스킬이다. 이 스크립트는 대화형 `fg-done`·`fg-done all`·`fg-next all`(위임) **세 봉인 경로가 공유하는 단일 봉인 프리미티브**로, read-only인 fg-status와 달리 파일을 이동하므로 **게이트-우선-비파괴**(검증·회고 게이트를 통과하기 전엔 아무것도 안 건드리고 사유와 함께 refuse)이며 behavior+parity 테스트로 보호된다 ([ADR-0030](../.forge/adr/0030-fg-done-deterministic-seal-script.md)).

**명시적 단일 `/fg-done`으로 봉인하면**, 마감 직후 아카이브된 plan·run·STATUS·retro에서 "요구사항 + 처리 내용"을 재구성한 **봉인 요약**(요구사항 / 처리 내용 / 회고 파일이 있을 때만 회고 챕터 / 검증·문서·아카이브 메타)을 화면에 렌더한다(파일로 저장하지 않고, 봉인 스크립트도 안 건드리는 판단 계층 산문). 반대로 `fg-done all`·`fg-next`(원샷 — autochain이든 fg-done 직접 위임이든 · all)·`fg-loop` 같은 **배치/무인 경로는 현행 간결 notice를 유지**한다 — 흐름 유지가 목적이고 autochain 뒤엔 회고가 방금 끝나 요약이 중복되기 때문. 이 비대칭의 근거는 [ADR-0032](../.forge/adr/0032-fg-done-single-seal-summary.md)이다.

`all` 인자(`fg-done all`, "봉인 all"·"모두 봉인")는 **봉인 전용 batch 모드**다 — 이미 실행된 작업(활성 슬롯 + `.forge/executed/` 전부)의 회고를 무조건 일괄 skip하고 각자 개별 `done/`으로 봉인한다. `fg-next all`의 봉인 전용 사촌으로, **백로그의 미실행 작업은 promote·run하지 않는다**(그게 유일한 구분점). 검증 게이트([ADR-0009](../.forge/adr/0009-verification-gate-before-seal.md))는 불가침이라 `verified:` 봉인 가능값만 봉인하고 `failed`는 fg-run 수리로 라우팅하며, `pending`은 단일 경로와 같은 봉인 시점 UAT를 작업마다 반복한다. 봉인 직전 대상·제외 목록을 한 번 보여주고 go-ahead 하나를 받은 뒤 작업당 질문 없이 일괄 봉인한다. 회고 skip은 `retro: skipped (fg-done all — …)`로 감사 가능하게 남고 학습은 run.md에 보존된다 ([ADR-0023](../.forge/adr/0023-fg-done-all-batch-seal.md)).

## 루프 밖 유틸리티 (16개)

### fg-map

`fg-map`은 **루프 단계가 아니다** — 코드베이스가 크게 바뀌어 지도가 낡았을 때 돌리는 온디맨드 유틸리티로, "코드베이스 분석", "코드베이스 지도" 같은 발화에서 트리거된다. 지도가 이미 있으면 **Update**(스탬프 `last_mapped_commit` 기준 diff 증분 — 7문서를 제자리 편집하므로 비용이 코드베이스 크기가 아니라 변경량에 비례)가 상용 경로이고, 스탬프가 빠졌거나 HEAD의 조상이 아니면(리베이스·force-push) 되묻지 않고 전체 Refresh로 폴백한다([ADR `260801-020258`](../.forge/adr/260801-020258-fg-map-diff-incremental-update.md)).

### fg-quick

`fg-quick`도 **루프 밖**이다 — 사소한 작업(오타·작은 rename·버전 범프)용 경량 차선으로, 그릴링은 하되 가볍게 하고 형식 산출물(ADR/plan/회고) 없이 바로 실행하며 `.forge/quick/LOG.md`에 한 줄 기록한다. 그릴링 중 비-trivial로 드러나면 `fg-ask`(정식 루프)로 bail한다. "forge quick", "quick task", "이거 빨리 해줘" 같은 발화에서 트리거된다.

### fg-status

`fg-status`도 **루프 밖 읽기 전용 리포터**다 — 아무 때나 돌려 모든 작업의 현황(active slot·backlog·회고 대기·완료 이력·빠른 작업 로그)과 지금 필요한 다음 단계 하나를 본다; 아무것도 쓰지 않고 자동 실행도 하지 않는다. "forge status", "where am I", "어디까지 했지" 같은 발화에서 트리거된다.

### fg-next

`fg-next`는 **fg-status의 행동하는 형제로, 역시 루프 밖**이다 — 같은 다음 단계 하나를 (fg-status의 상태 머신을 재사용해 — 재구현하지 않고) 도출하되, 한 줄로 알린 뒤 그 스킬을 곧바로 **실행**한다 — 보고만 하고 멈추지 않으며 별도 승인을 기다리지 않는다. one-shot(한 단계만, 이후는 호출된 스킬 자체 핸드오프가 이어받음)이며 자신은 아무것도 쓰지 않고 모든 행동을 해당 스킬에 위임한다 — 유일한 예외는 회고(`fg-learn`)가 재그릴링 권고 없이 정상 종료됐을 때로, 이땐 같은 호출에서 봉인(`fg-done`)까지 잇는다([ADR-0026](../.forge/adr/0026-fg-next-learn-done-autochain.md)). "어디까지 했는지 기억 안 날 때 그냥 다음 걸 해줘"라는 차가운 재진입 진입점이다. **`all` 모드**(`fg-next all`)에서는 백로그가 빌 때까지 작업을 하나씩 끝까지 몰며 진행한다 — 선형 기계적 단계는 자동 추천 진행하고 **회고는 (divergence 무관) 항상 자동 skip**하되, **대화의 벽**(실패/검증불가 UAT·진짜 fork·빈 상태)에서는 멈춰 사람에게 넘긴다. `fg-run`의 "Run all"을 verify→done까지 확장한 모멘텀 상위집합이다 ([ADR-0010](../.forge/adr/0010-fg-next-all-momentum-mode.md)). 무인 주행의 연속성은 **턴 내 계속**(위임 스킬의 진술형 정지를 턴 경계로 보지 않고 즉시 다음 단계 진행 — best-effort)과 **`/goal` 페어링**(진짜 턴 경계를 넘는 유일한 수단, 진입 시 붙여넣기 한 줄을 주경로로 제시; 없으면 한 사이클 후 멈춤이 정상 — 재트리거로 재개)의 두 축으로 이뤄지며, 이 공유 규율은 `skills/fg-next/DRIVE.md` 한 벌에 정의돼 fg-loop과 공유된다 ([ADR-0028](../.forge/adr/0028-unattended-drive-continuation-and-goal-pairing.md)). "forge next", "다음 단계", "이어서 해줘", "fg-next all", "다음 전부 진행" 같은 발화에서 트리거된다.

### fg-loop

`fg-loop`는 **goal 주도의 세 번째 차선으로, 역시 루프 밖**이다 — 기초 질의(대화)로 **기계 검증 가능한 정지 조건**(에이전트가 실행 가능한 체크 — "AI가 만족되었다고 생각함"은 인정 안 됨), **승인된 fix-forward 재계획 범위**, **재계획 상한**(기본 3라운드)을 `.forge/loop.md`에 못 박고 초기 백로그 plan을 적재한 뒤, 체크가 전부 통과할 때까지 작업 루프 전체(run → UAT → 회고 항상 자동 skip → 봉인, `fg-next all`의 기계를 참조로 재사용)를 주행한다. active slot이 비어 있는 stop-check 실패는 `generated-by: fg-loop` 정상 PLAN-FORMAT plan으로 만들고, **`verified: failed`는 별도 backlog plan을 만들지 않고** cap·scope·safety를 먼저 확인한 뒤 같은 active task를 `repaired-by: fg-loop` marker와 함께 제자리 수리해 fg-run의 failed 분기로 재실행한다. 이 구분이 활성 슬롯 1개 계약을 지키면서 `verified: failed`를 자동 fix-forward 케이스로 유지한다. 벽 — 검증 불가 UAT·진짜 fork(범위 밖 수정 포함)·상한 소진·같은 체크 2연속 무진전·tension(fix-forward가 이미 통과한 체크를 깨뜨리는 regression 핑퐁)·safety(승인 범위 안이라도 비가역 액션 클래스) — 에서는 멈춰 사람에게 넘기고, goal 충족 시 요약을 보고하고 `loop.md`를 삭제한다. 기둥 1의 의도적·경계 있는 완화다 ([ADR-0016](../.forge/adr/0016-fg-loop-goal-driven-bounded-replan.md)); 회고 학습은 아카이브된 run.md에 남아 추후 사람이 `fg-learn`으로 일괄 승급한다. `loop.md`는 체크별 진행 원장(`## Check progress` — 결과·`×N` 연속 무진전·**`regressed: ×N`**(pass→fail 회귀 횟수)·last-evidence·시도 slug·**`reflection`**)과 `wall:` 필드를 영속화한다: **Reflexion**(실패를 언어화해 다음 fix-forward에 주입 — fg-loop은 stateless 재개라 영속 필수)으로 다음 fix-forward가 *같은 접근을 반복하지 않고 다르게* 시도하게 만들고, no-progress 벽은 in-session 기억이 아닌 원장의 `×N≥2`로 판정하며, `fg-status`는 이 필드들을 읽어 *왜* 멈췄는지(맨 "재개"가 아니라) 보고한다(ADR-0016 2026-06-18 개정 2건). `reflection`은 드라이브 내 휘발 작업기억이지 회고가 아니다. "forge loop", "루프 시작", "조건 충족까지 반복" 같은 발화에서 트리거된다.

### fg-tdd

`fg-tdd`도 **루프 밖**이다 — `.forge/config.json`의 영속 TDD 모드 토글(`fg-tdd on|off`, 인자 없으면 상태 표시). `fg-ask`가 작업마다 이 설정을 기본 답으로 "이 작업 TDD로?"를 묻고, plan의 tdd marker가 켜져 있으면 `fg-run`이 test-first로 실행한다. "forge tdd", "tdd on/off", "TDD 켜/꺼" 같은 발화에서 트리거된다.

### fg-eco

`fg-eco`도 **루프 밖**이다 — `.forge/config.json`에 저장되는 eco 모드 토글(`fg-eco on|off`, 인자 없으면 상태 표시 + 켜기/끄기 선택). eco는 binary on/off이며, 켜지면 "forge 루프에서 낭비하지 않는다"는 한 원칙의 **세 효율 동작**이 활성화된다 ([ADR-0014](../.forge/adr/0014-fg-eco-subagent-model-tiering.md) 개정, ADR `260730-230321`).

1. **모델 캡 (비용 절약).** `fg-run`이 위임 Dynamic Workflow 서브에이전트를 `sonnet`으로 캡한다 — **내리기만** 하고(티어를 올리지 않음, 이미 sonnet 이하면 상속 그대로), 사용자의 명시적 모델 지시가 우선하며, **메인 세션 모델은 건드리지 않는다**. 스킬은 세션 모델을 바꿀 수 없으므로(그래서 자동 단계별 모델 전환은 불가능 — ADR-0014의 전제) 설계(fg-ask)·완료(fg-done)는 사용자가 고른 모델 그대로이고, 결과는 **강력=메인 세션 · 일반=위임 실행**의 2단 티어다. `fg-map`은 의도적으로 범위 밖이다(지도 품질=그릴링 연료라 절감 폭 대비 리스크가 크다).
2. **Eco laziness-first 규율 (코드·계획 복잡도 절약).** 임베드된 절제 규율(`skills/fg-eco/ECO.md` — "가장 좋은 코드는 쓰지 않은 코드")이 세 곳에 적용된다: (a) **fg-run** 각 위임 서브에이전트 프롬프트에 6단 사다리(YAGNI → stdlib → 네이티브 → 기존 의존성 → 한 줄 → 최소 코드)와 핵심 제약이 prepend되고, (b) **fg-ask** 그릴링에 조용한 YAGNI 렌즈("이게 꼭 필요한가? 최소 버전은? 기존 메커니즘이 커버하나?")로 녹아들며, (c) **현 세션**도 `eco: true`를 **관측할 때마다** 그 규율을 채택한다 — 토글뿐 아니라 no-arg가 on 유지·fg-run 직접 실행·fg-ask 핸드오프 등 main-session eco-read에서 발동하는 **상태 기반**(모델은 여전히 불변; 단 어떤 스킬도 안 돈 새 세션 첫 시점은 세션 시작 훅이 없어 자가 채택 불가 — 처음 eco를 읽는 스킬이 집어감). 신뢰 경계 검증·데이터 손실 방지·보안·접근성·명시 요청은 절대 단순화하지 않으며, 비-trivial 로직은 runnable check 하나를 남긴다. 이 규율은 독립 스킬이 아니라 eco의 일부이고(별도 토글 없음), DietrichGebert의 Ponytail에서 차용·각색했다(크레딧은 README). 여기에 더해 ECO.md는 **출력 prose 압축**(실행·보고 prose 간결화 — 코드/명령/에러는 verbatim, 그릴링 질문·생성 문서·명시 요청 설명은 압축 제외; JuliusBrussee의 caveman 차용)도 담아 소통 토큰을 아낀다(ADR-0014 2차 개정).
3. **eco 요약 표 (읽는 부담 절약).** 작업이 **끝나는** 지점 — fg-run 단일작업 핸드오프·fg-done 명시적 단일 봉인·배치/무인 경로(Run all·`fg-done all`·`fg-next` 위임 봉인·`fg-next all`·fg-loop) — 의 산문 핸드오프를 **교체**한다(추가가 아니라 교체 — 덧붙이면 글이 더 늘어 목적에 반한다): 헤더 한 줄(제목·`#task`·`verified`·divergence) + `▸ 요청`(plan Goal 한 줄) + `▸ 수행`(슬라이스 표: `#`·슬라이스·결과·계획 대비) + `▸ 다음`(다음 단계·트리거 한 줄). 배치 경로는 **작업당 1행** 표다. 2번의 압축이 *스타일* 지시라 지킴 여부가 보이지 않아 실제로 부족했다는 실증에서 나온 ***형태*** 규율이며, 표의 재료를 보장하기 위해 fg-run이 `run.md`에 **슬라이스별 한 줄 결과를 항상 기록**한다(eco 무관 — 나중 세션에서 봉인해도 표가 성립하도록). 검증 상태(`verified:`)는 봉인 가능 여부를 판단하는 정보라 헤더에서 절대 빠지지 않는다(ADR-0009). **실행 *중* narration은 그대로** 두어 어디서 막혔는지 보이고, 그릴링·회고·생성 문서(plan/run/retro/CONTEXT/ADR)·`fg-quick`은 제외이며, `eco: false`면 종전 산문 그대로다. 형태 정의는 `ECO.md` 한 곳에만 있고 fg-run·fg-done·`DRIVE.md`는 참조만 한다 (ADR `260730-230321`, GitHub 이슈 #7).

"forge eco", "eco on/off", "에코 모드", "경제 모드", "lazy mode", "게으른 모드", "요약 표" 같은 발화에서 트리거된다.

### fg-merge

`fg-merge`는 **브랜치 격리의 통합 유틸리티로, 역시 루프 밖**이다 — 피처 브랜치를 `git merge`한 뒤, 그 브랜치의 `.forge/branch/<branch>/`를 기본 브랜치의 `.forge/`로 합친다. 기계 통합은 **결정론 스크립트(`forge-merge.sh`/`.js`, dual dispatch)**가 수행한다: 브랜치의 시간기반 ADR을 그대로 옮기고(정확 ID 충돌 시 다음 빈 글자로 국소 해소 — cascade 재번호 없음, 교차참조 안 깨짐), incoming `done/`+`backlog/` plan의 `task:` 번호만 target과 안 겹치게 한 map으로 재부여한 뒤 CONTEXT·retro·done·backlog를 합치고 브랜치 폴더를 제거한다. 스크립트라 **AI 없이 CI 게이트로도 쓸 수 있고**(구조 충돌 시 nonzero exit), 진짜 충돌에서만 멈춰 사람에게 묻는다 — **용어 재정의**(용어는 `**이름**:` 항목이고 `## X`는 그룹 소제목이라, 두 글로서리가 `## Language`를 공유하는 것은 충돌이 아니다)·**incoming NNNN 충돌**·**미인식 CONTEXT 형식**(`## ` 헤딩만 있고 `**용어**:`가 0개면 용어 단위 병합이 조용히 아무것도 안 하므로, no-op 병합보다 정지가 안전하다) — **의미 ADR 모순은 스크립트 범위 밖으로 PR 리뷰가 담당**한다. 코어 스크립트는 git을 직접 돌리지 않아 CI에서 AI 없이 쓸 수 있고, 대화형 편의로 `fg-merge <branch>`는 `git merge`를 먼저 대신 돌려준다(스킬 계층 한정·기본 브랜치·충돌 시 그자리 정지 — ADR `260717-10a`). "forge merge", "fg-merge \<branch\>", "브랜치 통합" 같은 발화에서 트리거된다 ([ADR-0011](../.forge/adr/0011-branch-isolated-forge-root.md)). 팀에서의 merge 의식·충돌 권한·CI 게이트 사용법은 [team-workflow.md](./team-workflow.md)를 참조한다.

### fg-cleanup

`fg-cleanup`은 **ADR 은퇴 유틸리티로, 역시 루프 밖**이다 — 오래된/대체된 ADR을 활성 결정 집합에서 은퇴시킨다: 은퇴 후보를 근거와 함께 제시하고, 사람이 승인하면 각 ADR을 `.forge/adr/retired/<NNNN>-slug.md`로 옮기며 `Superseded by ADR-NNNN` / `Retired (사유)` 한 줄을 단다. 번호는 절대 바뀌지 않고 재사용도 없으며, 아무것도 삭제하지 않는다(왜는 디스크에 남는다). `fg-ask`는 `retired/`를 정답소스로 읽지 않아 은퇴된 결정이 그릴링 연료에서 빠진다. 은퇴는 사람 승인이 원칙이고 자동이 아니며, 작업 봉인은 이 스킬이 아니라 `fg-done`이다. "forge cleanup", "ADR 정리", "ADR 은퇴", "오래된 ADR 치워" 같은 발화에서 트리거된다 ([ADR-0012](../.forge/adr/0012-fg-cleanup-renamed-to-fg-done-cleanup-retires-adrs.md)).

### fg-statusline

`fg-statusline`은 **일회성 설정 유틸리티로, 역시 루프 밖**이다 — 터미널 statusline에 forge 루프의 현재 위치를 **두 설치 모드 중 하나로** 띄운다(ADR-0029). 두 모드는 forge 진행 줄을 위해 같은 얇은 fragment를 공유하고, 그 외에 무엇을 더 보여주고 누가 명령을 소유하느냐가 다르다.

- **방법 1 (append/wrap)** — 얇은 forge 전용 fragment(`scripts/forge-statusline.sh`/`.js`)를 안정 경로에 설치해, `.forge/`를 읽어 **의미 단위 그룹 대괄호 `[...]`로** 최대 2줄을 출력한다 — 1번째 줄은 `[🔁 rN/cap]` goal 루프 지표(있을 때)에 이어 `[⚒ #N slug · 색상 ✔ ask → ● run → ○ learn → ○ done · flag]` forge 그룹(현재 단계만 강조·`done`은 장식용·verified flag는 파이프라인 끝), 2번째 줄은 `[📋 N queued · 📝 M awaiting retro · ♻️ · 🧪]` 큐+모드 그룹(`🧪`=plan `<!-- tdd: on -->`·`♻️`=최상위 config `eco: true` — 실활동에서만 점등, idle 제외)이고, idle이면 아무것도 안 띄운다. 구분자는 기본 `·`(`FORGE_SL_SEP`)·무색이라 방법 1의 append 성격은 그대로다. Claude Code는 statusLine을 **하나만** 허용하므로 기존 명령을 **자동 래핑**해 forge를 아래 별도 줄로 덧붙인다(원본 보존). 시스템 정보는 일절 안 그리는 얇은 판독자다(ADR-0017; 그룹 대괄호·이모지 지시자만 ADR-0029 개정으로 반영).
- **방법 2 (merge)** — forge 소유 통합 스크립트(`scripts/forge-statusline-full.sh`/`.js` 트윈)가 daleseo식 **시스템 정보**와 **forge 진행**을 그룹 대괄호로 한 스크립트에 출력한다. `full`(4줄): `[모델|추론강도] [디렉터리|⎇git(↑N ↓N +!?)] [⏱|$비용|±라인]` / `[동적이모지 Context/크기 그라디언트바 N% | 5h … | 7d …]` / forge 그룹 / 큐+모드 그룹. `compact`(2줄): 시스템+바 한 줄 + forge 단일 그룹(세션 그룹 제외). 밀도는 command 위치 인자(`compact`/`full`, 기본 full)로 저장하며 새 config 키가 없다. 구분자는 `|`(fragment엔 `FORGE_SL_SEP=|` 위임), 색·그라디언트는 라이브 튜닝. forge 부분은 fragment에 **위임**해 단계 로직을 재사용하고(3중 복제 금지·parity 테스트), forge idle이면 forge 그룹만 사라지고 시스템 줄은 유지된다.

**설치 결정**: 기존 statusline 있으면 1/2 선택, 없으면 2 자동, Windows+기존이면 2만(방법 1 wrapper가 bash 전용). 방법 2가 기존을 교체할 땐 원본을 보존하고 복원법을 안내한다. 모드는 wired command 경로로, 밀도는 그 command의 위치 인자로 감지한다(둘 다 새 config 키 없음 — 방법 2 설치 시 밀도를 1회 묻고 인자로 박으며, refresh는 기존 밀도를 보존한다). 어느 모드든 다음 단계의 정답소스는 여전히 `fg-status`이며, forge 업데이트 후 스크립트 갱신은 다시 실행하면 된다. "forge statusline", "상태바", "statusline 설정" 같은 발화에서 트리거된다 ([ADR-0017](../.forge/adr/0017-statusline-integration.md) · [ADR-0029](../.forge/adr/0029-fg-statusline-combined-daleseo-dual-mode.md)).

### fg-adversarial-review

`fg-adversarial-review`는 **선택적 리뷰 유틸리티로, 역시 루프 밖**이다 — `fg-run`과 `fg-learn` 사이에서 봉인 전 의도적으로 적대적인 두 번째 검토를 돌린다. 검토자는 공격자·반대자 입장을 취해 "이 결과가 틀렸다고 가정하고 증거를 찾자"에서 출발하며, 6개 렌즈 — 실패 지점·숨은 가정·요구사항 오해·보안/성능/데이터 손실·예상 못한 오용·약하거나 미검증된 근거 — 를 Dynamic Workflow의 서브에이전트로 병렬 팬아웃한다(실행 중 사람 입력이 필요 없어 기둥 1에 걸리지 않는다). findings는 `.forge/review.md`에 기록되고, 핸드오프에서 사람이 각 건을 판단한다 — 코드 결함은 (승인 후) fix-forward backlog plan(`generated-by: fg-adversarial-review`)이 되지만 원 작업이 active slot을 점유하므로 **원 작업을 먼저 `fg-learn`→`fg-done`으로 봉인한 뒤** `fg-run`이 fix plan을 집어간다. 설계·요구사항 결함은 `fg-ask` 재그릴링으로 돌아가며, 수용된 findings는 회고로 들어간다. 순수 선택이고 봉인 게이트가 아니며(게이트는 `verified:`와 회고뿐), `fg-next all`·`fg-loop`는 findings 판단이 사람 몫이라 항상 skip한다. "adversarial review", "적대적 리뷰", "허점 찾아줘" 같은 발화에서 트리거된다 ([ADR-0018](../.forge/adr/0018-fg-adversarial-review.md)).

### fg-doctor

`fg-doctor`는 **읽기 전용 무결성 health check로, 역시 루프 밖**이다 — harness engineering의 `init.sh` health check를 forge에 적용한 것이다. `fg-status`가 *어디까지 했나*를 보고한다면, `fg-doctor`는 *상태가 건강한가*를 보고한다: `.forge/` 상태 계약(고아 `run.md`·STATUS 필드 손상·plan↔STATUS↔retro slug 페어링 불일치·half-sealed `done/`·backlog 마커와 task 번호 유일성)과 영속 문서/매니페스트(버전 3곳 동기·JSON 유효성·스킬 `name` frontmatter·스킬 개수 정합·CLAUDE.md 스킬 목록 완전성·README 이중언어 동기·ADR 번호/상호참조)를 검사해 각 위반을 error/warning/info로 분류하고 항목별 actionable 수정 안내를 출력한다. **아무것도 쓰지 않고 자동 수정도 하지 않는다** — 수정은 사람이 `fg-quick`(사소) 또는 `fg-ask`(비사소)로 하며, 다른 스킬이 자동 호출하지 않는다. "forge doctor", "무결성 검사", "상태 점검", "forge 진단", "health check", "정합성 확인", "check forge state" 같은 발화에서 트리거된다 ([ADR-0019](../.forge/adr/0019-fg-doctor-integrity-check.md)).

### fg-drop

`fg-drop`은 **폐기 유틸리티로, 역시 루프 밖**이다 — 더 이상 원하지 않는 **미완(미봉인) 작업**을 지운다: backlog plan·활성 슬롯·`executed/`의 회고 대기 작업·멈춘 goal `loop.md`가 대상이다(봉인된 `done/`은 대상 아님 — 그건 `fg-done`의 영역). 먼저 미완 항목을 **항목별 위험도**와 함께 제시한다(1개면 drop/cancel 2지, 2–4개면 체크박스, 5개 이상이면 번호 텍스트 목록). 별도 후속 질문으로 **하드 삭제**(기본·흔적 없음)와 `.forge/dropped/<slug>/` **보관** 중 하나를 고르게 한다. 불가역 삭제 전 확인 게이트가 한 번 더 막고, **이미 실행된 작업의 바뀐 코드는 되돌리지 않음**을 경고한다 — fg-drop은 forge 상태만 지우고 git·코드는 건드리지 않는다. 멈춘 goal 루프는 **통째로만** drop하며 멤버 task를 개별 제외하지 않는다(loop.md 멤버십 재동기화 로직을 만들지 않기 위함). `.forge/dropped/`는 휘발(gitignore)이라 `fg-doctor`는 관용하고 `fg-status`는 무시한다. "forge drop", "fg-drop", "작업 버리기", "이 작업 취소", "계획 지워", "백로그 비워", "drop task", "discard plan" 같은 발화에서 트리거된다 ([ADR-0021](../.forge/adr/0021-fg-drop-discard-incomplete-work.md)).

### fg-agents

`fg-agents`는 **생성 유틸리티로, 역시 루프 밖**이다 — 프로젝트의 **도메인 에이전트**를 만든다. 대화형 그릴링(기둥 1, 워크플로 밖)으로 프로젝트에서 반복되는·분리 가능한 작업 종류를 캐내 역할을 도출하고, 표준 Claude Code 서브에이전트 정의 `.claude/agents/<role>.md`(role 카드)를 자체 생성한다. 카드의 `description`에는 **"언제 쓰이나"를 반드시 담는다** — `fg-run`의 워크플로 빌더가 이 설명으로 plan의 work slice를 role에 자동 매핑하기 때문이다(ADR-0024는 plan 쪽 매핑 마커 대신 자동 매핑을 택했다). `.forge/codebase/` 지도·`CONTEXT.md`·**활성 `.forge/adr/`**가 있으면 그릴링 연료로 읽고, 없으면 직접 탐색하거나 사용자 설명만으로 진행한다(graceful·하드 의존 없음). ADR은 프로젝트의 문서화된 결정이므로, 관련 결정을 카드 system prompt에 **가볍게 반영**해(번호를 기계적으로 인용하지 않고 prose로) 카드가 generic하지 않고 프로젝트에 정합하게 한다 — `retired/`는 안 읽고(ADR-0012), 비기본 브랜치는 read-overlay(ADR-0011)로 fg-ask의 ADR 읽기 규율과 동일하다. 역할은 사람이 승인한 부분집합만 카드가 되며, 마땅한 seam이 없으면 **0개**도 정직한 결과다(역할을 억지로 만들지 않음 — fg-cleanup의 절제와 동형). **핵심 제약(ADR-0024)**: `.claude/agents/`는 **세션 시작 시 1회 로드**되므로 세션 중 만든 카드는 동적 픽업되지 않는다 — fg-agents가 생성한 카드는 **세션을 재시작해야** fg-run이 로드·`agentType` 호출한다. 운영 흐름은 **생성 → 재시작 → 활용**이며, 재시작은 프로젝트 셋업 시 1회뿐이다. 생성한 카드는 forge `.forge/` 상태가 아니라 프로젝트 자산이라 git으로 커밋한다(git은 직접 안 돌림). **루프 스킬이 fg-agents를 안내한다**: `fg-ask`(그릴링 중)·`fg-run`(실행 중)은 특화 역할이 반복적으로 도움될 것으로 판단되고 프로젝트에 맞는 카드가 없을 때 fg-agents를 **좁게·offered로** 한 번 안내한다(자동 호출 아님, 재시작 게이트 명시) — fg-agents의 "역할은 제 몫을 해야 한다" 절제와 동형. "forge agents", "도메인 에이전트 만들어", "에이전트 팀 구성", "create project agents", "domain agents", "agent roles" 같은 발화에서 트리거된다 ([ADR-0024](../.forge/adr/0024-fg-agents-and-domain-agent-execution.md)).

### fg-visual

`fg-visual`은 **시각 컴패니언 유틸리티로, 역시 루프 밖**이다 — obra/superpowers v6.1.1의 **Visual Companion**을 MIT 귀속과 함께 vendoring했다. zero-dependency Node 서버(`scripts/server.cjs` 등 5파일)가 에이전트가 push하는 HTML(목업·다이어그램·A/B 시각 비교)을 브라우저 탭에 실시간 표시하고, 사용자의 클릭·텍스트 입력을 이벤트(JSONL)로 받아 에이전트가 되읽는다. **브라우저는 표시 전용이 아니라 보조 답변 채널이다** — 선택형 질문에서 클릭이 답으로 성립하고 화면에 텍스트 입력칸을 둘 수 있으며, 두 채널의 답은 병합해 읽고 모순될 때만 한 줄로 되묻는다. 선택형 화면에는 **필수 확정 버튼**을 두어, 확정 클릭이 오면 터미널 턴 없이 바로 대화를 재개하고(탐색 클릭은 깨우지 않는다), 기둥 1은 근거를 옮겨 온전하다 — 재개가 터미널 턴이라서가 아니라 브라우저가 Dynamic Workflow의 런타임 입력이 아니라서다(ADR `260730-224259`·`260805-005436`). 세션 파일은 **모든 브랜치에서 최상위** `.forge/visual/<세션>/`(휘발·gitignore)에 둔다 — `.forge/config.json`·`.forge/codebase/`와 같은 전역 예외로, 브랜치 루트로 이동하지 않는다. 세션 키 URL 인증·서버 재시작/브라우저 재연결 생존·4시간 유휴 자동 종료를 갖추며, 텔레메트리·원격 자원은 없다. **fg-ask 통합**: fg-ask는 그릴링 **시작 전에** 이 작업이 시각적 표면을 건드리는지 한 번 판단해 두고(판단 시점), 시각적 질문이 처음 실제로 도착할 때 just-in-time으로 **1회만** 제안한다(제안 시점 — 단독 메시지, 거절 시 재제안 없음). 판단과 제안을 분리한 이유는 둘을 합쳐 두면 제안이 아예 발동하지 않았기 때문이다. 수락하면 fg-ask가 `../fg-visual/VISUAL.md`와 `scripts/`를 **파일 참조**로 직접 사용하고(ECO.md·FORGE-ROOT.md와 같은 단일 정의 관례 — 복붙 금지), Output(핸드오프) 시 서버를 종료한다. 이 스킬 자체는 단독 진입점이다 — `fg-visual`로 시작, `fg-visual stop`으로 종료. "forge visual", "visual companion", "시각적으로 보여줘", "목업 보여줘", "브라우저로 보여줘", "화면으로 비교해줘" 같은 발화에서 트리거된다 (ADR `260719-224442`).

### fg-agenda

`fg-agenda`는 **결정 대기열로, 역시 루프 밖**이다 — forge에 **아직 내리지 않은 결정**이 사는 자리를 준다. forge의 산출물은 전부 *빌드* 산출물이고(`plan.md`의 Work slices) ADR은 **이미 내려진** 결정을 기록하므로, 안개 속의 큰 작업은 억지로 완결된 계획이 되거나 결정이 대화·회고 산문에 흩어져 사라진다. `fg-agenda`는 그 구멍을 `.forge/agenda.md` **한 파일**로 메운다 — 목적지·결정된 것·열린 질문·아직 또렷하지 않은 것(fog)·범위 밖의 5개 절이며, 활성 의제는 **1개**(활성 슬롯 1개 규율과 같은 모양)이고 위치는 해석된 forge 루트(브랜치별 — `loop.md`와 같은 취급, 전역 예외 아님)다. 열린 질문이 0이 되면 **agenda.md를 삭제한다**(`fg-loop`가 goal 충족 시 `loop.md`를 삭제하는 선례) — 영속 흔적은 의제가 낳은 ADR과 백로그 plan이라 아카이브를 새로 만들지 않는다.

**자율성의 경계가 이 스킬의 정체다: 에이전트는 무엇을 결정해야 하는지 찾아내고, 답은 전부 사람이 한다.** 에이전트 몫은 breadth-first 그릴링으로 열린 결정을 캐내기·fog와 질문 구분(테스트는 *지금 질문을 정확히 진술할 수 있나*이지 답할 수 있나가 아니다)·"지금 답 가능한 것을 위로" 순서 세우기·다음 질문 고르기·fog 승격과 범위 밖 판정이고, 사람 몫은 **목적지 정하기와 모든 답**이다. **에이전트는 자기 질문에 스스로 답하지 않는다** — 그러면 의제의 "결정된 것"은 결정이 아니라 에이전트의 추측이 되고 기둥 1이 깨진다. 두 모드는 `agenda.md` 존재 여부로 갈린다: **open**(의제 없음)은 목적지를 사람과 먼저 정하고 breadth-first로 그릴링해 의제를 쓴 뒤 **멈춘다** — 아무 질문도 해소하지 않으며, 안개가 전혀 안 나오면 의제를 만들지 않고 `fg-ask`를 가리킨다. **work**(의제 있음)은 질문 **하나**를 골라(사용자 지목이 없으면 열린 질문의 첫 줄 = frontier) `fg-ask`의 그릴링 방법으로 해소하고, 답을 `## 결정된 것` 한 줄로 적고 세 조건을 넘으면 ADR도 쓰며, 새 질문 추가·또렷해진 fog 승격·범위 밖 이동으로 다시 차팅한다.

**의제는 결정만 소유한다** — 결정이 빌드 가능해지는 순간 그 줄은 의제를 떠나 `fg-ask`가 적재하는 평범한 백로그 plan이 된다(이 선이 없으면 의제가 **두 번째 백로그**가 되어 `fg-next`·`fg-run`이 무엇을 봐야 하는지 모호해진다). 의존 엣지·blocking은 만들지 않고(파일 하나를 위→아래로 읽는 것이 곧 frontier), 티켓 유형 분류도 만들지 않으며(research/prototype/grilling/task는 해소기의 이름이고 forge엔 이미 다 있다 — 조건부 deep research·`fg-visual`·`fg-ask`·`fg-quick`), 스크립트도 만들지 않는다. 그릴링 방법은 `fg-ask`의 단일 정의를 **참조**할 뿐 복붙하지 않으며 출력만 다르다(백로그 plan이 아니라 의제 한 줄 + 조건부 ADR). `fg-next`/`fg-status`의 다음 단계 사슬에는 **편입되지 않는다** — 그 사슬은 진행 중인 한 작업의 것이고 의제는 병행하는 계획 표면이라 `fg-status`는 한 줄 보고만 한다. 형제 유틸리티 `fg-loop`의 **거울상**이다: `loop.md`는 기계 검증 가능한 정지 조건 + 무인 주행, `agenda.md`는 판단 정지 조건 + HITL — 같은 모양의 계약 파일, 반대 성질의 멈춤. 개념은 `mattpocock/skills`의 **Wayfinder**(MIT) 각색이며 **코드 vendoring이 아니라 개념 각색**이다(파일 복사 없음, 이름은 forge 어휘로 — forge에서 "지도"는 이미 `fg-map`의 것이다). "forge agenda", "의제", "결정 대기열", "뭘 결정해야 하는지 정리해줘" 같은 발화에서 트리거된다 (ADR [`260805-201313`](../.forge/adr/260805-201313-fg-agenda-decision-queue.md)).
