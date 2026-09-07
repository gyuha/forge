---
last_mapped_commit: 0be20755431c3864dd25f295e8f1af45425445c2
mapped: 2026-09-07
---

# TESTING

이 문서는 **구현 사실만** 다룬다. 아래 수치는 이 커밋의 작업 트리에서 2026-09-07에 **전체 테스트를 실제로 돌려** 얻은 값이다(macOS/darwin 25.5.0, **21개 파일 전부 rc=0**). 같은 시점:

- `bash scripts/forge-doctor.sh` = **0 errors / 0 warnings / 0 info**(node 트윈도 동일). **처음으로 완전 클린이다** — 종전 유일한 warning이던 B16(`skills/fg-help/SKILL.md` 768자 > 600)이 커밋 `7d5623c`에서 description을 트리거 코어로 줄여 해소됐다(현재 최장은 `skills/fg-showme/SKILL.md` 649바이트이고 B16은 코드포인트로 세므로 600 미만). **이것이 "fg-doctor를 CI에 배선하지 않았다"의 근거를 무효화한다** — `CLAUDE.md`는 아직 "현재 B16 warning 1건으로 exit 1이라 즉시 붉어진다"고 적고 있으나 실측은 exit 0이다(§8).
- `bash scripts/release-check.sh` / `node scripts/release-check.js` = 둘 다 `ok (forge 0.8.5, shared skills + Claude/Codex adapters)`.

## 1. 프레임워크: 없음 — 순수 bash 스크립트 테스트

테스트 러너·프레임워크·의존성이 전혀 없다. 각 테스트는 자기완결 bash 스크립트로, 내부에 `assert()`/`assert_grep()` 헬퍼를 자체 정의하고 `pass`/`fail` 카운터를 세다가 실패가 있으면 exit 1 한다. 실행법은 파일 헤더 주석에 명시: `bash scripts/<name>.test.sh`.

테스트 대상은 산문 스킬이 아니라 **결정론 스크립트 층**(ADR-0022 트윈 11쌍)과 **훅 배선**뿐이다. 스킬(SKILL.md) 자체는 단위 테스트가 없고, 실동작 검증은 플러그인 설치 후 트리거해 보는 것뿐(`CLAUDE.md` 명시).

## 2. 테스트 파일 인벤토리 (21개, 전부 green)

두 종류가 있다 — **behavior 테스트**(`*.test.sh`, 픽스처 대비 단일 구현의 계약 검증)와 **parity 테스트**(`*.parity.test.sh`, 같은 픽스처에 `.sh`와 `.js`를 둘 다 돌려 출력 동일성 단언 — ADR-0022의 진짜 drift 가드).

| 파일 | 종류 | 2026-09-07 실행 결과 (괄호는 이전 판 대비) |
|---|---|---|
| `scripts/forge-doctor.test.sh` | behavior | **78 passed**(54 → 78 = B18 단언 18개 + B16 folded-scalar 3개 + A1b half-exec 3개) |
| `scripts/forge-doctor.parity.test.sh` | parity | PARITY OK (**22 케이스**, 11 → 22: B18 9개 추가) |
| `scripts/forge-done.test.sh` | behavior | **70 passed**(60 → 70: 회고 조회 정확성·경로 상대성) |
| `scripts/forge-done.parity.test.sh` | parity | PARITY OK |
| `scripts/forge-hook-session-start.test.sh` | behavior | 65 passed |
| `scripts/forge-hook-session-start.parity.test.sh` | parity | PARITY OK |
| `scripts/forge-hook-stop.test.sh` | behavior | 10 passed |
| `scripts/forge-hook-stop.parity.test.sh` | parity | all identical |
| `scripts/forge-loop-spend.test.sh` | behavior | 38 passed |
| `scripts/forge-loop-spend.parity.test.sh` | parity | all identical |
| `scripts/forge-merge.test.sh` | behavior | 58 passed |
| `scripts/forge-merge.parity.test.sh` | parity | PARITY OK |
| `scripts/forge-status.parity.test.sh` | parity | PARITY OK (픽스처 **H–L 5개 추가**, +102줄) |
| `scripts/forge-statusline.test.sh` | behavior | 35 passed |
| `scripts/forge-statusline.parity.test.sh` | parity | PARITY OK |
| `scripts/forge-statusline-full.test.sh` | behavior | 34 passed |
| `scripts/forge-statusline-full.parity.test.sh` | parity | PARITY OK |
| `scripts/forge-statusline-wrapper.test.sh` | behavior | 7 passed |
| `scripts/release-check.parity.test.sh` | parity | RELEASE-CHECK PARITY OK (**17 케이스**, 7 → 17: capability 어휘 6개 + docs 4개) |
| `scripts/resolve-forge-root.parity.test.sh` | parity | PARITY OK |
| `hooks/run-hook.test.sh` | behavior(배선) | **25 passed**(22 → 25: 문자열 grep 단언 1개를 **실행** 단언 4개로 교체 — §3) |

