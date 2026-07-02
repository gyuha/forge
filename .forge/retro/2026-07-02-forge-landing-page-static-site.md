# 2026-07-02 — Forge 디자인 목업을 docs/index.html 정적 랜딩 페이지로 구현

## Plan vs actual
- What went as planned: S1~S4 전부 계획대로. `Forge.dc.html`의 `x-dc`/`sc-for`/`sc-if`/`{{ }}`/`DCLogic`을 걷어내고 정적 HTML/CSS/vanilla JS로 `docs/index.html`을 작성, 스킬 카탈로그를 18개(루프 4 + 유틸리티 14)로 갱신, 통계 문구(11→18, 7→14) 갱신, 푸터 "팬 사이트" 문구 제거, 파비콘 연결, `docs/.nojekyll` 추가까지 완료.
- Divergences (범위 변경이 아니라 실행 방식 선택):
  - 산출물이 파일 1~2개(index.html + .nojekyll)뿐이라 Dynamic Workflow 오버헤드를 피해 **직접 실행**함(fg-run 비용 규약 적용).
  - 검증을 plan 요구("로컬 정적 서버 또는 파일 열기")보다 **더 엄격하게** — `python3 -m http.server`로 docs/를 서빙하고 playwriter(Chrome 확장 연동) 실브라우저로 9개 섹션 전체 스크린샷 대조 + 콘솔 에러 0건 확인.
  - 사소한 운영 해프닝: 스킬 섹션 스크린샷 중 탭이 `about:blank`로 튐(확장/탭 연결 이슈 추정) → 재-goto로 복구해 나머지 섹션 재확인. 산출물 영향 0.

## Learnings
- Do differently next time:
  - Claude Design 프리뷰 파일(`*.dc.html`)은 `x-dc`/`sc-for`/`{{ }}` 템플릿과 React 기반 `support.js` 런타임에 의존하므로 **그대로 배포 불가** — 실제 정적 사이트로 쓰려면 항상 데이터를 하드코딩한 순수 HTML로 변환하는 단계가 필수임을 명시적으로 인지.
  - 디자인 목업은 **시점의 스냅샷일 뿐 소스 오브 트루스가 아니다** (이번에 스킬 개수 11→18 불일치). 목업을 그대로 베끼기 전에 프로젝트 실제 상태(README.md/CLAUDE.md)와 대조하는 절차가 안전.
  - UI성 산출물은 **실브라우저(playwriter)로 스크롤·hover·애니메이션까지** 확인하는 것이 grep/구조 검증보다 신뢰도가 훨씬 높다 — 다음에도 UI 산출물은 실브라우저로 최종 확인.

## Doc updates
- CONTEXT.md promotion: none (forge 자체 도메인 용어를 다루는 작업이 아님)
- ADR added: none (되돌리기 쉬운 명백한 단순화 선택이라 ADR 3조건 미충족)

## Follow-up candidates (후속 후보 — 승급 아님, 새 작업 후보)
- fg-ask 그릴링에 "디자인 목업 ↔ 프로젝트 실제 상태(README/CLAUDE.md) 대조" 렌즈를 추가하는 fg-* 스킬 개선.
- 랜딩 페이지가 루프 밖에서 계속 개선되는 중(desktop stacking scroll, 애니메이션, footer 배경 이미지) — 향후 랜딩 개선은 fg-quick으로 최소 추적하거나 별도 backlog로 관리하면 표류를 줄일 수 있음.
