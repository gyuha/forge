---
last_mapped_commit: d3c47b5bdc859af54e741f0524f9ed8ce2b61483
mapped: 2026-06-14
---

# STACK — 기술 스택 / 런타임 / 산출물 형식

## 무엇으로 만들어졌는가

forge는 코드를 빌드하는 프로젝트가 아니라 **Claude Code 플러그인**이다. 산출물은 대부분 Markdown(`SKILL.md`, `*-FORMAT.md`)과 JSON(매니페스트)이며, 런타임 호스트는 Claude Code 플러그인 시스템이다. 코드를 컴파일하거나 서비스를 띄우는 대상 코드베이스가 아니다.

### 언어 / 형식 분포

- **Markdown** — 스킬 본문(`skills/*/SKILL.md`)·형식 문서(`*-FORMAT.md`)·문서(`README.md`, `README.ko.md`, `CLAUDE.md`, `CHANGELOG.md`, `docs/forge-vs-loop-engineering.md`). 절대 다수.
- **JSON** — 매니페스트 2종(`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`). 런타임 `.forge/config.json`은 lazy 생성이라 현재 리포에 **없다**.
- **Bash** — `scripts/` 아래 실행 가능한 셸 스크립트 2개(아래 "실행 런타임 코드" 참조).

스킬 본문·형식 문서는 영문으로 작성하되, 스킬이 사용자에게 출력하는 언어는 사용자 언어를 따른다(각 SKILL.md에 명시).

## 실행 런타임 코드 (NEW — 이전 지도와 달라진 핵심 사실)

이전 지도는 "런타임 코드 없음 / 빌드 없음 / 테스트 시스템 없음"이라 기술했다. 이는 이제 **부분적으로 거짓**이다. forge는 첫 실행 가능 런타임 코드를 갖췄다 — `scripts/` 디렉터리.

- **`scripts/forge-statusline.sh`** (실행권한 있음, `#!/usr/bin/env bash`) — forge 루프 진행 상태를 한 줄로 출력하는 statusline fragment. 의존성은 **bash + git 뿐**(JSON/jq 파싱 없이 `sed`로 파일을 직접 읽는다). `git rev-parse`로 브랜치를 판별해 ADR-0011 forge 루트(`​.forge/` 또는 `.forge/branch/<branch>/`)를 해석하고, `loop.md`·`plan.md`·`run.md`·`STATUS.md`·`executed/`·`backlog/`를 읽어 active > executed > backlog 우선순위로 단일 세그먼트를 찍는다(idle이면 아무것도 출력 안 함). `.forge/config.json`이 있으면 거기서 `defaultBranch`를 읽되, 없으면 `main`으로 폴백한다. **표시 전용**이며 fg-status의 다음-단계 우선순위 머신을 재현하지 않는다(ADR-0017).
- **`scripts/forge-statusline.test.sh`** (`#!/usr/bin/env bash`) — 위 스크립트의 fixture 기반 테스트 하니스. 임시 디렉터리에 일회용 `.forge/` 상태를 만들고 스크립트를 그 cwd에서 실행해 출력 한 줄을 기댓값과 비교한다. 실행: `bash scripts/forge-statusline.test.sh` (전부 통과 시 exit 0). 현재 **15 케이스 전부 통과** 확인. git 미설치 환경에서는 브랜치-루트 케이스를 skip한다. 외부 테스트 프레임워크 없이 자체 `assert` 함수로 구동.

**여전히 참인 것:** 빌드 시스템 없음, 린트 없음, CI 없음. 나머지 13개 스킬은 전부 Markdown 지시문이다. 즉 "실행 코드 0"은 더 이상 사실이 아니지만, "build/lint/CI 없음 + 스킬은 Markdown"은 그대로 유지된다. 이 statusline 스크립트가 유일한 예외다.

## 런타임 호스트 — Claude Code 플러그인

forge는 Claude Code 플러그인 호스트 위에서 동작한다. 스킬은 `skills/<name>/SKILL.md`로 **자동 탐색**되며, 스킬 식별자는 디렉터리명이 아니라 frontmatter의 `name` 필드다.

### 매니페스트 (단일 리포 = 플러그인 + 마켓플레이스)

- **`.claude-plugin/plugin.json`** — 플러그인 매니페스트. `version: 0.4.10`(리포에서 직접 확인), `name: forge`, MIT 라이선스. `skills/`가 자동 탐색되므로 `skills` 필드는 생략돼 있다.
- **`.claude-plugin/marketplace.json`** — 이 리포를 마켓플레이스로 등록. `metadata.version: 0.4.10`, `plugins[0].version: 0.4.10`, `plugins[0].source: "./"`(루트가 곧 플러그인). 설명에 "Fourteen fg-* skills"로 14개 스킬 명시.

버전은 3곳(`plugin.json`의 `version`, `marketplace.json`의 `metadata.version`·`plugins[0].version`)에 동기 유지되며, 현재 셋 다 `0.4.10`이다.

