---
last_mapped_commit: 0b8423d0dbcb836a75dcaf951afe993a97c8eb25
mapped: 2026-10-25
---

# ARCHITECTURE — forge

## 시스템 형태

forge는 실행 애플리케이션이 아니라 에이전트 호스트가 읽어 실행하는 Markdown 스킬 플러그인이다. 사용자 동작의 주 구현은 `skills/<skill>/SKILL.md`에 있고, 반복 가능해야 하는 파일 연산과 검사는 `scripts/forge-*.sh` 및 `scripts/forge-*.js`에 있다. 저장소는 동시에 Claude Code 마켓플레이스이므로 플러그인 정의와 배포 정보도 함께 보관한다.

구조는 다음 계층으로 나뉜다.

1. 패키징 계층 — `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`
2. 호스트 중립 계약 — `core/HOST.md`, `core/EXECUTION.md`, `core/INTERACTION.md`
3. 호스트 어댑터 — `hosts/claude/`, `hosts/codex/`, `hosts/opencode/`, `hosts/pi/`
4. 행동 계층 — `skills/*/SKILL.md`와 같은 디렉터리의 보조 계약 문서
5. 결정론 계층 — `scripts/`의 Bash/Node 트윈과 `hooks/`의 훅 디스패처
6. 상태 및 영속 자료 — `.forge/`
7. 사용자 문서 — `docs/`, `README.md`, `README.ko.md`

## 패키징과 로딩

- Claude Code용 플러그인 메타데이터는 `.claude-plugin/plugin.json`에 있고, 저장소 자체를 마켓플레이스로 노출하는 정의는 `.claude-plugin/marketplace.json`에 있다.
- Codex용 메타데이터는 `.codex-plugin/plugin.json`에 있으며 `skills: "./skills/"`로 동일한 스킬 트리를 가리킨다.
- opencode 전용 매니페스트는 없다. 설치 후 검색 경로에 연결하는 절차는 `docs/opencode.md`와 `docs/en/opencode.md`에 기록되어 있다.
- Pi도 별도 매니페스트·확장 없이 기존 `skills/` 디렉터리를 패키지로 읽어 `/skill:fg-*`로 노출한다. 절차는 `docs/pi.md`·`docs/en/pi.md`, 로딩 검증은 설치된 Pi SDK를 쓰는 `scripts/pi-host.test.mjs`에 있다.
- 저장소 로컬 유틸리티 스킬은 실체를 `.claude/skills/<name>/`에 두고 Codex용 `.codex/skills/<name>`을 심볼릭 링크로 잇는다(현재 `.codex/skills/issue-triage`). 배포 스킬 트리 `skills/`와는 분리된다.
- 스킬은 디렉터리명이 아니라 각 `skills/*/SKILL.md` YAML frontmatter의 `name` 필드로 식별된다.
- 프로젝트 전용 Claude Code 에이전트 카드는 `.claude/agents/*.md`에 있으며, `skills/fg-run/SKILL.md`가 호스트 지원 시 계획 슬라이스와 카드의 `description`을 맞춰 역할 위임에 사용한다.

## 호스트 추상화

`core/HOST.md`는 어댑터 선택, 플러그인 루트 처리, capability 어휘를 정의한다. 현재 capability 키는 `structured_choice`, `spawn_parallel`, `spawn_role`, `plugin_root`, `session_start`, `prevent_stop`, `project_agents`, `status_display`, `event_wake`의 9개다. 각 호스트의 관측값은 `hosts/claude/capabilities.json`, `hosts/codex/capabilities.json`, `hosts/opencode/capabilities.json`, `hosts/pi/capabilities.json`에 같은 키 집합으로 저장된다. `hosts/pi/capabilities.json`은 현재 9개 키 전부 `false`이며, Pi 식별은 `core/HOST.md`에 따라 명시적 호스트 메타데이터로만 한다.

호스트별 문서는 다음 사항만 구현한다.

- 질문 UI: `hosts/<host>/interaction.md`
- 위임 시작, 수집, 취소와 실행 핸들: `hosts/<host>/execution.md`
- 지원 여부: `hosts/<host>/capabilities.json`

작업 선택, 상태 전이, 결과 통합, 검증 게이트는 호스트 어댑터에 복제되지 않는다. 해당 규칙은 공유 `skills/`와 `core/`에 남는다. 위임이 없는 호스트는 `core/EXECUTION.md`에 따라 동일한 슬라이스를 직렬 실행한다.

## 작업 제어 흐름

기본 실행 흐름은 세 스킬이 파일 상태를 전달하는 형태다(ADR `.forge/adr/261024-191024-fold-retro-into-seal.md`로 별도 회고 단계가 봉인에 흡수됨).

