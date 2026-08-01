---
last_mapped_commit: bb54e27763aca86558ca45a965c9f8ede394018c
mapped: 2026-08-01
---

# TESTING

이 문서는 **구현 사실만** 다룬다. 도메인 용어 정의는 `.forge/CONTEXT.md` 소관이다. 아래 모든 수치는 이 커밋의 작업 트리에서 테스트를 **실제로 돌려** 얻은 값이다(2026-08-01, macOS/darwin 25.5.0 — 16개 파일 전부 green, `.js` 트윈 5개도 전부 green, `forge-doctor.sh`/`.js` 0 findings).

## 1. 프레임워크 — 없다

테스트 프레임워크·러너·설정 파일이 **하나도 없다.** `package.json`·`Makefile`·`.github/` 전부 부재(확인: 셋 다 No such file). 테스트는 그냥 **`bash`가 실행하는 자기완결 셸 스크립트**다. `.test.js`는 **0개** — `.js` 트윈도 같은 `.sh` 테스트 파일로 검증한다(§4).

각 테스트 파일은 다음을 스스로 갖는다:

- `#!/usr/bin/env bash` shebang + `set -u`(일부 parity는 `set -euo pipefail`, §5)
- 자체 카운터 `pass=0; fail=0`(behavior) 또는 `fails=0`(parity)
- 자체 assert 헬퍼 2~5개 (`assert`·`assert_grep`·`assert_ngrep`·`assert_file`·`assert_nofile`·`assert_bounded` / parity는 `check` 또는 `assert_parity`)
- 자체 `mktmp()` 임시 디렉터리 팩토리 + fixture seed 함수
- 자체 러너 래퍼 (`run_done`·`run_doc`·`run_merge`·`run_hook`·`run_in`·`run_in_env`·`run_in_json`·`run_full`·`run_wrapper`)
- 끝에 요약 출력 + 비-0 종료: behavior는 `N passed, M failed` + `[ "$fail" -eq 0 ]`, parity는 `... PARITY OK` / `... PARITY FAILED (N)`

의존성은 bash + coreutils(`sed`/`awk`/`grep`/`diff`/`mktemp`/`wc`/`tr`) + `git` + `node`(트윈 실행·JSON 파싱)뿐이다. `node`가 없으면 그것을 요구하는 케이스는 `SKIP`으로 정직하게 빠진다(§7).

### 실행법

```bash
# 하나만
bash scripts/forge-done.test.sh
bash hooks/run-hook.test.sh

# 전부 (러너가 없으므로 셸 루프로 돈다)
for f in $(find . -name "*.test.sh" -not -path "./.git/*" | sort); do
  echo "=== $f ==="; bash "$f" || echo "FAILED: $f"
done

# .js 트윈을 같은 behavior 테스트로 (§4)
FGDONE_IMPL=$PWD/scripts/forge-done.js bash scripts/forge-done.test.sh

# 상태·문서 무결성 검사 (테스트와 별개, 읽기 전용)
bash scripts/forge-doctor.sh   # 0 clean · 1 warnings · 2 errors
```

`hooks/run-hook.test.sh`가 `hooks/`에 있는 유일한 테스트고 나머지 15개는 `scripts/`에 있다.

---

## 2. 테스트 인벤토리 (실측)

한 스크립트 트윈에 **두 종류**의 테스트가 붙는다: `X.test.sh`(behavior)와 `X.parity.test.sh`(패리티). 총 **16개 파일, 2,561줄** — behavior 8개(1,681줄) + parity 8개(880줄).

### Behavior 테스트 — 8개, 합계 316 assertion (전부 pass)

| 파일 | 통과 assertion | 줄 | env 오버라이드 |
| --- | --- | --- | --- |
| `scripts/forge-hook-session-start.test.sh` | 64 | 399 | `FGHOOK_IMPL` |
| `scripts/forge-done.test.sh` | 60 | 254 | `FGDONE_IMPL` |
| `scripts/forge-merge.test.sh` | 58 | 155 | `FGMERGE_IMPL` |
| `scripts/forge-doctor.test.sh` | 36 | 88 | `FGDOCTOR_IMPL` |
| `scripts/forge-statusline.test.sh` | 35 | 248 | **없음** (`:19`에서 `.sh` 하드코딩) |
| `scripts/forge-statusline-full.test.sh` | 34 | 311 | `FGSL_FULL_IMPL` |
| `hooks/run-hook.test.sh` | 22 | 113 | **없음**(래퍼 자체가 디스패처라 불필요) |
| `scripts/forge-statusline-wrapper.test.sh` | 7 | 113 | **없음**(`.js` 트윈이 없음) |

**assertion 밀도가 파일 길이와 반비례하는 게 특징이다** — `forge-merge.test.sh`는 155줄에 58 assertion(줄당 0.37), `forge-doctor.test.sh`는 88줄에 36(0.41)으로 한 줄에 fixture 생성 + 실행 + 다중 단언 + `rm -rf`를 몰아 담는다(`scripts/forge-doctor.test.sh:27`이 대표형: `t=$(mktmp); mkdir -p ...; printf ... ; run_doc "$t"; assert "A1-rc2" 2 "$RC"; assert_grep "A1-msg" "$OUT" "A1 active-slot orphan"; rm -rf "$t"`). 반면 statusline 계열은 기대 문자열을 한 줄씩 적어 늘어난다.

훅 테스트가 최다인 것은 세션 시작 훅이 **리포 텍스트를 에이전트 컨텍스트에 주입**하는 유일한 스크립트라 적대적 입력 케이스(§5.8)가 붙었기 때문이다 — 케이스 `(12)`~`(19)`가 그 증분이며 파일 후반 절반(`:212-398`)을 차지한다.

### Parity 테스트 — 8개, 합계 94 케이스 (전부 ok)

| 파일 | 케이스 | 줄 | 비교 축 |
| --- | --- | --- | --- |
| `scripts/forge-hook-session-start.parity.test.sh` | 18 | 188 | stdout + rc + sentinel |
| `scripts/forge-merge.parity.test.sh` | 17 | 74 | 파일 트리(`diff -r`) + rc |
| `scripts/forge-done.parity.test.sh` | 14 | 84 | 파일 트리(`diff -r`) + rc |
| `scripts/forge-statusline.parity.test.sh` | 14 | 126 | stdout(ANSI strip) + 기대값 |
| `scripts/forge-statusline-full.parity.test.sh` | 10 | 126 | stdout(ANSI strip) |
| `scripts/forge-status.parity.test.sh` | 9 | 159 | stdout + sentinel (full/`--table` 두 모드) |
| `scripts/forge-doctor.parity.test.sh` | 6 | 55 | stdout + rc (경로 정규화) |
| `scripts/resolve-forge-root.parity.test.sh` | 6 | 68 | stdout + **기대 경로값** |

