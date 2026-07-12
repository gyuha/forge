# 2026-07-13 — fg-ask 시작 시 완료 안 된 작업 체크를 명시적 STEP 0으로 재배치

## 계획 대비 실제
- 계획대로 된 것: `skills/fg-ask/SKILL.md`의 "check for existing work" 불릿(하위 (1)/(1b)/(2) 포함)을 "Forge root" 뒤·"feed back the latest retros" 앞으로 이동하고, 명령형 STEP 0("you MUST first check…")으로 재프레이밍. 방향어 `reads above` → `reads below` 정정. (a)/(b)/(1b)/(2) 판단·라우팅 문구는 문자 그대로 불변. Definition of Done(불릿 순서·방향어·문구 불변) 전부 grep으로 확인, UAT 통과.
- Divergences: 미미. 계획에 없던 마무리 문장 한 줄("This is the entry step: run it before any of the setup reads that follow, not after.")을 범위 내 판단으로 추가 — 슬라이스 의도(명령형 STEP 0 강화)를 보강, 의미 변화 없음.

## Learnings
- 근본 원인은 **문서 순서 역전**이었다: "이걸 먼저 하라"고 자기 본문에 적은 불릿이 정작 그 대상(retro/map 읽기)보다 *뒤에* 놓여 있었다. 위→아래로 읽는 LLM에겐 **배치(salience)가 곧 지시의 일부** — 내용이 맞아도 순서가 어긋나면 건너뛴다. 다음에 스킬 문서에서 "먼저 하라"류 지시를 넣을 땐, 문구뿐 아니라 **실행 순서대로 물리적 위치**를 맞춰라("순서=명령").
- 측정 한계(정직히): 이 변경의 진짜 목표(LLM이 실제로 시작 체크를 안 건너뜀)는 **행동 베팅**이라 단발 UAT로 확인 불가. 앞으로 fg-ask 세션에서만 드러난다 — 이번 UAT는 관측 가능한 문서 구조에 한해 통과. 유사한 "salience 개선" 작업은 DoD를 문서 구조로만 잡고, 실효는 후속 세션 관찰로 미루는 게 정직하다.
- 후속 후보(미승급): "순서=명령(top-down 독자에겐 배치가 지시)" 휴리스틱은 프로젝트 `CLAUDE.md`의 "스킬 편집 규약"에 한 줄로 넣을 값어치가 있으나, forge ADR/CONTEXT 대상은 아님 — 필요 시 별도 액션(fg-quick)으로.

## Doc updates
- CONTEXT.md promotion: none (새 용어 없음)
- ADR added: none (되돌리기 쉬운 저위험 위치 조정 — ADR 3조건 미달)
