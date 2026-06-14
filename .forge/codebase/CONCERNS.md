---
last_mapped_commit: 74d8c840911bb14b4600e1618d678af158d1ce69
mapped: 2026-06-14
---

# CONCERNS

forge는 빌드·테스트·린트 시스템이 없는 플러그인 리포다(산출물은 Markdown 스킬 + JSON 매니페스트, 그리고 statusline용 bash 스크립트). 따라서 "tech debt"의 본질은 **손으로 편집되는 다수 Markdown/JSON 사이의 일관성·계약 무결성**이다. 아래는 RESOLVED(이번 변경으로 해소), STANDING(여전히 유효), FRAGILE(취약 영역) 세 갈래로 정리한다.

## Resolved (this change)

### fg-adversarial-review wrong-slot bug — RESOLVED
이전에는 SKILL.md가 parked `executed/<slug>/` 작업도 리뷰 대상으로 허용한다고 서술하면서도, findings는 항상 활성 슬롯의 `.forge/review.md`·STATUS에 기록했다 — 입력 범위와 기록 위치가 어긋나는 wrong-slot 버그(Codex 적대적 리뷰 지적). 이제 **리뷰 대상은 활성 슬롯 전용**이다: parked 작업을 리뷰하려면 fg-run unpark로 활성 슬롯에 올린 뒤 실행한다. `skills/fg-adversarial-review/SKILL.md`(특히 "When to run"·"The review targets the active slot only")와 `.forge/adr/0018-fg-adversarial-review.md`("대상 범위는 활성 슬롯 작업 전용 (개정 2026-06-14)")가 일치하도록 개정됐다.

이로써 fg-adversarial-review가 다루는 상태 계약면이 정리됐다 — 인지 대상은 다음과 같다: 활성 슬롯(`.forge/plan.md`·`.forge/run.md`) / `.forge/backlog/<slug>.md`(fix-forward plan 적재) / `.forge/executed/<slug>/`(리뷰 대상 아님, unpark 필요) / `.forge/done/<날짜-slug>/`(봉인 시 아카이브 목적지) / STATUS의 `verified:`·`retro:`(봉인 게이트) / loop.md 멤버십(자동 주행 skip 경계) / `.forge/review.md`. 이 중 **`.forge/review.md`와 STATUS의 `reviewed:`는 활성 슬롯 전용**이며, **`reviewed:`는 기록용일 뿐 봉인 게이트가 아니다**(게이트는 `verified:`·`retro:`만). per-task `executed/<slug>/review.md` 저장안은 fg-learn/fg-done에 분기를 더하는 드문 케이스라 기각됐다(ADR-0018).

### statusline tilde / config-dir blanking class — RESOLVED (illustrative)
`scripts/forge-statusline-wrapper.sh`가 동반 파일(`forge-statusline-orig.sh`·`forge-statusline.sh`)을 **자기 스크립트 위치**(`$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`)에서 해석하도록 개정됐다(line 24). 이전엔 런타임 `$CLAUDE_CONFIG_DIR`에 의존했는데, statusLine 프로세스가 그 변수를 export하지 않는 custom config dir 환경에서 동반 파일을 못 찾아 **statusline 전체가 조용히 공백**이 되는 결함이 있었다(Codex 적대적 리뷰 지적). `BASH_SOURCE` 기반 자기 위치 해석은 동반 파일이 래퍼와 같은 디렉터리에 복사되므로 항상 옳다.

이 결함은 statusline의 더 넓은 "경로 해석 깨짐 → 전체 공백" 위험군의 한 사례다 — `.forge/adr/0017-statusline-integration.md`의 "개정 (2026-06-14) — 강건성 재설계"가 같은 군의 다른 사례들(① `settings.json`의 `statusLine.command`에 tilde `~` 금지, 절대경로로; ② fragment가 stdin 세션 JSON의 `cwd`를 파싱)을 함께 못 박는다. 이 군 전체를 RESOLVED로 본다. 회귀 테스트가 신설됐다: `scripts/forge-statusline-wrapper.test.sh`의 custom-config 케이스(line 93~107, "Regression: custom install dir, NO CLAUDE_CONFIG_DIR")가 `CLAUDE_CONFIG_DIR` 미export 상태에서 원본 보존·forge 행 추가를 검증한다.

## Standing concerns

### Manifest sync risk — STANDING
스킬 개수와 설명이 `.claude-plugin/plugin.json`(`description`)과 `.claude-plugin/marketplace.json`(`plugins[0].description`) **양쪽**에 사람 읽는 산문으로 중복되고, 버전은 **3곳**(`plugin.json`의 `version`, `marketplace.json`의 `metadata.version`·`plugins[0].version`)에 있다. 한쪽만 편집하면 드리프트한다. 현재 상태: 버전은 `0.4.12`로 3곳 일치하고, `marketplace.json`의 "Fifteen … Eleven more"가 디스크 스킬 디렉터리 15개(`skills/`의 fg-* 15개)와 일치한다. **단 약간 stale하다** — 작업 트리에 미커밋 변경(task 31 수정: ADR-0017/0018 개정, wrapper·테스트·SKILL 수정)이 쌓여 있어 아직 릴리스되지 않았다. 이 작업이 별도 `feat` 커밋으로 묶인 뒤 **v0.4.13 릴리스가 대기 중**이다(배포 시 CHANGELOG + 3곳 버전 범프).

