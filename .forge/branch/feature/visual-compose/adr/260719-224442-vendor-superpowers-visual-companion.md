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
