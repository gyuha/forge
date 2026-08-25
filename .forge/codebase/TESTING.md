---
last_mapped_commit: 182175fe02f832806c44148e7036d0dc26d7a55b
mapped: 2026-08-26
---

# TESTING

이 문서는 **구현 사실만** 다룬다. 아래 수치는 이 커밋의 작업 트리에서 2026-08-26에 **전체 테스트를 실제로 돌려** 얻은 값이다(macOS/darwin 25.5.0, **20개 파일 전부 rc=0**).

## 1. 프레임워크: 없음 — 순수 bash 스크립트 테스트

테스트 러너·프레임워크·의존성이 전혀 없다. 각 테스트는 자기완결 bash 스크립트로, 내부에 `assert()`/`assert_grep()` 헬퍼를 자체 정의하고 `pass`/`fail` 카운터를 세다가 실패가 있으면 exit 1 한다. 실행법은 파일 헤더 주석에 명시: `bash scripts/<name>.test.sh`.

테스트 대상은 산문 스킬이 아니라 **결정론 스크립트 층**(ADR-0022 트윈 10쌍)과 **훅 배선**뿐이다. 스킬(SKILL.md) 자체는 단위 테스트가 없고, 실동작 검증은 플러그인 설치 후 트리거해 보는 것뿐(`CLAUDE.md` 명시).

## 2. 테스트 파일 인벤토리 (20개, 전부 green)

두 종류가 있다 — **behavior 테스트**(`*.test.sh`, 픽스처 대비 단일 구현의 계약 검증)와 **parity 테스트**(`*.parity.test.sh`, 같은 픽스처에 `.sh`와 `.js`를 둘 다 돌려 출력 동일성 단언 — ADR-0022의 진짜 drift 가드).

| 파일 | 종류 | 2026-08-26 실행 결과 |
|---|---|---|
| `scripts/forge-doctor.test.sh` | behavior | 54 passed (36 → 54, B17 포함) |
| `scripts/forge-doctor.parity.test.sh` | parity | PARITY OK (6 → **11 케이스**) |
| `scripts/forge-done.test.sh` | behavior | 60 passed |
| `scripts/forge-done.parity.test.sh` | parity | PARITY OK |
| `scripts/forge-hook-session-start.test.sh` | behavior | 64 passed |
| `scripts/forge-hook-session-start.parity.test.sh` | parity | PARITY OK |
| `scripts/forge-hook-stop.test.sh` (신규) | behavior | 10 passed |
| `scripts/forge-hook-stop.parity.test.sh` (신규) | parity | all identical |
| `scripts/forge-loop-spend.test.sh` (신규) | behavior | 38 passed |
| `scripts/forge-loop-spend.parity.test.sh` (신규) | parity | all identical |
| `scripts/forge-merge.test.sh` | behavior | 58 passed |
| `scripts/forge-merge.parity.test.sh` | parity | PARITY OK |
| `scripts/forge-status.parity.test.sh` | parity | PARITY OK |
| `scripts/forge-statusline.test.sh` | behavior | 35 passed |
| `scripts/forge-statusline.parity.test.sh` | parity | PARITY OK |
| `scripts/forge-statusline-full.test.sh` | behavior | 34 passed |
| `scripts/forge-statusline-full.parity.test.sh` | parity | PARITY OK |
| `scripts/forge-statusline-wrapper.test.sh` | behavior | 7 passed |
| `scripts/resolve-forge-root.parity.test.sh` | parity | PARITY OK |
| `hooks/run-hook.test.sh` | behavior(배선) | 22 passed |

비대칭 주의: `forge-status`와 `resolve-forge-root`는 **parity 테스트만** 있고 단독 behavior 테스트 파일이 없다(parity의 populated 케이스가 sentinel 검사로 일부 behavior를 겸함).

## 3. 구조·패턴

