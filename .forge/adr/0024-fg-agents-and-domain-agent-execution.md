# forge가 프로젝트 도메인 에이전트(.claude/agents/)를 fg-run 실행에 통합한다

## Status
accepted

## 맥락
revfactory/harness(도메인 → 멀티 에이전트 팀 메타-팩토리)처럼 "프로젝트 전용 에이전트 팀"을 forge에 넣자는 요구가 나왔다. harness는 도메인 설명을 받아 `.claude/agents/`(에이전트 정의)와 `.claude/skills/`(전용 스킬)를 6개 팀 패턴으로 스캐폴딩하고 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 실험 플래그에 의존한다. 사용자의 동기는 **복제가 아니라 통합** — harness를 따로 쓰지 않고 forge 안에서 도메인 팀을 만들고 그 팀으로 작업을 실행하고 싶다는 것이다.

## 결정
두 부분으로 통합한다.

1. **fg-agents (신규 루프 밖 유틸리티)** — 대화형 그릴링(기둥 1, 워크플로 밖)으로 프로젝트 도메인을 캐 역할을 도출하고, 표준 Claude Code 서브에이전트 정의 `.claude/agents/<role>.md`(role 카드)를 **자체 생성**한다. 온디맨드·선택적이며 루프 4단계에 속하지 않는다.
2. **fg-run 확장** — Dynamic Workflow 빌드 시 `.claude/agents/`를 발견하면 slice에 맞는 role을 Workflow `agent()`의 `agentType`으로 호출해 작업을 실행한다. 도메인 에이전트가 없으면 기존 기본 서브에이전트로 **100% 동일하게** 동작한다(graceful degradation — fg-map/eco/tdd 부재 시와 같은 forge 패턴).

**용어**: 이 ADR에서 "도메인 에이전트(domain agent / role 카드)"는 fg-agents가 생성하고 fg-run이 `agentType`으로 호출하는 `.claude/agents/<role>.md` 정의를 가리킨다. forge 문맥에서 "harness"는 (1) 패키징 모델(CLAUDE.md "harness 플러그인과 동일 패턴")과 (2) revfactory/harness 플러그인을 이미 가리키므로, 3중 혼동을 피하려고 이 기능은 "도메인 에이전트"로 부르고 스킬명도 `fg-agents`로 한다(harness 미사용).

## ADR-0013과의 관계 (비-충돌)
ADR-0013은 **forge 플러그인 자체**에 투기적 영속 서브에이전트(explorer/retro-analyzer/verifier)를 추가하는 것을 보류했다. 이 결정은 그것을 뒤집지 않는다 — forge 플러그인에 에이전트를 더하는 게 아니라, **사용자 프로젝트가 소유한** `.claude/agents/`를 fg-run이 활용하는 호출 경로(`agentType`)를 여는 것이다. 에이전트의 정의·소유는 사용자 프로젝트에 있고 forge는 경로만 노출한다. ADR-0013의 "구체적·재현된 통증" 재검토 바와도 무관하다(그 바는 forge 내부 서브에이전트용). 미래에 누군가 "ADR-0013이 멀티 에이전트를 보류했는데 왜 이걸?"이라고 물으면, 이 문단이 답이다.

## 고려한 대안
- **harness 통째 흡수/복제** — 거부: harness는 "프로젝트 한 번 셋업"(팩토리), forge는 "매 작업 한 바퀴"(루프)로 레이어가 다르다. 흡수하면 forge 정체성이 흐려지고 유지보수가 이중화되며, harness는 한 줄로 같이 설치 가능하다.
- **harness 플러그인에 위임(소프트 의존)** — 거부: 사용자가 자기완결을 택했다(forge가 외부 ponytail/caveman을 차용·각색해 `ECO.md`로 내장한 ADR-0014 선례와 동형). "스킬이 스킬을 호출"하는 실현 불확실성도 회피된다.
- **풀 복제(에이전트 + 전용 스킬 + 6패턴 오케스트레이션)** — 거부: 그중 2/3가 forge 기존 메커니즘의 중복이다. 6패턴은 fg-run 워크플로의 fan-out/pipeline/serial wave(Workflow `parallel()`/`pipeline()`)가 이미 하고, 전용 스킬은 forge 루프 자체가 스킬이며 워크플로 서브에이전트가 이미 모든 도구(MCP 포함)에 접근한다. 통합에 실제로 필요한 새 가치는 role 카드뿐이다.
- **plan에 slice↔role 매핑 마커 / config 등록** — 거부: fg-ask 수정과 등록 메커니즘이 더해져 범위가 늘고, 워크플로 빌더가 role `description`으로 자동 매핑하면 충분하다(YAGNI). 무관 에이전트를 쓸 위험은 fg-run의 기존 스크립트 승인 게이트가 안전망이 된다.