케이스 이름은 파일마다 규약이 다르다 — hook parity는 알파벳 레터(`A`~`N`), status parity는 `Fixture A`~`G`, 나머지는 서술형 문자열이다.

### 커버리지 구멍 (실측)

- **`scripts/forge-status.sh` — behavior 테스트가 없다.** parity만 있다. 즉 sh와 js가 *똑같이 틀린* 출력을 내면 아무도 잡지 못한다. `.claude/agents/script-twin-engineer.md`가 이 구멍을 이름까지 대고 규율로 적어 뒀다 — *"패리티 ≠ 정확성. 양 트윈이 똑같이 틀리면(both-wrong) 패리티는 통과하며 버그를 숨긴다(forge-status가 그랬다). 그러니 동작 테스트가 값을 단언해야 한다 — 패리티만 있는 스크립트에 로직을 더하면 값-단언 behavior 테스트를 함께 추가한다."*
- **`scripts/resolve-forge-root.sh` — behavior 테스트가 없다.** parity만 있다. 단 이 parity는 `check <desc> <workdir> <expected>` 시그니처로 **기대 경로값까지 단언**하고 출력에 찍으므로(`scripts/resolve-forge-root.parity.test.sh:19-30`) 사실상 behavior 겸용이다 — 헤더가 자칭한다(*"Parity + correctness test"*). 6케이스: 비-git 디렉터리 → `.forge`, 기본 브랜치 `main` → `<top>/.forge`, 비기본 `feature` → `<top>/.forge/branch/feature`, 중첩 `feature/x`, `config.json` `defaultBranch=trunk`인데 `main`에 있음 → `<top>/.forge/branch/main`, git 리포 하위 디렉터리 → `<top>/.forge`.
- **`scripts/forge-statusline-wrapper.sh` — parity 테스트가 없다.** bash 전용 래퍼라 `.js` 트윈 자체가 없다(ADR-0022의 명시적 예외, fg-doctor B15 제외 패턴에 등재).
- **`scripts/forge-statusline.test.sh`에 `_IMPL` 오버라이드가 없다**(`:19`에서 `.sh` 경로를 하드코딩). 따라서 `forge-statusline.js`는 **parity로만** 검증되고 35개 behavior assertion을 직접 통과하지는 않는다. 같은 계열의 `-full` 쪽은 `FGSL_FULL_IMPL`이 있어 이 비대칭이 존재한다.
- **CI가 없다.** `forge-doctor.sh`·`forge-merge.sh`는 exit-code 계약으로 "AI 없이 CI 게이트 가능"하도록 설계됐고 SKILL.md에 CI usage 절까지 있지만(`skills/fg-doctor/SKILL.md:51-53`, `skills/fg-merge/SKILL.md:16,19,40`), 이 리포에 실제로 그걸 돌리는 워크플로는 없다(`.github/` 부재). 테스트 실행은 전적으로 수동이다.
- **스킬 산문(`skills/*/SKILL.md`)에 대한 테스트는 없다.** 산문 정합은 `forge-doctor`의 B10/B12/B13/B16 lint가 대신하고, 그 lint가 보는 것은 `name:` 존재·`CLAUDE.md` 등재·README 스킬-행 개수·description 길이뿐이다.
- **산문-only 계약에는 테스트가 원리적으로 없다** — §9.

---

## 3. 왜 parity가 따로 존재하는가

**behavior 테스트의 느슨한 단언이 놓치는 버그를 독립 구현 교차검증이 잡기 때문이다.** 이건 추측이 아니라 이 리포에 기록된 실측 사건 두 건이다.

### 사건 1 — B8 버전 드리프트 오추출

`.forge/retro/2026-07-16-forge-doctor-script-extract.md:9`:

> **B8 버그**: behavior 테스트가 "drift finding이 떴다"만 assert하고 *어느 버전 번호인지*는 안 봐서 통과했는데, parity(`.sh`↔`.js` 출력 정확 비교)가 불일치를 잡았다.

원인은 `.sh`의 `jver`가 단일라인 JSON에서 다중 `"version"`을 오추출한 것. 같은 라운드에 B9 `[ -f ]` 가드 누락도 함께 잡혔다. 회고가 뽑은 교훈 두 개가 그대로 규율이 됐다(§6 규율 1) — (1) dual-dispatch 스크립트는 parity가 필수 안전망, (2) behavior fixture는 "finding이 발생했다"가 아니라 **구체적 출력 내용**을 단언해야 한다. 수정의 흔적이 현재 코드에 남아 있다 — `scripts/forge-doctor.sh:104` 주석: *"extract every "version": "X" value in document order (handles multi-per-line JSON)."*

### 사건 2 — 200KB 값 (런타임 I/O 차이는 behavior로 안 보인다)

`scripts/forge-hook-session-start.parity.test.sh:141-149`(케이스 L)의 주석이 측정치를 남겼다: `.sh`는 200,350바이트를 닫는 태그까지 전부 냈는데 `.js`는 **정확히 65,536바이트**(파이프 버퍼)만 내고 잘렸다 — 쓰기 직후 `process.exit(0)`가 비동기 stdout을 끊은 것. 두 구현이 같은 로직을 담고 있어도 **런타임 I/O 모델이 다르면 출력이 갈리며**, 이건 한쪽만 돌리는 behavior 테스트로는 원리적으로 안 보인다(`.sh`만 보면 정상, `.js`만 보면 "긴 값은 잘리는 게 맞나?" 싶다). 패리티가 두 값을 나란히 놓아 잡았다. 수정은 `.sh`↔`.js` 규약이 됐다(`CONVENTIONS.md` §4.11 — 쓰기 뒤 exit 금지).

ADR-0022가 같은 판단을 설계 시점에 적어 뒀다: *"drift 관리 ... **같은 fixture에 두 구현을 돌려 출력 동일성을 단언하는 패리티 테스트**가 진짜 동치 가드다(존재 검사보다 강력)."* fg-doctor의 B15(`.js` 트윈 존재 여부)는 정적인 절반일 뿐이다.

### parity가 무엇을 비교하는가 — 스크립트 성격에 따라 셋으로 갈린다

**(a) 읽기 전용 — 같은 fixture에서 둘 다 돌려 stdout + rc 비교** (`forge-doctor`·`forge-status`·`forge-hook-session-start`·`resolve-forge-root`)

