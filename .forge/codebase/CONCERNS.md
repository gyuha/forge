---
last_mapped_commit: 48899bdb6b04ad575767885a7c741cb2a09bd9d0
mapped: 2026-08-10
---

# CONCERNS — 기술 부담·결함·취약 지점

이 문서는 **구현 사실**만 담는다. 용어 정의는 `.forge/CONTEXT.md` 소관이다.

**읽는 법**
- `[확정]` — 이 매핑 세션에서 실제로 재현·실측·grep으로 확인한 것.
- `[확정/이월]` — 과거 매핑이 재현·실측으로 확정했고, 이번 세션에 해당 파일이 **한 줄도 변하지 않았음을 확인**해 근거가 그대로 유효한 것.
- `[의심]` — 코드를 읽어 추론했으나 재현하지 않은 것.
- severity: **critical**(사용자 머신에 실제 피해 가능) / **major**(상태 손상·조용한 실패·체감 성능) / **minor**(정합·유지보수).

forge는 공개 배포되어 남의 머신에 설치되고, **세션 시작마다 실행되는 셸/노드 코드**를 배포한다. 그래서 훅·스크립트 경로의 결함은 문서 결함과 급이 다르다. 반대로 이 리포에서 "코드"의 절반은 산문이므로, **문서 드리프트가 곧 동작 드리프트**인 경로가 따로 존재한다.

**이 세션의 기준선**(`48899bd`, v0.6.6): `bash scripts/forge-doctor.sh` → **0 errors, 0 warnings, 0 info**(실측). 활성 슬롯·backlog·executed 전부 비어 있고 `loop.md` 없음. 봉인 120건, 활성 ADR 47건, `retired/` 0건. **`a7a9c3e..48899bd` 구간에서 `scripts/`·`hooks/`는 파일 변경 0건**(`git diff --name-only` 무매치, 실측) — 따라서 코드 근거 항목(A절, B1~B4, B8, C2·C3·C8·C9)은 지난 매핑의 재현 결과가 그대로 유효하다. 이 구간에 들어온 것은 핸드오프 표 구현(`28e5eef`)·그 회고(`b4aa9fa`)·fg-loop `waiting`/`blocked-health`(`bf018d4`)·릴리스 2건·랜딩 페이지 수정 2건이다.

---

## A. 방어선이 생긴 항목 (재조사 불필요 — 단, 지우면 결함이 되돌아온다) `[확정/이월]`

훅 인젝션 계열 결함 6건은 `.forge/done/260730-234125-…-hook-hardening-fix/` → `.forge/done/260731-153236-hook-task-field-unbounded-fix/` 두 차례로 봉인됐고, 지난 매핑이 실제 공격 입력(닫는 태그 주입·100자리 task)으로 재확인했다. 이번 구간 훅 파일 무변경.

- **인젝션 차단** — 단일 초크포인트 `sanitize()`(`scripts/forge-hook-session-start.sh:74-87` / `.js:46-51`): 제어문자·CR/LF·태그 구분자 `<`/`>` 제거, 바이트 절단(멀티바이트 경계 보정). `NO EXEMPTIONS` 주석이 불변식.
- **소스단 상한** — `SAN_MAX=200` + `TASK_DIGITS_MAX=9`.
- **트렁케이션 차단** — `.js`가 `process.stdout.write` 뒤 `process.exit()`를 부르지 않는다.
- **park 개념 분리** — park은 별도 개수 줄, 헤더는 `Unsealed tail (ran, not sealed):`.
- **지시 문단 범위 한정** — "fg-ask's STEP 0 auto-close is the one approved exception" 문구 + 순서 계약 테스트.

**잔여 위험(구조적)**: 방어는 값이 블록을 **탈출**하지 못하게 막을 뿐, 값 안의 명령문 자체는 그대로 컨텍스트에 주입된다. 데이터로 묶는 마지막 한 겹은 산문 경고(모델의 순종)다.

---

## B. 미결 — critical·major

