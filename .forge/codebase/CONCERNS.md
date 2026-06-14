---
last_mapped_commit: d3c47b5bdc859af54e741f0524f9ed8ce2b61483
mapped: 2026-06-14
---

# CONCERNS — forge의 기술 부채·취약 지점·의도적 불일치

이 문서는 forge 리포의 알려진 위험·취약점·의도적 어긋남을 구현 사실 위주로 모은다. 도메인 용어 정의는 다루지 않는다(`.forge/CONTEXT.md` 소관). 모든 항목은 실제 파일과 대조해 확인했다.

---

## 1. 신규 실행 코드 — no-code 설계의 경계 있는 예외 (ADR-0017)

forge는 출범 이래 "실행 코드 0줄, 전부 Markdown/JSON, 빌드·테스트 없음"을 두 기둥 중 하나로 지켜온 리포다. 그런데 이번에 **최초의 실행 코드와 최초의 테스트 인프라**가 들어왔다:

- `scripts/forge-statusline.sh` — 첫 런타임 bash 스크립트(약 90줄, statusline 조각 출력)
- `scripts/forge-statusline.test.sh` — 첫 테스트(fixture 기반 bash 테스트, 15케이스)

이 둘은 `git check-ignore`로 확인한 결과 **gitignore되지 않고 정상 추적·배포**된다(`.gitignore`에 `scripts/` 항목 없음). 근거는 `.forge/adr/0017-statusline-integration.md`: Claude Code의 statusLine은 플러그인이 직접 등록 못 하고(`settings.json`의 `statusLine` 키 전용), 비대화형 셸 명령이라 Markdown 스킬(fg-status)을 호출할 수 없으므로 `.forge/`를 직접 읽는 실제 bash가 불가피하다는 것.

**위험: 실행 코드의 범위 확산(scope creep).** 이는 fg-quick이 기둥 2(문서=연료)를 trivial 작업에 한해 완화한 것과 동형의, **의도적·경계 있는** 예외다. 그러나 일단 리포에 bash가 들어온 이상 "이왕 스크립트 있으니 여기에도" 식으로 코드가 번질 유인이 생긴다. ADR-0017 Consequences와 회고(`.forge/retro/2026-06-14-fg-statusline-integration.md`)가 모두 "이 예외 범위를 넓히지 말 것"을 명시 경고로 남겼다. 후속 스킬 편집 시 새 실행 코드 추가는 ADR급 정당화를 요구해야 한다.

## 2. 중복 상태 판독자 — fg-status와의 동기 결합 (유지보수 위험)

`scripts/forge-statusline.sh`는 forge 상태 머신의 **두 번째 판독자**다. 정본은 `skills/fg-status/SKILL.md`의 Task table(bucket→stage 매핑·다음 단계 우선순위 머신)이고, 스크립트는 그 매핑의 **표시 전용(display-only) 얇은 트윈**이다. 스크립트는 우선순위 머신 전체를 재현하지 않고 단계 표시(`<slug>:run`/`<slug>:learn` + verified 플래그/loop 프리픽스)만 한다.

구체적으로 스크립트가 복제하는 매핑(파일 `scripts/forge-statusline.sh` 49–80행):

- 활성 슬롯(`plan.md` 존재) > `executed/` 파킹 > `backlog/` 의 **3단 우선순위** — fg-status의 active slot 항상 1개 계약과 짝
- `plan.md`만 있으면 `run`, `run.md`까지 있으면 `learn` 단계
- `STATUS.md`의 `verified:` 값 → 플래그(`yes`→✓, `failed`→✗, `pending`/공란→⏳, `skipped`/`n/a`→없음)
- `loop.md`의 `replan-round`/`replan-cap` → `🔁 rN/cap` 프리픽스
- ADR-0011 브랜치별 forge 루트 해석(`.forge/` vs `.forge/branch/<branch>/`)

**위험: 동기 결합(synchronization coupling).** fg-status의 상태 머신이나 Task table의 bucket→stage 매핑이 바뀌면 이 스크립트를 **반드시 같이** 고쳐야 한다. 둘이 어긋나면 statusline이 거짓 단계를 표시한다. 정본·트윈 관계가 코드로 강제되지 않으므로 사람이 기억해야 하는 어긋남이다. ADR-0017 Consequences·회고·`skills/fg-statusline/SKILL.md`(38행, "thin display twin … update both") 세 곳이 이 결합을 명시 경고로 박아두었다. fg-status를 만질 때는 이 스크립트를 점검 대상에 포함할 것.

## 3. 미검증 가정 — statusLine 셸의 cwd ($PWD 기준 판독)

