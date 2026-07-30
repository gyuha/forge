---
last_mapped_commit: c1100b17577529833c68ca5a8c59ee1e310f24d4
mapped: 2026-07-28
---

# TESTING

이 문서는 **구현 사실만** 다룬다. 도메인 용어 정의는 `.forge/CONTEXT.md` 소관이다. 아래 모든 수치는 이 커밋에서 실제로 테스트를 돌려 얻은 값이다(2026-07-28, macOS, 전부 green).

## 1. 프레임워크 — 없다

테스트 프레임워크·러너·설정 파일이 **하나도 없다.** `package.json`·`Makefile`·`.github/` 전부 부재. 테스트는 그냥 **`bash`가 실행하는 자기완결 셸 스크립트**다.

각 테스트 파일은 다음을 스스로 갖는다:

- `#!/usr/bin/env bash` shebang + `set -u`(일부 parity는 `set -euo pipefail`, §5)
- 자체 카운터 `pass=0; fail=0`
- 자체 assert 헬퍼 4~5개 (`assert`·`assert_grep`·`assert_file`·`assert_nofile`·`assert_ngrep`)
- 자체 fixture seed 함수 (`seed_active`·`seed_status`·`seed_plan`·`seed_adr` …)
- 끝에 `N passed, M failed` 요약 출력 + `[ "$fail" -eq 0 ] || exit 1`

의존성은 bash + coreutils + `git` + `node`(트윈 실행·JSON 파싱용)뿐이다.

### 실행법

```bash
# 하나만
bash scripts/forge-done.test.sh
bash hooks/run-hook.test.sh

# 전부 (러너가 없으므로 셸 루프로 돈다)
for f in $(find . -name "*.test.sh" -not -path "./.git/*" | sort); do
  echo "=== $f ==="; bash "$f" || echo "FAILED: $f"
done

# 상태·문서 무결성 검사 (테스트와 별개, 읽기 전용)
bash scripts/forge-doctor.sh   # 0 clean · 1 warnings · 2 errors
```

`.test.js`는 존재하지 않는다 — `.js` 트윈도 같은 `.sh` 테스트 파일로 검증한다(§4).

---

## 2. 테스트 인벤토리 (실측)

한 스크립트 트윈에 대해 **두 종류**의 테스트가 붙는다: `X.test.sh`(behavior)와 `X.parity.test.sh`(패리티). 총 16개 파일, 2,254줄.

### Behavior 테스트 — 8개, 합계 274 assertion

| 파일 | assertion | 줄 | env 오버라이드 |
| --- | --- | --- | --- |
| `scripts/forge-done.test.sh` | 60 | 254 | `FGDONE_IMPL` |
| `scripts/forge-merge.test.sh` | 48 | 121 | `FGMERGE_IMPL` |
| `scripts/forge-doctor.test.sh` | 36 | 88 | `FGDOCTOR_IMPL` |
| `scripts/forge-statusline.test.sh` | 35 | 248 | **없음** |
| `scripts/forge-statusline-full.test.sh` | 34 | 311 | `FGSL_FULL_IMPL` |
| `scripts/forge-hook-session-start.test.sh` | 32 | 194 | `FGHOOK_IMPL` |
| `hooks/run-hook.test.sh` | 22 | 113 | **없음**(래퍼 자체가 디스패처라 불필요) |
| `scripts/forge-statusline-wrapper.test.sh` | 7 | 113 | **없음** |

### Parity 테스트 — 8개, 합계 84 케이스

| 파일 | 케이스 | 줄 | 비교 대상 |
| --- | --- | --- | --- |
| `scripts/forge-merge.parity.test.sh` | 15 | 70 | 파일 트리 + rc |
| `scripts/forge-done.parity.test.sh` | 14 | 84 | 파일 트리 + rc |
| `scripts/forge-statusline.parity.test.sh` | 14 | 126 | stdout(ANSI strip) + 기대값 |
| `scripts/forge-hook-session-start.parity.test.sh` | 10 | 124 | stdout + sentinel |
| `scripts/forge-statusline-full.parity.test.sh` | 10 | 126 | stdout(ANSI strip) |
| `scripts/forge-status.parity.test.sh` | 9 | 159 | stdout + sentinel |
| `scripts/forge-doctor.parity.test.sh` | 6 | 55 | stdout + rc |
| `scripts/resolve-forge-root.parity.test.sh` | 6 | 68 | stdout |