### B1. `forge-done.sh`가 봉인 실패를 은닉하고 `SEALED`를 출력한다 (+ 트윈이 정반대로 죽는다) — **major** `[확정/이월 + 이번 세션 코드 재확인]`
- 위치: `scripts/forge-done.sh:175-179` — `mkdir -p "$DEST"` · `mv … 2>/dev/null || true`의 결과를 아무도 확인하지 않는다(이번 세션 코드 재확인). 트윈은 `scripts/forge-done.js:167`의 `fs.renameSync`가 예외를 던져 **문서화된 exit code 계약(2/3/4/5/64)에 없는 exit 1**로 죽는다.
- 지난 매핑의 재현(`done/`을 `chmod 500`): `.sh`는 stderr에 에러를 흘리고도 **`SEALED` + exit 0**, 활성 슬롯의 STATUS는 이미 `status: done`으로 덮어써진 상태로 잔존. 같은 입력에서 두 트윈이 다른 결과 = **parity 사각지대**(파일시스템 실패 픽스처가 스위트에 없다).
- **세 방어선이 전부 이 손상을 못 본다**: SessionStart 훅(`status != done` 조건이라 침묵), `forge-doctor.sh`(활성 슬롯의 `status: done`을 잡는 검사 없음), fg-done 스킬(exit code만 보고 "봉인 완료" 보고).
- 전제는 파일시스템 실패라 드물지만, 결과는 "봉인됐다고 믿는 미봉인 작업" — 재실행 방지 메커니즘의 정반대.

### B2. `.forge/branch/` 스캔이 2단 깊이라 3세그먼트 브랜치가 통째로 안 보인다 — **major** `[확정 / 이번 세션 코드 재확인]`
- 위치: `scripts/forge-merge.sh:70`(`"$BRANCHES_DIR"/*/ "$BRANCHES_DIR"/*/*/` — 재확인), `scripts/forge-merge.js:49-58`(깊이 2 고정), `scripts/forge-doctor.sh:89`(같은 글롭).
- 결과: `release/2026/hotfix`류 3+ 세그먼트 브랜치의 ADR·retro·done·backlog는 `fg-merge`가 `EMPTY nothing-to-integrate`로 넘기고, fg-doctor A8 경고도 안 뜬 채 기본 브랜치 트리에 **경고 없이 영구 잔존** — 조용한 데이터 유실. A8은 warning이라 CI 게이트(exit 2 기준)도 통과한다. 3세그먼트 픽스처가 스위트에 없어 회귀로 안 잡힌다.

### B3. `async: false` + bash 훅의 O(n) 서브프로세스가 세션 시작을 초 단위로 막는다 — **major** `[확정/이월 + hooks.json 재확인]`
- 위치: `hooks/hooks.json:11`(`"async": false` — 재확인) + `scripts/forge-hook-session-start.sh:106-111`(`field()` 호출마다 4프로세스) + park **전량 순회**.
- 지난 매핑 실측(macOS, 이후 무변경): `executed/` 300개에서 `.sh` **0.839s** vs `.js` 0.052s. bash가 우선 경로(`hooks/run-hook.cmd`)인데 하필 bash만 선형 증가.

### B4. 스크립트 백킹 컨벤션(ADR-0031)이 자기 리포에서 2건 위반 — behavior 테스트 없음 — **major** `[확정 / 이번 세션 재확인]`
- ADR-0031은 트윈 + parity + behavior 테스트 + 계약 동기 4종을 필수로 못 박는다. `ls scripts/` 재확인: **`forge-status`·`resolve-forge-root`는 parity 테스트만 있고 behavior 테스트가 없다**(`forge-status.test.sh`·`resolve-forge-root.test.sh` 부재). 하필 이 둘이 의존의 뿌리다 — `forge-status.sh`는 fg-status/fg-next 상태 머신의 조사(ADR-0020), `resolve-forge-root.sh`는 **모든 루프 스킬의 경로 해석**(ADR-0011). parity만 있으면 "두 트윈이 똑같이 틀린" 경우가 green이다.
- 감지 수단 없음: `forge-doctor.sh`의 B15는 트윈 **파일 존재**만 검사한다.

