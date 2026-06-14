---
last_mapped_commit: b3b267b7da443c3fbb0ca093c4fc4221a70ef7ab
mapped: 2026-06-14
---

# CONCERNS

forge는 런타임 코드가 거의 없는 플러그인 리포다(Markdown 스킬 + JSON 매니페스트 + 최근 추가된 bash statusline 스크립트). 따라서 여기서의 "기술 부채/리스크"는 런타임 버그가 아니라 **손으로 편집하는 여러 Markdown 파일에 걸친 일관성·계약 무결성**이 핵심이다. 빌드·테스트·린트·CI가 없으므로(`CLAUDE.md` 9행) 대부분의 드리프트는 자동 검출되지 않고 사람이 여러 파일을 교차로 읽어야만 드러난다.

아래 항목은 모두 "한쪽만 고치면 조용히 깨지는" 부류다.

## State-contract fragility (`.forge/` 입출력 계약)

15개 스킬이 `.forge/` 파일들을 통해 상태를 주고받는다. 한 스킬이 자기 입출력만 보고 편집하면 다른 스킬의 가정이 깨져 루프 흐름이 끊긴다. 계약면(contract surface)은 `CLAUDE.md` 52~68행의 표·불릿에 정의돼 있고, 실제 소비처는 `skills/<name>/SKILL.md`에 흩어져 있다.

계약면 목록(생산자 → 소비자):

