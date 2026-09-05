---
last_mapped_commit: 524c6a3ee40d28bcd90334a9e4f9ca0135fca088
mapped: 2026-09-03
---

# ARCHITECTURE — forge

## 전체 패턴

forge는 코드를 빌드하는 앱이 아니라 **에이전트 호스트 플러그인 겸 자기 자신의 마켓플레이스**다. 더는 Claude Code 전용이 아니다 — **호스트 어댑터 경계**(아래 절, ADR `260903-080713`)가 생겨 Claude Code와 Codex 두 호스트가 **같은 `skills/` 트리 하나**를 로드한다(스킬 사본 0). 실행 단위는 22개의 `fg-*` 스킬(`skills/<dir>/SKILL.md`, 영문 산문 지시문)이고, 스킬들은 프로세스가 아니라 **`.forge/` 파일 상태 계약**으로 서로 이어진다. 판단(그릴링·회고 분류·divergence 평가)은 산문 스킬에, 기계적·결정론적 연산은 `scripts/forge-*.sh`/`.js` 트윈에 둔다(ADR-0022/0031 — `.forge/adr/0022-forge-scripts-convention-cross-platform-dual-dispatch.md`).

- Claude Code 플러그인 매니페스트: `.claude-plugin/plugin.json` (v0.8.0)
- 마켓플레이스 매니페스트: `.claude-plugin/marketplace.json` (`plugins[0].source: "./"` — 리포 루트가 곧 플러그인)
- **Codex 플러그인 매니페스트: `.codex-plugin/plugin.json`** — 같은 리포의 두 번째 매니페스트. `"skills": "./skills/"`로 **공유 스킬 트리를 직접 가리켜** 두 호스트가 동일 스킬을 읽는다. `interface` 블록(displayName·category·`defaultPrompt` 3개·brandColor)은 Codex 전용 표현 계층이다. 버전 동기 지점이 3곳→**4곳**으로 늘어난 원인.
- 스킬은 `skills/*/SKILL.md` frontmatter `name`으로 자동 탐색(Claude 매니페스트에 skills 필드 없음 / Codex 매니페스트는 트리 경로를 명시)
- 훅도 자동 탐색: `hooks/hooks.json` — 이제 **2개**다. 둘 다 `hooks/run-hook.cmd <name>`(bash→node polyglot 래퍼, `scripts/forge-hook-<name>.sh`→`.js` 순 디스패치·런타임 없으면 exit 0 침묵)을 통과한다.
  - `SessionStart`(matcher `startup|resume|clear|compact`, `async: false`) → `scripts/forge-hook-session-start.{sh,js}` — 미봉인 잔여가 있을 때만 세션 컨텍스트에 알림 주입(없으면 무비용·무소음).
  - `Stop`(matcher 없음 = 전체, `async: false`) → `scripts/forge-hook-stop.{sh,js}` — 무인 주행이 턴 경계를 넘게 하는 기계(아래 "무인 주행" 절).
- **빌드 시스템은 문서 사이트 하나뿐**: 루트 `package.json`(name `forge-docs`, VitePress + `vitepress-plugin-mermaid`)과 `.github/workflows/docs.yml`. 플러그인 본체(스킬 Markdown·매니페스트 JSON)에는 빌드 단계가 없다 — 이 `package.json`은 문서 도구다. `"type"` 필드를 넣으면 `scripts/*.js` 트윈(CommonJS `require`)이 전부 죽으므로 부재가 의도다(ADR `260815-094725`).

## 호스트 어댑터 경계 (ADR `260903-080713`)

forge의 가장 큰 구조 변화다. **호스트-중립 계약**은 새 최상위 `core/` 3파일에, **호스트별 차이**는 `hosts/<host>/` 3파일에 산다.

```
core/HOST.md(57줄)        # 어댑터 선택 규칙 + 8-capability 어휘 표
core/EXECUTION.md(9줄)    # 위임 계약 — 의존 슬라이스 직렬, 독립 슬라이스 병렬 가능
core/INTERACTION.md(6줄)  # 한 번에 한 질문, 구조화 선택 없으면 번호 목록
hosts/claude/{interaction,execution}.md + capabilities.json
hosts/codex/{interaction,execution}.md  + capabilities.json
```