파일 **개수는 21개로 그대로**이고(신규 테스트 파일 0), 늘어난 것은 전부 기존 파일 안의 케이스다. 총 6개 파일이 +260줄 −2줄 변경됐다.

비대칭 주의(**3건**): `forge-status`·`resolve-forge-root`·`release-check`는 **parity 테스트만** 있고 단독 behavior 테스트 파일이 없다(parity의 populated 케이스가 sentinel 검사로 일부 behavior를 겸함). `release-check`의 경우 parity 케이스가 7 → **17개**로 자라 위반 유형을 더 촘촘히 덮으므로 이 비대칭이 더 굳었다 — 실측 케이스 이름: `all in sync`·`version drift`·`wrong skills field`·`missing hooks.json`·`missing host adapter`·`missing manifest`·`multiple violations, same order`·`capabilities unknown key`·`capabilities missing keys`·`capabilities broken JSON`·`capabilities non-boolean`·`HOST.md vocabulary gone`·`claude host checked too`·`docs name every capability key (clean)`·`docs missing a capability key`·`en docs checked too`·`support-table doc missing`.

## 3. 구조·패턴

- **픽스처 = mktemp 디렉터리에 `.forge/` 상태를 손으로 조립.** 예: `scripts/forge-doctor.test.sh`가 `mktmp()`로 임시 디렉터리를 만들고 `seed_status()`로 STATUS.md를 심은 뒤 `run_doc`으로 실행, `assert "A1-rc2" 2 "$RC"` + `assert_grep "A1-msg" "$OUT" "A1 active-slot orphan"`으로 **exit code(0/1/2 severity 계약)와 메시지 문자열**을 동시에 단언한다.
- **mocking 없음.** 실제 파일시스템(임시 디렉터리)과 실제 bash/node 실행뿐이다. 외부 네트워크·git 원격 의존 없음(forge-merge 코어는 git 자체를 안 건드림 — ADR-0011 CI git-free).
- **behavior 테스트를 js 트윈에 재사용**: 구현 경로를 env로 주입 — `FGDOCTOR_IMPL=.../forge-doctor.js bash scripts/forge-doctor.test.sh`(파일 헤더 명시), `run_doc()`이 `*.js`면 node로 분기. statusline-full도 같은 패턴(`impl:` 표기가 결과 줄에 나옴).
- **parity 테스트의 anti-vacuous 가드**: `scripts/forge-status.parity.test.sh`는 `set -euo pipefail`로 픽스처 조립 실패 시 abort하고, populated 케이스에 sentinel 부분문자열 존재를 단언해 "둘 다 빈 출력이라 동일" 같은 헛통과를 막는다(파일 헤더 주석에 근거 명시).
- **훅 배선 테스트**: `hooks/run-hook.test.sh`는 `hooks.json`의 JSON 유효성 + command/matcher 계약 필드 + `run-hook.cmd` 디스패치를 검사한다 — "hooks.json 오타는 어디서도 에러 없이 훅을 조용히 끈다"는 위험을 겨냥(헤더 주석).
- **문자열 대조를 실행으로 승격한 사례(신규 — 이 리포에서 가장 교훈적인 테스트 변경).** 종전 `assert_grep "hooks.json-codex-root"`(command에 `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}` 문자열이 있는지)가 **삭제되고** 실행 단언 4개로 교체됐다. 테스트 주석이 이유를 직접 적는다 — 호스트 루트 표현식을 grep하는 것은 "작성자의 문자열이 아직 파일에 있다"만 증명하고 **누군가 편집할 때는 실패하지만 그것이 틀렸을 때는 절대 실패하지 않는다**. 새 방식은 command를 `node -e "JSON.parse(...).hooks.SessionStart[0].hooks[0].command"`로 뽑아 조립된 `.forge/` 픽스처 안에서 **`/bin/sh -c "$CMD"`로 두 번 실제 실행**한다:
  - `hooks.json-command-resolves` / `-body` — `env -u PLUGIN_ROOT CLAUDE_PLUGIN_ROOT=<repo>`에서 rc=0 + 주입문에 픽스처 slug(`` `expand-check` ``)가 실제로 나오는지.
  - `hooks.json-command-decoy-immune` / `-body` — `PLUGIN_ROOT=<decoy>`를 함께 세워도 가로채이지 않는지. 가로채기는 훅 **둘 다**(SessionStart 잔여 통지 + 무인 주행이 의존하는 Stop)를 죽이므로 계약으로 못 박았다.
  - 이것이 `skills/fg-run/PLAN-FORMAT.md` 가드 **(e)**("DoD는 산출물의 *동작*을 재고, 대리 지표를 재지 않는다")를 테스트 층에 적용한 실례다 — 가드 (e)를 낳은 `#133` 사건(글롭 패턴 문자열은 존재했으나 Glob 도구로는 0개 매치)과 **같은 실패형**이며, 규칙이 규칙 밖으로 전파된 흔치 않은 사례다.
