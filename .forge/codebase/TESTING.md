---
last_mapped_commit: d3c47b5bdc859af54e741f0524f9ed8ce2b61483
mapped: 2026-06-14
---

# TESTING

## 큰 그림 — 빌드·테스트·린트 시스템은 (거의) 없다

forge는 코드를 빌드하는 프로젝트가 아니라 Markdown/JSON으로 패키징된 Claude Code 플러그인이다. `package.json`·`Makefile`·CI·린터가 **없다.** "개발"은 문서를 편집하는 것이고, 검증은 아래 세 가지뿐이다. forge는 오랫동안 **테스트가 전혀 없었고**, 최근에야 첫 자동 테스트가 하나 생겼다(`scripts/forge-statusline.test.sh`). 이 문서는 그 한 개의 테스트와, 그 전부터 있던 수동/한 줄 검증 방법을 같이 기록한다.

## 1. 첫 테스트 — `scripts/forge-statusline.test.sh`

forge 최초의 자동 테스트로, statusline 스크립트 `scripts/forge-statusline.sh`를 검증하는 **fixture 기반 bash 테스트 하니스**다.

### 어떻게 동작하는가

각 케이스는 다음 절차를 따른다(`fixture 생성 → 스크립트 실행 → 출력 비교`):

1. `mktemp -d`로 일회용 임시 디렉터리를 만든다(`mktmp` 헬퍼). 이 디렉터리는 git 레포가 아니므로 브랜치 해석이 최상위 `.forge/`로 폴백한다.
2. 그 안에 테스트할 forge 상태를 `.forge/` fixture로 직접 구성한다(`write` 헬퍼로 `plan.md`·`run.md`·`STATUS.md`·`backlog/*.md`·`executed/*/STATUS.md`·`loop.md`·`config.json` 등을 만든다).
3. 그 임시 디렉터리를 **cwd로 두고** 스크립트를 실행한다(`run_in` = `( cd "$1" && bash "$SCRIPT" )`). 스크립트가 cwd 상대로 `.forge/`를 읽으므로 이 방식이 성립한다.
4. 스크립트가 찍는 **단일 출력 라인**을 기대값과 문자열 비교한다(`assert <name> <expected> <actual>`). 통과/실패를 카운트하고, 실패 시 기대값·실제값을 출력한다.
5. 케이스마다 `rm -rf`로 임시 디렉터리를 정리한다.

### 어떻게 실행하는가

```bash
bash scripts/forge-statusline.test.sh
```

마지막에 `N passed, M failed`를 찍고, **모두 통과하면 exit 0, 하나라도 실패하면 exit 1**이다(`[ "$fail" -eq 0 ]`로 종료 코드 결정). 검증 결과: 현재 `15 passed, 0 failed`, EXIT=0.

### 무엇을 커버하는가 (15개 케이스)

statusline 출력의 우선순위·플래그·경로 해석을 모두 덮는다:

- **idle**: `.forge` 자체가 없을 때 / `.forge`는 있지만 전부 비었을 때 → 빈 출력.
- **active(run 단계)**: `plan.md`만 있고 `run.md` 없음 → `⚒ <slug>:run`.
- **verified 변종**: `plan.md`+`run.md`+`STATUS.md`의 `verified:` 값에 따라 — `pending`(또는 STATUS 없음) → `learn ⏳`, `yes` → `learn ✓`, `failed` → `learn ✗`, `skipped`/`n/a` → 플래그 없는 `learn`.
- **slug 폴백**: plan에 `forge-slug` 주석이 없으면 파일명 stem으로 폴백(`plan.md` → `plan`).
- **executed**: 활성 슬롯 없이 `executed/`에 파킹된 작업 → `📝 N awaiting retro`.
- **backlog**: 백로그만 있을 때 → `📋 N queued`.
- **우선순위**: active > executed > backlog (셋 다 있어도 active가 이김).
- **loop**: `loop.md` 존재 시 `🔁 rN/cap` 프리픽스 — 활성 작업과 함께(`🔁 r2/3 <slug>:run`) / idle일 때 단독(`🔁 r0/3`).
- **브랜치 루트(ADR-0011)**: 실제 `git init` 후 비-기본 브랜치(`feature-x`)로 체크아웃하고 `config.json`에 `defaultBranch`를 박은 뒤, 활성 plan을 `.forge/branch/feature-x/`에 두면 그 루트를 해석하는지, 그리고 비-기본 브랜치에서 최상위 `.forge/plan.md`(stray)는 무시하는지. (git이 없으면 이 두 케이스는 skip.)

### 성격 — 일회성 하니스, 범용 프레임워크 아님

이것은 **한 스크립트를 위한 일회성 bash 하니스**일 뿐 범용 테스트 프레임워크가 아니다. 의존성은 bash+git(+`mktemp`)뿐이고, assert 헬퍼·카운터·임시 디렉터리 패턴을 직접 손으로 구현했다. 여전히 `package.json`·CI·린트는 **없다.** 새 스크립트가 생기면 같은 패턴(`scripts/<name>.test.sh`)으로 동반 테스트를 손수 작성하는 것이 현재의 관행이다.

이 statusline 작업은 **test-first(TDD)로 만들어졌다** — 테스트를 먼저 쓰고 스크립트가 그것을 통과하게 했다. forge에는 영속 TDD 모드 토글(`fg-tdd` 스킬 / ADR-0008)이 있어 `.forge/config.json`의 `tdd` 플래그를 켜면 fg-ask가 작업마다 "이 작업 TDD로?"를 기본 답으로 묻고, plan에 `<!-- tdd: on -->` 마커가 붙으면 fg-run이 test-first로 실행한다. 첫 테스트가 TDD 스타일로 나온 것은 이 맥락과 일관된다.

## 2. 매니페스트 JSON 유효성 검증 (기존)

매니페스트를 편집한 뒤 반드시 돌린다(깨지면 플러그인 설치가 실패한다):

```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

`OK`가 찍히면 통과. 이건 테스트라기보다 구문 게이트지만, 배포 절차의 검증 단계이기도 하다.

## 3. 설치·동작 테스트는 수동 (기존)

실제 스킬 동작에 대한 단위 테스트는 없다. 검증은 플러그인을 설치해 트리거해 보는 것뿐이다:

```
/plugin marketplace add gyuha/forge   (또는 로컬 경로)
/plugin install forge@forge
```

`/plugin install`·`/plugin marketplace update`는 interactive 명령이라 에이전트가 직접 실행하지 못한다(사용자가 친다). 설치는 GitHub 기본 브랜치(main)를 당기므로, 설치를 테스트하려면 변경이 main에 push되어 있어야 한다. 에이전트가 검증할 수 있는 설치 전제는 두 가지뿐 — 원격 main의 버전 3곳을 `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`로, `skills/*/SKILL.md`의 frontmatter `name`(자동 탐색 대상) 누락 여부를 `awk '/^name:/'`로 확인한다.