- **어댑터가 소유하는 것은 딱 다섯 가지다** — 질문 방식(interaction) · 위임 방식(execution) · 프로젝트 에이전트 로딩 · 주행 계속 · 상태 UI. 워크플로 의미론·`.forge/` 상태 계약·게이트·결정론 스크립트는 **한 벌만** 존재하며 호스트별로 분기되지 않는다. `core/HOST.md`가 이를 명시적으로 금지한다 — *"They must not fork the state model or maintain a second Codex-specific copy of a skill."*
- **어댑터 선택 우선순위**: ① 명시적 호스트 메타데이터 → ② `PLUGIN_ROOT` = Codex → ③ Codex 메타데이터 없는 `CLAUDE_PLUGIN_ROOT` = Claude Code → ④ 식별 불가면 **순차 폴백**(평문 질문·역할 위임 없음·호스트 UI 변경 없음). 두 환경변수는 **둘 다 약한 신호**임을 문서가 자인한다(Codex도 호환용 `CLAUDE_PLUGIN_ROOT`를 줄 수 있고, `PLUGIN_ROOT`는 남이 export할 수 있는 일반명) — 확정적이지 않으면 추측하지 말고 폴백.
- **8-capability 어휘가 단일 정의**다: `structured_choice`·`spawn_parallel`·`spawn_role`·`plugin_root`·`session_start`·`prevent_stop`·`project_agents`·`status_display`. `hosts/<host>/capabilities.json`은 정확히 이 8개 키만 쓰므로 스킬이 이름으로 기계 조회할 수 있다. **`true`는 관측된 경우에만** — 미검증은 `false`가 기본이고, 모든 capability에 정의된 폴백이 있으므로 폴백 실행이 없는 도구 호출보다 항상 싸다. `false`→`true` 뒤집기는 관측 행위이며 `docs/codex.md`의 지원 표를 **같은 변경에서** 갱신해야 한다(같은 주장의 두 형태).
- **현 관측값**: Claude Code는 8개 전부 `true`. Codex는 `spawn_parallel`·`plugin_root`·`session_start`만 `true`이고 `structured_choice`·`spawn_role`·`prevent_stop`·`project_agents`·`status_display`는 `false` — 즉 Codex에서는 선택 메뉴가 번호 목록으로, 무인 주행이 **turn-bounded**로, `.claude/agents/` 역할 위임과 statusline이 부재로 떨어진다.
- **플러그인 루트 정규화**: 스킬·훅의 `${CLAUDE_PLUGIN_ROOT}`가 전부 `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}`로 바뀌었다(22개 `SKILL.md` 중 22곳 + `hooks/hooks.json` 2곳 + `hooks/run-hook.test.sh`). 스킬은 가능하면 자기 디렉터리 상대경로를 우선한다.
- **결정 계보**: 이 ADR은 "forge는 Claude Code 전용"이던 ADR-0025를 **supersede**하며, 0025는 `.forge/adr/retired/0025-claude-code-only-defer-codex-port.md`로 은퇴했다(0025가 명문화한 재검토 바 — *실사용 Codex 수요 발생* — 가 충족되어 그 절차를 밟은 결과이고 위반이 아니다). 두 길 중 **(a) 전면 도구 추상화**를 택한 것이 위 어댑터 구조다.
- **사람용 지원 표**: `docs/codex.md`·`docs/en/codex.md`(신규 이중언어 쌍) — capabilities JSON과 **같은 주장의 두 형태**이므로 한쪽만 고치면 어긋난다.

### 스킬의 `Host contract` 문단 (10곳)

capability에 의존하는 스킬은 본문에 **필요한 capability 이름과 폴백**을 적은 문단을 갖는다. 세 가지 형태로 나뉘는데 grep 패턴이 다르므로 주의:

| 형태 | 스킬 | 내용 |
| --- | --- | --- |
| `**Host contract**` (8) | `fg-map`·`fg-adversarial-review`·`fg-security` | `spawn_parallel` → **직렬 폴백**(산출물·게이트 불변, 위임만 달라짐) |
| | `fg-loop`·`fg-next` | `prevent_stop` → **turn-bounded 주행**(loop.md 유지·재트리거 재개), `fg-next`는 `structured_choice` → 번호 목록도 |
| | `fg-done`·`fg-learn`·`fg-status` | 상태 전이·해석은 호스트-중립, 확인/선택만 어댑터 경유 |
| `## Host interaction` 절 | `fg-ask` | verbatim 본문 예외라 별도 절 — 그릴링 의미론은 공유, 선택 제시 기계만 다름 |
| `**Host adapter**` | `fg-run` | `core/EXECUTION.md` + `hosts/<host>/execution.md` 참조 후 위임. Claude=Dynamic Workflow, Codex=bounded collaboration/subagent. 호스트 불명이면 직렬 실행하되 모든 상태 전이·검증 게이트 보존 |