```text
skills/fg-ask/SKILL.md
  -> <forge-root>/backlog/<slug>.md          (저장 직후 forge-plan-lint 자가 점검)
  -> skills/fg-run/SKILL.md                  (승격 직후 forge-plan-lint 게이트)
  -> <forge-root>/plan.md + run.md + STATUS.md
  -> skills/fg-done/SKILL.md                 (step 0 follow-up 수집, step 0b 회고 판정)
  -> <forge-root>/retro/<id>-<slug>.md (필요 시) + <forge-root>/followups.md
  -> <forge-root>/done/<timestamp>-<slug>/
```

- `skills/fg-ask/SKILL.md`는 대화를 통해 계획을 작성하고 `skills/fg-run/PLAN-FORMAT.md` 형식으로 backlog에 둔다.
- `skills/fg-run/SKILL.md`는 계획을 활성 슬롯으로 승격한 뒤 `scripts/forge-plan-lint.sh`(bash 없으면 `.js`)로 구조를 검사하고(exit 1이면 실행하지 않음, exit 0의 `WARN`은 표시 후 진행, exit 2는 읽기 불가 정지), 린트는 slug·슬라이스·depends·마커 값 외에 fix-forward(`generated-by`)·`playbook: bug-fix` 계획의 `eval` 마커(E6/E7), `playbook: refactor` 계획의 `pin` 마커와 모든 슬라이스가 pin 슬라이스에 직·간접 의존하는 순서(E8/E9), 계획당 playbook 1개(E5)를 검사한다(형식 단일 정의는 `skills/fg-run/PLAN-FORMAT.md`의 Playbooks 절, ADR `.forge/adr/261025-005132-bug-fix-refactor-playbooks.md`). `core/EXECUTION.md`와 선택된 `hosts/<host>/execution.md`를 통해 실행한다. 무인 주행에서 린트 error는 `skills/fg-next/ALL-MODE.md`·`skills/fg-loop/SKILL.md`의 벽으로 처리된다.
- 위임 시작과 결과 기록 사이에는 `<forge-root>/running.md`가 존재한다. 복구 절차는 `skills/fg-run/RECOVERY.md`가 소유한다.
- 실행 결과와 계획 차이는 `<forge-root>/run.md`, 검증 및 회고 상태는 `<forge-root>/STATUS.md`에 기록된다.
- `skills/fg-done/SKILL.md`는 봉인 전에 step 0(대상 작업의 follow-up 후보를 run/retro 끝의 표식 블록으로 정규화)과 step 0b(회고 판정 — `run.md`의 `⚠` 슬라이스 줄·`## Failed attempts`·`## Rulings`, STATUS `fix-rounds`, `review.md`의 `disposition: accepted`를 신호로 읽어 회고 로그 작성 또는 `--skip-retro` 결정)를 수행한 뒤 `scripts/forge-done.sh` 또는 `scripts/forge-done.js`를 호출한다. 스크립트는 검증 게이트(exit 3)·회고 게이트(exit 4 — 회고 파일 부재, 또는 스크립트가 직접 읽는 신호(`run.md`의 `⚠` 슬라이스 줄·`## Failed attempts`·`## Rulings` 항목, STATUS `fix-rounds` ≥ 1)가 있는데 `--skip-retro`를 받으면 `GATE_RETRO skip-refused signals=…`; `review.md` 신호는 스킬만 판정)·중복(exit 5)을 무변경으로 거부하고, 통과 시 `scripts/forge-followups.sh collect`로 후보를 원장에 모은 뒤 staging 복사→STATUS 마감→rename 게시→원본 제거 순으로 봉인한다(exit 6은 I/O 실패).
- 대화형 봉인만 승급 후보를 한 번 묻고, 무인 봉인은 회고 로그 첫 줄 `<!-- auto-retro: <seal path> -->`로 남긴다. `skills/fg-learn/SKILL.md`는 루프 단계가 아니라 이런 미검토·`retro: skipped` 작업과 `<!-- promotion-pending -->` 로그를 모아 승급하는 루프 밖 유틸리티다.

`skills/fg-status/SKILL.md`는 `scripts/forge-status.sh` 또는 `scripts/forge-status.js`의 조사를 바탕으로 현재 상태를 표시하지만(작업 표의 단계 열은 `ask`/`run`/`done`이며 봉인된 작업은 `done ✔`; `--json` 출력 스키마는 `skills/fg-status/STATUS-JSON.md`, 그 안의 follow-up 집계는 `forge-followups.sh list`에서 온다) 다음 단계 판정은 스킬 본문에 둔다. `skills/fg-next/SKILL.md`는 그 판정을 참조해 다음 스킬을 호출한다. 공통 핸드오프 출력 형식은 `skills/fg-next/HANDOFF.md`에 한 번 정의되어 있다.

## 상태 저장 경계

