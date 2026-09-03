# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 이 리포가 무엇인가

forge는 **Claude Code·Codex 플러그인**이다 — 코드를 빌드하는 프로젝트가 아니라, `fg-*` 워크플로우 스킬을 패키징한 플러그인이자 그 자신이 설치 가능한 마켓플레이스다. 산출물은 전부 Markdown(`SKILL.md`, 형식 문서)과 JSON(매니페스트)이다.

**플러그인 본체에는 빌드·테스트·린트 시스템이 없다.** Makefile 없고, 스킬 Markdown·매니페스트 JSON을 빌드하는 단계도 없다. "개발"은 Markdown/JSON을 편집하는 것이고, 검증은 아래 방법으로 한다. **예외는 문서 사이트 하나뿐** — 루트 `package.json`(VitePress)과 `.github/workflows/docs.yml`이 `docs/`의 Markdown을 `gyuha.com/forge/docs/`로 빌드·배포한다(랜딩 `gyuha.com/forge/`는 그대로 유지, ADR `260815-094725`). 이 `package.json`은 **문서 도구이지 플러그인 빌드가 아니다** — 이 경계를 흐리지 말 것.

> **루트 `package.json`에 `"type"` 필드를 넣지 말 것.** `scripts/*.js` 트윈 8개가 CommonJS(`require`)라 `"type": "module"`을 넣으면 리포 전체 `.js`가 ESM으로 해석되어 fg-done·fg-doctor·fg-status·fg-merge·세션 시작 훅이 전부 죽는다(bash 없는 Windows에서 실제 증상이 드러난다). VitePress 설정은 `.mts` 확장자만으로 이미 ESM이므로 이 필드가 애초에 필요 없다. 실제로 한 번 넣었다가 적대적 리뷰에서 잡혔다 — ADR `260815-094725`.

**문서 사이트를 검증할 때 반드시 볼 두 가지** — 라이트모드에서 페이지가 200으로 열리는 것만으로는 부족하다:

- **다크모드로 토글한 뒤** Mermaid 노드의 라벨↔배경 명암비를 확인한다(3:1 이상). 밝은 `fill:`을 지정한 노드는 다크 테마가 라벨을 `#ccc`로 칠해 글자가 사라진다 — 그래서 `style` 지시자에는 `color:#1a1a1a`를 함께 박는다.
- **페이지의 모든 자산 요청이 200인지** 확인한다. `<img>` 404는 **콘솔 에러를 내지 않으므로** "콘솔 에러 0건"을 근거로 삼으면 놓친다(실제로 nav 로고 404를 그렇게 놓쳤다).

```bash
# 매니페스트 JSON 유효성 (편집 후 반드시 확인 — 깨지면 설치 실패)
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json','.codex-plugin/plugin.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"

# 매니페스트 4곳 버전 동기 + 호스트 어댑터 존재 (배포 전 게이트)
npm run release:check

# 문서 사이트 빌드 (docs/*.md·VitePress 설정 편집 후 — dead link가 있으면 실패한다)
npm run docs:build

# 실제 동작 테스트는 설치해서 트리거해보는 것뿐 (단위 테스트 없음)
#   /plugin marketplace add gyuha/forge   (또는 로컬 경로)
#   /plugin install forge@forge
# 설치는 GitHub 기본 브랜치(main)를 당긴다 → 설치 테스트하려면 main에 push되어 있어야 한다.
```

**이 환경의 셸 함정 — 두 세션에 걸쳐 8번 밟았다.** 전부 "명령이 조용히 틀린 답을 낸다"는 같은 부류이고, 특히 **부정 체크(`→ 0`)와 만나면 fail-open이라 통과처럼 보인다**(0.6.11의 runnable-DoD 규칙이 이걸 다룬다). 기본 셸은 **zsh**이고 `grep`은 실은 **ugrep**이다:

- **글롭 패턴은 반드시 인용한다** — `--include='*.md'`. 인용하지 않으면 zsh가 먼저 확장해 `no matches found`로 **명령 전체가 실패**한다(이번 세션 3회, 그중 2회가 `0건`을 내 확인처럼 보였다).
- **`grep -c`는 미매치 시 exit 1이다** — `$(grep -c … || echo 0)`을 쓰면 `0\n0`이 나와 표가 어긋난다. 개수만 필요하면 `grep -o … | wc -l`을 쓰거나 exit code를 무시하지 말 것.
- **`cmd > f 2>/dev/null`은 셸 리다이렉션 오류를 못 잡는다** — `2>/dev/null`은 `cmd`에 붙지 `>`에 붙지 않으므로, 쓰기 권한이 없으면 셸 자신의 에러가 stderr로 샌다. 필요하면 `{ cmd > f; } 2>/dev/null`로 그룹을 감싼다(훅처럼 stderr가 **의미를 갖는** 곳에서는 계약 위반이 된다).
- **인용하지 않은 변수는 단어 분할되지 않는다** — `for f in $FILES`가 문자열 전체를 한 단어로 돌려 루프가 0회 돈다. 여러 파일 순회는 목록을 `for`에 직접 쓴다.
- **`grep`의 멀티바이트 컨텍스트 패턴이 죽는다** — `.{0,45}` 류가 `exceeds complexity limits`로 실패한다. 한국어 문맥 추출은 python이 안전하다.
- **경로를 기억으로 짚지 말 것** — `hooks/run-hook.test.sh`를 `scripts/`에서 찾아 "테스트가 깨졌다"고 오판했다(22/22 통과 중이었다). 측정 도구보다 **측정 기준선**을 먼저 의심한다.

## 패키징 구조 (단일 리포 = 플러그인 + 마켓플레이스)

`harness` 플러그인과 동일한 패턴이다: 리포 루트가 곧 플러그인 루트이자 마켓플레이스.