## Consequences
- fg-run 실행 모델이 "기본 워크플로 서브에이전트"에서 "프로젝트 `.claude/agents/`가 있으면 그 role을 `agentType`으로"까지 확장된다. graceful이라 기존 동작은 불변.
- eco(ADR-0014)가 ON이면 `agentType` 호출에도 sonnet 캡 + ECO.md 주입이 적용된다 — 단 role 카드에 `model`이 명시돼 있으면 사용자 명시로 보고 존중한다(eco는 내리기만).
- **전제 (PoC로 검증·보정 — 2026-06-26)**: 프로젝트 로컬 `.claude/agents/<role>.md`는 **세션 시작 시 1회 로드**되며, 그렇게 로드된 카드는 `subagent_type`/`agentType`으로 정상 호출된다(통합 메커니즘 유효 — 공식 문서 "Subagents are loaded at session start" 확인). **단 세션 중 파일로 만든 카드는 동적 픽업되지 않는다**(`/agents` interactive 인터페이스만 즉시 반영하나 스킬이 프로그램적으로 못 씀). 따라서 **fg-agents가 파일로 생성한 role 카드는 세션을 재시작해야 fg-run이 로드**하고, "생성 → 같은 세션 즉시 호출" e2e는 불가하다. 운영 흐름은 **fg-agents 생성 → 세션 재시작 → fg-run 활용**이며(graceful과 정합 — fg-run은 세션 시작 시 로드된 것만 본다), 이 재시작은 프로젝트 셋업 시 1회뿐이고 이후 모든 fg-run이 활용한다.
- 스킬이 18개가 된다(매니페스트 3곳·README 이중언어·`docs/skills.md`·CLAUDE.md 스킬 목록·STRUCTURE.md·fg-doctor 카운트 동기 필요).
- 작업은 두 part-plan으로 분할한다(fg-run 확장 먼저 → fg-agents). 각 part는 독립 sealable.

## 개정 (2026-07-20) — 카드 생성 규율: 최소 권한(tools) + model/effort 축

초판의 fg-agents는 role 카드에 `name`·`description`·(선택) `model`만 채웠다 — 그 결과 모든 카드가 전체 도구를 상속했다(읽기 전용이어야 할 리뷰·분석 역할에도 Write/Edit가 열림). Anthropic *Building Effective Agents*(ACI에 프롬프트만큼 투자·단순성·복잡도는 명증한 개선일 때만), Claude Code subagents 공식 스펙(`tools`/`disallowedTools`/`model`/`effort` 등 지원, 단 `tools` 항목이 도구로 해석 안 되면 **launch 실패**), affaan-m/ECC(67개 에이전트를 역할별 도구 제한·성격별 model로 정의)를 참고해 카드 **생성 품질**을 다음 규율로 정련한다(fg-run 디스패치 경로·slice↔role 자동 매핑은 불변 — 카드가 좋아지면 디스패치도 자동으로 좋아짐).

- **최소 권한 `tools` (핵심)**: 그릴링이 역할 성격을 판별한다 — **읽기 전용 역할**(리뷰·분석·조사)은 고정 안전 세트 `tools: Read, Grep, Glob, Bash`로 제한(ECC의 code-reviewer와 동형·항상 해석되므로 launch-fail 함정 회피); **쓰기 역할**(작성·수정)은 `tools`를 **생략**해 전체 상속(현행 유지). 목적은 보안 경계가 아니라 **역할 이탈 방지**(Bash로 쓰기가 가능한 허점은 수용). MCP 도구는 환경 의존이라 카드에 명시하지 않는다.
- **`model`은 절제, `effort`는 자유 — 비대칭**: `model:`을 박으면 위 eco 조항("eco는 내리기만, 카드 model이 이김")에 의해 **그 역할의 eco 절감이 죽는다**. 그래서 model은 성격이 명확히 요구하고 사용자가 옵트인할 때만 박고 기본은 생략(=inherit, eco 캡 보존). 반면 `effort`는 eco의 model 캡과 독립(모델을 안 바꿈)이라 성격이 뚜렷하면(심층 리뷰=high, 기계 반복=low) 더 편하게 제안한다. 이 비대칭을 SKILL.md에 서술한다.
- **흐름 편입**: tools/model/effort는 별도 질문을 늘리지 않고 역할 **제안 라인에 파생 속성으로 노출**하고 사람이 선택 단계에서 확정·덮어쓴다(도구·모델 성격은 도메인 그릴링이 이미 드러내는 정보). 재실행 시 기존 카드는 surface→confirm-before-replace 경로로 새 기준에 맞춰 갱신 가능.
- **비-목표**: `skills` 프리로드·`memory`·`maxTurns`는 도입하지 않는다(해결할 구체적 통증이 아직 없음 — ADR-0013의 "구체적·재현된 통증" 바와 같은 절제). 범위는 카드 생성 규율뿐, fg-run 매핑 로직은 손대지 않는다.