### 커버리지 구멍 (실측)

- **`scripts/forge-status.sh` — behavior 테스트가 없다.** parity만 있다. 즉 sh와 js가 *똑같이 틀린* 출력을 내면 아무도 잡지 못한다.
- **`scripts/resolve-forge-root.sh` — behavior 테스트가 없다.** parity만 있다. 단 이 parity는 기대 경로 문자열까지 출력에 찍어 확인한다(사실상 behavior 겸용).
- **`scripts/forge-statusline-wrapper.sh` — parity 테스트가 없다.** bash 전용 래퍼라 `.js` 트윈 자체가 없다(ADR-0022의 명시적 예외, fg-doctor B15 제외 패턴에 등재).
- **`scripts/forge-statusline.test.sh`에 `_IMPL` 오버라이드가 없다**(`:19`에서 `.sh` 경로를 하드코딩). 따라서 `forge-statusline.js`는 **parity로만** 검증되고 35개 behavior assertion을 직접 통과하지는 않는다. 같은 계열의 `-full` 쪽은 `FGSL_FULL_IMPL`이 있어 이 비대칭이 존재한다.
- **CI가 없다.** `forge-doctor.sh`·`forge-merge.sh`는 exit-code 계약으로 "AI 없이 CI 게이트 가능"하도록 설계됐고 SKILL.md에 CI usage 절까지 있지만(`skills/fg-doctor/SKILL.md:18`, `skills/fg-merge/SKILL.md:40`), 이 리포에 실제로 그걸 돌리는 워크플로는 없다. 테스트 실행은 전적으로 수동이다.
- **스킬 산문(`skills/*/SKILL.md`)에 대한 테스트는 없다.** 산문 정합은 `forge-doctor`의 B10/B12/B13/B16 lint가 대신한다.

---

## 3. 왜 parity가 따로 존재하는가

**behavior 테스트의 느슨한 단언이 놓치는 버그를 독립 구현 교차검증이 잡기 때문이다.** 이건 추측이 아니라 이 리포에 기록된 실측 사건이다 — `.forge/retro/2026-07-16-forge-doctor-script-extract.md:9`:

> **B8 버그**: behavior 테스트가 "drift finding이 떴다"만 assert하고 *어느 버전 번호인지*는 안 봐서 통과했는데, parity(`.sh`↔`.js` 출력 정확 비교)가 불일치를 잡았다.

(원인은 `.sh`의 `jver`가 단일라인 JSON에서 다중 `"version"`을 오추출한 것. 같은 라운드에 B9 `[ -f ]` 가드 누락도 함께 잡혔다.)

여기서 나온 두 교훈이 그대로 규율이 됐다 — §6.

ADR-0022가 같은 판단을 설계 시점에 적어 뒀다: *"drift 관리 ... **같은 fixture에 두 구현을 돌려 출력 동일성을 단언하는 패리티 테스트**가 진짜 동치 가드다(존재 검사보다 강력)."* fg-doctor의 B15(`.js` 트윈 존재 여부)는 정적인 절반일 뿐이다.

### parity가 무엇을 비교하는가 — 스크립트 성격에 따라 셋으로 갈린다

읽기 전용 / 표시용 / 파괴적 스크립트가 각각 다른 축을 비교한다.

**(a) 읽기 전용 — 같은 fixture에서 둘 다 돌려 stdout + rc 비교** (`forge-doctor`·`forge-status`·`forge-hook-session-start`·`resolve-forge-root`)

```
# scripts/forge-doctor.parity.test.sh:19-21
O_SH="$( cd "$D" && bash "$SH" 2>&1 )"; rc_sh=$?
O_JS="$( cd "$D" && node "$JS" 2>&1 )"; rc_js=$?
```
디렉터리를 하나만 만들어 순차로 돌린다(아무것도 안 쓰므로 안전).