- **회고 조회는 접미 글롭이 아니라 정확 대조여야 한다(신규 회귀, 불가역 액션의 fail-open).** slug가 `promotion`인 작업이 **다른 작업의** `…-eval-promotion.md`로 회고 게이트를 통과해 **자기 회고 없이 봉인됐다**. `scripts/forge-done.test.sh` 절 (n)과 `scripts/forge-status.parity.test.sh` 픽스처 J가 양쪽 표면(봉인·리포팅)에서 이를 잠근다 — 같은 결함이 두 스크립트에 동형으로 있었기 때문이다. **접미 매칭은 짧은 slug가 긴 slug의 부분문자열일 때 조용히 틀린다**는 부류이고, 봉인은 불가역이라 fail-open의 대가가 크다.
- **STATUS가 기록하는 경로의 상대성도 단언한다(신규)**: `n3-retro-path-relative`·`n6-reviewed-path-relative`가 `retro: .forge/retro/…`·`reviewed: .forge/review.md` 형태를 대조한다 — forge 루트는 git 리포 안에서 절대로 해석되고 비-기본 브랜치 루트는 통째로 추적되므로(ADR-0011), 절대경로를 적으면 머신 경로가 커밋된다.
- **`forge-status` parity 픽스처는 각자 자기가 잠그는 회귀를 헤더 주석에 적는다(신규 idiom, H–L 5개).** 케이스 이름만으로는 "무엇이 틀렸었는지"가 사라지므로 픽스처마다 사건을 한 문단으로 남긴다 — **H**: 단계 판정이 `run.md` 존재가 아니라 `verified:`에 걸려야 한다(같은 화면에서 표는 `learn`, 다음 단계 기계는 fg-run을 가리켜 서로 모순했다). **I**: 파킹된 작업 중 `failed`만 fg-run으로 돌아가고 파킹된 `pending`은 fg-learn으로 간다(판별자는 "다음 단계를 누가 소유하나"). **J**: 위 회고 접미 글롭. **K**: STATUS 값은 대소문자·공백 무관하게 읽어야 한다(`Yes`·`N/A`·`yes(ok)`는 봉인 가능, `retro: Skipped`는 X로 렌더 — 종전 O로 렌더해 forge-done이 봉인을 거부하는 값과 어긋났다). **L**: `done/` 디렉터리명은 **형태로 분해**해야 하고 고정 오프셋(`${name:0:10}`/`${name:11}`, 레거시 `YYYY-MM-DD` 폭 가정)으로는 `260615-143022-new-task`가 Date `260615-143` / Task `22-new-task`로 깨진다. 다섯 개의 공통 주제는 하나다 — **표면이 파일 존재·문자열 폭 같은 대리 지표가 아니라 상태 계약을 읽어야 한다**(커밋 `9d9f8d2`).
- **`$fg-next` Codex 포인터 단언(신규)**: `scripts/forge-hook-session-start.test.sh`가 세션 시작 주입문에 Codex 호출 형식(`$fg-next`)이 들어 있는지 단언한다(케이스 `4-codex-pointer`) — Claude의 `/forge:fg-next`만 안내하면 Codex 사용자는 진입 명령을 못 찾는다.
- **repo-shaped 픽스처 idiom(신규, `scripts/release-check.parity.test.sh`)**: 다른 스크립트는 `.forge/` 상태만 조립하면 되지만 `release-check`는 **자기 위치에서 리포 루트를 역산**하므로(`dirname "$0"/..`), 픽스처가 **버리는 리포 하나**여야 한다 — `mkrepo()`가 임시 디렉터리에 `scripts/`·`.claude-plugin/`·`.codex-plugin/`·`hooks/`·`hosts/{claude,codex}/`를 만들고 **두 트윈을 그 `scripts/`로 복사한 뒤** 거기서 실행한다. env로 impl을 주입하는 다른 테스트들과 다른 방식이다(그래서 `release-check`는 `*_IMPL` env가 없다).
- **stderr·순서까지 대조하는 parity(신규)**: `assert_parity()`가 **stdout·stderr·exit code 세 개를 모두** 비교하고, "여러 위반, 같은 순서" 케이스(G)로 **에러 출력 순서**까지 계약에 넣는다. 다른 parity 테스트가 주로 stdout 중심인 데 비해 한 단계 엄격하다 — 위반이 stderr 한 줄씩 나가는 스크립트라 stderr가 곧 산출물이기 때문. anti-vacuous 가드도 유지된다(`set -euo pipefail` + 케이스별 sentinel 부분문자열).
- **impl 주입 env 이름은 스크립트별로 다르다**(고정 이름 하나가 아님): `FGDOCTOR_IMPL`·`FGDONE_IMPL`·`FGHOOK_IMPL`(session-start와 **stop이 공유**)·`FGLS_IMPL`(loop-spend)·`FGMERGE_IMPL`·`FGSL_FULL_IMPL`. 각 테스트 헤더 주석에 사용법이 적혀 있다. `release-check`는 예외로 env가 없다(위 repo-shaped 픽스처 idiom 때문).
- **부정 단언 헬퍼는 forge-doctor 하나만** `assert_nogrep`을 정의한다(`scripts/forge-doctor.test.sh`) — "발견되면 안 되는 finding"을 세는 용도.
- **ground-truth 교차 검산(신규 idiom, `scripts/forge-loop-spend.test.sh`)**: 기대 총량을 손으로 적지 않고 픽스처에서 `JSON.parse`로 **계산해** 비교한다. 손으로 적은 숫자는 작성자의 스키마 모델만큼만 맞고, 실제로 1.928배 과대 계상이 **11/11 parity green** 상태로 배포된 적이 있다(헤더 주석·ADR-0022 개정 2026-08-20). parity는 두 트윈이 *같이 틀린 것*을 못 잡는다는 한계의 실증.
- **Stop 훅 테스트는 안전 불변식 중심**: "모든 실패·모호 경로는 정지 허용(exit 0)이고 정지 차단(`exit 2`)은 marker 존재 + 두 상한(30분·50회) 이내 + 세션 일치인 한 경우뿐"을 케이스별로 확인한다(`scripts/forge-hook-stop.test.sh` 헤더) — 하네스 쪽 루프 보호가 없어 이 상한이 유일한 폭주 가드이기 때문.