## 핵심 데이터 흐름 — 4단계 forge 루프

```
fg-ask(질의·그릴링) ──▶ .forge/backlog/<slug>.md
fg-run(승격·실행)   ──▶ .forge/plan.md + .forge/run.md + .forge/STATUS.md (status: executed, verified: …)
fg-learn(회고)      ──▶ .forge/retro/YYMMDD-HHMMSS-slug.md (+ CONTEXT/ADR 승급)
fg-done(봉인)       ──▶ .forge/done/<날짜-slug>/ 로 아카이브, 활성 슬롯 비움 (재실행 방지)
```

- **활성 슬롯은 항상 1개** (`plan.md`/`run.md`/`STATUS.md`). plan 첫 줄 `<!-- forge-slug: ... -->`가 짝 맞춤 식별자.
- "모두 실행" 시 실행-미회고 작업은 `.forge/executed/<slug>/`에 park.
- **봉인 전 검증 게이트(ADR-0009)**: STATUS `verified:`가 `yes`/`skipped`/`n/a`여야 봉인, `pending`/`failed`는 차단 — fg-done이 회고 게이트보다 먼저 확인.
- **회고 skip(ADR-0002)**: 저-divergence면 `retro: skipped (사유)`로 회고 없이 봉인 가능.
- 상태의 원천은 **파일 위치**이고 STATUS.md는 동반 마커(활성 슬롯→`executed/`→`done/` 이동).

상세 표는 `CLAUDE.md`의 "상태 계약" 절과 `docs/state-contract.md`.

## 스킬-간 핸드오프

각 스킬은 독립 실행되고 끝에서 **핸드오프 표**(`Just did`/`Next step`/`How to start`/`Alternative` — canonical 영문 라벨, 화면은 사용자 언어 렌더)를 낸다. 형태의 단일 정의는 `skills/fg-next/HANDOFF.md`(164줄) 하나이며, 다음 단계가 실재하는 스킬이 참조한다(복붙 금지 — **14곳**: 루프 4단계 + 다음 단계가 실재하는 유틸리티 10개. 소유자 `fg-next`는 `./HANDOFF.md`로 자기 파일을 가리키므로 `fg-next/HANDOFF.md` 패턴 grep은 13만 잡고 소유자를 놓친다 — 13+1). 전환은 진술형 — "진행할까요?"로 묻지 않고 다음 트리거를 알리고 멈춘다(ADR-0015, ADR `260805-231104`). 체이닝(동의 시 자동 호출)은 fg-next 전담이며, 유일한 예외로 회고가 재그릴 권고 없이 끝나면 fg-next가 같은 호출에서 봉인까지 잇는다(ADR-0026).

**문서 드리프트(측정됨)**: `docs/skills.md:38,45`와 `docs/en/skills.md:38,45`는 적용처를 **13곳**으로 적고 유틸리티를 9개만 열거해 `fg-security`가 빠져 있다. 자체 산술도 닫히지 않는다(13 + 제외 8 = 21인데 스킬은 22개). 정답은 `CLAUDE.md`의 14곳이고 이 이중언어 쌍이 낡았다.

## 무인 주행 — 턴 경계를 넘는 기계 (ADR-0028, 개정 `260822`)

`fg-next all`·`fg-loop`가 공유하는 규율의 단일 정의는 `skills/fg-next/DRIVE.md`(89줄)이고 세 부분으로 나뉜다(Part 3 = 옵트인 태스크당 커밋 `driveCommit`, ADR `260901-213128`).

