# Changelog

## [0.5.13] - 2026-07-12

### Changed
- **README 대표 이미지를 forge 로고로 교체.** 기존 루프 다이어그램(`workflow.png`) 대신 앤빌+해머+loop 화살표 로고(`docs/icon.png`)를 256px로 축소한 신규 `docs/icon-sm.png`를 대표 이미지로 사용(`README.md`·`README.ko.md` 이중언어 동기).

## [0.5.12] - 2026-07-12

### Changed
- **`fg-loop`의 `verified: failed`을 active-slot 제자리 수리로 전환 ([ADR-0016](./.forge/adr/0016-fg-loop-goal-driven-bounded-replan.md) 개정 2026-07-11).** 실패한 작업이 유일한 active slot을 점유한 채 새 backlog plan을 생성하면 fg-run이 그것을 승격할 수 없던 제어흐름 결함을 제거 — 같은 active task를 fg-run의 failed 분기(fix → fresh run.md → re-verify)로 **제자리 수리**하고 `<!-- repaired-by: fg-loop -->` provenance 마커만 더한다(slug/task/goal 불변). cap·scope·safety 게이트를 수리 전 통과시키며, tension의 `regressed:` 귀속은 `generated-by`·`repaired-by` 두 마커를 모두 인정한다. active slot이 빈 stop-check 실패만 종전처럼 `generated-by` backlog plan을 생성한다. 흐름도를 seal 경유가 명확한 텍스트 흐름도로 재작성.
- **`fg-run` 미실행 plan 4개 이상 선택 UI.** `AskUserQuestion`의 4옵션 상한 때문에 2–3개는 대화 메뉴, 4개 이상은 번호 텍스트 목록(task 번호/slug/목록 번호/`all`)으로 제시해 후보를 잘라내지 않는다. 동순위 정렬은 `part: N/M` 다음 slug.
- **`fg-merge` incoming task 번호를 done/+backlog 통합 재부여.** backlog만 재부여하면 done/ 아카이브에 중복 task 번호가 남아 fg-doctor uniqueness(error)와 fg-status 표시를 깨던 문제 — incoming plan 전체를 한 map으로 target 루트 마커에 대해 재부여한다.
- **`fg-drop` 항목 수별 선택 UI + goal 루프 통째 drop.** 1개는 drop/cancel 2지, 2–4개는 체크박스, 5개 이상은 번호 목록. goal 루프 drop은 `loop.md` + 모든 멤버 task의 미완 상태(backlog/active/executed)를 함께 제거하고 done·비멤버는 불변. 비-기본 브랜치 루트의 `dropped/`는 추적·fg-merge 보존.
- **`fg-done` 봉인 타깃 해석 규칙 명시.** active slot은 `--slug` 생략, parked/half-sealed는 `--slug`, active가 비고 parked가 여럿이면 먼저 선택(1개 자동·2–4 대화·5+ 목록). `all` 모드도 active는 `--slug` 생략·parked만 `--slug`.
- **`fg-adversarial-review` fix-forward 실행 순서.** 코드 결함 fix-forward는 원 작업이 active slot을 점유하는 동안 fg-run이 승격 못 하므로, 원 작업을 먼저 `fg-learn`→`fg-done`으로 봉인해 슬롯을 비운 뒤 `fg-run`이 fix plan을 집어간다.
- **`fg-next all` 전체 drive-set 스냅샷.** 새 backlog뿐 아니라 active slot·executed/ 작업(각 `verified:` 상태 + 회고 auto-skip·봉인 예정)을 먼저 보여, 이미 실행된 작업의 회고 waiver가 비공개로 넘어가지 않게 한다.
- **`fg-status` 고정 라벨만 로컬라이즈.** 스크립트의 행·순서·값·기호를 canonical로 취급하고 고정 라벨(No./Date/Task/Stage/Verify/Retro 등)만 사용자 언어로 번역 — 표를 재조사·재구성하지 않는다.
- **`fg-statusline` 쓰기 전 read-only preflight.** copy/chmod 전에 settings 위치·기존 statusLine·모드/밀도/OS 드리프트를 먼저 확인하고 밀도를 그 뒤 결정한다. Windows의 기존 wrapper는 유효한 refresh가 아니라 OS 드리프트로 보고 방법 2를 제안.

### Fixed
- **`fg-statusline` 방법 2의 Context 사용률이 항상 0%로 표시되던 버그.** 실제 세션 JSON의 `context_window`가 중첩 하위객체 `current_usage`를 `used_percentage` **앞**에 담는데, `.sh` 통합 스크립트의 `json_obj`가 평평한 객체만 파싱해 `used_percentage`를 놓쳤다(`.js` 트윈은 `JSON.parse`라 정상). `json_obj`를 한 단계 중첩을 위치 무관하게 허용하도록 고쳐 순서 독립으로 만들고, current_usage 앞/뒤 픽스처를 behavior·parity 테스트에 추가했다.
- **소비자 문서 정합 드리프트 일괄 수정(이 리포의 반복 실패 모드 — 단일 정의 vs 본문 갈라짐).** `fg-drop` frontmatter 선택 UI 설명(2분기→3분기), `docs/state-contract.md`의 `dropped/` 브랜치 추적 조건, README 이중언어 fg-run 행, `docs/forge-vs-loop-engineering.md`의 safety/tension 벽 스코프(생성·제자리수리 fix-forward), `docs/index.html` fg-run 선택 설명(이중언어)을 단일 정의에 맞춰 정렬했다.

## [0.5.11] - 2026-07-10

### Added
- **`fg-statusline` 방법 2(merge) 밀도 토글 (compact/full).** 4줄 `full` ↔ 2줄 `compact`를 wired command의 위치 인자로 전환한다(새 `config.json` 키 없음 — 모드처럼 command에 인코딩). `compact`는 시스템 정보+사용량 바를 한 줄로 합치고 forge를 단일 그룹으로 접으며 세션 그룹(⏱/$/±라인)을 생략한다. 설치 시 밀도를 한 번 묻고, refresh는 기존 밀도를 보존한다.
- **가이드 기반 신규 표시 필드(방법 2).** Context 라벨에 컨텍스트 윈도우 크기(`Context/1M`·`Context/200K`), 사용량 바에 컨텍스트 %별 동적 이모지(🟢<20·⚡20–69·🔥70–89·🚨≥90)와 셀별 RGB 그라디언트, 시스템 첫 줄 세션 그룹에 `$비용`(`cost.total_cost_usd`)과 `+A −R` 라인 수(`cost.total_lines_added/removed`). 각 필드는 소스 부재 시 graceful 생략.
- **task 번호 `#N` · git ahead/behind `↑N ↓N` · 모드 지시자 `🧪`(tdd)/`♻️`(eco).** 활성 plan의 안정 task 번호를 slug 앞에, upstream 대비 ahead/behind를 `⎇` 브랜치 세그먼트에(0·upstream 부재 시 생략), tdd/eco 모드를 실활동(활성 작업/큐)에서만 지시자로 표시한다(idle·loop-only 제외).

