---
last_mapped_commit: 8aaed407ae96e0d59f87de00424a18a652577950
mapped: 2026-06-27
---

# CONCERNS — 취약 지점과 알려진 불일치

forge는 코드·테스트·린트가 없는 **Claude Code 플러그인**이다 — 산출물은 전부 손으로 편집하는 Markdown(`SKILL.md`·`*-FORMAT.md`)과 JSON(매니페스트)이다. 따라서 여기서의 "위험"은 런타임 버그가 아니라 **계약·정합성의 조용한 부패**(consistency/contract rot)다. 여러 파일에 분산된 사실이 한쪽만 갱신되어 어긋나는 것이 유일하면서도 가장 흔한 실패 모드다. 이를 능동적으로 검사하는 단 하나의 장치가 `skills/fg-doctor/SKILL.md`이며, 아래 항목은 대부분 그 체크리스트(그룹 A·B)와 짝이 맞는다.

## 매니페스트 — 부패가 가장 빈번한 곳

- **버전 3곳 동기 (fg-doctor B7, error).** 버전 문자열이 세 곳에 중복된다: `.claude-plugin/plugin.json`의 `version`, `.claude-plugin/marketplace.json`의 `metadata.version`, 같은 파일 `plugins[0].version`. 현재 셋 다 `0.5.3`으로 일치. 하나라도 어긋나면 깨진 릴리스다. 배포 절차(`CLAUDE.md` "배포 규칙")가 이 셋을 함께 범프하도록 못 박혀 있지만 수동이라 빠뜨리기 쉽다.
- **매니페스트 JSON 유효성 (fg-doctor B8, error).** 두 매니페스트가 JSON으로 파싱돼야 한다 — 깨지면 설치가 실패한다. 편집 후 반드시 `node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"` 로 확인한다. 현재 두 파일 모두 파싱 통과.
- **스킬 개수 단어 정합 (fg-doctor B10, warning).** `.claude-plugin/marketplace.json`의 `plugins[0].description`에 스킬 개수가 영어 단어로 박혀 있다: 현재 `"Eighteen fg-* skills … Fourteen more sit outside the loop"`(루프 4 + 루프 밖 14 = 18). `.claude-plugin/plugin.json`의 `description`은 스킬을 나열하되 개수 단어를 쓰지 않는다. 스킬을 추가·삭제하면 `marketplace.json`의 "Eighteen"·"Fourteen"을 **반드시 손으로 갱신**해야 하며, 빠뜨리면 조용히 어긋난다.
- **두 description의 역할이 다르다 (`CLAUDE.md` 배포 규칙).** `marketplace.json`의 `metadata.description`은 **루프(ask·plan → execute → retro → done)만** 정의하는 한 줄 태그라인이므로 루프 밖 유틸리티(fg-map·fg-drop 등)를 넣으면 안 된다. 반대로 `plugins[].description`(과 `plugin.json`의 `description`)은 전체 스킬 목록을 담으므로 루프 밖 스킬도 반드시 반영한다.

## 스킬 자동 탐색과 목록 완전성