- `.claude-plugin/plugin.json` — 플러그인 매니페스트. `skills/` 가 자동 탐색되므로 `skills` 필드는 생략 가능.
- `.claude-plugin/marketplace.json` — 이 리포를 마켓플레이스로 등록. `plugins[].source` 는 `"./"`(루트가 곧 플러그인).
- `.codex-plugin/plugin.json` — **Codex 플러그인 매니페스트**(ADR `260903-080713`). `skills`가 `"./skills/"`를 가리켜 Claude와 **같은 스킬 트리**를 로드한다. 버전은 위 두 파일과 함께 4곳 동기 대상이다.
- `core/` — **호스트 중립 계약 3파일**(`HOST.md` 어댑터 선택+능력표 · `EXECUTION.md` 실행 계약 · `INTERACTION.md` 질문 계약). 워크플로·`.forge/` 상태 의미론은 전부 여기와 `skills/`·`scripts/`에 있고, 호스트별로 갈라지지 않는다.
- `hosts/<claude|codex>/` — **호스트 어댑터**(`interaction.md` · `execution.md` · `capabilities.json`). 어댑터가 소유하는 것은 *질문 방식·위임 방식·프로젝트 에이전트 로드·주행 계속·상태 UI* 뿐이다. **어댑터에 상태 모델을 복제하거나 스킬의 Codex 전용 사본을 만들지 말 것.**
- 스킬은 `skills/<name>/SKILL.md` 로 자동 탐색된다. **스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name`** 이다.
- `hooks/hooks.json` — **플러그인이 배포하는 훅**. `skills/`처럼 자동 탐색되므로 매니페스트에 등록하지 않으며, 사용자 설정(`settings.json`) 편집 없이 플러그인 설치만으로 걸린다. 현재 훅은 하나다 — `SessionStart`(매처 `startup|resume|clear|compact`, `async: false`)가 `hooks/run-hook.cmd session-start` 를 실행해 **미봉인 잔여**를 세션 진입 컨텍스트에 주입한다(ADR `260727-201031`). 본체는 `scripts/forge-hook-session-start.sh`/`.js` 트윈이고 `run-hook.cmd`는 bash→node 순으로 디스패치하는 polyglot 래퍼(superpowers 패턴 MIT 차용, 런타임 없으면 exit 0 침묵)다. **훅은 세션 시작 시 로드되므로 추가·수정은 세션 재시작 후에 적용된다**(`.claude/agents/` 카드와 동형 — ADR-0024).

매니페스트의 스킬 개수·설명을 바꿀 땐 `.claude-plugin/plugin.json`·`.claude-plugin/marketplace.json`·`.codex-plugin/plugin.json`을 함께 갱신해야 한다(셋 다 사람이 읽는 설명을 담는다).

## 핵심 아키텍처 — forge 루프

forge의 본질은 작업 하나를 한 바퀴 돌리는 4단계 루프다. 각 스킬은 **독립 실행**되며, 상태를 `.forge/` 파일로 주고받아 흐름을 잇는다.

```
fg-ask(①질의·계획·그릴링) → fg-run(②실행) → fg-learn(③회고) → fg-done(④완료) → (새 작업) fg-ask
```

- **fg-ask** — grill-with-docs식 대화형 그릴링. 계획을 도메인·용어·결정에 대고 검증해 `.forge/backlog/<slug>.md`로 적재. **반드시 본 세션 대화로** 진행(워크플로우 밖). 시작 시 STEP 0이 **미봉인 잔여**(활성 슬롯의 미봉인 `status: executed`)를 확인해, 판단이 남지 않았으면(검증 봉인 가능 + 회고 해결, 또는 회고만 밀렸고 저-divergence) **묻지 않고 봉인**한 뒤 한 줄 보고하고 같은 턴에 그릴링을 잇고, 판단이 남았으면(고-divergence·`verified: pending|failed`·멈춘 loop) 묻되 **새 요청을 버리지 않고 마감 후 그 자리로 복귀**한다 — 재트리거 요구는 폐기됐다. 사정거리는 활성 슬롯 1건이며 `executed/` park은 개수만 보고하고 손대지 않는다(의도된 대기 — `fg-done all`/`fg-learn` 소관), 검증 게이트(ADR-0009)는 불가침, 위임 봉인이라 상세 요약을 내지 않는다(ADR-0032 개정) — ADR `260727-201115`.
- **fg-run** — `.forge/plan.md`를 Claude Code Dynamic Workflow로 실행, 계획↔실제 차이를 `.forge/run.md`에 기록.
- **fg-learn** — 학습을 분류해 영속 문서로 승급, `.forge/retro/`에 회고 남김. 항상 대화형.
- **fg-done** — 루프의 ④ 완료(봉인) 단계: 한 바퀴의 잔여물을 정리(tidy up)해 마감한다 — 회고 확인, `STATUS.md`를 `done`으로 마감, 작업을 `.forge/done/<날짜-slug>/`로 봉인하고 활성 `.forge/`를 비워 루프를 닫음 → **재실행 방지의 핵심 메커니즘**. 기계적 봉인(사전점검·게이트 강제·STATUS 마감·아카이브·슬롯 비우기)은 결정론 스크립트 `forge-done.sh`/`.js`가 처리하고(세 봉인 경로 공유·게이트-우선-비파괴, ADR-0030) 이 스킬은 exit code로 라우팅만 한다 — fg-status(ADR-0020)에 이은 스크립트 백킹. `all` 인자(`fg-done all`)는 **이미 실행된** 작업(활성 슬롯+`executed/` 전부)의 회고를 무조건 일괄 skip하고 각자 개별 `done/`으로 봉인하는 봉인 전용 batch — 백로그 미실행 작업은 promote·run하지 않고(그건 fg-next all), 검증 게이트(ADR-0009)는 불가침, `failed`는 봉인 안 하고 fg-run으로 라우팅, 확인 게이트 1회. fg-next all의 봉인 전용 사촌(완화 계열 ADR-0002/0010/0016 옆) — ADR-0023.

**루프 밖 스킬(이 4단계에 속하지 않음):** `fg-map`(코드베이스 지도 유틸리티)·`fg-quick`(경량 차선)·`fg-status`(읽기 전용 상태 리포터 — `.forge/`를 조사해 현황+다음 단계를 출력, 아무것도 쓰지 않고 자동 실행 안 함)·`fg-next`(상태를 읽어 fg-status의 상태 머신으로 다음 단계 하나를 도출해 한 줄로 알린 뒤 그 스킬을 곧바로 실행하는 오케스트레이터 — 보고만 하고 멈추지 않음, fg-status는 보고만/fg-next는 행동까지. 기본은 one-shot이며 자체적으로는 아무것도 쓰지 않고 위임받은 스킬이 모든 쓰기를 함(단 회고 fg-learn이 재그릴링 권고 없이 정상 종료되면 같은 호출에서 봉인 fg-done까지 잇는 게 유일한 예외 — ADR-0026). `all` 모드(`fg-next all`)는 백로그가 빌 때까지 선형 기계적 단계를 자동 추천 진행하며(옵트인 `driveCommit`이 켜져 있으면 태스크를 봉인할 때마다 그 태스크를 로컬 커밋해 롤백 지점을 남긴다 — 커밋만이고 push는 안 하며, 거부되면 `fork` 벽, 기본 off. 단일 정의는 `skills/fg-next/DRIVE.md` Part 3, ADR `260901-213128`) 회고는 (divergence 무관) 항상 자동 skip하고 대화의 벽(실패/검증불가 UAT·진짜 fork·빈 상태)에서만 멈춤 — ADR-0010(개정 2026-06-08))·`fg-loop`(goal 주도 한정 재계획 루프 — 기초 질의(대화)로 기계 검증 가능한 정지 체크·승인된 fix-forward 재계획 범위·상한(기본 3라운드)을 `.forge/loop.md`에 못 박고 초기 백로그를 적재한 뒤, 체크 전부 통과까지 run→UAT→회고 자동 skip→봉인을 주행. loop.md의 `## Tasks` 멤버십 목록에 등재된 slug만 승격한다(벽에 멈춘 동안 fg-ask가 적재한 비소속 plan은 무필터 주행에 휩쓸리지 않음). active slot이 빈 stop-check 실패는 범위·상한 내 fix-forward plan으로 자동 생성(`<!-- generated-by: fg-loop -->` 마커, 단조 task 번호 유지)하고, `verified: failed`는 별도 backlog plan 없이 같은 active task를 cap 안에서 제자리 수리(`<!-- repaired-by: fg-loop -->`)하는 자동 fix-forward 케이스. 벽 = 검증불가 UAT·진짜 fork(범위 밖 수정 포함)·상한 소진·같은 체크 2연속 무진전·tension(fix-forward가 이미 통과한 다른 체크를 깨뜨리는 regression 핑퐁, 기계 감지)·safety(승인 범위 안이라도 비가역 액션 클래스면 정지, best-effort 자기분류)·stalled-waiting(아래 `waiting`이 `×2` 증거 불변으로 정체)·blocked-health(체크 명령이 아예 실행 불가 — 도구·인증 부재; 주행 전 실행파일 도출 점검 + 보수적 사후 승격)·budget-exhausted(선언한 `budget-tokens` 토큰 천장 도달 또는 사전 예측상 남은 예산이 태스크당 관측 평균 미달) — 이 넷은 생성·제자리수리된 fix-forward 또는 fg-loop 고유 기계에서만 발생해 fg-loop 전용(fg-next all 비적용). **`waiting`은 벽이 아니다** — 체크에 `evidence: external`을 선언하면(§1, 기본 off) 그 체크는 통과 전까지 무조건 `waiting`으로 분류돼 `replan-round`를 안 쓰고 fix-forward도 안 만들며, 사람에게 아무것도 요구하지 않는 상태로 턴만 끝낸다(증거 도착 후 재트리거로 재개). 대가로 "빨간 CI"와 "미완 CI"를 구분 못 해 선언된 외부 체크는 자동 수리 대상에서 빠지고, 그래서 `stalled-waiting` 상한이 영구 대기를 막는 유일한 안전장치다. 신규 최상위 필드 없이 `waiting ×N`은 기존 `## Check progress` 원장에, `evidence: external`은 기존 체크 절에 흡수(소비자 ripple 회피). **지출 상한만은 최상위 필드 2개**(`budget-tokens`·`budget-spent · since:`)인데, 지출은 어느 체크에도 속하지 않는 drive 수준 값이라 원장에 집이 없고 구조적 쌍둥이가 `replan-round`/`replan-cap`이기 때문이다. 결정론 트윈 `forge-loop-spend.sh`/`.js`가 세션+서브에이전트 트랜스크립트의 원시 토큰 총량을 델타로 합산해 **경계당 1회 호출**로 exit code 판정하며(`3` 초과·`4` 사전예측·`5` 측정불가→`blocked-health`·`0` 통과), `none`이면 전부 우회. 재는 것은 "이 드라이브의 지출"이 아니라 **"루프 수명 동안 이 프로젝트의 토큰 처리량"**이다(안전 한계이지 회계 장부 아님 — 과대 계상이 안전한 오차). `fg-next all` 비적용은 **구조적 불가능이 아니라 범위 결정**이다(천장이 `loop.md`에 살고 그쪽엔 계약 파일이 없음) — ADR-0016 개정 2026-08-19 — LoopX 개념 각색이며 quota·스케줄링은 다중 goal 경쟁 부재로 미도입, ADR-0016 개정 2026-08-09. goal 충족 시 요약 보고 후 loop.md 삭제, 벽에서는 loop.md 유지·재트리거로 stateless 재개. 옵트인 `driveCommit`은 fg-next all과 동일하게 적용된다(태스크당 로컬 커밋, 거부 시 `fork` 벽 — `skills/fg-next/DRIVE.md` Part 3). 기둥 1의 의도적·경계 있는 완화(fg-quick의 기둥 2 완화와 동형 선례) — ADR-0016)·`fg-merge`(`git merge` 뒤 비-기본 브랜치의 `.forge/branch/<branch>/`를 `.forge/`로 통합하는 유틸리티 — 결정론 스크립트(forge-merge.sh/.js)가 시간ID ADR 이동(충돌 시 다음 글자, cascade 재번호 없음)·incoming done/backlog task 번호 재부여·retro 이동·CONTEXT 용어 병합·done 합침·브랜치 폴더 제거, 기계 자동(AI 없이 CI 게이트 가능)/의미 충돌만 대화(의미 ADR 모순은 PR 리뷰). 코어 스크립트는 git 조작 안 함(CI git-free); 단 `fg-merge <branch>`(인자 모드)는 대화형 편의로 `git merge`를 먼저 대신 돌림 — 스킬 계층 한정·기본 브랜치·충돌 시 그자리 정지·통합 미커밋 — ADR-0011·`260717-10a`)·`fg-cleanup`(오래된/대체된 ADR을 활성 결정 집합에서 은퇴시키는 유틸리티 — 후보 제시→사람 승인으로 `.forge/adr/retired/<NNNN>-slug.md`로 이동+supersede 마킹, 번호 불변·재사용 금지·삭제 안 함, fg-ask는 retired/를 정답소스로 안 읽음; 작업 봉인은 fg-done이지 이 스킬이 아님 — ADR-0012)·`fg-tdd`(영속 TDD 모드 토글 — `.forge/config.json`의 `tdd`; fg-ask가 작업마다 이 설정을 기본 답으로 "이 작업 TDD로?"를 묻고, plan의 `<!-- tdd: on -->`이면 fg-run이 test-first로 실행 — ADR-0008)·`fg-eco`(eco 모드 토글 — `.forge/config.json`의 `eco`; 켜면 세 가지를 활성화: (1) fg-run 위임 워크플로우 서브에이전트를 sonnet으로 캡(내리기만·세션 모델 불변·명시적 사용자 지시 우선), (2) 내장 Eco laziness-first 규율(동반 `skills/fg-eco/ECO.md` — 코드 단순성 + 출력 prose 압축(caveman 차용))을 fg-run 서브에이전트 프롬프트에 prepend·fg-ask 그릴링에 YAGNI 렌즈로 직조·현 세션에 적용, (3) **eco 요약 표** — 작업이 끝나는 지점(fg-run 단일작업 핸드오프·fg-done 명시적 단일 봉인·배치/무인 경로)의 산문 핸드오프를 헤더 한 줄(제목·`#task`·`verified`·divergence)+`▸ 요청`/`▸ 수행`(슬라이스 표)/`▸ 다음`으로 **교체**(추가 아님). (2)의 스타일 압축이 지킴 여부가 안 보여 부족했다는 실증에서 나온 *형태* 규율이고, 재료 보장을 위해 fg-run이 run.md에 슬라이스별 한 줄을 기록한다(eco 무관 항상). 실행 *중* narration은 불변, 그릴링·회고·생성 문서·fg-quick은 제외, eco off면 종전 산문 그대로 — ADR `260730-230321`. Eco 규율은 독립 스킬 없이 여기에만 살며 eco가 유일한 활성화 경로 — ADR-0014)·`fg-adversarial-review`(fg-run↔fg-learn 사이 선택적 적대적 리뷰 — "결과가 틀렸다고 가정하고 증거를 찾는" 자세로 6개 렌즈(실패 지점·숨은 가정·요구사항 오해·보안/성능/데이터 손실·예상 못한 오용·약한 근거)를 dynamic workflow 서브에이전트로 병렬 팬아웃, findings를 `.forge/review.md`(휘발)에 기록하고 수정 필요 건은 사람 승인 후 fix-forward plan으로 만들어 fg-run 재실행. 검증(UAT)과 별개·비-게이트라 봉인을 안 막고(STATUS `reviewed:`는 기록용), fg-next all·fg-loop 무인 주행에선 회고처럼 항상 skip, 외부 스킬 하드 의존 없음 — ADR-0018)·`fg-statusline`(statusline에 forge 진행 상태를 띄우는 설정 유틸리티 — 두 설치 모드. **방법 1(append)**: statusLine은 하나뿐이라 기존 것을 교체하지 않고 아래 별도 줄로 자동 래핑(원본 보존)하는 얇은 forge-전용 fragment(ADR-0017, 불변). **방법 2(merge)**: forge 소유 통합 스크립트(`forge-statusline-full.sh`/`.js` 트윈)가 daleseo식 시스템 정보(모델·추론강도·디렉터리·⎇ git 브랜치+상태 · 동적이모지+Context/크기+그라디언트 사용량 바 · ⏱ 세션 경과·$비용·±라인)와 forge 진행을 **의미 단위 그룹 대괄호 `[...]`**로 한 스크립트에 출력하되 forge 부분은 fragment에 위임(fragment 기본 `⚒ ` 접두 그대로·`FORGE_SL_PREFIX` 잔존, 신설 `FORGE_SL_SEP`으로 구분자 위임·`FORGE_SL_DENSITY`로 밀도 위임)해 단계 로직을 재사용(3중 복제 금지). **compact/full 밀도 토글**은 wired command의 위치 인자로 저장(새 config 키 없음), 구분자는 방법 2 `|`·방법 1 `·`, 모드 지시자는 `🧪`(tdd)·`♻️`(eco). 설치 결정: 기존 statusline 있으면 1/2 선택·없으면 2 자동·Windows+기존이면 2만(wrapper가 bash 전용). 방법 2가 기존을 교체할 땐 원본 보존+복원 안내. 모드는 settings command 경로로·밀도는 그 command 인자로 감지(둘 다 새 config 키 없음). settings command는 절대경로(tilde 금지), 스크립트는 stdin 세션 JSON의 cwd 파싱·동반 파일을 자기 위치(BASH_SOURCE/__dirname)에서 해석, 재시작 후 적용 — ADR-0017·ADR-0029)·`fg-doctor`(상태·문서 무결성 health check — 읽기 전용·루프 밖. `.forge/` 상태 계약(고아 파일·STATUS 필드·slug 페어링·half-sealed)과 문서/매니페스트 정합(버전 4곳 동기·README 이중언어·CLAUDE.md 스킬 목록 등)을 검사해 위반을 severity·actionable 수정 안내와 함께 보고한다. 아무것도 쓰지 않고 자동 수정·자동 실행 안 함 — fg-status는 진행, fg-doctor는 건강. harness engineering의 init.sh health check를 forge에 적용 — ADR-0019)·`fg-help`(스킬 사용법 도움말 유틸리티 — 읽기 전용·루프 밖. `/forge:fg-help`(무인자)는 forge `fg-*` 스킬 전체를 루프 4단계 + 루프 밖 유틸리티로 그룹핑한 개요를, `/forge:fg-help <명령>`은 개별 스킬의 4줄 상세(무엇·언제·트리거·다음단계)를 출력한다. 사용법 소스는 각 `skills/*/SKILL.md`의 frontmatter `description` 단일 정의(사본 0)이고 `${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md` glob으로 forge 스킬만 대상. **결정론 스크립트 트윈 없음** — 사용자 언어 번역이 스크립트로 불가해 LLM 실행(이 점이 스크립트-백킹된 fg-status/fg-doctor와 다르다). fg-status가 길 잃은 사용자에게 이를 교차 참조("사용법은 `/forge:fg-help`"). 아무것도 안 쓰고 자동 실행 안 함 — fg-status는 진행, fg-doctor는 건강, fg-help는 사용법 — ADR `260814-104534`)·`fg-drop`(미완 작업을 폐기하는 유틸리티 — 봉인 안 된 작업(backlog plan·활성 슬롯·`executed/` 회고 대기·멈춘 goal `loop.md`)을 항목별 위험도와 함께 제시(1개는 drop/cancel·2–4 체크박스·5+ 번호 텍스트 목록)한 뒤, 별도 후속 질문으로 하드 삭제(기본·흔적 없음) 또는 `.forge/dropped/<slug>/` 보관을 고르게 하고, 불가역 삭제 전 확인 게이트에서 "이미 실행된 작업의 바뀐 코드는 되돌리지 않음"을 경고한다. forge 상태만 지우고 git·코드는 안 건드림. goal 루프는 `loop.md`+멤버의 미완 backlog/active/executed 상태를 통째로만 drop하고 멤버 task는 개별 제외(done·비멤버 불변; 멤버십 재동기화 로직을 안 만들기 위함). `dropped/`는 기본 브랜치에선 휘발(gitignore), 비기본 branch root에선 루트 전체와 함께 추적·fg-merge 보존되며 fg-doctor는 관용·fg-status는 무시. 작업 봉인은 fg-done, 폐기는 이 스킬 — ADR-0021)·`fg-agents`(프로젝트 도메인 에이전트를 생성하는 루프 밖 유틸리티 — 대화형 그릴링(기둥 1, 워크플로 밖)으로 반복·분리 가능한 작업을 캐 역할을 도출하고 표준 `.claude/agents/<role>.md` role 카드를 자체 생성한다. 카드 `description`에 "언제 쓰이나"를 담아 fg-run 워크플로 빌더가 slice↔role 자동 매핑(plan 마커 대신)에 쓴다. `.forge/codebase/` 지도·CONTEXT 있으면 연료로 읽고 없으면 직접 탐색(graceful·하드 의존 없음). 역할은 사람 승인 부분집합만 카드화하고 마땅한 seam 없으면 0개도 정직한 결과(억지 생성 금지). 핵심 제약(ADR-0024): `.claude/agents/`는 세션 시작 시 1회 로드라 세션 중 만든 카드는 동적 픽업 불가 → 생성한 카드는 **세션 재시작 후** fg-run이 로드·`agentType` 호출, 운영 흐름은 생성→재시작→활용. 카드는 forge `.forge/` 상태가 아니라 프로젝트 자산이라 git 커밋. fg-run 확장(part1)이 호출 경로를 열고 이 스킬(part2)이 카드를 생성 — ADR-0024)·`fg-showme`(브라우저 시각 컴패니언 유틸리티 — obra/superpowers v6.1.1의 Visual Companion을 MIT 귀속과 함께 vendoring. zero-dependency Node 서버(`scripts/server.cjs` 등 5파일)가 에이전트가 push하는 HTML(목업·다이어그램·A/B 시각 비교)을 브라우저 탭에 실시간 표시하고, 사용자의 클릭·텍스트 입력을 이벤트(JSONL)로 받아 에이전트가 **답으로** 읽는다(표시 전용이 아닌 보조 답변 채널 — 두 채널 병합·모순 시 되묻기. 선택형 화면의 필수 확정 버튼을 누르면 서버 기동 시 장전한 `Monitor` 감시가 확정·텍스트 이벤트만 통과시켜 터미널 턴 없이 바로 대화를 재개하고(탐색 클릭은 안 깨움), 기둥 1은 근거를 옮겨 온전하다 — 터미널만 재개시킬 수 있어서가 아니라 브라우저가 Dynamic Workflow 런타임 입력이 아니라서다. ADR `260730-224259`·`260805-005436`). 세션 파일은 모든 브랜치에서 **최상위** `.forge/showme/<세션>/`(휘발 — 전역 예외, 브랜치 루트 아님)이며 **git 진입 경로가 구조적으로 없다**: `start-server.sh`가 자체-ignore `.forge/showme/.gitignore`(`*` 한 줄)를 써 주고(사용자의 루트 `.gitignore`는 불가침 — 유일 예외), 종료 시 세션 폴더를 삭제·마지막 세션이면 `.forge/showme/` 통째 제거, 크래시/유휴 타임아웃이 남긴 죽은 세션은 다음 시작 때 sweep한다(ADR `260719-224442` 개정 2026-09-02). 세션 키 URL 인증·재시작/재연결 생존·4시간 유휴 자동 종료, 텔레메트리·원격 자원 없음. fg-ask 그릴링 중 시각적 질문이 처음 나올 때 just-in-time으로 1회 제안(단독 메시지, 거절 시 재제안 없음)되고, 수락 시 fg-ask가 `../fg-showme/VISUAL.md`·`scripts/`를 파일 참조로 직접 사용(ECO.md/FORGE-ROOT.md와 같은 단일 정의 관례)하며 Output(핸드오프) 시 서버 종료. 이 스킬 자체는 단독 진입점(`fg-showme` 시작 / `fg-showme stop` 종료) — ADR `260719-224442`)·`fg-agenda`(**아직 내리지 않은 결정**이 사는 자리를 주는 루프 밖 계획 유틸리티 — forge의 산출물은 전부 *빌드* 산출물이고(plan의 Work slices) ADR은 **이미 내려진** 결정을 기록하므로, 안개 속 작업은 억지로 완결된 계획이 되거나 결정이 대화·회고 산문에 흩어져 사라진다. `.forge/agenda.md` 한 파일 5개 절(목적지·결정된 것·열린 질문·아직 또렷하지 않은 것(fog)·범위 밖)에 담고, 활성 의제는 1개(활성 슬롯 규율과 동형), 위치는 해석된 forge 루트(브랜치별 — `loop.md`와 같은 취급, 전역 예외 아님), 열린 질문이 0이면 **스스로 삭제**(fg-loop의 loop.md 삭제 선례 — 영속 흔적은 낳은 ADR·백로그 plan이라 아카이브 미발명). **자율성 경계가 정체다: 에이전트는 무엇을 결정해야 하는지 캐내고(breadth-first 그릴링·fog↔질문 구분[테스트는 "지금 질문을 정확히 진술할 수 있나"이지 답할 수 있나가 아니다]·답 가능한 것 우선 순서·다음 질문 선택·fog 승격·범위 밖 판정) 목적지와 모든 답은 사람이 한다 — 에이전트는 자기 질문에 스스로 답하지 않는다**(기둥 1; 그러면 "결정된 것"이 결정 아닌 추측이 된다). 두 모드는 agenda.md 존재로 갈린다 — open: 목적지 합의 → breadth-first 그릴링 → 안개가 없으면 의제를 만들지 않고 fg-ask를 가리킴 → agenda.md 작성 → **멈춤**(아무것도 해소 안 함) / working: 질문 하나(지목 없으면 열린 질문 첫 줄=frontier)를 `fg-ask` 방법으로 해소 → `## 결정된 것` 한 줄 + 세 조건 넘으면 ADR → 새 질문·fog 승격·범위 밖 재차팅 → **기본은 같은 대화에서 계속**(다음 질문으로 이어지며, 사용자가 멈추라 하거나 열린 질문이 0일 때 끝난다 — 질문마다 재트리거하지 않고, 매 질문 앞에 `agenda.md`에서 파생한 오리엔테이션 블록(목적지·결정/열린/fog 수·지금 푸는 질문)을 띄운다. open의 **멈춤**은 유지하되 이유를 밝힌다 — 지형을 다 보기 전에 답하면 답이 편향된다). "하나씩"은 *순차*의 뜻이고 *호출당 하나*가 아니다. **의제는 결정만 소유** — 빌드 가능해지면 그 줄은 의제를 떠나 fg-ask가 적재하는 평범한 백로그 plan이 된다(두 번째 백로그 방지). 의존 엣지·blocking 없음(파일 하나를 위→아래로 읽는 것이 frontier)·티켓 유형 분류 없음(해소기의 이름일 뿐, forge엔 이미 다 있음)·스크립트 없음(ADR-0022/0031 바 미달), 그릴링 방법은 `../fg-ask/SKILL.md` 참조로만 쓰고 출력만 다름(백로그 plan이 아니라 의제 한 줄+조건부 ADR). `fg-next`/`fg-status` 다음 단계 사슬에 **미편입**(fg-status는 한 줄 보고만) — fg-loop의 거울상(기계 검증 정지·무인 vs 판단 정지·HITL). Wayfinder(`mattpocock/skills`, MIT) **개념** 각색이며 코드 vendoring 아님(파일 복사 없음, 이름은 forge 어휘 — "지도"는 이미 fg-map의 것) — ADR `260805-201313`)·`fg-security`(코드베이스 보안 감사 유틸리티 — 방법론은 [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill)을 MIT 귀속과 함께 **vendoring**(`AUDIT.md` + 공격유형 플레이북 9종 + `report-schema.json`·`validate-findings.cjs`, **원형 유지**·진입 파일만 개명 — forge 자동 탐색 충돌과 중첩 오탐 회피). forge가 더하는 것은 셋뿐: ① 산출물이 **리포 밖** — 업스트림 기본값 `~/security-audit-skill/<repo>/run-<N>/`(**리포 안**에 두면 `.gitignore` 관례에만 의존해 안전하고 forge는 사용자의 `.gitignore`를 편집하지 않으므로(자기 상태 디렉터리 안의 자체-ignore만 예외 — fg-showme, ADR `260719-224442` 개정), 빈 리포에서 `git add -A`가 `findings.json`을 스테이징한다 — 리포 밖은 구조적으로 안전; 대가는 팀 공유 불가·머신 변경 시 소실) ② **심각도 게이트**(CRITICAL·HIGH 제안·MEDIUM 제안+묶기 권고·**LOW/INFO는 plan 없음**) 통과분만 사람 승인 후 `<!-- generated-by: fg-security -->` fix-forward plan, DoD는 "취약점 재현 불가" ③ 무인 주행 항상 skip. 봉인 게이트 아님 — ADR `260820-215004`). 특히 **fg-quick**은 사소한 작업용으로, 그릴링은 유지(기둥 1)하되 형식 산출물(ADR·backlog plan.md·run.md·STATUS·done·회고)을 만들지 않고 `.forge/quick/LOG.md`에 한 줄만 기록한 뒤 직접 실행한다. **메인 루프의 활성 슬롯·backlog·done을 일절 건드리지 않아 상태 계약과 격리**되며, 비-trivial로 드러나면 fg-ask로 bail한다(상세·트레이드오프: `.forge/adr/0003-fg-quick-lightweight-lane.md`). 즉 기둥 2(문서=연료)를 trivial 작업에 한해 의도적으로 완화한 차선이다.