### B5. fg-map 증분 Update의 "상속된 거짓 보존" — 가드는 산문뿐, 자동 게이트 0건 — **major** `[확정/이월 + 이번 세션 doctor 재확인]`
- ADR `260801-020258`이 Update를 "재탐색 금지 + 제자리 편집" 하드 계약으로 정의하고 스크립트화를 명시 기각 → 트윈·테스트 없음. 가드는 `skills/fg-map/SKILL.md:51-57`·`:95-98`의 산문 mandatory 단계뿐.
- 구조적 대가: 베이스라인을 정답으로 삼으므로 **이미 들어 있던 틀린 사실은 검사받지 않고 살아남는다** — 두 리포에서 독립 실측(증분 5회가 통과시킨 오류 3건). 30% 축소 가드는 *유실*은 잡아도 *보존된 거짓*은 못 잡는다(라인 수 불변).
- 스탬프 사전점검은 `sort -u` 1줄만 봐서 7문서 중 1개 스탬프 소실을 못 잡고, 지도 문서가 프론트매터 예시를 줄 시작에 쓰는 순간 사전점검이 영구 실패한다(자기 참조 부류 — 실제 발동 이력 있음).
- **자동 게이트 0건**: `scripts/forge-doctor.{sh,js}`에 `.forge/codebase/` 검사가 전무하다(이번 세션 grep 0건 재확인). 지도가 통째로 삭제돼도 doctor는 0 findings. 지도는 fg-ask 그릴링의 연료이므로 조용한 드리프트 = 계획 품질 저하.

### B6. 브라우저 답변 채널(fg-visual)의 신뢰성이 전부 산문 수명 의무 위에 서 있다 — **major** `[확정/이월]`
- `Monitor`는 `persistent: true`로 걸며 스스로 만료되지 않는다 — 서버를 멈추는 **모든** 경로가 `TaskStop`을 함께 불러야 하고(`skills/fg-visual/VISUAL.md:357`), 빠뜨리면 죽은 세션의 events 파일을 tail한다. 실제 실행 중 재장전 누락이 두 번 발동(회고 `260805-063357`).
- 서버 4시간 유휴 종료는 인증된 요청만 활동으로 세므로 "클릭만 기다리는" 상태가 방치 구간이 된다 — 실측 5시간 11분 뒤 자기 종료. 완화는 "화면 밀기 전 서버 생존 확인" 산문 한 줄뿐.
- 텍스트 전송 버튼(`VISUAL.md:297`)에 확정 버튼의 `dataset.sent` 중복 전송 가드가 **없다**(확정 쪽에서 798ms 더블클릭 중복 실측, 텍스트 쪽 미수정).
- 위험의 성격은 중단이 아니라 **침묵** — 사용자가 누르고 기다리는데 아무 일도 안 일어나는 것.

### B7. 스킬 `description`이 카탈로그 설명과 자동 호출 트리거를 겸한다 — 상한 압력 상시 — **major** `[확정 / 이번 세션 재측정]`
- `DESC_MAX=600`(`scripts/forge-doctor.sh:169`, 코드포인트 기준) 대비 이번 세션 재측정: **fg-doctor 591(98%)** · fg-visual 573 · fg-eco 546 · fg-adversarial-review 531. fg-visual은 지난 구간에 실제로 615로 상한을 넘겼다가 압축된 이력이 있다 — "능력이 늘 때마다 description이 자란다"는 압력이 실증된 상태.
- `skills/fg-done/SKILL.md:3`은 여전히 `(Note: 'forge cleanup' routes to fg-cleanup, not here.)`로 트리거 충돌을 산문으로 막는다.
- B16은 **길이만** 본다 — description ↔ 본문의 의미 일치, 자동 호출 정확도의 회귀 테스트는 없다. 문구 드리프트가 곧 동작 드리프트가 된 실사례(fg-visual "표시 전용" 잔존)와 이름 오발동으로 실행 중 개명한 사례(fg-chart→fg-agenda)가 기록돼 있다.

### B8. 테스트가 프로덕션 호출 형태를 재현하지 않으면 통과가 아무것도 보장하지 않는다 — **major(구조적)** `[확정/이월]`
- 근거: `.forge/done/260727-233237-…/run.md` — 22개 단언 전부 통과 상태에서 훅이 전혀 발화하지 않았다(`hooks/run-hook.cmd` exec bit 부재; 테스트는 `bash "$WRAPPER"`로 불러 통과). exec bit 단언 테스트는 리포 전체 1건(`hooks/run-hook.test.sh:43`), exec bit는 파일마다 제각각(`forge-doctor.sh`·`forge-hook-session-start.sh`는 644) — 직접 실행으로 배선을 바꾸는 순간 지켜주는 장치가 없다.

