# 2026-06-11 — 루프 핸드오프의 전환 질문 제거 (fg-run 3지 메뉴, 나머지 진술형)

## Plan vs actual
- What went as planned: 5슬라이스(S1 fg-run 3지 메뉴 / S2 fg-ask 진술+실행모드질문 제거 / S3 fg-learn·fg-done·fg-status 진술 / S4 CLAUDE.md 규약 / S5 README 양쪽) 전부 완료. 합의대로 Dynamic Workflow 없이 직접 처리, 완료 기준 전부 정적 grep으로 통과. 게이트(UAT·승급확인·fg-map제안) 보존 확인.
- Divergences: 거의 없음. 미세 — fg-done의 전환 질문이 두 곳(Behavior §4 + Wrap-up)에 있어 둘 다 고침(계획은 Wrap-day만 명시했으나 같은 클래스라 완결).

## Learnings
- Do differently next time:
  - **스킬이 자기 규약과 조용히 드리프트한다.** 이번 변경의 본질은 "새 설계 도입"이 아니라 **CLAUDE.md의 핸드오프 규약('전한다')과 스킬 본문('ask whether to continue + invoke')의 어긋남을 바로잡은 것**이었다. 2차 감사(2026-06-11)도 같은 종류(stale fg-merge 블록, gitignore 단정 등)를 여럿 잡았다. → 규약/ADR과 스킬 본문의 정합을 주기적으로(예: 배포 전, 또는 감사 워크플로우로) 점검할 가치. 단일 정의가 본문과 갈라지는 게 이 리포의 반복 실패 모드다.
  - **"질문을 줄여달라"의 실체는 "전환 허락 질문"이었다** — 그릴링 질문(기둥 1)이나 콘텐츠 게이트(UAT·승급)가 아니라. 피드백을 받으면 "어떤 질문인지" 종류를 먼저 가르는 게 핵심이었다(fg-quick 검토가 이 분류를 미리 해둔 게 그릴링을 빠르게 했다).

## Doc updates
- CONTEXT.md 승급: 없음 — 새 도메인 용어 없음.
- ADR 추가: 없음(이번 회고에서) — 핵심 결정은 그릴링 때 ADR-0015(`.forge/adr/0015-fg-run-handoff-menu-others-stated.md`)로 이미 기록됨.
