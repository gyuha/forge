---
last_mapped_commit: 415041c8bf7ed6eca4f330cb1045acd946becfd7
mapped: 2026-06-15
---

# CONCERNS

forge는 빌드·테스트·린트 시스템이 없는 플러그인 리포다(산출물은 Markdown 스킬 + JSON 매니페스트, 그리고 statusline용 bash 스크립트). 따라서 "tech debt"의 본질은 **손으로 편집되는 다수 Markdown/JSON 사이의 일관성·계약 무결성**이다. 핵심 변화는 이번에 추가된 루프 밖 스킬 `fg-doctor`(ADR-0019)로, 그간 "손편집 Markdown에서 조용히 썩어 운으로만 발견되던" 다수 정합성 우려를 **능동 탐지** 대상으로 끌어올렸다는 점이다 — 단 on-demand + detect-only라 우려가 제거된 게 아니라 완화된 것이다. 아래는 MITIGATED(fg-doctor로 탐지 가능해짐), RESOLVED(이번 변경으로 해소), STANDING(여전히 유효), FRAGILE(취약 영역) 네 갈래로 정리한다.

## Mitigated by fg-doctor (detected, not eliminated)

`skills/fg-doctor/SKILL.md`은 read-only 무결성 점검 스킬로, 상태 계약면(orphan run.md, STATUS 필드 유효성, slug 페어링 plan↔STATUS↔retro, half-sealed `done/`, backlog 마커)과 docs/manifest 동기(버전 3곳 드리프트, JSON 유효성, 스킬 `name` frontmatter, 스킬 개수, **CLAUDE.md 스킬 목록 완전성**, README 이중 언어, ADR 번호/교차참조)를 훑어 위반을 severity + actionable fix 힌트와 함께 보고한다. **`forge doctor`로 on-demand 실행**한다.

이로써 아래의 기존 STANDING 우려들이 **이제 탐지 가능**해졌다:

- Manifest 버전 드리프트(3곳) · 스킬 개수/설명 드리프트
- README 이중 언어 드리프트
- CLAUDE.md 스킬 목록 누락(과거 fg-statusline 누락이 정확히 이 부류였음)
- slug 페어링 불일치(plan↔STATUS↔retro)
- half-sealed `done/` · orphan `run.md`
- ADR 번호 비연속/dangling 교차참조

**그러나 제거가 아니라 완화다.** fg-doctor는 ① **on-demand**(자동 실행 안 함 — 사용자가 호출해야 보고가 나옴)이고 ② **detect-only**(아무것도 쓰지 않고 절대 auto-fix 안 함 — 고침은 fg-quick/fg-ask로 사용자가 직접). 즉 호출하지 않으면 침묵하고, 호출해도 고쳐주지 않는다. 우려들은 여전히 "손편집으로 발생 가능"하며 fg-doctor는 발생 후 발견 확률만 높인다. **표준 탐지 도구로 fg-doctor를 기록**하되, 이 두 한계 때문에 위 항목들을 RESOLVED가 아니라 MITIGATED로 둔다.

## Resolved (this change)

### CLAUDE.md fg-statusline omission — RESOLVED
이전 매핑에서 follow-up-fix 후보로 기록됐던 "CLAUDE.md의 fg-statusline(ADR-0017) 누락"이 이번에 수정됐다. 재확인 결과 `CLAUDE.md`는 이제 `fg-statusline`(1회)·`fg-doctor`(1회)·`ADR-0017`(1회)·`ADR-0019`(1회)를 모두 언급하며, 디스크의 16개 스킬(`fg-ask`·`fg-run`·`fg-learn`·`fg-done`·`fg-map`·`fg-quick`·`fg-status`·`fg-next`·`fg-loop`·`fg-merge`·`fg-cleanup`·`fg-tdd`·`fg-eco`·`fg-statusline`·`fg-doctor`·`fg-adversarial-review`)가 전부 본문에 등장한다(grep 확인). CLAUDE.md 스킬 목록 갭은 닫혔다.

