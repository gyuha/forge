---
last_mapped_commit: 6146cae539151b65850e1e2609bdf8f7e78a1e47
mapped: 2026-09-11
---

# TESTING

이 문서는 현재 작업 트리의 검증 구현과 배선만 기록한다.

## 테스트 체계

- Jest, Vitest, pytest 같은 테스트 프레임워크나 통합 test runner는 없다. 검증 파일은 실행 가능한 셸 스크립트와 Windows 전용 Node 스크립트다.
- 저장소에는 테스트 파일이 22개 있다. `scripts/`와 `hooks/`에 `*.test.sh` 21개, `hooks/run-hook.windows.test.js` 1개가 있다.
- 일반 동작 테스트는 임시 디렉터리에 최소 `.forge/` 상태나 가짜 저장소를 만들고 대상 스크립트를 실행한 뒤 문자열, exit code, 파일 존재 여부와 파일 내용을 비교한다.
- 테스트는 `pass`/`fail` 카운터와 `assert`, `assert_grep`, `assert_nogrep` 같은 로컬 helper를 사용한다. 프레임워크 assertion은 Windows 테스트의 Node 내장 `assert`만 사용한다.
- fixture는 `mktemp -d "${TMPDIR:-/tmp}/<접두>.XXXXXX"` 형태로 격리하고 종료 전 제거한다. git 동작이 필요한 테스트는 임시 저장소와 로컬 bare remote를 만든다.
- ANSI 색상은 상태줄 테스트에서 제거하고 텍스트 구조를 비교한다. 시간 의존 출력은 `FORGE_SL_NOW`, `--now`, `--completed`, `--sealed-id` 같은 입력으로 고정한다.

## Bash/Node 트윈 parity

- 최상위 운영 트윈 11쌍 모두 parity 테스트가 있다: `scripts/forge-doctor.parity.test.sh`, `scripts/forge-done.parity.test.sh`, `scripts/forge-hook-session-start.parity.test.sh`, `scripts/forge-hook-stop.parity.test.sh`, `scripts/forge-loop-spend.parity.test.sh`, `scripts/forge-merge.parity.test.sh`, `scripts/forge-status.parity.test.sh`, `scripts/forge-statusline.parity.test.sh`, `scripts/forge-statusline-full.parity.test.sh`, `scripts/release-check.parity.test.sh`, `scripts/resolve-forge-root.parity.test.sh`.
- 읽기 전용 트윈은 같은 fixture에서 두 구현을 실행해 정규화된 출력과 exit code를 비교한다. `scripts/forge-doctor.parity.test.sh`, `scripts/forge-status.parity.test.sh`, `scripts/forge-statusline*.parity.test.sh`가 이 방식이다.
- 상태 변경 트윈은 fixture를 두 벌 만들어 각각 실행한 뒤 출력·exit code와 최종 파일 트리를 비교한다. `scripts/forge-done.parity.test.sh`, `scripts/forge-merge.parity.test.sh`, `scripts/forge-loop-spend.parity.test.sh`가 이 방식이다.
- parity 테스트는 두 구현이 함께 잘못되어도 통과하는 경우를 막기 위해 명시적 예상값이나 sentinel도 검사한다. `scripts/release-check.parity.test.sh`와 `scripts/resolve-forge-root.parity.test.sh`는 실행 결과가 실제 기대값과도 일치해야 통과한다.
- `scripts/forge-loop-spend.test.sh`는 fixture JSONL을 Node `JSON.parse`로 별도 계산한 ground truth와 비교한다. 반복 usage 구조, 도구 출력 속 문자열, 중첩 subagent transcript, 시간 경계를 함께 넣어 단순 정규식 합산의 과계상을 검출한다.

## 기능별 fixture 테스트