### B9. fg-loop `waiting`/`blocked-health`(신규, `bf018d4`)의 안전장치가 전부 산문 계약이다 — **major** `[확정 / 이번 세션 확인]`
- `evidence: external`로 선언된 체크는 통과 전까지 무조건 `waiting`으로 분류돼 **자동 수리 대상에서 빠진다** — "빨간 CI"와 "미완 CI"를 구분 못 하는 것이 문서화된 대가이고, 영구 대기를 막는 유일한 장치는 `stalled-waiting`(`×2` 증거 불변) 상한이다(`skills/fg-loop/SKILL.md:103-120`, ADR-0016 개정 2026-08-09). 상한 감지·증거 비교 모두 에이전트 판단 산문이며 스크립트 게이트가 없다.
- `blocked-health`는 "체크 명령의 실행파일 도출 점검 + **보수적 사후 승격**"인데 승격 판단이 best-effort 자기분류다(`:108-111` "Derive, don't declare" / "Conservative post-hoc promotion") — `safety` 벽과 같은 부류의, 산문으로만 지켜지는 계약.
- **stale `wall:` 오보고 경로는 산문 3겹으로만 막혀 있다** — `waiting` 신설로 "재개 시 이전 벽 원인 미해제"라는 기존의 무해한 암묵 규칙이 실제 오보고 경로가 됐고(적대 리뷰 high), 수정은 `wall: none` 전이 규칙 산문(`skills/fg-loop/SKILL.md:65,147`)과 fg-status의 서술 지침(`skills/fg-status/SKILL.md:25,98`)이다. 기계 검증 없음. 회고 `260810-084115`가 "상태 enum에 새 값을 더할 때 기존 값들의 해제 시점을 함께 감사하라"를 학습으로 남겼다.
- UAT 한계(회고의 3회+ 반복 패턴 재확인): forge-meta 지시문 작업의 검증은 "grep 가능한 문서 구조"까지이고, 진짜 효과(실주행에서 대기가 벽으로 오분류되지 않는가)는 실제 goal loop 주행 전까지 미검증이다.

---

## C. 미결 — minor