### fg-adversarial-review wrong-slot bug — RESOLVED
이전에는 SKILL.md가 parked `executed/<slug>/` 작업도 리뷰 대상으로 허용한다고 서술하면서도, findings는 항상 활성 슬롯의 `.forge/review.md`·STATUS에 기록했다 — 입력 범위와 기록 위치가 어긋나는 wrong-slot 버그(Codex 적대적 리뷰 지적). 이제 **리뷰 대상은 활성 슬롯 전용**이다: parked 작업을 리뷰하려면 fg-run unpark로 활성 슬롯에 올린 뒤 실행한다. `skills/fg-adversarial-review/SKILL.md`와 `.forge/adr/0018-fg-adversarial-review.md`가 일치하도록 개정됐다. `.forge/review.md`와 STATUS의 `reviewed:`는 활성 슬롯 전용이며, `reviewed:`는 기록용일 뿐 봉인 게이트가 아니다(게이트는 `verified:`·`retro:`만).

### statusline tilde / config-dir blanking class — RESOLVED (illustrative)
`scripts/forge-statusline-wrapper.sh`가 동반 파일(`forge-statusline-orig.sh`·`forge-statusline.sh`)을 **자기 스크립트 위치**(`$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`)에서 해석하도록 개정됐다. 이전엔 런타임 `$CLAUDE_CONFIG_DIR`에 의존했는데, statusLine 프로세스가 그 변수를 export하지 않는 custom config dir 환경에서 동반 파일을 못 찾아 statusline 전체가 조용히 공백이 되는 결함이 있었다(Codex 적대적 리뷰 지적). 이 결함은 statusline의 더 넓은 "경로 해석 깨짐 → 전체 공백" 위험군의 한 사례이며, `.forge/adr/0017-statusline-integration.md`의 강건성 재설계(tilde 금지·stdin `cwd` 파싱)와 회귀 테스트(`scripts/forge-statusline-wrapper.test.sh`의 custom-config 케이스)로 군 전체를 RESOLVED로 본다.

## Standing concerns

### FORGE-ROOT double definition — STANDING (follow-up candidate)
브랜치별 forge 루트 해석의 단일 정의는 `skills/fg-run/FORGE-ROOT.md`이고 모든 루프 스킬이 이를 참조한다(복붙 금지가 규약). 그러나 `scripts/forge-statusline.sh`는 bash 스크립트라 그 Markdown을 읽을 수 없어 **브랜치 루트 해석을 직접 재구현**한다(line 38~53: `git rev-parse --abbrev-ref HEAD`, `.forge/config.json`의 `defaultBranch`를 `sed`로 추출, 비-기본 브랜치면 `.forge/branch/<branch>`, detached HEAD/non-repo fallback). 사실상 두 번째 정의다. ADR-0017이 이 이중성을 명시적으로 인정하지만, 브랜치 해석 규칙(예: 전역 예외 `config.json`·`codebase/`)이 바뀌면 양쪽을 같이 고쳐야 한다. **개념적으로는 fg-doctor가 탐지할 수 있는 부류이나 현재 자동 점검 항목은 아니다** — 여전히 follow-up 후보.

### Manifest sync risk — STANDING (now fg-doctor-detectable)
스킬 개수·설명이 `.claude-plugin/plugin.json`(`description`)과 `.claude-plugin/marketplace.json`(`plugins[0].description`) **양쪽**에 사람 읽는 산문으로 중복되고, 버전은 **3곳**(`plugin.json`의 `version`, `marketplace.json`의 `metadata.version`·`plugins[0].version`)에 있다. 한쪽만 편집하면 드리프트한다. 현재 상태: 버전은 **`0.4.13`로 3곳 일치**한다. **단 작업 트리에 미커밋 fg-doctor 작업이 쌓여 있어**(새 스킬 `skills/fg-doctor/SKILL.md`·ADR-0019·CLAUDE.md 수정 등) 아직 릴리스되지 않았다 — 이 작업을 별도 `feat` 커밋으로 묶은 뒤 **v0.4.14 릴리스가 대기 중**이다(배포 시 CHANGELOG + 3곳 버전 범프). 이제 fg-doctor의 버전 3곳 동기·스킬 개수 점검으로 탐지 가능하나, on-demand이므로 호출해야만 드러난다.