`scripts/forge-statusline.sh`는 `.forge/`를 **`$PWD`(현재 작업 디렉터리) 기준**으로 읽는다. stdin으로 들어오는 세션 JSON의 `cwd` 필드를 **파싱하지 않는다**(스크립트 17행 주석 "No JSON/jq parsing (reads files by path)"). 즉 "statusLine 셸의 cwd = 프로젝트 디렉터리"라고 가정한다.

**위험: 호스트가 다른 디렉터리에서 statusLine을 실행하면 조각이 아무것도 안 뜬다**(`.forge/`를 못 찾아 37행 `exit 0`). 이 가정은 실제 터미널 통합에서 검증되지 않은 채 남았다(회고가 "statusLine 셸 cwd 가정은 미검증으로 남았다"고 명시). 폴백 — 래퍼가 캡처한 `$input`에서 `cwd`를 추출해 `cd` 후 조각 호출 — 은 `skills/fg-statusline/SKILL.md`의 "Notes & assumptions"(100행)에 설계로만 적혀 있고 **구현되지 않았다**. 사용자가 "분명 활성 프로젝트인데 조각이 안 뜬다"고 하면 이 가정부터 의심해야 한다. 상세: `.forge/retro/2026-06-14-fg-statusline-integration.md`.

## 4. 전달 취약성 — 설치 시 복사 모델의 staleness 위험

`fg-statusline` 스킬은 설정 시 `scripts/forge-statusline.sh`를 안정 경로 `~/.claude/forge-statusline.sh`로 **복사**한다(`skills/fg-statusline/SKILL.md` 44–46행). 이유는 ADR-0017에 명시: 플러그인 설치 경로 `~/.claude/plugins/cache/<hash>/`는 **업데이트마다 바뀌고**, `${CLAUDE_PLUGIN_ROOT}`는 statusLine 셸에서 **사용 불가**라 settings가 참조할 안정 경로가 필요하다.

**위험: 업데이트 staleness.** 복사본이므로 **forge 플러그인을 업데이트해도 사용자의 `~/.claude/forge-statusline.sh`는 자동 갱신되지 않는다.** 사용자가 `fg-statusline`을 **재실행**해야 최신 스크립트가 반영된다. SessionStart 훅 자동 복사 대안은 "forge에 훅이라는 새 아티팩트와 매 세션 실행을 도입하지 않으려" 의식적으로 기각됐고(ADR-0017 고려한 대안), 근거는 "스크립트가 거의 안 변해 재실행 비용이 작다"는 것이다. 그러나 항목 2의 동기 결합으로 스크립트가 바뀌는 날이 오면, 업데이트한 사용자 중 재실행 안 한 사람은 **구버전 표시 로직을 계속 쓴다.** SKILL.md 101행("Refresh on update")이 이 비대칭을 경고한다.

## 5. 사용자 settings.json 자동 편집 — 잘못된 임베딩이 statusline을 깰 수 있음

statusLine은 **동시에 하나뿐이고 스택 불가**라(ADR-0017), 사용자가 이미 다른 statusline을 쓰면 forge는 "추가"가 불가능하고 **합성(compose)**만 가능하다. 따라서 `fg-statusline`은 사용자의 기존 statusLine 명령을 **래퍼로 감싸** 자동 편집한다 — `~/.claude/forge-statusline-wrapper.sh`를 생성해 원본 명령에 stdin을 흘려보내고 그 출력 아래 forge 조각을 별도 줄로 덧붙인 뒤, `settings.json`의 `statusLine.command`를 래퍼로 교체한다(`skills/fg-statusline/SKILL.md` 64–84행).

**위험: 원본 명령 오임베딩으로 사용자 statusline 파손.** 래퍼는 원본이 스크립트 경로면 직접 호출, 인라인 셸 스니펫이면 `bash -c '<inline>'`로 감싸는데(79행), 이 분기를 잘못 처리하면 사용자의 기존 statusline 출력이 깨진다. 완화책은 스킬에 **절차로만** 박혀 있다: (a) 쓰기 전 `statusLine.command`의 before→after와 생성된 래퍼를 보여주고 **명시적 승인**을 받을 것, (b) 원본을 `# original:` 주석에 verbatim 보존해 수동 복원 경로를 남길 것, (c) 이미 forge 래퍼면 **이중 래핑 금지** 가드(62행). 이 가드들은 에이전트가 스킬 지시를 충실히 따라야만 작동한다 — 코드로 강제되지 않으므로, 스킬 본문이 흐려지거나 에이전트가 단계를 건너뛰면 사용자 설정 파손 위험이 실재한다.

---

## 6. 문서·매니페스트의 의도적 불일치 (CLAUDE.md 기록)

여러 파일을 읽어야 드러나는, 의도적 반복 작업으로 생긴 어긋남들. 편집 전 인지해야 계약이 안 깨진다.