forge 상태 루트의 단일 규칙은 `skills/fg-run/FORGE-ROOT.md`에 있고, 결정론 구현은 `scripts/resolve-forge-root.sh`와 `scripts/resolve-forge-root.js`다.

- 기본 브랜치에서는 `<forge-root>`가 `.forge/`다.
- 다른 브랜치에서는 `<forge-root>`가 `.forge/branch/<branch>/`다.
- `.forge/config.json`·`.forge/codebase/`·`.forge/rules/`·`.forge/showme/`·`.forge/monitor/`는 브랜치와 무관하게 최상위 경로를 사용한다.
- follow-up 원장 `<forge-root>/followups.md`는 브랜치별이며(오버레이 없음), 형식은 `skills/fg-learn/FOLLOWUPS-FORMAT.md`, 쓰기는 `scripts/forge-followups.sh`/`.js`(`add`·`collect`·`take`·`dismiss`·`list`)가 담당한다. fg-merge 통합 시 task 참조가 재매핑된다.
- 비기본 브랜치의 영속 자료 읽기는 브랜치 쪽 `.forge/branch/<branch>/CONTEXT.md`, `adr/`, `retro/`를 최상위 `.forge/` 위에 겹쳐 읽는다.
- 비기본 브랜치 상태의 기본 브랜치 통합은 `skills/fg-merge/SKILL.md`와 `scripts/forge-merge.sh`/`.js`가 수행한다.

기본 브랜치의 휘발 상태는 `.gitignore`가 제외하고 `.forge/CONTEXT.md`, `.forge/adr/`, `.forge/retro/`, `.forge/followups.md`, `.forge/codebase/`, `.forge/rules/`, `.forge/config.json`, `.forge/branch/`만 추적 대상으로 다시 포함한다.

## 자동 주행과 훅

`skills/fg-next/ALL-MODE.md`는 여러 작업을 연속 처리하는 절차를, `skills/fg-next/DRIVE.md`는 턴 내부 진행·Stop 훅·선택적 작업별 커밋 규율을 제공한다. `skills/fg-loop/SKILL.md`는 별도의 `<forge-root>/loop.md` 계약을 사용해 검사 충족까지 제한된 재계획을 수행한다.

`skills/fg-loop/`는 조건부 분할 구조를 쓴다. `loop.md`가 있으면 재개이므로 `INQUIRY.md`를 읽지 않고 `skills/fg-loop/SKILL.md` 안의 `Resume preflight`부터 실행한다. `loop.md`가 없을 때만 `skills/fg-loop/INQUIRY.md`를 읽으며, 그 파일은 신규 목표 계약을 확정하는 절차(정지 체크·fix-forward 범위·재계획 상한·`budget-tokens`·`## Tasks` 멤버십·초기 backlog 작성)만 담는다. 주행 중에 적용되는 규칙 — `## Check progress` 원장의 `×N` 집계, `waiting` 처리, Reflexion 기록 규칙, `/goal` 기반 주행 진입 — 은 모두 `SKILL.md`의 §2~§4에 있으므로 재개 경로는 `SKILL.md` 한 파일로 완결된다. 자동 주행을 시작할 수 있는 경우 `<forge-root>/drive.md`가 생성되고 모든 종료 경로에서 제거된다.

`hooks/hooks.json`은 두 제어 이벤트를 `hooks/run-hook.cmd`로 전달한다.

- `SessionStart` -> `scripts/forge-hook-session-start.sh` 또는 `.js`: 미봉인 실행 상태를 세션 컨텍스트에 알린다.
- `Stop` -> `scripts/forge-hook-stop.sh` 또는 `.js`: 같은 세션의 유효한 `drive.md`가 있을 때 제한된 횟수와 시간 안에서 정지를 차단한다.

같은 파일은 관측 전용으로 `SessionStart`·`Stop`·`SessionEnd`·`UserPromptSubmit`·`SubagentStart`·`SubagentStop`·`PreToolUse`·`PostToolUse`·`PostToolUseFailure`·`PermissionRequest`·`Notification`에 `node` exec-form 핸들러(`scripts/forge-hook-monitor.js`, timeout 3)를 추가로 건다. 이 핸들러는 제어 결정을 출력하지 않는다.

`hooks/run-hook.cmd`는 Bash를 우선 사용하고 사용할 수 없으면 Node 구현으로 넘긴다. Stop 훅은 벽 상태를 판정하지 않으며, 주행 측이 `drive.md`를 제거하는 것으로 정지 허용을 표현한다.

## 결정론 스크립트 계층

기계적 기능은 같은 basename의 Bash 기본 구현과 Node 대체 구현으로 쌍을 이룬다.

