---
name: fg-ask
description: Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decisions crystallise. Use when user wants to stress-test a plan against their project's language and documented decisions. forge 루프의 진입점이자 계획 그릴링 단계 — '새 작업 시작', 'forge로 시작', '이거 작업하자', '계획 다듬자', '이 계획 그릴링해줘' 같은 맥락에서 사용. 합의된 계획을 .forge/plan.md에 정리해 fg-execute로 넘긴다. 반드시 본 세션 대화로 진행한다(워크플로우 밖).
---

# fg-ask

> 이 스킬은 [grill-with-docs](https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs)를 **원문 그대로** 이식한 것이다. 아래 `<what-to-do>` / `<supporting-info>`가 grill-with-docs 원문이며, forge 루프 연결은 맨 아래 "forge 연결"에만 둔다.

<what-to-do>

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing.

If a question can be answered by exploring the codebase, explore the codebase instead.

</what-to-do>

<supporting-info>

## Domain awareness

During codebase exploration, also look for existing documentation:

### File structure

Most repos have a single context:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `CONTEXT-MAP.md` exists at the root, the repo has multiple contexts. The map points to where each one lives:

```
/
├── CONTEXT-MAP.md
├── docs/
│   └── adr/                          ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   └── docs/adr/                 ← context-specific decisions
│   └── billing/
│       ├── CONTEXT.md
│       └── docs/adr/
```

Create files lazily — only when you have something to write. If no `CONTEXT.md` exists, create one when the first term is resolved. If no `docs/adr/` exists, create it when the first ADR is needed.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up — capture them as they happen. Use the format in [CONTEXT-FORMAT.md](../../references/CONTEXT-FORMAT.md).

`CONTEXT.md` should be totally devoid of implementation details. Do not treat `CONTEXT.md` as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [ADR-FORMAT.md](../../references/ADR-FORMAT.md).

</supporting-info>

---

## forge 연결 (최소)

원문은 위에서 끝난다. 아래는 forge 루프가 끊기지 않게 하는 최소한의 연결이며, 그릴링 방식 자체는 위 원문을 따른다.

- **참조 형식 문서.** 원문 본문은 그대로 두되, 형식 문서 링크 경로만 forge 공통 위치로 맞췄다(유일한 적응) — `../../references/CONTEXT-FORMAT.md`, `../../references/ADR-FORMAT.md`(또는 `${CLAUDE_PLUGIN_ROOT}/references/...`). 스킬마다 복사하지 않고 이 1벌을 공유한다.
- **산출물.** 그릴링이 공유된 이해에 도달하면, 합의된 계획을 `.forge/plan.md`에 정리해 적는다. 이 파일이 다음 단계 `fg-execute`의 정답 기준(입력)이 된다.
- **핸드오프.** 계획을 `.forge/plan.md`에 정리한 뒤, 다음은 `fg-execute`로 실행한다고 자연스럽게 안내한다. Dynamic Workflow로 돌릴 만큼 큰 작업인지, 아니면 바로 처리할 만큼 작은지 물어 실행 방식을 정한다.
- **휘발 상태.** `.forge/`는 gitignore된 작업 상태라 추적·커밋하지 않는다.
