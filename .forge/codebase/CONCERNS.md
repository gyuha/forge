---
last_mapped_commit: 182175fe02f832806c44148e7036d0dc26d7a55b
mapped: 2026-08-26
---

# CONCERNS — 기술 부담·결함·취약 지점

이 문서는 **구현 사실**만 담는다. 용어 정의는 `.forge/CONTEXT.md` 소관이다.

**읽는 법**
- `[확정]` — 이 매핑 세션에서 실제로 재현·실측·grep으로 확인한 것.
- `[확정/이월]` — 과거 매핑이 재현·실측으로 확정했고, 이번 세션에 해당 파일이 **한 줄도 변하지 않았음을 확인**해 근거가 그대로 유효한 것.
- `[의심]` — 코드를 읽어 추론했으나 재현하지 않은 것.
- severity: **critical**(사용자 머신에 실제 피해 가능) / **major**(상태 손상·조용한 실패·체감 성능) / **minor**(정합·유지보수).
- **번호 공간이 둘이다(혼동 주의).** 이 문서의 `B1`~`B12`는 *결함 항목* 번호이고, 본문에 인용되는 `A9`·`B13`·`B15`·`B16`·`B17`은 `scripts/forge-doctor.{sh,js}`의 *검사 이름*이다. 두 공간이 이미 겹치므로(이 문서의 B13과 doctor의 B13은 무관) doctor 검사를 가리킬 때는 항상 "fg-doctor의 B17"처럼 적는다.

forge는 공개 배포되어 남의 머신에 설치되고, **세션 시작마다 실행되는 셸/노드 코드**를 배포한다. 그래서 훅·스크립트 경로의 결함은 문서 결함과 급이 다르다. 반대로 이 리포에서 "코드"의 절반은 산문이므로, **문서 드리프트가 곧 동작 드리프트**인 경로가 따로 존재한다. **이번 구간에 위험 표면이 한 등급 올라갔다** — forge는 이제 `Stop` 훅으로 **턴 종료를 거부하는 코드**를 배포한다(B11).

**이 세션의 기준선**(`182175f`, v0.6.16): `bash scripts/forge-doctor.sh` → **0 errors, 1 warnings, 0 info**(실측 — 그 1건이 B7의 실현이다). 활성 슬롯·backlog·executed 전부 비어 있고 `loop.md` 없음, `.forge/branch/` 빈 디렉터리. 봉인 **138**건, 활성 ADR **51**건, `retired/` 0건, retro **72**건, 스킬 **22**개. 스크립트 테스트 실측: `forge-doctor.test.sh` 54/54 · `forge-hook-stop.test.sh` 10/10 · `forge-hook-stop.parity.test.sh` 16/16 · `forge-loop-spend.test.sh` 38/38 · `forge-loop-spend.parity.test.sh` 19/19 · `forge-doctor.parity.test.sh` 11/11 — **전부 통과인데도 새 parity 위반 1건이 살아 있다**(B10). `48899bd..182175f` 구간에 들어온 것은 `Stop` 훅 트윈·`forge-loop-spend` 트윈·fg-help·fg-security 벤더링 12파일·VitePress 문서 사이트(+GitHub Actions)·fg-doctor B17이다. `scripts/forge-{done,merge,hook-session-start,status}.{sh,js}`·`hooks/run-hook.cmd`는 이번 구간 **무변경**(changed-list 부재로 확인).

---

## A. 방어선이 생긴 항목 (재조사 불필요 — 단, 지우면 결함이 되돌아온다) `[확정/이월]`

훅 인젝션 계열 결함 6건은 `.forge/done/260730-234125-…-hook-hardening-fix/` → `.forge/done/260731-153236-hook-task-field-unbounded-fix/` 두 차례로 봉인됐고, 지난 매핑이 실제 공격 입력(닫는 태그 주입·100자리 task)으로 재확인했다. `scripts/forge-hook-session-start.{sh,js}`는 이번 구간 무변경.

- **인젝션 차단** — 단일 초크포인트 `sanitize()`(`scripts/forge-hook-session-start.sh:74-87` / `.js:46-51`): 제어문자·CR/LF·태그 구분자 `<`/`>` 제거, 바이트 절단(멀티바이트 경계 보정). `NO EXEMPTIONS` 주석이 불변식.
- **소스단 상한** — `SAN_MAX=200` + `TASK_DIGITS_MAX=9`.
- **트렁케이션 차단** — `.js`가 `process.stdout.write` 뒤 `process.exit()`를 부르지 않는다.
- **park 개념 분리** — park은 별도 개수 줄, 헤더는 `Unsealed tail (ran, not sealed):`.
- **지시 문단 범위 한정** — "fg-ask's STEP 0 auto-close is the one approved exception" 문구 + 순서 계약 테스트.

**잔여 위험(구조적)**: 방어는 값이 블록을 **탈출**하지 못하게 막을 뿐, 값 안의 명령문 자체는 그대로 컨텍스트에 주입된다. 데이터로 묶는 마지막 한 겹은 산문 경고(모델의 순종)다.

**새 훅에는 이 방어선이 필요 없다** — `Stop` 훅(`scripts/forge-hook-stop.{sh,js}`)은 컨텍스트에 값을 **주입하지 않는다**. stderr로 내보내는 것은 고정 문구 + 숫자 2개 + 마커 경로뿐이다(`forge-hook-stop.sh:99-100`). 대신 이 훅의 위험은 전혀 다른 축이다(B11).

---

## B. 미결 — critical·major