### 상태 계약 (`.forge/`의 휘발 상태 — git 미추적)

스킬을 편집할 때 이 입출력 계약을 깨지 않아야 흐름이 이어진다. 입력 파일이 없으면 각 스킬은 앞 단계를 안내한다.

**브랜치별 forge 루트 (ADR-0011).** 아래 표·설명의 모든 `.forge/...` 경로는 **해석된 forge 루트 기준**이다 — 기본 브랜치(`config.json`의 `defaultBranch`, 없으면 `main`)면 `.forge/`, 그 외 브랜치면 `.forge/branch/<branch>/`. 단 전역 예외 세 개(`.forge/config.json`·`.forge/codebase/`·`.forge/showme/`)는 모든 브랜치에서 항상 최상위 `.forge/`다. **`config.json`의 키**는 현재 넷이다 — `tdd`(fg-tdd 토글)·`eco`(fg-eco 토글)·`driveCommit`(무인 주행의 태스크당 커밋, **엄격 불리언·기본 `false`**)·`driveCommitMessage`(그 커밋 메시지 템플릿, 선택 — 치환자는 `{title}`·`{slug}`·`{task}` 셋뿐). 앞의 둘은 작업마다 토글하는 값이라 전용 스킬이 있고, 뒤의 둘은 프로젝트당 한 번 켜는 값이라 **토글 스킬 없이 파일을 직접 편집한다**(의도된 비대칭). 비-기본 브랜치의 루트는 **통째로 git 추적**된다(`.gitignore`가 `!.forge/branch/`로 화이트리스트). 경로가 브랜치별로 네임스페이스되어 두 브랜치가 같은 파일을 안 건드리므로 git merge 충돌이 없고, 브랜치 내용은 `git merge` 뒤 **fg-merge**가 `.forge/`에 통합한다(task 번호 재부여·ADR 시간ID 이동[충돌 시 다음 글자, cascade 재번호 없음]·retro 이동·CONTEXT 병합·폴더 제거). 단일 정의는 `skills/fg-run/FORGE-ROOT.md`이며 모든 루프 스킬이 이를 참조한다(복붙 금지). 기본 브랜치의 휘발 상태는 종전대로 gitignored — 브랜치 루트만 추적되는 의도된 비대칭.