- **픽스처 = mktemp 디렉터리에 `.forge/` 상태를 손으로 조립.** 예: `scripts/forge-doctor.test.sh`가 `mktmp()`로 임시 디렉터리를 만들고 `seed_status()`로 STATUS.md를 심은 뒤 `run_doc`으로 실행, `assert "A1-rc2" 2 "$RC"` + `assert_grep "A1-msg" "$OUT" "A1 active-slot orphan"`으로 **exit code(0/1/2 severity 계약)와 메시지 문자열**을 동시에 단언한다.
- **mocking 없음.** 실제 파일시스템(임시 디렉터리)과 실제 bash/node 실행뿐이다. 외부 네트워크·git 원격 의존 없음(forge-merge 코어는 git 자체를 안 건드림 — ADR-0011 CI git-free).
- **behavior 테스트를 js 트윈에 재사용**: 구현 경로를 env로 주입 — `FGDOCTOR_IMPL=.../forge-doctor.js bash scripts/forge-doctor.test.sh`(파일 헤더 명시), `run_doc()`이 `*.js`면 node로 분기. statusline-full도 같은 패턴(`impl:` 표기가 결과 줄에 나옴).
- **parity 테스트의 anti-vacuous 가드**: `scripts/forge-status.parity.test.sh`는 `set -euo pipefail`로 픽스처 조립 실패 시 abort하고, populated 케이스에 sentinel 부분문자열 존재를 단언해 "둘 다 빈 출력이라 동일" 같은 헛통과를 막는다(파일 헤더 주석에 근거 명시).
- **훅 배선 테스트**: `hooks/run-hook.test.sh`는 `hooks.json`의 JSON 유효성 + command/matcher 계약 필드 + `run-hook.cmd` 디스패치를 검사한다 — "hooks.json 오타는 어디서도 에러 없이 훅을 조용히 끈다"는 위험을 겨냥(헤더 주석).
- **impl 주입 env 이름은 스크립트별로 다르다**(고정 이름 하나가 아님): `FGDOCTOR_IMPL`·`FGDONE_IMPL`·`FGHOOK_IMPL`(session-start와 **stop이 공유**)·`FGLS_IMPL`(loop-spend)·`FGMERGE_IMPL`·`FGSL_FULL_IMPL`. 각 테스트 헤더 주석에 사용법이 적혀 있다.
- **부정 단언 헬퍼는 forge-doctor 하나만** `assert_nogrep`을 정의한다(`scripts/forge-doctor.test.sh`) — "발견되면 안 되는 finding"을 세는 용도.
- **ground-truth 교차 검산(신규 idiom, `scripts/forge-loop-spend.test.sh`)**: 기대 총량을 손으로 적지 않고 픽스처에서 `JSON.parse`로 **계산해** 비교한다. 손으로 적은 숫자는 작성자의 스키마 모델만큼만 맞고, 실제로 1.928배 과대 계상이 **11/11 parity green** 상태로 배포된 적이 있다(헤더 주석·ADR-0022 개정 2026-08-20). parity는 두 트윈이 *같이 틀린 것*을 못 잡는다는 한계의 실증.
- **Stop 훅 테스트는 안전 불변식 중심**: "모든 실패·모호 경로는 정지 허용(exit 0)이고 정지 차단(`exit 2`)은 marker 존재 + 두 상한(30분·50회) 이내 + 세션 일치인 한 경우뿐"을 케이스별로 확인한다(`scripts/forge-hook-stop.test.sh` 헤더) — 하네스 쪽 루프 보호가 없어 이 상한이 유일한 폭주 가드이기 때문.

## 4. grep 기반 검증 (테스트 스크립트 밖의 검증 층)

- **fg-loop 정지 체크**: `.forge/loop.md`의 체크는 "agent-runnable command + 기대 결과" 형태여야 하며 예시가 grep/test/build/JSON parse다(`skills/fg-loop/SKILL.md` L40·L70). 단 Goodhart 가드로 "grep 존재 확인"보다 행동/결과 단언을 요구(L72·L74).
- **fg-run UAT**: 핸드오프 전 plan 목표에 대고 검증해 STATUS `verified:`를 기록 — fg-loop 문서가 이를 "grep/test/build/JSON — same shapes as fg-run's aggressive UAT"로 지칭.
- **`**Explaining forge**` verbatim 검사(신규)**: fg-doctor **B17**이 canonical 본문(`scripts/explaining-forge.rule.txt`)을 22개 `skills/*/SKILL.md`에 대해 **containment**로 대조한다(`grep -qF -e "$rule"`). 마커만 대조하는 검사는 문단을 지우거나 뒤집은 파일을 통과시키므로 본문 대조가 요점이고, containment라서 fg-ask의 superset 변형이 예외 목록 없이 통과한다. severity warning, 스코프는 최상위 매니페스트 `name == forge`일 때만. behavior 케이스(missing·canonical·superset·heading-only·truncated·altered 등)가 `scripts/forge-doctor.test.sh`에, parity 케이스 5개(rule missing·scope guard·multiline name·nested name·canonical altered)가 `scripts/forge-doctor.parity.test.sh`에 있다.
- **runnable DoD 규칙(신규, `skills/fg-run/PLAN-FORMAT.md` L43)**: plan의 Definition of Done이 명명하는 명령은 **작성 시점(fg-ask)과 승격 시점(fg-run `DoD baseline`)에 실제로 한 번씩 돌려야** 한다. 세 가드 — (a) `→ N` 정확한 개수는 슬라이스가 그 표면 전체를 소유할 때만 안전(아니면 기존 매치가 예산을 먹어 *작업 전에* 통과), (b) `→ 0` 금지 문자열은 plan 자신의 Non-goals와 교차 확인, (c) **부정 체크는 fail-open** — 깨진 명령도 `0`을 찍으므로 `0`은 "명령이 실제로 돈다"는 증거와 함께여야만 증거다. 실측 사례 `#116` C6·`#120` DoD 4·6.
- **배포 전제 검증**(`CLAUDE.md` 배포 규칙): `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`으로 원격 버전 3곳, `awk '/^name:/'`로 `skills/*/SKILL.md` frontmatter `name` 누락 확인.