```
# scripts/forge-doctor.parity.test.sh:18-19
O_SH="$( cd "$D" && bash "$SH" 2>&1 )"; rc_sh=$?
O_JS="$( cd "$D" && node "$JS" 2>&1 )"; rc_js=$?
```

디렉터리를 하나만 만들어 순차로 돌린다(아무것도 안 쓰므로 안전). hook parity는 여기에 **rc가 둘 다 0인지**를 별도 단언으로 추가한다 — `scripts/forge-hook-session-start.parity.test.sh:29-32`: *"a hook must always exit 0."*

**(b) 파괴적 — fixture를 두 벌 만들어 각각 돌리고 결과 트리를 `diff -r`** (`forge-done`·`forge-merge`)

```
# scripts/forge-done.parity.test.sh:25-41 (요지)
A=$(mktmp); B=$(mktmp); "$seedfn" "$A"; "$seedfn" "$B"
( cd "$A" && bash "$SH" "$@" ) >/dev/null 2>&1; rc_sh=$?
( cd "$B" && node "$JS" "$@" ) >/dev/null 2>&1; rc_js=$?
[ "$rc_sh" = "$rc_js" ] || FAIL
diff -r "$A/.forge" "$B/.forge" >/dev/null 2>&1 || FAIL   # 실패 시 diff 앞 20줄 출력
```

헤더가 이유를 적는다 — 이 프리미티브는 파일을 **옮기므로** stdout이 아니라 **파일 시스템 결과**(STATUS 마감 내용 + 아카이브 레이아웃 + 무엇이 이동/삭제됐는지)로 패리티를 본다. seed 함수를 **함수 이름으로 넘겨** 같은 fixture를 두 디렉터리에 두 번 심는 게 이 축의 핵심 관용구다.

**(c) 표시용 — stdout을 ANSI strip 후 비교, 시각은 주입** (`forge-statusline`·`forge-statusline-full`)

### 정규화(normalization) — 우주적 차이만 흡수한다

두 구현의 **의미 없는 차이**만 지우고, 의미 있는 차이는 절대 지우지 않는다.

- `scripts/forge-doctor.parity.test.sh:12-14` — bash 문자열 조립 vs node `path.join` 차이만 흡수(`norm() { printf '%s' "$1" | sed -e 's#\./##g' -e 's#//*#/#g'; }`). 주석이 경계를 명시한다 — *"Findings/severity/exit are what parity actually checks."*
- `scripts/forge-status.parity.test.sh:18` / `forge-hook-session-start.parity.test.sh:18` — 둘 다 `norm() { sed -e 's/[[:space:]]*$//'; }`, 행 끝 공백만 제거.
- statusline 계열 — `strip_ansi() { sed -E $'s/\x1b\\[[0-9;]*m//g'; }`로 ANSI 색코드만 제거. `scripts/forge-statusline.test.sh:4-5` 주석: 정확한 색은 live-tuned 구현 세부(ADR-0017)이고 **pct 텍스트·바 채움·이모지·라벨이 단언 대상 정보를 담는다.**

### 출력 형식

parity 테스트는 케이스마다 `ok   - <설명>` / `FAIL - <설명>`을 찍고 끝에 `... PARITY OK` 또는 `... PARITY FAILED (N)`을 낸 뒤 0/1로 종료한다. 불일치 시 `diff <(printf ...) <(printf ...)`로 실제 차이까지 출력한다(`forge-status.parity.test.sh:26-27`). behavior 테스트는 실패만 `FAIL <name> expected/actual` 3줄 형식으로 찍고 끝에 `N passed, M failed`를 낸다.

---

## 4. env 오버라이드 패턴 — 한 behavior 파일로 두 트윈을 검증

behavior 테스트 파일은 `<PREFIX>_IMPL` 환경변수로 대상 구현을 갈아끼운다. 확장자를 보고 러너(`bash` vs `node`)를 고른다.

```
# scripts/forge-done.test.sh:23
SCRIPT="${FGDONE_IMPL:-$(cd "$(dirname "$0")" && pwd)/forge-done.sh}"

# scripts/forge-done.test.sh:36-42
run_done() {
  local wd="$1"; shift
  case "$SCRIPT" in
    *.js) OUT="$( cd "$wd" && node "$SCRIPT" "$@" 2>&1 )"; RC=$? ;;
    *)    OUT="$( cd "$wd" && bash "$SCRIPT" "$@" 2>&1 )"; RC=$? ;;
  esac
}
```

**실측 변수명 5개 전부:**

| 변수 | 테스트 파일 | 정의 위치 |
| --- | --- | --- |
| `FGDOCTOR_IMPL` | `scripts/forge-doctor.test.sh` | `:10` |
| `FGMERGE_IMPL` | `scripts/forge-merge.test.sh` | `:13` |
| `FGDONE_IMPL` | `scripts/forge-done.test.sh` | `:23` |
| `FGSL_FULL_IMPL` | `scripts/forge-statusline-full.test.sh` | `:24` |
| `FGHOOK_IMPL` | `scripts/forge-hook-session-start.test.sh` | `:27` |

`FGSL_FULL_IMPL`만 상대경로도 받아 절대경로로 정규화한다(`scripts/forge-statusline-full.test.sh:25`: `case "$IMPL" in /*) : ;; *) IMPL="$(cd "$(dirname "$IMPL")" && pwd)/$(basename "$IMPL")" ;; esac`) — 나머지는 절대경로를 요구한다(`forge-hook-session-start.test.sh:23` 주석이 `/abs/path/`를 명시).

`.js` 트윈을 같은 테스트로 돌린 실측 결과(전부 green):

```
FGHOOK_IMPL=$PWD/scripts/forge-hook-session-start.js  → forge-hook-session-start.js: 64 passed, 0 failed
FGDOCTOR_IMPL=$PWD/scripts/forge-doctor.js            → forge-doctor: 36 passed, 0 failed
FGDONE_IMPL=$PWD/scripts/forge-done.js                → 60 passed, 0 failed
FGMERGE_IMPL=$PWD/scripts/forge-merge.js              → forge-merge: 58 passed, 0 failed
FGSL_FULL_IMPL=$PWD/scripts/forge-statusline-full.js  → 34 passed, 0 failed  (impl: forge-statusline-full.js)
```