### B1. `forge-done.sh`가 봉인 실패를 은닉하고 `SEALED`를 출력한다 (+ 트윈이 정반대로 죽는다) — **major** `[확정/이월 + 이번 세션 코드 재확인]`
- 위치: `scripts/forge-done.sh:174-178` — `mkdir -p "$DEST"` · `mv … 2>/dev/null || true`의 결과를 아무도 확인하지 않는다(이번 세션 재확인). 트윈은 `scripts/forge-done.js:167`의 `fs.renameSync`가 예외를 던져 **문서화된 exit code 계약(2/3/4/5/64)에 없는 exit 1**로 죽는다.
- 지난 매핑의 재현(`done/`을 `chmod 500`): `.sh`는 stderr에 에러를 흘리고도 **`SEALED` + exit 0**, 활성 슬롯의 STATUS는 이미 `status: done`으로 덮어써진 상태로 잔존. 같은 입력에서 두 트윈이 다른 결과 = **parity 사각지대**(파일시스템 실패 픽스처가 스위트에 없다).
- **세 방어선이 전부 이 손상을 못 본다**: SessionStart 훅(`status != done` 조건이라 침묵), `forge-doctor.sh`(활성 슬롯의 `status: done`을 잡는 검사 없음), fg-done 스킬(exit code만 보고 "봉인 완료" 보고).
- 전제는 파일시스템 실패라 드물지만, 결과는 "봉인됐다고 믿는 미봉인 작업" — 재실행 방지 메커니즘의 정반대.

### B2. `.forge/branch/` 스캔이 2단 깊이라 3세그먼트 브랜치가 통째로 안 보인다 — **major** `[확정 / 이번 세션 코드 재확인]`
- 위치: `scripts/forge-merge.sh:70`(`"$BRANCHES_DIR"/*/ "$BRANCHES_DIR"/*/*/` — 재확인), `scripts/forge-merge.js:49-58`(깊이 2 고정), `scripts/forge-doctor.sh:104`(같은 글롭 — 이번 구간 B17 추가로 줄 번호가 89→104로 밀렸을 뿐 내용 동일).
- 결과: `release/2026/hotfix`류 3+ 세그먼트 브랜치의 ADR·retro·done·backlog는 `fg-merge`가 `EMPTY nothing-to-integrate`로 넘기고, fg-doctor A8 경고도 안 뜬 채 기본 브랜치 트리에 **경고 없이 영구 잔존** — 조용한 데이터 유실. A8은 warning이라 CI 게이트(exit 2 기준)도 통과한다. 3세그먼트 픽스처가 스위트에 없어 회귀로 안 잡힌다.

### B3. `async: false` + bash 훅의 O(n) 서브프로세스가 세션 시작을 초 단위로 막는다 — **major** `[확정/이월 + hooks.json 재확인]`
- 위치: `hooks/hooks.json`의 SessionStart 항목 `"async": false`(재확인) + `scripts/forge-hook-session-start.sh:106-111`(`field()` 호출마다 4프로세스) + park **전량 순회**.
- 지난 매핑 실측(macOS, 이후 무변경): `executed/` 300개에서 `.sh` **0.839s** vs `.js` 0.052s. bash가 우선 경로(`hooks/run-hook.cmd`)인데 하필 bash만 선형 증가.
- **이번 구간에 `Stop` 훅이 추가되며 `async: false` 훅이 하나 더 늘었다**(`hooks/hooks.json` Stop 항목). Stop 훅 본체는 O(1)이지만(마커 한 파일), **모든 턴 종료마다** 프로세스 2개(`run-hook.cmd` → `forge-hook-stop.sh`)가 뜬다 — 주행하지 않는 세션에도. 실측은 안 했다 `[의심]`.

### B4. 스크립트 백킹 컨벤션(ADR-0031/0022)이 자기 리포에서 2건 위반 — behavior 테스트 없음 — **major** `[확정 / 이번 세션 재확인]`
- ADR-0031/0022는 트윈 + parity + behavior 테스트 + 계약 동기 4종을 필수로 못 박는다. `ls scripts/*.test.sh` 재확인: **`forge-status`·`resolve-forge-root`는 parity 테스트만 있고 behavior 테스트가 없다**(`forge-status.test.sh`·`resolve-forge-root.test.sh` 부재 — 신규 `forge-hook-stop`·`forge-loop-spend`는 둘 다 갖췄다). 하필 이 둘이 의존의 뿌리다 — `forge-status.sh`는 fg-status/fg-next 상태 머신의 조사(ADR-0020), `resolve-forge-root.sh`는 **모든 루프 스킬의 경로 해석**(ADR-0011)이자 `forge-hook-stop.sh:65`가 매 턴 종료마다 호출하는 것이다.
- 감지 수단 없음: `forge-doctor.sh`의 B15는 트윈 **파일 존재**만 검사한다(`scripts/forge-doctor.sh`의 B15 루프 — `.sh`↔`.js` 짝만 확인).
- **"parity만 있으면 두 트윈이 똑같이 틀린 경우가 green"은 더 이상 가설이 아니다** — 이번 구간에 정반대 형태로 실현됐다: parity 테스트가 있는데도 두 트윈이 **다르게** 동작하는 검사가 배포됐다(B10). parity 스위트의 커버리지 자체가 검사받지 않는다.

### B5. fg-map 증분 Update의 "상속된 거짓 보존" — 가드는 산문뿐, 자동 게이트 0건 — **major** `[확정 / 이번 세션 doctor 재확인]`
- ADR `260801-020258`이 Update를 "재탐색 금지 + 제자리 편집" 하드 계약으로 정의하고 스크립트화를 명시 기각 → 트윈·테스트 없음. 가드는 `skills/fg-map/SKILL.md`의 산문 mandatory 단계뿐.
- 구조적 대가: 베이스라인을 정답으로 삼으므로 **이미 들어 있던 틀린 사실은 검사받지 않고 살아남는다** — 두 리포에서 독립 실측(증분 5회가 통과시킨 오류 3건). 30% 축소 가드는 *유실*은 잡아도 *보존된 거짓*은 못 잡는다(라인 수 불변).
- **자동 게이트 0건**: `scripts/forge-doctor.{sh,js}`에 `.forge/codebase/` 검사가 전무하다(이번 세션 grep 0건 재확인). 지도가 통째로 삭제돼도 doctor는 0 findings. 지도는 fg-ask 그릴링의 연료이므로 조용한 드리프트 = 계획 품질 저하.
- **이 결함이 지금 미해결 의제로 살아 있다** — `.forge/agenda.md`(2026-08-05 개시, 37줄)의 목적지가 정확히 "fg-map 지도를 믿을 수 있게 만든다"이고, 그 문서가 인용하는 상속된 거짓 3건 중 하나가 이 문서의 C15다. 결정 4건이 내려졌고 **열린 질문 4건이 21일째 남아 있다**(C24 — 이 의제는 어떤 결정론 표면에도 안 보인다).