## 4. grep 기반 검증 (테스트 스크립트 밖의 검증 층)

- **fg-loop 정지 체크**: `.forge/loop.md`의 체크는 "agent-runnable command + 기대 결과" 형태여야 하며 예시가 grep/test/build/JSON parse다(`skills/fg-loop/SKILL.md` L40·L70). 단 Goodhart 가드로 "grep 존재 확인"보다 행동/결과 단언을 요구(L72·L74).
- **fg-run UAT**: 핸드오프 전 plan 목표에 대고 검증해 STATUS `verified:`를 기록 — fg-loop 문서가 이를 "grep/test/build/JSON — same shapes as fg-run's aggressive UAT"로 지칭.
- **`**Explaining forge**` verbatim 검사**: fg-doctor **B17**이 canonical 본문(`scripts/explaining-forge.rule.txt`)을 22개 `skills/*/SKILL.md`에 대해 **containment**로 대조한다(`grep -qF -e "$rule"`). 마커만 대조하는 검사는 문단을 지우거나 뒤집은 파일을 통과시키므로 본문 대조가 요점이고, containment라서 fg-ask의 superset 변형이 예외 목록 없이 통과한다. severity warning, 스코프는 최상위 매니페스트 `name == forge`일 때만. 실측 **22/22 통과**. behavior 케이스 18개(`B17-{missing,canonical,superset,heading-only,truncated,altered,mention-only,scope,nested-name}-{rc,msg}`)가 `scripts/forge-doctor.test.sh`에, parity 케이스 5개(rule missing·scope guard·multiline name·nested name·canonical altered)가 `scripts/forge-doctor.parity.test.sh`에 있다.
- **산문 계약 정합 검사(신규 — fg-doctor `B18`, ADR `260907-140655`)**: B17이 *한 문단의 verbatim*을 지켰던 것을 넘어, **두 파일에 걸친 산문 계약의 정합**을 검사하는 첫 사례다. 일곱 갈래이고 전부 warning·`name == forge` 스코프:
  - **개수 자기검증 3개** — `skills/fg-next/HANDOFF.md`의 `**Applies (15)**`·`**Does NOT apply (7)**` 선언 숫자가 같은 절에서 백틱으로 열거된 고유 `fg-*` 스킬 수와 일치하는지, `.forge/CONTEXT.md`의 핸드오프 용어 개수가 Applies 열거와 일치하는지. **"선언한 숫자 = 열거한 개수" 형태로 계약을 쓰면 기계가 지킬 수 있다**는 것이 이 검사의 이식 가능한 교훈이다.
  - **fg-debug 계약 4개** — `skills/fg-debug/SKILL.md`가 활성 `verified: failed`를 fg-run의 기존 fix-and-re-run으로 되돌린다고 진술하는지(`active-failure route`), Phase 1 명령을 영속/일회성으로 분류하고 PLAN-FORMAT에 위임하며 **자동 eval 준수를 과대 진술하지 않는지**(`persistent eval`), 모든 종료 경로에서 임시 산출물 정리를 요구하는지(`cleanup`), 불확정 종료 경로를 정의하는지(`inconclusive route`).
  - 테스트: behavior 18개(`B18-{good,handoff,handoff-excluded,context,active,active-decoupled,eval,cleanup,loop}-{rc,msg}`), parity 9개(`B18 good`·`handoff mismatch`·`handoff excluded mismatch`·`context mismatch`·`active failure`·`active decoupled`·`persistent eval`·`cleanup`·`loop inconclusive`).