- **C1. `CLAUDE.md:7`이 산출물을 "전부 Markdown과 JSON"이라고 단언한다** `[확정 / 재확인]` — 트리는 `scripts/`의 sh/js 트윈 + 테스트 파일 31개와 exec bit 붙은 `hooks/run-hook.cmd`를 배포한다. 리포 최상위 안내문이 "남의 머신에서 자동 실행되는 코드"라는 위험 표면을 서술에서 지운 상태다(같은 CLAUDE.md의 뒷부분은 스크립트를 상세 서술하므로 첫 단락만 낡았다).
- **C2. 상태 추출 로직이 10개 파일에 서로 다른 의미로 복제돼 있다** `[확정/이월]` — `field()`는 `forge-{done,status,doctor,hook-session-start}.{sh,js}` 8파일 + `forge-merge.{sh,js}`의 `slugof`/`taskof`. 의미가 의도적으로 다르다(doctor/status/done은 콜론 뒤 첫 토큰만, 훅은 전체 값, done만 별도 `fullfield()`). 공유 모듈이 없어 "중복 제거" 리팩터가 훅 출력 의미를 조용히 바꿀 수 있다.
- **C3. 테스트 러너도 CI도 없다** `[확정 / 재확인]` — `.github/` 없음, 일괄 실행 스크립트 없음. 테스트 파일 16종은 사람이 기억해서 손으로 돌린다. fg-doctor는 CI 게이트로 설계됐지만(exit 0/1/2) 그것을 부르는 자동화가 리포에 없다.
- **C4. 실제 `verified:` 값의 40%가 훅 주입 시 잘린다** `[확정 / 이번 세션 전수 재계산]` — `.forge/done/*/STATUS.md` **120건** 중 `verified:` 값 **48건(40%)이 200바이트 초과** → `SAN_MAX`에서 절단. 4작업이 더 봉인된 뒤에도 비율 불변 — 서술 습관이다. 사유 뒷부분이 세션 시작 컨텍스트에 도달하지 않는다.
- **C5. 모드 토글이 git 추적 파일을 더럽힌다** `[확정 — 구조적, 현재 미발현]` — `.gitignore`가 `!.forge/config.json`을 화이트리스트하므로 `fg-eco on`이 곧 리포 diff다. 지금은 `{"eco": false}`로 깨끗하다 — 결함은 사라지지 않았고 토글이 꺼져 있을 뿐.
- **C6. 활성 ADR 47건, `retired/` 0건** `[확정 / 재확인]` — fg-cleanup(ADR-0012)이 한 번도 돌지 않았고 fg-ask가 읽는 결정 집합은 단조 증가만 한다. 신규 ADR이 선행 ADR의 판단을 뒤집고도(예: `260805-231104` ↔ `260730-230321`) 은퇴 없이 상호 참조로 공존하는 관행이 계속된다.
- **C7. 회고 skip이 여전히 절반이다** `[확정 / 이번 세션 재계산]` — 봉인 120건 중 `retro: skipped` **60건(50%)**. ADR-0002의 "skip은 저-divergence 한정" 규정과 달리 `fg-next all`/`fg-loop`의 무조건 skip이 정책적으로 이를 만든다. 같은 표본의 `verified:`는 `yes` **98** / `n/a` 22, 차단 값(`pending`/`failed`) **0** — 검증 게이트(ADR-0009)는 실측으로 강하게 지켜지고 있다.
- **C8. `compact` 매처가 무인 주행 중간에 발화한다** `[확정 / hooks.json:5 재확인]` — `fg-next all`/`fg-loop` 주행 중 컨텍스트 압축이 일어나면 "사용자에게 물어라"가 주입된다. 매처 축소/in-flight 분기/침묵 스위치 중 미결.
- **C9. Windows 커버리지 과대 서술** `[확정/이월]` — `hooks/hooks.json:10`이 `"shell": "bash"`이므로 bash 없는 Windows에서는 훅이 비활성(비차단). `hooks/run-hook.cmd`의 배치 절반은 하네스 경로에서 사실상 죽은 코드.
- **C10. 세션 중 편집한 `SKILL.md`는 그 세션에 반영되지 않는다** `[확정/이월]` — 플러그인 스킬 본문·훅·`.claude/agents/` 카드 모두 세션 시작 1회 로드(ADR-0024 실측). 스킬을 고치는 작업의 "재시작 후 실 동작 검증"은 원리적으로 다음 세션의 일이라 미검증 잔여가 구조적으로 쌓이고, 이를 추적하는 상태 파일은 없다. B9의 fg-loop 신규 상태도 정확히 이 부류다(문서 grep까지만 검증됨).
- **C11. `debt` 용어 잔여 1건** `[확정 / 재확인]` — `hooks/run-hook.test.sh:55` 주석.
- **C12. 두 매니페스트 description이 갈라져 있다** `[확정 / 이번 세션 재측정]` — `plugin.json` **10,446자** vs `marketplace.json` `plugins[0]` **9,289자**(지난 매핑과 동일 — 이번 구간 무변경). 20개 스킬 이름은 양쪽 모두 있으나 어느 검사도 두 값을 비교하지 않는다(doctor는 version 3곳만). 스킬이 늘 때마다 손 동기 부담도 는다.
- **C13. `docs/index.html`은 어떤 자동 검사에도 없다 — 이번 구간에 드리프트가 또 실현되고 또 사람이 고쳤다** `[확정]` — 커밋 `eb334d1`("랜딩 페이지가 핸드오프 표를 반영하지 않던 드리프트 2건")이 세 번째 실현 사례다(지난 구간의 fg-visual 누락·개수 오기에 이어). `scripts/forge-doctor.{sh,js}`에 `index.html` 검사는 여전히 0건(grep 무매치 재확인) — doctor의 B13은 README 쌍 행 수 parity만 본다. 한 파일 안 KO/EN `data-l` span 구조(ADR-0027)라 두 언어가 함께 틀리는 형태를 막는 장치가 없다.
- **C14. 출력 *형태* 규율에는 기계 게이트가 없다 — 핸드오프 표가 구현됐지만 한계는 그대로 승계됐다** `[확정 / 이번 세션 갱신]` — 핸드오프 표(ADR `260805-231104`)는 `28e5eef`로 구현 완료: `skills/fg-next/HANDOFF.md`가 존재하고 스킬 33지점이 참조하며 CLAUDE.md 규약도 개정됐다(대화체 폐기). 지난 매핑이 기록한 "정본 파일 부재 + CLAUDE.md 모순" in-flight 창은 닫혔다. 그러나:
  - 회고 `260807-150205`가 명시적으로 남긴 대로 **표 렌더에는 여전히 기계 게이트가 없다**(에이전트 판단 산문) — ADR-0032·`260730-230321`·`260805-231104` 세 번 연속 같은 한계.
  - 그 구현 자체가 새 결함 부류를 실증했다: 영문 규율 문서에 **지시("사용자 언어로 렌더")와 모순되는 한글 예시**가 실려 13개 스킬 40여 지점으로 퍼졌고, 리뷰 6렌즈도 통과했다(결함이 현재 세션 언어와 우연히 일치하면 구조적으로 불가시 — 이중언어 자산 공통의 사각지대). 사후 수정됐고(`b4aa9fa` 회고) 이번 세션 grep으로 한글 하드코딩 트리거 잔여 0건을 확인했지만, "반대 언어 세션에서 어떻게 보이는가"를 검사하는 장치는 여전히 없다.
  - 같은 작업의 run.md가 미실행으로 남긴 단계(S6)가 실제로는 이미 수정돼 있었다(수정 주체 기록 없음) — **run.md 잔여 목록을 정본으로 믿으면 중복 작업**이 되는 원장 신뢰 문제가 기록됐다.