| 파일 | 생산자 | 소비자 |
| --- | --- | --- |
| `.forge/ask.md` (fg-ask 그릴링 시작 시 쓰는 표시용 마커, 백로그 적재/fg-quick 이탈 시 삭제) | fg-ask | fg-statusline(표시 전용 — 다른 스킬은 게이트로 읽지 않음) |
| `.forge/backlog/<slug>.md` | fg-ask | fg-run(선택 메뉴·승격) |
| `.forge/plan.md` (활성 슬롯) | fg-run(백로그에서 승격) | fg-run(정답 기준), fg-learn |
| `.forge/run.md` | fg-run | fg-learn |
| `.forge/review.md` (적대적 리뷰 findings — 휘발, 활성 슬롯 동반, 선택적·비-게이트) | fg-adversarial-review | fg-learn(retro 승급 입력)·fg-done(봉인 시 done/ 아카이브) |
| `.forge/STATUS.md` (활성 슬롯, `status: executed`, `verified: pending`) | fg-run(run.md 기록 직후 작성, 핸드오프 UAT로 `verified:` 기록) | fg-run(상태 요약·검증 재진입)·fg-learn(검증 통과 시 회고)·fg-done(검증→회고 게이트 후 `status: done` 마감) |
| `.forge/executed/<slug>/` (+`STATUS.md`, `status: executed`) | fg-run("모두 실행" park) | fg-learn(회고 대기), fg-done(봉인) |
| `.forge/done/<날짜-slug>/` (+`STATUS.md`, fg-done이 `status: done`으로 마감) | fg-done | fg-ask(slug 충돌 검출)·fg-run(완료 판별·상태 요약)·fg-learn(회고 대상 제외 — 단 `retro: skipped`는 일괄 승급 모드의 후보)·fg-done(이중 봉인 방지) |
| `.forge/loop.md` (goal 계약 — 정지 체크·replan 라운드/상한·`## Tasks` 멤버십, goal 충족 시 fg-loop가 삭제) | fg-loop | fg-loop(재개·멤버십 필터 주행)·fg-status(한 줄 보고+상태 머신 step 0)·fg-ask(벽에 멈춘 루프 경고)·fg-next(all 모드 주행 양보)·fg-merge(브랜치 루트 잔존 시 in-flight halt) |

