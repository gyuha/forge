# forge는 Claude Code 전용 — Codex/크로스플랫폼 포팅 보류

Status: Superseded by ADR-260903-080713 (재검토 바 충족 — 실제 Codex 사용 수요 발생, (a) 전면 도구 추상화 채택)

## Status
superseded by ADR-260903-080713 (원문 당시: accepted (deferred — 재검토 바는 아래))

## 맥락
"forge를 Codex(또는 Gemini/Copilot 등 다른 에이전트)에서도 쓸 수 있나?"라는 질문이 나왔다. 제기자의 전제는 "Claude Code의 ultracode/Dynamic Workflow가 Codex엔 없어서 못 쓰지 않나"였다. 코드베이스 결합도를 조사하니 **그 전제는 빗나갔고** 진짜 결합점은 다른 곳에 있다:

- **Dynamic Workflow는 하드 의존이 아니다.** fg-run에 "스케일이 작으면 워크플로 대신 직접 실행"이라는 fallback이 명시돼 있고(`skills/fg-run/SKILL.md` Constraints), forge 자체 작업 대부분이 직접 실행이다. Workflow가 없는 환경에선 대규모 병렬 팬아웃이 직렬/직접 실행으로 **degrade될 뿐, 루프가 깨지지 않는다.**
- **진짜 결합은 패키징 + 도구 계층(Claude Code 전용)이다.**
  1. forge는 **Claude Code 플러그인**이다 — `.claude-plugin/`(plugin.json·marketplace), `/plugin install`, `skills/*/SKILL.md` 자동 탐색, `/forge:fg-*` 슬래시 커맨드.
  2. 스킬 다수가 `CLAUDE_PLUGIN_ROOT`로 교차참조 경로를 푼다(`${CLAUDE_PLUGIN_ROOT}/skills/...`).
  3. Claude Code **네이티브 도구를 직접 명명**한다 — `AskUserQuestion`(메뉴 UI), Skill 도구 체이닝(fg-next), `Agent`/`Workflow`/`run_in_background`(fg-run·fg-map·fg-adversarial-review).
  Codex는 자체 스킬 메커니즘·다른 도구셋이라 이 층을 그대로 읽지 못한다.
- **이식 가능한 층**: `.forge/` 상태 계약(backlog → plan/run/STATUS → executed/ → done/ + 영속 문서)·루프 방법론·`scripts/*`(bash+node 트윈)는 플랫폼 독립적이다. 즉 **개념·상태는 이식 가능하나 패키징·도구 결합은 아니다.**
- superpowers는 "도구를 행동으로 추상화"해 멀티 플랫폼(Codex/Gemini/Copilot)을 지원하지만, forge는 **의도적으로** Claude Code 도구를 직접 쓴다. 현재 codex/크로스플랫폼 인지가 코드·문서·ADR 어디에도 없다.

## 결정
forge는 **Claude Code 네이티브 플러그인으로 유지**한다. Codex/크로스플랫폼 포팅은 **지금 하지 않는다.** Claude Code 고유 기능(Dynamic Workflow·Skill 체이닝·AskUserQuestion·플러그인 마켓플레이스)을 최소공통분모로 추상화하지 않고 그대로 깊게 활용한다.

## 결정 근거
- **트레이드오프가 비대칭.** 포팅의 이득(타 에이전트 사용자 도달)은 가설적·미검증인데, 비용(도구 계층 전면 추상화 = superpowers식 재작성, 전 스킬의 `CLAUDE_PLUGIN_ROOT`·도구 참조 치환, 두 플랫폼 동시 유지보수)은 확정적이고 크다.
- **정체성.** forge의 가치는 Claude Code의 강력한 기능(병렬 워크플로·대화형 그릴링·파일 상태 계약)을 *깊게* 쓰는 데서 나온다. 도구를 최소공통분모로 추상화하면 그 깊이가 희석된다(ADR-0024의 "harness를 흡수하면 forge 정체성이 흐려진다"는 우려와 동형).
- **YAGNI.** 실사용자의 크로스플랫폼 수요가 아직 없다 — 투기적 일반화는 forge가 일관되게 거부해 온 패턴(ADR-0013과 동형).

## 재검토 바 (충족되면 그때)
투기적 일반론이 아니라 **구체적·재현된 수요**가 생기면 재고한다:
- 실사용자가 Codex/Gemini/Copilot에서 forge 루프를 반복적으로 요구하는 사례가 나타날 때. 그때 두 길을 그릴한다:
  - **(a) 전면 도구 추상화** — superpowers식으로 도구를 행동으로 추상화하고 플랫폼별 어댑터를 둔다(깊이 일부 희생, 도달 확대).
  - **(b) 방법론-only 차선** — 플러그인 없이 `.forge/` 상태 계약 + 루프 규율만 다른 에이전트에서 수동으로 따른다(자동 트리거 없음, 포팅 비용 0, 가장 가벼움).

## 고려한 대안
- **지금 전면 포팅** — 거부: 도구 계층 전면 치환 + 이중 유지보수. 확정 비용 대비 가설적 이득.
- **방법론-only 수동 사용을 지금 문서화** — 보류: 수요가 없어 불필요. 재검토 바 충족 시 (b)로 검토.
- **(채택) Claude Code 전용 유지 + 재검토 바 명문화** — 미래에 누군가 "forge는 왜 크로스플랫폼이 아닌가 / Codex 지원은?"이라고 물을 때, 이 ADR이 근거와 재고 조건을 제시해 재논의를 막는다.

## Consequences
- forge는 Claude Code 외 환경에서 **그대로는 동작하지 않는다**(플러그인·도구 결합). 이는 버그가 아니라 의도된 범위다.
- 새 스킬·기능은 Claude Code 도구를 자유롭게 직접 써도 된다 — 크로스플랫폼 추상화 부담을 지지 않는다.
- Dynamic Workflow가 없는 환경을 가정한 분기 코드는 두지 않는다(YAGNI). 단 fg-run의 기존 직접실행 fallback은 그대로 유지된다 — 그것은 **스케일** 기반 결정이지 플랫폼 호환을 위한 것이 아니다.
