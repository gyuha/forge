# 2026-06-05 — TDD 지원 (config 설정 표면 + fg-tdd / fg-ask / fg-run, 3 part)

> 한 기능을 3 part(tdd-support-1of3·2of3·3of3)로 분할해 Run-all로 실행. 공통 학습이라 묶음 회고 1건.

## 계획 대비 실제
- 계획대로 된 것: 3 part 모두 계획대로 — part1(config.json 화이트리스트 + fg-tdd 스킬 + 매니페스트·README), part2(PLAN-FORMAT tdd 마커 + fg-ask 시작 질문·기록), part3(fg-run test-first 분기). JSON 유효·README 영/한 동기 확인.
- 차이(divergence): 없음. 결정은 ADR-0008로 기록.

## 학습
- **forge가 첫 설정 표면을 가졌다.** 지금까지 상태의 원천은 전부 "파일 위치"(backlog/active/executed/done)였는데, `.forge/config.json`은 *영속 전역 설정*이라는 새 상태 범주다. 앞으로 설정이 늘면 여기로 모으되, 작업 상태(파일 위치)와 설정(config.json)을 섞지 말 것.
- **마커가 5개째(`tdd`)가 됐다 — 인플레이션 경고 구체화.** task·retro-hint·priority·part·tdd. 다음 마커 추가 전 반드시 "기존과 겹치나·정말 plan에 박혀야 하나(설정/전역이면 config.json로)"를 점검. config 기본값이 per-task 질문 부담을 낮춘 게 이번 완화책.
- **Run-all은 문서 편집엔 안전, 빌드 의존 코드엔 위험.** part 1→2→3은 개념상 전제 관계(설정→질문→실행)지만, *문서* 편집이라 런타임 의존이 없어 Run-all 일괄이 문제없었다. 진짜 빌드/실행 의존이 있는 코드 part였다면 하나씩(1 완료·검증 후 2)이 맞다. fg-run이 part에 "하나씩 권장"을 두는 이유가 이것.
- **이식성 패턴이 정착됐다.** deep-research(0.2.9)·code-review(0.2.11)·TDD(이번) 모두 "fg-skill에 규율을 자체 기술 + 외부 역량은 가용 시 선택적, 하드 의존 금지"로 동일하게 풀렸다. 외부 역량 통합 시 기본 템플릿으로 삼을 것.
- 다음에 다르게 할 것: **분할-기능의 회고 짝맞춤 갭.** 회고는 `*-<slug>.md`로 slug마다 짝을 보는데, 한 기능의 part들은 회고를 공유하는 게 자연스럽다(이번에 공유 회고 1건 + 각 part STATUS의 retro를 이 파일로 가리킴). fg-learn/fg-cleanup의 part 회고 처리를 언젠가 명문화할 것.

## 문서 갱신
- CONTEXT.md 승급: 없음
- ADR 추가: 없음 — 설정 표면·TDD 도입은 ADR-0008(`.forge/adr/0008-tdd-support-and-config-surface.md`)에 이미 기록