- **활성 슬롯은 항상 1개** — 한 plan.md = 한 run.md = 한 봉인. 백로그는 미실행 대기열, `executed/`는 "실행됐으나 미회고"의 명시적 상태다. plan 첫 줄의 `<!-- forge-slug: ... -->` 주석이 회고·봉인의 짝 맞춤 식별자다(파일 이동에도 영속).
- **활성 슬롯·백로그·executed가 모두 비어 있으면 = 진행 중 작업 없음.** fg-run는 빈 상태에서 실행하지 않는다(재실행 방지). fg-done이 봉인하며 비운다.
- **STATUS.md는 작업 파일들과 함께 이동하는 동반 마커다(이중 장부 아님).** 상태의 원천은 파일 위치이고 STATUS.md는 plan/run과 함께 활성 슬롯→`executed/`→`done/`을 따라 이동한다. fg-run가 `status: executed`(+`verified: pending`+`retro: pending`)로 만들고 fg-done이 `status: done`(+`completed`/`verified`/`retro`/`docs updated`)으로 마감한 뒤 plan/run과 함께 아카이브한다. 완료 판별 = `done/*/STATUS.md`의 `status: done`.
- **봉인 전 검증 게이트(ADR-0009).** 루프 순서는 run → verify → learn → done. fg-run 핸드오프가 plan 목표에 대고 UAT를 수행해 STATUS `verified:`를 기록한다 — **봉인 가능** `yes`/`skipped (사유)`/`n/a (사유)`, **차단** `pending`(미검증)/`failed (사유)`(검증했으나 깨짐). fg-done은 **검증 게이트를 회고 게이트보다 먼저** 확인하고(no-seal-without-verification), 봉인 가능 값이 아니면 봉인하지 않는다. `pending`은 fg-run 검증 전용 재진입(재실행 없이 UAT만)으로, `failed`는 fg-run의 parked-failed 회수(executed/→active slot unpark)·fix-and-re-run 또는 fg-ask 재그릴로 라우팅 — fg-run이 unpark의 단일 소유자다. `failed`은 fresh re-run으로 봉인 가능 값에 재검증될 때만 봉인되며 waiver로 통과시키지 않는다. Run all은 작업별 UAT를 파킹 전 수행(sealable만 파킹, `failed`은 active slot에 남김). ADR-0009 이전 봉인 작업은 `verified: n/a (legacy pre-ADR-0009)`로 백필됐다.
- **회고는 저-divergence 사소한 작업에 한해 건너뛸 수 있다(ADR-0002).** 기본값은 회고(fg-learn)다. run.md의 계획↔실제 차이가 없거나 미미할 때만 fg-run 핸드오프가 "회고 / 건너뛰기"를 명시 제시하고, 사용자가 건너뛰기를 고르면 STATUS.md의 `retro:` 필드에 `skipped (사유)`를 기록한다(회고 파일 없음). fg-done의 봉인 가드는 회고 파일 존재 **또는** `retro: skipped`를 통과 조건으로 인정한다. divergence가 크면 건너뛰기를 제시하지 않는다. fg-ask는 plan에 `<!-- retro-hint: optional -->`(비구속 힌트)를 남길 수 있을 뿐, 자동 건너뛰기는 없다.
- 재그릴링이 필요하면 fg-learn/fg-run가 **fg-ask**를 가리킨다(과거 별도 `fg-plan` 단계는 fg-ask로 통합됨).