**(b) 파괴적 — fixture를 두 벌 만들어 각각 돌리고 결과 트리를 `diff -r`** (`forge-done`·`forge-merge`)

```
# scripts/forge-done.parity.test.sh:27-38
A=$(mktmp); B=$(mktmp); "$seedfn" "$A"; "$seedfn" "$B"
( cd "$A" && bash "$SH" "$@" ); rc_sh=$?
( cd "$B" && node "$JS" "$@" ); rc_js=$?
[ "$rc_sh" = "$rc_js" ] || FAIL
diff -r "$A/.forge" "$B/.forge" >/dev/null || FAIL
```
헤더(`:2-6`)가 이유를 적는다 — 이 프리미티브는 파일을 **옮기므로** stdout이 아니라 **파일 시스템 결과**(STATUS 마감 내용 + 아카이브 레이아웃 + 무엇이 이동/삭제됐는지)로 패리티를 본다.

**(c) 표시용 — stdout을 ANSI strip 후 비교, 시각은 주입** (`forge-statusline`·`forge-statusline-full`)

### 정규화(normalization) — 우주적 차이만 흡수한다

두 구현의 **의미 없는 차이**만 지우고, 의미 있는 차이는 절대 지우지 않는다.

- `scripts/forge-doctor.parity.test.sh:14-15` — bash 문자열 조립 vs node `path.join` 차이만 흡수: `sed -e 's#\./##g' -e 's#//*#/#g'`. 주석이 경계를 명시한다 — *"Findings/severity/exit are what parity actually checks."*
- `scripts/forge-status.parity.test.sh:17` — 행 끝 공백만 제거(`sed -e 's/[[:space:]]*$//'`).
- statusline 계열 — ANSI 색코드만 제거. `scripts/forge-statusline.test.sh:4` 주석: 정확한 색은 live-tuned 구현 세부(ADR-0017)이고, **pct 텍스트·바 채움·이모지·라벨이 단언 대상 정보를 담는다.**

### 출력 형식

parity 테스트는 케이스마다 `ok   - <설명>` / `FAIL - <설명>`을 찍고 끝에 `... PARITY OK` 또는 `... PARITY FAILED (N)`을 낸 뒤 0/1로 종료한다. behavior 테스트는 실패만 `FAIL <name> expected/actual`로 찍고 끝에 `N passed, M failed`를 낸다.

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
| `FGDONE_IMPL` | `scripts/forge-done.test.sh` | `:23` |
| `FGMERGE_IMPL` | `scripts/forge-merge.test.sh` | `:13` |
| `FGDOCTOR_IMPL` | `scripts/forge-doctor.test.sh` | `:10` |
| `FGHOOK_IMPL` | `scripts/forge-hook-session-start.test.sh` | `:27` |
| `FGSL_FULL_IMPL` | `scripts/forge-statusline-full.test.sh` | `:24` |

`FGSL_FULL_IMPL`만 상대경로도 받아 절대경로로 정규화한다(`:25`) — 나머지는 절대경로를 요구한다(`forge-hook-session-start.test.sh:23` 주석이 `/abs/path/`를 명시).

`.js` 트윈을 같은 테스트로 돌린 실측 결과(전부 green):

```
FGHOOK_IMPL=$PWD/scripts/forge-hook-session-start.js  → 32 passed, 0 failed
FGDOCTOR_IMPL=$PWD/scripts/forge-doctor.js            → 36 passed, 0 failed
FGDONE_IMPL=$PWD/scripts/forge-done.js                → 60 passed, 0 failed
FGMERGE_IMPL=$PWD/scripts/forge-merge.js              → 48 passed, 0 failed
FGSL_FULL_IMPL=$PWD/scripts/forge-statusline-full.js  → 34 passed, 0 failed (impl: forge-statusline-full.js)
```

