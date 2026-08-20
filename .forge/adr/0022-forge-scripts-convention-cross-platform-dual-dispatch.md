# forge 스크립트 규약 + 크로스플랫폼 이중 디스패치 (.sh + .js)

## 맥락

forge가 기계적·결정론적 연산을 스크립트로 추출하기 시작했다(ADR-0020 — fg-status survey/테이블을 `forge-status.sh`로). 타깃 환경이 **Windows와 mac/Linux 둘 다**이고, 특히 한 사용 환경은 **보안 정책상 PowerShell이 차단**되어 있어 `.ps1`을 쓸 수 없다. 참조한 [planning-with-files](https://github.com/othmanadi/planning-with-files)(23.5k★)는 모든 셸 스크립트를 `.sh`+`.ps1` 쌍으로 두고 hooks·JSONL ledger·SHA attestation·완료게이트까지 갖췄으나 — 그 기능 대부분은 forge가 이미 자기 형태로 갖고 있거나(FORGE-ROOT 해석·ADR-0009 검증게이트·fg-loop·fg-next 콜드재진입) forge 철학과 충돌한다(hooks 의존·단일저자 루프의 attestation 과잉). 그래서 차용하는 것은 **"결정론적 연산을 스크립트로 추출"하는 방법론 하나**다.

## 결정

- **각 운영 스크립트는 `.sh`(bash, 1차) + `.js`(node, 폴백) 트윈으로 제공한다.** PowerShell 차단 환경 때문에 `.ps1`은 배제하고 node를 폴백으로 쓴다(node는 Claude Code가 항상 보장).
- **호출 규약 — bash 우선, node 폴백.**
  - **스킬 호출 경로**: Bash 도구가 bash를 보장하므로 `bash scripts/<name>.sh`로 호출한다.
  - **statusline 경로**: Bash 도구 *밖*에서 시스템 셸로 실행되고 PowerShell이 강제/차단될 수 있다. fg-statusline 설치 시 **bash 가용 여부를 한 번 판정해 단일 `STATUSLINE_CMD`를 확정**한다 — bash 있으면 settings.json 진입을 `<CFG>/forge-statusline.sh`로, 없으면 `node <CFG>/forge-statusline.js`로 둔다(런타임 내부 위임이 아니라 설치 시점 분기). 원본 statusline 보존 wrapper는 bash 전용이라, no-bash 호스트에선 forge를 단독 statusline으로만 연결하고 기존 것 래핑은 미지원(후속). `.sh`와 `.js`는 동일 출력(패리티 테스트로 보장)이므로 어느 쪽이 연결돼도 결과가 같다.
- **포터블 규칙**: shebang `#!/usr/bin/env bash`(`/bin/bash` 금지 — NixOS 등), `bash script.sh`로 호출(`./script.sh` 금지 — NTFS는 POSIX exec 비트가 없음), realpath류는 python fallback, `.gitattributes`로 `*.sh`를 **LF 강제**(CRLF가 bash를 깨뜨림 — PWF가 실제 겪은 이슈).
- **drift 관리(이중 유지의 핵심 리스크)**: (1) fg-doctor가 `scripts/*.sh`마다 `.js` 트윈 존재를 **정적 검사**, (2) **같은 fixture에 두 구현을 돌려 출력 동일성을 단언하는 패리티 테스트**가 진짜 동치 가드다(존재 검사보다 강력).
- **판단은 스크립트로 옮기지 않는다.** grilling·retro 분류·divergence 평가·검증 결정 같은 LLM 판단은 산문에 남기고, 결정론적 survey/상태 전이만 스크립트화한다(ADR-0020의 "survey=스크립트, next-step=산문" 분할을 일반 규약으로 계승).
- **스크립트 수를 의도적으로 작게 유지한다.** 1차 추출은 `forge-status`(ADR-0020 마무리)와 `resolve-forge-root` 2개 + statusline 포팅. 나머지(backlog 스캔·seal 기계부분·fg-doctor 체크)는 패턴 검증 후 후속.

## 고려한 대안

- **`.ps1` 미러(PWF식)** — PowerShell 차단 환경에서 무용 + 이중 유지. 기각.
- **node 단일 원천** — 크로스플랫폼 가장 단순하나 "bash 기본" 의도와 충돌하고 기존 `.sh`(forge-status·statusline)를 폐기. 기각.
- **맥락별 단일 원천**(루프 스크립트=sh만, statusline=node만) — 패리티 부담 0으로 더 단순하나, 사용자가 향후 de-bash·Bash 도구 밖 독립 실행 여지를 위해 **이중 디스패치를 명시 선택**. 그 비용(패리티 유지)은 패리티 테스트로 상쇄.

## 결과

- 이중 유지 비용이 생기지만 패리티 테스트 + fg-doctor 트윈 검사로 관리한다.
- forge는 여전히 스킬 경로에서 bash를 하드 의존한다(Bash 도구가 ls/grep/mv 등을 셸아웃). node 폴백이 실효를 갖는 유일한 지점은 **statusline**이다 — Windows/PowerShell-차단 환경의 실제 수정 지점.

## 개정 (2026-08-20) — parity는 *일치*를 보장하지 *정확성*을 보장하지 않는다: 외부 스키마 파서에 진실 대조 의무

`forge-loop-spend`(ADR-0016 개정 2026-08-19)가 이 ADR의 보장에 구멍이 있음을 실증했다. 두 트윈이 **같은 정규식 전략**으로 남의 JSON을 파싱했더니 **같은 실수**를 했고, behavior 29×2 + parity 11 전부 green으로 출하됐다. 실제 오차는 **1.928배 과대**였다(`usage.iterations[]`가 같은 4필드를 되풀이하는데 줄 전체 스캔이 또 셈). 봉인 전 적대적 리뷰가 잡았고, 독립 렌즈 5개가 같은 지점에 수렴했다.

**① 진단: parity 테스트는 *동치*를 검증하고 *정확성*을 검증하지 않는다.** 이 ADR의 «결과» 절은 "이중 유지 비용이 생기지만 패리티 테스트 + fg-doctor 트윈 검사로 관리한다"고 적었는데, 그 관리 범위는 **drift**(두 트윈이 서로 달라짐)뿐이다. **공유 오류**(두 트윈이 같이 틀림)는 parity가 구조적으로 볼 수 없고, 오히려 green이 확신을 준다. 이 구분이 명문화돼 있지 않아 "parity green"이 "맞다"로 읽혔다.

**② 규약: 외부가 소유한 스키마를 파싱하는 스크립트는 진실 대조(ground-truth cross-check)를 갖춘다.** 대상 판정 기준은 **"입력 형식을 forge가 정의하지 않는가"** — Claude Code 트랜스크립트 `usage`, 세션 JSON, 남의 CLI 출력 등. forge 자신이 형식을 정의하는 것(`loop.md`·`STATUS.md`·plan)은 해당하지 않는다(형식과 파서가 같은 저자라 대조할 외부 정본이 없다). 대조 방법은 **독립적인 경로로 같은 답을 계산해 비교**하는 것이다: 기대값을 손으로 적지 않고 픽스처에서 `JSON.parse`로 계산해 스크립트 출력과 맞춘다. 손으로 적은 기대값은 저자의 스키마 모형만큼만 옳고, 그 모형이 틀린 것이 바로 이번 사고다. 픽스처에는 **함정 형태를 반드시 포함**한다(이번 경우 `iterations[]`·중첩 `cache_creation`·`toolUseResult.usage`·이스케이프된 JSON 블롭). 덧붙여 픽스처는 **계약이 갈릴 수 있는 최소 다중 케이스**로 만든다 — 이번에 모든 멤버 픽스처가 `- alpha` 하나였던 탓에 `.js`가 첫 멤버만 읽는 결함이 parity green 속에 숨어 있었다(N=1은 N>1의 대표가 아니다).

**③ 정직한 한계 — CI로 강제할 수 없다.** 진실 대조가 **머신 로컬 데이터**를 필요로 하는 경우(트랜스크립트가 `~/.claude/`에 있다)에는 커밋된 테스트가 될 수 없고, 봉인 전 사람이 한 번 돌리는 데 의존한다. 그래서 이 의무는 두 층으로 나뉜다 — **픽스처 기반 진실 대조는 커밋된 테스트로**(가능하고 필수), **실제 코퍼스 대조는 봉인 전 수동 1회로**(불가피하게 비-CI). 이 비대칭을 감추지 않고 적는다: `fg-doctor`가 검사할 수 있는 것은 트윈 존재뿐이며 진실 대조의 존재는 검사하지 못한다.

**④ 트윈을 의도적으로 다른 방식으로 구현하는 것이 권장된다.** 같은 전략의 두 구현은 오류를 복제하지만, **다른 경로로 같은 답을 내면 parity 자체가 교차 검증**이 된다. `forge-loop-spend`가 첫 적용 사례다 — `.sh`는 awk로 `iterations`를 잘라내고, `.js`는 `JSON.parse`로 구조를 읽는다. 대가는 두 구현을 각자 이해해야 한다는 것이고, 얻는 것은 parity green이 실제 신호가 되는 것이다. **강제하지는 않는다**(단순 필드 추출에는 과하다) — 외부 스키마 파서에 한한 권장이다.

**⑤ 탈출구: 정규식으로 안전하지 않은 중첩 JSON은 node 주 구현으로 전환한다.** `.sh`의 `iterations` strip은 `"iterations":\[[^]]*\]`로 실측 정확하지만(실제 코퍼스 6,363건 제거 실패 0) **`iterations` 안에 `]`가 없다는 현 스키마에 의존**한다. 스키마가 그것을 깨면 정규식을 더 비틀지 말고 그 스크립트를 **node 주 구현으로 뒤집고 `.sh`는 얇은 디스패처로 남긴다**(B15 트윈 검사는 그대로 만족). 지금 뒤집지 않은 이유는 규약 예외가 영구 비용이고(다음 작성자가 매번 "내 것도 예외인가"를 되묻는다), 현 방식이 실측 정확하며, 진짜 원인은 bash의 약함이 아니라 정답 대조 부재였기 때문이다 — ②가 그것을 막는다.

**불변.** `.sh` 우선 + `.js` 폴백의 이중 디스패치 · `*.parity.test.sh` 의무 · `*.test.sh` behavior 의무 · fg-doctor B15 트윈 검사 · ADR-0030 게이트-우선-비파괴 · ADR-0031의 스크립트/산문 경계는 전부 그대로다. 이 개정은 **테스트 의무를 하나 더 얹을 뿐** 디스패치 구조를 바꾸지 않는다.