### 영속 문서 모델 (`.forge/` 내부, git 추적)

휘발 상태와 같은 `.forge/` 지붕 아래 있지만, 이들은 **영속이며 루프의 "연료"**다. `.gitignore`가 `.forge/`를 기본 제외(`​.forge/*`)하되 이 영속 문서들만 화이트리스트로 되살려 추적한다(`!.forge/CONTEXT.md` · `!.forge/adr/` · `!.forge/retro/` · `!.forge/codebase/` · `!.forge/config.json`). 즉 **위치는 `.forge/` 안, 구분은 git 추적 여부**다. 전부 **lazy 생성**(쓸 내용이 생길 때만).

- `.forge/CONTEXT.md` / 루트 `CONTEXT-MAP.md`(멀티 컨텍스트) — 도메인 글로서리. 용어만, 구현 세부 금지. fg-ask가 그릴링 중 인라인 갱신. **멀티 컨텍스트만 예외** — 컨텍스트별 `CONTEXT.md`는 코드 옆(`src/<context>/`)에, `CONTEXT-MAP.md`는 루트에 둔다(`.forge/` 통합 대상 아님). 단일 컨텍스트만 `.forge/CONTEXT.md`.
- `.forge/adr/<id>-slug.md` — 아키텍처 결정. ID는 시간기반(`YYMMDD-HHMMSS`+같은-초 충돌 시에만 소문자 글자; 기존 `YYMMDD-HH`+글자·순차 `NNNN`은 grandfather로 공존, ADR-FORMAT.md). `decided`에 시각(분)까지 기록. 세 조건(되돌리기 어렵다/맥락 없이 의아하다/진짜 트레이드오프) 모두 충족 시에만.
- `.forge/retro/YYMMDD-HHMMSS-slug.md` — 세션 회고 로그. 승급 바를 못 넘는 학습의 종착지.
- `.forge/codebase/*.md` — fg-map(루프 밖 유틸리티)이 생성하는 코드베이스 지도(7문서). fg-ask가 그릴링 전 읽어 context rot을 줄인다.

