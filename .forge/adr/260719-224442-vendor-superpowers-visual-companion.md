---
author: gyuha
decided: 2026-07-19 22:44
---
# Visual Companion은 superpowers를 vendoring한다 — fg-visual 스킬, 전역 .forge/visual/ 세션, 핸드오프 시 종료

## 맥락
fg-ask 그릴링 중 UI 관련 질문(mockup·레이아웃 비교·다이어그램)은 터미널 텍스트보다 브라우저로 보여주는 게 명확하다. obra/superpowers(MIT)의 brainstorming 스킬에 검증된 구현이 있다 — zero-dependency Node 서버(세션 키 인증·경로 샌드박스·재시작/재연결 생존·4h 유휴 종료)가 에이전트가 쓴 HTML을 브라우저에 밀어주고 클릭 선택을 JSONL 이벤트로 수집한다. "산출물은 전부 Markdown/JSON"인 forge 리포에 웹 서버 코드(~1,430줄)가 들어오는 의외의 결정이라 기록한다.

## 결정
1. **Vendoring** — superpowers의 5개 파일(server.cjs·start/stop-server.sh·frame-template.html·helper.js)을 MIT 귀속(LICENSE 사본 + 파일 헤더)과 함께 복제한다. superpowers 설치 여부와 무관하게 forge 단독 동작. 브랜딩·텔레메트리(Prime Radiant 원격 로고·버전 전송)는 제거 — 네트워크는 localhost 서버 자체뿐.
2. **소유 = 새 루프 밖 스킬 `fg-visual`** — 가이드(VISUAL.md)·스크립트의 단일 정의를 `skills/fg-visual/`에 두고, fg-ask는 스킬 호출이 아니라 파일 참조로 사용(ECO.md·FORGE-ROOT.md 관례). fg-ask 디렉터리의 verbatim 3파일 계약 불변.
3. **제안 규율 = superpowers 그대로** — just-in-time 1회 제안(단독 메시지), 거절 존중, 수락 후에도 질문 단위 브라우저/터미널 판단. config 토글 없음(ADR-0006의 '제안만, 자동실행 없음' 계열).
4. **세션 상태 = 최상위 `.forge/visual/`(전역)** — 브랜치 루트는 통째로 git 추적이라 mockup HTML이 커밋에 섞이므로 거부. `.gitignore`의 `.forge/*` 기본 제외가 그대로 커버(수정 불필요).
5. **수명 = fg-ask 핸드오프 시 stop** + 4h 유휴 타임아웃 백스톱.
6. **ADR-0022 트윈 관례의 명시적 예외** — vendored 업스트림 파일은 bash+node 트윈을 만들지 않고 원형을 유지한다(업스트림 추적 용이·재작성 위험 회피). 서버는 node, 런처는 bash 그대로.

## 고려한 대안
- **superpowers 설치본 참조**(가용 시에만 활성) — 거부: 플러그인 캐시의 버전 디렉터리 경로에 의존해 깨지기 쉽고, superpowers 없는 사용자에겐 기능 자체가 없다.
- **자체 최소 재구현** — 거부: 인증·재연결·샌드박스 등 검증된 부분을 다시 만들 이유가 없고, 이 리포는 테스트 인프라가 없어 회귀 위험이 크다.
- **superpowers 테스트 스위트 이식** — 거부: npm 의존이 리포에 유입(zero-dep 성격 훼손). 검증은 실기동 UAT.

## 개정 (2026-09-02) — 세션 잔여물의 구조적 git 격리와 완결 시 삭제 (결정 4·5 보강, 업스트림 보존 의도와 결별)

**결정 4의 전제가 forge 자기 리포에서만 참이었다.** *"`.gitignore`의 `.forge/*` 기본 제외가 그대로 커버(수정 불필요)"*는 forge 리포의 `.gitignore`를 두고 한 말이고, **사용자 프로젝트에는 그 규칙이 없다** — fg-security 개정(ADR `260820-215004` ⑧)이 이름 붙인 "검증 환경을 의심하지 않은" 바로 그 함정이다. 사용자 프로젝트에서 `git add -A`는 목업 HTML·이벤트 로그·세션 키 파일(`.last-token`·`server-info`)을 스테이징했다.

**보강 1 — 자체-ignore.** `start-server.sh`가 `--project-dir` 모드에서 `.forge/showme/.gitignore`(내용 `*` 한 줄)를 없을 때 써 준다. 중첩 gitignore는 디렉터리가 스스로를 통째로 가리므로 사용자 프로젝트의 루트 `.gitignore` 유무와 무관하게 동작한다. 이로써 "forge는 사용자 프로젝트에 `.gitignore`를 쓰지 않는다"(fg-security ADR의 논거)는 **"사용자의 `.gitignore`를 편집하지 않는다 — 자기 상태 디렉터리 안의 자체-ignore는 예외"**로 좁혀진다. 고려한 대안: 사용자 루트 `.gitignore`에 append — 사용자 소유 파일을 forge가 편집하게 되어 거부.

**보강 2 — 완결 시 삭제 (업스트림 의도 역전).** 업스트림 `stop-server.sh`는 `.forge/showme/` 세션을 *"나중에 목업을 다시 볼 수 있게"* 의도적으로 보존했다(`/tmp`만 삭제). 이를 역전한다: 정상 종료·`stale_pid` 경로 모두 세션 폴더를 삭제하고, 마지막 세션이면 `.forge/showme/`를 통째로 제거한다(`.last-*`·`.gitignore` 포함 — 의도적 완결 후에는 재연결할 대상이 없다). 대가: 완결 후 목업 재열람 불가(필요하면 종료 전에 복사). 트레이드오프를 알고 "흔적 없음"을 택했다.

**보강 3 — 시작 시 sweep.** 크래시·4h 유휴 타임아웃으로 "완결되지 못한" 세션은 stop이 불리지 않아 영원히 쌓인다(실증: forge 리포에 잔여 세션 2개). `start-server.sh`가 새 세션 생성 직전에 죽은 세션(정지 마커 또는 죽은/부재 PID)을 삭제한다. 살아있는 동시 세션과 `.last-*`는 불변 — 크래시 후 재시작 시 열린 탭 재연결(결정의 원래 기능)을 보존한다. `server.cjs`가 유휴 종료 시 자기 폴더를 지우는 대안은 vendored 본체 diff를 키워 거부(sweep이 어차피 처리).

**불변**: 결정 1(vendoring)·2(소유)·3(제안 규율)·6(트윈 예외)은 그대로다. 이 개정은 세션 잔여물의 수명만 바꾼다 — 수정은 vendored 런처 2개(`start/stop-server.sh`)에 국한되고 각 파일 헤더에 기록했다.
