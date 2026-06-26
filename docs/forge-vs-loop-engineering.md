# forge와 Loop Engineering

> Addy Osmani의 [Loop Engineering](https://addyosmani.com/blog/loop-engineering/)(2026)을 forge에 적용할지 검토한 결과 문서. 검토일 2026-06-11(forge v0.4.4) · 현황 갱신 2026-06-25(Loop Library 2차 감사 — fg-loop tension·safety 벽 추가).
>
> **결론: forge는 loop engineering의 구현체다.** 글이 정의하는 6개 프리미티브 중 5개와 경고 전부를 forge가 자기 어휘로 이미 제도화하고 있으며, 유일한 갭(Automations)은 이 리포에서 효용이 낮아 도입하지 않기로 했다(아래 "도입하지 않은 것" 참조).

## 핵심 테제 대응

Osmani의 테제는 "에이전트에 프롬프트를 치는 사람을 시스템으로 대체하라 — 프롬프트 엔지니어가 아니라 루프 설계자가 되라"이다. forge의 답: **루프는 자동화하되, 환원 불가능한 판단(그릴링·회고·검증 확인)은 사람에게 남긴다.** 이것이 forge의 두 기둥이고, Osmani가 경고하는 cognitive surrender를 구조적으로 막는 장치다.

## 프리미티브 대응표

| Loop Engineering 개념 | forge의 구현 | 근거 문서 |
| --- | --- | --- |
| **Skills** — SKILL.md로 관례·의도 인코딩, intent debt 방지 | forge 자체가 18개 `fg-*` 스킬(루프 4단계 + 루프 밖 유틸리티 14개). 용어는 `CONTEXT.md`, 결정은 ADR, 코드 맥락은 `.forge/codebase/` 지도 — "문서는 산출물이 아니라 루프의 연료"(기둥 2)가 곧 intent-debt 방지 | README 두 기둥, ADR-0001 |
| **State/Memory** — 컨텍스트 밖 디스크 영속 상태 | `.forge/` 상태 계약 전체: backlog → 활성 슬롯(plan/run/STATUS) → executed/ → done/. "memory has to be on disk"를 문자 그대로 구현 — 모든 스킬이 독립 호출돼도 파일로 흐름이 이어진다 | README 공유 상태, FORGE-ROOT.md |
| **Worktrees** — 병렬 에이전트 격리 | 브랜치별 forge 루트(`.forge/branch/<branch>/`)가 같은 충돌 문제를 상태 수준에서 해결. git worktree는 병용 가능하며, "worktree만으로 충분"은 검토 후 기각됨(추적 문서 충돌을 못 풀어서) | ADR-0011 |
| **Sub-agents** — maker/checker 분리, 자기 채점 방지 | fg-run의 Dynamic Workflow(병렬 실행) + 전용 적대 리뷰 스킬 **fg-adversarial-review**(결과가 틀렸다고 가정하고 6개 렌즈를 병렬 서브에이전트로 팬아웃) + fg-map의 매퍼 4개 팬아웃. 별도 3종(explorer/retro-analyzer/verifier)은 구체적 통증 없음으로 **의도적 보류** — 재검토 바 명문화 | ADR-0007, ADR-0013, ADR-0018 |
| **`/goal`·`/loop`** — 검증 가능한 정지 조건까지 무인 재개 | 전용 goal 루프 스킬 **fg-loop** — 기계 검증 가능한 정지 조건을 `.forge/loop.md`에 못 박고 한정 fix-forward 재계획으로 수렴까지 무인 주행. `fg-next all`(백로그 완주, 대화의 벽에서 halt)은 그릴링 완료된 대기열용 동반 차선 | ADR-0016, ADR-0010 |
| **Automations** — 스케줄 발굴·트리아지 → 인박스 | **없음 (유일한 갭).** forge의 모든 루프는 사람이 시작한다 | — (아래 참조) |
| **Plugins/Connectors** — MCP로 외부 도구 연동 | **없음 (의도적).** 파일 기반 자기완결이 설계 원칙 — 외부 트래커 의존은 이식성을 깬다 | 스킬 편집 규약(하드 의존 금지) |

## 경고의 제도화 — forge가 가장 강한 지점

Osmani가 후반부에 쏟는 경고들은 forge에서 권고가 아니라 **게이트**다:

| 경고 | forge의 제도화 |
| --- | --- |
| Token cost volatility | `fg-eco` — 켜면 위임 서브에이전트를 sonnet으로 캡 + Eco laziness-first 규율(`ECO.md`)로 코드·계획 복잡도까지 절감(ADR-0014 개정). 비용 추정 우선 원칙(fg-run Constraints) |
| "A loop running unattended is a loop making mistakes unattended" | **no-seal-without-verification** — 검증 결정이 기록되지 않으면 봉인 불가(ADR-0009). `failed`는 어떤 waiver로도 봉인 못 함 |
| Comprehension debt | 회고가 기본값(ADR-0002) — 건너뛰기는 저-divergence에서만, 감사 가능하게(`retro: skipped (사유)`). 학습은 영속 문서로 승급 |
| Cognitive surrender | 기둥 1 — 그릴링·회고는 워크플로우 밖 대화. `fg-next all`조차 실패한 UAT·진짜 fork·고비용 판단에서는 멈춰 사람에게 돌려준다 |
| Orchestration tax | 활성 슬롯 항상 1개(한 plan = 한 run = 한 봉인) — 사람 리뷰 대역폭에 루프 폭을 맞춘 설계 |

## fg-loop 2차 경화 — Loop Library 감사 (2026-06-25)

Osmani 글에 더해, Forward Future의 [Loop Library](https://signals.forwardfuture.ai/loop-library/)(69개 루프 레시피)의 **공통 가드레일 DNA**에 대고 fg-loop를 다시 감사했다. DNA의 대부분 — 기계 검증 정지 조건 · "AI가 됐다고 생각함"은 정지 아님 · no-progress 2라운드 · Reflexion · evidence ledger · stateless 재개 · 독립 기계 checker — 은 이미 보유했고, 진짜 빈틈 둘만 차용했다(ADR-0016 7차 개정):

- **tension 벽** — fix-forward가 이미 통과한 다른 정지 체크를 깨뜨리는 oscillation을 원장의 pass→fail 회귀(`regressed: ×N`)로 **기계 감지**해, cap 소진 전에 충돌 쌍을 보고하며 조기 정지(lenient + 1회 재시도). 기존 no-progress 벽(`×N`)이 핑퐁을 놓치던 사각지대를 메운다 — Loop Library #034가 oscillation을 1급 정지 사유로 명시.
- **safety 벽** — 승인 범위 *안*이라도 비가역/파괴적/외부 액션 클래스(기본 7종)면 fix-forward **생성 시점**에 정지. Loop Library 전반의 approval-gate DNA를 계약 수준에 명시(하니스 권한 게이트가 넓은 권한에서 놓치는 in-scope-destructive 갭). best-effort 자기분류라는 한계는 ADR에 솔직히 기록.

budget(replan-cap과 별개의 토큰/시간) 분리·체크 상태 다변화(proved/weak/contradicted)는 YAGNI로 기각. 두 벽은 *생성된* fix-forward에서만 발생해 **fg-loop 전용**(fg-next all 비적용).

## 도입하지 않은 것과 그 이유

- **Automations (스케줄 트리아지).** 두 가지 이유로 보류. ① 기둥 1 제약 — 자동화는 그릴링(대화)을 할 수 없으므로, 산출물은 plan이 아니라 "fg-ask 후보 인박스"까지만 가능하다. ② 이 리포는 CI·테스트가 없는 Markdown 플러그인이라 스케줄 발굴이 주기적으로 찾아낼 거리가 거의 없다. **이 갭이 가치를 갖는 곳은 forge를 사용하는 큰 코드베이스다** — 그쪽 프로젝트에서 필요해지면 "스케줄 트리아지 → `.forge/` 인박스 적재 → 사람이 fg-ask로 그릴링" 패턴으로 그때 그릴링한다.
- **Connectors (MCP 연동).** forge의 상태는 의도적으로 파일 기반 자기완결이다. 이슈트래커 연동은 특정 외부 도구에의 하드 의존을 만들어 이식성(어느 리포에든 설치)을 깬다.
- **전용 서브에이전트 3종(explorer/retro-analyzer/verifier).** ADR-0013의 재검토 바(구체적·재현된 통증) 미충족으로 여전히 보류. 이 글의 일반론은 그 바를 넘는 새 증거가 아니다. (적대적 리뷰 수요는 이 3종과 별개로 `fg-adversarial-review`가 채웠다 — ADR-0018.)