두 파일은 요약 줄에 어떤 구현으로 돌렸는지 남긴다 — `-full`은 `(impl: <basename>)`(`scripts/forge-statusline-full.test.sh` 마지막 줄이 `basename "$IMPL"`을 찍음), hook은 요약 접두에 `forge-hook-session-start.js:`를 붙인다. 오버라이드가 실제로 먹었는지 눈으로 확인되게 하는 장치다. `forge-done.test.sh`는 이 표기가 없어(그냥 `60 passed`) 어느 구현이 돌았는지 출력만으로는 분간이 안 된다.

이 패턴은 ADR-0031이 스크립트 사용 시 **필수 조건 2**로 못 박은 것이다: *"behavior 테스트: fixture 기반 `*.test.sh`. `.js` 트윈도 같은 테스트로 green(예: `FGDONE_IMPL`/`FGSL_FULL_IMPL` 인자 오버라이드)."*

---

## 5. Fixture 스타일

### 5.1 기본형 — `mktemp -d` 일회용 디렉터리 + 합성 `.forge/` 트리 + cwd 전환

모든 테스트가 같은 형태다: 임시 디렉터리를 만들고, 그 안에 `.forge/` 상태를 `printf`로 심고, **그 디렉터리를 cwd로 삼아** 스크립트를 서브셸에서 돌리고, stdout/rc/파일 트리를 단언하고, `rm -rf`로 지운다.

```
t=$(mktmp); mkdir -p "$t/.forge"
printf '<!-- forge-slug: %s -->\n<!-- task: %s -->\n# %s\n' ... > "$t/.forge/plan.md"
printf 'run notes\n' > "$t/.forge/run.md"
printf '# STATUS — t\nslug: %s\nstatus: %s\nexecuted: 2026-07-20\nverified: %s\nretro: %s\n' ... > "$t/.forge/STATUS.md"
run_done "$t" --completed 2026-07-05 --sealed-id "$SID"
assert "a-empty-rc2" 2 "$RC"
rm -rf "$t"
```

`mktemp` 접두는 테스트마다 다르게 붙여 잔여물을 구분할 수 있게 한다 — **실측 11종**: `fgdoc.`(doctor behavior)·`fgdocp.`(doctor parity)·`fgdone.`·`fgdonep.`·`fghook.`·`fgmerge.`·`fgmergep.`·`fgsl.`·`fgslfull.`·`fgslw.`·`fgwrap.`(run-hook). 전부 `${TMPDIR:-/tmp}/<접두>XXXXXX` 형태다. 접두를 안 붙이는 예외는 `set -euo pipefail` 계열 parity 3개(`forge-hook-session-start`·`forge-status`·`resolve-forge-root`)로, 이들은 맨 `mktemp -d`를 쓴다.

fixture는 **함수로 재사용**한다. 실측 seed 함수 이름:

| 파일 | seed 함수 |
| --- | --- |
| `forge-done.parity.test.sh` | `seed_active`·`seed_normal`·`seed_skip`·`seed_vfail`·`seed_vpend`·`seed_retro_owed`·`seed_review`·`seed_executed`·`seed_halfsealed`·`seed_dup`·`seed_empty`·`seed_badslug` |
| `forge-merge.parity.test.sh` | `seed_clean`·`seed_collide`·`seed_collide_new`·`seed_retro`·`seed_ctx_add`·`seed_ctx_redef`·`seed_ctx_disjoint`·`seed_ctx_legacy`·`seed_nnnn_ok`·`seed_nnnn_x`·`seed_remap`·`seed_dropped`·`seed_retired_collide`·`seed_retired_letterskip`·`seed_inflight`·`seed_ambig`·`seed_empty` |
| `forge-doctor.parity.test.sh` | `seed_clean`·`seed_mixed`·`seed_orphan`·`seed_t3`·`seed_desclen`·`seed_retired_dup` |
| behavior 쪽 | `seed_status`(doctor·hook)·`seed_plan`(hook)·`seed_active`(done)·`seed_adr`(merge) |

parity 테스트에서는 이 seed 함수를 **함수 이름으로 넘겨** 같은 fixture를 두 디렉터리에 두 번 심는다(`check "<desc>" seed_normal --args...`).

### 5.2 결정론 주입

시각과 랜덤이 들어가면 테스트가 흔들리므로 전부 주입한다.

- **봉인 시각** — `forge-done`은 `--completed 2026-07-05 --sealed-id 260705-120000`을 인자로 받는다. 테스트가 `SID`를 상수로 고정한다(`scripts/forge-done.test.sh:25`). 스크립트 헤더가 목적을 두 번 명시한다 — *"An arg so tests are deterministic."*
- **statusline 시각** — `FORGE_SL_NOW`(epoch 초)를 환경변수로 주입해 "⏱ 세션 경과" 인간화를 검증 가능하게 한다(`scripts/forge-statusline-full.test.sh`, 실측 리포 전체 사용 10회).
- **표시 옵션** — `FORGE_SL_SEP`/`FORGE_SL_DENSITY`/`FORGE_SL_PREFIX`도 env로 주입해 compact/full·구분자·접두 변형을 단언한다(`scripts/forge-statusline.test.sh:40` `run_in_env()`; 리포 전체 사용 13/13/4회).
- **git identity** — `resolve-forge-root.parity.test.sh:17`은 `gitc() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }`로 사용자 전역 git 설정을 무력화한다. 다른 테스트들은 `git config user.email t@t && git config user.name t`를 fixture 안에서 돌린다.

### 5.3 ANSI strip (statusline 계열)

```
strip_ansi() { sed -E $'s/\x1b\\[[0-9;]*m//g'; }
run_in() { ( cd "$1" && bash "$SCRIPT" </dev/null ) | strip_ansi; }
```

색·그라디언트는 live-tuned 구현 세부라 비교 대상이 아니고(ADR-0017), 텍스트·바 채움·이모지·라벨만 단언한다. 기대값은 문자 그대로 적는다 — 예: `assert "stdin-cwd-redirects" "[⚒ cwd-task · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in_json ...)"`. `</dev/null`이 load-bearing이다 — statusline은 stdin에서 세션 JSON을 읽으므로 리다이렉트가 없으면 블로킹한다.

`scripts/forge-statusline.test.sh:7-12` 헤더가 단언하는 계약을 요약해 둔다 — 세그먼트는 `[ ... ]` 그룹, 그룹은 공백으로, 그룹 안은 `" <SEP> "`(기본 `·`, merge 모드는 `|`), 밀도는 `full`(최대 2줄)/`compact`(1줄, queue를 forge 그룹에 접음), 모드 지시자 `🧪`(plan `tdd:on`)/`♻️`(최상위 config `eco:true`)는 **실제 활동이 있을 때만** 렌더(idle·loop-only에서는 안 나옴), `verified` 플래그는 파이프라인 끝에 온다.