### B6. 브라우저 답변 채널(fg-showme)의 신뢰성이 전부 산문 수명 의무 위에 서 있다 — **major** `[확정/이월]`
- `Monitor`는 `persistent: true`로 걸며 스스로 만료되지 않는다 — 서버를 멈추는 **모든** 경로가 `TaskStop`을 함께 불러야 하고(`skills/fg-showme/VISUAL.md:357`), 빠뜨리면 죽은 세션의 events 파일을 tail한다. 실제 실행 중 재장전 누락이 두 번 발동(회고 `260805-063357`).
- 서버 4시간 유휴 종료는 인증된 요청만 활동으로 세므로 "클릭만 기다리는" 상태가 방치 구간이 된다 — 실측 5시간 11분 뒤 자기 종료. 완화는 "화면 밀기 전 서버 생존 확인" 산문 한 줄뿐.
- 텍스트 전송 버튼(`VISUAL.md:297`)에 확정 버튼의 `dataset.sent` 중복 전송 가드가 **없다**(확정 쪽에서 798ms 더블클릭 중복 실측, 텍스트 쪽 미수정).
- 위험의 성격은 중단이 아니라 **침묵** — 사용자가 누르고 기다리는데 아무 일도 안 일어나는 것.

### B7. 스킬 `description`이 카탈로그 설명과 자동 호출 트리거를 겸한다 — 상한 압력이 **실현됐다** — **major** `[확정 / 이번 세션 재측정]`
- 압력이 아니라 위반이다. `DESC_MAX=600`(`scripts/forge-doctor.sh`의 B16, 코드포인트 기준) 대비 이번 세션 전수 재측정: **fg-help 768(128% — 리포의 유일한 doctor 경고)** · fg-doctor 591(98%) · fg-showme 573 · fg-security 551 · fg-eco 546 · fg-agents 531 · fg-adversarial-review 531. 신규 스킬 fg-help가 **상한을 28% 넘긴 채 v0.6.16으로 배포됐다** — doctor가 잡는데도(warning) 릴리스가 통과했다는 것이 요점이다(C3: doctor를 부르는 자동화가 없다).
- `skills/fg-done/SKILL.md:3`은 여전히 `(Note: 'forge cleanup' routes to fg-cleanup, not here.)`로 트리거 충돌을 산문으로 막는다.
- fg-doctor의 B16은 **길이만** 본다 — description ↔ 본문의 의미 일치, 자동 호출 정확도의 회귀 테스트는 없다. 문구 드리프트가 곧 동작 드리프트가 된 실사례(fg-showme "표시 전용" 잔존)와 이름 오발동으로 실행 중 개명한 사례(fg-chart→fg-agenda)가 기록돼 있다.

### B8. 테스트가 프로덕션 호출 형태를 재현하지 않으면 통과가 아무것도 보장하지 않는다 — **major(구조적)** `[확정/이월 + 이번 세션 exec bit 재전수]`
- 근거: `.forge/done/260727-233237-…/run.md` — 22개 단언 전부 통과 상태에서 훅이 전혀 발화하지 않았다(`hooks/run-hook.cmd` exec bit 부재; 테스트는 `bash "$WRAPPER"`로 불러 통과). exec bit 단언 테스트는 리포 전체 1건(`hooks/run-hook.test.sh:43`).
- **exec bit는 여전히 제각각이다**(이번 세션 `ls -l` 전수): 755 = `run-hook.cmd`·`forge-done.{sh,js}`·`forge-hook-stop.*`·`forge-loop-spend.*`·`forge-status.sh`·`forge-statusline*`·`resolve-forge-root.sh` / 644 = `forge-doctor.{sh,js}`·`forge-hook-session-start.*`·`forge-merge.*`·`forge-status.js`·`resolve-forge-root.js`. 같은 트윈 쌍 안에서도 갈린다(`forge-status.sh` 755 vs `.js` 644). 직접 실행으로 배선을 바꾸는 순간 지켜주는 장치가 없다.

### B9. fg-loop `waiting`/`blocked-health`의 안전장치가 전부 산문 계약이다 — **major** `[확정/이월 + 이번 세션 재확인]`
- `evidence: external`로 선언된 체크는 통과 전까지 무조건 `waiting`으로 분류돼 **자동 수리 대상에서 빠진다** — "빨간 CI"와 "미완 CI"를 구분 못 하는 것이 문서화된 대가이고, 영구 대기를 막는 유일한 장치는 `stalled-waiting`(`×2` 증거 불변) 상한이다(ADR-0016 개정 2026-08-09). 상한 감지·증거 비교 모두 에이전트 판단 산문이며 스크립트 게이트가 없다.
- `blocked-health`는 "체크 명령의 실행파일 도출 점검 + **보수적 사후 승격**"인데 승격 판단이 best-effort 자기분류다 — `safety` 벽과 같은 부류의, 산문으로만 지켜지는 계약.
- **stale `wall:` 오보고 경로는 산문 3겹으로만 막혀 있다** — `waiting` 신설로 "재개 시 이전 벽 원인 미해제"라는 기존의 무해한 암묵 규칙이 실제 오보고 경로가 됐고(적대 리뷰 high), 수정은 `wall: none` 전이 규칙 산문(`skills/fg-loop/SKILL.md`)과 fg-status의 서술 지침이다. 기계 검증 없음. 회고 `260810-084115`가 "상태 enum에 새 값을 더할 때 기존 값들의 해제 시점을 함께 감사하라"를 학습으로 남겼다.
- **`budget-exhausted`만은 예외적으로 결정론이다** — `scripts/forge-loop-spend.{sh,js}`가 exit code 0/3/4/5로 판정한다(38+19 단언 통과, 실측). 아홉 벽 중 스크립트가 지키는 유일한 벽이며, 나머지 여덟은 여전히 산문이다. 그 결정론에는 별도의 대가가 붙는다(C22).
- UAT 한계(회고의 3회+ 반복 패턴): forge-meta 지시문 작업의 검증은 "grep 가능한 문서 구조"까지이고, 진짜 효과는 실제 goal loop 주행 전까지 미검증이다.