`-full` 테스트는 요약 줄에 어떤 구현으로 돌렸는지 찍는다(`... (impl: forge-statusline-full.js)`) — 오버라이드가 실제로 먹었는지 눈으로 확인되게. 다른 테스트는 이 표기가 없다.

이 패턴은 ADR-0031이 스크립트 사용 시 **필수 조건 2**로 못 박은 것이다: *"behavior 테스트: fixture 기반 `*.test.sh`. `.js` 트윈도 같은 테스트로 green."*

---

## 5. Fixture 스타일

### 5.1 기본형 — `mktemp -d` 일회용 디렉터리 + 합성 `.forge/` 트리 + cwd 전환

모든 테스트가 같은 형태다: 임시 디렉터리를 만들고, 그 안에 `.forge/` 상태를 `printf`로 심고, **그 디렉터리를 cwd로 삼아** 스크립트를 서브셸에서 돌리고, stdout/rc/파일 트리를 단언하고, `rm -rf`로 지운다.

```
t=$(mktmp); mkdir -p "$t/.forge"
printf '<!-- forge-slug: %s -->\n# T %s\n' "$2" "$2" > "$1/.forge/plan.md"
printf 'run notes\n' > "$1/.forge/run.md"
printf '# STATUS — %s\nslug: %s\nstatus: executed\nexecuted: 2026-07-01\nverified: %s\nretro: %s\n' ...
run_done "$t" --completed 2026-07-05 --sealed-id "$SID"
assert "a-empty-rc2" 2 "$RC"
rm -rf "$t"
```

`mktemp` 접두는 테스트마다 다르게 붙여 잔여물을 구분할 수 있게 한다 — 실측 11종: `fgdoc.`·`fgdocp.`·`fgdone.`·`fgdonep.`·`fghook.`·`fgmerge.`·`fgmergep.`·`fgsl.`·`fgslfull.`·`fgslw.`·`fgwrap.`. 전부 `${TMPDIR:-/tmp}/` 아래.

fixture는 **함수로 재사용**한다 — `seed_active`·`seed_status`·`seed_plan`·`seed_adr`·`seed_executed`·`seed_halfsealed`·`seed_clean`·`seed_mixed`·`seed_orphan`·`seed_vfail`·`seed_vpend`·`seed_retro_owed`·`seed_review` 등. parity 테스트에서는 이 seed 함수를 **함수 이름으로 넘겨** 같은 fixture를 두 디렉터리에 두 번 심는다(`check "<desc>" seed_normal --args...`).

### 5.2 결정론 주입

시각과 랜덤이 들어가면 테스트가 흔들리므로 전부 주입한다.

- **봉인 시각** — `forge-done`은 `--completed 2026-07-05 --sealed-id 260705-120000`을 인자로 받는다. 테스트가 `SID="260705-120000"`을 상수로 고정한다(`scripts/forge-done.test.sh:25`). 스크립트 헤더가 목적을 명시: *"An arg so tests are deterministic."*
- **statusline 시각** — `FORGE_SL_NOW`(epoch 초)를 환경변수로 주입해 "⏱ 세션 경과" 인간화를 검증 가능하게 한다(`scripts/forge-statusline-full.test.sh:47-48`).
- **표시 옵션** — `FORGE_SL_SEP`/`FORGE_SL_DENSITY`/`FORGE_SL_PREFIX`도 env로 주입해 compact/full·구분자 변형을 단언한다(`scripts/forge-statusline.test.sh:40` `run_in_env()`).

### 5.3 ANSI strip (statusline 계열)

```
strip_ansi() { sed -E $'s/\x1b\\[[0-9;]*m//g'; }
run_in() { ( cd "$1" && bash "$SCRIPT" </dev/null ) | strip_ansi; }
```
색·그라디언트는 live-tuned 구현 세부라 비교 대상이 아니고(ADR-0017), 텍스트·바 채움·이모지·라벨만 단언한다. 기대값은 문자 그대로 적는다 — 예:

```
assert "stdin-cwd-redirects" "[⚒ cwd-task · ✔ ask → ● run → ○ learn → ○ done]" "$(run_in_json "$b" ...)"
```

