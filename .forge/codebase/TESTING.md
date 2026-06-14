---
last_mapped_commit: b3b267b7da443c3fbb0ca093c4fc4221a70ef7ab
mapped: 2026-06-14
---

# TESTING

forge에는 **빌드·테스트·린트 시스템이 없다**(`CLAUDE.md` "이 리포가 무엇인가"). package.json, Makefile, CI 없음. "개발"은 Markdown/JSON 편집이고, 검증은 아래 세 갈래뿐이다: (1) 매니페스트 JSON 유효성, (2) 유일한 실행 코드인 statusline 스크립트의 bash 테스트, (3) 스킬 동작은 실제 설치해서 트리거해보는 것(install-and-trigger). 그 위에 forge 루프 자신이 작업 산출물을 검증하는 메커니즘(fg-tdd, ADR-0009 UAT 게이트)이 얹힌다.

## JSON manifest validity

매니페스트는 깨지면 설치가 실패하므로, 편집 후 반드시 유효성을 확인한다. node 한 줄(`CLAUDE.md`):

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

배포 절차 3단계(JSON 검증)에서도 이 한 줄을 쓴다. 원격 main 검증은 `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`로 버전 3곳을 확인하고, frontmatter `name` 누락은 `awk '/^name:/' skills/*/SKILL.md`로 확인한다.

## Bash test harness for the statusline scripts

유일한 실행 코드는 `scripts/forge-statusline.sh`(forge 진행 상태를 한 줄로 출력하는 fragment)와 `scripts/forge-statusline-wrapper.sh`(기존 statusline과 합성하는 wrapper)다. 각각 fixture 기반 bash 테스트가 짝으로 있다. 외부 프레임워크 없이 순수 bash로 작성됐다.

- `scripts/forge-statusline.test.sh` — 19 케이스. 각 케이스가 temp dir에 throwaway `.forge/` 상태를 만들고, 그 dir을 cwd로 스크립트를 돌려 단일 출력 라인을 기대값과 비교한다(자체 `assert`/`mktmp`/`write` 헬퍼). 커버 범위: 빈/idle 상태, active plan 단계(run/learn), `STATUS.md`의 `verified:` 플래그 매핑(yes→✓, failed→✗, pending→⏳, skipped/n-a→무), slug fallback, executed/backlog 카운트, precedence(active > executed > backlog), `loop.md` 인디케이터, ADR-0011 브랜치 루트 해석, stdin 세션 JSON의 `cwd`/`workspace.current_dir` 처리와 $PWD fallback. git 없는 환경에서는 브랜치 케이스를 자동 skip한다.
- `scripts/forge-statusline-wrapper.test.sh` — 5 케이스. 가짜 CLAUDE config dir(실제 fragment 복사 + stub original statusline)을 만들어 세션 JSON을 파이프하고 합성 출력을 검증한다. 커버 범위: original 라인이 먼저·forge 행이 아래로 append, idle일 때 빈 행을 안 만듦(단일 라인), original이 stdin으로 세션 JSON을 받는지(stub이 바이트 수를 echo).

실행:

```bash
bash scripts/forge-statusline.test.sh          # → 19 passed, 0 failed
bash scripts/forge-statusline-wrapper.test.sh  # → 5 passed, 0 failed
```

종료 코드는 전부 통과 시 0, 하나라도 실패 시 1. 두 스크립트 모두 의존성은 bash(+git)뿐 — jq/JSON 파서를 쓰지 않고 `sed`로 방어적 파싱한다(ADR-0017). 최근 실행 결과 양쪽 모두 통과 확인됨(19/0, 5/0).

## No general unit-test system — real testing is install-and-trigger

스킬(`fg-*`)의 실제 동작에는 단위 테스트가 없다. 검증 수단은 설치해서 트리거해보는 것뿐(`CLAUDE.md`):

```
/plugin marketplace add gyuha/forge   (또는 로컬 경로)
/plugin install forge@forge
```

설치는 GitHub 기본 브랜치(main)를 당기므로, 설치를 테스트하려면 main에 push되어 있어야 한다. `/plugin install`·`/plugin marketplace update`는 interactive 명령이라 에이전트가 직접 실행하지 못한다(사용자가 친다).

## TDD support via fg-tdd / `.forge/config.json`

forge는 영속 TDD 모드 토글을 제공한다(ADR-0008, `.forge/adr/0008-tdd-support-and-config-surface.md`). 이건 forge 루프 단계가 아니라 `.forge/config.json`의 `tdd` 키 하나만 뒤집는 on-demand 유틸리티다(`skills/fg-tdd/SKILL.md`).

- `fg-tdd on` → `tdd: true`, `fg-tdd off` → `tdd: false`, 인자 없으면 현재 상태만 보고. 기본값은 `false`(파일 없으면 off로 취급). 쓸 때 다른 키는 보존한다.
- `.forge/config.json`은 브랜치 루트 해석의 전역 예외다 — 모든 브랜치에서 항상 최상위 `.forge/config.json`(ADR-0011 / `skills/fg-run/FORGE-ROOT.md`). git 추적됨(`.gitignore`가 `!.forge/config.json` 화이트리스트).
- 이건 팀 공유 프로젝트 기본값이다. 개별 작업은 fg-ask가 작업마다 "이 작업 TDD로?"를 이 설정을 기본 답으로 묻고, plan에 `<!-- tdd: on|off -->`를 기록해 override한다.
- 실행: plan의 `tdd` 마커가 on이면 **fg-run이 test-first로 실행**한다 — 각 슬라이스마다 실패하는 테스트 작성 → 구현 → 통과시키기.

## UAT verification gate (ADR-0009) — the run → verify step

봉인 전 검증 게이트가 forge 루프의 run→verify 단계다(ADR-0009, `.forge/adr/0009-verification-gate-before-seal.md`). 루프 순서는 run → verify → learn → done.

- fg-run 핸드오프가 plan 목표에 대고 UAT를 수행해 `.forge/STATUS.md`의 `verified:` 필드를 기록한다.
- **봉인 가능** 값: `yes` / `skipped (사유)` / `n/a (사유)`. **차단** 값: `pending`(미검증) / `failed (사유)`(검증했으나 깨짐).
- fg-done은 검증 게이트를 회고 게이트보다 **먼저** 확인하고(no-seal-without-verification), 봉인 가능 값이 아니면 봉인하지 않는다.
- `pending`은 fg-run 검증 전용 재진입(재실행 없이 UAT만), `failed`는 fg-run의 parked-failed 회수(fix-and-re-run) 또는 fg-ask 재그릴로 라우팅. `failed`은 fresh re-run으로 봉인 가능 값에 재검증될 때만 봉인되며 waiver로 통과시키지 않는다.
- Run all은 작업별 UAT를 파킹 전 수행한다(sealable만 파킹, `failed`은 active slot에 남김).

이 `verified:` 값은 statusline에도 반영된다 — `scripts/forge-statusline.sh`가 `STATUS.md`의 `verified:`를 읽어 learn 단계 플래그(yes→✓, failed→✗, pending→⏳, skipped/n-a→무)로 표시하고, `scripts/forge-statusline.test.sh`가 그 매핑을 케이스로 검증한다.