### B10. fg-doctor A9 검사가 **bash 트윈에만 있다** — parity 스위트가 통과하는데도 두 트윈이 다르게 판정한다 — **major** `[확정 / 이번 세션 재현]`
- 재현(격리 픽스처 `/tmp`에 `.forge/drive.md`만 두고 `started: 1000000`):
  - `bash scripts/forge-doctor.sh` → `[warning] A9 stale drive.md` — **0 errors, 1 warnings**
  - `node scripts/forge-doctor.js` → **0 errors, 0 warnings** (findings 0건)
- 위치: `scripts/forge-doctor.sh:87-98`에 A9 블록(3분기: 낡음·미파싱·정상)이 있고, `scripts/forge-doctor.js`에는 `drive`·`A9` 문자열이 **한 건도 없다**(grep 무매치). 두 파일의 A-검사 목록을 뽑아 비교하면 js 쪽에만 A9이 통째로 없다.
- **왜 안 잡혔나**: `scripts/forge-doctor.parity.test.sh`(11 케이스)와 `forge-doctor.test.sh`(54 단언) 어디에도 `drive.md` 픽스처가 없다(grep 무매치). parity 테스트는 "같은 픽스처에 두 트윈을 돌려 stdout+exit를 비교"하는 올바른 설계인데, **픽스처가 새 검사를 덮지 않으면 검사 자체가 존재하지 않는 것과 같다** — B4가 경고한 사각지대의 실물이다.
- **결과**: exit code까지 갈린다(`.sh`는 warning → exit 1, `.js`는 clean → exit 0). fg-doctor는 AI 없는 CI 게이트로 설계됐으므로(exit 0/1/2), 러너의 런타임에 따라 게이트 판정이 달라진다. 하필 A9이 지키는 대상이 리포에서 가장 위험한 물건의 잔여물(B11의 `drive.md`)이다.

### B11. forge가 이제 **턴 종료를 거부하는 코드**를 배포한다 — 하네스 루프 보호가 없고, 해제는 산문 의무다 — **major** `[확정 / 이번 세션 코드·테스트 재현]`
- 위치: `hooks/hooks.json`의 `Stop` 항목(매처 없음 = 전체, `"shell": "bash"`, `"async": false`) → `hooks/run-hook.cmd stop` → `scripts/forge-hook-stop.{sh,js}`. 조건이 모두 참일 때 **`exit 2`로 턴 종료를 막는다**(`forge-hook-stop.sh:101`).
- **스스로 밝히는 위험**(`forge-hook-stop.sh:10-16`): "the harness provides NO loop protection for Stop hooks (there is no `stop_hook_active`-style input field), so the two bounds below are the ONLY runaway guard." 상한은 `MAX_AGE=1800`(30분)·`MAX_BLOCKED=50`(`:40-42`) 둘뿐.
- **설계는 정직하고 방어적이다**(재현 확인): 마커 부재·세션 불일치·`started`/`blocked` 미파싱·시계 없음·tty stdin·root 미해석·카운터 쓰기 실패 — **모든 실패·모호 경로가 exit 0(정지 허용)**. behavior 10 케이스 + parity 16 케이스 전부 통과(실측). 읽기 전용 dir(`chmod 555`)에서 stderr 누출까지 테스트가 덮는다(`forge-hook-stop.test.sh:113`).
- **그래서 진짜 잔여 위험은 코드가 아니라 계약이다.** 훅은 벽을 판정하지 않는다 — **마커 삭제가 "멈춰도 된다"의 유일한 표현**이고, 삭제 지점 전량 열거는 `skills/fg-next/SKILL.md:98` 이하와 `skills/fg-loop` §2의 **산문**에 산다. 주행이 마커를 지우지 못하고 죽으면(예외·컨텍스트 소진·사용자 중단) 같은 세션은 최대 30분 또는 50회 동안 정지 요청이 막힌다. `fg-doctor`의 A9은 이 잔여를 **warning**으로만 보고하며, 그마저 bash 트윈에만 있다(B10).
- **`hooks/run-hook.cmd`의 배치 절반은 exit 2를 삼킨다** `[확정 / 코드 확인]` — 네 디스패치 분기 전부 `… exit /b 0`(`:34-35`·`:40-41`·`:49-50`·`:58-59`)로 본체 exit code를 버린다. SessionStart에는 무해했지만(exit code가 의미 없음) **Stop에서는 그것이 메커니즘 전체**다. 지금은 `"shell": "bash"` 때문에 배치 경로가 실질적으로 안 쓰이므로(C9) 잠복 상태이나, Windows 커버리지를 고치려고 `shell`을 떼는 순간 Stop 훅이 조용히 무력화된다(에러 없이 항상 "멈춰도 됨").
- **참고**: 마커 조건부라 **주행하지 않는 세션은 완전 무영향**임은 코드로 확인된다(`:68` 마커 부재 → exit 0). 이건 잘 지켜진 부분이다.