### README bilingual drift — STANDING (now fg-doctor-detectable)
`README.md`(영문)와 `README.ko.md`(한글)는 번역 쌍으로 동기 유지가 규약이다. 한쪽만 편집하면 어긋난다 — 매 편집 시 양쪽 동시 갱신 필요. fg-doctor의 README 이중 언어 점검으로 탐지 가능하나, on-demand 한계는 동일하다.

## Fragile areas

- **새 스킬 authoring 트랩 — `.forge/` 영속 문서를 읽는 스킬은 ADR-0011 FORGE-ROOT 브랜치 오버레이를 반드시 존중해야 한다.** fg-doctor 자체가 이 함정에 빠졌다 첫 초안에서 — 적대적 리뷰가 잡아내 수정됐다. 핵심: 점검을 그룹별로 **읽는 스코프를 나눠야** 한다(`skills/fg-doctor/SKILL.md` line 14~17). **Group A(휘발 상태: plan/run/STATUS/backlog/executed/done)는 해석된 브랜치 루트만** 읽고, **Group B의 ADR 무결성 점검(B13)은 FORGE-ROOT 읽기 오버레이**(비-기본 브랜치에선 최상위 `.forge/adr/` + `.forge/branch/<branch>/adr/`, 충돌 시 브랜치 우선)를 합쳐 읽어야 한다 — 브랜치 루트만 보면 (a) 브랜치 스킬이 실제로 읽는 최상위 ADR의 손상을 놓치고 (b) 브랜치 ADR이 최상위 ADR을 교차참조하면 dangling으로 오탐한다. Group B의 repo-root 점검(매니페스트·README·CLAUDE.md·`skills/`)은 브랜치 무관. **이는 `.forge/` 영속 문서를 읽는 모든 신규 스킬에 재발하는 authoring 트랩이다** — 휘발/영속 스코프를 섞으면 같은 오류가 난다.

- **fg-adversarial-review SKILL ↔ ADR-0018 ↔ CLAUDE.md 계약 3중 동기.** SKILL.md(활성 슬롯 전용·`review.md`·`reviewed:` 기록용)·ADR-0018·CLAUDE.md(목록 + 계약 표 행)이 같은 사실을 세 곳에서 진술한다. fg-learn·fg-done·fg-next·fg-loop가 `review.md` 아카이브·retro 승급·자동 skip을 다루므로 향후 이들 스킬 편집 시 함께 깨지기 쉽다.

- **statusline 상태 머신 이중 표현.** `skills/fg-status/SKILL.md`(다음-단계 우선순위 머신의 정본)와 `scripts/forge-statusline.sh`(표시 전용 얇은 판독본)가 bucket→stage 매핑을 각자 갖는다. ADR-0017이 의도적 이중성으로 인정하나, 단계 매핑이 바뀌면 양쪽을 같이 고쳐야 한다(위 FORGE-ROOT double definition과 같은 뿌리).

- **fg-ask verbatim 본문 ↔ Forge integration 섹션.** `skills/fg-ask/`는 grill-with-docs 원본의 영문 verbatim 본문과 맨 아래 "Forge integration" 섹션이 따로 움직인다 — 한쪽만 고치면 계약이 깨진다(CLAUDE.md "알려진 불일치"에 명시).

- **형식 문서 단일 소유 + 상대경로 참조.** `*-FORMAT.md`(`skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-learn/RETRO-FORMAT.md`)와 `FORGE-ROOT.md`는 한 벌만 존재하고 타 스킬이 `${CLAUDE_PLUGIN_ROOT}/skills/<소유>/...` 상대경로로 참조한다(fg-doctor도 `../fg-run/FORGE-ROOT.md` 참조). 소유 스킬 디렉터리명이 바뀌면 모든 참조가 끊긴다.

- **검증 없는 산출물.** 빌드·CI·단위 테스트가 없어, 매니페스트 JSON 유효성(node 한 줄)과 statusline bash 테스트(`scripts/*.test.sh`)를 빼면 Markdown 계약 무결성은 사람 리뷰 + fg-doctor on-demand 호출에만 의존한다. fg-doctor는 자동 실행되지 않으므로, 깨진 매니페스트가 push되면 여전히 설치 실패로만 드러날 수 있다(설치는 GitHub main을 당김).
