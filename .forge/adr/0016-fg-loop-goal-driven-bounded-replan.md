# fg-loop — goal 주도 한정 재계획 루프 (기둥 1의 의도적·경계 있는 완화)

## 맥락

Addy Osmani의 Loop Engineering 검토(`docs/forge-vs-loop-engineering.md`)에서 forge의 유일한 미구현 패턴으로 "검증 가능한 정지 조건까지의 자가 수렴 루프"가 남았다. 기존 `fg-next all`(ADR-0010)은 **사람이 그릴링해 둔 백로그를 소진**할 뿐, 정지 조건이 미충족이어도 빈 백로그에서 멈춘다 — "새 작업 그릴링은 사람이 내용 공급"이 벽이기 때문이다(기둥 1). 사용자는 "기초 질의 후 AI가 조건 충족까지 스스로 반복"하는 차선을 원했다. 이를 무제한으로 허용하면(Ralph식) 그릴링 없는 계획 양산으로 기둥 1을 정면 위반하고, 자기 판단("만족되었다고 생각됨")을 정지 조건으로 쓰는 고전적 무인 루프 실패에 빠진다.

## 결정

**13번째 스킬 `fg-loop`를 신설하고, 기둥 1을 다음 세 경계 안에서만 완화한다** (fg-quick이 기둥 2를 trivial 한정으로 완화한 것과 동형의 선례 — ADR-0003):

1. **정지 조건은 기계 검증 가능해야 한다.** fg-loop의 기초 질의(대화, 워크플로우 밖)는 정지 조건을 grep 단언·테스트·JSON 체크 등 에이전트가 실행 가능한 형태로 못 박아 `.forge/loop.md`(goal 계약, 휘발)에 기록한다. "AI가 만족되었다고 생각함"은 정지 조건으로 인정하지 않는다.
2. **재계획은 사전 승인 범위 안에서만.** 기초 질의에서 사용자가 승인한 범위 — **정지 조건의 실패 체크에 직접 추적되는 fix-forward 작업** — 에 한해 AI가 그릴링 없이 새 plan을 생성할 수 있다. 생성된 plan도 PLAN-FORMAT·단조 작업 번호(ADR-0005)를 따르고 `<!-- generated-by: fg-loop -->` 마커를 단다(상태 계약 불변).
3. **반복 상한 + 무진전 조기 중단.** 전역 재계획 기본 3라운드(루프별 재정의 가능), 같은 체크가 2연속 무진전이면 상한 전이라도 중단. 상한 소진·검증 불가·진짜 설계 fork는 여전히 벽 — 멈춰 사람에게 돌려준다.

기존 게이트는 전부 불변: 검증 없는 봉인 금지(ADR-0009), 활성 슬롯 1개 계약, 회고는 자동 작성하지 않고 auto-skip만(ADR-0010 개정 패턴 — `retro: skipped`, 학습은 run.md 보존). `verified: failed`는 fg-next all에서는 벽이지만 fg-loop에서는 상한 내 자동 fix-forward 대상이다 — 이 벽 완화가 fg-loop의 존재 이유다. 턴 경계를 넘는 재개는 스킬이 발동할 수 없으므로(`/goal`은 하니스 기능) 페어링 운영 패턴으로만 문서화한다.

## 고려한 대안

- **빈 백로그에서 정지·갭 보고만**: 가장 안전하나 fg-next all + 조건 래퍼와 사실상 동일 — 신규 가치가 없어 기각.
- **무제한 재계획(Ralph식)**: 그릴링 없는 계획 양산으로 기둥 1 정면 위반, 품질 게이트 없는 무한 루프 위험. 그게 필요하면 하니스의 ralph-loop를 직접 쓰는 게 맞다 — 기각.
- **fg-next all의 인자 확장(`fg-next loop`)**: 스킬 추가 비용은 없지만, goal 계약·재계획 규칙이 all 모드와 본질적으로 다른 계약이라 한 파일에 두 계약이 섞인다. 사용자가 전용 진입점을 원했고, 루프 기계의 공유부는 참조(복붙 금지)로 해결 — 기각.

## 결과

- forge의 차선이 셋이 된다: 정식 루프(회고 대화 포함) / fg-next all(회고 skip, 백로그 소진) / **fg-loop(회고 skip + goal 수렴, 한정 재계획)**. fg-quick은 별도(trivial 전용).
- 기둥 1의 문장은 "그릴링·회고는 대화"에서 변하지 않는다 — fg-loop가 자동화하는 것은 *사전 승인된 범위 안의 fix-forward 계획*뿐이고, 범위 승인 자체가 기초 질의(대화)의 산출물이다.
- 무인 루프의 실패 모드(영원히 돌기 / 미검증 조기 종료)는 각각 상한·무진전 중단과 기계 검증 정지 조건이 막는다.

## 개정 (2026-06-12) — `## Tasks` 멤버십 목록 (무필터 백로그 주행 차단)