- **runnable DoD 규칙(`skills/fg-run/PLAN-FORMAT.md`)**: plan의 Definition of Done이 명명하는 명령은 **작성 시점(fg-ask)과 승격 시점(fg-run `DoD baseline`)에 실제로 한 번씩 돌려야** 한다. 가드가 **3개 → 5개**로 자랐다 — (a) `→ N` 정확한 개수는 슬라이스가 그 표면 전체를 소유할 때만 안전(아니면 기존 매치가 예산을 먹어 *작업 전에* 통과), (b) `→ 0` 금지 문자열은 plan 자신의 Non-goals와 교차 확인, (c) **부정 체크는 fail-open** — 깨진 명령도 `0`을 찍으므로 `0`은 "명령이 실제로 돈다"는 증거와 함께여야만 증거다. 신규 두 개:
  - **(d) DoD는 산출물을 검사하고, 산출물이 기대는 primitive를 검사하지 않는다.** 외부 도구 동작(git·훅·exit code·셸 빌트인)에 의존하는 계약을 쓸 때는 **그 동작을 한 번 재현**한다 — DoD가 7/7 초록인데 계약이 도구에 대한 거짓 가정 위에 서 있을 수 있다. 실측 `#131`: `git commit`이 "커밋할 것 없음"과 "훅이 거부함" **양쪽 모두 exit 1**이라 계약의 두 분기가 구분 불가였고, 어떤 DoD 항목도 요구하지 않은 일회성 repro만이 이를 잡았다. (c)의 거울상 — (c)는 DoD에 *있는* 비싼 명령을 면제하지 말라는 것이고, (d)는 그 primitive가 DoD에 *아예 없을* 수 있다는 것.
  - **(e) DoD는 산출물의 동작을 재고, 대리 지표를 재지 않는다 — 이 목록에서 가장 나쁜 실패형.** (a)–(d)는 시끄럽게 오작동하지만(불충족·이미충족·fail-open) **(e)만은 작업이 아직 깨진 상태로 초록을 보고한다**. 편집이 도입하는 *문자열*을 grep하는 체크는 "누군가 그것을 타이핑했다"만 단언한다. 그래서 어떤 도구가 소비하는 값(글롭 패턴·경로·매처·명령 문자열)을 슬라이스가 편집하면 DoD는 **그 도구가 해석하는 방식으로 해석해** 결과를 단언해야 한다. 실측 `#133` DoD 4: `grep -o '\.\./' skills/fg-help/SKILL.md | wc -l → >=1`이 1로 통과했으나 그 패턴이 정작 대상 Glob 도구로는 **0개** 파일에 매치했다 — 슬라이스의 목적 자체가 미달인데 모든 DoD가 초록이었다. **§3의 `hooks/run-hook.test.sh` 변경이 이 가드를 테스트 층에 적용한 실례다.**
- **fix-forward eval 규칙(신규, ADR `260906-171420` — `skills/fg-run/PLAN-FORMAT.md` 「Fix-forward eval rule」이 단일 정의)**: **새 plan 파일을 쓰는가**가 판정자다. `<!-- generated-by: fg-adversarial-review|fg-security|fg-debug|fg-loop -->` 계열은 하드 규칙 — 원래 실패가 기계 확인 가능하면 plan이 **영속 회귀 체크를 추가하는 슬라이스**를 포함하고 DoD가 그 체크의 **red → green**(수리 전 실패·수리 후 통과)을 증명해야 한다. **red 절반이 곧 위 runnable-DoD가 요구하는 작성 시점 실행**이라, 이 규칙은 면제가 아니라 그 실행이 *무엇을 보여야 하는지*를 명명한다. 이미 실행된 plan을 고치는 두 경로(fg-run fix-and-re-run·fg-loop 제자리 수리 `repaired-by`)는 **권고**뿐인데, 제자리 수리 계약이 marker-only·슬라이스 보존이라 "추가하라"와 "보존하라"가 충돌하기 때문이다(ADR 개정에서 정정된 실제 모순). fg-quick은 사정거리 밖.
  - **착지점**: 프로젝트 자신의 테스트 스위트. 스위트가 없는 리포는 **상응하는 실행 가능 착지점**(forge 자신에서는 fg-doctor 검사 — B17·B18이 그 선례)이고, 스위트가 아예 없으면 **첫 테스트를 만드는 것 자체가 유효한 착지점**이다("스위트가 없다"는 사유가 아니라 곧 그 작업이다).
  - **면제는 침묵이 아니라 산출물이어야 한다** — 기계 확인 불가면(시각 UAT, 또는 커밋되면 안 되는 것을 커밋해야 영속화되는 체크 — exploit 재현이 원형) `완료 정의(DoD)` 절 **안에** 사유 한 줄을 적는다(`retro: skipped (사유)`와 동형).
  - **강제의 공백을 계약이 스스로 적는다**: 슬라이스가 plan에 들어간 *뒤*로는 기존 검증 게이트(ADR-0009)가 다른 DoD 항목처럼 강제하지만, **슬라이스를 애초에 빠뜨린 plan을 잡는 기계는 없다**(게이트는 적힌 DoD를 읽을 뿐 적혔어야 할 DoD를 읽지 않는다). 수용된 공백이자 **장차 fg-doctor 검사 후보**이며, 그래서 면제가 적힌 한 줄이어야 한다. 원래 ADR의 "기존 게이트가 강제한다"는 과대 진술이라 `docs/state-contract.md` 쌍과 함께 정정됐다.
  - `skills/fg-learn/RETRO-FORMAT.md` L45가 승급 표의 네 번째 행으로 이를 담는다 — 승급 바 3조건은 **기계 확인 가능 · 재발 그럴듯(구조적 함정이지 일회성 실수가 아님) · 실행이 저렴(CI를 느리게 하지 않음)** 전부 충족.