### 5.4 stdin 세션 JSON

statusline은 Claude Code가 stdin으로 넘기는 세션 JSON에서 cwd를 파싱한다. 세 경로를 각각 테스트한다(`scripts/forge-statusline.test.sh`, `run_in_json()` = `:42`):

- `{"cwd": "..."}` → 그 경로 사용
- `{"workspace":{"current_dir":"..."}}` → 그 경로 사용
- cwd 키 없음 / stdin 없음(`</dev/null`) → `$PWD` 폴백

Windows식 백슬래시 escape된 cwd 디코딩은 parity 쪽에 fixture가 있다 — `scripts/forge-statusline.parity.test.sh:112-114`가 `wd\sub/.forge/backlog` 디렉터리를 실제로 만들고 JSON의 `"\\"`가 `chdir` 전에 `"\"`로 디코딩되는지를 sh/js 양쪽에서 확인한다.

### 5.5 진짜 `git init` fixture (브랜치 루트 해석)

브랜치별 forge 루트(ADR-0011)를 검증하려면 진짜 git 저장소가 필요하다. 목이 아니라 실제 `git init`을 쓴다:

```
( cd "$t" && git init -q -b feature-x && git config user.email t@t && git config user.name t \
  && git commit -q --allow-empty -m init ) 2>/dev/null
```

실측 사용처 11곳: `scripts/forge-hook-session-start.test.sh:168`(`-b feature-x`), `scripts/forge-done.test.sh:189`(`-b feature-x`), `scripts/forge-statusline-full.test.sh:200,210`(`-b test-branch` / `-b main`)와 `:218-219`(`git init -q --bare`로 **가짜 remote까지** 만들어 ahead/behind 표시 검증), `scripts/forge-statusline.test.sh:217`, parity 쪽은 `forge-statusline-full.parity.test.sh:75,84-85`(bare remote 포함)·`forge-hook-session-start.parity.test.sh:119`. `resolve-forge-root.parity.test.sh`는 6케이스 전부 실제 리포를 만들어 돌린다.

### 5.6 CRLF fixture

Windows 체크아웃을 재현한다 — `printf`에 `\r\n`을 직접 넣는다.

```
# scripts/forge-hook-session-start.test.sh:185-187
printf '<!-- forge-slug: crlf-task -->\r\n<!-- task: 4 -->\r\n# T\r\n' > "$t/.forge/plan.md"
printf 'run\r\n' > "$t/.forge/run.md"
printf '# STATUS\r\n- slug: crlf-task\r\n- status: executed\r\n- verified: failed (button dead)\r\n- retro: pending\r\n' > "$t/.forge/STATUS.md"
```

이 케이스(`(9)`)는 **CRLF + 레거시 대시-리스트 필드 형식을 한 fixture에 겹쳐서** 두 관용을 동시에 검증한다. CRLF fixture를 가진 파일은 실측 3개뿐이다 — `forge-hook-session-start.test.sh`·`forge-hook-session-start.parity.test.sh`(케이스 F)·`forge-status.parity.test.sh`(Fixture E). 후자 `:124-131`이 실제로 잡았던 버그를 주석에 남겼다 — CRLF 체크아웃된 STATUS.md 때문에 `.sh`가 `yes\r`/`pending\r`을 캡처해 심볼이 오작동했다. `forge-done`/`forge-merge`/`forge-doctor` 쪽에는 CRLF fixture가 없다 — 이들도 같은 `tr -d '\r'` 추출기를 쓰지만 그 관용이 테스트로 고정돼 있지는 않다.

### 5.7 한글/멀티바이트 fixture

`.sh`(`LC_ALL=C` 바이트)와 `.js`(`Buffer.compare`/latin1 뷰)의 정렬·패딩·절단이 갈리는 지점을 직접 찍는다.

- `scripts/forge-hook-session-start.parity.test.sh:77-86`(케이스 E) — 활성 슬롯의 한글 slug + 한국어 `verified:` 값이 **바이트째로 동일**함을 sentinel로 단언. 헤더 주석이 축을 명시한다(*"LC_ALL=C vs latin1 view"*). 예전에는 파킹 slug 셋의 **정렬 순서**를 보는 케이스였는데, park이 개수 줄로 바뀌어 렌더되는 slug가 사라지자 멀티바이트 위험이 활성 슬롯 값 쪽으로 옮겨갔다 — fixture도 따라 옮겼다.
- `scripts/forge-hook-session-start.parity.test.sh:87-97`(케이스 E2) — **절단 경계에 걸친 멀티바이트.** 한글을 대량으로 넣어 200바이트 컷이 문자 중간에 떨어지게 만들고, 양 트윈이 똑같이 ASCII 경계까지 후퇴해 유효 UTF-8을 내는지 본다(전부 멀티바이트라 남는 게 없으면 `(value suppressed: N bytes)`). 바이트 컷 자체는 패리티를 지켜도 **무효 UTF-8**을 낼 수 있고 그건 실측으로 BSD `sed`가 거부했다.
- `scripts/forge-status.parity.test.sh:133-138`(Fixture F) — `한글-task` slug로 **표 패딩이 바이트 정렬로 일치**함을 단언. 주석 `:134`가 근거를 적는다 — `awk(LC_ALL=C)`는 바이트로 패딩하므로 node 트윈도 UTF-8 바이트로 패딩해야 한다.

### 5.8 적대적 입력 fixture (세션 시작 훅 한정)

세션 시작 훅만 **리포 텍스트를 에이전트 컨텍스트에 주입**하므로, 이 파일만 값 자체를 공격하는 fixture 계열을 가진다(behavior 케이스 `(12)`~`(19)`, parity 대응 케이스 K·L·M·N).