- **Part 1 — 턴 *안*에서 계속(best-effort)**: 위임된 fg-run/fg-done의 진술형 핸드오프를 턴 경계로 취급하지 않고 곧바로 다음 단계를 재도출한다. 스킬 산문만으로는 모델의 턴 양보를 막지 못한다(문서가 명시하는 한계).
- **Part 2 — 턴 경계를 넘음(호스트 capability에 조건부)**: 주행이 진입 시 `<forge-root>/drive.md` 마커(`started:` epoch · `blocked:` 카운트 · `session:` id)를 쓰고, `Stop` 훅 `scripts/forge-hook-stop.{sh,js}`가 그 마커가 살아 있고 경계 안이며 같은 세션이면 **`exit 2`**(정지 차단·대화 계속)를 반환한다. 상한은 **30분 / 50회 차단**이며, 하네스가 Stop 훅에 루프 보호를 제공하지 않으므로 이 둘이 유일한 폭주 가드다. 그 외 **모든** 경로(마커 없음·상한 초과·타 세션·파싱 실패·시계 없음·비-forge 프로젝트)는 `exit 0`으로 정지를 허용한다 — 실패는 언제나 "멈춰도 된다" 쪽으로 붕괴.
  - **훅은 given이 아니라 host capability다**(신규). `Stop`은 Claude Code 훅 이벤트이고, 다른 호스트가 `hooks/hooks.json`의 `Stop` 항목을 디스패치하는지는 *호스트 사실*로 `hosts/<host>/capabilities.json`의 `prevent_stop`에 기록된다. **`prevent_stop`이 `false`거나 호스트 불명이면 마커를 쓰지 않고** 연속 실행을 시사하지도 않는다 — 주행은 turn-bounded이고 재트리거로 재개한다. 미검증 호스트를 훅이 산 것처럼 다루면 못 지킬 무인 진행을 약속하고 마커가 지울 주체 없이 남는다(DRIVE.md가 이 문단의 존재 이유로 명시).
- **훅은 벽을 판단하지 않는다.** 벽·종료 상태에 도달한 주행이 `drive.md`를 지우는 것이 "이제 멈춰도 된다"는 표현이다(훅에 fg-status 상태 머신을 복제하지 않기 위한 의도적 분업). 하네스 `/goal`은 폴백으로 남으며, 훅이 살아 있지 않다고 볼 이유가 있을 때(방금 설치·갱신)만 제시한다. 훅은 세션 시작에 로드되므로 설치·수정은 재시작 후 적용된다.

## 항상-on 설명 규율 (ADR `260824-134246`)

`**Explaining forge**` 문단(전문용어 첫 등장 주석·목적 먼저·결론 먼저)은 `eco`에 번들하지 않고 **항상 켜져** 있으며, 22개 `SKILL.md`의 `**Language**` 블록 옆에 인라인 복제돼 있다. 복붙 금지 규율의 의도적 예외이고, 안전장치는 두 가지다 — canonical 본문이 `scripts/explaining-forge.rule.txt` **한 파일**에 살고, `forge-doctor`의 검사 **B17**이 22개 전부에서 그 본문의 **verbatim 포함**을 요구한다(severity `warning`, `grep -qF`). 형태(길이)는 `ECO.md`가, 어휘는 이 규율이 지배해 서로 지우지 않는다.

## 루프 밖 오케스트레이터·유틸리티

