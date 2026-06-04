---
last_mapped_commit: 21c8bdbf3b13543c1aec209669ec38b57f8f25e2
mapped: 2026-06-04
---

# Concerns — 알려진 취약점과 위험 영역

이 문서는 forge 코드베이스의 의도적 반복 작업, 수동 동기화 지점, 발산 위험을 기록한다. 기술부채가 아니라 **설계의 비용**이다 — 각각은 기둥이나 계약을 지키기 위한 필수 불가피한 복잡성이며, 의도적으로 취한 트레이드오프다.

## 1. fg-ask의 verbatim 분할 (grill-with-docs ↔ Forge 통합)

**위치:** `skills/fg-ask/SKILL.md`

**상황:**
- `skills/fg-ask/SKILL.md`는 **grill-with-docs 원문(Matt Pocock)을 영문 그대로 이식**한 것이다. 본문 1~87줄의 `<what-to-do>`, `<supporting-info>` 섹션이 그것이다.
- 88줄부터의 "## Forge integration (minimal)" 섹션은 이 원문을 **forge 루프에 연결하는 최소한의 글루 코드**다 — backlog 산출, retro 피드백, codebase 지도 읽기, 핸드오프 메커니즘이 여기에만 있다.

**발산 위험:**
이 두 부분은 **독립적으로 수정되면 계약이 깨진다**:
- verbatim 본문을 수정하면 Forge integration 섹션의 참조가 어긋날 수 있다 (예: 형식 문서 경로 참조 `[CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md)` 등).
- Forge integration을 수정하면 원문의 철학이나 방법론과 불일치할 수 있다 (예: 그릴링 절차와 산출물 계약이 안 맞음).
- **진짜 위험:** 향후 grill-with-docs 원문이 업스트림에서 업데이트되면, 경로는 `.forge/` 계약으로 정합하되 본문은 원문 유지 — 이때 정합 누락이 쉽다.

**현 상태:**
- CLAUDE.md 118줄에 이 분할을 명시했다: "verbatim 본문과 Forge integration 섹션은 따로 움직이므로, 둘 중 하나만 고치면 계약이 깨진다."
- 2026-06-04 세션에서 "fg-ask ADR·CONTEXT 경로 정합" 회고(`2026-06-04-fg-ask-adr-path-fix.md`)가 정확히 이 위험을 기록했다: "외부 텍스트를 verbatim 이식할 때 경로/이름은 호스트 계약에 맞춰 정합해야 한다."

**예방책:**
- 수정 전에 분할 경계를 명확히 한다 (88줄 "## Forge integration (minimal)").
- Forge integration 세션 후 `grep -rn docs/adr / grep -rn "루트 CONTEXT"` 등으로 옛 경로 잔존 확인.
- 향후 upstream 동기화 시, 경로 정합이 되돌려지지 않도록 diff 검증.

---

## 2. forge-prd.md는 옛 설계 초안 (권위 없음)

**위치:** `forge-prd.md`

**상황:**
- `forge-prd.md`는 2026-06-03 작성된 **프로젝트 초안(draft)**이다.
- 본문 11줄: "스킬 5개로 쪼갠다."
- 본문 25줄 다이어그램: `fg-ask → fg-run → fg-learn → fg-complete` (4단계만, 새 스킬 없음).
- 마지막 단계 이름이 현재의 `fg-cleanup`이 아닌 옛 이름 **`fg-complete`**다.

**실제 현황 (2026-06-04):**
- 현재는 **7개 스킬**: `fg-ask`, `fg-run`, `fg-learn`, `fg-cleanup` (루프 4개) + `fg-map`, `fg-quick`, `fg-status` (루프 밖 3개).
- CHANGELOG 0.1.1: `fg-complete` → `fg-cleanup` 개명.
- CHANGELOG 0.2.1: `fg-quick` 추가 (경량 차선).
- CHANGELOG 0.2.2: `fg-status` 추가 (읽기 전용 리포터).

**발산 위험:**
- **신규자가 forge-prd.md를 읽으면 잘못된 정보를 얻는다** — 5개 vs 7개 스킬, `fg-complete` vs `fg-cleanup` 이름.
- CLAUDE.md 118줄에서도 경고한다: "명세로 신뢰하지 말 것 — 실제는 `skills/`와 `README.md`가 기준."
- PRD가 권위를 잃으면 변경 의도를 기록하는 도구로서의 역할을 못 한다.

**현 상태:**
- PRD는 더 이상 갱신되지 않았다. 동기화 책임은 없다고 봐서인지, 정책인지 불명.