### B12. 회고 유예의 "나중에 승급한다"가 **git에 없는 로컬 아카이브**에 걸려 있다 — **major** `[확정 / 이번 세션 전수 실측]`
- 실측: 봉인 **138**건 중 `retro: skipped` **66건(48%)**, 그중 짝이 되는 `.forge/retro/*-<slug>.md`가 있는 것 **0건**(python 전수). 배치 승급 모드는 **한 번 돌았다** — 3건이 `retro: … (batch promotion 2026-08-25)`로 승급됐다(`.forge/done/260824-*/STATUS.md`). 즉 "약속된 수신처"는 작동하지만 처리량이 유입을 못 따라간다.
- 유예의 전제는 "학습은 아카이브된 `run.md`에 남고 나중에 승급한다"인데, **그 아카이브는 기본 브랜치에서 git에 없다** — `.gitignore:5`의 `.forge/*`가 `.forge/done/`을 제외하고(`git check-ignore -v` 확인), `git ls-files .forge/done/` = **0**. 클론에는 66건분의 `run.md`가 존재하지 않는다.
- 자동 연료 경로도 이것을 읽지 않는다(grep 확인): `skills/fg-ask/SKILL.md:113`과 `skills/fg-run/SKILL.md:82`는 `.forge/retro/`만 읽는다. `done/*/run.md`를 읽는 곳은 **명시 호출 전용**인 `skills/fg-learn/SKILL.md:41`(배치 승급 모드) 하나뿐이며, 오케스트레이터는 절대 자동 진입하지 않는다고 같은 문서(`:36`)가 못 박는다.
- 결론: 66건의 학습은 **이 머신의 gitignored 디렉터리에만** 있고, 사람이 명시적으로 배치 승급을 부르기 전까지 어떤 그릴링·실행도 그것을 연료로 쓰지 않는다. ADR-0002가 상정한 "저-divergence 한정 skip"과 달리 `fg-next all`/`fg-loop`의 무조건 skip이 정책적으로 이 잔고를 만든다.
- 같은 표본의 `verified:`는 `yes` **116** / `n/a` **22**, 차단 값(`pending`/`failed`) **0** — 검증 게이트(ADR-0009)는 실측으로 강하게 지켜지고 있다(대조).

---

## C. 미결 — minor