- **frontmatter `description` 길이 린트의 함정(B16, 실제 회귀)**: B16 리더는 `sed -n 's/^description:[[:space:]]*//p' | head -1`로 **줄 단위**다. 5개 스킬의 `description`이 내용 변경 0으로 YAML folded scalar(`>-`)가 됐을 때 값이 `>-`(2자)로 읽혀 **600자 상한 검사가 조용히 통과**했다(fail-open). 전부 한 줄로 복원됐다. 길이는 **바이트가 아니라 코드포인트**(바이트 − UTF-8 continuation 바이트)로 세어 `.js` 트윈·`/fg` 메뉴 상한과 일치시킨다. **현재 이 린트가 잡는 것은 0건이다** — 종전 유일한 위반 `skills/fg-help/SKILL.md`(768자)가 커밋 `7d5623c`에서 해소돼 fg-doctor 전체가 클린해졌다(문서 머리말·§8). parity 케이스 `B16 desc length`·`B16 folded scalar` 둘이 이 회귀를 계속 잠근다.
- **배포 전제 검증**(`CLAUDE.md` 배포 규칙): `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json` + `.../main/.codex-plugin/plugin.json`으로 원격 버전 **4곳**, `awk '/^name:/'`로 `skills/*/SKILL.md` frontmatter `name` 누락 확인.

## 5. 매니페스트 검증 — 두 층

canonical 한 줄(`CLAUDE.md`, 이제 **3개 매니페스트**):

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json','.codex-plugin/plugin.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

같은 검사가 `scripts/forge-doctor.sh`/`.js`의 B9(JSON 유효성, error — **Codex 매니페스트가 있으면 그것까지 파싱**)·B8(버전 **4곳** 동기, error — `Claude=$pv metadata=$m1 marketplace=$m2 Codex=$cv`를 fix 힌트에 찍는다)로 상시화되어 있고, exit 0/1/2 계약 덕에 AI 없이 CI 게이트로 쓸 수 있다(`skills/fg-doctor/SKILL.md` "CI usage").

**둘째 층은 릴리스 게이트 `npm run release:check`**(= `scripts/release-check.{sh,js}`, 배포 절차 step 4에 편입되고 **이제 CI에서도 돈다** — §8). fg-doctor와 대상이 겹치지만(버전 4곳) 범위가 다르고, 네 갈래에서 **일곱 갈래로 확장**됐다: Codex 매니페스트의 `skills == "./skills/"`, `hooks/hooks.json` 존재, `hosts/{claude,codex}/{interaction,execution}.md`+`capabilities.json` 6파일 완비에 더해 — **capability 어휘 대조**(`core/HOST.md` 표를 파싱한 8키 vs 두 `capabilities.json`의 키 집합, missing·unknown 각각 별도 위반), **형태 검사**(불리언 평면 객체), **`docs/codex.md`·`docs/en/codex.md`가 8키를 모두 이름 짓는지**. 등급은 **error 하나뿐**(exit 0/1)이고 위반은 stderr 한 줄씩 고정 순서로 나온다. 버전 리더는 fg-doctor B8과 **같은 방식**(문서 순서대로 `"version"` 값 추출)이라 두 게이트가 어긋나지 않는다.

**이 게이트의 두 설계 선택이 테스트 관점에서 눈여겨볼 만하다:**