- **C15. `skills/fg-merge/SKILL.md:19`의 "never runs git"이 거짓이다** `[확정/이월]` — `scripts/forge-merge.sh`는 읽기 전용 git 호출 3개(`:57`·`:325`·`:328`)를 경고 스캔에 쓴다. 정확한 표현은 mutation-free이고 스크립트 자신의 헤더 주석은 맞게 적혀 있다 — 산문만 드리프트. 이 문장이 CI 게이트 주장의 근거로 쓰이므로 사소하지 않다. 아직 안 고쳐졌다.
- **C16. eco의 ECO.md 전문 주입이 코드를 쓰지 않는 서브에이전트에도 걸린다** `[확정/이월]` — `skills/fg-run/SKILL.md`의 "all workflow/execution subagents" 지시 때문에 채점·선언만 하는 비-코딩 에이전트에도 코드 단순성 규율 전문이 주입된 실사례(회고 `260801-234547`). 처방(코드 슬라이스 한정 또는 ECO.md 분할)은 ADR-0014 문언 수정이 걸려 미결.
- **C17. `.forge/` 장부가 외부 트리 스캐너에 코드로 흡수된다** `[확정/이월]` — graphify 실측 41.5%가 `.forge/` 유래. `.graphifyignore`로 그 한 도구만 해소됐고, 인덱서·RAG·검색 도구 일반에 대한 표준 제외 신호는 없다.
- **C18. 그릴링이 plan에 적는 ADR 파일명을 검증하지 않는다** `[확정 — 실사례 2건]` — 회고 `260810-084115` divergence ④: plan의 ADR 링크 2건이 실제 파일명과 불일치(기억으로 적고 `ls` 확인 안 함). plan은 실행의 정답 기준이므로 깨진 참조가 실행 중 잘못된 문서 탐색을 유발할 수 있다. 같은 회고가 "적기 전 `ls`로 실명 확인"을 학습으로 남겼을 뿐 게이트는 없다.

---

## 이미 판정된 무해 항목 (재조사 불필요) `[확정/이월]`

- **런타임 부재**: bash·node 둘 다 없으면 `hooks/run-hook.cmd`가 조용히 exit 0 → 훅 도입 전 현상 유지.
- **`.forge`가 파일인 경우 / STATUS 없는 park 디렉터리**: 훅이 exit 0(침묵/폴백).
- **깨진 `config.json`**: `resolve-forge-root.{sh,js}`가 정규식으로 `defaultBranch`를 뽑아 파싱 예외가 없고 sh·js 일치.
- **`forge-statusline-wrapper.sh`의 `.js` 트윈 부재**: 의도된 예외로 B15가 명시 제외.
- **`STATUS.md` 필드 표기 두 형식 공존**: 봉인 120건 중 legacy 불릿 형식(`- verified:`)이 섞여 있으나 파서가 양쪽을 명시 허용(`-\{0,1\}` 앵커). 이 리포에서 STATUS 통계를 낼 때는 불릿 접두를 허용해야 한다(이번 세션 집계도 그렇게 했다 — `verified: yes` 98에는 불릿 16건 포함).
- **`.forge/dropped/`(1건 존재)**: 기본 브랜치에서 gitignored(이번 세션 `git check-ignore` 확인) — 설계 그대로(ADR-0021).
