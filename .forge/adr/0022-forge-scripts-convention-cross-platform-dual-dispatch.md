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