- `skills/fg-status/` — 읽기 전용 리포터. survey는 `scripts/forge-status.sh`/`.js`가 담당(ADR-0020).
- `skills/fg-next/` — 상태 머신으로 다음 한 단계를 도출해 곧바로 실행. `all` 모드는 백로그 소진까지 무인 주행, 대화의 벽에서만 정지(ADR-0010).
- `skills/fg-loop/` — goal 주도 한정 재계획 루프(264줄, 가장 큰 스킬). `.forge/loop.md`에 기계 검증 정지 체크·fix-forward 범위·상한(기본 3라운드)을 못 박고 run→UAT→회고 skip→봉인을 주행. 벽: no-progress·cap-exhausted·unverifiable-uat·fork·tension·safety·**stalled-waiting**·**blocked-health**·**budget-exhausted**. 최근 추가(ADR `260810` 회고 기준): 체크에 `evidence: external` 선언 시 그 체크는 실패가 아닌 **`waiting`** 상태 — `## Check progress` 원장에 `waiting ×N`으로만 기록(신규 최상위 필드 없음), `replan-round` 미소비·fix-forward 미생성, `×2` 증거 불변이면 `stalled-waiting` 벽으로 승격. `blocked-health`는 체크 명령 자체가 실행 불가(도구·인증 부재)일 때의 벽 — 주행 전 실행파일 사전점검 + 보수적 사후 승격. `budget-exhausted`(ADR-0016 개정 `260819`)는 토큰 지출 천장 — 최상위 필드 `budget-tokens`/`budget-spent · since:`(지출은 체크가 아니라 drive 소유라 원장 흡수 예외), 결정론 트윈 `scripts/forge-loop-spend.{sh,js}`가 세션+`subagents/` 트랜스크립트의 `message.usage` 4필드를 델타 합산해 경계당 1회 호출로 exit 3(초과)/4(사전예측)/5(측정불가→`blocked-health`)로 판정(`iterations[]`·`toolUseResult.usage` 제외 — 둘 다 이중 계상, 실측 1.928배였다가 정정; 두 트윈을 awk strip vs `JSON.parse`로 **다르게** 구현해 parity가 실제 교차 검증이 되게 함 — ADR-0022 개정 `260820`), `replan-round` 미소비·fix-forward 미생성, 해제는 사람이 `budget-tokens` 상향(`budget-spent` 리셋 안 함).
- `skills/fg-agenda/` — 아직 내리지 않은 결정의 대기열. `.forge/agenda.md` 단일 파일(목적지·결정된 것·열린 질문·fog·범위 밖), 열린 질문 0이면 자기 삭제. fg-next/fg-status 다음-단계 사슬에 미편입(ADR `260805-201313`).
- `skills/fg-security/` — 코드베이스 보안 감사(98줄 glue + vendored 12파일). **명명 비대칭이 구조를 지탱한다**: vendored 진입 파일이 `AUDIT.md`로 개명돼 있는데, 이는 플러그인 스킬 자동 탐색(`skills/*/SKILL.md`)이 vendored 본문을 **중첩 스킬로 잡아가지 않게** 하기 위한 것이다 — `skills/fg-security/SKILL.md`는 forge 자신의 glue(라우팅·게이트)이고, 방법론 본문은 `AUDIT.md` + 공격유형 플레이북 9종(`ATTACK-CLASSES.md`·`HUNTING.md`·`RECONNAISSANCE.md`·`WEB-PROTOCOL-AND-AUTH.md`·`CLIENT-SIDE.md`·`AI-AND-LLM.md`·`MEMORY-SAFETY-AND-BINARY.md`·`VALIDATION-AND-REPORTING.md`) + `report-schema.json`·`validate-findings.cjs`로, 업스트림(cloudflare/security-audit-skill, MIT `LICENSE`)과 byte-for-byte 유지가 규약이다(수정 금지). forge가 더하는 것은 셋뿐 — 산출물을 **리포 밖**(`~/security-audit-skill/<repo>/run-<N>/`)에 두어 취약점 목록이 커밋될 경로 자체를 없앰, 심각도 게이트(CRITICAL·HIGH 제안 / MEDIUM 제안+묶기 / LOW·INFO 계획 없음) 통과분만 사람 승인 후 fix-forward backlog plan, 무인 주행 항상 skip. 봉인 게이트 아님 — ADR `260820-215004`.
- `skills/fg-help/` — 사용법 리포터(66줄). 각 `skills/*/SKILL.md`의 frontmatter `description`을 런타임에 읽어 사용자 언어로 렌더하므로 **결정론 트윈이 없는** 유일한 리포터다(번역이 스크립트로 불가 — fg-status/fg-doctor와의 분기점). 사용법 사본 0 → 스킬을 추가해도 fg-help는 수정 불필요(ADR `260814-104534`).
- 기타: `fg-map`(코드베이스 지도→`.forge/codebase/`), `fg-quick`(경량 차선, `.forge/quick/LOG.md` 한 줄), `fg-merge`(브랜치 forge 통합), `fg-cleanup`(ADR 은퇴→`.forge/adr/retired/`), `fg-drop`(미완 작업 폐기→삭제 또는 `.forge/dropped/`), `fg-config`(`.forge/config.json` 여섯 키 통합 설정 — 옛 eco·tdd 토글 스킬 대체, ADR `260905-212045`), `fg-statusline`, `fg-doctor`(무결성 검사), `fg-adversarial-review`(6렌즈 적대 리뷰→`.forge/review.md`), `fg-agents`(`.claude/agents/<role>.md` 카드 생성 — 세션 재시작 후 로드, ADR-0024), `fg-showme`(브라우저 컴패니언 — vendored 서버 `skills/fg-showme/scripts/server.cjs` 외 4파일. 세션 디렉터리는 최상위 `.forge/showme/<세션>/`이고 **git 진입 경로가 구조적으로 없다**: `start-server.sh`가 `.forge/showme/.gitignore`에 `*` 한 줄을 자체-기록(`printf '*\n'` — 사용자 루트 `.gitignore`는 불가침, 이것이 유일 예외)하고, `stop-server.sh`가 세션 폴더를 `rm -rf`하며 마지막 세션이면 `.forge/showme/` 부모까지 제거하고, 크래시가 남긴 죽은 세션(stopped 마커 또는 죽은 PID)은 다음 시작 때 sweep한다 — ADR `260719-224442` 개정).