- **canonical을 파싱하고 하드코딩하지 않는다.** 어휘를 `grep -oE '^\| `[a-z_]+`' core/HOST.md | sed …`로 표에서 도출하며, 스크립트 주석이 이유를 자기가 적는다 — "That table is the single definition; a second copy in this script would be the very drift this check exists to prevent." 도출 실패(표 소멸)가 그 자체로 위반이다(`cannot derive the capability vocabulary from core/HOST.md`, parity 케이스 `HOST.md vocabulary gone`). fg-doctor B17이 `scripts/explaining-forge.rule.txt`를 읽는 것과 같은 계열 — **검사기는 규칙을 재진술하지 않고 규칙 파일을 읽는다.**
- **계약을 정규식이 표현할 수 있을 만큼 좁혀 bash 트윈을 node-free로 유지한다.** `capabilities.json` 검증에 JSON 파서를 들이지 않고, `tr -d ' \t\n\r'`로 압축한 뒤 `^\{("[a-z_]+":(true|false),)*"[a-z_]+":(true|false)\}$` 하나로 본다. 임의 JSON 파싱이 아니라 **"불리언 평면 객체"라는 좁은 계약의 검사**이고, 그래서 ADR-0022의 bash-primary가 살아 있으면서 `.js` 트윈과 정확히 같은 판정을 낸다(parity 케이스 `capabilities broken JSON`·`capabilities non-boolean`이 이를 확인).
- **게이트가 자기 사정거리를 과대 진술하지 않는다.** docs 검사는 **키 이름의 등장**만 보고 지원 등급 문구는 사람 리뷰로 남기며, 주석이 "this gate does not claim more than it checks"로 명시한다 — 위 fix-forward eval 규칙의 "강제의 공백을 정직하게 적는다"와 같은 규율이다.

## 6. 커버리지

커버리지 도구 없음(측정 불가·미측정). 사실상의 커버리지 정책은: 결정론 스크립트마다 behavior+parity 쌍(§2의 비대칭 3건 제외), 트윈 **존재** 자체는 fg-doctor B15가 정적 검사(warning, `scripts/*.sh`·`scripts/*.js` 전체를 훑고 `*.test.sh`·`*.parity.test.sh`·`*-wrapper.sh`만 제외 — `forge-` 접두가 없는 `release-check`도 대상).

