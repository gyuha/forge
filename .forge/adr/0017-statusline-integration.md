# statusline 통합 — forge 최초의 런타임 스크립트 + 얇은 두 번째 상태 판독자

> **후속:** [ADR-0029](0029-fg-statusline-combined-daleseo-dual-mode.md)가 이 얇은 forge-전용 판독자 위에 **이중 모드**를 얹었다 — 방법 1(append)은 이 문서의 wrap 그대로, 방법 2(merge)는 daleseo식 시스템 정보+forge를 하나로 합친 통합 스크립트(`forge-statusline-full.sh`/`.js`)를 신설한다. 이 문서의 결정(얇은 forge fragment·설정 시 복사·절대경로·stdin cwd·bash+js 트윈)은 방법 1에서 불변으로 남는다.

## 맥락

forge는 실행 코드가 한 줄도 없는 리포다(전부 Markdown/JSON, 빌드·테스트 없음). 그런데 Claude Code의 statusLine은 **플러그인이 직접 등록할 수 없고**(`settings.json`의 `statusLine` 키로만 설정), 명령은 stdin JSON을 받아 텍스트를 뱉는 **비대화형 셸 명령**이라 에이전트가 읽는 Markdown 스킬(fg-status)을 호출할 수 없다. 또 statusLine은 **동시에 하나뿐**이라 사용자가 이미 쓰는 다른 플러그인 statusline에 "추가"가 불가능하다(합성만 가능). 따라서 forge 상태를 statusline에 띄우려면 `.forge/`를 직접 읽는 **실제 bash 스크립트**가 필요하다.

## 결정

`fg-statusline` 유틸리티 스킬(루프 밖)과 자기완결 bash 스크립트 `scripts/forge-statusline.sh`를 도입한다. 스크립트는 cwd 기준으로 forge 루트(ADR-0011의 브랜치별 해석 포함)를 풀어 활성 슬롯·`executed/`·백로그·`loop.md`를 읽고 **현재 단계 한 줄**(`⚒ <slug>:<stage> <flag>`, loop 주행 시 `🔁 rN/cap` 동반)을 출력한다. fg-status가 다음-단계 우선순위 머신의 단일 정의처로 남고, 이 스크립트는 **표시 전용의 의도적으로 얇은 두 번째 상태 판독자**다(우선순위 머신을 재현하지 않는다). `fg-statusline` 스킬은 한 번 실행 시 스크립트를 안정 경로 `~/.claude/forge-statusline.sh`로 복사하고, 사용자 `settings.json`의 기존 statusLine을 stdin을 양쪽에 흘려보내는 래퍼로 감싸 forge 조각을 **아래 별도 줄**로 덧붙인다(기존 출력 불변).

## 고려한 대안

- **상태 노출 방식**: 전용 `.forge/state.json`을 두고 모든 루프 스킬이 갱신 — 로직 중복은 없지만 13개 스킬에 쓰기 의무를 추가하고 드리프트할 새 계약면이 생겨 기각. 표시용 얇은 직접 판독을 택했다(상태는 이미 파일 위치+STATUS.md 필드에 인코딩됨).
- **스크립트 언어**: node(견고한 파싱, 크로스플랫폼) 대신 bash+git을 택했다 — end-user에게 새 런타임 의존성을 강제하지 않기 위해(git은 이미 암묵 필요, STATUS.md는 단순 `key: value` 줄).
- **전달·갱신**: SessionStart 훅 자동 복사(업데이트 자동 반영) 대신 설정 시 복사를 택했다 — forge에 '훅'이라는 새 아티팩트와 매 세션 실행을 도입하지 않기 위해. 스크립트가 거의 안 변해 "업데이트 후 재실행" 비용이 작다. (플러그인 설치 경로 `~/.claude/plugins/cache/<hash>/`는 업데이트마다 바뀌어 직접 참조 불가.)

## 결과