## 브랜치별 forge 루트 (ADR-0011)

모든 `.forge/...` 경로는 **해석된 루트** 기준: 기본 브랜치면 `.forge/`, 그 외는 `.forge/branch/<branch>/`(통째 git 추적 — `.gitignore`의 `!.forge/branch/`). 해석 규칙의 단일 정의는 `skills/fg-run/FORGE-ROOT.md`(62줄)이며 모든 루프 스킬이 참조한다. 전역 예외 2개는 항상 최상위: `.forge/config.json`, `.forge/codebase/` (+휘발 예외 `.forge/showme/`). 비기본 브랜치에서 영속 문서(CONTEXT/adr/retro)는 **읽기 overlay**(최상위+브랜치, 브랜치 우선), 쓰기는 브랜치 루트만. 통합은 `git merge` 후 fg-merge(`scripts/forge-merge.sh`/`.js`).

## 결정론 스크립트 백킹 (ADR-0020/0022/0030/0031)

각 운영 스크립트는 `.sh`(bash 1차) + `.js`(node 폴백) **트윈**이고, 동일 fixture 출력 동일성을 `*.parity.test.sh`로, 동작을 `*.test.sh`로 보장한다. `scripts/`(44파일)의 트윈 **10종**: `forge-status`, `forge-done`(세 봉인 경로 공유·게이트-우선-비파괴, ADR-0030), `forge-merge`, `forge-doctor`, `forge-hook-session-start`, `forge-hook-stop`(Stop 훅 본체), `forge-loop-spend`(토큰 지출 판정), `forge-statusline`(+`forge-statusline-full` — daleseo식 통합, ADR-0029), **`release-check`**(신규 — 아래) 및 `resolve-forge-root`. `forge-statusline-wrapper.sh`만 bash 단독(방법 1 래퍼). 스킬은 exit code로 라우팅만 한다. 판단은 절대 스크립트로 옮기지 않는다.

**`release-check` — 다중 호스트 릴리스 게이트(신규, 37줄/34줄 트윈 + parity 테스트).** 유일하게 `package.json`의 `scripts`에 wire된 forge 스크립트다(`npm run release:check` → `node scripts/release-check.js`). 검사 네 가지: ① **매니페스트 버전 4곳 동기**(`.claude-plugin/plugin.json` + `marketplace.json` 2곳 + `.codex-plugin/plugin.json`) ② Codex 매니페스트의 `skills`가 `./skills/`를 가리키는지(= 스킬 사본 0 불변식의 기계 검증) ③ 기본 훅 파일 `hooks/hooks.json` 존재 ④ **두 호스트 어댑터 6파일 전부 존재**(`hosts/{claude,codex}/{interaction.md,execution.md,capabilities.json}`). exit 0/1이라 AI 없이 CI 게이트로 쓸 수 있고, 버전 판독기(`jver`)를 `forge-doctor`의 B8과 같은 방식으로 구현해 둘이 같은 사실을 본다. `forge-doctor`의 B8도 함께 4곳 비교로 확장됐다.

**트윈은 일부러 서로 다른 방식으로 구현한다**(ADR-0022 개정 `260820`) — bash는 원시 텍스트를 grep/sed하고 node는 구조를 파싱한다. 두 사본이 같은 실수를 공유하지 않아 parity 테스트가 진짜 교차 검증이 되게 하려는 것이다(`forge-hook-stop`·`forge-loop-spend`가 그 규약대로 쓰였다).

스크립트가 읽는 **데이터 파일**도 하나 있다: `scripts/explaining-forge.rule.txt` — 두 `forge-doctor` 트윈이 B17 검사에서 verbatim 비교 기준으로 읽는 canonical 본문(위 절).

## 단일 정의 공유 문서 (복붙 금지 규율)