- 상태 조사: `scripts/forge-status.sh`, `scripts/forge-status.js`
- 상태 무결성 검사: `scripts/forge-doctor.sh`, `scripts/forge-doctor.js` (B17은 `scripts/*.rule.txt` 각각 — 현재 `scripts/explaining-forge.rule.txt`·`scripts/evidence-and-candor.rule.txt` — 의 한 줄 본문이 모든 `skills/*/SKILL.md`에 verbatim 포함됐는지 대조, ADR `.forge/adr/261025-005131-evidence-and-candor-always-on.md`)
- 작업 봉인: `scripts/forge-done.sh`, `scripts/forge-done.js`
- 계획 구조 린트: `scripts/forge-plan-lint.sh`, `scripts/forge-plan-lint.js` (exit 0 통과/1 error/2 읽기 불가)
- follow-up 원장: `scripts/forge-followups.sh`, `scripts/forge-followups.js` (parity 테스트 대신 `scripts/forge-followups.test.js`)
- 브랜치 상태 통합: `scripts/forge-merge.sh`, `scripts/forge-merge.js`
- 루프 토큰 사용량 판정: `scripts/forge-loop-spend.sh`, `scripts/forge-loop-spend.js`
- 세션 시작 및 정지 훅: `scripts/forge-hook-session-start.*`, `scripts/forge-hook-stop.*`
- 상태 표시: `scripts/forge-statusline.*`, `scripts/forge-statusline-full.*`
- 릴리스 검사: `scripts/release-check.sh`, `scripts/release-check.js`
- 상태 루트 해석: `scripts/resolve-forge-root.sh`, `scripts/resolve-forge-root.js`

각 트윈의 stdout, stderr, 종료 코드는 `scripts/*.parity.test.sh`가 비교한다. 기능별 fixture 검사는 `scripts/*.test.sh`에 있다. `scripts/forge-statusline-wrapper.sh`는 사용자 기존 statusline 명령을 보존하면서 forge 출력을 덧붙이는 단일 Bash 보조 스크립트다. 반대로 Node 전용(트윈 없음)인 것은 모니터 계열 `scripts/forge-monitor.js`·`scripts/forge-hook-monitor.js`와 부작용 없는 상태 조회 모듈 `scripts/forge-status-query.js`다.

## 시각 동반 기능

`skills/fg-showme/SKILL.md`와 `skills/fg-showme/VISUAL.md`는 `skills/fg-showme/scripts/server.cjs`를 실행해 로컬 브라우저용 시각 화면과 응답 이벤트를 중계한다. HTML 골격과 클라이언트 보조 코드는 `skills/fg-showme/scripts/frame-template.html`, `skills/fg-showme/scripts/helper.js`에 있다. 세션 산출물은 전역 휘발 경로 `.forge/showme/<session>/`에 생성된다.

## 문서 사이트와 CI

문서 사이트는 플러그인 실행계층과 분리되어 있다. `package.json`은 VitePress 문서 명령과 `release:check`만 제공하며 플러그인 본체의 빌드 단계는 없다.

- VitePress 구성: `docs/.vitepress/config.mts`
- 한국어 문서: `docs/*.md`
- 영어 문서: `docs/en/*.md`
- 정적 랜딩 페이지: `docs/index.html`
- Pages 빌드·배포: `.github/workflows/docs.yml`
- 매니페스트·호스트 계약 릴리스 게이트: `.github/workflows/release-check.yml`
- 모니터 기능·배선 검사: `.github/workflows/monitor-check.yml` (`scripts/forge-monitor*`·`scripts/forge-status*`·`hooks/**`·`skills/fg-monitor/**` 등 경로에 발동, macOS·Linux·Windows)

`.github/workflows/docs.yml`은 정적 랜딩을 `/forge/`, VitePress 산출물을 `/forge/docs/`에 조립한다. `.github/workflows/release-check.yml`은 두 릴리스 검사 트윈과 parity 검사를 별도 의존성 설치 없이 실행하고, Windows에서는 `hooks/run-hook.windows.test.js`로 훅 종료 코드 전달을 확인한다.

## fg-monitor 런타임

`skills/fg-monitor/SKILL.md`가 진입점이다. 모니터 CLI/서버는 `scripts/forge-monitor.js`, 수집 훅은 `scripts/forge-hook-monitor.js`다. `forge-status-query.js`의 순수 상태 조회를 기존 CLI와 공유하며 화면에서 다음 행동을 실행하지 않는다. 시작 프로젝트·브랜치·세션을 고정하고 `.forge/monitor/`에 격리한다. 정적 UI는 빌드 없는 `scripts/forge-monitor-ui/`(`index.html`·`app.js`·`style.css`)다.

## 규칙 채택

`skills/fg-rules/SKILL.md`는 채택한 규칙을 최상위 `.forge/rules/`에 쓰고, 기존 프로젝트 지침에서 규칙 색인을 읽도록 하는 연결 절차를 `skills/fg-rules/CONNECTIONS.md`에 둔다.