**예방책:**
- 신규 스킬 추가 시 forge-prd.md를 갱신하거나, PRD 자체가 "참고용 옛 초안이며 실제 기준은 skills/ + README"임을 헤더에 명시.
- 혹은 PRD를 폐기하고 README의 스킬 카탈로그를 유일한 명세로.

---

## 3. README.md ↔ README.ko.md 수동 동기화

**위치:** `README.md` (영문) ↔ `README.ko.md` (한글)

**상황:**
- CLAUDE.md 87줄: "README.md(영문)와 README.ko.md(한글)는 같은 내용의 번역 쌍이다. README.md를 갱신하면 반드시 README.ko.md도 같은 변경으로 함께 갱신한다."

**수동 동기화 지점:**
1. 스킬 카탈로그 (10~21줄) — 스킬 추가/설명 변경 시.
2. 전체 흐름 섹션 (24~55줄) — 다이어그램·설명 변경 시.
3. Install 섹션 (57~79줄) — 설치 절차 변경 시.
4. Shared state 섹션 (81~117줄) — `.forge/` 구조·상태 계약 변경 시.
5. The two pillars (119~123줄) — 설계 원칙 변경 시.

**발산 위험:**
- 2026-06-04 세션에서만 여러 이슈가 고쳐졌다:
  - 스킬 개수 update (5→7), `fg-complete`→`fg-cleanup` rename.
  - retro skip ADR 추가.
  - 상태 계약 명확화.
- **이번에 README.md만 갱신되고 README.ko.md는 빠졌을 수 있다** (이 문서 작성 시점에는 양쪽 동일해 보이나, 향후 변경이 한쪽만 되기 쉽다).

**예방책:**
- README 변경 시 **둘 다 touch**하는 절차를 배포 규칙에 명시.
- CI/자동화로 번역 쌍의 구조(섹션·목차) 일치 여부 확인 (불가능하면, 수정 커밋에 "README 이중 동기화" 체크리스트 강제).

---

## 4. 3곳 버전 동기화 (plugin.json, marketplace.json ×2)

**위치:** `plugin.json` 버전 · `marketplace.json`의 `metadata.version` + `plugins[0].version`

**상황 (CLAUDE.md 배포 규칙, 101~107줄):**

```
plugin.json:           version: X.Y.Z
marketplace.json:  metadata.version: X.Y.Z
marketplace.json:  plugins[0].version: X.Y.Z
```

세 곳을 항상 **동일하게 유지**해야 한다.

**현 상태:**
- 현재 모두 0.2.4로 일치.
- CHANGELOG가 명확하므로, 배포 절차를 따르면 동기화는 보통 잘 된다.

**발산 위험:**
- 배포 절차를 부분 수행(예: plugin.json만 범프하고 marketplace 빠뜨림)하면 설치 시 버전 불일치로 혼란.
- 수동 편집으로 각각 다른 값을 넣으면 마켓플레이스 메타데이터가 실제와 다를 수 있다.

**예방책:**
- 배포 규칙 102줄처럼 **"3곳을 반드시 동시 갱신"**을 명시하되, 이를 강제하는 pre-commit 훅이 있으면 좋다 (현재 없음).
- 배포 스크립트화 (bash/node 자동화).

---

## 5. Manifest description의 역할 혼동 위험

**위치:** `plugin.json` description · `marketplace.json` `metadata.description` · `marketplace.json` `plugins[0].description`

**상황 (CLAUDE.md 배포 규칙, 111줄):**

```
metadata.description  = 루프(ask→execute→retro→cleanup)를 정의하는 한 줄 태그라인
                        → 루프 밖 유틸리티(fg-map류)는 넣지 않는다
plugins[].description = 전체 스킬 목록을 담는 설명
                        → 루프 밖 스킬도 반영한다
```

**역사:**
- CHANGELOG 0.1.2: fg-map 추가 시, **두 description을 다르게 다뤘다**는 학습이 회고에 남았다.
  - 2026-06-04-fg-map-skill.md retro: "매니페스트의 두 description을 다르게 다뤘다. metadata.description은 루프 태그라인이라 fg-map(루프 밖)을 넣지 않았고, plugins[0].description에만 '4→5 skills'로 반영."
  - CLAUDE.md 배포 규칙에 "매니페스트 description 역할 구분을 의식하고 작업한다"는 학습을 기록.

**발산 위험:**
- 신규 루프 밖 스킬(fg-quick, fg-status 등)을 추가할 때, metadata.description에 끼우면 **루프 정의가 흐려진다**.
- fg-map 추가 시처럼, 이번에도 두 description을 다르게 다뤘는지 검증 없음.