| 대상 | 주 테스트 | 확인하는 구현 경계 |
| --- | --- | --- |
| 훅 배선·dispatcher | `hooks/run-hook.test.sh`, `hooks/run-hook.windows.test.js` | `hooks/hooks.json` 구조, 셸 command 실제 해석, decoy 환경변수 내성, 실행 비트, Bash→Node fallback, 프로젝트 cwd, Windows exit code 전파 |
| 상태 진입 알림 | `scripts/forge-hook-session-start.test.sh`, `scripts/forge-hook-session-start.parity.test.sh` | 깨끗한 상태의 무출력, 활성/parked/loop 상태, 브랜치 루트, CRLF·한글, 입력 주입 방지, 출력 크기 제한, session 소유권, Bash/Node 동일성 |
| 무인 주행 Stop 훅 | `scripts/forge-hook-stop.test.sh`, `scripts/forge-hook-stop.parity.test.sh` | marker·세션·30분·50회 경계, counter 갱신, 파싱/쓰기 실패 시 정지 허용, stderr와 exit code 동일성 |
| 상태 조사 | `scripts/forge-status.parity.test.sh` | 활성·backlog·parked·done 표, priority/part/slug 정렬, verification 단계 판정, 정확한 retro 매칭, CRLF·한글·과거 디렉터리 형식 |
| 작업 봉인 | `scripts/forge-done.test.sh`, `scripts/forge-done.parity.test.sh` | 검증/회고 gate, 비파괴 거절, active·parked·half-sealed 처리, 중복, branch root, 경로 순회 방지, 정확한 retro 매칭, running marker 경쟁·복원 |
| 브랜치 상태 통합 | `scripts/forge-merge.test.sh`, `scripts/forge-merge.parity.test.sh` | 진행 중 상태 거절, ADR ID 충돌·참조 변경, retired ID 보존, retro·done·backlog 이동, 번호 재부여, CONTEXT 충돌, dropped 이동 |
| 토큰 지출 계측 | `scripts/forge-loop-spend.test.sh`, `scripts/forge-loop-spend.parity.test.sh` | transcript 합산, baseline/누적/idempotence, 상한·사전예측, 다중 task 평균, CRLF, 잘못된 입력, ledger 변경 동일성 |
| 상태줄 fragment | `scripts/forge-statusline.test.sh`, `scripts/forge-statusline.parity.test.sh` | 단계·검증 표시, queue와 loop, eco/tdd 표시, full/compact 밀도, 구분자, 한글·Windows 경로, Bash/Node 출력 |
| 통합 상태줄 | `scripts/forge-statusline-full.test.sh`, `scripts/forge-statusline-full.parity.test.sh` | 모델·effort·cwd·git·context/rate-limit·비용/라인, 시간·bar 경계, 중첩 JSON, fragment 결합, full/compact 출력 |
| append wrapper | `scripts/forge-statusline-wrapper.test.sh` | 기존 statusline 보존, stdin 재전달, idle 출력, 설치 위치 기준 동반 파일 탐색 |
| 무결성 검사 | `scripts/forge-doctor.test.sh`, `scripts/forge-doctor.parity.test.sh` | 상태 오류 A군, 문서/매니페스트 B군, severity exit code, ADR ID, 트윈 존재, description, 공통 설명 문단, handoff·debug·showme·host 계약 정합, 자기참조 `§N` 인용(B21) |
| 릴리스 gate | `scripts/release-check.parity.test.sh` | 버전 네 값, Codex skills 경로, hook 파일, 동적 host 목록, adapter 파일, capability JSON·문서 키, 오류 순서와 트윈 parity |
| forge root | `scripts/resolve-forge-root.parity.test.sh` | 비-git fallback, 기본/비기본/중첩 브랜치, `defaultBranch`, 저장소 하위 cwd, 두 구현의 실제 기대 경로 |

## 대체 구현 실행

- 일부 기능 테스트는 환경변수로 대상 구현을 교체해 같은 fixture를 Node 트윈에도 적용한다: `FGDOCTOR_IMPL`, `FGDONE_IMPL`, `FGHOOK_IMPL`, `FGLS_IMPL`, `FGMERGE_IMPL`, `FGSL_FULL_IMPL`.
- parity 전용 테스트는 Bash와 Node를 한 번에 직접 호출하므로 별도 구현 선택 변수가 없다.
- `hooks/run-hook.windows.test.js`는 Windows가 아니면 성공 상태로 skip한다. Windows에서는 실제 `cmd.exe`로 `hooks/run-hook.cmd`의 Node fallback과, Bash가 있으면 Bash 경로의 exit 0/1/2 전파를 확인한다.

## 문서형 평가

- `skills/fg-loop/tests/resume-scenarios.md`는 실행 스크립트가 아니라 격리된 대화 평가용 행동 fixture다. 저장된 wall, scope 승인, 동일 증거 재확인, budget 소진, `fg-next all`, 외부 증거 waiting, active failure 재개의 기대 행동과 금지 행동을 표로 기록한다.
- 이 문서형 평가는 실제 프로젝트에 명령을 실행하지 않으며, end-to-end 호스트 실행을 증명하지 않는다고 파일 자체가 명시한다.

## 실행 방법

