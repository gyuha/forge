# 2026-06-14 — fg-statusline 강건 재설계 (tilde·cwd·문서/구현 불일치 제거)

## Plan vs actual
- What went as planned:
  - S1(fragment의 stdin cwd 파싱), S2(generic wrapper + orig.sh), S3(SKILL.md 정정 + ADR-0017 개정) 모두 plan대로 구현. TDD로 진행해 자동 테스트 24개(fragment 19 + wrapper 5) 전부 green.
  - 채택한 진단(tilde가 유력 root cause)이 라이브에서 사실로 확인됨 — settings command가 실제로 `~/.claude/...`였고, 절대경로 교정 후 UAT 통과.
- Divergences:
  - **라이브 환경이 작업 트리보다 뒤처져 있었다.** S1–S3 코드는 작업 트리에 완성됐지만 라이브 `~/.claude/`의 fragment·wrapper는 구버전, settings는 tilde 그대로였다. plan이 고치려던 결함이 라이브에 그대로 남아 있었고, S4(라이브 교정)에서야 스크립트 2개 복사 + settings 절대경로화로 해소했다.
  - **이 작업이 fg-run 워크플로우를 거치지 않았다.** 본 세션 대화로 직접 구현돼 run.md/STATUS.md가 비어 있었고, 회고·봉인 시점에 보강 작성해야 했다.

## Learnings
- Do differently next time:
  - **fg-statusline(또는 라이브 설치본이 있는 스크립트) 수정 작업의 DoD는 "작업 트리 코드 수정"이 아니라 "라이브 동기화"까지다.** fg-statusline은 "설치 시 복사" 모델이라 스크립트를 고쳐도 사용자가 재실행/복사하기 전엔 라이브에 반영되지 않는다 — 이런 작업 plan엔 항상 라이브 교정(스크립트 복사 + settings 절대경로) 슬라이스를 명시적으로 둘 것.
  - **fg-run을 건너뛰고 직접 구현하면 run.md/STATUS가 비어 봉인 게이트(verified)가 막힌다.** 직접 구현하더라도 최소한 STATUS는 그 자리에서 남기는 편이 회고·봉인을 매끄럽게 한다.
  - statusLine 변경은 **재시작 후 적용**이고 tilde 경로는 조용히 전체 statusline을 공백으로 만든다 — 같은 세션에서 "안 보인다"로 판단하지 말 것(이미 SKILL.md·ADR-0017에 명시).

## Doc updates
- CONTEXT.md promotion: none (새 도메인 용어 없음 — wrapper·fragment·cwd는 구현 개념)
- ADR added: none — 단 **ADR-0017이 작업 중 개정**됨(2026-06-14 "강건성 재설계" 섹션). 기존 결정의 메커니즘 개정이라 새 ADR은 불필요.