- **C1. `CLAUDE.md:7`이 산출물을 "전부 Markdown과 JSON"이라고 단언한다** `[확정 / 재확인]` — 문장 무변경. 트리는 `scripts/`의 sh/js 트윈 + 테스트 파일, exec bit 붙은 `hooks/run-hook.cmd`, 그리고 이제 `skills/fg-security/validate-findings.cjs`까지 배포한다. 리포 최상위 안내문이 "남의 머신에서 자동 실행되는 코드"라는 위험 표면을 서술에서 지운 상태이며, `Stop` 훅이 추가된 지금 그 간극이 더 커졌다(같은 CLAUDE.md의 뒷부분은 스크립트를 상세 서술하므로 첫 단락만 낡았다).
- **C2. 상태 추출 로직이 여러 파일에 서로 다른 의미로 복제돼 있다** `[확정/이월 + 신규 2파일]` — `field()`는 `forge-{done,status,doctor,hook-session-start}.{sh,js}` 8파일 + `forge-merge.{sh,js}`의 `slugof`/`taskof`, 여기에 이번 구간 `forge-hook-stop.sh:70`의 자체 `field()`가 더해져 **11번째 복제**가 됐다(`.js` 트윈까지 12). 의미가 의도적으로 다르다(doctor/status/done은 콜론 뒤 첫 토큰만, session-start 훅은 전체 값, stop 훅은 다시 첫 토큰만). 공유 모듈이 없어 "중복 제거" 리팩터가 훅 출력 의미를 조용히 바꿀 수 있다.
- **C3. CI가 생겼지만 **문서 빌드 전용**이고, 테스트·doctor를 부르는 자동화는 여전히 0건** `[확정 / 이번 세션 갱신]` — 지난 매핑의 "`.github/` 없음"은 해소됐다: `.github/workflows/docs.yml`이 `main` push 시 VitePress를 빌드해 GitHub Pages로 배포한다(트리거 경로는 `docs/**`·`package*.json`·자기 자신). 그러나 **`scripts/*.test.sh` 19종도 `forge-doctor`도 어떤 job에서도 실행되지 않는다** — 아티팩트 조립 단계의 `test -f` 5줄이 이 워크플로의 유일한 검증이다. 아이러니가 하나 실려 있다: 리포는 `docs/examples/github-actions-forge-check.yml`로 **fg-doctor CI 게이트 예제를 배포하면서 자기 자신에는 적용하지 않는다**. B7(상한 28% 초과 배포)·B10(parity 위반 배포)이 그 결과다.
- **C4. 실제 `verified:` 값의 42%가 훅 주입 시 잘린다** `[확정 / 이번 세션 전수 재계산]` — `.forge/done/*/STATUS.md` **138**건 중 `verified:` 값 **59건(42%)이 200바이트 초과** → `SAN_MAX`에서 절단. 봉인이 18건 늘어도 비율이 40%→42%로 유지된다 — 서술 습관이다. 사유 뒷부분이 세션 시작 컨텍스트에 도달하지 않는다.
- **C5. 모드 토글이 git 추적 파일을 더럽힌다** `[확정 — 구조적, 현재 미발현]` — `.gitignore:10`이 `!.forge/config.json`을 화이트리스트하므로 `fg-eco on`이 곧 리포 diff다. 지금은 `{"eco": false}`로 깨끗하다 — 결함은 사라지지 않았고 토글이 꺼져 있을 뿐.
- **C6. 활성 ADR 51건, `retired/` 0건** `[확정 / 재확인]` — 47→51로 늘었고(이번 구간 신규 4: fg-help·VitePress·fg-security·explaining-forge) fg-cleanup(ADR-0012)은 여전히 한 번도 돌지 않았다(`retired/` 디렉터리 자체가 없다). fg-ask가 읽는 결정 집합은 단조 증가만 한다. 신규 ADR이 선행 ADR의 판단을 뒤집고도 은퇴 없이 상호 참조로 공존하는 관행이 계속된다.
- **C7. 회고 skip 비율** — B12로 승격됐다(48%에 더해 "승급 연료가 git에 없다"는 사실이 확인되면서 minor를 벗어났다). 이 항목은 번호 보존용으로 남긴다.
- **C8. `compact` 매처가 무인 주행 중간에 발화한다** `[확정 / hooks.json 재확인]` — SessionStart 매처는 여전히 `startup|resume|clear|compact`. `fg-next all`/`fg-loop` 주행 중 컨텍스트 압축이 일어나면 "사용자에게 물어라"가 주입된다. **이번 구간에 위험이 커졌다** — 이제 그 주행은 `Stop` 훅으로 턴을 이어가므로(B11) compact와 훅 차단이 같은 주행 안에서 맞부딪힐 수 있다. 매처 축소/in-flight 분기/침묵 스위치 중 미결.
- **C9. Windows 커버리지 과대 서술 — `Stop` 훅으로 대가가 올라갔다** `[확정 / 이번 세션 재확인]` — `hooks/hooks.json`의 두 항목 모두 `"shell": "bash"`이므로 bash 없는 Windows에서는 훅이 비활성(비차단)이다. `hooks/run-hook.cmd`의 배치 절반은 하네스 경로에서 사실상 죽은 코드이고, 그 죽은 코드가 Stop의 exit 2를 삼킨다(B11 마지막 불릿). 즉 Windows 사용자는 SessionStart 알림뿐 아니라 **무인 주행 연속성도 못 받는다**.
- **C10. 세션 중 편집한 `SKILL.md`·훅은 그 세션에 반영되지 않는다** `[확정/이월]` — 플러그인 스킬 본문·훅·`.claude/agents/` 카드 모두 세션 시작 1회 로드(ADR-0024 실측). 스킬을 고치는 작업의 "재시작 후 실 동작 검증"은 원리적으로 다음 세션의 일이라 미검증 잔여가 구조적으로 쌓이고, 이를 추적하는 상태 파일은 없다. **`Stop` 훅이 이 부류의 최악 사례다** — 설치·갱신한 세션에서는 아예 안 걸리고, 실제 차단 동작은 다음 세션에서 처음 발현된다.
- **C11. `debt` 용어 잔여 1건** `[확정 / 재확인]` — `hooks/run-hook.test.sh:55` 주석(무변경). `scripts/forge-merge.test.sh:131`의 `_Avoid_: debt`는 CONTEXT 병합 픽스처의 의도된 문자열이라 잔여가 아니다.
- **C12. 두 매니페스트 description이 갈라져 있고 격차가 벌어졌다** `[확정 / 이번 세션 재측정]` — `plugin.json` **11,492자** vs `marketplace.json` `plugins[0]` **10,345자**(문자열 동일성 `false`). 지난 매핑의 10,446 / 9,289에서 양쪽 다 늘었고 격차는 1,157 → 1,147로 사실상 그대로다. 22개 스킬 이름은 양쪽 모두 있으나 어느 검사도 두 값을 비교하지 않는다(fg-doctor의 B8은 version 3곳만). 스킬이 20→22로 늘며 손 동기 부담도 늘었다.
- **C13. `docs/index.html`은 어떤 자동 검사에도 없다** `[확정 / 이번 세션 재확인]` — `scripts/forge-doctor.{sh,js}`에 `index.html` 검사는 여전히 0건(grep 무매치). fg-doctor의 B13은 README 쌍의 스킬 행 수 parity만 본다. 한 파일 안 KO/EN `data-l` span 구조(ADR-0027)라 두 언어가 함께 틀리는 형태를 막는 장치가 없다. **현재 드리프트는 없다**(실측: `data-l="ko"` 120개 = `data-l="en"` 120개, 22개 스킬 이름 전부 등장) — 과거 세 차례 실현됐고 매번 사람이 고쳤다는 이력이 남아 있을 뿐이다.
- **C14. 출력 *형태* 규율에는 기계 게이트가 없다** `[확정/이월]` — 핸드오프 표(ADR `260805-231104`)는 구현 완료(`skills/fg-next/HANDOFF.md` 존재, CLAUDE.md 규약 개정). 그러나 표 렌더에는 기계 게이트가 없고(에이전트 판단 산문) ADR-0032·`260730-230321`·`260805-231104` 세 번 연속 같은 한계다. 그 구현 자체가 새 결함 부류를 실증했다 — 영문 규율 문서에 지시("사용자 언어로 렌더")와 모순되는 한글 예시가 실려 다수 스킬로 퍼졌고 리뷰 6렌즈도 통과했다(결함이 현재 세션 언어와 우연히 일치하면 구조적으로 불가시 — 이중언어 자산 공통 사각지대). "반대 언어 세션에서 어떻게 보이는가"를 검사하는 장치는 여전히 없다.
- **C15. `skills/fg-merge/SKILL.md:21`의 "never runs git"이 거짓이다 — 이번 구간에도 안 고쳐졌다** `[확정 / 이번 세션 재확인]` — 문장은 그대로이고 줄만 19→21로 밀렸다. `scripts/forge-merge.sh`는 읽기 전용 git 호출 3개(`:57` `rev-parse --show-toplevel`·`:325` `rev-parse ORIG_HEAD`·`:328` `diff --name-only`)를 경고 스캔에 쓰고, `.js` 트윈도 동형이다(`:33`·`:305`). 정확한 표현은 mutation-free이고 스크립트 자신의 헤더 주석은 맞게 적혀 있다(`forge-merge.sh:41` "+ git only for the warn-only …") — 산문만 드리프트. 이 문장이 CI 게이트 주장의 근거로 쓰이므로 사소하지 않다. **`.forge/agenda.md`가 이 건을 fg-map 지도 신뢰성 문제의 대표 사례로 인용하고 있으면서도 원본 산문은 그대로다** — 진단이 수정으로 이어지지 않은 21일.
- **C16. eco의 ECO.md 전문 주입이 코드를 쓰지 않는 서브에이전트에도 걸린다** `[확정/이월]` — `skills/fg-run/SKILL.md`의 "all workflow/execution subagents" 지시 때문에 채점·선언만 하는 비-코딩 에이전트에도 코드 단순성 규율 전문이 주입된 실사례(회고 `260801-234547`). 처방(코드 슬라이스 한정 또는 ECO.md 분할)은 ADR-0014 문언 수정이 걸려 미결.
- **C17. `.forge/` 장부가 외부 트리 스캐너에 코드로 흡수된다** `[확정/이월]` — graphify 실측 41.5%가 `.forge/` 유래. `.graphifyignore`로 그 한 도구만 해소됐고, 인덱서·RAG·검색 도구 일반에 대한 표준 제외 신호는 없다. **문서 사이트가 들어오며 표면이 늘었다** — `node_modules/`·`docs/.vitepress/{dist,cache}/`가 `.gitignore:23-25`에 추가됐으나 이 역시 git 한정 신호다.
- **C18. 그릴링이 plan에 적는 ADR 파일명을 검증하지 않는다** `[확정/이월 — 실사례 2건]` — 회고 `260810-084115` divergence ④: plan의 ADR 링크 2건이 실제 파일명과 불일치(기억으로 적고 `ls` 확인 안 함). plan은 실행의 정답 기준이므로 깨진 참조가 실행 중 잘못된 문서 탐색을 유발할 수 있다. 같은 회고가 "적기 전 `ls`로 실명 확인"을 학습으로 남겼을 뿐 게이트는 없다.
- **C19. 정본 규칙 텍스트가 23개 파일에 복제돼 있고, 게이트는 실행되지 않는 warning 하나다** `[확정 / 이번 세션 전수 확인]` — ADR `260824-134246`의 **Explaining forge** 문단은 `scripts/explaining-forge.rule.txt`(1줄 534바이트) 1벌 + `skills/*/SKILL.md` **22개** 전부에 verbatim 인라인돼 있다(전수 `grep -qF` 결과 22/22 보유, 누락 0). fg-doctor의 B17이 "정본 파일과의 containment"로 드리프트를 잡도록 잘 설계돼 있으나(마커가 아니라 본문을 비교, 초과분 허용), 그 검사를 부르는 자동화가 없다(C3). 규칙 문구를 한 글자 고치면 **23파일 동시 수정**이 필요하고, 그 필요를 알려주는 것은 사람이 손으로 돌리는 doctor뿐이다.
- **C20. fg-doctor의 B17이 다행 매니페스트에서 조용히 통과한다(fail-open)** `[확정 / 이번 세션 재현]` — 검사는 `jname`(`scripts/forge-doctor.sh`의 B17 블록)이 뽑은 최상위 `name`이 `forge`일 때만 발동하는데, `jname`은 **줄 단위**(`"name"[[:space:]]*:[[:space:]]*"…"`)라 값이 다음 줄에 있으면 빈 문자열을 낸다. 재현: `"name":\n    "forge"` 형태의 `plugin.json`을 둔 픽스처에서 규칙 없는 `SKILL.md`를 놓아도 **두 트윈 모두 B17 findings 0건**, 같은 값을 한 줄로 되돌리면 **두 트윈 모두 1건**. parity는 유지되지만 방향이 fail-open이다. 부수 가정 하나 더 — `jname`은 문서 순서상 **첫 `name`**이 최상위라고 가정한다(현재 `plugin.json:2`가 그렇다). 둘 다 코드 주석에 명시돼 있으나(의도된 잔여) 검사가 조용히 꺼지는 형태라 눈에 안 띈다. 원 기록: `.forge/done/260824-152043-fg-doctor-b17-hardening/`.
- **C21. 문서 사이트가 이중언어 동기 부담을 1쌍에서 8쌍으로 늘렸고, 기계 게이트는 0이다** `[확정 / 이번 세션 실측]` — `docs/*.md` 7개와 `docs/en/*.md` 7개가 번역 쌍이고(`agenda` `forge-vs-loop-engineering` `git-workflow` `index` `skills` `state-contract` `team-workflow`), 여기에 `docs/index.html`의 KO/EN span(C13)까지 8쌍이다. **현재는 동기 상태**(짝 누락 0건, `##` 헤딩 수 7쌍 전부 일치: 15/5/12/4/27/4/6). 그러나 fg-doctor는 README 1쌍만 본다(B13) — `docs/` 쌍 검사는 `.sh`·`.js` 어디에도 없다(grep 무매치). CLAUDE.md가 확인용 한 줄 셸을 적어 두었을 뿐 사람이 기억해서 돌려야 한다. 부수: `docs/icon.png`와 `docs/public/icon.png`가 **바이트 동일 중복**이다(md5 일치 — 랜딩용/VitePress static용으로 경로가 갈려 생긴 사본).
- **C22. `forge-loop-spend`가 하네스 내부 디렉터리 규약에 결합돼 있다** `[확정 / 이번 세션 확인]` — 트랜스크립트 루트를 `$HOME/.claude/projects/<slug>`로 도출하며 slug는 `pwd -P`를 `tr -c 'A-Za-z0-9' '-'` 한 값이다(`scripts/forge-loop-spend.sh:123-131`). 이 머신에서는 일치를 확인했다(도출 `-Users-gyuha-workspace-forge` = 실재 디렉터리). 문서화되지 않은 하네스 내부 레이아웃이므로 규약이 바뀌면 `BLOCKED transcripts-unreadable` → `blocked-health` 벽으로 **영구 정지**한다. 설계상 이 방향이 안전(측정 불가를 0 지출로 위장하지 않음, `:29-33` 주석)이지만 goal 루프가 원인 불명으로 못 도는 형태가 된다. 부수: 이 스크립트는 판정과 동시에 `loop.md`의 `budget-spent · since:`를 **덮어쓴다**(`:214-224`) — `loop.md`를 변경하는 유일한 스크립트이며, 판정이 소비되지 않아도 `since:`는 이미 전진해 있다.
- **C23. 비-기본 브랜치에서는 `drive.md`가 git 추적 대상이다** `[확정 / 이번 세션 `git check-ignore` 재현]` — `.gitignore:11`의 `!.forge/branch/`가 브랜치 루트를 통째로 화이트리스트하므로 `.forge/branch/<branch>/drive.md`는 ignored가 아니다(재현: `check-ignore` rc=1, `git status`에 `?? .forge/branch/` 노출). 무인 주행 중 `git add -A`가 세션 ID를 담은 마커를(그리고 크래시 시 `drive.md.tmp.$$` 잔해까지) 커밋한다. 실피해는 낮다 — `Stop` 훅은 해석된 루트의 `drive.md`만 보므로 머지된 마커가 main 세션을 막지 않고, `forge-merge.sh:339`의 `rm -rf "$SRC"`가 폴더째 치운다. 다만 `forge-merge.sh:65`의 forge-루트 판별 목록(`CONTEXT.md plan.md run.md STATUS.md loop.md`)과 GATE 1의 in-flight 목록(`:128-132`) **어느 쪽에도 `drive.md`가 없다** — 살아 있는 `fg-next all` 주행은 fg-merge의 in-flight 감지에 안 걸린다.
- **C24. `.forge/agenda.md`는 어떤 결정론 표면에도 보이지 않는다** `[확정 / 이번 세션 grep + 상태 실측]` — `scripts/forge-status.{sh,js}`·`scripts/forge-hook-session-start.sh`·`scripts/forge-doctor.{sh,js}` 전부 `agenda` 문자열 0건. 유일한 노출 경로는 `skills/fg-status/SKILL.md:30,44,57`의 산문 지시이고, 그 문서 자신이 **"The script never reports this — deliberately"**라고 밝힌다(의도된 결정이지 버그가 아니다). 실측 대가: 현재 `.forge/agenda.md`는 2026-08-05 개시, 결정 4·열린 질문 4·fog 보유 상태로 **21일째** 서 있는데, doctor는 clean(경고 1건은 B16)이고 SessionStart 훅은 침묵한다. 의제는 "낡음"을 알려주는 장치가 없는 유일한 활성 상태 파일이다(비교: `loop.md`는 fg-status·fg-ask·fg-merge가 모두 본다).
- **C25. 벤더링된 fg-security 12파일에 드리프트 감지가 없고, 그 안의 실행 코드는 스크립트 규약 밖이다** `[확정 / 이번 세션 확인]` — `skills/fg-security/`에 업스트림(cloudflare/security-audit-skill, MIT) 파일 12개가 있고(`AUDIT.md` + 형제 11: 플레이북 6·`RECONNAISSANCE`·`HUNTING`·`VALIDATION-AND-REPORTING`·`report-schema.json`·`validate-findings.cjs`, 그리고 `LICENSE`), `SKILL.md:10`이 "byte-for-byte with upstream"을 요구한다. **체크섬도 핀도 없다** — 원본 커밋 SHA가 리포 어디에도 기록돼 있지 않아 "언제 것과 동일한가"를 확인할 방법이 없고, 실수로 한 줄 고쳐도 아무 검사가 안 잡는다. 부수: `validate-findings.cjs`는 `scripts/` 밖이라 fg-doctor의 B15(트윈 존재 검사, `"$repo"/scripts/*.sh` 글롭 한정)와 ADR-0022 이중 디스패치 규약이 **닿지 않는** 실행 코드다. 산출물을 리포 밖(`~/security-audit-skill/`)에 두는 결정은 커밋 경로를 구조적으로 없앤 옳은 선택이지만, 그 결과 **생성된 fix-forward plan이 유일한 리포 내 취약점 정보 운반체**가 되고 그것을 지키는 것은 `SKILL.md:55`의 산문("run과 index로만 참조, 페이로드·재현 명령 금지")뿐이다.