| 문서 | 소유 | 내용 |
| --- | --- | --- |
| `core/HOST.md` | core | 어댑터 선택 규칙 + 8-capability 어휘 — capability를 쓰는 10개 스킬 참조 |
| `core/EXECUTION.md` · `core/INTERACTION.md` | core | 위임 계약 / 질문 계약 — 호스트-중립 |
| `hosts/<host>/{interaction,execution}.md` · `capabilities.json` | hosts | 호스트별 다섯 가지(질문·위임·프로젝트 에이전트·주행 계속·상태 UI)만 |
| `skills/fg-run/FORGE-ROOT.md` | fg-run | 브랜치별 forge 루트 해석 — 전 루프 스킬 참조 |
| `skills/fg-next/HANDOFF.md` | fg-next | 핸드오프 표 형태 — 14곳 참조(나머지 8개 스킬은 종전 산문 유지) |
| `skills/fg-next/DRIVE.md` | fg-next | 무인 주행 규율(Part 1 턴 내 계속 · Part 2 forge 자체 `Stop` 훅, `/goal`은 폴백) — fg-next all·fg-loop·fg-done·fg-config 참조 |
| `skills/fg-ask/CONTEXT-FORMAT.md` · `ADR-FORMAT.md` | fg-ask | 글로서리·ADR 형식(grill-with-docs verbatim) |
| `skills/fg-run/PLAN-FORMAT.md` · `RUN-ALL.md` | fg-run | plan 형식·분할 규칙 / Run-all 절차 |
| `skills/fg-learn/RETRO-FORMAT.md` | fg-learn | 회고 형식 |
| `skills/fg-config/ECO.md` | fg-config | Eco laziness-first 규율(fg-run 서브에이전트 prepend 등) |
| `skills/fg-showme/VISUAL.md` | fg-showme | 시각 컴패니언 운용(fg-ask가 파일 참조로 소비) |
| `skills/fg-security/AUDIT.md` | (vendored) | 보안 감사 절차 — fg-security glue가 참조만, 편집 금지 |
| `scripts/explaining-forge.rule.txt` | (스크립트 데이터) | 항상-on 설명 규율 canonical 본문 — 22 `SKILL.md` 인라인 사본을 fg-doctor B17이 대조 |

## 진입점

- **명령 호출 접두가 호스트별로 다르다**: Claude Code는 `/forge:fg-*`, Codex는 `$fg-*`. 같은 스킬 파일이 두 접두로 불린다(`scripts/forge-hook-session-start.*`의 안내 문구도 두 형태를 함께 낸다).
- 사용자 트리거: 각 SKILL.md frontmatter `description`의 한/영 트리거 문구(예: "start a new task"→fg-ask, "forge next"→fg-next).
- 콜드 재진입: fg-next(상태에서 다음 단계 도출) 또는 fg-status(보고만).
- 사용법을 모를 때: `/forge:fg-help`(무인자 개요 / `<명령>` 상세).
- 자동 진입: `hooks/hooks.json`의 SessionStart 훅 — 미봉인 잔여 알림(자동 실행·자동 봉인 없음, ADR `260727-201031`). 호스트 capability `session_start`에 대응(두 호스트 모두 `true`).
- 자동 *재*진입: 같은 매니페스트의 Stop 훅 — `drive.md` 마커가 있는 동안 턴 종료를 막아 무인 주행을 잇는다(위 절). capability `prevent_stop` — Codex는 `false`라 이 진입점이 없다.
- CI: `docs/examples/github-actions-forge-check.yml`(예시)처럼 `forge-doctor`·`forge-merge`·`release-check`가 AI 없이 exit code 게이트로 사용 가능. 리포 자신의 유일한 실동 워크플로는 `.github/workflows/docs.yml`(문서 사이트 배포)이다 — `docs/**`·`package.json`·`package-lock.json` 변경 시 발동해 `docs/index.html`(랜딩, `/forge/`)과 VitePress 빌드(`/forge/docs/`)를 한 Pages 아티팩트로 합쳐 배포한다.

## 설계 불변 (두 기둥)

1. **그릴링은 Dynamic Workflow 안에 넣지 않는다** — 워크플로우는 사용자 입력을 못 받으므로 fg-ask류 대화는 반드시 세션 대화로.
2. **문서는 산출물이 아니라 루프의 연료** — 계획의 용어가 실행 기준, 회고의 학습이 다음 계획의 출발점. 영속 문서(`.forge/CONTEXT.md`·`adr/`·`retro/`·`codebase/`)는 git 추적 화이트리스트, 휘발 상태는 gitignore.