**B15는 "파일이 두 개 있는지"만 보고 "구현이 두 개인지"는 못 본다.** `scripts/release-check.sh`는 처음 `exec node`로 js를 부르는 shim이었고 B15·parity 둘 다 통과했다 — parity는 같은 결과를 낼 수밖에 없고, B15는 존재만 세니까. node 없는 bash-only 환경이라는 ADR-0022의 목적이 통째로 무력화된 상태가 초록으로 보였다. 현재는 83줄의 실제 bash 구현이다. §3의 "parity는 두 트윈이 *같이 틀린 것*을 못 잡는다"의 사촌 실패 유형이고, 여기서는 **한쪽이 다른 쪽이었다**. 산문 스킬 층은 테스트 0 — 리포 변경의 다수가 이 무테스트 층에서 일어나고, 그 층의 유일한 기계 가드가 fg-doctor의 산문 드리프트 검사(B12/B13/B16/B17/**B18**)다.

**측정된 실제 parity 공백 하나 — fg-doctor `A9`가 `.js` 트윈에 아예 없다(이 지도 작성 중 실측 확인, 기존 상태).** `scripts/forge-doctor.sh`는 `A9 stale drive.md`/`A9 unparseable drive.md`를 warning으로 내지만 `scripts/forge-doctor.js`에는 `A9`도 `drive` 문자열도 **0건**이다(`grep -n 'drive' scripts/forge-doctor.js` → B16 fix 힌트의 "drives"만 매치). 직접 재현:

```bash
mkdir -p /tmp/a9probe/.forge && cd /tmp/a9probe
printf 'started: 1\nsession: x\ncount: 1\n' > .forge/drive.md
bash <repo>/scripts/forge-doctor.sh   # → 0 errors, 1 warnings  (A9 stale drive.md)
node <repo>/scripts/forge-doctor.js   # → 0 errors, 0 warnings
```

**22개 parity 케이스가 초록이고, 게다가 `FGDOCTOR_IMPL=.../forge-doctor.js bash scripts/forge-doctor.test.sh`가 78개 behavior 단언을 전부 통과한다** — 검사 하나가 통째로 없는 트윈이 양쪽 하네스를 모두 초록으로 통과한다는 뜻이다(실측). 원인은 단순하다: 어느 픽스처도 `drive.md`를 심지 않는다(`grep -c 'drive'`가 behavior·parity 테스트 양쪽에서 0). **baseline 커밋 `524c6a3`에서도 같은 상태였으므로 신규 회귀가 아니라 처음부터 있던 공백**이다. 교훈은 §3의 ground-truth 교차 검산·(e) 가드와 같은 계열이고 여기서 셋이 나란히 선다 — **B15는 파일 존재만 보고, parity는 픽스처가 닿는 코드 경로만 비교하고, behavior 테스트를 js에 재사용하는 idiom도 그 픽스처 집합을 물려받는다.** 세 가드가 모두 같은 맹점을 공유하므로 "트윈이 검증됐다"의 실제 사정거리는 **픽스처 집합의 사정거리와 정확히 같다**.

**테스트 하네스 밖의 검증 스크립트 1개**: `skills/fg-security/validate-findings.cjs`(201줄, zero-dependency Node, exit 0/1)가 `skills/fg-security/report-schema.json`(210줄)을 **런타임에 읽어** `findings.json`을 검증한다 — 스키마가 단일 정의이고 규칙 사본이 없다(스키마로 표현 못 하는 제약[trace가 `entrypoint`에서 시작해 `sink`로 끝나야 함]만 명시적 semantic 층으로 뒤에 붙음). `.test.sh` 하네스와 **다른 idiom**이고 vendoring된 원형이라 자체 테스트 파일이 없다.

## 7. 전체 실행 한 줄

전체 실행은 여전히 셸 루프뿐이다(테스트 러너 없음):

```bash
for f in scripts/*.test.sh hooks/run-hook.test.sh; do bash "$f" || echo "FAIL $f"; done
```

## 8. CI — 워크플로가 둘이 되고, 처음으로 테스트가 CI에서 돈다

`.github/workflows/`에 워크플로가 **둘**이다(하나 → 둘).

**① `docs.yml`(`name: Deploy docs site`)** — 종전과 같다. 트리거는 `main` push 중 `docs/**`·`package.json`·`package-lock.json`·`.github/workflows/docs.yml` 경로 변경 + `workflow_dispatch`. 잡은 둘(`build` → `deploy`)이고 `npm ci` → `npm run docs:build`(VitePress) → 아티팩트 조립 → GitHub Pages 배포. 조립 단계에 **`test -f` 다섯 줄의 산출물 존재 단언**이 있다(`_site/index.html`·`_site/docs/index.html`·`_site/docs/skills.html`·`_site/docs/examples/github-actions-forge-check.yml`·`_site/docs/icon.png`).

**② `release-check.yml`(`name: Release gate`, 신규)** — **이 리포에서 처음으로 CI가 테스트를 돌린다.** 잡 하나(`gate`)에 스텝 셋:

```yaml
- run: bash scripts/release-check.sh          # bash primary
- run: node scripts/release-check.js          # node twin
- run: bash scripts/release-check.parity.test.sh  # stdout·stderr·exit code·순서
```

주석이 배선 근거를 자기가 적는다 — **트윈 둘을 다 돌리는 이유**는 "CI is where a silent divergence between them would otherwise go unnoticed"이고, **`npm ci`가 없는 이유**는 게이트가 설계상 zero-dependency이기 때문이다. 트리거는 push·**pull_request 양쪽**이며 경로는 `.claude-plugin/**`·`.codex-plugin/**`·`core/**`·`hosts/**`·`hooks/**`·`scripts/release-check.*`·자기 자신·`docs/codex.md`·`docs/en/codex.md`.

**게이트를 `docs.yml`에 스텝으로 넣지 않은 이유도 워크플로 주석에 명문화되어 있다**: `docs.yml`은 `docs/**`·`package.json`에만 발동하므로 정작 지켜야 할 `.codex-plugin/`·`hosts/`·`core/` 변경에는 발동하지 않는 **fail-open 게이트**가 된다 — "A gate that looks wired but cannot fire is worse than no gate." 이 리포에서 반복되는 fail-open 주제(§3·§4의 부정 체크·대리 지표)가 **CI 배선 층에서 다시 나타난 사례**다.

**여전히 CI가 돌리지 않는 것(실측):**

- **21개 테스트 파일 중 1개만 CI에서 돈다** — `scripts/release-check.parity.test.sh` 하나이고, 나머지 20개(`forge-doctor`·`forge-done`·`forge-status`·`forge-merge`·훅 계열 전부)는 어떤 워크플로에서도 실행되지 않는다(`grep -rn 'test.sh' .github/workflows/` → 1건).
- **fg-doctor는 배선되지 않았다** — `grep -rn 'forge-doctor\|fg-doctor' .github/workflows/` → 0건. **다만 배선을 막던 근거가 사라졌다**: `CLAUDE.md`는 "현재 B16 warning 1건으로 exit 1이라 즉시 붉어진다"를 이유로 들지만 실측은 **0 errors / 0 warnings, exit 0**이다(문서 머리말). 즉 지금 배선하면 초록으로 통과한다 — `docs/examples/github-actions-forge-check.yml`이 그대로 쓸 수 있는 복사용 예시이고, 이 리포 자신만 아직 안 쓴다. **이 문서가 기록하는 가장 값싼 개선 후보다.**

로컬 수동 실행이 나머지 20개 파일의 유일한 경로다.

문서 사이트 빌드는 로컬에서도 검증 명령이다 — dead link가 있으면 실패한다(`node_modules/` 설치돼 있음):

```bash
npm run docs:build
```