### 6a. fg-ask의 자기완결 3파일 verbatim 구조 — 드리프트 위험

`skills/fg-ask/`는 grill-with-docs 원본을 그대로 옮긴 **자기완결 3파일**이다(`SKILL.md` + 형제 `CONTEXT-FORMAT.md`/`ADR-FORMAT.md`, 전부 영문). `SKILL.md` 본문은 **영문 verbatim**이고, forge 루프 연결(백로그 산출·fg-run 핸드오프·회고 환류)은 맨 아래 "Forge integration (minimal)" 섹션에만 격리돼 있다.

**위험:** verbatim 본문과 Forge integration 섹션은 **따로 움직인다.** 둘 중 하나만 고치면 계약이 깨진다 — verbatim을 건드리면 원본 동기화가 깨지고, integration 섹션을 빠뜨리면 루프 연결이 끊긴다. CLAUDE.md "현재 상태의 알려진 불일치"가 이를 명시 경고한다.

### 6b. 두 매니페스트 description의 서로 다른 역할

`.claude-plugin/marketplace.json`에는 사람이 읽는 description이 **두 개** 있고 역할이 다르다(확인한 실제 값):

- `metadata.description` — `"forge — a stage-by-stage workflow skill set (fg-*) for the ask·plan → execute → retro → done loop."` → **루프(ask→execute→retro→done)를 정의하는 한 줄 태그라인.** 루프 밖 유틸리티(fg-map·fg-statusline류)는 여기 **넣지 않는다.**
- `plugins[].description` — `"Fourteen fg-* skills. …"`로 시작하는 **전체 스킬 목록 설명.** 루프 밖 스킬도 여기 반영한다.

**위험:** 스킬 개수·설명을 바꿀 때 `plugin.json`의 `description`·`version`과 `marketplace.json`의 두 description·두 version(`metadata.version`·`plugins[0].version`)을 **함께** 갱신해야 한다. 루프 밖 스킬을 `metadata.description`에 끼우면 루프 정의가 흐려지고, version 3곳(`plugin.json`·`metadata`·`plugins[0]`)이 어긋나면 배포가 깨진다. CLAUDE.md 배포 규칙과 "매니페스트의 두 description은 역할이 다르다" 항목이 이를 강제한다.

### 6c. 형식 문서·README의 단일 정의 분산

- **형식 문서는 한 벌만 존재하고 소유 스킬 디렉터리에 둔다** — `skills/fg-ask/{CONTEXT,ADR}-FORMAT.md`, `skills/fg-run/PLAN-FORMAT.md`, `skills/fg-learn/RETRO-FORMAT.md`. 다른 스킬(fg-done 등)은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>` 상대경로로 참조하고 **자체 복사하지 않는다.** 복붙하면 단일 정의가 깨진다. (PLAN-FORMAT은 생산자가 fg-ask인데 소비자 fg-run 디렉터리에 둔 미묘한 위치 — fg-ask 디렉터리가 verbatim 영역이라서.)
- **FORGE-ROOT 정의도 단일** — 브랜치별 forge 루트 해석 규칙의 단일 정의는 `skills/fg-run/FORGE-ROOT.md`이고 모든 루프 스킬(그리고 `scripts/forge-statusline.sh`)이 이를 참조한다. 복붙 금지. statusline 스크립트가 이 해석을 bash로 재구현한 것(31–35행)도 항목 2와 같은 결의 동기 결합이다.
- **README 이중 언어** — `README.md`(영문)와 `README.ko.md`(한글)는 번역 쌍이다. 한쪽만 고치면 어긋난다. 항상 같은 변경으로 함께 갱신.

---

## 7. 구조적 취약성 — 자동화된 검증의 부재

- **빌드·테스트·린트·CI 없음.** 검증은 매니페스트 JSON 유효성 한 줄(`node -e ...`)과 "설치해서 트리거해보기"가 전부다. statusline 스크립트만 유일하게 테스트가 있고(`scripts/forge-statusline.test.sh`), 이 테스트조차 자동 실행 훅이 없어 **사람이 수동으로 `bash scripts/forge-statusline.test.sh`를 돌려야** 한다.
- **설치는 GitHub 기본 브랜치(main)를 당긴다.** 설치 테스트하려면 main에 push돼 있어야 하므로, 로컬에서 검증 못 한 변경이 배포로만 드러나는 구조다.
- **상태 계약의 무결성은 스킬 본문에만 의존한다.** `.forge/` 휘발 상태(활성 슬롯 1개·STATUS.md 동반 이동·검증 게이트·봉인 비우기)는 13개+ 스킬이 Markdown 지시로 지키는 계약일 뿐, 코드로 강제되지 않는다. 스킬 하나가 계약을 어기면 루프가 조용히 깨진다.
