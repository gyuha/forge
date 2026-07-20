<!-- forge-slug: fg-visual-companion -->
<!-- task: 1 -->
<!-- tdd: off -->
# superpowers Visual Companion vendoring — fg-visual 스킬 신설 + fg-ask 그릴링 통합

## Goal / Non-goals

- Goal: obra/superpowers(MIT)의 브라우저 기반 Visual Companion(zero-dep Node 서버 + 프레임 템플릿 + 사용 가이드)을 forge에 vendoring하여 `fg-visual` 스킬로 신설하고, fg-ask 그릴링 중 시각적 질문(mockup·레이아웃 비교·다이어그램)이 나올 때 just-in-time으로 제안·활용할 수 있게 한다.
- Non-goals:
  - fg-run·fg-loop·fg-learn·fg-agents 등 다른 루프 스킬 통합 없음(소비자는 fg-ask + 단독 트리거만).
  - `.forge/config.json` 토글 없음(제안 기반 — ADR-0006 계열).
  - superpowers 테스트 스위트(`tests/brainstorm-server/`) 이식 없음(npm 의존 유입 거부, 검증은 실기동 UAT).
  - Codex/Copilot/Gemini 등 타 플랫폼 런치 지시 유지 없음 — Claude Code 전용으로 트림(ADR-0025).
  - 텔레메트리·원격 자원 로드 없음(Prime Radiant 로고·버전 전송 제거).
  - vendored 스크립트에 ADR-0022 bash+node 트윈 관례 비적용(업스트림 파일 원형 유지 — ADR 260719-224442 참조).

## Source of truth

- Glossary terms: **Visual Companion** — `.forge/CONTEXT.md`(브랜치 루트)
- Related ADRs:
  - `.forge/adr/260719-224442-vendor-superpowers-visual-companion.md` (이번 결정: vendoring·소유 위치·세션 경로·수명)
  - ADR-0006 (선택적 연료의 '제안만, 자동실행 없음' 선례), ADR-0025 (Claude Code 전용), ADR-0022 (스크립트 트윈 관례 — 이번 건은 명시적 예외), 260716-22a (스킬 description trigger-core 규율)
- 원본: `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.1.1/skills/brainstorming/` — `scripts/`(server.cjs 723줄·start-server.sh·stop-server.sh·frame-template.html·helper.js, 총 ~1,430줄) + `visual-companion.md`. MIT (Copyright (c) 2025 Jesse Vincent).
- Definition of Done: fg-ask 그릴링 중 시각적 질문에서 컴패니언이 단독 메시지로 1회 제안되고, 수락 시 브라우저가 열려 mockup 화면과 클릭 이벤트(`state/events`) 수집이 동작하며, 핸드오프 시 서버가 종료된다. 매니페스트·문서(19-스킬 카탈로그)가 동기화되고 `fg-doctor`가 클린하다.

## 합의된 설계 결정 (그릴링 전사)

1. **구현 방식 = vendoring** — superpowers의 zero-dep 파일 5개를 MIT 귀속과 함께 복제. superpowers 설치 여부와 무관하게 forge 단독 동작. (참조 방식·자체 재구현 거부 — ADR 참조)
2. **소유 위치 = 새 스킬 `skills/fg-visual/`** — SKILL.md + VISUAL.md(가이드) + scripts/(서버 4파일 + 템플릿). fg-ask는 스킬 호출이 아니라 **파일 참조**(`${CLAUDE_PLUGIN_ROOT}/skills/fg-visual/VISUAL.md`)로 사용 — ECO.md/FORGE-ROOT.md와 같은 "단일 정의, 소유 스킬 디렉터리" 관례. fg-ask 디렉터리의 verbatim 3파일 계약은 불변.
3. **제안 규율 = superpowers 그대로** — 선불 제안 금지. 시각적으로 보여주는 게 명백히 나은 질문이 *처음* 나올 때 **단독 메시지**로 1회 제안, 거절하면 재제안 없음, 수락 후에도 질문 단위로 브라우저/터미널 판단("UI 주제냐"가 아니라 "보여야 이해되냐").
4. **세션 경로 = 최상위 `.forge/visual/<세션>/`** — 모든 브랜치에서 최상위(config.json·codebase/와 같은 전역 취급). `.gitignore`의 `.forge/*` 기본 제외에 해당되어 추적 안 됨(확인 완료, .gitignore 수정 불필요). 브랜치 루트에 두면 mockup HTML이 git 추적되므로 거부.
5. **서버 수명 = fg-ask 핸드오프(Output) 시 종료** — stop-server 실행. 중단·방치 세션은 4시간 유휴 타임아웃이 백스톱. mockup 파일은 `.forge/visual/`에 잔존(참고용).
6. **fg-visual 단독 트리거 = 범용 시각 유틸리티(루프 밖)** — 어느 대화에서든 컴패니언을 열어 VISUAL.md 규율대로 화면 push·클릭 수집, `stop` 인자로 종료.
7. **검증 = TDD off + 실기동 UAT.**

