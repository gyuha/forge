---
last_mapped_commit: 2059a08bee17a9fbb97e6e938958f5ed813bdb2d
mapped: 2026-06-26
---

# TESTING

forge에는 **빌드·테스트·린트 시스템이 없다**(`CLAUDE.md` "이 리포가 무엇인가"). package.json, Makefile, CI 없음. "개발"은 Markdown/JSON 편집이고, 검증은 다음 갈래뿐이다: (1) 매니페스트 JSON 유효성 한 줄, (2) frontmatter `name` 누락 검사, (3) 실행 코드(bash 스크립트)의 fixture 기반 bash 테스트 + 패리티 테스트, (4) 스킬 동작은 실제 설치해서 트리거해보는 것(install-and-trigger). 그 위에 forge 자신의 무결성 health check(fg-doctor)와 루프의 작업 검증 메커니즘(fg-tdd, ADR-0009 UAT 게이트)이 얹힌다. **단위 테스트 프레임워크는 존재하지 않으며, 만들지 말 것.**

## JSON manifest validity (the `node -e JSON.parse` check)

매니페스트는 깨지면 설치가 실패하므로, 편집 후 반드시 유효성을 확인한다. node 한 줄(`CLAUDE.md`):

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

배포 절차 JSON 검증 단계에서도 이 한 줄을 쓴다. 원격 main 검증은 `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`으로 버전 3곳을 확인한다.

## Frontmatter `name` check (the `awk '/^name:/'` check)

스킬은 디렉터리명이 아니라 frontmatter의 `name`으로 자동 탐색된다(`CLAUDE.md` "패키징 구조"). `name`이 없으면 그 스킬은 탐색되지 않는다. 누락 검사:

```bash
awk '/^name:/' skills/*/SKILL.md
```

배포 후 설치 전제 확인에서 이 한 줄을 쓴다.

## Bash test harness for the executable scripts

실행 코드는 `scripts/` 아래 bash/node 스크립트뿐이며, 각 스크립트에 fixture 기반 bash 테스트가 짝으로 있다(외부 프레임워크 없이 순수 bash). ADR-0022에 의해 `.sh`와 `.js` 트윈이 동일 출력을 보장해야 하며, 패리티 테스트(`*.parity.test.sh`)가 그 동치를 강제한다.

### forge-status 테스트

- `scripts/forge-status.sh` / `scripts/forge-status.js` — fg-status용 결정론적 survey + 6열 task 테이블(ADR-0020).
- **패리티 테스트**: `scripts/forge-status.parity.test.sh`. 동일 fixture에 두 구현을 돌려 출력 동일성을 단언한다(`set -euo pipefail`로 fixture 오류 시 즉시 abort). 커버 케이스: 빈 상태, 활성/파킹/백로그/done이 섞인 populated 상태, `config.json` defaultBranch 존재 시, 빈 quick LOG(grep -c regression), CRLF state 파일(Windows), 멀티바이트(Hangul) slug의 바이트 정렬 테이블, 백로그 정렬 순서(priority→part→slug 계약).

```bash
bash scripts/forge-status.parity.test.sh    # 패리티 OK 시 exit 0
```

### forge-statusline 테스트

- `scripts/forge-statusline.sh` / `scripts/forge-statusline.js` — statusline 한 줄 fragment.
- **기능 테스트**: `scripts/forge-statusline.test.sh`. temp dir에 throwaway `.forge/` 상태를 만들고 그 dir을 cwd로 스크립트를 돌려 단일 출력 라인을 기대값과 비교(자체 `assert`/`mktmp`/`write` 헬퍼). 커버: 빈/idle 상태, active plan 단계(run/learn), `STATUS.md`의 `verified:` 플래그 매핑(yes→✓, failed→✗, pending→⏳, skipped/n-a→무), slug fallback, executed/backlog 카운트, precedence(active > executed > backlog), `loop.md` 인디케이터(🔁 r/N), ADR-0011 브랜치 루트 해석, stdin 세션 JSON의 `cwd`/`workspace.current_dir` 처리와 $PWD fallback, nonexistent cwd fallback. git 없는 환경에서는 브랜치 케이스를 자동 skip한다.
- **패리티 테스트**: `scripts/forge-statusline.parity.test.sh`. 세션 JSON을 stdin으로 파이프해 두 구현의 출력을 비교 + 기대값과도 비교(`set -euo pipefail`). escaped(Windows-style) cwd 디코딩 케이스 포함.