형식 정의는 한 벌만 존재하며 소유 스킬의 디렉터리에 둔다 — `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`(grill-with-docs 원본), `skills/fg-run/PLAN-FORMAT.md`(plan.md 형식 + 분할 규칙; 생산자는 fg-ask지만 fg-ask 디렉터리는 verbatim 영역이라 소비자 쪽에 둠), `skills/fg-learn/RETRO-FORMAT.md`. 전부 영문(생성되는 문서는 사용자 언어). 다른 스킬(fg-done 포함)은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`(상대경로 `../fg-ask/` 등)로 참조하고 자체 복사하지 않는다. 루트 `references/` 디렉터리는 폐지됐다.

형식 문서 외에 **공유 규율 문서**도 같은 "단일 정의·복붙 금지" 원칙을 따른다: `skills/fg-run/FORGE-ROOT.md`(forge 루트 해석 — 모든 루프 스킬 참조, ADR-0011)와 `skills/fg-next/DRIVE.md`(무인 주행 규율 — 턴 내 계속 + **forge가 배포하는 `Stop` 훅**(주경로: 주행이 `drive.md` 마커를 쓰고 훅이 `exit 2`로 턴 종료를 막는다, 상한 30분·50회) + `/goal` 폴백·문구 규칙·정직한 폴백; fg-next `all` 모드·fg-loop이 참조하되 각자 자기 벽 집합을 채움, ADR-0028)가 그것이다.

## 설계 원칙 (두 기둥)

스킬을 수정할 때 이 둘을 깨면 forge가 forge가 아니게 된다:

1. **그릴링은 절대 실행 워크플로우 안에 넣지 않는다.** 위임 실행(Claude Code Dynamic Workflow·Codex collaboration/subagent)은 **실행 중 사용자 입력을 못 받는다** — 이것이 이 기둥의 근거이며, 호스트가 늘어도 사라지지 않는다. 한 질문씩 주고받는 그릴링(fg-ask)은 반드시 워크플로우 밖 대화로.
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.

## 스킬 편집 규약

- **핸드오프**: 각 스킬은 끝에서 "방금 한 것 / 다음 단계 / 시작하는 법 / (대안)"을 **핸드오프 표**로 낸다. **라벨의 canonical 이름은 영문**(`Just did` · `Next step` · `How to start` · `Alternative`, 헤더는 `Item` · `Detail`)이고 스킬 본문은 그 이름으로 셀을 지칭하되 **화면 출력은 사용자 언어로 렌더**한다 — `PLAN-FORMAT.md`·`RETRO-FORMAT.md`와 같은 "canonical 영문 이름 + 사용자 언어 렌더" 규율이다. **자연어 트리거도 verbatim이 아니다** — 각 스킬 `description`에 한/영이 모두 등록돼 있으므로 사용자 언어에 맞는 것을 골라 `How to start`를 채우고, verbatim으로 유지하는 것은 경로·`.forge/` 필드·`/명령`뿐이다(스킬 본문에 한쪽 언어의 트리거 문구를 하드코딩하지 않는다). 형태의 **단일 정의는 `skills/fg-next/HANDOFF.md` 하나**이며(복붙 금지 — `FORGE-ROOT.md`·`DRIVE.md`와 같은 규율), 다음 단계가 실재하는 **14곳**(루프 4 + fg-status·fg-next·fg-loop·fg-quick·fg-map·fg-doctor·fg-agenda·fg-adversarial-review·fg-agents·fg-security)에 적용된다. 토글·설정이라 가리킬 다음이 없는 fg-tdd·fg-eco·fg-statusline과 애초에 다음-단계 안내를 내지 않는 fg-cleanup·fg-drop·fg-merge·fg-showme·fg-help **8곳은 종전 산문을 유지**한다. 과거 이 규약이 지시했던 *"자연스러운 대화체로 전한다 — 정해진 양식을 사무적으로 출력하지 않는다"* 는 **폐기됐다**(드리프트가 아니라 결정이다 — [ADR `260805-231104`](.forge/adr/260805-231104-handoff-table.md)). 고친 통증은 출력 **길이가 아니라 찾기 어려움(위치)** 이며, 길이 축은 eco 요약 표(ADR `260730-230321`)가 이미 다뤘다. eco on의 작업 종료 지점에서는 두 표가 역할을 나눈다 — eco 요약 표를 먼저 내고 핸드오프 표는 `방금 한 것` 행을 빼 3행으로 뒤따른다(우선순위 규칙이 아니다). **폐기된 것은 대화체뿐이고 진술형은 전부 그대로다** — 표는 메뉴가 아니라 텍스트 출력이라 `AskUserQuestion`으로 내지 않으며, `대안` 행은 다른 경로가 있다는 *진술*이지 질문이 아니다. **전환은 진술형** — "진행할까요?"로 다음 단계 진입을 *묻지 않고* 다음 스킬·트리거를 알리고 멈춘다. 체이닝(동의 시 다음 스킬 자동 호출)은 **fg-next 전담**이다. **전 루프 핸드오프가 진술형** — fg-run 단일작업 종료도 진술형으로, 다음 단계(기본=회고 fg-learn)·트리거를 알리고 멈춘다(저-divergence면 skip+봉인 안내, 고-divergence면 재그릴 권고; "회고+봉인 한 번에"는 fg-next로). 과거 fg-run 종료의 4지 `AskUserQuestion` 메뉴는 **선택해도 같은 메뉴가 다시 뜨는 반복 버그**(영속 상태 + 멱등 가드 부재)로 폐지됐다(ADR-0015 개정 2026-06-15). 단 fg-run *시작* 시 백로그 2+ 작업 선택 메뉴는 별개로 유지된다(선택→실행으로 진행, 반복 없음). Run-all 배치 핸드오프도 진술형이다("어느 것부터?"는 fg-learn 소유 질문 — 중복 금지). 핸드오프에 "진행할까요?"를 재추가하지 말 것 — 정합·근거는 [ADR-0015](.forge/adr/0015-fg-run-handoff-menu-others-stated.md)(개정 2026-06-15).
- **언어**: 스킬 본문(`SKILL.md`)·형식 문서(`*-FORMAT.md`)는 **영문으로 작성**한다(grill-with-docs 원문을 그대로 옮긴 부분은 영문 verbatim 유지). 단 스킬이 **사용자에게 출력하는 언어는 사용자의 언어를 따른다** — 각 스킬에 "respond in the user's language" 지시를 명시하고, 산출 문서(plan·회고·CONTEXT·ADR 등 사용자 프로젝트에 남는 문서)도 사용자 언어로 쓴다.
- **설명 방식(`Explaining forge`)**: 22개 `SKILL.md` 전부가 `**Language**` 규칙 옆에 **항상-on `**Explaining forge**` 문단**을 담는다 — forge 전문용어를 첫 등장에서 즉시 주석, 목적을 메커니즘보다 먼저, 결론 먼저+so-what으로 닫기. **`eco` 게이트와 무관하다**(ADR `260824-134246`): eco에 번들하면 주석을 가장 필요로 하는 신규 설치자가 기본값 `false` 때문에 못 받는다. `ECO.md`의 간결 규칙과 **형태(caveman) vs 어휘(이 규율)**로 분업하므로 **간결함이 주석을 지우지 않는다**. **새 스킬을 추가할 때 이 문단을 빠뜨리지 말 것** — 인라인이라 자동 상속되지 않고, `fg-doctor` 검사 **B17**이 **warning**으로 잡는다(**canonical 본문** 단일 정의 `scripts/explaining-forge.rule.txt`를 verbatim **포함**으로 대조하므로 헤딩만 남기거나 본문을 고쳐 쓴 경우도 걸리고, 상위집합은 통과한다 — canonical을 바꿀 땐 그 파일과 22곳을 함께 고칠 것)(`fg-ask`만 verbatim 본문 예외라 「Forge integration」 절의 불릿 형태로 넣는다).
- **README 이중 언어 동기화**: `README.md`(영문)와 `README.ko.md`(한글)는 같은 내용의 번역 쌍이다. **`README.md`를 갱신하면 반드시 `README.ko.md`도 같은 변경으로 함께 갱신한다**(역방향도 동일). 한쪽만 고치면 두 문서가 어긋난다.
- **문서 사이트 이중 언어 동기화**: 같은 규율이 문서 사이트에도 적용된다 — `docs/<name>.md`(한글, root locale)와 `docs/en/<name>.md`(영문)는 **7쌍의 번역 쌍**이며, 한쪽을 고치면 반드시 다른 쪽도 함께 고친다. README 1쌍이던 부담이 8쌍으로 늘어난 것이므로 **번역문은 절 구조를 1:1로 유지**해야 한다(`##` 헤딩의 개수·순서, 표의 행 수·열 수를 원문과 일치). 그래야 동기화 여부를 눈이 아니라 diff로 확인할 수 있다. 쌍이 빠지지 않았는지는 아래 한 줄로 확인한다:

  ```bash
  # ko 문서마다 en 짝이 있는지 (출력이 없어야 정상)
  for f in docs/*.md; do [ -f "docs/en/$(basename "$f")" ] || echo "missing: docs/en/$(basename "$f")"; done
  ```

  영문판 안의 링크는 **영문판끼리 닫혀야 한다**(형제 문서 상대 링크는 그대로 두면 `/en/` 안에서 해결된다). 단 두 가지 예외: `README.ko.md`를 가리키던 절대 URL은 영문판에서 `README.md`로 바꾸고, `./examples/…`는 아티팩트에 `/docs/examples/`로만 실리므로 영문판에서 `../examples/…`로 올린다. 이 쌍 검사를 `fg-doctor`에 넣을지는 아직 판단하지 않았다(별개 작업).
- **`docs/index.html` 이중 언어 동기화**: 랜딩 페이지는 한 파일 안에 KO/EN 텍스트를 `data-l="ko"`/`data-l="en"` span으로 나란히 담고 언어 토글로 전환한다(ADR-0027). **한쪽 언어 텍스트를 고치면 반드시 짝이 되는 다른 언어 span도 함께 갱신한다** — 한쪽만 고치면 두 언어가 어긋난다(README 쌍과 동일한 규율).
- **흐름도는 텍스트로**: 스킬 문서(`SKILL.md`)에 흐름·상태 전이·분기를 넣을 때는 **Mermaid를 쓰지 말고 텍스트 흐름도로 작성한다**(`A → B → C`, 분기는 들여쓰기·화살표·조건 레이블로). 스킬 본문은 영문이므로 텍스트 흐름도도 영문으로 쓴다. 이유: 스킬은 에이전트가 읽고 실행하는 지시문이라 렌더링 없이 그대로 파싱되어야 하고, Mermaid 블록은 진단·diff·grep을 어렵게 한다. (이 규약은 스킬 문서 한정이며, 사용자 프로젝트에 생성되는 산출 문서에는 적용되지 않는다.)
- **분기를 쓸 땐 판정을 쓴다**: 계약 문서(스킬 본문·형식 문서·규율 문서)에 **둘 이상의 결과**를 적으면, 그 결과들을 **무엇으로 구분하는지 같은 문단에** 적는다. 분기의 *존재*만 적은 계약은 오분류를 허용하고, 그 오분류는 조용하다. 실제 사례: 주행 커밋 규율이 "커밋할 것 없음 / 커밋 거부" 두 결과를 서술했는데 판별 수단을 안 써서, 둘 다 `git commit` exit code가 `1`이라는 사실(실측)을 만나 구분이 불가능했다 — 거부를 "없음"으로 읽으면 봉인이 활성 슬롯을 비운 뒤라 롤백 지점도 forge 상태도 사라진다. 메시지 파싱이 아니라 **순서·상태로 결정론화**하는 것이 답이었다(회고 `260901-223116`).
- **절제**: ADR·글로서리 용어는 바를 넘을 때만 승급. 회고에서 나온 모든 걸 영속 문서로 밀어 넣지 않는다.