### CLAUDE.md gap (fg-statusline / ADR-0017) — STANDING
CLAUDE.md line 44의 "루프 밖 스킬" 목록에 `fg-adversarial-review`(ADR-0018)는 이번에 추가됐으나 **`fg-statusline`(ADR-0017)은 여전히 누락**돼 있다. 재확인 결과 `CLAUDE.md` 전체에 `fg-statusline`·`ADR-0017`·`0017` 문자열이 0회 등장한다. 매니페스트 두 곳과 README는 fg-statusline을 기술하지만 CLAUDE.md 본문 목록만 빠져 있다 — follow-up-fix 후보. (참고: line 57의 상태 계약 표에는 `.forge/review.md` 행이 추가돼 있어, fg-adversarial-review 쪽 계약 반영은 완료됐다.)

### FORGE-ROOT double definition — STANDING
브랜치별 forge 루트 해석의 단일 정의는 `skills/fg-run/FORGE-ROOT.md`이고 모든 루프 스킬이 이를 참조한다(복붙 금지가 규약). 그러나 `scripts/forge-statusline.sh`는 bash 스크립트라 그 Markdown을 읽을 수 없어 **브랜치 루트 해석을 직접 재구현**한다(line 39~51: `git rev-parse --abbrev-ref HEAD`, `.forge/config.json`의 `defaultBranch`를 `sed`로 추출, 비-기본 브랜치면 `.forge/branch/<branch>`). 사실상 두 번째 정의다. ADR-0017이 이 이중성을 "상태 머신이 두 곳(fg-status 정본 + 얇은 표시본)"으로 명시적으로 인정하지만, 브랜치 해석 규칙(예: 전역 예외 `config.json`·`codebase/`)이 바뀌면 양쪽을 같이 고쳐야 한다 — follow-up 후보.

### README bilingual drift — STANDING
`README.md`(영문)와 `README.ko.md`(한글)는 번역 쌍으로 동기 유지가 규약이다. 둘 다 statusline·adversarial review를 언급하므로 현재는 정렬돼 있으나, 한쪽만 편집하면 어긋난다 — 매 편집 시 양쪽 동시 갱신 필요.

## Fragile areas

- **fg-adversarial-review SKILL ↔ ADR-0018 ↔ CLAUDE.md 계약 3중 동기.** SKILL.md(활성 슬롯 전용·`review.md`·`reviewed:` 기록용)·ADR-0018(개정 결정·Consequences의 "총 15 스킬")·CLAUDE.md(line 44 목록 + line 57 계약 표 행)이 같은 사실을 세 곳에서 진술한다. 이번 개정으로 정렬됐지만, fg-learn·fg-done·fg-next·fg-loop가 `review.md` 아카이브·retro 승급·자동 skip을 다루므로(ADR-0018 Consequences가 명시) 향후 이들 스킬 편집 시 함께 깨지기 쉽다.

- **statusline 상태 머신 이중 표현.** `skills/fg-status/SKILL.md`(다음-단계 우선순위 머신의 정본)와 `scripts/forge-statusline.sh`(표시 전용 얇은 판독본)가 bucket→stage 매핑을 각자 갖는다. ADR-0017이 의도적 이중성으로 인정하나, 단계 매핑이 바뀌면 양쪽을 같이 고쳐야 한다.

- **fg-ask verbatim 본문 ↔ Forge integration 섹션.** `skills/fg-ask/`는 grill-with-docs 원본의 영문 verbatim 본문과 맨 아래 "Forge integration" 섹션이 따로 움직인다 — 한쪽만 고치면 계약이 깨진다(CLAUDE.md "알려진 불일치"에 명시).

- **형식 문서 단일 소유 + 상대경로 참조.** `*-FORMAT.md`(`skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-learn/RETRO-FORMAT.md`)와 `FORGE-ROOT.md`는 한 벌만 존재하고 타 스킬이 `${CLAUDE_PLUGIN_ROOT}/skills/<소유>/...` 상대경로로 참조한다. 소유 스킬 디렉터리명이 바뀌면 모든 참조가 끊긴다.

- **검증 없는 산출물.** 빌드·CI·단위 테스트가 없어, 매니페스트 JSON 유효성(node 한 줄)과 statusline bash 테스트(`scripts/*.test.sh`)를 빼면 Markdown 계약 무결성은 사람 리뷰에만 의존한다. 설치는 GitHub main을 당기므로 깨진 매니페스트가 push되면 설치 실패로만 드러난다.