## Work slices

- [ ] S1. **Vendoring + de-branding** — `skills/fg-visual/scripts/`에 5파일 복제(server.cjs·start-server.sh·stop-server.sh·frame-template.html·helper.js). 세션 경로 `.superpowers/brainstorm` → `.forge/visual` 치환, Prime Radiant 원격 로고·버전 텔레메트리 제거(로컬 정적 forge 헤더로 교체), 각 파일 상단 출처·MIT 귀속 헤더 + `skills/fg-visual/LICENSE`(원본 MIT 사본). `.sh` 실행 비트 유지. — 완료 기준: `node --check server.cjs`·`bash -n *.sh` 통과, 서버 기동→키 포함 URL curl 200→stop 정상, 원격(비-localhost) 호출 코드 grep 0건.
- [ ] S2. **VISUAL.md 가이드** — superpowers `visual-companion.md` 기반으로 작성(영문): Claude Code 전용으로 런치 섹션 트림(ADR-0025), `.forge/visual/` 경로 반영, 콘텐츠 fragment 작성법·CSS 클래스·이벤트 형식·unload(waiting 화면)·수명 규칙 유지. — 완료 기준: 가이드의 모든 경로·명령이 S1 vendored 스크립트와 일치(불일치 0). (depends: S1)
- [ ] S3. **fg-visual SKILL.md** — 영문, 루프 밖 범용 시각 유틸리티. 직접 트리거 동작(열기→VISUAL.md 규율로 화면 push→`stop` 인자로 종료), frontmatter `name: fg-visual`, description은 trigger-core 규율(260716-22a) — 트리거 문맥: 'forge visual', '시각적으로 보여줘', 'mockup 보여줘', 'visual companion' 등. 사용자 출력은 사용자 언어. — 완료 기준: frontmatter `name` 존재, 열기→push→stop 시나리오와 fg-ask 관계(파일 참조·자동 제안) 기술. (depends: S2)
- [ ] S4. **fg-ask 통합** — `skills/fg-ask/SKILL.md`의 "Forge integration (minimal)" 섹션에만 불릿 추가(영문): just-in-time 1회 제안(단독 메시지)·거절 존중·질문 단위 판단·수락 시 `../fg-visual/VISUAL.md` 읽고 서버 기동·Output 핸드오프 시 stop-server. verbatim 본문(원본 3파일 영역)은 불변. — 완료 기준: diff가 Forge integration 섹션에만 존재. (depends: S2)
- [ ] S5. **문서·매니페스트 동기화** — CLAUDE.md(루프 밖 스킬 목록에 fg-visual 추가), README.md + README.ko.md(동일 변경 쌍), docs/skills.md, `plugin.json`·`marketplace.json`의 `plugins[].description`/`description`(18→19 스킬; `metadata.description`은 루프 정의라 불변). — 완료 기준: 매니페스트 JSON 유효성 node 한 줄 OK + `fg-doctor` 정합 검사 클린. (depends: S3, S4)

## 검증(UAT) 시나리오

1. `start-server.sh --project-dir <repo> --open` → 브라우저 자동 오픈, 키 포함 URL 반환.
2. content 디렉터리에 A/B 레이아웃 fragment HTML 작성 → 브라우저 자동 갱신 확인.
3. 브라우저에서 옵션 클릭 → `state/events`에 JSONL 기록 확인.
4. `stop-server.sh` → 종료, `.forge/visual/`에 mockup 잔존 확인.
5. `fg-doctor` 실행 → `.forge/visual/` 관련 오탐 없음(사전 확인 완료: doctor는 지정 계약만 검사).
