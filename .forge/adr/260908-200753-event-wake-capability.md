---
author: gyuha
decided: 2026-09-08 20:07
---
# fg-showme의 확정-클릭 즉시 반영을 `event_wake` capability로 공개한다

fg-showme의 "화면에서 확정하면 터미널 턴 없이 대화가 재개된다"(ADR `260805-005436`)는 Claude Code의 `Monitor` 도구에 전적으로 의존하는 **호스트 능력**인데, 그 사실이 `core/HOST.md`의 capability 어휘·`hosts/*/capabilities.json`·`docs/codex.md` 지원표 어디에도 없어 Codex 사용자는 확정 뒤 아무 일도 일어나지 않는 이유를 알 수 없었다(폴백은 `VISUAL.md`에만 "`Monitor`가 없으면"이라는 **런타임 발견** 형태로 적혀 있었고, 회고 `260805-063357`은 그 분기를 "미밟힌 분기"로 남겨 뒀다). **9번째 공유 capability `event_wake`("외부 이벤트로 대화를 재개한다, 사용자 턴 없이")를 신설**해 Claude Code `true`(이번 조사에서 필터·`--line-buffered`·`-F` 파일 삭제 생존까지 실측) / Codex `false`(미관측 = 기본값)로 선언하고, fg-showme는 장전 전에 키를 **사전 조회**해 `false`면 URL을 건네는 그 메시지에서 폴백을 **세션 시작 1회** 밝힌다.

## 고려한 대안

- **지원표 산문 행만 추가(키 없이)** — `budget-tokens` 행이 이미 그 선례라 가능했고 더 싸다. 기각: 기계 강제가 없다. 이 리포는 "카탈로그를 산문에 적으면 조용히 낡는다"를 반복해서 밟았고(0.8.3 릴리스, 랜딩의 스킬 수 21 잔존), `release-check`가 `core/HOST.md` 표에서 어휘를 **도출**하고 `docs/{,en/}codex.md`에 모든 키 명시를 **강제**하므로 키를 만드는 것이 공개를 영속화하는 유일한 수단이었다 — 실행 중 S1(표 행만 추가)만으로 두 트윈이 `missing keys: event_wake`로 붉어지고, S2 뒤엔 docs 오류만 남아 S3를 강제하는 것을 확인했다.
- **`prevent_stop` 재사용** — 같은 "Claude 전용 턴 제어" 부류라 유혹이 있다. 기각: `prevent_stop`은 Stop 훅으로 **턴 종료를 막는** 것이고 이것은 외부 이벤트로 **턴을 재개하는** 것이라 메커니즘도 목적도 다르다. 한 키가 두 뜻을 가지면 Codex의 `false`가 무엇을 부정하는지 읽을 수 없게 된다.
- **소비자가 fg-showme 하나뿐인데 공유 어휘에 넣는가** — `status_display`도 소비자가 `fg-statusline` 하나뿐인 선례가 있다. HOST.md는 메커니즘(`Monitor`)이 아니라 능력을 명명하므로 이름도 `watch_file` 류가 아니라 `event_wake`다 — `session_start`(진입)·`prevent_stop`(종료 방지)·`event_wake`(재진입)의 턴 수명 3형제.
- **산문 범위** — wake를 언급하는 표면은 10파일이지만, `prevent_stop` 선례대로 호스트 차이는 지원표 한 곳에만 살고 README·랜딩·`docs/skills.md`는 호스트 단서 없이 능력을 서술한다. 예외는 `.forge/CONTEXT.md` 하나 — 글로서리는 정답소스라 "터미널 입력 없이 도착한다"를 무조건 단언으로 남길 수 없어 호스트 조건을 달았다.

## 결과

- `core/HOST.md`의 "정확히 여덟 키"가 아홉이 되고 `release-check.parity.test.sh`의 `allkeys` 픽스처도 따라간다(픽스처는 실제 `HOST.md`를 복사해 어휘를 도출하므로 docs 문자열만 손댔다).
- Codex에서 `event_wake`를 `true`로 뒤집는 것은 **관측**이어야 한다(`core/HOST.md` 규율) — 그 조사는 별도 작업(`codex-event-wake-feasibility`)이며, 결론이 "확인 불가"면 `false`가 정직한 값이다.
- 확정 버튼의 `confirm:` 접두가 vendored 코드에 없고 에이전트가 화면마다 손으로 쓰는 규약이라는 점은 이 결정과 별개의 취약성이다 — ADR `260805-005436`의 인라인 결정을 유지한 채 스니펫 정본화로 다루는 것이 별도 작업(`showme-confirm-snippet-single-definition`)이다.

## 개정 2026-09-08 — Codex 측 조사 결과 (`codex-event-wake-feasibility`)

**결론: 수단은 존재하나 관측 미완 → `false` 유지, 상태는 "미지원"이 아니라 "미확인".** 로컬 `codex-cli 0.153.4`에 `codex queue --thread <UUID|exact name> --message <TEXT>`가 있고, 공식 릴리스 노트 `rust-v0.149.0`이 "Added `codex queue` for sending messages to existing local or remote sessions"(#39092)와 "Queued messages now **wake idle sessions reliably**"(#39034)를 적는다. 즉 Codex에는 idle 세션을 외부에서 깨우는 수단이 있다. 그러나 형태가 다르다 — Claude의 `Monitor`는 에이전트가 파일을 **pull**하는 도구인데 `codex queue`는 외부 프로세스가 **push**하는 명령이라, fg-showme가 이를 쓰려면 (a) events 파일을 tail해 `confirm:`에 `codex queue`를 부르는 watcher를 세션 시작 시 띄우고 (b) 대상 세션 id를 알아야 한다. (b)는 `SessionStart` 훅 페이로드의 `session_id`로 가능하다(forge의 stop 훅이 이미 이 필드를 읽는다; `--session-name` 플래그는 0.153.4에 없다). 훅 자체는 관찰 전용이라 턴을 시작하지 못하므로 wake의 후보는 `codex queue` 하나다. **`true`로 뒤집는 조건은 fg-showme가 Codex 세션 안에서 그 watcher로 실제로 깨어나는 관측**이며, 이 조사는 Claude Code 세션에서 수행돼 그 관측을 할 수 없었다 — HOST.md 규율("관측했을 때만 `true`")대로 `false`를 유지한다. 출처: `codex --help`/`codex queue --help`(로컬 실측) · https://github.com/openai/codex/releases/tag/rust-v0.149.0 · https://github.com/openai/codex/pull/39092 · Codex hooks 레퍼런스(`session_id` 공통 필드, 훅은 턴 시작 불가). 후속: push형 어댑터(watcher) 구현 + Codex 세션 실측은 별개 작업.