### 5.4 stdin 세션 JSON

statusline은 Claude Code가 stdin으로 넘기는 세션 JSON에서 cwd를 파싱한다. 세 경로를 각각 테스트한다(`scripts/forge-statusline.test.sh:232,236,240`):

- `{"cwd": "..."}` → 그 경로 사용
- `{"workspace":{"current_dir":"..."}}` → 그 경로 사용
- cwd 키 없음 / stdin 없음(`</dev/null`) → `$PWD` 폴백

Windows식 백슬래시 escape된 cwd 디코딩은 parity 쪽에 fixture가 있다 — `scripts/forge-statusline.parity.test.sh:112-114`가 `"$WIN/wd\\sub/.forge/backlog"` 디렉터리를 실제로 만들고 JSON의 `"\\"`가 `chdir` 전에 `"\"`로 디코딩되는지를 sh/js 양쪽에서 확인한다.

### 5.5 진짜 `git init` fixture (브랜치 루트 해석)

브랜치별 forge 루트(ADR-0011)를 검증하려면 진짜 git 저장소가 필요하다. 목이 아니라 실제 `git init`을 쓴다:

```
( cd "$t" && git init -q -b feature-x && git config user.email t@t && git config user.name t \
  && git commit -q --allow-empty -m init ) 2>/dev/null
```

실측 사용처: `scripts/forge-hook-session-start.test.sh:149`(`-b feature-x`), `scripts/forge-done.test.sh:189`(`-b feature-x`), `scripts/forge-statusline-full.test.sh:200,210`(`-b test-branch`, `-b main`), `:218-219`(`git init -q --bare`로 가짜 remote까지 만들어 ahead/behind 표시 검증), `scripts/forge-statusline.test.sh:217`, parity 쪽은 `forge-statusline-full.parity.test.sh:75,84-85`·`forge-hook-session-start.parity.test.sh:107`. `resolve-forge-root.parity.test.sh`는 `config.json`의 `defaultBranch`와 실제 브랜치 조합(예: `default=trunk`인데 `main`에 있음 → `<top>/.forge/branch/main`)까지 확인하고 결과 경로를 출력에 찍는다.

### 5.6 CRLF fixture

Windows 체크아웃을 재현한다 — `printf`에 `\r\n`을 직접 넣는다.

```
# scripts/forge-hook-session-start.test.sh:166-168
printf '<!-- forge-slug: crlf-task -->\r\n<!-- task: 4 -->\r\n# T\r\n' > "$t/.forge/plan.md"
printf '# STATUS\r\n- slug: crlf-task\r\n- status: executed\r\n- verified: failed (button dead)\r\n- retro: pending\r\n' > ...
assert_grep "9-crlf-verified" "$OUT" "verified: failed (button dead)"
```

이 케이스는 **CRLF + 레거시 대시-리스트 필드 형식을 한 fixture에 겹쳐서** 두 관용을 동시에 검증한다. `scripts/forge-status.parity.test.sh:124-131`이 실제로 잡았던 버그를 주석에 남겼다 — *"A CRLF-checked-out STATUS.md made the .sh capture `yes\r`/`pending\r` → wrong."*

### 5.7 한글/멀티바이트 fixture

`.sh`(로케일)와 `.js`(`Buffer.compare`)의 정렬·패딩이 갈리는 지점을 직접 찍는다.

- `scripts/forge-hook-session-start.parity.test.sh:77-84` — 파킹된 slug를 `한글-작업`·`zzz-task`·`가나-작업` 셋으로 만들어 **바이트 순서 정렬이 sh==js임**을 단언(sentinel `한글-작업`). 주석: *"byte-order sort must agree (LC_ALL=C vs Buffer.compare)"*.
- `scripts/forge-status.parity.test.sh:133-138` — `한글-task` slug로 **표 패딩이 바이트 정렬로 일치**함을 단언. 주석이 근거를 적는다 — `awk(LC_ALL=C)`는 바이트로 패딩하므로 node 트윈도 UTF-8 바이트로 패딩해야 한다.