- forge에 **첫 실행 코드(bash)와 첫 테스트 인프라**(fixture 기반 bash 테스트)가 생긴다 — 두 기둥(문서=연료, no-code)의 의도적·경계 있는 예외다(fg-quick의 기둥 2 완화와 동형 선례).
- forge 상태 머신이 **두 곳**에 존재하게 된다: fg-status(정본·다음 단계)와 이 스크립트(얇은 표시본). 단계 매핑(bucket→stage)이 바뀌면 양쪽을 같이 고쳐야 한다.
- 스크립트 업데이트는 사용자가 `fg-statusline`을 재실행해야 안정 경로에 반영된다(자동 아님).

## 개정 (2026-06-14) — 강건성 재설계

초기 구현이 사용자 환경에서 **statusline 전체가 공백**이 되는 장애를 냈다(claude-hud까지 사라짐). 원인 진단과 함께 다음을 결정했다(핵심 결정 — thin reader + 설정 시 복사 — 은 불변, 메커니즘만 강건화):

- **`settings.json`의 `statusLine.command`는 절대경로로 쓴다 — `~`(tilde) 금지.** statusLine 명령은 호스트가 tilde를 확장한다는 보장이 없어, 리터럴 `~/.claude/...`가 해석 실패 시 래핑된 원본까지 포함해 **전체 statusline이 조용히 공백**이 된다(유력 장애 원인). 기존에 작동하던 statusline(claude-hud·powerline)이 모두 절대경로/인라인이었던 것과 일치시킨다. `$HOME`/`$CLAUDE_CONFIG_DIR`을 설정 시점에 풀어 절대경로를 기록한다.
- **fragment가 stdin 세션 JSON의 `cwd`를 파싱한다(`workspace.current_dir` → `$PWD` 폴백).** 원래 "무파싱/jq-free, cwd는 셸 작업디렉터리 가정"이었던 설계의 **의도적·부분적 반전**이다 — 호스트가 프로젝트 밖에서 statusLine을 실행하면 active여도 영원히 공백이던 문제를 없앤다. 여전히 jq는 안 쓴다(방어적 `sed` 추출). 인터랙티브 실행에서 블록되지 않도록 stdin이 tty가 아닐 때만 읽는다.
- **합성 래퍼는 committed generic 스크립트(`scripts/forge-statusline-wrapper.sh`) + 원본 보존 파일(`forge-statusline-orig.sh`)로 한다.** 원본 명령을 별도 파일에 verbatim 저장하므로 래퍼 자체엔 설치별 치환이 없어 fragment처럼 복사만 하면 된다(중첩 따옴표 escaping 회피). 래퍼는 같은 JSON을 원본과 fragment **양쪽에 stdin으로 흘려** cwd 해석을 일치시키고, 원본을 먼저 출력한 뒤 fragment를 별도 줄로 덧붙인다. SKILL.md의 과거 "inline 임베드" 서술은 이 구현에 맞춰 정정했다. **(개정 2026-06-14)** 래퍼는 동반 파일(`forge-statusline-orig.sh`·`forge-statusline.sh`)을 **자기 스크립트 위치**(`$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`)에서 해석한다 — 런타임 `CLAUDE_CONFIG_DIR`에 의존하면 statusLine 프로세스가 그 변수를 export 안 하는 custom config dir 환경에서 동반 파일을 못 찾아 전체 statusline이 조용히 공백이 되는 결함(Codex 적대적 리뷰 지적)을 제거. 동반 파일은 래퍼와 같은 디렉터리에 복사되므로 자기 위치 해석이 항상 옳다. custom config dir·`CLAUDE_CONFIG_DIR` 미설정 회귀 테스트 추가.
- **테스트가 늘었다**: fragment에 stdin-cwd 케이스 추가(`forge-statusline.test.sh`), 래퍼 동반 테스트 신설(`forge-statusline-wrapper.test.sh` — 원본 보존·forge 행 추가·idle 무행·stdin 재공급).
- statusLine 설정은 **Claude Code 재시작 후** 적용된다 — 설정 직후 같은 세션에서 판단하면 안 된다(SKILL.md Notes·Handoff에 명시).

## 개정 (2026-07-02) — 단일 세그먼트 우선순위 표시 → 2줄 상시 표시 + progress-dots 파이프라인