### Changed
- **statusline 표시 계약을 의미 단위 그룹 대괄호 `[...]`로 재편 + 구분자/라벨/색상/재배치.** 세그먼트를 대괄호 그룹으로 묶고(그룹 사이 공백, 안은 구분자), 방법 2 구분자를 ` · `→` | `로(fragment엔 신설 `FORGE_SL_SEP`으로 위임 — 방법 1은 `·`·무색 유지), `Ctx`→`Context` 라벨 원복(#70 개정의 부분 원복), 가이드 팔레트 색(모델 magenta·`⎇`cyan·`$`yellow·`±`green/red·대괄호·구분자 dim·바 truecolor 그라디언트), 세션 그룹(⏱/$/±라인)을 사용량 줄에서 시스템 첫 줄 끝으로 재배치, 모드 지시자를 원문자 `Ⓣ`/`Ⓔ`에서 이모지 `🧪`/`♻️`로 교체(#71 이모지 기각의 원복). fragment는 **전역 그룹 대괄호 + density-aware**로 확장되어 방법 1 출력도 대괄호·이모지 지시자를 반영한다(구분자 `·`·무색·append 성격은 불변). 색은 라이브 튜닝·테스트 ANSI strip이며 6개 테스트 스위트를 새 계약으로 전수 갱신했다([ADR-0029](./.forge/adr/0029-fg-statusline-combined-daleseo-dual-mode.md) 2026-07-10 개정 · [ADR-0017](./.forge/adr/0017-statusline-integration.md) 개정).

## [0.5.10] - 2026-07-07

### Changed
- **statusline 리셋 남은 시간의 24h 초과 표기.** 방법 2(merge) 통합 스크립트의 Usage/Weekly 바에서 `resets in`이 24h를 초과하면 `4d 4h`처럼 일 단위(`Nd Nh`)로 표기한다 — 24h 이하는 기존 `Nh Nm`/`Nm` 유지, 경계는 86400초 초과부터(정확히 24h는 `24h 0m`). `forge-statusline-full.sh`/`.js` 트윈 동시 반영이며, 이 분기를 고정하는 behavior/parity 테스트 케이스와 `fg-statusline` SKILL.md의 출력 형식 문서를 함께 동기화했다.

### Fixed
- **스킬 전수 리뷰에서 나온 정합 수정 2건.** ① `fg-quick`의 LOG 항목 라벨이 한국어(`요청/결정/결과`)로 하드코딩되어 비한국어 사용자도 한국어 라벨을 받던 결함 — canonical English(`Request/Decision/Result`)로 바꾸고 사용자 언어로 렌더하도록 했으며, 이 라벨을 리터럴 매칭하던 `fg-merge`의 브랜치 통합 전 in-flight 검사(`결과: pending`)도 의미 매칭으로 함께 동기. ② `fg-status` 태스크 표의 Retro 컬럼 라벨을 실제 값 집합에 맞춰 `O/X` → `O/X/—`로 정정.
- **`forge-statusline-full.test.sh` 하니스 버그.** 파일 헤더가 문서화한 상대경로 실행법(`FGSL_FULL_IMPL=scripts/….js`)이 테스트 내부의 픽스처 디렉터리 `cd` 때문에 전 케이스 MODULE_NOT_FOUND로 깨지던 문제 — 상대경로 IMPL을 절대경로로 정규화해 수정.

## [0.5.9] - 2026-07-06

### Added
- **`fg-done` 단일 봉인 마감 요약.** 명시적 단일 `/fg-done`(사람이 한 작업을 의도적으로 봉인)에서만 봉인 후 마감 요약(요구사항 / 처리 내용 / 조건부 회고 챕터 / 메타)을 화면에 렌더한다. 아카이브된 `plan.md`·`run.md`·`STATUS.md`·retro에서 재구성하는 **화면 출력 전용**(파일 미영속 — 아카이브 자체가 영속 흔적)이며, 봉인 스크립트·상태 계약·검증 게이트(ADR-0009)는 전혀 바뀌지 않는다(ADR-0031 경계 — 판단=산문). 배치·무인 경로(`fg-done all`·`fg-next` 원샷/all·`fg-loop`)는 요약 챕터 없이 현행 간결 notice를 유지한다 — 이 비대칭은 의도된 설계다(GitHub 이슈 #4, [ADR-0032](./.forge/adr/0032-fg-done-single-seal-summary.md)).

## [0.5.8] - 2026-07-05

### Added
- **`fg-statusline` 방법 2(merge) 이중 모드.** forge 소유 통합 스크립트(`forge-statusline-full.sh`/`.js` 트윈)가 daleseo식 시스템 정보(모델·추론강도·작업 디렉터리·git 브랜치+상태 · Context/Usage/Weekly 사용량 바 — 임계값 색·필드 부재 그레이스풀 생략)와 forge 진행을 한 스크립트로 출력한다. 설치 시 기존 statusline이 있으면 방법 1(append/wrap)/방법 2(merge) 선택, 없으면 2 자동, Windows+기존이면 2만(wrapper가 bash 전용). forge 부분은 기존 fragment에 `FORGE_SL_PREFIX`로 위임해 단계 로직을 재사용한다(방법 1은 바이트 불변 — [ADR-0029](./.forge/adr/0029-fg-statusline-combined-daleseo-dual-mode.md)).
- **`fg-done` 봉인 결정론 스크립트(`forge-done.sh`/`.js`).** 사전점검·게이트 강제·STATUS 마감·원자적 아카이브·슬롯 비우기를 한 번의 호출로 처리하는, 대화형 `fg-done`·`fg-done all`·`fg-next all`(위임) **세 봉인 경로가 공유하는 단일 프리미티브**다. read-only인 fg-status 스크립트와 달리 파일을 이동하므로 **게이트-우선-비파괴**(검증·회고 게이트 통과 전엔 아무것도 안 건드리고 사유+exit code로 refuse)이며 behavior+parity 테스트로 보호된다 — 스킬은 스크립트 호출+출력 relay+exit code 라우팅으로 축약된다([ADR-0030](./.forge/adr/0030-fg-done-deterministic-seal-script.md)).

### Changed
- **스크립트 백킹을 forge 컨벤션으로 승격.** "기계적·결정론 작업은 트윈 스크립트(behavior+parity 테스트, 파괴적이면 게이트-우선-비파괴), 판단·대화·next-step은 산문"을 fg-status(ADR-0020)·fg-statusline(ADR-0029)·fg-done(ADR-0030)에 흩어진 원칙에서 새 스킬 작성자용 단일 정본으로 명문화했다([ADR-0031](./.forge/adr/0031-script-backing-convention-for-mechanical-skill-work.md)).

## [0.5.7] - 2026-07-04

### Changed
- **무인 주행(`fg-next all`·`fg-loop`)의 턴 내 계속 + `/goal` 페어링을 1차 경로로 강제.** `fg-next all`은 위임 스킬의 진술형(statement-form) 정지를 턴 경계가 아니라 계속 신호로 취급해 같은 턴에서 다음 단계로 이어가고, `fg-next all`·`fg-loop` 둘 다 진입 시 진짜 턴 경계를 넘기 위한 붙여넣기용 `/goal` 라인을 1차 경로로 제시한다. 공유 규율은 `skills/fg-next/DRIVE.md`에 단일 정의로 두고 두 차선이 참조한다(자동 설치형 Stop 훅은 검토 후 거부 — [ADR-0028](./.forge/adr/0028-unattended-drive-continuation-and-goal-pairing.md)).

## [0.5.6] - 2026-07-03

### Added
- **GitHub Pages 랜딩 페이지 신설 (`docs/index.html`).** 단일 파일에 KO/EN 텍스트를 나란히 담고 언어 토글로 전환하는 이중언어 구조([ADR-0027](./.forge/adr/0027-docs-index-single-file-bilingual.md)), 데스크탑 스택 스크롤 + 섹션별 reveal 프리셋 애니메이션, 모바일(≤760px)에서 nav 링크 숨김·grid 1~2열 재배치로 반응형 대응.
- **이슈 연동 작업 봉인 시 자동 커밋+push+이슈 코멘트+닫기.** 이 리포 전용 `CLAUDE.md` 규칙 — plan의 `## Source of truth`에 `이슈 추적: GitHub 이슈 #N` 표기가 있으면 fg-done 봉인 시 확인 질문 없이 가벼운 배포(커밋+push, 전체 릴리스 절차 아님)와 이슈 코멘트·닫기를 자동 수행한다. `.claude/skills/issue-triage`(로컬 전용, forge 플러그인 비소속)의 hand-off가 이 표기를 기록하도록 안내.

### Fixed
- **`fg-statusline` — plan.md만 있고 run.md가 없는 상태를 "ask"가 아니라 "run"으로 판정.** 활성 슬롯 승격은 fg-run만 하는 행위라 이 상태는 실질적으로 fg-run의 영역이었다(GitHub 이슈 #3). fg-ask 그릴링 중에는 읽을 파일이 없어 표시가 비어 있던 문제도 함께 고쳐, 그릴링 시작 시 쓰는 `ask.md` 표시용 마커로 "ask 진행 중"을 보여주게 했다([ADR-0017](./.forge/adr/0017-statusline-integration.md) 3차 개정).

## [0.5.5] - 2026-07-02

### Changed
- **`fg-next` — 회고(fg-learn)가 재그릴링 권고 없이 끝나면 같은 호출에서 봉인(fg-done)까지 자동으로 잇는다.** 실사용 관찰상 회고 후 봉인하지 않은 경우는 "divergence가 커서 재그릴링" 뿐이었기에, `fg-next`(인자 없는 one-shot)의 유일한 예외로 이 연쇄를 추가했다 — 그 외 모든 포크·다른 스킬(`fg-learn`/`fg-done`/`fg-status` 자체, `fg-next all`)은 그대로다 ([ADR-0026](./.forge/adr/0026-fg-next-learn-done-autochain.md)).
- **`fg-statusline` — 파이프라인 현재 단계 판정을 파일 존재가 아니라 `verified` 게이트 기반으로.** `run.md`가 있어도 `verified`가 아직 확정 안 됐으면(`pending`/`failed`) `run`을 현재로, 확정되면(`yes`/`skipped`/`n/a`) `learn`을 현재로 표시한다 — `run.md`가 없으면 `ask`가 현재(플랜을 아직 자유롭게 재그릴링할 수 있는 상태)로 표시된다. `fg-learn`의 실제 회고 게이트 로직과 일치시킨 것 ([ADR-0017](./.forge/adr/0017-statusline-integration.md) 2차 개정).

## [0.5.4] - 2026-07-02

### Changed
- **`fg-statusline` — task 이름 + 색상 ask/run/learn/done 진행 파이프라인, 2줄 상시 표시.** 활성 슬롯 > `executed/` > `backlog` 우선순위로 하나만 가리던 단일 세그먼트 표시를 폐지 — 1번째 줄은 활성 task의 slug와 `✔ ask → ● run → ○ learn → ○ done` 색상 진행 파이프라인(현재 단계만 강조, `done`은 forge 루프 전체 그림을 완성하는 장식용 4번째 단계), 2번째 줄은 backlog 대기·회고 대기 개수 요약을 **해당되면 항상 동시에** 보여준다. bash(`forge-statusline.sh`)·node 폴백(`forge-statusline.js`) 양쪽 동일 반영, 정확한 색상 값은 라이브 튜닝 대상으로 열어두고 테스트는 ANSI를 벗겨 구조만 검증한다 ([ADR-0017](./.forge/adr/0017-statusline-integration.md) 개정).

### Added
- **README GSD Core·GStack·Superpowers 비교표 (이중언어).** forge를 다른 AI 코딩 하네스 세 가지와 비교하는 표와 forge의 강점·솔직한 격차를 `README.md`/`README.ko.md`에 추가.

### Docs
- 코드베이스 지도(`.forge/codebase/`) 전체 리프레시 — v0.5.3 반영(`.claude/agents/` 도메인 카드, ADR-0025, scripts dual-dispatch 등).
- 프로젝트 로컬 `.forge/config.json` 초기화(`eco: false`) — forge의 자체 dogfooding 설정.

## [0.5.3] - 2026-06-27

### Added
- **README 사용 시나리오 섹션 (이중언어).** "상황별 어떤 스킬을 어떤 순서로 쓰나"를 보여주는 7행 표를 `README.md`·`README.ko.md`의 "Choosing a lane / 차선 고르기" 뒤에 추가 — 처음 셋업·일상·사소한 1회 변경·무인 주행·재진입/점검·마무리/배포·유지보수. 특히 Quick start가 건너뛰던 **첫 셋업 흐름**(`fg-map` → `fg-agents`[세션 재시작 필요, ADR-0024] → `fg-ask`)을 명시한다. 일상·무인 행은 기존 Quick start/Choosing a lane을 참조만 해 중복을 피한다.

## [0.5.2] - 2026-06-26

### Fixed
- **스킬 문서 정합 수정 (적대적 감사 후속, #54).** `fg-adversarial-review`로 18개 스킬 묶음을 감사해 adjudicate한 실 결함을 정정 — 전부 SKILL.md 지시문 정합이며 동작은 불변:
  - **ADR-0015 미전파 stale 제거** — `fg-loop`의 폐지된 "four-option menu" 참조를 진술형 핸드오프 표현으로, `fg-done`의 "fg-run이 handoff에서 `retro: skipped`를 쓴다"는 부정확 문구를 "skip 값은 skip-and-seal 경로(cleanup 시점, human 또는 fg-next all/fg-loop 드라이브)에서 기록"으로 정정.
  - **`fg-drop` git 주장 브랜치 케이스 정정** — 비-기본 브랜치는 `.forge/branch/<branch>/`가 git-추적(ADR-0011)이라 hard-delete가 `git status`에 unstaged 삭제로 보임을 3곳에 명시. "nothing lost in git"의 무조건 주장을 기본 브랜치로 한정하되, fg-drop이 git을 직접 안 돌린다는 원칙(ADR-0021)은 유지.
  - **`fg-done` STATUS 정합** — close-out 템플릿에 `reviewed:` 필드(record-only, fg-adversarial-review 실행 시) 추가 + cleanup-time retro-skip이 human 선택뿐 아니라 fg-next all/fg-loop 무인 드라이브가 구동하는 skip도 포함함을 명시(ADR-0010/0016 seam 해소).
  - **다이어그램 완전성** — `fg-done`(cleanup retro-skip 분기)·`fg-merge`(in-flight 노드에 `loop.md`) 텍스트 흐름도를 prose와 정합.

### Decisions
- **ADR-0025 — forge는 Claude Code 전용, Codex/크로스플랫폼 포팅 보류.** 진짜 결합점은 ultracode/Dynamic Workflow(직접실행 fallback 있음)가 아니라 패키징(`.claude-plugin/`·`/plugin`·`CLAUDE_PLUGIN_ROOT`)+도구 계층(AskUserQuestion·Skill 체이닝·Workflow). 도구 추상화의 확정 비용 대비 가설적 이득이라 보류하되, 실사용 수요가 반복되면 (a)전면 추상화 / (b)방법론-only 차선을 그릴하라는 재검토 바를 명문화(ADR-0013/0024와 동형).

## [0.5.1] - 2026-06-26

### Added
- **forge 자체 도메인 에이전트 카드 2개 — fg-agents 도그푸딩.** v0.5.0의 fg-agents로 forge 리포 자체의 도메인 에이전트를 생성: `skill-author`(`skills/*/SKILL.md`·형식문서를 forge 컨벤션에 맞게 작성/편집)와 `manifest-doc-syncer`(18-스킬 카탈로그·버전 3곳·README 이중언어 동기 + JSON/카운트 검증). 활성 ADR·CONVENTIONS를 prose로 가볍게 반영, `description`에 "언제 쓰이나"를 담아 fg-run이 `agentType` 자동 매핑. **주의 — 리포-로컬 자산**: `.claude/agents/`에 있어 클론 시 따라오지만 `/plugin install`로는 배포되지 않는다(매니페스트가 선언한 플러그인 에이전트가 아님). fg-run이 dispatch하려면 세션 재시작 필요(ADR-0024).

## [0.5.0] - 2026-06-26

### Added
- **fg-agents (신규, 18번째 스킬) — 프로젝트 도메인 에이전트 생성.** 대화형 그릴링(기둥 1, 워크플로 밖)으로 프로젝트 도메인을 캐 역할을 도출하고 표준 `.claude/agents/<role>.md` 서브에이전트 카드를 생성한다. `.forge/codebase/` 맵·`CONTEXT.md`·**활성 ADR**을 연료로 읽어 — 번호를 기계 인용하지 않고 prose로 **가볍게** — 카드를 프로젝트에 정합하게 만든다. 카드 `description`의 "언제 쓰이나"로 fg-run이 slice↔role을 자동 매핑한다. **핵심 제약(ADR-0024)**: `.claude/agents/`는 세션 시작 시 1회 로드되므로 생성한 카드는 **세션 재시작 후** fg-run이 활용한다(생성→재시작→활용). 루프 밖 온디맨드 유틸리티·graceful·optional.

### Changed
- **fg-run이 프로젝트 도메인 에이전트를 `agentType`으로 dispatch.** Dynamic Workflow 빌드 시 세션 시작 시 로드된 `.claude/agents/`의 role을 slice에 맞춰 `agentType`으로 호출한다 — 도메인 에이전트가 없으면 **기존과 100% 동일**(graceful degradation). eco ON 시 `agentType` 호출도 sonnet 캡 + ECO.md 주입(단 카드에 `model:` 명시가 있으면 사용자 명시로 존중 — eco는 내리기만). 도메인 에이전트 부재 시 fg-agents로 생성할 수 있음을 1줄로 안내(의존 아닌 포인터).
- **fg-ask가 반복적·분리 가능한 특화 역할이 도움될 때 fg-agents를 안내** — 좁게·offered·1회·자동 호출 안 함·"카드는 세션 재시작 후 활용" 게이트 명시(deep-research 포인터 ADR-0006와 동형).
- **18-스킬로 동기** — `plugin.json`·`marketplace.json`의 `plugins[].description`(루프 밖이라 `metadata.description`은 제외), `README.md`+`README.ko.md`(이중언어), `docs/skills.md`·`docs/forge-vs-loop-engineering.md`, `CLAUDE.md` 스킬 목록, `fg-doctor` 카운트. `.forge/codebase/` 맵 7문서를 현재 상태로 리프레시.

### Decisions
- **ADR-0024** — forge가 사용자 프로젝트의 `.claude/agents/`를 fg-run 실행에 통합한다(생성=fg-agents, 호출=fg-run `agentType`). harness 풀 복제는 거부(harness=프로젝트 1회 셋업 팩토리, forge=매 작업 루프로 레이어가 다름; 한 줄로 공존 설치 가능). **ADR-0013(forge 내부 투기적 서브에이전트 보류)과 비충돌** — forge 플러그인에 에이전트를 더하는 게 아니라 사용자 프로젝트가 소유한 에이전트의 호출 경로를 여는 것. 전제(PoC+공식문서 검증): `.claude/agents/`는 세션 시작 시 1회 로드, 세션 중 생성분은 재시작 후 dispatch 가능.

## [0.4.28] - 2026-06-25

### Fixed
- **fg-loop tension/safety 벽의 제어흐름 허점 2건 보정 (ADR-0016 8차 개정, Codex 적대적 리뷰).** v0.4.27의 두 벽에 대한 Codex 리뷰가 짚은 허점 — 둘 다 SKILL.md *메커니즘*이 자기/소비자 설명보다 넓거나 누락된 경우라 메커니즘을 의도에 정렬했다. **[high]** tension이 일반 멀티태스크 백로그 작업에도 오발동: regression 원장이 *모든* 봉인 작업의 pass→fail 플립을 카운트해, 초기 사람-그릴링 member 작업이 정지 체크를 깨면(정상적 다중작업 간섭) 위양성 `wall: tension`이거나 알려진 regression을 지나칠 수 있었다 → `regressed: ×N`을 **fix-forward 귀인 플립(`generated-by: fg-loop`)만** 세도록 한정, member 작업 플립은 last-evidence에만 기록·비-tension·드레인 안 멈춤. satisfy-both 재시도·×2/핑퐁 정지도 fix-forward 귀인에만 적용. **[medium]** safety 게이트가 `verified: failed` 자동 fix-forward 경로를 우회: `/goal`이 failed에서 안 멈추라 지시하므로 승인 범위 안의 비가역 수정이 무인 자동 실행될 수 있었다 → safety 분류를 **모든 fix-forward 생성의 필수 전제조건**(replan·verified:failed 동일)으로 통합, 다이어그램 verified:failed 화살표도 `safety-class?` 경유. 소비자 문서(CLAUDE.md·docs·README)는 설명이 이미 fix-forward-scoped라 무변경. `skills/fg-loop/SKILL.md`·ADR-0016 동기.

## [0.4.27] - 2026-06-25

### Added
- **fg-loop에 tension 벽 + safety 벽 (ADR-0016 7차 개정).** Forward Future [Loop Library](https://signals.forwardfuture.ai/loop-library/)(69개 루프 레시피)의 공통 가드레일 DNA에 대고 fg-loop를 감사한 결과 — DNA 대부분(기계 검증 정지 조건·"AI가 됐다고 생각함"은 정지 아님·no-progress 2라운드·Reflexion·evidence ledger·stateless 재개·독립 기계 checker)은 이미 보유 — 남은 진짜 빈틈 2건을 보강했다. **tension 벽**: fix-forward가 이미 통과한 다른 정지 체크를 깨뜨리는 oscillation을 `## Check progress` 원장의 `regressed: ×N`(pass→fail 플립)으로 **기계 감지** — lenient + 1회 재시도(다음 fix-forward에 "둘 다 만족" 하드 제약 주입) 후 핑퐁이면 `wall: tension (Cx↔Cy)`으로 cap 소진 전 조기 정지. 기존 no-progress 벽(`×N`)이 놓치던 사각지대를 메운다(LL #034). **safety 벽**: 승인 범위 *안*이라도 비가역 7-class 액션(prod 데이터 변경/삭제·배포/릴리스/publish·외부 발신 통신·비가역 VCS/파일 파괴·금융/결제·시크릿/권한 변경·프라이버시 노출)이면 fix-forward **생성 시점**에 `wall: safety (<class>)`으로 정지(best-effort 자기분류라는 한계는 ADR에 명기). 둘 다 *생성된* fix-forward에서만 발생해 **fg-loop 전용**(fg-next all 비적용). budget 분리·체크 상태 다변화는 YAGNI로 기각. `skills/fg-loop`·`skills/fg-status` SKILL·ADR-0016·`docs/skills.md`·`docs/forge-vs-loop-engineering.md`·`CLAUDE.md`·README(이중언어) 동기.

## [0.4.26] - 2026-06-23

### Added
- **eco 모드에 caveman식 출력 prose 압축 (ADR-0014 2차 개정).** eco를 켜면 ECO.md 규율이 실행·보고 prose를 간결화한다 — 군더더기·헤지·인사치레 제거, 문장 단편 허용, 결론 먼저(언어 중립); 코드·명령·경로·에러는 verbatim. **적용 경계**: chat/실행/보고 prose만; 그릴링 질문·생성 영속문서(plan/run/retro/CONTEXT/ADR)·명시 요청 설명·보안/불가역/다단계 경고는 full 보존(기둥 1·2). 강도 레벨·wenyan 변형·별도 config 키는 미도입(eco 하나에 번들). JuliusBrussee의 [caveman](https://github.com/JuliusBrussee/caveman)에서 차용·각색(크레딧 README). `ECO.md`·`fg-eco`/`fg-run`/`fg-ask` SKILL·README(이중언어)·`docs/skills.md`·`CLAUDE.md`·매니페스트 동기.

### Fixed
- **eco 세션 채택을 상태 기반으로 전환 (적대적 리뷰 발견).** behavior 4(현재 세션 채택)가 `fg-eco on` 토글 행동에만 묶여 있어, eco를 기본값으로 박은 새 세션·`fg-eco` no-arg "그대로 두기"·fg-run 직접 실행 경로에서 메인 세션 prose 압축이 조용히 누락되던 결함을 수정. 이제 메인 세션이 `eco: true`를 **관측할 때마다** ECO.md를 채택한다(토글·no-arg 유지·fg-run 빌드/직접 실행·fg-ask 핸드오프). 불가피한 한계(어떤 forge 스킬도 안 돈 새 세션 첫 시점은 세션 시작 훅이 없어 자가 채택 불가 — 처음 eco-read 스킬이 집어감)는 behavior 4에 명문화. `fg-eco`/`fg-run`/`fg-ask` SKILL·ADR-0014·`docs/skills.md` 동기.

## [0.4.25] - 2026-06-23

### Added
- **Eco laziness-first 규율 (`skills/fg-eco/ECO.md`).** eco 모드에 임베드되는 코드 단순성 규율 — 6단 게으름 사다리(YAGNI → stdlib → 네이티브 → 기존 의존성 → 한 줄 → 최소 코드)와 핵심 제약(불필요 추상화 금지·삭제 우선·`// eco:` 주석·신뢰 경계/보안/데이터 손실은 단순화 금지·비-trivial 로직은 runnable check 하나). 독립 스킬이 아니라 eco의 일부이며(별도 토글 없음), DietrichGebert의 [Ponytail](https://github.com/DietrichGebert/ponytail)에서 차용·각색(크레딧은 README).

### Changed
- **fg-eco eco 모드 확장 — 모델 캡에서 루프 전체 절약 모드로 (ADR-0014 개정).** eco를 켜면 네 가지 효율 동작이 활성화된다: (1) fg-run이 위임 서브에이전트를 `sonnet`으로 캡(기존; 내리기만·세션 모델 불변·명시 지시 우선), (2) fg-run이 각 서브에이전트 프롬프트에 `ECO.md`를 prepend, (3) fg-ask 그릴링에 Eco YAGNI 렌즈를 적용(별도 질문 없음), (4) `fg-eco on` 시 메인 세션이 `ECO.md`를 읽어 그 대화 동안 규율을 채택. 모델 비용 기준 "강력=메인 세션 / 효율=위임 실행"의 2단 티어는 유지(behavior 4는 *행동 렌즈*만 적용, 세션 *모델*은 여전히 불변). `skills/fg-eco`·`skills/fg-run`·`skills/fg-ask` SKILL.md 동기.
- **문서 현행화 (이번 릴리스 작업 반영).** `docs/skills.md` — 누락됐던 `fg-drop` 카탈로그 행+섹션 추가, 루프 밖 유틸리티 카운트 12→13 정정, fg-eco를 두 동작+사다리+Ponytail 크레딧으로 재작성, fg-doctor 트리거 alias 보강. `docs/state-contract.md` — 디렉터리 트리에 `review.md`(ADR-0018)·`loop.md`(ADR-0016) 추가, **생산자·소비자 계약 표 신설**, 흐름 도식에 검증 게이트·적대적 리뷰·executed park·fg-loop·fg-drop 반영. `docs/forge-vs-loop-engineering.md` — 스킬 수 12→17, `/goal·/loop`에 fg-loop·sub-agents에 fg-adversarial-review 명시, eco 두 동작, 날짜 스탬프 재기입. `README.md`·`README.ko.md`(이중언어)·`CLAUDE.md` fg-eco 동기.

## [0.4.24] - 2026-06-21

### Added
- **README 루프 흐름 이미지·프로젝트 아이콘.** forge 4단계 순환 루프(ask → run → learn → done)를 투명 배경 인포그래픽으로 만들어 `README.md`·`README.ko.md` 최상단에 삽입(이중언어 동기). 기존 텍스트 흐름도는 "전체 흐름" 섹션에 그대로 유지(grep·diff 가능). 프로젝트 아이콘 `docs/icon.png`도 추가.

## [0.4.23] - 2026-06-20

### Added
- **fg-done `all` 모드 — 봉인 전용 batch (ADR-0023).** `fg-done all`은 이미 실행된 작업(활성 슬롯 + `.forge/executed/` 전부)의 회고를 무조건 일괄 skip하고 각자 개별 `done/`으로 봉인한다. `fg-next all`의 봉인 전용 사촌으로 **백로그의 미실행 작업은 promote·run하지 않는 것**이 유일한 구분점이다. 검증 게이트(ADR-0009)는 불가침 — `verified:` 봉인 가능값만 봉인하고 `failed`는 fg-run 수리로 라우팅, `pending`은 단일 경로와 같은 봉인 시점 UAT를 작업마다 반복한다. 봉인 직전 대상·제외 목록을 한 번 보여주고 go-ahead 하나를 받은 뒤 일괄 봉인하며, 회고 skip은 `retro: skipped (fg-done all — …)`로 감사 가능하게 남고 학습은 run.md에 보존된다(차선 완화 계열 ADR-0002/0010/0016의 네 번째 멤버). `SKILL.md`·`CLAUDE.md`·README(이중언어)·`docs/skills.md` 동기.
- **fg-loop ↔ loop engineering 비교 안내 (사용법).** README(이중언어)에 "차선 고르기 — L1→L2→L3 신뢰 사다리" 절을 신설: `/fg-status`(L1 관찰) → `/fg-next`(L2 보조) → `/fg-loop`·`/fg-next all`(L3 무인)을 loop engineering의 배포 사다리에 매핑해 *언제 어느 차선을 쓰는지* 안내한다. fg-loop `SKILL.md`에 maker/checker(기계 검증 체크 = 독립 게이트)·배포 레벨 정합 근거 한 단락 추가. 동작 변경 없음 — worktree·스케줄링·중복 verifier는 forge 불변식·범위와 충돌해 의도적으로 비채택.

## [0.4.22] - 2026-06-19

### Added
- **README "빠른 시작(Quick start)" 섹션.** 17개 스킬이 많아 보이는 진입 장벽을 낮추기 위해, 평소 쓰는 핵심 흐름만 카탈로그 앞에 간결히 제시: `/fg-ask → /fg-run → /fg-next` (또는 더 짧게 `/fg-ask → /fg-next all`), 길 잃으면 `/fg-status`·`/fg-next`, 사소한 건 `/fg-quick`, 출하는 `배포`. 나머지는 "선택적 보조"로 명시. 영문 `README.md`·한글 `README.ko.md` 동기.

## [0.4.21] - 2026-06-18

### Changed
- **fg-loop에 Reflexion 도입 (ADR-0016 2026-06-18 2차 개정).** `loop.md`의 `## Check progress` 원장에 체크별 `reflection`(왜 실패했고 다음엔 무엇을 *다르게*)을 추가하고, fix-forward 생성이 그 체크의 `tried`+`reflection`을 먼저 읽어 **반복이 아닌 다른 접근**을 취하도록 강제했다. no-progress 벽 보고에 reflection을 포함하고(임계값 `×2`는 불변, 의미는 "다양한 시도 소진"으로 격상), reflection이 범위 밖 수정을 요구하면 cap 소진 전 fork 벽을 조기 발동한다. `fg-status`는 halted-loop 보고에 reflection을 surface해 "왜 멈췄는지"를 보여준다(맨 "fg-loop 재개" 반복 제거). 참고 글에서 Reflexion만 차용하고 worktree·cron·MCP·역할 분리는 개념 이탈로 배제. `reflection`은 드라이브 내 휘발 작업기억이지 회고가 아니다(영속 승급은 run.md → fg-learn, ADR-0010 불변).
- **배포 규칙 갱신 (CLAUDE.md).** "배포" 절차에 **README(이중언어)·`docs/` 갱신** 단계를 추가 — 릴리스 작업 내용을 사용자 문서에 반영한 뒤 버전을 올린다(feat 커밋 포함, 릴리스 커밋은 CHANGELOG+버전만).

## [0.4.20] - 2026-06-18

### Added
- **크로스플랫폼 dual-dispatch 스크립트 규약 (ADR-0022).** 운영 연산을 결정론적 스크립트로 추출하고 각 스크립트를 `.sh`(bash 1차) + `.js`(node 폴백) 트윈으로 제공해 PowerShell이 차단된 Windows에서도 동작. `.gitattributes`로 `*.sh` LF 강제. 같은 fixture에 두 구현을 돌려 출력 동일성을 단언하는 **패리티 테스트 3종**이 drift 가드, fg-doctor는 `.sh`↔`.js` 트윈 존재를 정적 검사(check 14).
- **`scripts/forge-status.{sh,js}`** — fg-status의 survey + 6열 테이블을 결정론적 스크립트로 (ADR-0020 완결). fg-status SKILL은 스크립트를 실행해 출력을 relay하고 next-step만 산문으로 도출.
- **`scripts/resolve-forge-root.{sh,js}`** — FORGE-ROOT 해석을 추출(git 저장소 루트 앵커 — 하위 디렉터리 실행에서도 동작), forge-status가 DRY로 소비.
- **`scripts/forge-statusline.js`** — statusline의 node 트윈. fg-statusline은 HOST OS로 `STATUSLINE_CMD`를 1회 판정(Windows→node, 그 외→`.sh`)해 모든 wiring에 단일 사용.

### Changed
- **fg-loop: `loop.md`에 `## Check progress` 원장 + `wall:` 필드 추가 (ADR-0016 개정).** no-progress 벽("같은 체크 2연속 무진전")이 stateless 재개에서도 `×N≥2`로 판정되도록 이력을 영속화. fg-status는 `wall:`·`×N`·last-evidence를 읽어 멈춘 *원인*을 보고 → 맨 "fg-loop 재개" 반복 제거.
- **fg-status가 스크립트 출력 외에 loop 진단·active STATUS 상세·quick 최근 항목을 surface**하도록(스크립트는 테이블+카운트만 출력).
- **forge-status backlog 표시 순서**를 fg-run 계약(priority→part→slug)에 맞춤(파일 glob 순서 아님).

### Fixed
- statusline의 Windows cwd 디코드(`JSON.parse`/sed unescape), CRLF 상태파일·한글 slug에서 sh↔js 출력 동일성, 패리티 테스트의 `set -euo pipefail`로 setup-실패 가짜통과 차단 — adversarial review 라운드들에서 발견·수정.

## [0.4.19] - 2026-06-18

### Added
- **fg-drop 신설 (17번째 스킬, 루프 밖 유틸리티) — 미완 작업 폐기 차선.** 봉인 안 된 작업(backlog plan·활성 슬롯·`executed/` 회고 대기·멈춘 goal `loop.md`)을 항목별 위험도와 함께 제시(≤4 체크박스/≥5 번호 텍스트 목록)한 뒤, 별도 후속 질문으로 **하드 삭제(기본·흔적 없음)** 또는 **`.forge/dropped/` 보관**을 고르게 하고, 불가역 삭제 전 확인 게이트에서 "이미 실행된 작업의 바뀐 코드는 되돌리지 않음"을 경고한다. forge 상태만 지우고 git·코드는 안 건드린다. goal 루프는 통째로만 drop하고 멤버 task는 개별 제외. `.forge/dropped/`는 휘발(gitignore)이라 fg-doctor는 관용·fg-status는 무시 (ADR-0021).

### Changed
- **README를 골격만 남기고 상세를 `docs/`로 분리.** `docs/skills.md`(스킬별 상세)·`docs/state-contract.md`(상태 계약) 신설, README.md 148→85·README.ko.md 147→84줄로 슬림화, 이중언어 동기 유지.
- fg-doctor가 `.forge/dropped/` 버킷을 관용(고아·half-sealed 오탐 안 함).
- 매니페스트 스킬 카운트 "Sixteen→Seventeen / Twelve→Thirteen more" 갱신.

## [0.4.18] - 2026-06-16

### Changed
- **`/goal` 페어링을 "선택적 제안"에서 "무인 드라이브 운용 전제 + 정직한 fallback"으로 격상 (fg-loop·fg-next all).** fg-loop·fg-next all 무인 드라이브가 "한 작업 하고 그냥 턴 종료"로 멈추던 실사용 문제를 문서 수준에서 해소. 근본 원인은 두 겹 — (1) 스킬 본문("Do not end the turn")은 모델의 턴 yield를 물리적으로 못 막고, 특히 위임된 fg-run/fg-done이 ADR-0015대로 "다음 단계를 진술하고 멈춤"으로 핸드오프하는 근접 지시가 먼 "멈추지 마라"를 이김; (2) 턴 경계를 넘는 유일한 실효 메커니즘인 `/goal`을 §1이 "offer only"로 제시해 사용자가 매번 까먹음. 고침: `"offer only"` hedge 제거 → 진입 직전 *가장 눈에 띄게* "무인 주행하려면 지금 붙여넣어라"; `/goal` 미사용 시 동작을 **정직하게 약속**(한 사이클 후 멈춤 = 정상, `forge loop`/`fg-next all` 재트리거로 stateless 재개); **재개 때마다 paste 줄을 벽 집합에서 재파생·재출력**해 "까먹음" 구조적 차단(`loop.md` 스키마 불변, 상태 계약 ripple 없음). fg-loop·fg-next all 양쪽 동형 적용 + ADR-0016 개정 노트(2026-06-15). 순수 framing 변경 — 드라이브 로직·게이트(ADR-0009·활성 슬롯 1개·회고 auto-skip·`/goal` 자동발동 불가)는 전부 불변.

## [0.4.17] - 2026-06-15

### Fixed
- **fg-doctor의 legacy STATUS 대시 형식 오탐 수정.** A2/A4 등 STATUS 검사가 평문 `status:`만 가정해, legacy `done/`의 대시 리스트 형식(`- status:`)을 읽지 못하고 done/ 31개를 half-sealed로 오탐했다(첫 실전 dogfooding에서 노출). "How it runs"에 STATUS 필드가 `field:`(평문)·`- field:`(대시) 두 형식으로 존재하며 전 STATUS 검사(A2/A3/A4/A6)가 optional `- ` prefix를 허용해야 함을 명시 — 오탐 제거.

## [0.4.16] - 2026-06-15

### Added
- **fg-doctor에 retro 페어링 정합 검사 추가.** A3(Slug pairing)을 확장해 "retro 파일 존재 ↔ STATUS `retro:` 필드" 정합을 검출한다 — (a) `retro:`가 경로인데 파일 없음 → error, (b) `done/` STATUS가 `retro: pending` → warning(봉인 close-out 누락), (c) active/executed에서 retro 파일 존재 + `retro: pending`은 정상(pre-seal). 상태 판정 규칙이 fg-status·fg-learn·fg-done 3곳에 중복 서술돼 드리프트 시 흐름이 꼬일 위험을, fg-doctor가 능동 검출하도록 예방(ADR-0019 범위 내).

## [0.4.15] - 2026-06-15

### Fixed
- **fg-run 종료 핸드오프 메뉴 반복 버그 제거 — 진술형 전환(ADR-0015 개정).** fg-run 단일작업 종료 핸드오프만 유일하게 `AskUserQuestion` 4지 메뉴를 썼는데, 메뉴를 유발하는 활성 슬롯 상태(`executed`+`verified: sealable`+`retro: pending`+unsealed)가 응답 후에도 영속하고 "이미 띄웠다"는 멱등 가드가 없어 — 응답을 매핑 행동으로 옮기지 않고 핸드오프를 재평가하면 같은 메뉴가 다시 떠 "선택해도 즉시 또" 반복되는 버그가 있었다. 4지 메뉴를 **진술형으로 전환**(다른 핸드오프와 통일) — 다이얼로그가 아니라 텍스트 안내라 재제시 자체가 없어 구조적으로 멱등. 백로그 선택 메뉴(fg-run *시작* 시 2+ 작업 선택)는 별개로 유지(선택→실행, 반복 없음). "회고 후 봉인 한 번에" 인라인 편의는 fg-next로 대체. ADR-0015 개정 + CLAUDE.md 규약 + fg-next·README 양쪽 동기.

### Changed
- `.gitignore`에 `.omx`(muxa 런타임 상태 디렉터리) 추가.

## [0.4.14] - 2026-06-15

### Added
- **fg-doctor — 상태·문서 무결성 health check(루프 밖, ADR-0019).** harness engineering(walkinglabs/learn-harness-engineering)의 `init.sh` health check를 forge에 적용한 루프 밖 읽기 전용 유틸리티. forge의 상태 계약은 손편집 Markdown이라 조용히 깨질 수 있는데(고아 `run.md`·STATUS 필드 손상·slug 페어링 불일치·half-sealed `done/`·매니페스트 버전 drift·README 이중언어 어긋남·CLAUDE.md 스킬 목록 누락) 이를 능동 검증하는 메커니즘이 없었다. fg-doctor가 `.forge/` 상태 계약(6항목)과 문서/매니페스트 정합(7항목)을 검사해 위반을 severity(error/warning/info)·actionable 수정 안내와 함께 보고한다. 검출·보고 전용(자동 수정 안 함)·on-demand(자동 호출 안 함)·읽기 전용. 검사 group별 FORGE-ROOT 처리(group A 휘발=branch root, B13 ADR=top-level+branch 오버레이). fg-status는 "어디까지 했나", fg-doctor는 "상태가 건강한가" — 책임 분리. 스킬 15→16(루프 밖 11→12).

### Fixed
- **CLAUDE.md의 fg-statusline 누락 보완.** 루프 밖 스킬 목록에 fg-statusline(ADR-0017)이 빠져 있던 것을 fg-doctor 추가와 함께 보완 — 이제 16개 스킬 전부 CLAUDE.md에 등재(fg-doctor의 CLAUDE.md 스킬 목록 완전성 검사로 입증).

### Fixed
- **Codex 적대적 리뷰 findings 2건 수정.** (1) **[high]** `fg-adversarial-review`가 parked `executed/<slug>` 작업을 리뷰할 때 findings를 항상 활성 슬롯 `.forge/review.md`·STATUS에 기록해 엉뚱한 작업에 붙거나 아카이브에 안 따라가던 결함 → **활성 슬롯 전용**으로 좁혀 제거(ADR-0018 개정, parked는 fg-run unpark 후 리뷰, per-task `review.md` 경로는 기각). (2) **[medium]** `scripts/forge-statusline-wrapper.sh`가 동반 파일을 런타임 `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`로 찾아 custom config dir(그 변수 미export) 환경에서 statusline 전체가 공백되던 결함 → 래퍼 **자기 스크립트 위치(`BASH_SOURCE`)** 해석으로 제거(ADR-0017 개정, generic wrapper 설계 유지). custom config dir 회귀 테스트 추가(`forge-statusline-wrapper.test.sh` — wrapper 7/0, fragment 19/0).

## [0.4.12] - 2026-06-14

### Added
- **fg-adversarial-review — 회고 전 선택적 적대적 리뷰 스킬(루프 밖, ADR-0018).** fg-run↔fg-learn 사이에서 "결과가 틀렸다고 가정하고 증거를 찾는" 적대적 자세로 6개 렌즈(실패 지점·숨은 가정·요구사항 오해·보안/성능/데이터 손실·예상 못한 오용·약하거나 미검증된 근거)를 dynamic workflow 서브에이전트로 병렬 팬아웃, findings를 `.forge/review.md`에 기록하고 수정 필요 건은 사람 승인 후 fix-forward plan으로 만들어 fg-run 재실행. 검증(UAT)과 별개·비-게이트라 봉인을 막지 않고(STATUS `reviewed:`는 기록용), fg-next all·fg-loop 무인 주행에선 회고처럼 항상 skip. ADR-0007(자동 코드리뷰)과 보완 관계로 cross-ref. 인접 5개 스킬(fg-run 핸드오프 포인터·fg-learn retro 승급·fg-done 아카이브·fg-next/fg-loop skip) 연결, 상태 계약에 `.forge/review.md` 추가. 스킬 14→15, 매니페스트 두 description·CLAUDE.md·README 양쪽 동기.

### Fixed
- **fg-statusline 강건 재설계(ADR-0017 개정).** "fg-statusline 실행 후 statusline 전체(claude-hud 포함)가 공백" 장애 수정 — (1) settings command `~`(tilde)→절대경로(유력 root cause: 호스트가 tilde 미확장 시 래핑된 원본까지 전체 statusline 공백), (2) fragment가 stdin 세션 JSON의 cwd를 파싱(`workspace.current_dir`→`$PWD` 폴백, jq-free)해 호스트가 프로젝트 밖에서 실행해도 정상, (3) 합성 래퍼를 committed generic 스크립트(`scripts/forge-statusline-wrapper.sh`)+원본 보존 파일(`forge-statusline-orig.sh`)로 정리하고 SKILL.md의 "inline 임베드" 서술 정정. 테스트 추가(fragment stdin-cwd 케이스 + 래퍼 동반 테스트, 총 24 green).

## [0.4.11] - 2026-06-14

### Added
- **fg-statusline — forge 진행 상태 statusline 통합(ADR-0017).** `.forge/`를 읽어 한 줄 진행 상태(활성 작업 `slug:stage`+검증 플래그 / `📝 awaiting retro` / `📋 queued` / goal 루프 `🔁 rN/cap` / idle 빈출력)를 출력하는 자기완결 bash 조각 `scripts/forge-statusline.sh`와, 이를 `~/.claude/`로 복사한 뒤 기존 statusLine을 자동 래핑(아래 별도 줄)하도록 settings.json을 와이어링하는 설정 유틸리티 `skills/fg-statusline/SKILL.md`(루프 밖). 브랜치 루트 해석(ADR-0011) 재현, bash+git만 의존. Claude Code는 statusLine이 하나뿐이라 교체가 아닌 합성 — 기존 출력 보존. forge 최초의 실행 코드·테스트 인프라(fixture 기반 bash 하니스 15케이스, TDD)로, 두 기둥의 경계 있는 예외(ADR-0017). 스킬 13→14, 매니페스트 두 description·README 양쪽 동기.

### Changed
- **코드베이스 맵 전체 리프레시.** `.forge/codebase/` 7문서를 fg-statusline 도입(첫 실행 코드·테스트, 새 `scripts/` 디렉터리, 스킬 14개) 반영해 재매핑.

## [0.4.10] - 2026-06-13

### Changed
- **fg-loop 무인 자율 계약(ADR-0016 개정 2026-06-13).** 드라이브 도중 위임 스킬의 결정 지점(fg-run 핸드오프 메뉴·TDD 질문·slug 충돌·"회고/skip")마다 사용자에게 되묻던 격차를 해소 — goal 계약이 못 박힌 뒤 추천/기본값이 있는 모든 소프트 결정은 자동 선택하고 조용히 진행, 사용자에게 선호를 묻지 않는다. 정지점은 네 정합성 벽(검증불가 UAT·진짜 fork·상한·무진전)+워크플로우 스크립트 승인뿐(자동 선택할 추천이 없는 진짜 블록). 기초 질의(§1)는 정지조건·범위·상한만 묻고 나머지는 문서화된 기본값을 취하도록 lean화. ADR-0009·활성 슬롯 1개·회고 auto-skip 게이트 전부 불변. plugin.json·marketplace.json 설명 동기 갱신.

## [0.4.9] - 2026-06-12

### Added
- **fg-learn 일괄 승급 모드(Batch promotion mode).** fg-next all·fg-loop·fg-run의 회고 skip 경로가 약속해 온 "추후 fg-learn 일괄 승급"의 수신 구현. 명시 진입 전용("일괄 승급"/"batch promotion")으로 봉인된 `retro: skipped` 작업을 후보로 재허용하고(기본 경로의 배제 규칙은 예외 교차참조와 함께 유지), 승급 바를 넘는 학습만 개별 retro 파일로 작성하며, 승급 시 봉인 STATUS의 `retro:`를 사후 정정한다.

### Changed
- **fg-loop `## Tasks` 멤버십 목록(ADR-0016 개정).** loop.md에 루프 소속 slug를 등재하고 드라이브·재개가 멤버만 승격 — 벽에 멈춘 사이 fg-ask가 적재한 비소속 plan의 무필터 자동 주행을 차단. 주변 계약 동기화: fg-ask 벽 경고(1b)·fg-merge in-flight halt에 branch loop.md·fg-status `(loop)` 출처 태그(generated-by 마커의 첫 소비자)·fg-next all의 loop.md 주행 양보·CLAUDE.md 상태 계약 표 loop.md 행.
- **fg-loop /goal 페어링 능동 제시 + 턴 연속성.** 기초 질의 종료·재개 시점에 붙여넣기용 `/goal` 한 줄을 능동 제시(멈춤 허용 = goal-met·벽·스크립트 승인뿐, `verified: failed`는 fix-forward 계속), 드라이브에 "봉인 사이에 턴을 끝내지 않는다" 명시 — "한 사이클 후 중단" 증상 대응.

### Fixed
- **marketplace.json 스킬 카탈로그 정합.** plugins description의 루프 4스테이지에 스킬명 병기(`fg-learn`·`fg-done`이 이름으로 누락돼 plugin.json과 어긋나 있던 것 교정).

## [0.4.8] - 2026-06-12

### Added
- **신규 `fg-loop` 스킬 — goal 주도 한정 재계획 루프(루프 밖, 13번째 스킬) ([ADR-0016](./.forge/adr/0016-fg-loop-goal-driven-bounded-replan.md)).** 기초 질의(대화)로 기계 검증 가능한 정지 조건("AI가 만족됐다고 생각함"은 불인정)·승인된 fix-forward 재계획 범위·상한(기본 3라운드)을 `.forge/loop.md`에 못 박고 초기 백로그를 적재한 뒤, 체크 전부 통과까지 run→UAT→회고 자동 skip→봉인을 주행한다. 실패 체크에 직접 추적되는 fix-forward plan만 범위·상한 내 자동 생성(`<!-- generated-by: fg-loop -->` 마커, 단조 task 번호 유지), `verified: failed`는 벽 대신 자동 fix-forward 케이스. 벽(검증불가 UAT·진짜 fork·상한 소진·같은 체크 2연속 무진전)에서 멈춰 사람에게 환원, goal 충족 시 요약 보고 후 loop.md 삭제 — 기둥 1의 의도적·경계 있는 완화(fg-quick의 기둥 2 완화와 동형 선례).

### Changed
- **fg-status에 goal loop 가시성 추가** — survey에 `loop.md`, 리포트에 Loop 섹션 한 줄, 상태머신에 최우선 0번 분기(loop.md 존재 → fg-loop 재개 안내).
- 매니페스트 2벌·README 양판·CLAUDE.md를 13스킬 체제(루프 밖 유틸 9개)로 동기.
- 코드베이스 지도(`.forge/codebase/`) 전체 리프레시 — 13스킬·fg-loop 상태 표면(loop.md)·ADR-0016·TDD 검증-선행 해석 반영.

## [0.4.7] - 2026-06-12

### Changed
- **fg-run 단일작업 핸드오프 메뉴 4지화 ([ADR-0015](./.forge/adr/0015-fg-run-handoff-menu-others-stated.md) 개정).** "회고 후 봉인까지"(회고 대화 정상 수행 → 종료 시 fg-done 인라인 봉인, 회고 중 재그릴 권고 시 자동 봉인 중단)를 선두 기본 옵션으로 추가 — divergence 무관 제시. 기존 3지(회고만 / 바로 종료=skip+봉인[저-divergence 한정] / 프롬프트로 나가기)는 유지.
- **Run-all 배치 핸드오프 진술형 통일.** "어느 것부터?"는 fg-learn 소유 질문이라 중복 제거하고 다음 단계 통지만 남김. RUN-ALL.md 헤더의 "Behavior is unchanged" 선언을 개정 표기로 갱신, fg-next all의 `retro: skipped` 기록 주체를 fg-done cleanup-time 경로로 명시. "3지/three-way" 서술 전수 동기화(CLAUDE.md·README 양판·fg-next).

### Added
- **docs/forge-vs-loop-engineering.md** — Addy Osmani의 Loop Engineering(2026)과 forge의 대응 검토 문서. 6개 프리미티브 중 5개와 경고 전부의 제도화를 대응표로 정리, 유일한 갭(Automations)은 미도입 결정 기록.

## [0.4.6] - 2026-06-11

### Fixed
- **3차 정합 감사 — v0.4.5 변경분 드리프트 8건 수정.** 병렬 5 에이전트 감사(47건 점검)로 발견: CLAUDE.md의 fg-tdd 전체 누락 보충 · README 양판 `.forge/` 트리에 `adr/retired/` 줄 추가 · fg-status 상태머신 case 3(파킹 작업) sealable 분기에 회고 완료→fg-done 라우팅 추가 및 작업 테이블 Retro 열에 "회고 파일 존재+`pending` = 정상 pre-seal `O`" 규칙 추가 · fg-learn에 "STATUS `retro:` 필드는 건드리지 않음(fg-done이 봉인 시 채움)" 계약 명시 · fg-next 핸드오프의 ADR-0015 이전 stale 문구 교체.

### Added
- **fg-done 영속 문서 커밋 상기.** 봉인 완료 통지에서 이 루프가 갱신한 git 추적 영속 문서(retro·ADR·CONTEXT)가 미커밋이면 한 줄로 커밋을 상기(상기만, git 실행 금지 — fg-merge와 동일 절제).

### Changed
- 코드베이스 지도(`.forge/codebase/`) 전체 리프레시 — 12스킬 체제·ADR-0015 핸드오프·감사 open concerns 반영.

## [0.4.5] - 2026-06-11

### Changed
- **루프 핸드오프 전환을 진술형으로 통일 — 체이닝은 fg-next 전담 ([ADR-0015](./.forge/adr/0015-fg-run-handoff-menu-others-stated.md)).** 각 스킬 끝의 "진행할까요?" 전환 허락 질문을 걷어내고 다음 단계·트리거를 알린 뒤 멈추도록 바꿨다(드리프트 교정 — CLAUDE.md 규약은 원래 "전한다"였다). 예외는 분기가 가장 많은 `fg-run` 종료뿐 — 3지 명시 메뉴(회고 / 바로 종료=skip+봉인 / 프롬프트로 나가기, "바로 종료"는 저-divergence에서만)를 유지한다. `fg-ask`·`fg-learn`·`fg-done`·`fg-status` 핸드오프를 진술형으로, `fg-ask`의 실행모드 질문(워크플로우 vs 직접)을 제거(fg-run이 자체 결정), README 양쪽 "Overall flow" 서술을 함께 갱신.
- **전 스킬 `Language` 지시문 강화.** "always converse in the user's language"를, 사용자에게 출력하는 모든 메시지(질문·메뉴·상태/다음단계·핸드오프)를 사용자 언어로 쓰고 이 파일의 영문을 그대로 복창(mirror)하지 말 것으로 13개 스킬 전부 명문화.

## [0.4.4] - 2026-06-11

### Added
- **신규 `fg-eco` 스킬 — 위임 서브에이전트 모델 티어링 토글(루프 밖, 12번째 스킬).** `.forge/config.json`의 `eco` 키를 켜고 끈다(`fg-eco on|off`, 인자 없으면 상태 표시+켜기/끄기 선택). 켜면 `fg-run`이 Dynamic Workflow/실행 서브에이전트 모델을 **sonnet으로 캡** — 내리기만 하고(티어 업그레이드 금지) 사용자의 명시적 모델 지시가 우선하며, 메인 세션 모델은 건드리지 않는다(스킬은 세션 모델을 바꿀 수 없음 — 설계·완료는 사용자가 고른 모델 그대로, 강력=메인 세션·일반=위임 실행의 2단 구조). fg-map은 의도적으로 범위 밖(지도 품질=그릴링 연료) ([ADR-0014](./.forge/adr/0014-fg-eco-subagent-model-tiering.md)).

### Changed
- README 양쪽의 `.forge/` 디렉터리 트리에 누락 항목 보충: `config.json`(영속 — 3키 `tdd`·`eco`·`defaultBranch`, 전역)·`quick/LOG.md`(휘발). fg-tdd·FORGE-ROOT의 config 키 서술도 3키 체제로 갱신.

## [0.4.3] - 2026-06-11

### Changed
- **브랜치 영속 연료 읽기 오버레이 (ADR-0011 개정).** 비-기본 브랜치의 그릴링 연료(CONTEXT.md·adr/·retro/) 읽기가 최상위 `.forge/` 베이스 위에 브랜치 루트를 오버레이한다(브랜치 우선) — 갓 만든 브랜치가 main의 용어·결정을 못 보던 실명 문제 해소. 쓰기·ADR 채번은 브랜치 루트 그대로(단일 정의: `skills/fg-run/FORGE-ROOT.md`).
- **`fg-merge` 견고화** — ADR 재부여를 "전체 old→new 맵 선구축 → placeholder 일괄 치환, incoming 문서만" 으로 바꿔 순차 치환 캐스케이드/타깃 참조 오염 차단; 채번이 `retired/` 포함; 브랜치 backlog plan을 통합 목록에 추가(slug `-2`·task 번호 재부여)하고 halt 게이트를 진짜 in-flight 상태(active slot·executed/·pending quick 항목)로 축소; 통합 결과 커밋 리마인드 추가.
- **`fg-done` 봉인 절차 견고화** — STATUS 마감을 이동 전에 수행(close-out-before-move)하고, 중단된 봉인(half-seal)을 빈 상태 선언 전에 감지·완결; 검증·회고 게이트의 per-task 평가 명시(Run-all fail-stop 혼합 상태에서 통과 작업은 계속 봉인).
- **`fg-run` unpark 전제 구체화** — 활성 슬롯 점유 시 unpark하지 않고 대기, 슬롯이 비면 재진입 시 자동으로 최상위 회수 후보로 표면화.

### Fixed
- ADR 채번이 은퇴(`retired/`) 번호를 재사용할 수 있던 구멍(ADR-FORMAT·fg-merge 채번에 retired/ 포함, never-reuse 불변식 보존).
- `skills/fg-run/FORGE-ROOT.md`의 stale "fg-merge is not built yet" 블록 제거(수동 통합 지시가 7개 스킬에 전파되던 문제).
- README "모든 `.forge/...` 경로가 브랜치 루트로 해석" 과잉 진술에 전역 예외 2개(`config.json`·`codebase/`) 명시(README 양쪽·CLAUDE.md).
- fg-done의 봉인 가능 값을 fg-run과 동일한 `yes (<evidence>)` 형식으로 정렬, STATUS.md 템플릿 모양 통일(생산자 fg-run의 plain `key: value` 기준).
- fg-ask·fg-done·fg-quick·fg-learn의 "`.forge/` 통째 untracked" 단정을 브랜치별 서술로 한정.
- Run-all failed 파킹 provenance 모순(fg-run — Run all은 failed를 파킹하지 않음), fg-learn의 "fg-run은 executed/를 안 읽음" 오서술, fg-status 3b 상태의 스킬·트리거 누락(retro 여부로 fg-learn/fg-done 분기) 등 상태 머신 서술 정합.
- TDD 질문 조건 오서술(켜짐 여부와 무관하게 작업마다 질문, config는 기본 답) — fg-tdd·README 양쪽; fg-tdd config 키 2개(tdd·defaultBranch) 반영.
- README mermaid의 유령 'chores' 엣지 제거, README.ko 누락 트리거 3건 보충, fg-next "verify→done 확장" 절 영문판 보강.
- 회고 "per session" → "per task" 정정(RETRO-FORMAT·fg-learn), part-plan 정렬을 `part: N/M` 숫자 기준으로(10+ 파트 슬러그 오정렬), CLAUDE.md 화이트리스트에 `!.forge/config.json` 추가.
- ADR-0010에 개정 노트(기본 fg-next의 confirm-then-delegate 폐지를 역사로 명시), 코드베이스 지도(`.forge/codebase/`) 갱신.

## [0.4.2] - 2026-06-10

### Changed
- **`fg-run` — Run-all 절차를 `skills/fg-run/RUN-ALL.md`로 분리(progressive disclosure).** 흔한 호출 경로(1작업·단일선택)는 Run-all을 로드하지 않아 fg-run 본문이 ~12% 가벼워지고(28061→24579자), "Run all"을 실제로 고를 때만 그 파일을 참조 로드한다. **동작 불변** — 추출은 재배치일 뿐, rule census로 행동 규칙 19/19가 (SKILL ∪ RUN-ALL)에 보존됨을 입증.

### Added
- **`fg-done` — 봉인 후 codebase 지도 stale 감지 → `fg-map` 제안.** 작업이 `.forge/codebase/`가 서술하는 프로젝트 파일(`.forge/` 밖)을 바꿨고 지도가 존재하면, 봉인 wrap-up에서 `fg-map`을 **제안**한다(자동 실행 아님 — fg-map은 4-agent라 on-demand, ADR-0006의 offer-not-auto 선례). doc-only 작업이나 지도 부재 시엔 침묵. 봉인 가드·순서는 불변.

## [0.4.1] - 2026-06-09

### Added
- **`fg-ask` 진입 시 미봉인 이전 작업 알림** — 새 작업 그릴링을 시작할 때 이전 작업이 `status: executed`인데 봉인 안 됨(활성 `run.md` 미봉인 또는 `executed/` 파킹)이면, 한 번만 "먼저 마치기(`fg-next`) / 새 작업 계속"을 묻는다. 미완이 없으면 침묵하고 즉시 그릴링(평소 지연 0). 이 싼 체크는 retro 피드백·codebase 지도 읽기보다 먼저 수행. 미실행 plan(awaiting-run)은 트리거하지 않고, 백로그 공존 설계는 불변. learn-vs-done 판정은 `fg-next`에 위임(복제 없음).

## [0.4.0] - 2026-06-09

### Added
- **신규 `fg-cleanup` 스킬 — 오래된/대체된 ADR 은퇴 유틸리티(루프 밖).** 후보를 근거와 함께 제시하고 사람이 승인하면 각 ADR을 `.forge/adr/retired/<NNNN>-slug.md`로 이동(번호 불변·재사용 없음·삭제 없음, supersede/retire 마킹). `fg-ask`는 `retired/`를 정답소스로 안 읽어 은퇴분이 그릴링 연료에서 빠진다. 스킬 11개로 ([ADR-0012](./.forge/adr/0012-fg-cleanup-renamed-to-fg-done-cleanup-retires-adrs.md)).
- **`fg-merge` 스킬 — 브랜치 격리 통합 유틸리티(루프 밖).** `git merge` 뒤 `.forge/branch/<branch>/`를 `.forge/`로 통합 — ADR 재번호+교차참조 갱신·retro 이동(충돌 시 `-2`)·CONTEXT 용어 병합·done 합침·브랜치 폴더 제거. 기계적 자동, 진짜 충돌(용어 재정의·ADR 모순)에서만 멈춤. 대상 디렉터리는 lazy 생성. git은 직접 안 돌림 ([ADR-0011](./.forge/adr/0011-branch-isolated-forge-root.md)).
- **브랜치별 forge 루트 격리** — 비-기본 브랜치는 forge 루트 전체를 `.forge/branch/<branch>/`에서 운영(git 추적, 네임스페이스 격리로 병렬 브랜치 충돌 차단). 기본 브랜치는 종전대로 `.forge/`. 해석 규칙은 `skills/fg-run/FORGE-ROOT.md` 한 곳 정의 ([ADR-0011](./.forge/adr/0011-branch-isolated-forge-root.md)).
- **`fg-next all` 무인 완주(/goal 페어링) 패턴 문서화** — 하니스 `/goal`과 짝지어 백로그가 빌 때까지 자동 재개. 조건은 "완료 OR 사람 필요 벽"으로 적어 안전 벽에서 풀리게(스킬은 /goal 자동 발동 불가, 사용자가 침).

### Changed
- **봉인 ④단계를 `fg-cleanup` → `fg-done`으로 개명**하고, 루프 ④단계의 *단어*도 `cleanup`/`정리` → `done`/`완료`로 통일 — 흐름은 `질의·계획 → 실행 → 회고 → 완료`. "cleanup"은 이제 ADR 은퇴 스킬(`fg-cleanup`) 전용. fg-done 트리거 `작업 완료`·`봉인`(옛 `작업 정리`·`forge complete` alias) ([ADR-0012](./.forge/adr/0012-fg-cleanup-renamed-to-fg-done-cleanup-retires-adrs.md)).
- **`fg-next all`이 회고를 divergence와 무관하게 항상 자동 skip** — 고-divergence 회고에서 멈추던 것을 제거(forge-meta 작업이 거의 고-div라 매번 멈춰 모멘텀이 사라지던 문제). 멈춤은 `verified: failed`·미검증·진짜 fork·빈 상태 4개. 학습은 run.md에 보존, 승급은 추후 사람 ([ADR-0010](./.forge/adr/0010-fg-next-all-momentum-mode.md) 개정).

### Fixed
- `fg-merge`가 대상 디렉터리(`adr/`/`retro/`/`done/`)가 없을 때 lazy 생성하도록 명시 — 라이프사이클 e2e 검증(샌드박스)에서 발견·보강(없으면 folded done 이력이 유실되던 갭).

## [0.3.4] - 2026-06-08

### Fixed
- **`fg-next` 기본 모드가 진행하지 않던 문제** — 다음 단계를 알려주고 멈춰 `fg-status`처럼 행동하던 것을, 다음 단계를 한 줄로 알린 뒤 **곧바로 그 스킬을 호출(진행)**하도록 수정. 재실행 안전성은 `fg-run`·`fg-cleanup`의 기존 가드가 보장하므로 별도 확인 게이트가 불필요. 멈추는 경우는 입력이 필요한 진짜 fork·빈 상태로 한정. `all` 모드의 시작 1회 확인은 그대로 유지.

## [0.3.3] - 2026-06-07

### Fixed
- README(양 언어) 헤더가 루프 밖 스킬을 `fg-map` 하나만 세어 표·본문과 모순되던 것을 정정 — "nine fg-* skills — four loop + five utilities(`fg-map`·`fg-quick`·`fg-status`·`fg-next`·`fg-tdd`)".

## [0.3.2] - 2026-06-07

### Added
- **`fg-next` 스킬** — fg-status의 다음-단계 상태 머신을 참조해 다음 한 수를 도출하고, 한 번 확인 후 그 스킬을 실행하는 루프-밖 오케스트레이터. fg-status는 보고만 하고 fg-next는 행동까지 한다(기본 one-shot). 차갑게 재진입하는 진입점("어디까지 했는지 기억 안 날 때 다음 걸 해줘").
- **`fg-next all` 모멘텀 모드** (ADR-0010) — 백로그가 빌 때까지 선형 기계적 단계(run·n/a/자동검증 verify·저-div 회고 skip·cleanup·다음 승격)를 추천값으로 자동 진행하고, 대화의 벽(실패/검증불가 UAT·고-divergence 회고·진짜 fork·빈 상태)에서 멈춘다. `fg-run` "Run all"의 verify→cleanup 확장 상위집합.

### Changed
- **증거-우선 검증** (ADR-0009 보강) — `fg-run` 핸드오프 UAT가 `verified: yes`를 기록할 때 "어떻게 확인했는지"를 한 줄 증거로 동반한다(`yes (<evidence>)`, 예: `yes (npm test → 42 passing)`). TDD 모드에선 통과한 슬라이스 테스트가 곧 그 증거. 전면 덤프가 아닌 한 줄 경량. `n/a`/`skipped`/`failed`는 불변.

## [0.3.1] - 2026-06-05

### Added
- **봉인 전 검증(UAT) 게이트** (ADR-0009) — 회고 완료만으로 봉인하던 루프에 검증 게이트를 추가해, 한 번도 동작 확인되지 않은 작업이 `done`으로 봉인되는 것을 막는다. 루프 순서는 run → verify → learn → cleanup.
  - `fg-run` — 핸드오프에서 plan 목표/Definition of Done에 대고 UAT를 수행하고 결과를 STATUS `verified:` 필드에 기록(`yes`/`skipped`/`n/a`/`pending`/`failed`).
  - `fg-cleanup` — `verified:`가 봉인 가능 값(`yes`/`skipped`/`n/a`)이 아니면 봉인 차단(no-seal-without-verification), 회고 게이트보다 먼저 확인.
  - `fg-learn` — 검증 통과 시에만 회고 진입.
  - `fg-status` — `done`의 누락 `verified`는 legacy(pre-ADR-0009)로 해석, 활성/파킹의 `pending`과 의미 구분.

## [0.3.0] - 2026-06-05

### Added
- **선택적 TDD 모드 + forge 첫 설정 표면** (3 part로 분할 구현, ADR-0008):
  - `.forge/config.json` — git 추적 영속 설정 파일(`.gitignore` 화이트리스트). forge 첫 "설정" 상태 표면.
  - `fg-tdd` 스킬 — `fg-tdd on|off`로 TDD 모드 토글(인자 없으면 상태 표시), 루프 밖 유틸. 기본값 **off**.
  - `fg-ask` — 그릴링 시작 때 config 기본값으로 "이 작업 TDD로?"를 묻고 plan에 `<!-- tdd: on|off -->` 마커 기록.
  - `fg-run` — plan의 tdd가 on이면 test-first로 실행(슬라이스별 실패 테스트→구현→통과, 완료 기준에 테스트 포함). 외부 TDD 스킬은 선택적, 하드 의존 없음.

## [0.2.11] - 2026-06-05

### Added
- `fg-run`에 **조건부 코드 리뷰** — §3에서 계획-검증(항상)과 코드 품질 리뷰(조건부)를 구분. 변경이 위험 영역(인증·데이터·공개 API·마이그레이션)이거나 클 때만 워크플로우에 리뷰/adversarial-verify 단계(diff를 버그·보안·품질로 점검)를 포함(사소하면 생략). 워크플로우 자체 서브에이전트로 구성(외부 의존 없음), findings는 수정→재검증·잔여 중대건은 run.md 기록. 결정 기록 `.forge/adr/0007-fg-run-conditional-code-review.md`

## [0.2.10] - 2026-06-05

### Changed
- `fg-ask` 핸드오프가 fg-run 안내 직전에 **이번 그릴링이 만든/건드린 문서 경로를 나열** — 백로그 plan(항상) + 갱신한 CONTEXT.md·추가한 ADR(있으면). 사용자가 실행 전 검토하도록 안내

## [0.2.9] - 2026-06-05

### Added
- `fg-ask`에 **조건부 외부 리서치 참고 연료** 단계 — 작업이 리포에 없는 외부 지식(낯선 라이브러리·외부 API·미지 도메인)에 의존하거나 사용자가 요청할 때, 가용한 deep research 역량(예: deep-research 스킬)으로 근거를 모아 그릴링에 보탬. 선택적(없으면 조용히 건너뜀, 하드 의존 없음)·자동 실행 없음(먼저 제안)·그릴링 대체 아님(웹은 참고, 정답 원천은 CONTEXT/ADR). 결정 기록 `.forge/adr/0006-fg-ask-optional-deep-research-fuel.md`

## [0.2.8] - 2026-06-05

### Changed
- **작업에 고정 번호(#N) 부여** — fg-ask가 plan 생성 시 단조증가 번호를 `<!-- task: N -->` 마커로 매기고(max+1, forge-slug처럼 영속), fg-status No. 컬럼이 이 고정 번호를 표시, fg-run 메뉴가 `#N`을 보이고 번호로 지목·선택. priority는 정렬, 번호는 식별/지목용. 0.2.7의 위치 기반 행번호를 대체. 앞으로 생성분만 부여(기존 작업은 `—`), fg-quick 제외. 결정 기록 `.forge/adr/0005-monotonic-task-numbers.md`

## [0.2.7] - 2026-06-05

### Changed
- `fg-status` 표에 **순번(No.) 컬럼** 추가 — 섹션별 1부터 표시 순서 행 번호. 미완료 작업은 priority→part→slug 순(= #1이 fg-run이 다음 제시할 작업), done은 최근순. 새 순서 마커는 만들지 않음(순서는 기존 priority/part가 담당, 번호는 표시용)

## [0.2.6] - 2026-06-05

### Changed
- **큰 작업을 순서 힌트 가진 part-plan들로 분할** — fg-ask가 합의된 작업이 독립 배포/검증/봉인 가능한 덩어리로 분해되면(판단 기반) 거대 plan 대신 여러 part-plan(`<base>-NofM` 슬러그 + `<!-- part: N/M -->` 마커)으로 백로그에 적재. fg-run은 part를 순서대로 `(part N/M)` 라벨로 보여주고 하나씩 순차 완성을 권장(소프트 순서 — 하드 의존 아님, 각 part 독립 봉인 가능). PLAN-FORMAT 분할 규칙에 크기/분해 트리거 추가. 결정 기록 `.forge/adr/0004-split-oversized-tasks-into-ordered-parts.md`

## [0.2.5] - 2026-06-04

### Changed
- 백로그에 미실행 plan이 여럿일 때 `fg-run` 선택 메뉴를 **우선순위순(`high → medium → low`)으로 정렬** — plan의 `<!-- priority: high|medium|low -->` 마커 기준(무표기=medium, 동순위 slug 알파벳). "모두 실행" 순차 순서도 동일하게 따름. 자동 선택은 도입하지 않음(메뉴 선택 유지). PLAN-FORMAT에 priority 마커 정의, fg-ask가 그릴링 중 설정 가능

### Added
- `.forge/codebase/` 코드베이스 지도 7개 문서(fg-map 산출 — STACK·INTEGRATIONS·ARCHITECTURE·STRUCTURE·CONVENTIONS·TESTING·CONCERNS)

## [0.2.4] - 2026-06-04

### Changed
- `fg-status` 출력을 `Date | Task | Stage | Retro` 4열 테이블로 정리 — 단계는 현재 단계 하나만(버킷 매핑), 회고는 O/X(완료 O · 건너뜀 X · 미정 —). 직전의 파이프라인 배지를 대체
- `fg-status` SKILL.md 본문을 영문으로 통일(출력 라벨·테이블 컬럼은 canonical English, 출력은 사용자 언어로 렌더) — 스킬 본문 영문 작성 규약에 맞춤

## [0.2.3] - 2026-06-04

### Changed
- `fg-status` 출력에 **작업별 `ask · run · learn · done` 단계 배지** 추가 — 각 작업이 4단계 루프에서 어디까지 왔는지 한 줄로 표시(✓ 통과 · ▶ 현재 · — 미도달 · —(skip) 건너뜀). 버킷 위치 + STATUS `retro` 필드에서만 도출(읽기 전용 유지)

## [0.2.2] - 2026-06-04

### Added
- `fg-status` 스킬 — **루프 밖 읽기 전용 상태 리포터**. `.forge/`를 조사해 진행 중(active·backlog·executed)은 상세, 완료·빠른작업은 요약으로 출력하고, 상태 머신으로 지금 필요한 다음 단계 하나와 트리거를 표시한다. 아무 파일도 쓰지 않고 자동 실행도 하지 않는다. 트리거: "forge status", "어디까지 했지"

## [0.2.1] - 2026-06-04

### Added
- `fg-quick` 스킬 — 사소한 작업용 **루프 밖 경량 차선**. 그릴링은 유지(가볍게)하되 형식 산출물(ADR·plan·run·STATUS·done·회고)을 만들지 않고 `.forge/quick/LOG.md`에 한 줄만 기록한 뒤 직접 실행. 메인 루프의 활성 슬롯·backlog·done과 격리되며, 비-trivial로 드러나면 fg-ask로 bail. 결정 기록 `.forge/adr/0003-fg-quick-lightweight-lane.md`. 트리거: "forge quick", "이거 빨리 해줘"

## [0.2.0] - 2026-06-04

### Changed
- `fg-execute` 스킬을 **`fg-run`으로 개명** — 호출은 `/forge:fg-run`, 주 트리거는 "forge run"("forge execute"는 legacy alias로 유지). 디렉터리(`skills/fg-run/`, `PLAN-FORMAT.md` 동반)·식별자·전 문서의 참조를 fg-run으로 통일. 루프 스테이지 라벨 "② Execute"는 유지(skill id ≠ stage 라벨, fg-learn/Retro 선례와 동일). 동작·상태 계약은 불변

### Added
- 회고(fg-learn)를 **저-divergence 사소한 작업에 한해 건너뛸 수 있는 경로** — fg-run 핸드오프가 명시 선택지로 제시(자동 아님, 고-divergence 미제시), STATUS.md `retro: skipped (사유)` 기록, fg-cleanup이 봉인 가드 통과로 인정. plan의 `<!-- retro-hint: optional -->`는 비구속 힌트. 결정 기록 `.forge/adr/0002-optional-retro-skip.md`

### Fixed
- fg-ask verbatim 본문의 ADR·글로서리 경로(`docs/adr/`·루트 `CONTEXT.md`)를 forge `.forge/` 계약(`​.forge/adr/`·`.forge/CONTEXT.md`)에 맞춰 정합 — ADR이 추적·참조 안 되는 위치에 생성되던 버그
- README 스킬 카탈로그·태그라인·Mermaid를 실제 스킬 동작(fg-map 포함 5개, fg-run 조건부 메뉴·STATUS 출력)과 동기화

## [0.1.2] - 2026-06-04

### Added
- `fg-map` 스킬 — 코드베이스를 4개 병렬 서브에이전트로 분석해 `.forge/codebase/`에 7개 구조 문서(STACK·INTEGRATIONS·ARCHITECTURE·STRUCTURE·CONVENTIONS·TESTING·CONCERNS)를 직접 작성하는 루프 밖 온디맨드 유틸리티. 에이전트는 확인만 반환해 context rot을 줄이고, `last_mapped_commit` 스탬프로 신선도를 표시. fg-ask가 그릴링 전 이 지도를 읽음
- 결정 기록 `.forge/adr/0001-docs-into-forge.md`

### Changed
- 모든 forge 문서를 `.forge/` 단일 디렉터리 하위로 통합 — 영속 문서(`CONTEXT.md`·`adr/`·`retro/`·`codebase/`)는 `docs/`·루트에서 `.forge/` 하위로 이동
- `.gitignore`를 화이트리스트 패턴으로 교체 — `.forge/`를 기본 제외하고 영속 문서 4종만 추적, 휘발 상태(plan/run/STATUS/backlog/executed/done)는 제외
- 5개 스킬·4개 형식 문서·CLAUDE.md·README(영/한)의 경로 참조를 새 구조로 갱신 (멀티 컨텍스트는 코드 옆 배치 유지로 예외)
- worktree 폴더를 `.gitignore`에 추가

## [0.1.1] - 2026-06-04

### Changed
- `fg-complete`를 `fg-cleanup`으로 개명, 4단계 명칭을 "완료"에서 "정리"로 통일 (기존 "forge complete" 트리거는 alias로 유지)
- 매니페스트 설명 영문화 — `plugin.json`·`marketplace.json`의 description을 영문으로 통일
- README 태그라인을 4단계 표기(`ask·plan → execute → retro → cleanup`)로 정리, `fg-plan` 통합 문구 명확화
- README Install 섹션 보강 — 로컬 클론 설치, main 브랜치 노트, 업데이트·제거 명령
- CLAUDE.md에 배포 규칙 추가, JSON 검증을 python3에서 node로 교체

## [0.1.0] - 2026-06-03

### Added
- 최초 릴리스 — `fg-*` 4단계 루프 스킬: `fg-ask`(질의·계획·그릴링), `fg-execute`(Dynamic Workflow 실행), `fg-learn`(회고·문서 승급), `fg-cleanup`(정리·봉인·재실행 방지)
- `fg-ask`에 grill-with-docs 원문 verbatim 이식 (`CONTEXT-FORMAT.md`/`ADR-FORMAT.md` 포함), 기존 `fg-plan` 단계를 `fg-ask`로 통합
- 백로그·작업 선택 메뉴("모두 실행" 지원)·회고 환류 도입, 스킬 본문 영문화
- 스킬별 형식 문서 체계 (`PLAN-FORMAT.md`, `RETRO-FORMAT.md`)
- `README.md`(영문)/`README.ko.md`(한글) 번역 쌍과 동기화 규칙
