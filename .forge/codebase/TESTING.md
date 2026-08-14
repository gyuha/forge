---
last_mapped_commit: 48899bdb6b04ad575767885a7c741cb2a09bd9d0
mapped: 2026-08-10
---

# TESTING

이 문서는 **구현 사실만** 다룬다. 아래 수치는 이 커밋의 작업 트리에서 2026-08-10에 **전체 테스트를 실제로 돌려** 얻은 값이다(macOS/darwin 25.5.0, 16개 파일 전부 rc=0).

## 1. 프레임워크: 없음 — 순수 bash 스크립트 테스트

테스트 러너·프레임워크·의존성이 전혀 없다. 각 테스트는 자기완결 bash 스크립트로, 내부에 `assert()`/`assert_grep()` 헬퍼를 자체 정의하고 `pass`/`fail` 카운터를 세다가 실패가 있으면 exit 1 한다. 실행법은 파일 헤더 주석에 명시: `bash scripts/<name>.test.sh`.

테스트 대상은 산문 스킬이 아니라 **결정론 스크립트 층**(ADR-0022 트윈)과 **훅 배선**뿐이다. 스킬(SKILL.md) 자체는 단위 테스트가 없고, 실동작 검증은 플러그인 설치 후 트리거해 보는 것뿐(`CLAUDE.md` 명시).

## 2. 테스트 파일 인벤토리 (16개, 전부 green)

두 종류가 있다 — **behavior 테스트**(`*.test.sh`, 픽스처 대비 단일 구현의 계약 검증)와 **parity 테스트**(`*.parity.test.sh`, 같은 픽스처에 `.sh`와 `.js`를 둘 다 돌려 출력 동일성 단언 — ADR-0022의 진짜 drift 가드).

| 파일 | 종류 | 2026-08-10 실행 결과 |
|---|---|---|
| `scripts/forge-doctor.test.sh` | behavior | 36 passed |
| `scripts/forge-doctor.parity.test.sh` | parity | PARITY OK |
| `scripts/forge-done.test.sh` | behavior | 60 passed |
| `scripts/forge-done.parity.test.sh` | parity | PARITY OK |
| `scripts/forge-hook-session-start.test.sh` | behavior | 64 passed |
| `scripts/forge-hook-session-start.parity.test.sh` | parity | PARITY OK |
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

## 4. grep 기반 검증 (테스트 스크립트 밖의 검증 층)

- **fg-loop 정지 체크**: `.forge/loop.md`의 체크는 "agent-runnable command + 기대 결과" 형태여야 하며 예시가 grep/test/build/JSON parse다(`skills/fg-loop/SKILL.md` L40·L70). 단 Goodhart 가드로 "grep 존재 확인"보다 행동/결과 단언을 요구(L72·L74).
- **fg-run UAT**: 핸드오프 전 plan 목표에 대고 검증해 STATUS `verified:`를 기록 — fg-loop 문서가 이를 "grep/test/build/JSON — same shapes as fg-run's aggressive UAT"로 지칭.
- **배포 전제 검증**(`CLAUDE.md` 배포 규칙): `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`으로 원격 버전 3곳, `awk '/^name:/'`로 `skills/*/SKILL.md` frontmatter `name` 누락 확인.

## 5. 매니페스트 JSON 검증

canonical 한 줄(`CLAUDE.md`):

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

같은 검사가 `scripts/forge-doctor.sh`/`.js`의 B9(JSON 유효성, error)·B8(버전 3곳 동기, error)로 상시화되어 있고, exit 0/1/2 계약 덕에 AI 없이 CI 게이트로 쓸 수 있다(`skills/fg-doctor/SKILL.md` "CI usage").

## 6. 커버리지

커버리지 도구 없음(측정 불가·미측정). 사실상의 커버리지 정책은: 결정론 스크립트마다 behavior+parity 쌍(§2의 비대칭 2건 제외), 트윈 존재 자체는 fg-doctor B15가 정적 검사(warning, `*.test.sh`·`*.parity.test.sh`·`*-wrapper.sh` 제외). 산문 스킬 층은 테스트 0 — 리포 변경의 다수가 이 무테스트 층에서 일어난다.

## 7. 전체 실행 한 줄

CI 스크립트가 없으므로 전체 실행은 셸 루프뿐:

```bash
for f in scripts/*.test.sh hooks/run-hook.test.sh; do bash "$f" || echo "FAIL $f"; done
```