초판의 드라이브는 "promote the next backlog task"로 백로그 소속을 가리지 않았다. 루프가 벽에서 멈춘 사이 fg-ask가 적재한 **비소속 plan이 재개 시 자동 주행에 휩쓸리고 회고 자동 skip까지 따라붙는** 격차가 코드베이스 매핑(CONCERNS #4)에서 확인됐다.

**결정**: loop.md에 `## Tasks` 절(멤버십 목록)을 신설한다. 기초 질의가 적재한 plan과 이후 생성되는 fix-forward plan의 slug를 등재하고, 드라이브(최초·재개 모두)는 **목록의 slug만 승격**한다. 비소속 backlog plan은 건드리지 않고 한 줄 보고만. `<!-- generated-by: fg-loop -->` 마커는 파일 단위 출처 표기로 유지하며 fg-status가 `(loop)` 태그로 표시한다(주변 계약 동기: fg-ask 벽 경고·fg-merge in-flight halt·fg-next all 주행 양보·CLAUDE.md 상태 계약 표).

**기각 대안**: 마커 단독 필터(기초 질의 plan은 대화 산출물이라 "generated"가 의미상 거짓 + loop.md가 자기 작업 집합을 모름) · 재개 시 비소속 발견을 무조건 벽 처리(백로그에 뭔가 쌓일 때마다 루프 정지 — momentum 차선의 존재 이유 훼손).

## 개정 (2026-06-13) — 무인 자율 계약 (소프트 결정은 추천값 자동 선택, 벽에서만 정지)

초판·1차 개정은 "무인 주행 + 회고 auto-skip"을 의도했으나, 드라이브 도중 위임 스킬의 결정 지점(fg-run 핸드오프 메뉴·TDD 질문·slug 충돌·"회고/skip")마다 모델이 사용자에게 되묻고 멈추는 일이 잦았다. goal 주도 차선의 존재 이유(조건 충족까지 스스로 수렴)가 실사용에서 훼손된다.

**결정**: fg-loop에 **무인 자율 계약**을 명시한다. goal 계약이 못 박힌 뒤 드라이브는 *추천·기본값이 있는 모든 소프트 결정 지점*에서 추천/기본값을 자동 선택하고 조용히 진행하며, 사용자에게 선호를 묻지 않는다. 기초 질의(§1)는 정지 조건·재계획 범위·상한을 못 박는 데 필요한 최소만 묻고 나머지는 문서화된 기본값(TDD는 config, 기본 범위, 상한 3, 자동 분해)을 취한다. 이 차선이 보존하는 사람 판단은 *정지 조건을 앞에서 못 박는 것*이지 거기로 가는 매 단계를 승인받는 것이 아니다.

**경계는 불변**: 정지 가능한 지점은 네 개의 정합성 벽(§4 — 검증 불가 UAT·진짜 fork/범위 밖 수정·상한 소진·무진전 2연속)과 하니스가 물리적으로 요구하는 워크플로우 스크립트 승인뿐이다. 이들은 "추천이 있는 선호"가 아니라 혼자 진행하면 *틀리는* 진짜 블록이다(미검증 봉인은 ADR-0009 위반, 진짜 fork는 사람 몫). 따라서 "묻지 않는다"와 "벽에서 멈춘다"는 충돌하지 않는다 — 벽은 자동 선택할 추천이 없는 지점이다. ADR-0009·활성 슬롯 1개·회고 auto-skip 게이트는 전부 불변.

## 개정 (2026-06-15) — `/goal`을 "선택적 제안"에서 "운용 전제 + 정직한 fallback"으로 격상

2026-06-13 개정의 무인 자율 계약("턴 사이에서 멈추지 마라")에도 불구하고 실사용에서 드라이브가 **한 작업 하고 그냥 턴을 종료**하는 일이 재발했다. 근본 원인은 두 겹이다: (1) 스킬 본문 텍스트("Do not end the turn")는 모델이 턴을 yield하는 것을 *물리적으로 막지 못한다* — 특히 위임된 fg-run/fg-done이 ADR-0015대로 "다음 단계를 *진술하고 멈춘다*"로 핸드오프하는 순간, 그 근접 지시가 fg-loop의 먼 "멈추지 마라"를 이긴다. (2) 턴 경계를 넘어 연속을 강제하는 **유일한 실효 메커니즘은 `/goal` Stop hook**인데, 스킬은 `/goal`을 스스로 켤 수 없고(하니스 제약) §1이 이를 **"offer only"(선택적 제안)**로 제시해 사용자가 매번 까먹었다.

**결정**: `/goal` 페어링을 **무인 드라이브의 운용 전제**로 격상한다 — (a) §1 드라이브 진입 직전, 붙여넣을 `/goal` 줄을 "offer only" hedge 없이 *가장 눈에 띄는 마지막 단계*로 제시("무인 주행하려면 지금 붙여넣어라"); (b) `/goal` 미사용 시 동작을 **정직하게 약속**("한 사이클 후 멈춤은 정상 — `forge loop` 재트리거로 stateless 재개", 계약 위반 아님); (c) **재개할 때마다 paste 줄을 벽 집합에서 재파생해 다시 출력**해 "까먹음"을 구조적으로 차단. paste 줄은 파생값이라 `loop.md` 스키마 변경 불요(상태 계약 ripple 없음).

**범위**: 이 손질은 **fg-next all의 동형 `/goal` 섹션**(소유 ADR-0010)에도 같이 적용했다 — 동일 메커니즘·동일 one-cycle-stall이라 한쪽만 고치면 곧 다른 쪽에서 재발하기 때문. **불변**: `/goal`을 스킬이 자동 발동하는 것은 여전히 불가능하고(하니스 제약), 안전 벽(§4)·ADR-0009·활성 슬롯 1개·회고 auto-skip·위임 핸드오프의 진술형(ADR-0015)은 전부 그대로다. 이번 변경은 순수 문서(framing) 수준이며 드라이브 로직·게이트는 건드리지 않는다.

## 개정 (2026-06-18) — no-progress 벽이 참조하는 이력을 loop.md에 영속화 (`## Check progress` + `wall:`)

§4의 **No-progress 조기 중단 벽**("같은 체크 2연속 무진전")과 fg-status의 멈춤-원인 보고는 "체크별 이전 결과·연속 무진전 횟수·시도한 fix-forward·증거"를 알아야 한다. 그러나 최초 `loop.md` 스키마는 현재 체크박스·라운드·Tasks 멤버십만 담았고, fg-loop은 **stateless 재개**(매 pause 후 재트리거)라 — 영속 이력 없이는 재개 시 "이 체크가 이미 2번 무진전이었는지"를 판별할 수 없어 no-progress 벽이 사실상 발동하지 못하고, cap까지 거의 동일한 fix-forward를 반복 제안할 수 있었다(adversarial review가 지적한 "진행 없이 같은 작업 반복" 모드).

**결정**: `loop.md`에 **`## Check progress` 원장**(체크별 result·`×N` 연속 무진전 횟수·last-evidence·tried slug)과 상단 **`wall:` 필드**(멈춤 정확 원인)를 추가한다. fg-loop은 매 stop-condition 실행 후 원장을 갱신하고, no-progress 벽은 in-session 기억이 아니라 **원장의 `×N ≥ 2`**로 판정하며, 벽에서 `wall:`을 채운다. fg-status는 이 필드들을 읽어 "왜 멈췄는지"(어느 체크·몇 회 무진전·증거)를 보고하므로 맨 "fg-loop 재개" 반복이 사라진다.

**불변**: 드라이브 순서·cap·replan 범위·walls 집합·ADR-0009는 그대로. 이번 변경은 기존 no-progress 벽이 stateless 재개에서 *실제로 작동하도록* 필요한 상태를 영속화하는 additive 보강이다(로직 신설 아님).

## 개정 (2026-06-18, 2차) — Reflexion: 실패 언어화 → 다음 fix-forward에 주입

[How to build a Claude loop](https://gaodalie.substack.com/p/how-to-build-a-claude-loop-engineering)의 Reflexion 패턴(실패를 자연어로 언어화해 다음 시도에 사용)을 fg-loop에 도입한다. 동기: 직전 개정의 `## Check progress` 원장은 무진전을 `×N`으로 *세기만* 할 뿐, 실패한 fix-forward의 "왜 실패했고 다음엔 무엇을 다르게"를 보존·주입하지 않아, 다음 fix-forward가 같은 접근을 반복하다 벽에 부딪혔다(반복 정체 모드). 참고 글의 나머지 기법(worktree 병렬·cron·MCP 커넥터·Generator/Evaluator/Planner 3역할·별도 SKILL.md/loop_system.md)은 forge가 이미 갖췄거나(파일 메모리·stop+cap·진행추적·UAT·docs 연료) 순차·오케스트레이션 전용 개념에서 벗어나므로 **의도적으로 배제**하고 Reflexion 하나만 차용한다.

**결정**: `## Check progress` 원장의 각 체크에 **`reflection:` 한 줄**(왜 직전 접근이 evidence를 못 움직였나 + 다음엔 무엇을 *다르게*)을 추가한다. fix-forward 생성은 그 체크의 `tried`+`reflection`을 먼저 읽고 **이미 시도한 접근의 반복이 아닌 다른 접근**의 plan을 만든다(첫 실패엔 reflection 없음 → 평소대로; 2번째 시도부터 작동; `verified: failed` fix-forward에도 적용). no-progress 벽 임계값(×2 unchanged-evidence)은 불변이나 의미가 격상된다 — "같은 접근 반복"이 아니라 "서로 다른 접근들이 모두 무진전"; 벽 보고에 reflection을 포함한다. reflection이 "범위 밖 수정이 필요"로 결론나면 cap 소진 전 **fork 벽 조기 발동**.

**경계(불변)**: `reflection`은 loop.md에 사는 **드라이브 내 휘발 작업기억** — goal 충족 시 loop.md와 함께 삭제되며 **회고(retro)가 아니다.** 영속 학습 승급은 종전대로 run.md → 사람 fg-learn(ADR-0010 불변). 임계값·cap·authorized replan 범위·walls 집합·ADR-0009도 전부 불변 — Reflexion은 범위 내 fix-forward의 *질*을 높일 뿐 권한을 넓히지 않는다.

## 개정 (2026-06-25) — tension 벽(oscillation 가드) + safety 벽(비가역 행위 정지)

Forward Future의 [Loop Library](https://signals.forwardfuture.ai/loop-library/)(69개 루프 레시피)의 공통 가드레일 DNA에 대고 fg-loop를 감사한 결과, DNA의 대부분(기계 검증 정지 조건·"AI가 됐다고 생각함"은 정지 아님·no-progress 2라운드·Reflexion·evidence ledger·stateless 재개·독립 기계 checker)은 이미 보유함이 확인됐고, 진짜 빈틈 둘만 남았다 — 둘 다 ADR-0016 walls/replan 메커니즘의 경계 있는 *확장*이며 별도 ADR 바(되돌리기 어려움·맥락 없이 의아함·진짜 트레이드오프)를 따로 넘지 않아 7차 개정으로 기록한다.

**① tension 벽 (oscillation 가드).** 기존 no-progress 벽(`×N ≥ 2`)은 *같은* 체크가 증거 불변으로 연속 실패할 때만 발동한다. 그러나 C1을 고치면 C2가 깨지고 C2를 고치면 C1이 깨지는 **체크 간 긴장**에서는 각 체크가 pass/fail을 번갈아 → 증거가 매 라운드 바뀌어 `×N`이 2에 못 도달 → 조기 중단이 안 터지고 cap을 전부 소진한 뒤 무의미한 "cap-exhausted"로만 멈춘다. Loop Library #034(multi-LLM convergence)는 oscillation을 1급 정지 사유로 명시한다. **결정**: `## Check progress` 원장에 **`regressed: ×N`**(체크가 직전 기록 대비 pass→fail로 뒤집힌 횟수 — 무인 드라이브에선 두 체크 실행 사이 변경이 봉인된 fix-forward뿐이라 인과 귀속이 깨끗) 마커를 추가하고, **lenient + 1회 재시도** 정책으로 처리한다 — 첫 regression엔 다음 fix-forward에 "타깃 체크 + 회귀된 체크를 동시에 만족" 하드 제약을 Reflexion과 나란히 주입하고, 또 깨지면(같은 체크 `regressed ×2` 또는 두 체크 핑퐁) cap 전 **`wall: tension (Cx↔Cy)`**로 조기 정지해 충돌 쌍·증거를 사람에게 넘긴다. 감지는 **기계적·확정적**(원장의 pass→fail 플립)이다.

**② safety 벽 (비가역 행위 정지).** Loop Library는 거의 모든 루프가 "파괴적/프로덕션/외부/비가역 행위 = 승인 필요"를 *design fork와 별도로* 명시한다. fg-loop은 이를 "genuine fork" 하나에 뭉뚱그렸는데, 기존 설계가 덮는 건 *승인 범위 밖*인 경우뿐이다 — **승인 범위 안인데 비가역**인 fix-forward(예: 체크="prod에 orphan row 없음" + 범위="데이터 정리" → prod DELETE)는 자동 생성·실행되어 버린다(사용자가 넓은 권한이면 하니스 prompt도 안 뜸). **결정**: fix-forward **생성 시점**에 생성될 plan 슬라이스를 `loop.md`의 `## Authorized replan scope`에 표준화한 **`always-halt action classes`**(기본 7클래스 — prod 데이터 변경/삭제 · 배포/릴리스/publish · 외부 발신 통신 · 비가역 VCS/파일 파괴 · 금융/결제 · 시크릿/권한 변경 · 프라이버시 데이터 노출; 루프별 override/확장 가능)에 대고 자기분류, 하나라도 걸리면 생성 대신 **`wall: safety (<class>)`**로 정지한다. 강제 지점은 fix-forward 생성 시점만 — 초기 inquiry plan은 fg-ask로 사람이 그릴링했으니 재게이트하지 않는다.

**①②의 비대칭(솔직히 명기).** ①은 원장 플립으로 **기계적·확정적** 감지가 되지만, ②는 fg-loop이 생성하는 plan을 모델이 **스스로 분류**하는 best-effort 안전 *선언*이다(Markdown 플러그인이라 정적 분석기로 강제 불가). ②의 가치는 100% 가로채기가 아니라, 멈춤이 계약과 `/goal` stop-allowed 집합에 명시되어 드라이브가 "멈추라는 명시 지시"를 갖는 것이다.

**기각·경계(불변).** replan-cap과 별개의 토큰/시간 budget(**→ 토큰 지출 상한 부분은 2026-08-19 개정에서 기각 해제됨; 아래 개정 절 참조. 시간 budget은 기각 유지**)·체크 상태 다변화(proved/weak/contradicted — 기계 체크의 이진성이 없애려던 주관성 재도입)는 YAGNI로 기각. **fg-next all에는 비적용** — tension·safety 둘 다 *생성된* fix-forward에서만 발생하는데 fg-next all은 fix-forward를 만들지 않으므로(공유는 `/goal` 메커니즘뿐, 벽 집합 분리), goal-pairing 개정(2026-06-15)의 fg-next 동기 대상이 아니다. cap·authorized replan 범위·ADR-0009·활성 슬롯 1개·회고 auto-skip·Reflexion·ADR-0015 진술형은 전부 불변.

## 개정 (2026-06-25 2차) — 7차 개정 두 벽의 제어흐름 허점 보정 (Codex 적대적 리뷰)

7차 개정 직후 배포(v0.4.27)에 대한 Codex 적대적 리뷰가 두 벽의 제어흐름 허점 2건을 짚었다. 둘 다 7차 개정의 *의도*는 옳았으나 SKILL.md *메커니즘*이 그 의도(및 이미 작성된 소비자 설명)보다 넓거나 누락된 경우였다 — 메커니즘을 의도에 맞추는 보정이다.

**[high] tension 귀속이 너무 넓었다.** 7차 메커니즘은 "매 seal 후 pass→fail 플립 = regression, `regressed:` 증가"로 **모든** 봉인 작업을 카운트했다. 그러나 tension은 *fix-forward가 체크를 주고받는* 현상인데, 초기 멀티태스크 백로그 drain 중엔 사람이 그릴링한 member 작업도 정상적으로 체크를 깰 수 있다(다중작업 간섭). 그 member regression이 `regressed:`에 카운트되면 (a) 두 member가 각각 다른 체크를 깨 `regressed ×2`/핑퐁 위양성 `wall: tension`, 또는 (b) 알려진 regression을 지나쳐 주행하는 모순이 생긴다. **결정(옵션 a)**: `regressed: ×N`을 **fix-forward 귀인 플립(`generated-by: fg-loop`)만** 세도록 한정한다. member 작업의 플립은 `last-evidence`에만 기록(체크가 failing이 되어 잔여 백로그/후속 fix-forward가 처리)하고 `regressed:`·tension·드레인 정지에 영향 없음. tension의 satisfy-both 재시도·`×2`/핑퐁 정지는 모두 fix-forward 귀인 regression에만 적용된다. 기각한 옵션 b(즉시 우선 분기로 satisfy-both fix-forward를 백로그 승격 전 삽입)는 드라이브 제어흐름을 재배치해 더 침투적이고, member 간섭에도 조기 fix-forward를 생성해 백로그 순서를 교란할 위험이 있어 보류.

**[medium] safety 게이트가 `verified: failed` 자동 경로를 우회했다.** 7차의 safety 게이트는 backlog-empty replan 경로에만 다이어그램으로 드러났고, `verified: failed` 자동 fix-forward bullet과 그 다이어그램 화살표는 게이트를 통과하지 않았다. `/goal`이 `verified: failed`에선 멈추지 말라고 지시하므로, 게이트 누락 시 *승인 범위 안의 비가역* 수정이 무인 자동 실행될 수 있다(최고위험 경로의 제어흐름 모호성). **결정**: safety 분류를 **모든 fix-forward 생성의 필수 전제조건**으로 통합 명시한다 — backlog-empty replan과 `verified: failed` 자동 케이스가 동일 게이트를 통과하고, 다이어그램의 `verified: failed` 화살표도 `safety-class?`를 경유한다.

**소비자 무변경(근거).** wall enum 소비자(CLAUDE.md·docs/skills.md·docs/forge-vs-loop-engineering.md·README 양판)의 tension 설명은 7차 작성 시점부터 이미 "fix-forward가 깨뜨리는"으로, safety 설명은 "fix-forward 생성 시점"으로 (옳게) 스코프돼 있었다 — 어긋난 것은 SKILL.md 메커니즘뿐이라 이 보정은 메커니즘을 그 설명들에 정렬한다(소비자 편집 불요). **불변**: 두 벽의 이름·`wall:` enum·cap·authorized replan 범위·ADR-0009·활성 슬롯·회고 auto-skip·Reflexion·fg-next all 비적용은 전부 그대로.

## 개정 (2026-07-11) — `verified: failed`는 별도 backlog plan이 아니라 active-slot in-place repair

기존 문구는 `verified: failed`에서 새 fix-forward plan을 backlog에 생성한 뒤 계속 주행한다고 했지만, 실패한 원래 작업이 유일한 active slot을 점유한 채 남는다. fg-run은 active slot을 항상 backlog보다 먼저 처리하므로 새 plan을 승격할 수 없고, 결과적으로 생성된 plan은 실행되지 않거나 원래 작업 수리 뒤 중복 실행된다. 이는 "활성 슬롯 1개" 불변과 자동 fix-forward를 동시에 만족하지 못하는 제어흐름 결함이었다.

**결정**: `verified: failed` 자동 케이스는 새 task/slug를 만들지 않고 **같은 active task를 제자리 수리**한다. 시도 전에 `replan-round`를 올려 cap을 적용하고, 실패 체크의 `tried`·`reflection`에서 다른 접근을 도출한 뒤 authorized scope와 safety 게이트를 통과시킨다. active plan에는 내용·식별자를 바꾸지 않는 `<!-- repaired-by: fg-loop -->` provenance marker만 더하고, fg-run의 기존 failed 분기(수정 → fresh run.md → 재검증)를 사용한다. 시도명(`<slug>-repair-rN`)은 `loop.md` 원장에 남긴다. active slot이 비어 있고 stop-condition만 실패한 경우에만 종전처럼 새 `generated-by: fg-loop` backlog plan을 만든다. tension의 fix-forward 귀속은 두 marker(`generated-by` 또는 `repaired-by`)를 모두 인정한다.

`verified: failed` active task → round+1/cap 확인 → scope·safety 확인 → `repaired-by` marker + fg-run in-place repair → fresh UAT

**불변**: ADR-0009(실패 작업 봉인 금지), active slot 1개, 재계획 범위·cap, no-progress·tension·safety 벽, 회고 auto-skip은 그대로다. 바뀐 것은 failed fix-forward의 저장 위치와 실행 순서뿐이다.

## 개정 (2026-07-16) — stop-condition 체크 "충실성(faithfulness)" 적대 그릴링 (lean 예외)

무인 드라이브에서 "done"을 판정하는 유일한 기준은 `## Stop-condition checks`의 기계 검증 체크다. 그런데 이 체크는 목표의 *프록시*라, 게임 가능(Goodhart)하거나 불완전하면 드라이브가 "all checks pass → loop.md 삭제 → 완료"로 **거짓 승리**를 선언한다(아무도 안 보는 무인 주행일수록 치명적). 무인 자율 계약(2026-06-13 개정)의 "초기 inquiry를 LEAN하게" 지시는 inquiry를 *빠른 시작*에 최적화하는데, 이 leanness가 체크 정의에까지 적용되면 정작 가장 중요한 것(체크가 목표의 *충실한* 프록시인지)을 대충 못 박게 된다. 사용자 지적: fg-loop의 핵심은 끝나는 조건이고, 그 조건을 그릴링하는 것이 지속적 loop 엔지니어링의 전제다.

**결정**: fg-loop §1에 **체크 충실성 적대 그릴링**을 추가하고, 이 부분만 "lean" 지시에서 **명시적으로 카브아웃**한다(주변부 — scope·cap·TDD·slug·분해 — 는 lean, 체크 자체는 하드 그릴). 각 체크(및 집합)를 네 렌즈로 한 질문씩 적대적으로 그릴해 통과할 때까지 재작성/확장한다: **① 게임 가능성(Goodhart)** — 통과하는데 목표 미달? → 존재가 아니라 행동/결과 단언으로 조임 · **② 완전성/regression 누수** — 전부 통과하는데 중요한 게 깨짐? → anti-regression 체크 추가(기존 tension/regression 기계에 그대로 먹이) · **③ 충실 vs 편한 프록시** — 진짜 의도를 재나 grep 쉬운 걸 재나? · **④ in-scope 도달성** — 승인된 replan scope 안에서 달성 가능? → 아니면 cap 태우기 전 fork 조기 표면화(§3). 충실+in-scope 도달 가능한 체크로 못 만들면 non-runnable goal과 동일 처리(sharpen 또는 fg-ask 라우팅). 산출물은 `## Stop-condition checks`의 강화·확장된 체크 집합뿐 — **새 loop.md 필드 없음**(상태 계약 ripple 회피, 2026-06-12 loop-md-contract-gaps 회고).

**정합(모순 아님)**: 같은 무인 자율 계약이 이미 "이 레인이 보존하는 사람 판단 = 정지 조건을 앞에서 못 박기"라 했다. 체크를 하드하게 그릴하는 것이 *바로 그 판단의 올바른 수행*이다 — leanness의 위반이 아니라 그 경계다.

**기각·경계(불변)**: 렌즈 4(in-scope 도달성)를 "충실성"과 분리해 별도 게이트로 두는 안은 YAGNI로 기각(같은 up-front 그릴링에서 함께 판정하는 게 자연스럽고, 도달 불가 체크의 조기 fork는 기존 §3 fork-early와 연결). per-check "faithfulness rationale"를 loop.md에 영속하는 안도 기각(새 필드 = ripple 부담, 드라이브는 체크만 실행하면 되므로 근거 영속 불요). 드라이브·walls·ledger·Reflexion(§2/§3/§4)·cap·authorized replan 범위·ADR-0009·활성 슬롯 1개·회고 auto-skip은 전부 불변 — 이 개정은 체크를 *어떻게 정의하는가*(앞단)만 강화하고 *어떻게 돌리는가*는 안 건드린다. fg-ask도 무변경(4렌즈는 "체크=프록시"라는 fg-loop 고유 문제라 fg-loop 본문에만 둠).

## 개정 (2026-08-09) — `waiting`(외부 증거 대기)과 `blocked-health`(능력 사전점검); LoopX quota는 기각 유지

외부 참조 [LoopX](https://huangruiteng.github.io/loopx/docs/)(control plane: objective · todos · gates · evidence · quota)를 fg-loop에 대조한 결과다. 다섯 중 넷은 이미 forge에 있다 — objective=goal+authorized scope, todos=`## Tasks` 멤버십+활성 슬롯 1개, gates=벽 6종+7 action class, evidence=`## Check progress` 원장+Reflexion(오히려 더 정교). 남은 하나(quota)와 그 주변에서 두 개의 **오분류**가 드러났다.

**① quota 본체는 기각 유지 — 단 이유를 정확화한다.** 7차 개정(2026-06-25)은 토큰/시간 budget을 "forge 작업은 사람 규모"로 기각했는데, 이는 부정확했다. LoopX quota의 실체는 토큰 예산이 아니라 **벽시계 분(minute) 슬롯을 24시간 윈도우에 배분**하는 것이고, 그 전제는 **다수의 상시 goal이 자동 에이전트 시간을 놓고 경쟁하는 cron/heartbeat 구동 시스템**이다. forge에는 그 전제 자체가 없다 — `loop.md` 1개, 활성 슬롯 1개, 사람이 트리거. **경쟁할 goal이 없으므로 배분할 것이 없다.** 기각은 유지하되 근거는 "작업 규모"가 아니라 "다중 goal 경쟁 부재"다(규모가 커져도 이 결론은 안 바뀐다는 점에서 더 강한 기각이다). 같은 이유로 `scheduler_hint`·tick 스케줄링·claim/lease·attention queue도 미도입 — 후자 둘은 동시 에이전트 전제라 활성 슬롯 1개 계약에서 무의미하다. (크로스-턴 무인 구동 수단(`ScheduleWakeup`/cron)으로 `/goal`을 보완하는 안은 성격이 다르고 `DRIVE.md`를 통해 fg-next에 파급되므로 **별건으로 유예**.)

**② `waiting` — 외부 증거 대기는 실패가 아니다.** LoopX의 상태 enum(`eligible/throttled/waiting/operator_gate/paused/blocked_health/focus_wait`)이 짚는 구멍: 정지 체크가 "CI 초록"처럼 **남의 시계에 달린 증거**에 의존하면, 아직 판정 불가인 상태를 fg-loop는 평범한 실패로 읽는다. 대가가 둘이다 — 존재하지 않을 수도 있는 문제에 `replan-round`를 태우고, 끝내 `unverifiable-uat` 벽으로 **사람이 해결할 수 없는 것**을 사람에게 넘긴다.

**결정**: 체크에 `evidence: external`을 §1에서 **선언**할 수 있게 하고, 선언된 체크가 통과 아니면 **무조건 `waiting`**으로 분류한다. `replan-round` 미소모, fix-forward 미생성, `fail ×N`·`regressed: ×N` 미오염, `reflection` 없음. **벽이 아니다** — 사람에게 아무것도 요구하지 않는 유일한 상태라, 벽으로 보고하면 이 상태가 없애려던 오분류를 보고 층에서 재생산한다.

**핵심 트레이드오프(명시)**: 판정을 *선언*만으로 하고 **`waiting-when:` 술어를 버렸다.** 술어가 없으니 주행은 "CI가 빨간불"과 "CI가 미완"을 **구분할 수 없고**, 따라서 **선언된 외부 체크는 자동 수리 대상에서 통째로 빠진다.** 받아들인 이유: (a) 런타임 추론은 "이건 그냥 대기"라는 자기선언 알리바이를 열어 렌즈 1(Goodhart)이 막으려던 구멍을 무인 주행에 다시 뚫는다 — 선언만이 모델 재량 0을 보장한다; (b) 외부 증거에 걸린 결함은 대개 authorized replan scope 밖(=fork 벽 행)이라 실제로 잃는 자동 수리가 적다; (c) 마커 한 줄로 끝나 §1에 새 렌즈·새 필드가 안 붙는다. **대가의 직접적 귀결**: 술어가 없으니 대기가 실패로 떨어질 자연 탈출구도 없어, **`stalled-waiting` 상한(연속 `×2` + `last-evidence` 불변)이 영구 대기를 막는 유일한 안전장치**가 된다 — 선택 사항이 아니라 이 설계의 필수 구성이다. 임계값 2는 기존 no-progress `×N ≥ 2`와 통일해 사용자가 외울 값을 하나로 유지한다.

**③ `blocked-health` — 환경 결함을 코드 결함으로 읽지 않는다.** 체크 명령이 아예 실행 못 되면(도구 부재·미인증·권한) 지금은 코드가 틀린 것과 동일하게 실패로 잡혀, 도움이 될 수 없는 fix-forward에 cap을 태우고 끝내 `no-progress` 벽으로 **진짜 원인을 감춘 채** 멈춘다.

**결정**: 주행 첫 체크 실행 **전에** 각 체크 명령의 실행 파일명을 **도출**해(`command -v`) 확인하고, 실패면 `wall: blocked-health (<name>)`. 파이프 뒤 도구·미인증·권한은 사전 도출이 못 잡으므로 **보수적 사후 승격**을 둔다 — 명령이 대상에 도달조차 못 한 명백한 경우(실행 파일 부재·권한 거부)만 승격하고 **애매하면 평범한 실패로 둔다**. 비대칭은 의도적이다: 환경 문제를 실패로 오분류하면 라운드 하나를 낭비할 뿐이지만(현행 동작), 실패를 환경 문제로 오분류하면 **진짜 버그를 숨긴다**. LoopX의 `required_capabilities`처럼 사람에게 능력 목록을 **선언받지 않는다** — §1의 lean 계약 위반이자, 체크 명령에 이미 있는 정보의 중복 질의다.

**④ 신규 최상위 필드를 만들지 않는다.** `waiting ×N`은 기존 `## Check progress` 원장 줄에, `evidence: external`은 기존 `## Stop-condition checks` 절에 흡수한다. 최상위 `waiting:` 필드를 두는 안은 그릴링에서 한 번 채택됐다가 **기각**됐다 — `.forge/retro/2026-07-16-fg-loop-check-faithfulness-grilling.md`(및 2026-06-12 loop-md-contract-gaps)가 두 번 적용한 규율, *"새 능력을 새 필드/상태가 아니라 기존 절의 강화된 산출물로 흡수 → 소비자 6지점 ripple 회피"* 를 이번에도 따른다. 대가는 "대기 중인가"를 최상위 한 줄이 아니라 원장에서 읽는 것인데, 소비자는 이미 전부 원장을 파싱하므로 실질 손실이 작다. LoopX식 `state:` 필드 신설도 기각 — `wall:`과 **이중 장부**가 되어 forge가 STATUS.md에서 이미 배격한 패턴이다. 늘어난 것은 `wall:` enum 값 **둘**(`stalled-waiting`·`blocked-health`)뿐이며, 이 둘은 진짜 벽이라 불가피하다.

**벽 집합의 비대칭(불변 유지)**: `stalled-waiting`·`blocked-health`는 tension·safety와 마찬가지로 **fg-loop 전용**이다 — 둘 다 `evidence: external` 선언과 능력 사전점검에서 발생하는데 `fg-next all`엔 그 기계가 없으므로 fg-next의 벽 집합은 무변경이다(공유는 `/goal` 메커니즘뿐).

**출처 성격**: LoopX의 **개념 각색**이며 코드·CLI vendoring이 아니다(선례: fg-agenda ← Wayfinder). `loopx` 명령·상태 이름·JSON 계약은 가져오지 않았고, 채택한 것은 "대기와 실패는 다른 상태다"·"실행 전제는 소진 전에 게이트한다" 두 통찰뿐이다.

**불변**: ADR-0009(검증 없는 봉인 금지)·활성 슬롯 1개·authorized replan 범위·cap·no-progress/tension/safety 벽·Reflexion·회고 auto-skip·ADR-0015 진술형·기둥 1의 경계 있는 완화는 전부 그대로다. 이 개정은 **판정 불가·실행 불가 상황을 실패에서 분리**할 뿐 실패의 처리 방식은 안 건드린다.

## 개정 (2026-08-19) — 토큰 지출 상한 기각 해제 (`budget-tokens` + `budget-exhausted` 벽)

GitHub 이슈 #12("loop의 다양한 조건을 fg-loop에서 선택해 쓰게 해 달라")에서 출발해, 참조된 외부 글(Kopadze, *Loops explained*)의 구성요소를 fg-loop 현행과 1:1 대조한 결과다. 글이 든 것 대부분은 이미 있거나 forge가 더 엄격하다 — 5단계 사이클(=fg-ask→run→UAT→fix-forward)·State(=`## Check progress`+Reflexion)·Stop condition(=체크+`replan-cap`)·"모델이 자기 채점하면 관대하다"(=§1의 기계 검증 불가침, 글이 허용하는 루브릭 자가채점보다 엄격)·maker≠checker(=기계 체크가 독립 checker, 별도 verifier 서브에이전트를 두지 않는 근거는 본문 그대로). **비어 있던 것은 하나, `Cost`다** — 글은 이 축에 독립 절과 다이어그램 박스 하나를 배정했다.

**① 토큰 지출 상한의 기각을 해제한다 — 기존 기각에 살아 있는 근거가 없었다.** 7차 개정(2026-06-25)이 "토큰/시간 budget"을 기각한 근거는 "forge 작업은 사람 규모, fg-run이 이미 bounded"였고, 79행은 그 근거가 **2026-08-09 개정에서 교체됐다**고 표시해 뒀다. 그런데 2026-08-09 개정이 실제로 제시한 근거는 **LoopX quota(벽시계 분 슬롯을 다중 goal에 배분)**에 대한 것이며, 그 개정문 스스로 *"quota의 실체는 토큰 예산이 아니라"*고 두 메커니즘을 구분한다. 즉 토큰 예산 기각은 **폐기 표시된 근거와, 다른 물건을 겨눈 대체 근거 사이에서 근거 없이 서 있었다.** 게다가 폐기된 근거의 사실 주장도 틀렸다 — `fg-run`에 강제 상한은 0건이고 권고 산문 2줄(*"Estimate cost first"*·*"trial a small slice"*)뿐이며, Dynamic Workflow 런타임의 `budget.total`은 **사용자가 `+500k`류 지시를 칠 때만** 설정돼 스킬이 걸 수 없다.

**② quota 기각은 유지하되, 지출 상한과 명확히 갈라 놓는다.** quota는 *경쟁하는 다수 goal에 시간을 배분*하는 것이고 forge엔 그 전제가 없다(`loop.md` 1개·활성 슬롯 1개·사람 트리거). 지출 상한은 *단일 goal의 누적 자원 천장*이다. **전자의 기각이 후자를 덮지 않는다** — 이 구분을 명문화하지 않으면 다음 사람이 79행만 보고 다시 닫는다(실제로 이번에 그렇게 닫힐 뻔했다).

**③ 단위는 원시 토큰 총량**(`input_tokens`+`cache_creation_input_tokens`+`cache_read_input_tokens`+`output_tokens`). USD 환산은 단가표 드리프트 부채라 기각. 출력 토큰만 세는 안도 기각 — 실측 샘플에서 `cache_read` 90,818 대 `output` 1,270(71배)이므로 루프가 태우는 것의 1.4%만 세게 되고, 무엇보다 **글이 경고한 "매 iteration마다 재전송되는 컨텍스트"의 직접 계측치가 바로 cache_read**다. 정직한 대가: 캐시읽기 단가가 훨씬 싸므로 원시 합산은 청구액을 **과대평가**한다. 이 숫자는 "비용"이 아니라 "토큰 처리량"이다.

**④ 최상위 필드 2개(`budget-tokens`, `budget-spent · since:`)로 담는다 — 원장 흡수 규율은 재대조했고 적용되지 않는다.** 2026-07-16·2026-08-10에 두 번 적용된 규율은 "새 필드를 만들지 말라"가 아니라 **"이미 자연스러운 집이 있으면 새 집을 짓지 말라"**다. `waiting`은 체크별 상태라 원장에 집이 있었다. 지출은 **어느 체크에도 속하지 않는 drive 수준 값**이므로 원장에 넣으려면 "C1이 소비한 토큰"이라는 없는 개념을 발명해야 한다. 구조적 쌍둥이는 `replan-round`/`replan-cap`(누계+천장, 둘 다 최상위)이다. **파생(매번 재계산)도 기각** — 단 그 근거는 **2026-08-20 개정에서 교체됐다**(아래 참조). 애초에 적은 "델타 누적만이 무관한 작업 청구를 피한다"는 **사실이 아니었다.**

**⑤ 검사는 태스크 경계에서 2겹**(사후 + 사전 예측). fg-loop는 워크플로우 안으로 들어갈 수 없으므로(fg-run 소유·Dynamic Workflow는 런타임 입력 불가) "즉시 중단"은 도달 불가능한 선택지다. 사후만 두면 상한이 "±한 태스크"로 희석되므로, 다음 태스크 시작 전에 `남은 예산 < 관측된 태스크당 평균`이면 시작하지 않는다. 평균은 `budget-spent ÷ 봉인된 멤버 태스크 수`로 공짜이고, **첫 태스크는 평균이 없어 무조건 시작**하므로 최악 초과는 한 태스크로 유계다. 보수적 오정지는 안전한 실패 방향이다(사람이 상한을 올려 재개).

**⑥ `budget-exhausted` 벽은 `replan-round`를 소비하지 않고 fix-forward도 만들지 않는다** — 자원 소진이라 고칠 코드가 없다(`waiting`·`blocked-health`와 같은 처우). 단 `waiting`과 달리 **벽이다**. **해제 의미론이 다른 벽과 다르므로 "정리"하지 말 것**: 재개는 `wall:`을 `none`으로 리셋하지만 천장은 여전히 도달 상태라 다음 체크포인트가 같은 벽을 재기록한다. 유일한 출구는 사람이 **`budget-tokens`를 올리는 것**이고 **`budget-spent`는 리셋하지 않는다** — `cap-exhausted`를 `replan-round` 리셋 없이 `replan-cap` 상향으로 푸는 것과 동형이다. 누계를 리셋하면 천장이 묶으려던 유일한 숫자가 조용히 사라진다.

**⑦ §1 lean 계약을 깨지 않는다 — 기존 cap 질문에 흡수한다.** 새 질문을 만들면 §1에 네 번째 항목이 붙어 18행("ask only what is needed…")을 위반한다. *"재계획 상한 3라운드, 토큰 상한은? (없음도 가능)"* 한 줄로 합쳐 **질문 수를 늘리지 않는다.** **기본값은 발명하지 않는다** — 근거로 쓸 실측 주행 비용이 리포에 없다(fg-run은 토큰을 기록하지 않는다). `none`이면 검사를 전부 우회해 종전 동작과 동일하다. 다만 **기본 off + 안 묻기**는 기각했다: 그러면 아무도 켜지 않아 죽은 기능이 되고, 그것이 `fg-agenda`에서 실제로 관측된 실패 모드다. 매 주행 표면에 떠오르게 하는 것이 그 대가 없는 예방이다. 기본값은 `budget-spent` 실측이 쌓인 뒤 별건으로 정한다.

**⑧ 스크립트 백킹(ADR-0031 세 다리 전부 통과).** 순수 기계적 ✅ · **LLM이 하면 느림 ✅(가장 강함 — 세션+서브에이전트 트랜스크립트 다수를 읽어 메시지별 4필드를 합산하는 것은 "비용을 재려고 비용을 태우는" 구조다)** · 자주 도는 경로 ✅(체크포인트마다). `forge-loop-spend.sh`/`.js` 트윈 + behavior + parity(ADR-0022), 판정은 exit code로 넘기고 벽 세우기는 산문(ADR-0030/0031). 관측 근거는 `~/.claude/projects/<slug>/<uuid>.jsonl`과 `<uuid>/subagents/agent-*.jsonl`의 메시지별 `usage`이며, 실측으로 서브에이전트 10개가 합계에 +14,457,833 토큰(약 11%) 기여함을 확인했다.

**⑨ 벽 집합의 비대칭 — 이번 것은 성질이 다르다(오인용 방지).** `stalled-waiting`·`blocked-health`·tension·safety가 `fg-next all`에 비적용인 것은 그쪽에서 **발생 자체가 불가능**하기 때문이다(fix-forward 미생성·외부/능력 선언 부재). **예산 초과는 `fg-next all`에서 완벽하게 발생 가능하다** — 무인 주행이고 같은 워크플로우를 태운다. `budget-exhausted`를 fg-loop 전용으로 두는 것은 천장이 `loop.md`에 살고 `fg-next all`엔 계약 파일이 없다는 **범위 결정**이며 구조적 불가능이 아니다. 동일 노출이 그쪽에 의도적으로 남아 있고, 이를 덮으려면 `config.json`에 프로젝트 기본값을 두는 별건 작업이 필요하다.

**기각·경계(불변).** 시간(벽시계) budget · LoopX quota·`scheduler_hint`·claim/lease · USD 환산 · `fg-next all` 적용 · "cost per accepted change" 지표(forge는 `verified: yes` 봉인으로 accept 신호를 이미 갖지만 상한보다 투기적이라 2차) — 전부 기각 또는 유예. ADR-0009·활성 슬롯 1개·authorized replan 범위·`replan-cap`·no-progress/tension/safety/waiting/blocked-health 기계·Reflexion·회고 auto-skip·ADR-0015 진술형은 전부 불변이다. 이 개정은 **자원 천장을 하나 더 추가**할 뿐 실패·대기·판정 불가의 처리 방식은 안 건드린다.

## 개정 (2026-08-20) — 미터의 정체 정정 · 측정 불가는 벽 · 경계당 1회 호출 (적대적 리뷰 #114 후속)

`#114`가 낸 미터를 적대적 리뷰(6렌즈 팬아웃)가 공격해 critical 1·major 6·minor 3을 확인하고, 후속 그릴링이 미판정 9건 중 8건을 실측으로 추가 확인했다. 그중 **설계 전제 하나가 틀렸고**, 나머지는 구현 결함이다. 결정 자체(지출 상한을 둔다·단위·필드 형태·2겹 검사·해제 의미론)는 전부 유지된다.

**① 2026-08-19 개정 ④의 근거를 교체한다 — 그 문장은 거짓이었다.** 파생(매번 재계산) 방식을 기각한 근거로 *"델타 누적만이 벽↔재개 사이 무관한 작업 청구를 피한다"*를 적었으나, `since:`는 **매 호출 `now`로 전진**하므로 다음 구간의 첫 델타가 그 사이 사람이 한 작업을 전부 포함한다. 즉 델타 누적과 재계산은 **총액이 같고**, 누적은 같은 총액을 증분 기록하는 것일 뿐이다. **기각은 유지하되 근거는 실재하는 것으로 바꾼다** — (1) 매 호출 전량 재스캔을 피하는 비용, (2) 트랜스크립트 회전·삭제에 견딤.

**② 그래서 미터의 정체를 다시 쓴다.** 이것은 "이 드라이브의 지출"이 아니라 **"루프가 살아 있는 동안 이 프로젝트가 태운 토큰 처리량"**이다. 무인 AFK 주행에서는 사람이 딴 일을 하지 않으므로 대체로 같지만, **그 동일성은 전제이고 전제는 문서에 있어야 한다.** 기각한 대안 둘: `sessionId` 필터·drive 구간 마커 — 둘 다 합산 대상을 *줄이는* 방향이라 **위험한 오차(과소 계상 = 천장 미발동)를 늘린다.** 특히 마커는 누락 시 0을 합산해 천장을 통째로 무력화하는 새 무증상 실패를 만든다. **이 천장은 회계 장부가 아니라 안전 한계**이고, 과대 계상이 안전한 오차라는 것이 이 개정의 여러 결정을 지배하는 원칙이다.

**③ 측정 불가는 무증상이 아니라 벽이다 — 새 exit `5` `BLOCKED`, 기존 `blocked-health` 재사용.** `budget-tokens: N`이 선언됐는데 (a) 트랜스크립트 루트를 읽을 수 없거나 (b) `since:`가 타임스탬프가 아니거나(템플릿 placeholder `{ISO}`가 실제로 발생하는 경우) (c) 상한값이 정수로 파싱 불가면, 종전에는 `spent=0` + exit 0으로 **천장이 조용히 무효**였다(그리고 테스트가 그 동작을 사양으로 고정해 놨다). "아직 안 썼다"와 "측정 불가"를 구분하지 못하는 것이 M1(slug 오도출)을 무증상으로 만든 진짜 원인이므로, 이제 exit 5로 halt한다. `budget-tokens: none`이 "묶지 말라"의 정식 표현이므로 **"선언했는데 측정 불가"는 애매한 상태가 아니라 모순**이다. 새 벽 클래스는 만들지 않는다 — `blocked-health`의 정의("환경 문제, 코드 변경으로 안 풀림")가 이미 정확히 이 모양이다. stderr 경고만 두는 안은 기각: AFK에서 아무도 안 읽는다. **baseline보다 먼저** 검사한다(주행 시작 시점에 알아야 한다).

**④ 경계당 호출 1회 — 2회 호출은 계약 자체의 버그였다.** 2026-08-19 개정 ⑤가 "봉인 직후(사후) + 다음 태스크 시작 전(사전 예측)" 2회 호출을 지시했는데, 첫 호출이 `since:`를 전진시켜 두 번째가 같은 구간을 다시 세었다(실측 `spent=10` → `20`). 태스크 경계에서 두 시점은 **같은 순간**이므로 나눌 이유가 없었다. `--preflight` 플래그를 **제거**해 단일 동작으로 만들고(초과 먼저, 그다음 예측), `now`의 **밀리초 절삭도 제거**한다(절삭은 경계 *간* 같은-초 재계상을 남긴다). 멱등 워터마크(계상한 uuid 기록)는 원장에 대량 상태가 들어가므로 기각.

**⑤ 측정 정확성 — 이중 계상 두 종류.** (i) `usage.iterations[]`가 같은 4필드를 되풀이하는데 줄 전체 스캔이 그것을 또 세어 **실측 1.928배 과대**였다(실제 코퍼스 usage 라인 7,616건, `iterations` 길이 분포 `{0:1285, 1:6331}`). (ii) `toolUseResult.usage`는 **서브에이전트 지출이 부모 트랜스크립트에 되보고된 것**이고 우리는 그 서브에이전트 트랜스크립트를 따로 읽으므로 세면 이중 계상이다(실제 코퍼스에 1건, 정확히 35,447 토큰 — awk strip 방식에 남던 잔차와 일치). 둘 다 제외한 뒤 실제 코퍼스에서 **진실값과 정확히 일치**(2,071,636,333, 오차 0)한다.

**⑥ 트랜스크립트 경로 도출 — 두 축이 틀렸다.** Claude Code는 프로젝트 디렉터리를 **세션 cwd** 기준으로 명명하고 **모든 비영숫자**를 `-`로 바꾼다(실증: `/Users/gyuha/.settings/bin` → `-Users-gyuha--settings-bin`; 그 경로의 git toplevel은 상위인데 디렉터리는 cwd 기준). 종전의 `tr '/' '-'` + git-toplevel은 경로에 `.`·`_`·공백·비ASCII가 있는 리포에서 **존재하지 않는 디렉터리**를 가리켰고, ③ 이전에는 그것이 조용히 `spent=0`이 됐다.

**⑦ 트윈을 의도적으로 다른 방식으로 구현한다 — parity가 실제 교차 검증이 되도록.** `.sh`는 awk로 `iterations` strip, `.js`는 `JSON.parse` 구조 파싱. **같은 파싱 전략을 공유하면 두 트윈이 같은 실수를 하고 parity는 green이다** — 그것이 1.928배가 11/11 통과로 출하된 경로다. 자세한 규약은 ADR-0022 개정(2026-08-20) 소관이며, 이 개정은 그 첫 적용 사례다.

**기각·경계(불변).** 시간(벽시계) budget · LoopX quota · USD 환산 · `sessionId` 필터·drive 마커 · 멱등 워터마크 · `fg-next all` 적용(여전히 **범위 결정**, 구조적 불가능 아님) · 기본 상한값 지정(실측 축적 후 별건) — 전부 기각 또는 유예 유지. ADR-0009·활성 슬롯 1개·authorized replan 범위·`replan-cap`·no-progress/tension/safety/waiting/blocked-health 기계·Reflexion·회고 auto-skip·ADR-0015 진술형은 불변이다.
