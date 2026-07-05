# 2026-07-05 — fg-done 봉인 결정론 스크립트화 (task #68)

## Plan vs actual
- What went as planned: S1~S5 전부 계획대로. 스크립트↔산문 경계·공유 봉인 프리미티브(3경로)·게이트-우선-비파괴·완전 parity(.sh/.js)가 ADR-0030 설계 그대로 구현됐고, behavior 39(.sh·.js)+parity 11 green, 스킬·매니페스트·이중언어·docs 동기, skill 개수 18 불변. divergence 낮음.
- Divergences (낮음 — 재그릴 불필요):
  - **Dynamic Workflow 대신 메인 세션 직접 순차 TDD.** 이 환경 subagent 팬아웃 `fork failed`가 #67·#68 연속 확인됨 + 의존 사슬 거의 선형 + 파괴적 트윈-parity 델리킷 → 직접 실행이 신뢰성 높음. fg-run이 "scale 작으면 workflow 생략" 명시 허용.
  - **behavior 테스트 impl-파라미터화(`FGDONE_IMPL`).** S1은 behavior 테스트만 명시했으나 S3 criterion("behavior가 .js에도 green")을 만족하려면 impl 오버라이드 필요 → statusline-full.test.sh와 동형 보강.
  - **fg-next SKILL.md 1줄 정확화.** "cleanup-time skip path"→"seal script의 `--skip-retro`(ADR-0030)". 위임 상속이라 로직 불변.
  - **index.html 미수정.** #67과 달리 fg-done 언급이 일반 핸드오프 서술(사실 정확)이라 손 안 댐 — 상황이 다름(스크립트는 내부 메커니즘, 사용자 대면 동작 불변).

## Learnings
- Do differently next time:
  - **이 환경에선 스크립트-트윈 TDD 작업에 직접 순차 실행이 기본.** 팬아웃 `fork failed`가 이제 3사례(2026-07-05 감사·#67·#68)에서 확인됐다. "workflow가 기본, 직접은 예외"가 아니라, 이 환경에선 선형·델리킷 스크립트 작업은 직접이 기본이고 workflow가 예외다. (fg-run 규정이 이미 허용하므로 별도 승급 불필요 — 프로세스 확인.)
  - **script-twin 작업은 behavior 테스트를 `IMPL` 인자로 파라미터화하라.** `.js` 트윈을 같은 fixture로 검증하는 표준 수단(statusline-full·fg-done 2회). 새 트윈 스크립트의 기본 패턴으로 굳힘.
  - **doc 동기 시 "사실-stale(필수 수정)"과 "내부-정확(방치)"을 구분하라.** #67 index.html은 방법 1만 서술해 틀렸으므로 계획 파일목록 밖이어도 수정했고, #68 index.html은 정확해 방치했다. DoD("docs 동기")를 파일 목록보다 우선하되, "동기"는 사실 오류 교정이지 무조건 편집이 아니다.
- Confirmed (계속 유지):
  - **"기계적은 스크립트, 판단은 산문" 패턴이 3번 반복돼 컨벤션으로 굳음.** fg-status(0020)→statusline(0029)→fg-done(0030). 이번에 ADR-0031(컨벤션)로 승격 — 새 스킬 작성자의 단일 정본.
  - **파괴적 스크립트는 게이트-우선-비파괴가 read-only 스크립트보다 안전.** LLM 손 bash의 부분 상태(half-sealed) 위험을 원자적 스크립트가 제거. 라이브 데모로 pending→exit 3 비파괴 확인.

## Follow-ups (이번 작업 무관, 별도 처리 후보)
- **fg-agents/SKILL.md `^name:` 중복** — 본문에 `name:`로 시작하는 줄이 있어 배포 체크 `awk '/^name:/'`가 19로 셈(SKILL.md 디렉터리는 18로 정상). #67에서 발견, 미해결.
- **Windows용 node wrapper** — ADR-0029에서 deferred(방법 1 크로스플랫폼).

## Doc updates
- CONTEXT.md promotion: none (신규 도메인 용어 없음; `.forge/CONTEXT.md` 부재).
- ADR added: **ADR-0031**(forge 스킬의 스크립트 백킹 컨벤션 — 0020/0029/0030에 흩어진 원칙을 단일 정본으로 승격). ADR-0030은 fg-ask 그릴링에서 이미 생성됨.