| 케이스 | fixture | 무엇을 단언하나 |
| --- | --- | --- |
| `(12)` `:212-229` | `verified:` 값에 `</forge-state>` + 명령문 | 닫는 태그가 **정확히 1회**, 출력 **마지막 줄**이 닫는 태그, 태그 구분자 제거됨, 블록이 값을 `untrusted`로 프레이밍 |
| `(13)` `:230-241` | 디렉터리명에 개행 + 값에 탭·ANSI escape | 블록 구조 유지 + **맨 제어문자 0개**(`tr -cd`로 실제로 센다) |
| `(14)` `:242-254` | 거대 `verified:` 값 | 절단 마커 `…` 존재 + 블록이 작게 유지 |
| `(15)` `:255-275` | 활성 슬롯 + 파킹 다수 | **줄 위치로** 순서 계약 단언(`grep -n` 줄 번호 비교) — 렌더 방식이 바뀌어도 살아남게 |
| `(16)` `:276-290` | 파킹 다수 | 활성 슬롯 항목이 살아남고 파킹 개수 줄이 총합을 냄 |
| `(17)` `:291-311` | `hooks/hooks.json` | **파싱된 객체**로 계약 단언(§7), node 없으면 `SKIP` |
| `(18)` `:312-375` | 10만 자리 `task:` / 거대 slug / 모든 STATUS 필드 동시 거대화 / 거대 goal 줄 / 파킹·백로그 대량 | **블록 크기 불변식** `BLOCK_MAX=4096` |
| `(19)` `:376-398` | 40자리 `task:` / 정상 `task: 103` | 말도 안 되는 task 번호는 **부재 취급**(slug-only 렌더로 폴백)하고 정상 번호는 유지 |

`BLOCK_MAX=4096`의 근거가 테스트 주석(`:320-325`)에 측정치로 적혀 있다 — 이 리포의 아카이브된 STATUS 파일 **n=80** 기준 `verified:` 중앙값 193B / p90 304B / 최대 512B, `retro:` 최대 153B, slug 최대 40자, task 번호 최대 3자리. `SAN_MAX=200`에서 이론상 최악 블록(tail 1 + goal loop + parked + backlog + directive)이 ~1.9KB, 실측 최악이 664B라 4096은 이론 대비 2배 여유이면서 병리적 값은 통과시키지 않는 값이다. **상한을 근거 없이 고르지 않는다**는 규율의 실례다.

헬퍼도 이 계열 전용이다 — `assert_bounded()`(`:329-335`, `wc -c`로 블록 바이트를 재 `BLOCK_MAX` 이하인지) + `big()`(`:327`, `awk`로 같은 문자 n개 생성).

### 5.9 실패 경로도 fixture로 덮는다

exit-code 계약이 인터페이스이므로, 각 코드에 대응하는 fixture가 있다. `forge-done` 예: `seed_vfail`(`verified: failed` → 3)·`seed_vpend`(`pending` → 3)·`seed_retro_owed`(→ 4)·`seed_halfsealed`(멱등 완료 → 0)·`seed_dup`(→ 5)·`seed_badslug`(경로 탈출 → 64)·`seed_empty`(→ 2). `forge-merge` 예: `seed_ctx_redef`(→ 4)·`seed_ctx_legacy`(인식불가 형식 → 4)·`seed_nnnn_x`(NNNN 충돌 → 4)·`seed_inflight`(→ 3)·`seed_ambig`(→ 6)·`seed_empty`(→ 2).

**게이트 거절 케이스는 rc뿐 아니라 "파일이 안 움직였음"까지 단언한다** — `assert_nofile`(그리고 소스가 그대로 남았음을 보는 `assert_file`). 예: `scripts/forge-merge.test.sh:103-104`의 케이스 j가 rc 4 + `assert_file "j-adr-untouched"`(브랜치 ADR 잔존) + `assert_nofile "j-target-adr-none"`(타깃에 안 생김)을 함께 본다. 케이스 i3(`:141-152`)은 더 나아가 `before="$(cat ...)"`를 미리 떠 두고 실행 후 내용 문자열을 비교해 **"타깃 파일을 전혀 안 건드림"**까지 단언한다. 비파괴-거절 계약(ADR-0030)의 검증이다.

---

## 6. 명시적으로 기록된 네 가지 단언 규율

이 리포가 실패로 배운 것이라 그냥 스타일 권고가 아니다.

### 규율 1 — "출력이 났다"가 아니라 **구체적 출력 내용**을 단언한다

출처: `.forge/retro/2026-07-16-forge-doctor-script-extract.md:9`.

> behavior 픽스처는 "finding이 발생했다"가 아니라 **구체적 출력 내용**을 단언해야 이런 버그를 자체적으로도 잡는다. 향후 forge 스크립트 개발에 적용.

실제 사고는 §3 사건 1의 B8 버전 드리프트 오추출이다 — "drift finding이 떴다"만 봐서 통과, parity가 잡음.

**현재 코드에 반영된 형태 셋:**

- behavior 쪽 — rc만 보지 않고 finding 문자열을 `assert_grep`으로 함께 본다: `assert "A1-rc2" 2 "$RC"; assert_grep "A1-msg" "$OUT" "A1 active-slot orphan"`(`scripts/forge-doctor.test.sh:27`). A4·A3 등 다른 체크도 같은 쌍으로 간다.
- 훅 쪽 — 사유 **전체**를 단언한다: `assert_grep "9-crlf-verified" "$OUT" "verified: failed (button dead)"`. 첫 토큰만 잡는 추출기로는 통과할 수 없는 단언이라, 추출기 변종(`field()` vs `fullfield()`, `CONVENTIONS.md` §4.3)을 테스트가 고정한다.
- parity 쪽 — **sentinel 단언**으로 "둘 다 빈 출력이라 같음"이 PARITY OK로 통과하는 걸 막는다. `assert_parity`의 마지막 인자가 그것이고, 실패 메시지가 진단까지 적는다: `FAIL - <desc> (equal but missing sentinel '<must>' — script likely didn't run)`(`scripts/forge-status.parity.test.sh:29-32`, `forge-hook-session-start.parity.test.sh:33-36`). hook parity는 역방향 단언까지 넣었다 — `must`가 비면 **침묵을 기대**하고, 출력이 있으면 실패시킨다(`:37-40`). 같은 이유로 이 파일 계열은 `set -euo pipefail`을 켜서 fixture 빌드 실패가 통과로 위장되지 않게 한다.

**아직 적용 안 된 곳:** `forge-doctor`/`forge-done`/`forge-merge`의 parity 3개는 sentinel 강화 + `set -euo pipefail`이 없다(`set -u`만). 이 셋은 트리 `diff -r` / rc 비교 축이라 위양성 형태가 다르지만(빈 트리 vs 빈 트리도 diff는 같다고 하므로 위험이 없진 않다), 강화된 5개와 비대칭인 건 사실이다.

또 하나의 인접 교훈 — `.forge/retro/2026-06-16-goal-pairing-prominent-not-offer.md`: **검증-선행 grep 기준선은 신규 문구가 기존 문구와 어휘를 공유하면 오염된다.** 대응은 (a) 신규 framing에만 등장할 sentinel을 편집 전에 미리 정하거나 (b) 제거되는 문구의 count→0 같은 결정적 체크에 무게를 두는 것.