- 각 테스트는 개별 명령으로 실행한다. 예: `bash scripts/forge-done.test.sh`, `bash scripts/forge-done.parity.test.sh`, `bash hooks/run-hook.test.sh`.
- Node 트윈을 같은 기능 fixture로 검사하는 예는 `FGDONE_IMPL="$PWD/scripts/forge-done.js" bash scripts/forge-done.test.sh`다.
- 릴리스 전 기계 검사는 `npm run release:check`이며 실제 명령은 `node scripts/release-check.js`다. Bash 구현과 parity는 별도 명령 `bash scripts/release-check.sh`, `bash scripts/release-check.parity.test.sh`로 실행한다.
- 문서 사이트는 `npm run docs:build`로 빌드한다. `package.json`에는 전체 테스트를 실행하는 `test` script가 없다.

## CI 배선

- `.github/workflows/release-check.yml`은 Linux에서 `scripts/release-check.sh`, `scripts/release-check.js`, `scripts/release-check.parity.test.sh`를 실행한다. 별도 Windows job은 `hooks/run-hook.windows.test.js`를 실행한다.
- 해당 workflow는 `.claude-plugin/**`, `.codex-plugin/**`, `core/**`, `hosts/**`, `hooks/**`, `scripts/release-check.*`, 호스트 문서와 workflow 자체가 바뀔 때 동작한다.
- `.github/workflows/docs.yml`은 Node 22에서 `npm ci`, `npm run docs:build`를 실행한 뒤 랜딩과 VitePress 결과를 하나의 Pages artifact로 조립하고 필수 파일 존재를 `test -f`로 확인한다.
- 나머지 fixture·parity 테스트와 `scripts/forge-doctor.*`는 GitHub Actions에서 자동 실행되지 않는다.

## 문서 사이트 수동 확인 범위

- `npm run docs:build`는 VitePress 내부 상대 링크와 빌드 가능성을 확인한다. 외부 `https://` 링크의 응답 여부는 이 빌드가 검사하지 않는다.
- `CLAUDE.md`는 문서 변경 시 다크 모드 Mermaid 대비, 모든 이미지 요청의 HTTP 200, 외부 링크 실재를 별도 확인하도록 규정한다.
- `docs/index.html`과 `docs/.vitepress/config.mts`의 사이트 경로는 `/forge/` 랜딩과 `/forge/docs/` 문서 사이트로 나뉜다. `.github/workflows/docs.yml`의 artifact 검사도 이 배치를 전제로 한다.

## 테스트 작성 패턴

- 새로운 fixture는 성공 출력만 보지 않고 실패 exit code와 비변경 조건을 함께 단언한다. 변경 도구의 gate 테스트는 실행 전후 파일을 `cmp`하거나 별도 fixture tree를 `diff`한다.
- 새 검사는 양성 케이스 하나만 두지 않고 검출기가 실제로 보고 있음을 증명하는 음성 케이스를 함께 둔다. `scripts/forge-doctor.test.sh`의 B21은 케이스 3개 — 심어 둔 자기참조는 exit 1과 메시지로 잡고, 올바른 교차 절 인용과 `§12` 접두 충돌은 발견 0건이어야 한다. 양성만 있었으면 모든 입력에 0을 반환하던 초기 awk 구현이 "실제 저장소 발견 0건"과 구분되지 않았다. 이 파일의 fixture는 `pass`/`fail` 카운터로 집계되며 현재 127개가 통과한다.
- 음수 검사는 명령 자체가 실행됐다는 근거와 함께 사용한다. `skills/fg-run/PLAN-FORMAT.md`는 정확한 개수 검사의 기존 값, 금지 문자열의 합법적 사용, fail-open, 외부 primitive 실제 동작, 문자열 존재 대신 소비자 동작을 확인하도록 요구한다.
- 수정용 새 plan에서 원래 실패가 기계적으로 재현 가능하면 프로젝트의 영속 테스트나 동등한 실행 가능 검사와 red→green 증거를 포함한다. 이 규칙의 단일 정의는 `skills/fg-run/PLAN-FORMAT.md`에 있다.
- CRLF, 다국어, 빈 상태, 오래된 형식, 중복 필드, 접미사 충돌, 잘못된 JSON, 경로 구분자, 큰 입력과 제어 문자는 여러 fixture의 공통 경계값이다.
- 두 구현이 같은 오류를 내는 것만으로 통과하지 않도록 명시적 예상 결과를 둔다. 특히 parity 테스트는 빈 출력의 우연한 일치와 같은 fail-open을 막는 sentinel 또는 expected value를 사용한다.
