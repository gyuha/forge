<!-- forge-slug: fg-visual-click-feedback-and-event-label -->
<!-- task: 2 -->
<!-- tdd: off -->
# fg-visual 클릭 피드백 토스트 + events 라벨 정제

## 목표 / 하지 않을 것
- 목표: `helper.js`의 클릭 처리에서 두 결함을 함께 고친다. (1) 클릭이 Claude에 실시간 전달되지 않는다는 사실을 클릭 순간 화면에서 알린다. (2) events의 `text` 필드를 문서가 이미 명세한 대로 짧은 라벨 한 줄로 만든다.
- 하지 않을 것:
  - main 병합·배포·설치본 직접 패치 (task 1과 동일하게 브랜치까지만)
  - upstream obra/superpowers에 보고 (같은 결함이 v6.1.1에 존재하나 범위 밖)
  - `VISUAL.md` 수정 — **문서는 이미 맞다**(아래 참조). 코드를 문서에 맞추는 작업이지 그 반대가 아니다
  - 토스트 문구의 다국어화 — 프레임 UI 문구는 영문 고정이 기존 규약이고, i18n 메커니즘 신설은 이 크기에 과함
  - 회귀 테스트 파일 추가 (리포에 테스트 러너 없음 — task 1과 동일)
  - 신규 ADR

## 정답 기준
- 글로서리 용어: **Visual Companion** (`.forge/CONTEXT.md`) — 추가·변경 없음
- 관련 ADR: `.forge/adr/260719-224442-vendor-superpowers-visual-companion.md` — vendored 파일 수정 근거. 파일 헤더 주석의 `forge modifications:` 목록을 갱신해 upstream 대비 diff를 그 자리에서 설명한다(task 1이 세운 방식 그대로).
- 완료 판정: 카드 목업 화면에서 A/B/C를 클릭했을 때 (a) events의 각 `text`가 해당 카드 제목 한 줄이고 120자 이하이며, (b) 우측 하단 토스트에 그 라벨과 "터미널에 말해야 전달된다"는 안내가 뜨고 다른 카드를 클릭하면 라벨만 갱신되며 저절로 사라지지 않고, (c) 전체 문서(full-document) 화면에서도 토스트가 동일하게 보이며, 변경이 이 브랜치에 커밋되어 있다.

### 진단

**결함 A — 클릭이 전달되지 않는 걸 사용자가 알 방법이 없다.**
브라우저 클릭은 WebSocket으로 서버에 가서 `state_dir/events`에 쌓이지만(`server.cjs:469`가 helper가 보낸 이벤트를 그대로 append), Claude Code 에이전트는 **사용자 턴 없이 깨어나지 않는다**. 그래서 에이전트는 사용자가 터미널에 무언가 입력하는 다음 턴에야 events를 읽는다. 이건 구조적 제약이지 버그가 아니다 — 문제는 그 규칙을 사용자에게 알려주는 곳이 어디에도 없다는 것이다. `toggleSelect()`(`helper.js:149`)가 `.selected` 테두리를 입혀 "골랐다"는 것만 보여줄 뿐, "이걸로는 전달되지 않는다"는 알려주지 않는다.

**결함 B — events의 `text`가 클릭 대상 전체 텍스트로 오염된다.**
`helper.js:139`가 `text: target.textContent.trim()`이라 카드 안 목업의 모든 글자("적용", "취소", 공백 줄까지)가 통째로 들어간다. 실측: 클릭 35번에 events 파일 **26KB**, 이벤트 하나가 수백 자. 에이전트가 읽으면 컨텍스트를 낭비하고 선택을 알아보기도 어렵다.
**`VISUAL.md:233-236`의 events 예시는 이미 `"text":"Option A - Simple Layout"`** — 짧은 라벨 한 줄이다. 문서가 명세한 형태를 구현이 못 지킨 것이므로 해석의 여지 없는 버그이고, 고칠 곳은 코드다.

두 결함은 같은 클릭 핸들러에서 만난다. 라벨 추출 함수 하나가 events의 `text`와 토스트 문구를 동시에 공급하므로 한 작업으로 묶는다.