최초 결정(위)은 활성 슬롯 > `executed/` > `backlog` **우선순위 중 하나만** 보여주는 "단일 세그먼트" 모델이었다 — 활성 작업이 있으면 대기 중인 backlog·회고 대기 개수는 화면에서 완전히 가려졌다. 사용자 요청(task 이름 + ask/run/learn 진행 표시를 색상 등 여러 방식으로 구상해달라는 fg-ask 그릴링)을 반영하며 이 우선순위 은닉 모델을 바꿨다.

**결정**: 세그먼트를 우선순위로 하나만 고르는 대신, 해당되는 상태를 **독립적으로 판단해 최대 2줄을 동시에** 출력한다.

- **1번째 줄** (활성 슬롯 `plan.md`가 있을 때만): `⚒ [🔁 rN/cap ]<slug> | ✔ ask → ● run → ○ learn → ○ done | [flag]`. 파이프라인은 forge 루프 전체(ask/run/learn/done) 네 단계를 항상 다 그리되, 지난 단계는 초록 `✔`, 현재 단계는 강조색 `●`, 다음 단계는 흐린 `○`로 구분한다. `done`은 fg-status의 버킷→stage 매핑에 실재하는 상태가 아니라(봉인되면 추적 버킷을 아예 벗어나 `done/`로 이동) 루프 전체 그림을 완성하기 위해 덧붙인 장식용 4번째 단계로, 항상 `○`(예정)로만 그려진다 — fg-ask 그릴링에서 "단순히 4번째 단계로서 항상 표시"를 선택한 결과다. 활성 슬롯은 backlog에서 promote된 뒤에만 생기므로(fg-ask는 항상 backlog에 적재) `ask`는 이 줄이 뜨는 한 항상 "완료"로 그려진다 — 마찬가지로 의도된 동작이다.
- **1번째 줄의 예외**: 활성 슬롯이 없고 goal loop(`loop.md`)만 도는 중이면 `🔁 rN/cap` 단독 줄(⚒ 프리픽스 없음)을 대신 보여준다.
- **2번째 줄** (backlog 또는 `executed/` 중 하나라도 있으면, **1번째 줄 유무와 무관하게 항상**): `📋 N queued · 📝 M awaiting retro`(해당 없는 쪽은 생략, ⚒ 프리픽스 없음).
- 색상 값 자체(완료=초록/현재=강조/예정=흐림)는 스크립트에 고정하고 `.forge/config.json`에 별도 설정 키를 두지 않는다 — 표시 방식을 여러 개 만들어 토글 가능하게 하는 건 요청 범위를 넘는 speculative 확장으로 보고 기각했다. 정확한 ANSI 색상 코드 값(어떤 색조를 쓸지)은 라이브 터미널에서 눈으로 보고 조정 가능한 구현 세부로 열어뒀다.

**고려한 대안**: backlog-only/executed-only 상태에서도 대표 task 1개를 뽑아 `ask` 포인터를 실제로 보여주는 확장안을 검토했으나(예: `<slug> | ▶︎ ask > run > learn | (+N more)`), "여러 개 중 어떤 걸 대표로 보여줄지" 규칙이 새로 필요해 범위가 커져 기각했다 — `ask`는 이 스크립트에서 실질적으로 결코 현재 포인터가 되지 않는 채로 남는다(항상 배경 완료 표시로만 등장).

**트레이드오프**: 정보량(활성 작업 + 대기 요약을 한눈에) vs 줄 수(최대 2줄, 기존 1줄보다 statusline 세로 공간을 더 씀 — 래퍼가 원본 statusline에 추가하는 행까지 합치면 최대 3줄). 우선순위 은닉으로 인한 "backlog에 뭔가 쌓였는데 안 보인다"는 혼란을 없애는 쪽을 택했다.