```bash
bash scripts/forge-statusline.test.sh
bash scripts/forge-statusline.parity.test.sh   # STATUSLINE PARITY OK 시 exit 0
```

### forge-statusline-wrapper 테스트

- `scripts/forge-statusline-wrapper.sh` — 기존 statusline과 합성하는 bash 전용 wrapper.
- **기능 테스트**: `scripts/forge-statusline-wrapper.test.sh`. 가짜 CLAUDE config dir(실제 fragment 복사 + stub original statusline)을 만들어 세션 JSON을 파이프하고 합성 출력을 검증한다(original 먼저, forge 행 append, idle일 때 빈 행 없음, original이 stdin으로 세션 JSON 수신).

```bash
bash scripts/forge-statusline-wrapper.test.sh
```

### resolve-forge-root 테스트

- `scripts/resolve-forge-root.sh` / `scripts/resolve-forge-root.js` — 브랜치별 forge-root 경로 해석(ADR-0011).
- **패리티 + 정확성 테스트**: `scripts/resolve-forge-root.parity.test.sh`. 두 구현이 동일 경로를 출력하고 그 경로가 FORGE-ROOT.md 규칙과 일치하는지 단언(`set -euo pipefail`). 커버: non-git dir(`.forge` fallback), 기본 브랜치(main)(`<top>/.forge`), 비기본 브랜치(`<top>/.forge/branch/<branch>`), 슬래시 포함 중첩 브랜치명(`feature/x`), `config.json` defaultBranch 커스터마이즈, git repo의 서브디렉터리에서 실행(top-level anchor 확인 — ADR-0022 리뷰 regression).

```bash
bash scripts/resolve-forge-root.parity.test.sh  # RESOLVE PARITY OK 시 exit 0
```

### 전체 실행

```bash
bash scripts/forge-status.parity.test.sh
bash scripts/forge-statusline.test.sh
bash scripts/forge-statusline.parity.test.sh
bash scripts/forge-statusline-wrapper.test.sh
bash scripts/resolve-forge-root.parity.test.sh
```

의존성은 bash(+git)뿐 — jq/JSON 파서를 쓰지 않고 `sed`로 방어적 파싱한다(ADR-0017). 각 테스트는 독립 temp dir을 생성·삭제해 순서 의존성이 없다.

## No general unit-test system — real testing is install-and-trigger

스킬(`fg-*`)의 실제 동작에는 단위 테스트가 없다. 검증 수단은 설치해서 트리거해보는 것뿐(`CLAUDE.md`):

```
/plugin marketplace add gyuha/forge   (또는 로컬 경로)
/plugin install forge@forge
```

설치는 GitHub 기본 브랜치(main)를 당기므로, 설치를 테스트하려면 main에 push되어 있어야 한다. `/plugin install`·`/plugin marketplace update`는 interactive 명령이라 에이전트가 직접 실행하지 못한다(사용자가 친다).

## fg-doctor — read-only integrity health check (ADR-0019)

자동 테스트 프레임워크의 빈자리를 메우는 forge 자신의 무결성 점검 스킬이다(`skills/fg-doctor/SKILL.md`). **읽기 전용 — 아무것도 쓰지 않고 자동 수정·자동 실행 안 함.** 위반을 severity(error/warning/info)와 항목별 actionable fix hint와 함께 보고하며, 실제 수정은 사람이 fg-quick(사소)/fg-ask(비사소)로 한다.