### 규율 2 — 테스트는 **프로덕션 호출 형태**를 재현해야 한다

`bash <파일>`로 감싸 호출하면 통과하는데 실제 경로에서는 실패하는 버그가 있었다. Claude Code는 훅 커맨드를 `/bin/sh`에 넘겨 **파일을 직접 실행**하므로, exec 비트가 없으면 Permission denied로 훅이 **조용히** 발화하지 않는다.

`hooks/run-hook.test.sh:37-42` 주석이 그대로 남아 있다:

> Claude Code does not run `bash <wrapper>` — it hands the command string to `/bin/sh`, which executes the FILE. Without the exec bit that fails with "Permission denied" and the hook silently never fires, while a test that calls `bash "$WRAPPER"` still passes. So assert the bit, and assert the real invocation shape below. (superpowers ships its wrapper 755 for the same reason.)

**지금은 두 축이 함께 단언된다:**

```
# (1) exec 비트 자체 — hooks/run-hook.test.sh:43
if [ -x "$WRAPPER" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL wrapper-exec-bit (chmod +x %s)\n' "$WRAPPER"; fi

# (2) 프로덕션 호출 형태 — :50-52
OUT="$( cd "$t" && /bin/sh -c "\"$WRAPPER\" session-start" 2>/dev/null )"; RC=$?
assert      "wrapper-sh-direct-rc0"  0 "$RC"
assert_grep "wrapper-sh-direct-block" "$OUT" '`prod-call`'
```

즉 "권한이 있다"(정적)와 "그 권한으로 실제 호출 형태가 동작한다"(동적)를 따로 본다. 나머지 케이스는 `bash "$WRAPPER"`로 돌려도 되지만(디스패치 로직 검증), 대표 케이스 하나는 반드시 `/bin/sh -c`로 간다. 실측 현재 `hooks/run-hook.cmd`는 `-rwxr-xr-x`이고, 이건 `scripts/` 안의 일관성 없는 exec 비트(`CONVENTIONS.md` §4.1)와 달리 **load-bearing**이다.

### 규율 3 — 필드 하나가 아니라 **속성(property)**을 단언한다

출처: `scripts/forge-hook-session-start.test.sh:312-318`의 주석. 값 sanitize가 블록 크기를 묶는다는 보장은 **모든 값이 그 함수를 통과할 때만** 성립하는데, 한 필드가 추론으로 면제됐다 — "`task:`는 추출 시 `[0-9]+`로 매칭했으니 숫자뿐이라 상한 불필요". 문자 클래스는 알파벳을 제한할 뿐 **길이를 제한하지 않아** 10만 자리 `task:`가 100,553바이트 블록을 냈다.

> So assert the PROPERTY (the block stays bounded for any input), not just the one field — that is what catches the next bypass.

그래서 그 케이스만 추가하는 대신 **속성**을 단언한다 — "어떤 입력에도 블록은 `BLOCK_MAX` 이하"(`assert_bounded()` 헬퍼 + 병리적 fixture 5종). 필드별 단언은 다음 우회(새 필드 추가·새 값 경로)를 못 잡지만 속성 단언은 잡는다. 같은 규율이 스크립트 쪽 주석에도 "NO EXEMPTIONS — 필드를 추가하면 반드시 `sanitize()`를 태운다"로 박혔다(`scripts/forge-hook-session-start.sh:138-142`).

### 규율 4 — fixture가 코드와 **같은 오독**을 하면 아무것도 못 잡는다

출처: `scripts/forge-merge.test.sh:89-91`의 주석 — *"The old fixtures used `## Alpha` AS a term — the same misreading the code had, which is why neither caught the bug."*

`forge-merge`의 CONTEXT 병합은 `**Name**:`을 term으로 봐야 하는데(`skills/fg-ask/CONTEXT-FORMAT.md`) 코드가 `## X`를 term으로 읽었고, **fixture도 똑같이** `## Alpha`를 term으로 심어 뒀다. 그래서 assertion 전부 green인 채로, 정상 형식의 두 글로서리가 공유하는 `## Language`에서 항상 거짓 exit 4가 나는 버그가 살아 있었다(실제로 `feature/result-summary` 브랜치 통합에서 터짐 — 커밋 `7b1ef73`/`1619054` 무렵). 패리티도 못 잡는다 — 두 트윈이 같은 오독을 공유했으니 출력은 일치했다.

교훈: **소비하는 형식의 fixture는 형식 문서에 대고 만든다**(구현을 보고 만들지 않는다). 지금은 세 축으로 덮는다:

- **정상 형식의 disjoint term 병합** — `scripts/forge-merge.test.sh:124-139`(케이스 i2, "REGRESSION: the case that actually broke"). 양쪽이 각자 `## Language` 밑에 서로 다른 term을 갖고, 병합 후 **4개 term이 하나의 `## Language` 아래** 살아남는지를 `grep -c '^\*\*'` = 4 + `grep -c '^## Language$'` = 1로 단언한다.
- **진짜 재정의 → exit 4 + 무이동** — `:97-103`(케이스 j).
- **인식 불가 형식 → exit 4 + 타깃 무변경** — `:141-152`(케이스 i3, `before`/`after` 내용 비교).

패리티 쪽 fixture도 같은 형식으로 교체됐다 — `seed_ctx_add`·`seed_ctx_redef`에 더해 신규 `seed_ctx_disjoint`(`:59`)·`seed_ctx_legacy`(`:60`)가 i2/i3 대응이다.

---

## 7. `hooks/run-hook.test.sh`가 특별히 덮는 것

훅 배선은 조용히 죽는 종류의 실패라 별도 테스트가 있다. 헤더가 존재 이유를 적는다 — *"a typo in hooks.json's command or matcher disables the hook with no error anywhere (Claude Code just never fires it), and a wrapper that exits non-zero would fail session start."*

22개 assertion이 덮는 것:

1. **`hooks.json` 정적 계약 6건**(`:23-35`) — `node -e JSON.parse`로 유효성 1건, 그리고 문자열 단언 5건으로 `"SessionStart"`·매처 `startup|resume|clear|compact`·커맨드 `/hooks/run-hook.cmd" session-start`·`${CLAUDE_PLUGIN_ROOT}`·`"async": false`. **이 5건은 substring grep(`grep -qF`)이라 형식이 깨졌거나 순서가 바뀐 매니페스트도 통과시킨다** — 그래서 `scripts/forge-hook-session-start.test.sh:291-310`(케이스 17)이 같은 계약을 **파싱된 객체**로 다시 단언한다: `matcher` 정확 일치, `type: command`, `shell: bash`, `async: false`, 커맨드 형태 정규식(`/run-hook\.cmd" session-start$/`), `SessionStart` 엔트리 **개수 1**. node가 없으면 그 케이스는 `SKIP`으로 정직하게 빠진다. 즉 훅 배선 계약은 **두 파일에 걸쳐 이중으로** 덮인다.
2. **exec 비트 + 프로덕션 호출 형태** — §6 규율 2.
3. **디스패치 정상 경로** — 미봉인 잔여 fixture → `<forge-state>` 블록 + slug 등장, rc 0.
4. **graceful 침묵 3종** — 깨끗한 상태 / 미지 훅 이름(`no-such-hook`) / 인자 없음 → 전부 빈 출력 + rc 0.
5. **`CLAUDE_PROJECT_DIR`가 cwd를 이긴다** — forge 상태가 전혀 없는 디렉터리에서 돌리면서 `CLAUDE_PROJECT_DIR`만 진짜 상태 디렉터리로 지정 → anchored slug가 나오는지.
6. **node-only 경로** — bash 없는 Windows-ish 박스를 흉내내 `.js` 트윈이 직접 답하는지.

이 파일은 `_IMPL` 오버라이드가 없다 — 래퍼 자체가 디스패처이므로 구현 교체가 의미 없다.

---

## 8. 새 스크립트를 추가할 때의 체크리스트 (ADR-0031 필수 조건)

1. `.sh`(bash 우선) + `.js`(node 폴백) 트윈을 만든다 — dual dispatch로 호출.
2. `X.test.sh`(fixture behavior)를 쓰고, `<PREFIX>_IMPL` 오버라이드로 **`.js` 트윈도 같은 테스트로 green**을 확인한다. 요약 줄에 `(impl: ...)`를 찍으면 오버라이드가 먹었는지 눈으로 확인된다.
3. `X.parity.test.sh`로 동일 출력(또는 동일 파일 트리 + 동일 rc)을 보장한다. 성격에 맞는 비교 축을 고른다(§3: 읽기전용=stdout+rc, 파괴적=`diff -r`, 표시용=ANSI strip). **populated 케이스에는 sentinel을 넣고 `set -euo pipefail`을 켠다**(§6 규율 1).
4. 파괴적이면 게이트-우선·비파괴-거절 + exit code로만 refuse. 게이트 거절 케이스는 rc와 "안 움직였음"(`assert_nofile`/내용 비교)을 함께 단언한다.
5. 브랜치 루트는 `resolve-forge-root.sh`/`.js`를 재사용한다(ADR-0011) — 하드코딩 금지.
6. `SKILL.md`에 스크립트 출력·exit-code 계약을 문서화하고 동기 유지한다(형식이 양쪽에 존재 → 함께 고친다).
7. `bash scripts/forge-doctor.sh`로 B15(트윈 존재, 양방향) 등 정합을 확인한다.

흐름: `트윈 작성 → X.test.sh(.sh green) → _IMPL로 .js green → X.parity.test.sh → forge-doctor.sh`

`.claude/agents/script-twin-engineer.md`가 이 체크리스트의 운영 버전을 담고 있으며, 두 가지를 추가로 못 박는다 — **고정폭 명명 형식이 바뀌면 위치-파싱을 전수 점검**하라(`:0:10`·`.slice(0,10)`·`${name:11}`이 조용히 깨진다; 가능하면 위치 슬라이스 대신 필드에서 값을 읽어 format-agnostic하게), **형식별 코드 경로는 가드를 대칭으로 미러링**하라(한쪽에만 있는 가드가 버그의 서식지; bash glob `[a-z]*`는 "최소 1글자"라 regex `[a-z]?`와 비대칭이다 — B14의 시간ID 수집이 그래서 glob을 둘로 나눠 쓴다, `scripts/forge-doctor.sh:141-143`).

---

## 9. 테스트가 원리적으로 없는 영역 — 산문 계약

이 리포에서 **테스트로 덮이지 않는 규율의 양이 덮이는 양보다 크다.** 16개 테스트 파일은 전부 `scripts/`·`hooks/`의 결정론 코드만 본다. 나머지 전부 — 19개 SKILL.md의 절차, 상태 계약의 의미론, 게이트 라우팅 판단, 핸드오프 형태 — 는 산문이고 검증 수단이 `forge-doctor`의 4개 lint(B10/B12/B13/B16)와 사람 뿐이다.

**작업 트리의 fg-map Update 경로가 이 비대칭의 최신 실례다.** `skills/fg-map/SKILL.md:47-67`이 증분 갱신을 **번호 매긴 mandatory 단계**로 못 박았는데(자격 사전점검 → 변경 파일 union → 베이스라인 `wc -l` → 제자리 편집 계약 → 사후 스탬프·30% 축소 검사), 여기에는 **스크립트 트윈도, behavior 테스트도, parity 테스트도, fg-doctor 체크도 없다.** 실측: `grep -c codebase scripts/forge-doctor.{sh,js}` → **0, 0**.

이건 누락이 아니라 ADR `260801-020258:47`의 명시적 결정이다 — ADR-0031의 세 다리 중 **"자주 도는 경로"**가 부러지므로(fg-map은 가끔 도는 유틸리티) 스크립트화하면 필수 조건 4종(트윈 + behavior + parity + 계약 동기)이 따라붙어 **파일 4개와 영구 유지비**만 생긴다. 대신 같은 스킬의 선례(secret scan **mandatory**)와 동일하게 산문의 mandatory 단계로 처리한다.

**따라서 이 리포에서 "테스트 커버리지"를 논할 때는 두 층을 구분해야 한다:**

| 층 | 검증 수단 | 현재 상태 |
| --- | --- | --- |
| 결정론 스크립트(9개 트윈) | behavior 316 assertion + parity 94 케이스 + fg-doctor B15 | 전부 green, 구멍은 §2에 열거 |
| 스킬 산문(19 SKILL.md + 9 공유 문서) | fg-doctor B10/B12/B13/B16 lint + 사람 | 절차·판단·형태는 **미검증** |
| 지도 문서(`.forge/codebase/` 7개) | fg-map 자신의 산문 precheck/post-check | 기계 검사 **0** |

산문 층에서 회귀를 잡는 유일한 실전 기법이 회고에 기록돼 있다 — **편집 전 grep 기준선 + 제거 문구의 count→0 확인**(§6 규율 1 말미). 문서 편집이 계약을 깼는지는 그렇게만 알 수 있다.