- **`name:` frontmatter 누락 (fg-doctor B9, error).** 스킬은 디렉터리명이 아니라 `skills/*/SKILL.md` frontmatter의 `name`으로 식별·자동 탐색된다. `name`이 빠지면 그 스킬은 설치돼도 탐색되지 않는다. 확인: `awk '/^name:/' skills/*/SKILL.md`. 현재 18개 모두 `name:` 존재.
- **CLAUDE.md 스킬 목록 완전성 (fg-doctor B11, warning).** `skills/` 아래 모든 스킬이 `CLAUDE.md`의 루프 설명 또는 "루프 밖 스킬" 문단에 등장해야 한다. 디스크에 있으나 CLAUDE.md에 없으면 위반이다. 현재 디스크의 18개(fg-adversarial-review, fg-agents, fg-ask, fg-cleanup, fg-doctor, fg-done, fg-drop, fg-eco, fg-learn, fg-loop, fg-map, fg-merge, fg-next, fg-quick, fg-run, fg-status, fg-statusline, fg-tdd) 모두 `CLAUDE.md:44`의 서술에 포함돼 있다.
- **다중 카탈로그 동기화 지점.** 스킬 추가·삭제 시 한 번에 갱신해야 하는 파일은 8곳: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`(`plugins[0].description`의 카운트 단어 포함), `README.md`, `README.ko.md`(이중언어 쌍), `docs/skills.md`, `CLAUDE.md` 인라인 스킬 목록, `.forge/codebase/STRUCTURE.md`(fg-map 생성물이나 수동 갱신 시), `skills/fg-doctor/SKILL.md`의 카운트 예시 단어. 이 8곳이 한 번의 편집으로 동기되지 않으면 fg-doctor가 경고를 낸다.

## README 이중 언어 드리프트 (fg-doctor B12, warning)

- `README.md`(영문)와 `README.ko.md`(한글)는 같은 내용의 번역 쌍이다. 한쪽을 갱신하면 **반드시** 다른 쪽을 같은 변경으로 함께 갱신해야 한다(`CLAUDE.md` "README 이중 언어 동기화"). 현재 두 파일의 스킬 카탈로그 행 수는 일치한다.
- 이 쌍의 유지는 `manifest-doc-syncer` 도메인 에이전트 카드(`.claude/agents/manifest-doc-syncer.md`)의 주요 책임 중 하나다.

## 현재 미커밋 상태

- `git status --short`: 유일한 untracked 항목은 `.forge/config.json` — eco 모드 토글 파일이다. 이 파일은 `.gitignore`의 화이트리스트(`!.forge/config.json`)로 추적 **가능**하나, 현재 세션의 eco 설정(`{"eco": true}`)이 커밋되지 않은 채 워킹 트리에만 있다. eco 설정은 세션별 사용자 선택이므로 이 상태는 의도적일 수 있다.
- 이 외 staged/unstaged 변경은 없다. 마지막 릴리스(`v0.5.3`, 커밋 `8aaed40`) 이후 추가된 미커밋 기능 작업은 없다.

## `.claude/agents/` 도메인 에이전트 카드 (ADR-0024)

- 현재 이 리포의 `.claude/agents/` 디렉터리에 두 카드가 존재한다: `manifest-doc-syncer.md`와 `skill-author.md`. 둘 다 `fg-agents`가 생성한 이 프로젝트(forge 자체)의 도메인 에이전트다.
- **세션 시작 시 1회 로드 제약 (ADR-0024).** 이 카드들은 세션이 시작될 때만 로드된다 — 세션 중 카드를 수정하거나 새로 만들어도 동적으로 반영되지 않는다. fg-run이 `agentType`으로 호출하려면 **세션 재시작이 필수**다.
- **플러그인 매니페스트에 선언되지 않는다.** `.claude/agents/` 카드는 `/plugin install`로 배포되지 않는다 — 이 두 카드는 forge 플러그인 자체의 개발 편의를 위한 **리포 로컬 자산**이며, 매니페스트(`plugin.json`·`marketplace.json`)에 선언된 플러그인 에이전트가 아니다. fg-agents가 대상 프로젝트의 `.claude/agents/`에 생성하는 카드와 동형이지만, 이 리포 밖으로 배포되지 않는다(ADR-0025 맥락: forge는 Claude Code 전용 네이티브 플러그인으로 유지).

## fg-ask 자기완결 3파일의 verbatim 분리 (의도된 불일치)

- `skills/fg-ask/`는 grill-with-docs 원본을 그대로 옮긴 자기완결 3파일(`SKILL.md` + `CONTEXT-FORMAT.md` + `ADR-FORMAT.md`)이다. **SKILL.md 본문은 영문 verbatim 영역**이고, forge 루프 연결(백로그 산출·fg-run 핸드오프·회고 환류)은 맨 아래 "Forge integration (minimal)" 섹션에만 둔다. 이 verbatim 본문과 Forge integration 섹션은 독립적으로 움직이므로, 둘 중 하나만 고치면 입출력 계약이 깨진다(`CLAUDE.md` "현재 상태의 알려진 불일치").

## `.forge/` 상태 계약 부패 (fg-doctor 그룹 A)

손으로 편집되는 휘발 상태라 다음이 조용히 깨질 수 있다. 전체 계약은 `docs/state-contract.md`에 있다.

- **고아 `run.md`/`STATUS.md` (A1, error).** 활성 슬롯 `plan.md`는 0 또는 1개. `run.md`/`STATUS.md`가 있는데 `plan.md`가 없으면 고아다.
- **STATUS 필드 손상 (A2, error/warning).** 모든 `STATUS.md`에서 `status` ∈ {executed, done}, `verified` ∈ {yes…, skipped…, n/a…, pending, failed…}, `retro`는 pending·skipped…·retro 경로여야 한다. **주의: 레거시 `done/` 파일(~2026-06-12 이전 봉인)은 대시 리스트 형식(`- status: done`)** 이라 필드 매칭 시 `^[[:space:]]*-?[[:space:]]*` 접두를 허용해야 한다 — 엄격한 `^status:`는 레거시 done을 전부 half-sealed로 오탐한다(체커 버그, `skills/fg-doctor/SKILL.md` "STATUS field format" 주석).
- **slug 페어링 불일치 (A3, error).** plan 첫 줄 `<!-- forge-slug: <slug> -->` ↔ `STATUS.md`의 `slug:` ↔ retro 파일명 `retro/*-<slug>.md`가 일치해야 한다. 이 "retro 파일 ↔ STATUS 필드" 규칙이 fg-status·fg-learn·fg-done **세 곳에 중복** 존재해 드리프트에 취약하다.
- **half-sealed `done/` (A4, error).** 모든 `.forge/done/*/STATUS.md`는 `status: done`이어야 한다. 여전히 `status: executed`이면 중단된 봉인이다.
- **task 번호 유일성 (A6, error if dup).** backlog + active + executed + done 전체에서 `task:` 번호가 유일해야 한다(단조 번호 — ADR-0005). 중복은 fg-run 선택/fg-status 표시를 깨뜨린다.
- **봉인 전 이중 게이트 (ADR-0002·0009).** 봉인은 `verified:`(봉인 가능 값) **그리고** 회고 존재 또는 `retro: skipped`를 모두 통과해야 한다. fg-done은 검증 게이트를 회고 게이트보다 먼저 본다(no-seal-without-verification). 이 순서 규칙도 여러 스킬에 분산돼 있어 한 스킬만 고치면 어긋난다.

## fg-drop과 `.forge/dropped/` (ADR-0021)

- fg-drop은 미완(미봉인) 작업 — backlog plan·활성 슬롯·`executed/` 회고 대기·멈춘 goal `loop.md` — 을 폐기하는 루프 밖 유틸리티다.
- **`.forge/dropped/`는 휘발·gitignored**이며 의도적으로 활성 상태 계약 밖이다. fg-doctor는 이를 스캔하지 않고 관용하며(`skills/fg-doctor/SKILL.md` "Ignore `.forge/dropped/`" 지시), fg-status는 무시한다. 이 관용 규칙을 깨고 `dropped/`를 그룹 A 검사 대상에 넣으면 정상 동작을 오탐한다.
- goal 루프는 통째로만 drop되고 멤버 task는 개별 drop에서 제외된다(loop.md 멤버십 재동기화 로직을 만들지 않기 위함).

## 배포·설치 전제

- **설치는 GitHub 기본 브랜치(main)를 당긴다.** push되지 않은 작업은 설치 테스트가 불가능하다 — 배포는 commit이 아니라 **push까지**가 완료다(`CLAUDE.md` "배포 규칙").
- `/plugin install`·`/plugin marketplace update`는 interactive라 에이전트가 실행 못 한다. 에이전트가 검증 가능한 것은 설치 전제뿐이다: `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`으로 원격 main의 버전 3곳을, `awk '/^name:/' skills/*/SKILL.md`로 frontmatter `name` 누락을 확인한다.

## 스크립트 쌍 패리티 (ADR-0022, fg-doctor B14)

- `scripts/`에는 bash 1차·Node.js 대체의 이중 디스패치 쌍이 있다: `forge-status.sh`/`.js`, `forge-statusline.sh`/`.js`, `resolve-forge-root.sh`/`.js`. 각 쌍에는 `.parity.test.sh`가 딸려 있어 의미론적 동등성을 검증한다.
- fg-doctor B14는 정적 쌍 존재만 검사한다(`.sh` 있으나 `.js` 없거나 역방향). 면제 대상: `*.test.sh`·`*.parity.test.sh`·`*-wrapper.sh`. 현재 3쌍 모두 `.sh`·`.js` 둘 다 존재하므로 B14 위반은 없다.
- 신규 스크립트 추가 시 `.js` 쌍과 `.parity.test.sh`를 함께 만들지 않으면 패리티가 깨진다.

## 브랜치 격리에서의 검사 범위 (ADR-0011)

- 비-기본 브랜치에서는 forge 루트 전체가 `.forge/branch/<branch>/`(git 추적)로 이동한다. fg-doctor는 체크 그룹별로 다른 스코프를 읽어야 한다: 그룹 A(휘발 상태)는 해석된 브랜치 루트만, B13(ADR 정합)은 최상위 `.forge/adr/` + 브랜치 루트의 **결합 오버레이**(브랜치 우선), B7–B12(매니페스트·README·CLAUDE.md·`skills/`)는 브랜치 무관 리포 루트. 스코프를 혼동하면 브랜치 ADR이 최상위 ADR을 참조하는 정상 케이스를 dangling으로 오탐한다(`skills/fg-doctor/SKILL.md` "Forge root" 섹션).

## ADR 정합 (fg-doctor B13, warning)

- `.forge/adr/`의 ADR 번호는 연속이거나, 빈 번호가 `.forge/adr/retired/`로 설명돼야 한다(은퇴 번호 재사용 금지 — ADR-0012). 활성 ADR의 `ADR-NNNN` 교차참조는 존재하는 번호(활성 또는 은퇴)를 가리켜야 한다.
- **현재 상태:** `.forge/adr/0001`–`0025`가 파일시스템에 존재하며 연속. `retired/` 디렉터리 없음(아직 은퇴된 ADR 없음). 모든 ADR이 git 추적 중이므로 B13 위반은 없다.