매니페스트 JSON 유효성 검증(편집 후 필수):
```bash
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```
이 검증 한 줄이 `node`를 쓰는 유일한 지점이며, 런타임 의존이 아니라 개발자 검증 도구일 뿐이다(설치·실행에 node 불필요).

## 셸 의존성

- **git** — 브랜치별 forge 루트 해석(ADR-0011)에 필수. `forge-statusline.sh`가 `git rev-parse --abbrev-ref HEAD`로 현재 브랜치를 판별하고, 비-git/detached HEAD면 최상위 `.forge/`로 폴백한다. 다수 스킬도 git 조작을 전제하지만 직접 호출하는 코드는 statusline 스크립트와 fg-merge 안내뿐이다.
- **bash** — statusline 스크립트·테스트 하니스 실행. POSIX `sed`/`find`/`ls`/`wc`/`mktemp` 사용.
- **node** — 매니페스트 JSON 검증과 배포 절차의 원격 매니페스트 확인용(개발 편의 도구). 플러그인 자체는 node 런타임을 요구하지 않는다.

## 스킬 인벤토리 (14개)

`skills/` 자동 탐색 대상. 모두 frontmatter `name`을 가진다(전수 확인). 디렉터리당 보조 형식 문서가 붙는 경우가 있다.

| 스킬 | 루프 내/밖 | 부속 형식 문서 |
| --- | --- | --- |
| `fg-ask` | 루프 ① 질의·계획·그릴링 | `CONTEXT-FORMAT.md`, `ADR-FORMAT.md` |
| `fg-run` | 루프 ② 실행 | `PLAN-FORMAT.md`, `RUN-ALL.md`, `FORGE-ROOT.md` |
| `fg-learn` | 루프 ③ 회고 | `RETRO-FORMAT.md` |
| `fg-done` | 루프 ④ 완료·봉인 | — |
| `fg-map` | 루프 밖 (코드베이스 지도) | — |
| `fg-quick` | 루프 밖 (경량 차선) | — |
| `fg-status` | 루프 밖 (읽기 전용 리포터) | — |
| `fg-next` | 루프 밖 (다음 단계 오케스트레이터) | — |
| `fg-loop` | 루프 밖 (goal 주도 재계획 루프) | — |
| `fg-merge` | 루프 밖 (브랜치 forge 통합) | — |
| `fg-cleanup` | 루프 밖 (ADR 은퇴) | — |
| `fg-tdd` | 루프 밖 (TDD 모드 토글) | — |
| `fg-eco` | 루프 밖 (위임 모델 티어링 토글) | — |
| `fg-statusline` | 루프 밖 (statusline 설치 — NEW) | — (스크립트는 `scripts/`에 있음) |

**`fg-statusline`이 신규 추가된 14번째 스킬이다.** 이 스킬은 `${CLAUDE_PLUGIN_ROOT}/scripts/forge-statusline.sh`를 `~/.claude/forge-statusline.sh`(안정 경로)로 복사하고 `settings.json`의 `statusLine` 키에 배선한다. 기존 statusLine이 있으면 교체하지 않고 `~/.claude/forge-statusline-wrapper.sh`로 감싸 별도 행으로 추가한다(원본 출력 보존).

형식 정의는 한 벌만 존재하며 소유 스킬 디렉터리에 둔다: `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-learn/RETRO-FORMAT.md`. 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`로 참조하고 복사하지 않는다. `skills/fg-run/FORGE-ROOT.md`는 브랜치별 루트 해석의 단일 정의이며 모든 루프 스킬이 참조한다.

## 설정 파일

- **`.claude-plugin/plugin.json`** · **`.claude-plugin/marketplace.json`** — 위 매니페스트.
- **`.forge/config.json`** — 런타임 설정(`tdd`, `eco`, `defaultBranch` 등). **lazy 생성**이라 현재 리포에 파일이 없다(fg-tdd/fg-eco가 처음 토글될 때 생성). 모든 브랜치에서 항상 최상위 `.forge/`에 위치하는 전역 예외(ADR-0011). `forge-statusline.sh`가 존재 시 `defaultBranch`를 읽는다.
- **`.gitignore`** — `.forge/*`를 기본 제외하되 영속 문서만 화이트리스트로 추적(`!.forge/CONTEXT.md`, `!.forge/adr/`, `!.forge/retro/`, `!.forge/codebase/`, `!.forge/config.json`, `!.forge/branch/`). `.claude/worktrees`·`.planning/`·`.DS_Store`도 제외.

## 디렉터리 레이아웃 (실제 확인)

```
forge/
  .claude-plugin/      plugin.json, marketplace.json
  scripts/             forge-statusline.sh (실행 런타임), forge-statusline.test.sh (테스트)
  skills/              14개 스킬 디렉터리 (각 SKILL.md + 일부 *-FORMAT.md)
  docs/                forge-vs-loop-engineering.md
  .forge/              런타임 상태 + 영속 문서 (codebase/는 이 매핑이 채우는 중)
  CLAUDE.md  README.md  README.ko.md  CHANGELOG.md  .gitignore
```
