# statusline 통합 — forge 최초의 런타임 스크립트 + 얇은 두 번째 상태 판독자

## 맥락

forge는 실행 코드가 한 줄도 없는 리포다(전부 Markdown/JSON, 빌드·테스트 없음). 그런데 Claude Code의 statusLine은 **플러그인이 직접 등록할 수 없고**(`settings.json`의 `statusLine` 키로만 설정), 명령은 stdin JSON을 받아 텍스트를 뱉는 **비대화형 셸 명령**이라 에이전트가 읽는 Markdown 스킬(fg-status)을 호출할 수 없다. 또 statusLine은 **동시에 하나뿐**이라 사용자가 이미 쓰는 다른 플러그인 statusline에 "추가"가 불가능하다(합성만 가능). 따라서 forge 상태를 statusline에 띄우려면 `.forge/`를 직접 읽는 **실제 bash 스크립트**가 필요하다.

## 결정

`fg-statusline` 유틸리티 스킬(루프 밖)과 자기완결 bash 스크립트 `scripts/forge-statusline.sh`를 도입한다. 스크립트는 cwd 기준으로 forge 루트(ADR-0011의 브랜치별 해석 포함)를 풀어 활성 슬롯·`executed/`·백로그·`loop.md`를 읽고 **현재 단계 한 줄**(`⚒ <slug>:<stage> <flag>`, loop 주행 시 `🔁 rN/cap` 동반)을 출력한다. fg-status가 다음-단계 우선순위 머신의 단일 정의처로 남고, 이 스크립트는 **표시 전용의 의도적으로 얇은 두 번째 상태 판독자**다(우선순위 머신을 재현하지 않는다). `fg-statusline` 스킬은 한 번 실행 시 스크립트를 안정 경로 `~/.claude/forge-statusline.sh`로 복사하고, 사용자 `settings.json`의 기존 statusLine을 stdin을 양쪽에 흘려보내는 래퍼로 감싸 forge 조각을 **아래 별도 줄**로 덧붙인다(기존 출력 불변).

## 고려한 대안

- **상태 노출 방식**: 전용 `.forge/state.json`을 두고 모든 루프 스킬이 갱신 — 로직 중복은 없지만 13개 스킬에 쓰기 의무를 추가하고 드리프트할 새 계약면이 생겨 기각. 표시용 얇은 직접 판독을 택했다(상태는 이미 파일 위치+STATUS.md 필드에 인코딩됨).
- **스크립트 언어**: node(견고한 파싱, 크로스플랫폼) 대신 bash+git을 택했다 — end-user에게 새 런타임 의존성을 강제하지 않기 위해(git은 이미 암묵 필요, STATUS.md는 단순 `key: value` 줄).
- **전달·갱신**: SessionStart 훅 자동 복사(업데이트 자동 반영) 대신 설정 시 복사를 택했다 — forge에 '훅'이라는 새 아티팩트와 매 세션 실행을 도입하지 않기 위해. 스크립트가 거의 안 변해 "업데이트 후 재실행" 비용이 작다. (플러그인 설치 경로 `~/.claude/plugins/cache/<hash>/`는 업데이트마다 바뀌어 직접 참조 불가.)

## 결과

- forge에 **첫 실행 코드(bash)와 첫 테스트 인프라**(fixture 기반 bash 테스트)가 생긴다 — 두 기둥(문서=연료, no-code)의 의도적·경계 있는 예외다(fg-quick의 기둥 2 완화와 동형 선례).
- forge 상태 머신이 **두 곳**에 존재하게 된다: fg-status(정본·다음 단계)와 이 스크립트(얇은 표시본). 단계 매핑(bucket→stage)이 바뀌면 양쪽을 같이 고쳐야 한다.
- 스크립트 업데이트는 사용자가 `fg-statusline`을 재실행해야 안정 경로에 반영된다(자동 아님).

## 개정 (2026-06-14) — 강건성 재설계

초기 구현이 사용자 환경에서 **statusline 전체가 공백**이 되는 장애를 냈다(claude-hud까지 사라짐). 원인 진단과 함께 다음을 결정했다(핵심 결정 — thin reader + 설정 시 복사 — 은 불변, 메커니즘만 강건화):

- **`settings.json`의 `statusLine.command`는 절대경로로 쓴다 — `~`(tilde) 금지.** statusLine 명령은 호스트가 tilde를 확장한다는 보장이 없어, 리터럴 `~/.claude/...`가 해석 실패 시 래핑된 원본까지 포함해 **전체 statusline이 조용히 공백**이 된다(유력 장애 원인). 기존에 작동하던 statusline(claude-hud·powerline)이 모두 절대경로/인라인이었던 것과 일치시킨다. `$HOME`/`$CLAUDE_CONFIG_DIR`을 설정 시점에 풀어 절대경로를 기록한다.
- **fragment가 stdin 세션 JSON의 `cwd`를 파싱한다(`workspace.current_dir` → `$PWD` 폴백).** 원래 "무파싱/jq-free, cwd는 셸 작업디렉터리 가정"이었던 설계의 **의도적·부분적 반전**이다 — 호스트가 프로젝트 밖에서 statusLine을 실행하면 active여도 영원히 공백이던 문제를 없앤다. 여전히 jq는 안 쓴다(방어적 `sed` 추출). 인터랙티브 실행에서 블록되지 않도록 stdin이 tty가 아닐 때만 읽는다.
- **합성 래퍼는 committed generic 스크립트(`scripts/forge-statusline-wrapper.sh`) + 원본 보존 파일(`forge-statusline-orig.sh`)로 한다.** 원본 명령을 별도 파일에 verbatim 저장하므로 래퍼 자체엔 설치별 치환이 없어 fragment처럼 복사만 하면 된다(중첩 따옴표 escaping 회피). 래퍼는 같은 JSON을 원본과 fragment **양쪽에 stdin으로 흘려** cwd 해석을 일치시키고, 원본을 먼저 출력한 뒤 fragment를 별도 줄로 덧붙인다. SKILL.md의 과거 "inline 임베드" 서술은 이 구현에 맞춰 정정했다.
- **테스트가 늘었다**: fragment에 stdin-cwd 케이스 추가(`forge-statusline.test.sh`), 래퍼 동반 테스트 신설(`forge-statusline-wrapper.test.sh` — 원본 보존·forge 행 추가·idle 무행·stdin 재공급).
- statusLine 설정은 **Claude Code 재시작 후** 적용된다 — 설정 직후 같은 세션에서 판단하면 안 된다(SKILL.md Notes·Handoff에 명시).