## 배포 규칙

사용자가 프롬프트에 **"배포"** 라고 치면 아래 절차를 순서대로 수행한다.

1. **CHANGELOG.md 갱신** — 마지막 배포(마지막 버전 범프 커밋) 이후의 커밋들을 요약해 새 버전 섹션을 맨 위에 추가한다. 형식은 Keep a Changelog 약식:

   ```markdown
   ## [X.Y.Z] - YYYY-MM-DD
   ### Added / Changed / Fixed (해당 항목만)
   - 변경 요약 한 줄씩
   ```

   파일이 없으면 `# Changelog` 헤더와 함께 새로 만든다(lazy 생성).
2. **README·docs 갱신 (이번 릴리스 작업 내용 반영)** — 이번 릴리스에 담긴 변경에 맞춰 사용자 문서를 동기화한다:
   - **`README.md`** — 스킬 카탈로그·개수·역할·흐름 등 바뀐 내용을 반영하고, **반드시 `README.ko.md`도 같은 변경으로 함께 갱신**한다(이중언어 동기 — 위 "README 이중 언어 동기화" 규약).
   - **`docs/`** — 변경과 관련된 문서를 갱신한다: 스킬 추가·변경이면 `docs/skills.md`, 상태 계약·디렉터리·게이트 변경이면 `docs/state-contract.md`, 그 외 해당 문서(`docs/forge-vs-loop-engineering.md` 등).
   - 이 갱신은 **기능 작업의 일부이므로 `feat` 커밋에 포함**한다(릴리스 커밋은 아래 CHANGELOG+버전 범프만 — step 5). 미커밋 변경이 곧 릴리스 내용인 정상 흐름(아래 불릿)에서는 README·docs 갱신도 그 feat 커밋에 함께 들어간다.
   - 바뀐 게 사용자 문서에 영향이 없으면(예: 내부 리팩터만) 이 단계는 건너뛴다 — 억지로 만들지 않는다.
3. **버전 범프** — 기본은 **patch**. 사용자가 "배포 minor" / "배포 major"라고 지정하면 그에 따른다. 버전은 **4곳을 반드시 동기 갱신**한다: `.claude-plugin/plugin.json`의 `version`, `.claude-plugin/marketplace.json`의 `metadata.version`과 `plugins[0].version`, `.codex-plugin/plugin.json`의 `version`. 한 곳만 빠져도 `fg-doctor` B8과 `npm run release:check`가 error로 잡는다.
4. **검증** — 매니페스트 JSON 유효성 확인(위 node 한 줄)과 `npm run release:check`(4곳 버전 동기+호스트 어댑터 존재). README 이중언어·docs 갱신이 빠진 게 없는지도 함께 점검한다(필요하면 `fg-doctor`).
5. **commit & push** — `chore(release): vX.Y.Z` 형식으로 커밋하고 `main`에 push한다(설치는 main을 당기므로 push까지가 배포다).

절차 흐름: `CHANGELOG.md 작성 → README(이중언어)·docs 갱신 → 버전 4곳 범프 → JSON 검증 + release:check → commit → push`

**배포 후 "설치 테스트":** `/plugin install`·`/plugin marketplace update`는 interactive 명령이라 에이전트가 실행 못 한다(사용자가 직접 침). 에이전트가 검증할 수 있는 건 설치 전제뿐 — `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json` 과 `.../main/.codex-plugin/plugin.json`으로 원격 main의 버전 4곳을, `awk '/^name:/'`로 `skills/*/SKILL.md`의 frontmatter `name`(자동 탐색 대상) 누락 여부를 확인한다.

- 작업 트리에 배포와 무관한 변경이 섞여 있으면 멈추고 먼저 확인받는다(배포 커밋에 끼워 넣지 않는다).
- 마지막 배포 이후 커밋이 하나도 없으면 배포할 것이 없다고 알리고 멈춘다.
- **미커밋 변경이 곧 릴리스 내용이면**(커밋 0개인데 작업 트리에 그 릴리스의 기능 작업이 쌓여 있음) 먼저 그 작업을 별도 `feat` 커밋으로 묶은 뒤 릴리스 절차를 돈다(릴리스 커밋엔 CHANGELOG+버전 범프만). 이 리포의 정상 흐름이다.
- **매니페스트의 두 description은 역할이 다르다.** `marketplace.json`의 `metadata.description`은 루프(ask→execute→retro→done)를 정의하는 한 줄 태그라인이므로 루프 밖 유틸리티(fg-map류)는 넣지 않는다. `plugins[].description`(과 `plugin.json`의 `description`)은 전체 스킬 목록을 담는 설명이므로 루프 밖 스킬도 여기에 반영한다. 루프 밖 스킬을 metadata에 끼우면 루프 정의가 흐려진다.

## 이슈 연동 작업 봉인 규칙

fg-done이 작업을 봉인(`status: done`)하는 시점에, 그 작업의 plan `## Source of truth`에 **`이슈 추적: GitHub 이슈 #N`** 형식의 표기가 있으면(예: `.claude/skills/issue-triage`로 찾았든 사용자가 직접 이슈 번호를 언급했든 무관), 아래를 **확인 질문 없이 자동으로** 수행한다. 이 표기가 plan에 없는 작업에는 아무 영향이 없다.

**여러 태스크로 쪼갠 작업은 `이슈 추적:` 마커를 마지막 태스크에만 둔다.** 이 규칙은 마커를 가진 plan이 봉인되는 *순간* 발동하므로, 쪼갠 첫 태스크에 마커가 남아 있으면 **나머지가 미완인 채로 이슈가 "해결됨"으로 닫힌다** — 외부에 거짓을 게시하는 것이고 되돌리기 번거롭다. fg-ask가 태스크를 쪼갤 때(PLAN-FORMAT.md의 splitting rule) 마커를 마지막 것에만 붙이고, 이미 붙어 있으면 이관한다. 실제로 네 번 반복돼 매번 손으로 이관했다(`#114`→`#115` · `#116`→`#117` · `#118`→`#119` 및 그 봉인).

1. **커밋** — 이 작업이 바꾼 파일만 커밋한다. 커밋 메시지에 `(Fixes #N)`을 포함해 GitHub의 커밋-이슈 자동 링크·자동 닫힘을 이용한다(예: `fix(...): ... (Fixes #N)`). 이것은 위 "배포 규칙"(CHANGELOG 갱신·4곳 버전 범프까지 포함하는 전체 릴리스 절차)과 **다르다** — 이슈 하나 봉인마다 버전을 올리지 않는, **커밋+push만의 가벼운 배포**다.
2. **push** — `git push origin main`.
3. **이슈 코멘트** — `gh issue comment N`으로 커밋 해시·수정 요약·검증 근거를 남긴다.
4. **닫힘 확인** — 커밋 메시지의 `(Fixes #N)`으로 GitHub이 push 시점에 자동으로 이슈를 닫는다. 코멘트 작성 후 `gh issue view N --json state`로 실제 닫혔는지 확인하고, 아직 열려 있으면(다른 리포의 이슈이거나 커밋 메시지 링크가 인식되지 않은 경우) `gh issue close N`으로 직접 닫는다.

**안전장치(배포 규칙과 동일)**: 작업 트리에 이 작업과 무관한 미커밋 변경이 섞여 있으면 멈추고 먼저 확인받는다 — 무관한 변경을 이슈-연동 커밋에 끼워 넣지 않는다.

## 현재 상태의 알려진 불일치 (편집 전 인지할 것)

여러 파일을 읽어야 드러나는, 의도적 반복 작업으로 생긴 어긋남:

- **`skills/fg-ask/`는 grill-with-docs 원본의 자기완결 3파일**(`SKILL.md` + 형제 `CONTEXT-FORMAT.md`/`ADR-FORMAT.md`, 영문)이며, SKILL.md 본문은 영문 verbatim이고 forge 루프 연결(백로그 산출, fg-run 핸드오프, 회고 환류)은 맨 아래 "Forge integration (minimal)" 섹션에만 둔다. 이 verbatim 본문과 Forge integration 섹션은 따로 움직이므로, 둘 중 하나만 고치면 계약이 깨진다.