**현 상태:**
- plugin.json description: 7개 전부 나열 (루프 4개 + 밖 3개) — `fg-map · fg-quick · fg-status` 모두 포함.
- marketplace.json metadata.description: "ask·plan → execute → retro → cleanup loop" 루프만 (루프 밖 없음) ✓
- marketplace.json plugins[0].description: 7개 전부 나열 (루프 4개 + 밖 3개) ✓

**예방책:**
- 배포 규칙에 **"루프 밖 스킬을 metadata.description에 넣지 말 것"**을 다시 강조.
- 또는 git hook으로 metadata.description에 "fg-map" / "fg-quick" / "fg-status" 문자열 검출 시 경고.

---

## 6. 회고 skip 침식 위험

**위치:** `.forge/done/*/STATUS.md`의 `retro:` 필드

**상황:**
이 세션(2026-06-04) 모든 완료 작업이 `retro: skipped`로 기록되었다:
- optional-retro-skip (ADR 도입)
- fg-status-stage-badge
- add-fg-quick (신규 스킬)
- fg-status-table-format
- add-fg-status (신규 스킬)
- rename-fg-execute-to-fg-run
- (더 많음)

**CLAUDE.md의 기둥 2:**
"문서는 루프의 연료다. 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다."

**발산 위험:**
- **회고 skip이 관례가 되면, 문서가 연료로서의 역할을 잃는다.**
- 지금까지 정당화:
  - ADR-0002 (optional-retro-skip): "저-divergence 사소한 작업에 한해" skip을 명시했다.
  - 각 skip STATUS에 "사유"를 기록했다 (학습 불요 / divergence 없음 등).
- 그러나 "사소함"의 정의가 점점 완화될 수 있다:
  - 신규 스킬 추가(fg-map, fg-quick, fg-status)도 skip 대상이 된 것은, 원래 예상(오타·경로·버전 범프)보다 광범위.
  - "핵심 결정은 ADR에 기록됐으니 별도 회고는 불요"라는 논리도, 회고와 ADR의 역할 혼동 신호.

**예방책:**
- ADR-0002를 정기적으로 읽어, skip의 원래 의도(저-divergence, 학습 없음)를 재확인.
- fg-run의 "skip 제시 게이트" (divergence 크면 skip 미제시)가 제대로 작동하는지 검증.
- 회고 파일이 실제로 문서 승급의 연료가 되고 있는지 샘플링.

---

## 7. 형식 문서의 경로 참조 분산

**위치:** 형식 문서들 (`CONTEXT-FORMAT.md`, `ADR-FORMAT.md`, `PLAN-FORMAT.md`, `RETRO-FORMAT.md`)

