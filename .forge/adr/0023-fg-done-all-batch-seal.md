# fg-done `all` — 회고를 일괄 skip하고 실행된 작업을 모두 봉인하는 batch 모드

## 맥락
`fg-run "Run all"`로 여러 작업을 실행해 `.forge/executed/`에 park해두면, 각 작업은 회고를 기다린다. 이것들을 한꺼번에 봉인하려면 회고를 작업마다 돌리거나(fg-learn), 단일 fg-done이 회고 가드(no-seal-without-retro)에 막혀 "먼저 회고하라"며 멈추는 걸 작업마다 우회해야 했다. `fg-next all`은 이 흐름을 자동화하지만 **백로그의 미실행 작업까지 promote·run하는 전체 드라이브**라, "아직 안 돌릴 백로그는 두고 executed 더미만 봉인하고 싶다"는 의도에는 과하다.

## 결정
`fg-done`에 `all` 인자 모드를 추가한다. **이미 실행된 작업(활성 슬롯 + `.forge/executed/` 전부)의 회고를 무조건 자동 skip하고 각자 개별 `done/`으로 일괄 봉인한다.** 의도적으로 완화하는 게이트는 **회고 가드 하나뿐**이고, 나머지 경계는 단일 fg-done과 동일하다:

- **봉인 전용 (fg-next all과의 유일한 구분점).** 대상은 활성 슬롯과 `executed/`뿐. **백로그(`.forge/backlog/`)는 범위 밖** — 미실행 plan을 promote·run하지 않는다. 백로그 실행까지 원하면 `fg-next all`이다. 이 경계가 흐려지면 두 차선이 중복된다.
- **검증 게이트(ADR-0009)는 불가침.** `all`이 푸는 건 회고지 검증이 아니다. `verified:`가 봉인 가능값(`yes`/`skipped`/`n/a`)인 작업만 봉인. `failed`는 절대 봉인 안 하고 fg-run 수리로 라우팅, `pending`/누락은 단일 fg-done과 **동일한 봉인 시점 UAT 복구 경로**를 작업마다 반복(봉인 가능값이면 봉인, 아니면 따로 뺌).
- **회고 무조건 skip.** divergence 무관, `retro: skipped (fg-done all — 학습은 run.md, 승급은 추후 fg-learn)` 기록. ADR-0010(fg-next all)·fg-loop가 이미 택한 동일 waiver — 학습은 아카이브된 run.md에 보존되고 승급은 사람이 추후 fg-learn으로.
- **확인 게이트 1회.** 봉인 직전 봉인 대상(+회고 skip 명시)과 따로 빠질 작업(failed/검증 불가)을 한 번 보여주고 go-ahead 하나를 받은 뒤, 작업당 질문 없이 일괄 봉인(fg-next all 진입 게이트와 동형).

## 고려한 대안
- **`fg-next all`을 쓰게 한다(신규 모드 없음)**: 가장 단순하나, executed 더미만 봉인하려는데 백로그까지 실행돼버린다 — 봉인 전용 niche를 못 채운다.
- **확인 없이 즉시 일괄 봉인**: 더 빠르나 봉인은 불가역에 가깝고 다건이라, 잘못 섞인 작업이 조용히 done/에 들어간다 — 확인 게이트 1회로 막는다.
- **검증도 함께 우회**: ADR-0009 정면 위반 — 사용자가 명시적으로 거부.

## 결과
- 차선 완화 계열(fg-quick=ADR-0003·fg-next all=ADR-0010·fg-loop=ADR-0016·optional retro skip=ADR-0002)의 네 번째 멤버: **봉인 전용·검증 게이트 불가침·회고 무조건 skip**이 경계다.
- "작업 1개 = 봉인 1개" 단위는 유지된다 — `all`은 작업을 묶지 않고 각자 개별 `done/`으로 봉인하며 회고만 일괄 skip한다.
- 봉인이 활성 상태를 비우는 재실행-방지 메커니즘은 그대로다.
