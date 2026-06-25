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

**기각·경계(불변).** replan-cap과 별개의 토큰/시간 budget(forge 작업은 사람 규모, fg-run이 이미 bounded)·체크 상태 다변화(proved/weak/contradicted — 기계 체크의 이진성이 없애려던 주관성 재도입)는 YAGNI로 기각. **fg-next all에는 비적용** — tension·safety 둘 다 *생성된* fix-forward에서만 발생하는데 fg-next all은 fix-forward를 만들지 않으므로(공유는 `/goal` 메커니즘뿐, 벽 집합 분리), goal-pairing 개정(2026-06-15)의 fg-next 동기 대상이 아니다. cap·authorized replan 범위·ADR-0009·활성 슬롯 1개·회고 auto-skip·Reflexion·ADR-0015 진술형은 전부 불변.

## 개정 (2026-06-25 2차) — 7차 개정 두 벽의 제어흐름 허점 보정 (Codex 적대적 리뷰)

7차 개정 직후 배포(v0.4.27)에 대한 Codex 적대적 리뷰가 두 벽의 제어흐름 허점 2건을 짚었다. 둘 다 7차 개정의 *의도*는 옳았으나 SKILL.md *메커니즘*이 그 의도(및 이미 작성된 소비자 설명)보다 넓거나 누락된 경우였다 — 메커니즘을 의도에 맞추는 보정이다.

**[high] tension 귀속이 너무 넓었다.** 7차 메커니즘은 "매 seal 후 pass→fail 플립 = regression, `regressed:` 증가"로 **모든** 봉인 작업을 카운트했다. 그러나 tension은 *fix-forward가 체크를 주고받는* 현상인데, 초기 멀티태스크 백로그 drain 중엔 사람이 그릴링한 member 작업도 정상적으로 체크를 깰 수 있다(다중작업 간섭). 그 member regression이 `regressed:`에 카운트되면 (a) 두 member가 각각 다른 체크를 깨 `regressed ×2`/핑퐁 위양성 `wall: tension`, 또는 (b) 알려진 regression을 지나쳐 주행하는 모순이 생긴다. **결정(옵션 a)**: `regressed: ×N`을 **fix-forward 귀인 플립(`generated-by: fg-loop`)만** 세도록 한정한다. member 작업의 플립은 `last-evidence`에만 기록(체크가 failing이 되어 잔여 백로그/후속 fix-forward가 처리)하고 `regressed:`·tension·드레인 정지에 영향 없음. tension의 satisfy-both 재시도·`×2`/핑퐁 정지는 모두 fix-forward 귀인 regression에만 적용된다. 기각한 옵션 b(즉시 우선 분기로 satisfy-both fix-forward를 백로그 승격 전 삽입)는 드라이브 제어흐름을 재배치해 더 침투적이고, member 간섭에도 조기 fix-forward를 생성해 백로그 순서를 교란할 위험이 있어 보류.

**[medium] safety 게이트가 `verified: failed` 자동 경로를 우회했다.** 7차의 safety 게이트는 backlog-empty replan 경로에만 다이어그램으로 드러났고, `verified: failed` 자동 fix-forward bullet과 그 다이어그램 화살표는 게이트를 통과하지 않았다. `/goal`이 `verified: failed`에선 멈추지 말라고 지시하므로, 게이트 누락 시 *승인 범위 안의 비가역* 수정이 무인 자동 실행될 수 있다(최고위험 경로의 제어흐름 모호성). **결정**: safety 분류를 **모든 fix-forward 생성의 필수 전제조건**으로 통합 명시한다 — backlog-empty replan과 `verified: failed` 자동 케이스가 동일 게이트를 통과하고, 다이어그램의 `verified: failed` 화살표도 `safety-class?`를 경유한다.

**소비자 무변경(근거).** wall enum 소비자(CLAUDE.md·docs/skills.md·docs/forge-vs-loop-engineering.md·README 양판)의 tension 설명은 7차 작성 시점부터 이미 "fix-forward가 깨뜨리는"으로, safety 설명은 "fix-forward 생성 시점"으로 (옳게) 스코프돼 있었다 — 어긋난 것은 SKILL.md 메커니즘뿐이라 이 보정은 메커니즘을 그 설명들에 정렬한다(소비자 편집 불요). **불변**: 두 벽의 이름·`wall:` enum·cap·authorized replan 범위·ADR-0009·활성 슬롯·회고 auto-skip·Reflexion·fg-next all 비적용은 전부 그대로.