**상황:**
- 형식 정의는 **소유 스킬의 디렉터리**에 둔다 (CLAUDE.md 74줄).
- `skills/fg-ask/` 내: `CONTEXT-FORMAT.md`, `ADR-FORMAT.md` (grill-with-docs 원본).
- `skills/fg-run/` 내: `PLAN-FORMAT.md` (fg-run의 소비자이지만, fg-ask가 생산하므로 역할 명확성을 위해 소비자 쪽에 둠).
- `skills/fg-learn/` 내: `RETRO-FORMAT.md`.
- 다른 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<소유 스킬>/<파일>`로 **상대경로 참조** (복사 없음).

**현 상태:**
- 경로 참조가 대부분 맞으나, 명확한 문서화가 없다.

**발산 위험:**
- 형식 문서 이동 시 참조 경로 누락 가능.
- 새 스킬 추가 시 "형식 문서는 누가 소유하는가"를 모를 수 있다.

**예방책:**
- CLAUDE.md 74줄의 규약을 더 명확히: "형식 정의 경로" 섹션 신설, 각 스킬별 소유/참조 관계 테이블.

---

## 8. .forge/ codebase 문서의 신선도 확인

**위치:** `.forge/codebase/*.md`

**상황:**
- fg-map이 7개 codebase 문서를 생성한다 (STACK, INTEGRATIONS, ARCHITECTURE, STRUCTURE, CONVENTIONS, TESTING, CONCERNS).
- 각 문서는 `last_mapped_commit` frontmatter를 갖는다.
- fg-ask가 그릴링 전 이 지도를 읽는데, SKILL.md 96줄에서 "지도가 stale하면 경고하되 계속 진행"한다.

**현 상태:**
- 현재 codebase 지도는 0.2.4 배포 직후 단 1개 문서(STACK.md)만 있다 (불완전).
- 실제 fg-map 실행으로 7개 모두 생성되었는지 검증 안 됨 (배포 후 테스트 대기).

**발산 위험:**
- codebase 지도가 실제로 7개 다 생성되지 않으면, fg-ask의 "지도 읽기" 기능이 부분적으로만 작동.
- stale 경고 로직이 제대로 트리거되는지 미검증.

**예방책:**
- 배포 후 `/forge:fg-map` 실행 → codebase/ 7개 문서 생성 여부 검증.
- fg-ask의 `last_mapped_commit` 신선도 판단 로직 실제 테스트.
- CONCERNS.md 이 파일이 제때 갱신되는지 모니터.

---

## 9. 루프 밖 스킬의 상태 격리 검증 부족

**위치:** `fg-quick`, `fg-status`, `fg-map`

**상황 (CLAUDE.md 44줄, ADR-0003):**
- fg-quick은 메인 루프의 active slot / backlog / done을 **일절 건드리지 않는다**.
- 대신 `.forge/quick/LOG.md`에 한 줄만 기록하고 자체 완결.
- fg-map은 `.forge/codebase/`만 생성, 루프 상태와 무관.
- fg-status는 읽기 전용, 아무것도 쓰지 않음.

**발산 위험:**
- fg-quick이 실제로 다른 상태를 건드리지 않는지 검증 없음.
- fg-map이 codebase 외 파일을 실수로 생성/수정하지 않는지 검증 없음.
- fg-status가 정말 읽기 전용인지 (숨은 부수효과 없는지) 검증 없음.

**예방책:**
- 각 루프 밖 스킬의 "격리" 계약을 SKILL.md에 명시적으로 선언.
- 테스트: 루프 밖 스킬 실행 전후 `.forge/plan.md`, `.forge/backlog/`, `.forge/done/` 무변화 확인.

---

## 10. 도메인 용어와 구현 세부의 경계 유지

**위치:** `.forge/CONTEXT.md`, 회고 문서, ADR

**상황 (CLAUDE.md 74줄, 권한 주석):**
- CONTEXT.md는 "**용어만, 구현 세부 금지**".
- ADR은 "되돌리기 어렵다 / 의외하다 / 트레이드오프"의 3조건 모두 충족할 때만.
- 회고는 "바를 못 넘는 학습의 종착지" — 영속 문서로 승급하는 기준이 모호.

**현 상태:**
- 2026-06-04 회고 몇 개가 "별도 회고 불요 (결정은 ADR에 이미 있음)"라고 기록했다 → 이건 회고와 ADR 역할의 혼동.
- ADR-0002, ADR-0003은 "결정 기록" 목적으로 잘 썼으나, fg-map 회고에서 "CLAUDE.md 배포 규칙에 한 줄 추가"로 승급했다 → 문서화 정책이 고정되지 않았다는 신호.

**발산 위험:**
- 회고에서 배운 것이 CONTEXT로 가야 하는지(용어) · ADR로 가야 하는지(결정) · 그냥 로그로 남아야 하는지(학습) 헷갈린다.
- 결과: "CLAUDE.md에도 쓰고, ADR에도 쓰고, 회고에도 남고" 중복/산재.

**예방책:**
- fg-ask의 "ADR 3조건 확인" 텍스트처럼, **"도메인용어 vs 결정 vs 학습" 구분 체크리스트**를 fg-learn에 추가.

---

## 참고: 의도적 설계, 비용이지 부채가 아님

위 10가지는 모두 **설계 의도**의 비용이다:

1. **Verbatim 분할** — grill-with-docs 원문 보존 vs 로컬 계약 정합 사이의 긴장.
2. **forge-prd 미갱신** — 초안이 권위를 잃은 것; 권위를 지우든 유지하든 비용.
3. **README 이중 동기화** — 다국어 지원의 비용.
4. **3곳 버전 동기화** — 마켓플레이스 메타와 실제 동기화의 비용.
5. **Manifest description 역할 분화** — 루프 정의 명확성 vs 전체 스킬 안내 사이의 설계.
6. **회고 skip 가능성** — 기둥 2(문서 연료) vs 사소한 작업의 효율성 트레이드오프 (ADR-0002).
7. **형식 문서 분산 위치** — 소유권 명확성 vs 한곳 집중의 트레이드오프.
8. **Codebase 지도 갱신** — on-demand 유틸리티의 신선도 유지 비용.
9. **루프 밖 스킬 격리** — 가벼운 차선의 독립성 유지 비용.
10. **용어/결정/학습 구분** — 문서화 규약의 정교함 비용.

각각은 forge의 **두 기둥**(대화형 그릴링·문서 연료)이나 **4단계 루프** 구조를 지키기 위해 **필수불가결**하다. 따라서 예방책은 "제거"가 아니라 **"의식화·검증·자동화"**다.