### 합의된 설계

**라벨 추출** — 카드·옵션 마크업이 이미 제목에 `h3`를 쓰므로(VISUAL.md의 두 예시 모두) 마크업 변경 없이 기존 화면까지 즉시 개선된다.
1. `.card-body h3` 또는 `.content h3`를 먼저 찾는다 — 카드에서 `.card-image` 안 목업이 자체 `h3`를 쓸 수 있어, 단순 `querySelector('h3')`는 문서 순서상 목업 쪽을 잡을 수 있다.
2. 없으면 아무 `h3`.
3. 그것도 없으면 전체 텍스트.
4. 어느 경우든 공백을 한 칸으로 정규화(`\s+` → `' '`)하고 120자로 자른다.

**토스트** — 클릭 순간 우측 하단에 나타나 **머문다**. "터미널에 말해야 전달된다"는 일시적 알림이 아니라 상태이므로 자동으로 사라지면 안 된다(사라지면 사용자는 다시 "선택했는데 아무 일도 안 일어나네" 상태로 돌아간다). 새로 클릭하면 라벨만 갱신되고, 에이전트가 다음 화면을 push하면 `reload`(`helper.js:103`)로 페이지가 새로 그려지며 자연히 사라진다 — 별도 제거 코드는 필요 없다.
- 문구(영문 — 프레임 UI 규약): `Selected: <label>` + `Tell your agent in the terminal — clicks alone don't reach it.`
- 다중 선택(`data-multiselect`)에서 선택을 해제한 클릭이면 `Deselected: <label>`. 인라인 `onclick="toggleSelect(this)"`이 버블링 단계의 document 핸들러보다 먼저 실행되므로, 핸들러에서 `classList.contains('selected')`를 읽으면 갱신된 상태다.
- **자체 스타일이어야 한다.** `showTombstone`(`helper.js:65`)의 주석 *"Self-styled so it works on framed and full-document screens alike"*가 그대로 적용된다 — 에이전트가 전체 문서를 push하면 프레임 CSS가 없으므로 `--bg-secondary` 같은 CSS 변수에 기대면 안 된다. tombstone처럼 색을 직접 지정해 라이트·다크 어느 배경에서도 읽히게 한다.

## 작업 슬라이스
- [ ] S1. `skills/fg-visual/scripts/helper.js`에 라벨 추출 함수를 추가하고 클릭 핸들러의 `text` 필드에 적용한다 — 완료 기준: 카드 목업 화면에서 A/B/C를 클릭했을 때 events의 각 `text`가 해당 카드 제목 한 줄(`A · 좁은 중앙 모달 (권장)` 등)이고 120자 이하이며 개행이 없다
- [ ] S2. 같은 파일에 클릭 토스트를 추가한다 (자체 스타일, 우측 하단 고정, 라벨+안내, 자동 소멸 없음, 새 클릭 시 라벨 갱신) — 완료 기준: 프레임 화면과 전체 문서 화면 **양쪽에서** 클릭 시 토스트가 보이고, 다른 카드를 클릭하면 라벨이 바뀌며, 시간이 지나도 사라지지 않는다
- [ ] S3. 파일 헤더 주석의 `forge modifications:` 목록을 갱신하고 변경을 브랜치에 커밋한다 — 완료 기준: `git status`가 `helper.js`에 대해 clean이고 커밋이 브랜치에 존재 (depends: S1, S2)

## 비고
- **검증 방식**: headless Chrome으로 라벨 추출 결과와 토스트 DOM을 계측하고(프레임/전체문서 두 경우), 실기동 UAT로 실제 클릭 후 events 파일과 토스트를 눈으로 확인한다. task 1과 같은 방식이며 리포에 테스트 파일은 남기지 않는다.
- task 1(`fg-visual-card-image-mockup-collapse`)이 같은 브랜치에서 봉인 대기 중이다. 파일이 겹치지 않으므로(`frame-template.html`+`VISUAL.md` vs `helper.js`) 순서 의존은 없다.