### 5.8 실패 경로도 fixture로 덮는다

exit-code 계약이 인터페이스이므로, 각 코드에 대응하는 fixture가 있다. `forge-done` 예: `seed_vfail`(`verified: failed` → 3)·`seed_vpend`(`pending` → 3)·`seed_retro_owed`(→ 4)·`seed_halfsealed`(멱등 완료 → 0)·`seed_badslug`(경로 탈출 → 64)·빈 상태(→ 2). **게이트 거절 케이스는 rc뿐 아니라 "파일이 안 움직였음"까지 단언한다**(`assert_nofile`) — 비파괴-거절 계약의 검증.

---

## 6. 명시적으로 기록된 두 가지 단언 규율

이 리포가 실패로 배운 것이라 그냥 스타일 권고가 아니다.

### 규율 1 — "출력이 났다"가 아니라 **구체적 출력 내용**을 단언한다

출처: `.forge/retro/2026-07-16-forge-doctor-script-extract.md:9`.

> behavior 픽스처는 "finding이 발생했다"가 아니라 **구체적 출력 내용**을 단언해야 이런 버그를 자체적으로도 잡는다. 향후 forge 스크립트 개발에 적용.

실제 사고는 §3에 적은 B8 버전 드리프트 오추출이다 — "drift finding이 떴다"만 봐서 통과, parity가 잡음.

**현재 코드에 반영된 형태 셋:**

- behavior 쪽 — rc만 보지 않고 finding 문자열을 `assert_grep`으로 함께 본다: `assert "A1-rc2" 2 "$RC"; assert_grep "A1-msg" "$OUT" "A1 active-slot orphan"`(`scripts/forge-doctor.test.sh:27`).
- 훅 쪽 — 사유 전체를 단언한다: `assert_grep "9-crlf-verified" "$OUT" "verified: failed (button dead)"`. 첫 토큰만 잡는 추출기로는 통과할 수 없는 단언이다.
- parity 쪽 — **sentinel 단언**으로 "둘 다 빈 출력이라 같음"이 PARITY OK로 통과하는 걸 막는다. `assert_parity`의 4번째 인자가 그것이고, 실패 메시지가 진단까지 적는다: `FAIL - <desc> (equal but missing sentinel '<must>' — script likely didn't run)`(`scripts/forge-status.parity.test.sh:31-33`). 같은 이유로 이 파일 계열은 `set -euo pipefail`을 켜서 fixture 빌드 실패가 통과로 위장되지 않게 한다(`:7-10`).

**아직 적용 안 된 곳:** `forge-doctor`/`forge-done`/`forge-merge`의 parity 테스트 3개는 sentinel 강화 + `set -euo pipefail`이 없다(`set -u`만). 이 셋은 트리 diff / rc 비교 축이라 위양성 형태가 다르지만, 강화된 5개와 비대칭인 건 사실이다.

또 하나의 인접 교훈 — `.forge/retro/2026-06-16-goal-pairing-prominent-not-offer.md:11`: **검증-선행 grep 기준선은 신규 문구가 기존 문구와 어휘를 공유하면 오염된다.** 대응: (a) 신규 framing에만 등장할 sentinel을 편집 전에 미리 정하거나 (b) 제거되는 문구의 count→0 같은 결정적 체크에 무게를 둔다.

### 규율 2 — 테스트는 **프로덕션 호출 형태**를 재현해야 한다

`bash <파일>`로 감싸 호출하면 통과하는데 실제 경로에서는 실패하는 버그가 있었다. Claude Code는 훅 커맨드를 `/bin/sh`에 넘겨 **파일을 직접 실행**하므로, exec 비트가 없으면 Permission denied로 훅이 **조용히** 발화하지 않는다 — c1100b1 커밋 메시지가 UAT 실측으로 기록했다.

`hooks/run-hook.test.sh:37-42` 주석이 그대로 남아 있다:

> Claude Code does not run `bash <wrapper>` — it hands the command string to `/bin/sh`, which executes the FILE. Without the exec bit that fails with "Permission denied" and the hook silently never fires, while a test that calls `bash "$WRAPPER"` still passes. So assert the bit, and assert the real invocation shape below.

**지금은 두 축이 함께 단언된다:**

```
# (1) exec 비트 자체 — :43
if [ -x "$WRAPPER" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL wrapper-exec-bit (chmod +x %s)\n' "$WRAPPER"; fi

# (2) 프로덕션 호출 형태 — :50-52
OUT="$( cd "$t" && /bin/sh -c "\"$WRAPPER\" session-start" 2>/dev/null )"; RC=$?
assert      "wrapper-sh-direct-rc0"  0 "$RC"
assert_grep "wrapper-sh-direct-block" "$OUT" '`prod-call`'
```

즉 "권한이 있다"(정적)와 "그 권한으로 실제 호출 형태가 동작한다"(동적)를 따로 본다. 나머지 케이스는 `bash "$WRAPPER"`로 돌려도 되지만(디스패치 로직 검증), 대표 케이스 하나는 반드시 `/bin/sh -c`로 간다.

---

## 7. `hooks/run-hook.test.sh`가 특별히 덮는 것

훅 배선은 조용히 죽는 종류의 실패라 별도 테스트가 있다. 헤더(`:5-8`)가 존재 이유를 적는다 — *"a typo in hooks.json's command or matcher disables the hook with no error anywhere (Claude Code just never fires it), and a wrapper that exits non-zero would fail session start."*

22개 assertion이 덮는 것:

1. **`hooks.json` 정적 계약 6건** — `node -e JSON.parse`로 유효성, 그리고 문자열 단언으로 `"SessionStart"`·매처 `startup|resume|clear|compact`·커맨드 `/hooks/run-hook.cmd" session-start`·`${CLAUDE_PLUGIN_ROOT}`·`"async": false`(`:23-35`).
2. **exec 비트 + 프로덕션 호출 형태** — §6 규율 2.
3. **디스패치 정상 경로** — 부채 상태 fixture → `<forge-state>` 블록 + slug 등장, rc 0.
4. **graceful 침묵 3종** — 깨끗한 상태 / 미지 훅 이름(`no-such-hook`) / 인자 없음 → 전부 빈 출력 + rc 0.
5. **`CLAUDE_PROJECT_DIR`가 cwd를 이긴다** — forge 상태가 전혀 없는 디렉터리에서 돌리면서 `CLAUDE_PROJECT_DIR`만 진짜 상태 디렉터리로 지정 → anchored slug가 나오는지(`:87-98`).
6. **node-only 경로** — bash 없는 Windows-ish 박스를 흉내내 `.js` 트윈이 직접 답하는지(`:100-110`).

---

## 8. 새 스크립트를 추가할 때의 체크리스트 (ADR-0031 필수 조건)

1. `.sh`(bash 우선) + `.js`(node 폴백) 트윈을 만든다 — dual dispatch로 호출.
2. `X.test.sh`(fixture behavior)를 쓰고, `<PREFIX>_IMPL` 오버라이드로 **`.js` 트윈도 같은 테스트로 green**을 확인한다.
3. `X.parity.test.sh`로 동일 출력(또는 동일 파일 트리 + 동일 rc)을 보장한다. 성격에 맞는 비교 축을 고른다(§3).
4. 파괴적이면 게이트-우선·비파괴-거절 + exit code로만 refuse. 게이트 거절 케이스는 rc와 "안 움직였음"을 함께 단언한다.
5. 브랜치 루트는 `resolve-forge-root.sh`/`.js`를 재사용한다(ADR-0011).
6. `SKILL.md`에 스크립트 출력·exit-code 계약을 문서화하고 동기 유지한다(형식이 양쪽에 존재 → 함께 고친다).
7. `bash scripts/forge-doctor.sh`로 B15(트윈 존재) 등 정합을 확인한다.

흐름: `트윈 작성 → X.test.sh(.sh green) → _IMPL로 .js green → X.parity.test.sh → forge-doctor.sh`