---

## 이미 판정된 무해 항목 (재조사 불필요) `[확정/이월]`

- **런타임 부재**: bash·node 둘 다 없으면 `hooks/run-hook.cmd`가 조용히 exit 0 → 훅 도입 전 현상 유지(`:82-88` 재확인).
- **`.forge`가 파일인 경우 / STATUS 없는 park 디렉터리**: 훅이 exit 0(침묵/폴백).
- **깨진 `config.json`**: `resolve-forge-root.{sh,js}`가 정규식으로 `defaultBranch`를 뽑아 파싱 예외가 없고 sh·js 일치.
- **`forge-statusline-wrapper.sh`의 `.js` 트윈 부재**: 의도된 예외로 fg-doctor의 B15가 명시 제외(`*-wrapper.sh` case).
- **`STATUS.md` 필드 표기 두 형식 공존**: 봉인 138건 중 legacy 불릿 형식(`- verified:`)이 섞여 있으나 파서가 양쪽을 명시 허용(`-\{0,1\}` 앵커). 이 리포에서 STATUS 통계를 낼 때는 불릿 접두를 허용해야 한다(이번 세션 집계도 그렇게 했다).
- **`.forge/dropped/`(1건 존재)**: 기본 브랜치에서 gitignored — 설계 그대로(ADR-0021).
- **루트 `package.json`에 `"type"` 필드 없음**: 확인 완료(`name: forge-docs`, `private: true`, scripts는 vitepress 3종). CLAUDE.md가 경고하는 CommonJS 붕괴 조건에 해당하지 않는다.
- **`Stop` 훅의 실패 경로 전량**: 마커 부재·세션 불일치·미파싱·시계 부재·tty·쓰기 실패 모두 exit 0(정지 허용)이며 behavior 10 + parity 16 케이스가 덮는다(실측 전건 통과). 위험은 코드가 아니라 마커 삭제 계약에 있다(B11).