**결과**:
- `forge-statusline.sh`/`forge-statusline.js`가 최대 2줄을 출력하도록 재작성됨 (ADR-0022 패리티 유지 — 색상 포함 동일 출력).
- 기존 fixture 테스트(`forge-statusline.test.sh`, `forge-statusline.parity.test.sh`, `forge-statusline-wrapper.test.sh`)가 새 포맷 기대값으로 갱신됨. 색상 값은 라이브 튜닝 대상이라 테스트는 ANSI 코드를 벗겨내고 텍스트/기호만 비교한다.
- `skills/fg-statusline/SKILL.md`의 "What the fragment prints" 섹션이 새 2줄 모델로 갱신됨.
- fg-status의 다음-단계 우선순위 머신(어떤 스킬로 갈지 판단)은 이 표시 방식 변경과 무관하게 그대로다 — 여전히 표시 전용 개정.

## 개정 (2026-07-02, 2차) — 현재 단계 판정을 "파일 존재"에서 "verified 게이트"로

위 개정에서 파이프라인의 "현재 단계(●)" 판정은 파일 존재 여부만 봤다 — `run.md`가 있으면 곧바로 `run`을 `✔`로, `learn`을 `●`로 그렸다. 그런데 이건 실제 게이트 로직과 어긋난다: `fg-learn`은 `verified`가 아직 확정 안 됐으면(`pending`/`failed`) 회고를 거부하고 `fg-run`으로 돌려보낸다(회고 게이트, fg-learn SKILL.md "Input" 섹션) — 즉 `run.md`가 존재해도 `verified`가 미확정이면 실질적으로 아직 `run` 단계에 머물러 있는 것이다. 또한 `fg-ask`/`fg-run`의 재실행 경계상, 한 단계는 "다음 단계로 실질적으로 못 넘어가는 시점"까지는 계속 열려있다고 봐야 한다(예: `run.md`가 생기기 전까지는 `fg-ask`로 plan을 자유롭게 고칠 수 있고, `verified`가 확정되기 전까지는 `fg-run`이 계속 개입할 수 있다).

**결정**: 파이프라인의 현재 단계(`●`) 판정 기준을 다음으로 바꾼다 — 한 번에 점 하나만 켜진다는 제약(single active dot)을 유지하면서:

- `plan.md`만 있고 `run.md` 없음 → `● ask → ○ run → ○ learn → ○ done` (ask는 아직 재그릴링으로 자유롭게 고칠 수 있는 열린 상태 — `run`은 아직 시작 전).
- `run.md` 있음, `verified: pending`/`failed`(미확정) → `✔ ask → ● run → ○ learn → ○ done` (`run.md`가 생겨 plan은 더 이상 조용히 못 고치지만(ask 마감), `verified`가 아직 안 끝나 회고 게이트를 통과 못 했으므로 여전히 `run` 단계).
- `run.md` 있음, `verified: yes`/`skipped`/`n/a`(sealable) → `✔ ask → ✔ run → ● learn → ○ done` (이제야 `fg-learn`의 회고 게이트를 통과할 수 있는 상태 — `run`도 마감, `fg-run` 재진입은 이제 "중복 실행 경고"가 뜨는 예외 경로일 뿐 자연스러운 이어짐이 아니다).

**고려한 대안**: 파일 존재만으로 판정 유지 — 기각. `verified: pending`/`failed`인데 `learn`을 현재로 그리면, 실제로는 `fg-learn`이 그 즉시 `fg-run`으로 돌려보내는 상태를 "회고 진행 중"처럼 보이게 해 혼란을 준다.

**결과**: `run`/`learn` 경계 판정에 `STATUS.md`의 `verified:` 필드를 추가로 읽어야 한다(기존엔 `run.md` 파일 존재만 확인했음). `ask`/`done`의 판정 로직(각각 "항상 완료"/"항상 예정")은 이번 개정과 무관하게 그대로다.

## 개정 (2026-07-03) — plan-only(run.md 없음) 판정을 ask에서 run으로 되돌리고, 그릴링 중 표시용 ask.md 마커 추가

GitHub 이슈 #3이 이 스크립트의 두 가지 버그를 지적했다.