체크 두 그룹:

- **Group A — 상태 계약**(`.forge/`, 브랜치 루트 해석 적용): A1 active-slot 단일·고아 없음(orphaned run.md/STATUS.md = error), A2 STATUS 필드 유효성(`status`/`verified`/`retro` 값 검사), A3 slug 페어링(plan↔STATUS↔retro)·retro 필드 정합, A4 half-sealed done/(STATUS가 `status: done`이 아니면 error), A5 executed/ 정합, A6 backlog 마커·task 번호 유일성(중복 번호 = error).
- **Group B — 문서/매니페스트 정합**(repo 루트, git 추적): B7 매니페스트 버전 3곳 동기, B8 매니페스트 JSON 유효성, B9 skill frontmatter `name`, B10 skill 개수↔매니페스트 설명 개수 단어, B11 CLAUDE.md 스킬 목록 완전성, B12 README 이중언어 동기, B13 ADR 번호 연속성·cross-ref(retired/ 고려, 브랜치 오버레이 합집합으로 평가).

fg-doctor는 `scripts/*.sh`마다 `.js` 트윈 존재를 **정적 검사**한다(ADR-0022 — 동치는 패리티 테스트로 보장). `.forge/dropped/`는 스캔 대상에서 제외(ADR-0021).

fg-status는 "어디까지 했나"를, fg-doctor는 "상태가 건강한가"를 본다.

## UAT verification gate (ADR-0009) — the run → verify step

봉인 전 검증 게이트가 forge 루프의 run→verify 단계다(`.forge/adr/0009-verification-gate-before-seal.md`). 루프 순서는 run → verify → learn → done.

- fg-run 핸드오프가 plan 목표에 대고 UAT를 수행해 `.forge/STATUS.md`의 `verified:` 필드를 기록한다.
- **봉인 가능** 값: `yes` / `skipped (사유)` / `n/a (사유)`. **차단** 값: `pending`(미검증) / `failed (사유)`(검증했으나 깨짐).
- fg-done은 검증 게이트를 회고 게이트보다 **먼저** 확인하고(no-seal-without-verification), 봉인 가능 값이 아니면 봉인하지 않는다.
- `pending`은 fg-run 검증 전용 재진입(재실행 없이 UAT만), `failed`는 fg-run의 parked-failed 회수(fix-and-re-run) 또는 fg-ask 재그릴로 라우팅. `failed`은 fresh re-run으로 봉인 가능 값에 재검증될 때만 봉인되며 waiver로 통과시키지 않는다.
- Run all은 작업별 UAT를 파킹 전 수행한다(sealable만 파킹, `failed`은 active slot에 남김).

이 `verified:` 값은 statusline에도 반영된다 — `scripts/forge-statusline.sh`가 `STATUS.md`의 `verified:`를 읽어 learn 단계 플래그(yes→✓, failed→✗, pending→⏳, skipped/n-a→무)로 표시하고, `scripts/forge-statusline.test.sh`가 그 매핑을 케이스로 검증한다.

## TDD support via fg-tdd / `.forge/config.json`

forge는 영속 TDD 모드 토글을 제공한다(ADR-0008, `.forge/adr/0008-tdd-support-and-config-surface.md`). 이건 forge 루프 단계가 아니라 `.forge/config.json`의 `tdd` 키 하나만 뒤집는 on-demand 유틸리티다(`skills/fg-tdd/SKILL.md`). `fg-tdd on/off`, 인자 없으면 현재 상태만 보고, 기본 `false`(파일 없으면 off). plan의 `<!-- tdd: on -->` 마커가 켜져 있으면 fg-run이 test-first로 실행한다(슬라이스마다 실패 테스트 작성 → 구현 → 통과). `.forge/config.json`은 브랜치 루트 해석의 전역 예외라 모든 브랜치에서 항상 최상위 `.forge/config.json`이며 git 추적된다(ADR-0011 / `skills/fg-run/FORGE-ROOT.md`).