## 5. 매니페스트 JSON 검증

canonical 한 줄(`CLAUDE.md`):

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

같은 검사가 `scripts/forge-doctor.sh`/`.js`의 B9(JSON 유효성, error)·B8(버전 3곳 동기, error)로 상시화되어 있고, exit 0/1/2 계약 덕에 AI 없이 CI 게이트로 쓸 수 있다(`skills/fg-doctor/SKILL.md` "CI usage").

## 6. 커버리지

커버리지 도구 없음(측정 불가·미측정). 사실상의 커버리지 정책은: 결정론 스크립트마다 behavior+parity 쌍(§2의 비대칭 2건 제외 — 신규 트윈 2쌍은 둘 다 완비), 트윈 존재 자체는 fg-doctor B15가 정적 검사(warning, `*.test.sh`·`*.parity.test.sh`·`*-wrapper.sh` 제외). 산문 스킬 층은 테스트 0 — 리포 변경의 다수가 이 무테스트 층에서 일어나고, 그 층의 유일한 기계 가드가 fg-doctor의 산문 드리프트 검사(B12/B13/B16/B17)다.

**테스트 하네스 밖의 검증 스크립트 1개**: `skills/fg-security/validate-findings.cjs`(201줄, zero-dependency Node, exit 0/1)가 `skills/fg-security/report-schema.json`(210줄)을 **런타임에 읽어** `findings.json`을 검증한다 — 스키마가 단일 정의이고 규칙 사본이 없다(스키마로 표현 못 하는 제약[trace가 `entrypoint`에서 시작해 `sink`로 끝나야 함]만 명시적 semantic 층으로 뒤에 붙음). `.test.sh` 하네스와 **다른 idiom**이고 vendoring된 원형이라 자체 테스트 파일이 없다.

## 7. 전체 실행 한 줄

전체 실행은 여전히 셸 루프뿐이다(테스트 러너 없음):

```bash
for f in scripts/*.test.sh hooks/run-hook.test.sh; do bash "$f" || echo "FAIL $f"; done
```

## 8. CI — 존재하지만 테스트를 돌리지 않는다

`.github/workflows/`에 워크플로가 **하나** 있다: `docs.yml`(`name: Deploy docs site`). 트리거는 `main` push 중 `docs/**`·`package.json`·`package-lock.json`·`.github/workflows/docs.yml` 경로 변경 + `workflow_dispatch`. 잡은 둘(`build` → `deploy`)이고 하는 일은 `npm ci` → `npm run docs:build`(VitePress) → 아티팩트 조립 → GitHub Pages 배포다. 조립 단계에 **`test -f` 다섯 줄의 산출물 존재 단언**이 있다(`_site/index.html`·`_site/docs/index.html`·`_site/docs/skills.html`·`_site/docs/examples/github-actions-forge-check.yml`·`_site/docs/icon.png`) — 이 리포에서 CI가 수행하는 검증의 전부다.

**즉 `scripts/*.test.sh`·`hooks/run-hook.test.sh`는 어떤 워크플로에서도 실행되지 않는다**(실측: `docs.yml`에 `bash scripts/` 호출 없음). 로컬 수동 실행이 유일한 경로다. 단 fg-doctor는 exit 0/1/2 계약 덕에 AI 없이 CI 게이트로 **쓸 수 있고**(`docs/examples/github-actions-forge-check.yml`이 그 복사용 예시), 이 리포 자신은 아직 그렇게 쓰지 않는다.

문서 사이트 빌드는 로컬에서도 검증 명령이다 — dead link가 있으면 실패한다(`node_modules/` 설치돼 있음):

```bash
npm run docs:build
```