**버그 1 — plan-only 상태의 오분류.** 위 "개정 (2026-07-02, 2차)"는 `plan.md`만 있고 `run.md`가 없을 때를 `ask`가 현재 단계라고 판정했다("plan은 아직 재그릴링으로 자유롭게 고칠 수 있는 열린 상태"). 그런데 이는 실제 소유권 경계와 어긋난다: **오직 fg-run만 백로그에서 활성 슬롯으로 승격시킨다** — `plan.md`가 활성 슬롯에 있다는 사실 자체가 이미 fg-run이 개입해 승격을 마쳤다는 뜻이고, 그 다음(워크플로우 빌드/실행 시작)도 구조적으로 fg-run의 영역이지 fg-ask의 영역이 아니다(`skills/fg-status/SKILL.md`의 버킷→stage 매핑도 애초에 "active slot, plan.md only (no run.md) → run"이었다 — 이 스크립트만 어긋나 있었다). fg-ask가 `plan.md`를 직접 조용히 고치는 경로는 없다(재그릴은 항상 새 `backlog/` 행을 거친다).

**결정 1**: `plan.md` 있음·`run.md` 없음 케이스의 현재 단계 판정을 `ask` → **`run`**으로 되돌린다(플래그는 그대로 없음). 이로써 이 한 케이스에 한해 "개정 (2026-07-02, 2차)"의 ask/run 경계를 뒤집는다 — 나머지(`run.md` 있음 이후의 verified 기반 run/learn 분기)는 그대로다.

**버그 2 — 그릴링 중 공백.** `plan.md`가 아직 없으면(= fg-ask가 그릴링 중이라 아직 백로그에도 안 실렸으면) line 1이 통째로 비어 있었다 — statusline만 보면 대화가 진행 중인지 아무 작업도 없는지 구분할 수 없었다.

**결정 2**: fg-ask가 그릴링 **시작 시점**에 `$root/ask.md`를 표시 전용 마커로 쓰고(`<!-- forge-ask: <working-slug> -->` 한 줄), **백로그에 계획을 적재할 때**(또는 fg-quick으로 이탈할 때) 삭제한다. 스크립트는 `plan.md`가 없고 `ask.md`만 있으면 `⚒ <working-slug> | ● ask → ○ run → ○ learn → ○ done`을 그린다(플래그 없음; 마커 줄이 없거나 파싱 실패하면 `working-slug`는 문자열 `"ask"`로 대체). **둘 다 있으면 `plan.md`가 이긴다** — 기존 line 1 로직 그대로 표시하고 `ask.md`는 무시한다. 이는 "다른 작업이 이미 승격되어 활성 슬롯에 대기 중인 채로, 새 작업을 그릴링 중"인 상태를 정확히 반영한다(활성 슬롯은 언제나 최대 1개이지만, 그릴링은 활성 슬롯과 별개로 진행될 수 있다).

**고려한 대안**: `STATUS.md`에 `status: running`류의 새 값을 추가하는 안을 검토했으나 기각했다. `STATUS.md`는 이미 fg-done의 봉인 게이트, fg-learn의 회고 게이트, fg-doctor의 정합성 검사, fg-status의 버킷 판정 등 여러 소비자가 필드값을 가드 조건으로 직접 읽는 파일이다 — 여기에 새 상태값을 얹으면 이 계약면 전체에 파급되어 각 소비자가 그 값을 무시/처리하도록 손봐야 한다. 반면 `ask.md`는 fg-statusline **하나만** 읽는 표시 전용 마커라 계약 표면이 훨씬 작다.

**결과**:
- `scripts/forge-statusline.sh`/`.js`의 헤더 표·gating 로직이 위 두 결정으로 갱신됨(ADR-0022 패리티 유지).
- `fg-ask`가 그릴링 시작 시 `ask.md`를 쓰고 백로그 적재/이탈 시 삭제하는 책임을 새로 진다.
- `skills/fg-statusline/SKILL.md`의 "What the fragment prints" 섹션과 `CLAUDE.md`/`docs/state-contract.md`의 상태 계약 표가 `ask.md` 항목을 반영하도록 갱신됨.
