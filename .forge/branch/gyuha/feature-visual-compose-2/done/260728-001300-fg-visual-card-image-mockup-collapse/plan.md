<!-- forge-slug: fg-visual-card-image-mockup-collapse -->
<!-- task: 1 -->
<!-- retro-hint: optional -->
<!-- tdd: off -->
# fg-visual 카드 목업이 24px로 붕괴하고 좁은 폭에서 잘리는 문제 수정

## 목표 / 하지 않을 것
- 목표: `frame-template.html`의 `.card-image` 슬롯을 고쳐, 카드 안에 넣은 목업이 (1) 폭을 채우고 (2) 카드 폭이 좁아져도 세로로 잘리지 않게 한다. VISUAL.md에 남는 함정 한 줄을 보강한다.
- 하지 않을 것:
  - main 병합·배포·설치본(`/Users/gyuha/workspace/forge`) 직접 패치 — 이 작업은 브랜치까지만. 따라서 **이 수정 직후에도 story-weaver 등 설치본을 쓰는 환경에서는 여전히 깨진 채**이며, 반영 시점은 별도 판단.
  - upstream obra/superpowers에 버그 보고 (같은 버그가 v6.1.1에 존재하나 이번 범위 밖)
  - 회귀 테스트 스크립트·검증용 샘플 파일을 리포에 추가 (리포에 테스트 인프라가 없고 headless Chrome 의존을 들이지 않기로 함)
  - `.card-image` 외의 frame-template CSS 손보기 (전수 확인 결과 나머지는 안전)
  - 신규 ADR 생성 (되돌리기 쉽고, 정책 근거는 기존 vendoring ADR이 이미 제공)

## 정답 기준
- 글로서리 용어: **Visual Companion** (`.forge/CONTEXT.md`) — 이번 작업으로 추가·변경되는 용어 없음
- 관련 ADR: `.forge/adr/260719-224442-vendor-superpowers-visual-companion.md` — vendored 파일 수정의 근거. 6항 "원형 유지"는 **bash+node 트윈 관례(ADR-0022)의 예외**를 뜻하며 버그 수정 금지가 아니다. 브랜딩·텔레메트리 제거라는 수정 전례가 이미 있으므로, 파일 헤더 주석의 `forge modifications:` 목록을 갱신하는 방식으로 upstream 대비 diff를 그 자리에서 설명한다.
- 완료 판정: headless Chrome으로 1600 / 1200 / 900px 세 폭에서 카드 목업 페이지를 렌더링했을 때 **모든 폭에서 `.card-image` 자식 폭 == 컨테이너 폭**이고 **컨테이너 높이 >= 자식 높이**(잘림 0)이며, VISUAL.md 카드 섹션에 단일 루트 안내가 있고, 변경이 이 브랜치에 커밋되어 있다.

### 진단 (그릴링 중 실측 확정)
원인은 두 개이며 둘 다 `frame-template.html:147`의 한 규칙에서 나온다.

```css
.card-image { background: var(--bg-tertiary); aspect-ratio: 16/10; display: flex; align-items: center; justify-content: center; }
```

1. **폭 붕괴** — 이 슬롯은 원본에서 이모지·짧은 텍스트 썸네일을 중앙 정렬하려고 `display:flex`로 만들어졌다. 그런데 VISUAL.md는 `<div class="card-image"><!-- mockup content --></div>`로 목업을 넣으라고 안내한다. 목업 컨테이너가 flex item이 되고, 목업 내부는 전부 `position:absolute`(모달·딤)거나 폭 미지정 블록이라 내재 폭이 0 → shrink-to-fit으로 min-content까지 붕괴. 실측: 컨테이너 499px, 자식 **24px**(한글 한 글자 폭). 그래서 `width:74%`인 모달이 18px가 되고 글자가 세로로 쌓였다.
2. **세로 잘림** — `aspect-ratio:16/10`이라 슬롯 높이가 카드 폭에 종속되는데, 카드 그리드는 `repeat(auto-fit, minmax(280px,1fr))`이라 폭이 창 크기에 따라 변한다. 에이전트는 목업 높이를 픽셀로 고정해 쓰므로 어떤 값을 써도 창을 줄이면 `overflow:hidden`에 잘린다. 실측: 창 1200px에서 슬롯 229px vs 목업 280px → **51px 잘림**, 사이드 시트 안의 헤더 줄이 통째로 사라졌다.

`.card-image`가 "flex 중앙정렬 + 자식 폭 미지정" 조합인 **유일한** 지점이다(`.options`는 flex column이라 가로 stretch, `.cards`/`.split`/`.pros-cons`는 grid라 기본 stretch, `.option`의 자식은 `flex:1`, `.header`는 `minmax(0,1fr)` — 전수 확인 완료).

### 검증된 수정안
아래 2줄은 그릴링 중 실제 렌더링으로 이미 검증했다(1600/1200/900px 전부 통과).

```css
- .card-image { background: var(--bg-tertiary); aspect-ratio: 16/10; display: flex; align-items: center; justify-content: center; }
+ .card-image { background: var(--bg-tertiary); min-height: 180px; display: flex; align-items: center; justify-content: center; }
+ .card-image > :only-child { width: 100%; }
```

- `:only-child`로 한정한 이유: 자식이 여럿일 때 각각 100% 폭이 되어 가로 나열 의도가 깨지는 것을 피한다. 텍스트 노드(`<div class="card-image">🖼️</div>`)는 요소가 아니므로 이 셀렉터에 걸리지 않아 기존 중앙 정렬이 보존된다.
- `min-height: 180px`로 바꾼 대가: 카드마다 목업 높이가 다르면 `card-body` 시작 위치가 어긋나고, 16:10으로 일관되던 썸네일 비율이 사라진다. 잘림(정보 손실)을 막는 편익이 더 크다고 판단했다.

## 작업 슬라이스
- [ ] S1. `skills/fg-visual/scripts/frame-template.html`의 `.card-image` 규칙을 위 검증된 2줄로 교체하고, 파일 헤더 주석의 `forge modifications:` 목록에 이 변경(카드 목업 폭 붕괴·세로 잘림 수정)을 추가한다 — 완료 기준: headless Chrome으로 1600/1200/900px 렌더링 시 세 폭 모두 `.card-image` 자식 폭 == 컨테이너 폭이고 컨테이너 높이 >= 자식 높이
- [ ] S2. `skills/fg-visual/VISUAL.md`의 "Cards (visual designs)" 섹션에 남는 함정을 한 줄 보강한다 — 카드 안 목업은 **단일 루트 요소로 감싸면 자동으로 폭을 채우고**, 형제를 여럿 직접 넣으면 각자 내재 폭으로 줄어든다 — 완료 기준: 해당 섹션에 그 안내 문장이 있고, 이미 CSS로 해결된 `width:100%` 지시는 넣지 않는다
- [ ] S3. 변경을 이 브랜치에 커밋한다 (`fix(fg-visual): card-image 목업 폭 붕괴·세로 잘림 수정`) — 완료 기준: `git status`가 이 두 파일에 대해 clean이고 커밋이 브랜치에 존재 (depends: S1, S2)

## 비고
- **검증 방식**: 위 완료 기준의 headless Chrome 실측 + fg-run 핸드오프 UAT(실제로 fg-visual을 기동해 카드 목업을 push하고 브라우저에서 육안 확인, 창 크기를 줄여도 안 잘리는지 확인). 리포에 테스트 파일은 남기지 않는다.
- 재현·검증에 쓴 임시 파일은 세션 스크래치패드에 있으며 리포에 들어가지 않는다.
