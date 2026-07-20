<!-- forge-slug: fg-visual-companion -->
# run — superpowers Visual Companion vendoring (task 1)

실행일: 2026-07-19 · 실행 방식: 직접 실행(아래 divergence 1) + S5는 `manifest-doc-syncer` 도메인 에이전트 위임

## 계획대로 된 것

- **S1 Vendoring + de-branding** — 5파일(`server.cjs`·`start-server.sh`·`stop-server.sh`·`frame-template.html`·`helper.js`)을 `skills/fg-visual/scripts/`로 복제, `.superpowers/brainstorm` → `.forge/visual` 치환, Prime Radiant 원격 로고·버전 텔레메트리·`readSuperpowersVersion`/`isTruthyEnv`/`escapeHtmlText`(고아) 제거, 정적 로컬 브랜딩(`⚒ forge — Visual Companion`), 각 파일 귀속 헤더 + `skills/fg-visual/LICENSE`(MIT 원문). 검증: `node --check`·`bash -n` 통과, smoke(기동→키 200/무키 403→fragment push·프레임 래핑·브랜딩 확인→stop 정상), 원격 호출 0건, 업스트림 diff에 의도된 변경만 존재(파일별 diff 66/17/8/11/5줄 전수 검토).
- **S2 VISUAL.md** — 원본 가이드 기반, Claude Code 전용으로 런치 섹션 트림(Codex/Copilot 제거, ADR-0025), `.forge/visual/` 경로·`${CLAUDE_PLUGIN_ROOT}` 경로·forge 수명 규칙(fg-ask Output 시 stop) 반영. 가이드의 경로·플래그가 vendored 스크립트와 일치.
- **S3 fg-visual SKILL.md** — frontmatter `name: fg-visual`, trigger-core description(회고 2026-07-16 교훈 반영: 트리거 문구+형제 구분, ADR 참조는 본문), 열기→push→`stop` 시나리오·fg-ask 파일 참조 관계 기술.
- **S4 fg-ask 통합** — Forge integration 섹션에 불릿 1줄 삽입(diff가 해당 섹션에만 존재, verbatim 영역 불변): just-in-time 1회 제안·거절 존중·질문 단위 판단·`../fg-visual/VISUAL.md` 참조·Output 시 stop.
- **S5 문서·매니페스트 동기화** (에이전트) — CLAUDE.md 루프 밖 목록, README.md+README.ko.md(18→19, 14→15 동기), docs/skills.md(표+상세 섹션), plugin.json/marketplace.json description(metadata.description 불변). JSON 유효성 OK, 버전 3곳 0.5.18 불변, fg-doctor 0 errors/0 warnings/0 info.

## Divergences (계획↔실제)

1. **Dynamic Workflow 대신 직접 실행.** 슬라이스 의존이 사실상 직렬(S1→S2→{S3,S4}→S5)이고 그릴링 컨텍스트(superpowers 원본 정독·결정 사항)가 메인 세션에 이미 실려 있어, fg-run의 비용 원칙("스케일이 작으면 직접 실행")에 따라 워크플로를 만들지 않았다. S5만 전용 도메인 에이전트에 위임. 결과물은 계획 그대로.
2. **업스트림 진단 2건 원형 유지.** vendored `server.cjs`에 deprecated `buffer.slice`(L427)·미사용 파라미터(L544) 진단이 있으나 업스트림 원형 유지 원칙(ADR 260719-224442의 트윈 관례 예외와 같은 정신)으로 수정하지 않음.
3. **내부 식별자는 업스트림 그대로.** `BRAINSTORM_*` env·`brainstorm-key-` 쿠키·`brainstorm-session-key` 스토리지 키는 사용자 비가시 내부 식별자라 diff 최소화를 위해 유지(계획이 명시하지 않은 현장 결정).
4. **범위 밖 드리프트(후속 후보).** S5 에이전트 보고 + 적대적 리뷰(review.md)가 보강: (a) `docs/forge-vs-loop-engineering.md:15`의 "18개 스킬" 잔존; **`docs/index.html`의 stale 카운트 8곳(L7·111·119·121·197·235·479-480)+fg-visual 카드 부재 — 리뷰가 새로 확인(MAJOR), S5 파일 목록 누락분**, (b) `.forge/codebase/STRUCTURE.md`의 stale 카운트 — fg-map 재실행이 정도, (c) "전역 예외 **두 개**" 표기가 CLAUDE.md뿐 아니라 **`skills/fg-run/FORGE-ROOT.md:18-25,58`(단일 정의 문서)·`docs/state-contract.md:34`에도** 잔존 — `.forge/visual/`이 사실상 세 번째 전역 위치라 세 파일 함께 개정 대상(리뷰가 범위 확장). 모두 이번 plan 범위 밖이라 미수정 — fix-forward/후속 작업 후보.
5. **적대적 리뷰 결과(review.md).** fix-needed 13건(MAJOR 4·MINOR 9). 핵심 MAJOR = 임의 사용자 프로젝트에서 세션 키(.last-token·server-info) 커밋 가능(4렌즈 독립 확증) — plan 결정 4의 gitignore 검증이 forge 리포 한정이었던 오류. 이 리포 자체 봉인/커밋은 무영향(여기선 `.forge/*` gitignore됨). fix-forward plan 권고, 사람 승인 대기. fg-merge CONTEXT 파서 불일치는 선재 버그로 이 브랜치 머지 무영향(최상위 CONTEXT.md 부재로 GATE 2 skip) 확인.

## 막힌 곳

- 없음. (smoke 중 이전 명령의 `cd` 잔존으로 경로 오류 1회 — 절대 경로로 재시도해 해결, 산출물 영향 없음.)
