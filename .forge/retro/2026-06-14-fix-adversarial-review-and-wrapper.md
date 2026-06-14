# 2026-06-14 — Codex 적대적 리뷰 findings 수정 (fg-adversarial-review 범위 + wrapper 경로)

## Plan vs actual
- What went as planned:
  - 결함 1: fg-adversarial-review를 활성 슬롯 전용으로 좁혀 findings 기록 모호성 제거, ADR-0018에 범위 명시. parked는 "리뷰 대상 아님 + unpark 안내"로만 남김.
  - 결함 2: wrapper를 `BASH_SOURCE` 자기 위치 해석으로 전환, custom config dir 회귀 테스트 추가. test-first(red 7 → green 7), fragment 19/0 회귀 없음.
- Divergences:
  - **테스트를 "케이스 추가"가 아니라 전체 재작성해야 했다.** wrapper의 경로 해석을 `$CLAUDE_CONFIG_DIR` → `BASH_SOURCE`로 바꾸자 테스트의 동반 파일 위치 모델(fake `$CLAUDE_CONFIG_DIR` home → wrapper와 같은 디렉터리)이 통째로 바뀌어, 기존 3 케이스도 "설치 모델(세 파일 한 디렉터리)에서 env 없이 실행"으로 재구성해야 했다. plan은 "케이스 추가"로만 적었음.
  - **plan이 라이브 `~/.claude/` 교정 슬라이스를 또 빠뜨렸다.** 직전 retro(fg-statusline-rebuild)의 교훈을 살려 라이브 wrapper를 수동 cp로 동기화했지만, plan 자체에는 그 슬라이스가 없었다.
  - 무관한 `.omx/` 디렉터리가 워킹 트리에 나타남 — 내 작업과 무관, 커밋 제외.

## Learnings
- Do differently next time:
  - **경로/위치 해석 방식을 바꾸는 수정은 "테스트 한 케이스 추가"로 끝나지 않는다.** 해석 기준(env var → 스크립트 위치)이 바뀌면 테스트 픽스처가 재현하는 "환경 모델"이 통째로 바뀐다 — plan 단계에서 "테스트 재구성"으로 잡아야 슬라이스 추정이 맞다.
  - **statusline/설치형 스크립트 plan은 fg-ask 단계에서 "라이브 `~/.claude/` 교정" 슬라이스를 반드시 명시할 것.** 이번이 두 번째 누락(fg-statusline-rebuild → 이 작업)이다. "설치 시 복사" 모델인 스킬은 코드 수정이 라이브에 자동 반영되지 않으므로, DoD에 라이브 동기화를 못 박지 않으면 매번 빠진다. 반복되는 패턴 — 다음 statusline 관련 fg-ask는 이 슬라이스를 기본 포함.
  - **자기가 작성한 산출물의 내부 일관성(입력 계약 vs 기록 계약)은 스스로 놓치기 쉽다.** Codex 외부 적대적 리뷰가 fg-adversarial-review SKILL.md의 "parked 입력 허용 vs 활성 슬롯 기록" 불일치를 잡았다 — 새 스킬/계약 도입 직후엔 외부 적대 시선(fg-adversarial-review 자신 또는 codex)을 한 번 태우는 게 값어치 있다.

## Doc updates
- CONTEXT.md promotion: none (새 도메인 용어 없음)
- ADR added: none — ADR-0018(활성 슬롯 전용 범위)·ADR-0017(wrapper BASH_SOURCE 경로 해석)이 작업 중 개정됨. 새 ADR 불필요.