- **활성 슬롯(active slot)** — `.forge/plan.md` + `.forge/run.md`. 항상 정확히 1개라는 불변식. `fg-run`이 백로그에서 승격해 생성, `fg-learn`·`fg-done`이 소비. plan 첫 줄의 `<!-- forge-slug: ... -->` 주석이 회고·봉인 짝맞춤 식별자(파일 이동에도 영속). statusline 스크립트(`scripts/forge-statusline.sh` 70행)와 fg-run이 이 주석 형식에 동시에 의존 — 형식이 바뀌면 양쪽을 같이 고쳐야 한다.
- **backlog** — `.forge/backlog/<slug>.md`. `fg-ask` 생산, `fg-run`이 선택 메뉴·승격으로 소비. 빈 backlog + 빈 활성 슬롯 + 빈 `executed/` = "진행 중 작업 없음" 신호이며 fg-run의 재실행 방지 가드의 근거.
- **executed/** — `.forge/executed/<slug>/`(+STATUS). "실행됐으나 미회고"의 명시적 상태. fg-run "모두 실행"이 park, `fg-learn`·`fg-done`이 소비. fg-run이 unpark(executed/→활성 슬롯)의 단일 소유자다.
- **done/** — `.forge/done/<날짜-slug>/`. fg-done이 `status: done`으로 봉인. fg-ask(slug 충돌 검출)·fg-run(완료 판별)·fg-learn(회고 제외)·fg-done(이중 봉인 방지)이 소비.
- **STATUS.md 필드** — 작업 파일과 함께 이동하는 동반 마커(이중 장부 아님). 깨지기 쉬운 필드값 계약:
  - `verified:` — 봉인 전 검증 게이트(ADR-0009). 봉인 가능값 `yes`/`skipped`/`n/a`, 차단값 `pending`/`failed`. fg-run이 기록, fg-done이 회고 게이트보다 **먼저** 확인. statusline 스크립트도 이 필드를 읽어 플래그(`✓`/`✗`/`⏳`)를 그린다(`forge-statusline.sh` 76~83행) — 값 어휘가 바뀌면 게이트와 표시가 동시에 어긋난다.
  - `retro:` — `skipped (사유)`이면 회고 파일 없이도 봉인 통과(ADR-0002). fg-run 기록, fg-done 봉인 가드가 인정.
  - `reviewed:` — 적대적 리뷰 기록용(비-게이트, ADR-0018). **생산: `fg-adversarial-review`만**. 소비자 측 검증: 코드베이스 전체에서 `reviewed:` 문자열은 `skills/fg-adversarial-review/SKILL.md`와 `skills/fg-learn/SKILL.md`에만 등장 — fg-done은 이 필드를 읽지 않는다(설계상 비-게이트라 정상). 즉 게이트가 아니라는 가정이 fg-done에 암묵적으로 박혀 있어, 누군가 reviewed를 게이트로 바꾸려면 fg-done까지 손대야 한다.
- **loop.md 멤버십** — `.forge/loop.md`의 `## Tasks` 목록. fg-loop가 이 목록에 등재된 slug만 승격(무필터 주행 방지). fg-loop 생산, fg-status·fg-ask·fg-next·fg-merge가 소비. 멤버십 목록 형식이 fg-loop 내부에만 정의돼 있어 다른 소비자가 형식 변경을 모를 수 있다.
- **review.md (신규, ADR-0018)** — `.forge/review.md`. 적대적 리뷰 findings, 휘발·활성 슬롯 동반·선택적·비-게이트. `fg-adversarial-review` 생산, `fg-learn`(retro 승급 입력)·`fg-done`(봉인 시 done/ 아카이브)이 소비. 코드 확인: `review.md` 문자열은 `fg-adversarial-review`·`fg-done`·`fg-learn`·`fg-run` 4개 SKILL.md에 존재 — 생산자·소비자가 분산돼 있어 아카이브 누락 시 봉인 후 review.md가 고아가 된다.

**FORGE-ROOT 단일 정의 의존**: 브랜치별 forge 루트 해석(ADR-0011)은 `skills/fg-run/FORGE-ROOT.md` 한 벌로만 정의되고 14개 스킬이 이를 참조한다(복붙 금지 규약). **예외: `fg-statusline`은 bash 스크립트(`scripts/forge-statusline.sh` 38~52행)에 루트 해석 로직을 직접 재구현**한다 — Markdown 참조 대신 코드 복제. ADR-0011의 해석 규칙(`defaultBranch`·detached HEAD·`.forge/branch/<branch>/`)이 바뀌면 FORGE-ROOT.md와 이 스크립트를 **각각** 고쳐야 한다. 두 번째 사실상의 정의처가 생긴 셈이다.

## Manifest sync risk (`plugin.json` ↔ `marketplace.json`)

스킬 개수·설명이 **두 매니페스트에 중복**으로 들어 있고, 버전은 **3곳**에 박혀 있다. 한쪽만 편집하면 드리프트한다(`CLAUDE.md` 29·109행).

- **버전 3곳** — `.claude-plugin/plugin.json`의 `version`, `.claude-plugin/marketplace.json`의 `metadata.version`과 `plugins[0].version`. 현재 셋 다 `0.4.12`로 일치(확인됨). 배포 절차(`CLAUDE.md` 109행)가 셋을 동기 갱신하도록 강제하지만 수동 편집 시 어긋날 수 있다.
- **두 description의 역할 분리** — `marketplace.json`의 `metadata.description`은 루프(ask→execute→retro→done)를 정의하는 한 줄 태그라인이라 **루프 밖 유틸리티를 넣지 않는다**. 반면 `plugins[].description`(과 `plugin.json`의 `description`)은 전체 스킬 목록을 담아 **루프 밖 스킬도 반영**한다. 이 역할 차이를 모르고 metadata에 fg-map류를 끼우면 루프 정의가 흐려진다(`CLAUDE.md` 120행). 두 긴 description은 사실상 손으로 동기화하는 산문이라, 스킬 추가/문구 변경 시 둘을 함께 고치지 않으면 어긋난다.
- **스킬 개수 단어** — 현재 디스크 스킬 디렉터리 15개. `marketplace.json`의 `plugins[].description`은 "Fifteen fg-* skills … Eleven more sit outside the loop"로 4(루프)+11(밖)=15에 정합(확인됨). 단 이 개수가 **문자열 하드코딩**이라 스킬을 추가하면 "Fifteen"/"Eleven"을 손으로 바꿔야 하며, `plugin.json`의 description에는 개수 단어가 없어 비대칭이다.

## README bilingual drift (`README.md` ↔ `README.ko.md`)

두 파일은 같은 내용의 번역 쌍이며 한쪽을 고치면 반드시 다른 쪽도 같은 변경으로 갱신해야 한다(`CLAUDE.md` 92행). 현재 줄 수는 `README.md` 146행 / `README.ko.md` 145행으로 근접 — 큰 드리프트는 없으나, 자동 동기화 장치가 없어 부분 편집 시 조용히 벌어진다. 검출 수단이 사람 검토뿐이라는 점이 리스크 자체다.

## Known inconsistencies (CLAUDE.md 출처)

- **fg-ask의 verbatim 본문 ↔ Forge integration 섹션 분리** — `skills/fg-ask/`는 grill-with-docs 원본의 자기완결 3파일(`SKILL.md` + 형제 `CONTEXT-FORMAT.md`/`ADR-FORMAT.md`)이다. SKILL.md 본문은 영문 verbatim이고 forge 루프 연결(백로그 산출·fg-run 핸드오프·회고 환류)은 맨 아래 "Forge integration (minimal)" 섹션에만 있다. 이 둘이 따로 움직이므로 한쪽만 고치면 계약이 깨진다(`CLAUDE.md` 126행). verbatim 영역이라 다른 스킬과 편집 규약이 다른 점도 함정.
- **형식 문서 단일 소유권** — 형식 정의는 한 벌만 존재하며 소유 스킬 디렉터리에 둔다: `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`(생산자는 fg-ask지만 fg-ask는 verbatim 영역이라 소비자 쪽에 둠 — 직관에 반함), `skills/fg-learn/RETRO-FORMAT.md`. 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유>/<파일>`로 참조하고 복사하지 않는다(`CLAUDE.md` 79행). 누군가 형식을 복사해 로컬 수정하면 단일 소유권이 깨진다.

## 기록할 특정 불일치: CLAUDE.md가 fg-statusline을 누락

**확인됨(High).** `CLAUDE.md` 44행의 "루프 밖 스킬" 문단은 루프 밖 스킬을 나열하지만 **`fg-statusline`(ADR-0017)을 빠뜨린다**. 문단은 fg-eco(ADR-0014)에서 곧바로 fg-adversarial-review(ADR-0018)로 건너뛴다. grep 결과 `CLAUDE.md` 전체에 `fg-statusline`·`statusline`·`ADR-0017` 문자열이 **단 하나도 없다**. 즉:

- 44행 루프-밖 스킬 나열에서 fg-statusline 누락.
- 상태 계약 표(52~61행)·불릿에도 statusline이 `.forge/` 밖(`~/.claude/`)에 쓴다는 점, `settings.json` `statusLine` 키에 의존한다는 점이 전혀 언급되지 않음.
- "현재 상태의 알려진 불일치"(122~126행) 섹션에도 statusline 관련 항목 없음.

스킬 매니페스트(`marketplace.json`·`plugin.json`)와 ADR-0017에는 fg-statusline이 충분히 기술돼 있으므로, 이것은 **CLAUDE.md만의 문서 공백**이며 후속 수정 후보다. 권장 수정: 44행 문단에 fg-statusline(ADR-0017) 추가 + 상태 계약 섹션에 "`.forge/` 밖 `settings.json`·`~/.claude/`에 쓰는 유일한 스킬" 주석.

## statusline script risks (`scripts/forge-statusline.sh`, ADR-0017)

forge 최초의 실행 코드(bash) + 최초의 테스트 인프라. 두 기둥(문서=연료, no-code)의 의도적 예외(ADR-0017)이며, 고유한 리스크를 들여온다:

- **install-time copy 모델** — fg-statusline은 스크립트를 안정 경로 `~/.claude/forge-statusline.sh`(+`forge-statusline-wrapper.sh`)로 **복사**한다(`SKILL.md` 47~52행). 따라서 리포의 `scripts/forge-statusline.sh`를 고쳐도 **사용자가 fg-statusline을 재실행하기 전까지 라이브 설치본에 반영되지 않는다**. 플러그인 업데이트도 안정 경로를 자동 갱신하지 않는다(설치 경로 `~/.claude/plugins/cache/<hash>/`가 업데이트마다 바뀌므로 직접 참조 불가). "스크립트 = 진실"이 아니라 "사용자가 마지막으로 복사한 스냅샷 = 진실"이라는 비대칭.
- **statusLine 설정은 Claude Code 재시작 후에만 적용** — 설정은 세션 시작 시 로드된다(`SKILL.md` 104행). 설정 직후 같은 세션에서 "안 보인다"고 판단하면 오진. 자동 검증이 불가능한 부분이라 핸드오프가 사용자에게 재시작을 명시해야 한다.
- **tilde 경로가 statusline 전체를 조용히 공백으로 만듦 (해결됨이나 시사적)** — 초기 구현이 사용자 환경에서 **statusline 전체 공백** 장애를 냈다(claude-hud까지 사라짐, ADR-0017 개정 2026-06-14). 원인: `settings.json`의 `statusLine.command`에 리터럴 `~/.claude/...`를 썼는데 호스트가 tilde 확장을 보장하지 않아, 해석 실패 시 래핑된 원본까지 포함해 전체가 조용히 빈다. 해결: 설정 시 `$HOME`/`$CLAUDE_CONFIG_DIR`을 풀어 **절대경로**를 기록. 해결됐지만, "statusLine은 실패해도 에러를 안 내고 조용히 빈다"는 호스트 특성은 그대로라 향후 경로 처리 회귀 시 같은 부류 장애가 재발할 수 있다.
- **상태 머신 이중화** — 단계 매핑(bucket→stage)이 fg-status(정본)와 statusline 스크립트(얇은 표시본) **두 곳**에 존재한다(ADR-0017 결과, `SKILL.md` 39행). bucket→stage 매핑이 바뀌면 양쪽을 같이 고쳐야 한다 — 위의 FORGE-ROOT 이중 정의와 같은 패턴.
- **방어적 sed 파싱** — 스크립트는 jq 없이 stdin 세션 JSON의 `cwd`(`workspace.current_dir`→`$PWD` 폴백)를 `sed`로 추출한다(`forge-statusline.sh` 32~34행). 새 런타임 의존성을 피한 의도적 선택이지만, JSON 형식 변화나 비정형 따옴표에 sed 추출이 깨질 수 있고 그 실패는 조용하다(공백 출력). 테스트(`forge-statusline.test.sh`·`forge-statusline-wrapper.test.sh`)가 일부 케이스를 막지만, 이 테스트들 역시 CI 없이 수동 실행 대상이다.

## 기타 fragile area

- **자동 검증 부재가 메타 리스크** — JSON 유효성 한 줄(`node -e ...`)과 statusline의 수동 bash 테스트를 빼면, 위 모든 계약·동기화는 **사람이 여러 파일을 교차로 읽어야만** 검증된다. 깨짐이 설치/실행 시점까지 드러나지 않을 수 있다.
- **ADR 번호의 단조 증가·불변 규약** — ADR-0001~0018이 활성, retired/는 별도(ADR-0012). fg-merge가 브랜치 ADR을 재번호하므로(ADR-0011) 번호 충돌·교차참조 갱신 누락이 잠재 위험. CLAUDE.md·README·매니페스트가 ADR 번호를 본문에 하드코딩해 인용하므로, 재번호·은퇴 시 이 인용들이 어긋날 수 있다(예: CLAUDE.md 44행이 ADR 번호를 다수 인라인 인용).
- **fg-adversarial-review의 비-하드-의존 가정** — ADR-0018은 이 스킬이 외부 스킬에 하드 의존하지 않고 무인 주행에서 항상 skip된다고 명시한다. 그러나 review.md·`reviewed:` 계약면을 fg-learn·fg-done·fg-run이 인지해야 하므로, "선택적·비-게이트"라는 성격이 네 스킬에 분산 가정으로 박혀 있다 — 한 곳에서 이를 게이트로 바꾸면 나머지와 모순된다.
