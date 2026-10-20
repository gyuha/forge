<!-- forge-slug: fg-monitor-web-dashboard -->
<!-- task: 1 -->
<!-- tdd: on -->
# Claude 세션의 작업·에이전트를 보여주는 fg-monitor 대시보드

## 목표 / 제외 범위

현재 프로젝트·현재 브랜치·현재 Claude Code 세션의 forge 작업과 주/서브에이전트 상태를 Node 웹 앱으로 관찰한다. `/fg-monitor on`으로 시작하고 `/fg-monitor off` 또는 연결된 Claude 종료로 끝낸다. 사용자 선택 A안의 어두운 흐름 중심 관제 화면을 제공한다.

제외: 다른 프로젝트·브랜치·세션의 통합 모니터, Codex/opencode/Pi 에이전트 수집, 작업 실행·취소 등 브라우저 제어, 대화·도구 입출력 전문 뷰어, 추정 진행률·토큰/비용 차트, 상시 서비스, 자동 배포. fg-showme는 설계 시안 도구로 유지하고 제품 모니터와 수명주기를 공유하지 않는다.

서버·수집·UI는 함께 있어야 요청된 사용 흐름이 성립하므로 한 계획으로 구현한다. 슬라이스는 실행 순서를 나누는 단위이며, 독립 봉인되는 part-plan이 아니다.

## 기준 문서

- 이슈 추적: GitHub 이슈 #24 — https://github.com/gyuha/forge/issues/24 (확인 시 OPEN, 댓글 없음).
- 사용자 대화: A안, TDD on, 현재 프로젝트·브랜치·세션, 주/서브에이전트별 상태, localhost 기본/명시적 외부 바인딩, Claude Code 우선, 첫 실행에서 보관 방식 질문 후 설정 저장·변경 허용.
- 이 브랜치 `CONTEXT.md`: 모니터 세션·모니터 기록·확인 불가.
- 이 브랜치 ADR `261020-130456-session-scoped-node-monitor.md`.
- 기본 `.forge/adr/0011-branch-isolated-forge-root.md`, `0020-fg-status-deterministic-script.md`, `0022-forge-scripts-convention-cross-platform-dual-dispatch.md`, `0031-script-backing-convention-for-mechanical-skill-work.md`, `260909-150614-fg-run-inflight-marker.md`.
- `skills/fg-run/FORGE-ROOT.md`, `skills/fg-status/SKILL.md`, `core/HOST.md`, `hosts/claude/`, `skills/fg-config/SKILL.md`.
- 외부 참고: https://code.claude.com/docs/en/hooks 。SessionEnd와 Stop의 의미 및 세션/서브에이전트 이벤트 입력 스키마를 확인했다. 문서는 참고 근거이며 최소 지원 Claude 버전과 실제 전달 필드는 구현 때 설치 버전으로 검증한다.

## 합의한 동작

### 명령·설정

- `/fg-monitor on`: 활성 Claude 세션에 연결, 기본 `127.0.0.1`, 빈 포트 할당, 접속 키가 포함된 URL 제공. 로컬 브라우저 자동 열기는 best-effort이며 실패해도 URL로 접근할 수 있다.
- `/fg-monitor on --host 0.0.0.0`: 명시적으로 모든 IPv4 인터페이스에 바인딩. `0.0.0.0`을 접속 주소라고 안내하지 않고 실제 인터페이스 주소와 포트를 제공한다. 접속 키는 외부 모드뿐 아니라 localhost에서도 사용한다.
- `/fg-monitor off`: 호출한 세션의 모니터만 종료한다. 없으면 이미 꺼져 있다고 응답한다. 같은 세션의 중복 on은 기존 URL을 반환하고 서버를 늘리지 않는다. 바인딩이 다른 on은 무시하지 않고 기존 모니터의 off 후 재실행 방법을 안내한다.
- 프로젝트 설정 `monitorRetention`은 `delete | keep`이며 처음에는 미설정이다. 미설정 첫 on에서 두 선택지를 한 번 묻고 `.forge/config.json`의 다른 키를 보존해 저장한다. 설정 파일이 손상됐거나 값이 잘못된 경우 조용히 덮어쓰거나 기본값으로 삭제하지 않는다.
- `/fg-config monitorRetention delete|keep`으로 변경한다. 실행 중인 모니터에는 시작 시 읽은 값을 고정하고 변경은 다음 시작부터 적용한다. keep→delete 변경으로 과거 보관분을 일괄 삭제하지 않는다.
- keep이면 다음 실행의 같은 프로젝트·브랜치 ‘모니터 기록’에서 과거 기록을 읽을 수 있다. 과거 기록은 종료된 세션임을 표시하고 현재 실시간 상태와 합산하지 않는다. delete이면 해당 실행의 임시 관측 기록만 정리한다. 기존 forge plan/run/done 기록은 어느 모드에서도 보존한다.

### 화면 A

참고 이미지와 showme에서 선택한 A안을 따른다. 새 상품 소개 페이지나 통계 카드 중심 대시보드로 바꾸지 않는다.

```text
forge 모니터 | 프로젝트 / 시작 브랜치 | 연결 상태 / 마지막 갱신
┌ 현재 프로젝트 ┬ 계획 → 실행 → 검증 → 회고 → 완료 ───────────┐
│ 전체 현황     ├ 현재 작업·진행 항목 ┬ 주/서브에이전트 상태 ┤
│ 작업 기록     │ 계획·실행 기록      │ 이름·작업·최근 활동   │
│ 모니터 기록   │ 검증 결과          │ 시간순 활동 요약      │
└──────────────┴────────────────────┴───────────────────────┘
```

- 차콜 배경, 얇은 경계선, 노랑(계획·대기)·파랑(실행)·초록(완료), 실패는 텍스트와 함께 별도 강조. 한국어 라벨, 읽을 수 있는 본문 크기, 상태는 색상 외 텍스트로도 구분한다.
- 왼쪽은 현재 프로젝트 정보와 보기 전환이며, 여러 프로젝트 목록이나 전환 기능을 만들지 않는다.
- 작업 진행 항목은 실제 계획에서 완료 근거를 읽을 수 있을 때만 수치를 표시한다. 파일에 근거가 없으면 ‘진행률 확인 불가’다. 에이전트 활동으로 계획 체크박스를 자동 수정하지 않는다.
- 첫 실행·빈 프로젝트·실행 중·검증 실패·이벤트 수집 불가·서버 종료·재연결을 모두 표현한다. 좁은 화면은 패널을 세로로 쌓는다.
- 저빈도 조회 또는 이벤트 갱신으로 변경 후 통상 2초 안에 화면을 갱신한다. 연결이 끊기면 마지막 관측 시각과 끊김을 표시하고 살아 있는 것처럼 표시하지 않는다.

### 데이터·수명주기

- 시작 시 프로젝트 실제 경로, 브랜치, forge root, Claude session ID를 고정한다. 이후 cwd/브랜치가 바뀌어도 다른 범위로 조용히 전환하지 않는다.
- 기존 resolver를 사용하고, 기존 상태 조회의 규칙·픽스처를 재사용한다. 현재 `forge-status.js`는 CLI 출력 전용이므로 require 부작용이나 표 텍스트 파싱으로 재사용하지 않는다. 필요하면 순수 조회 함수를 분리하되 기존 sh/js 출력 계약을 유지한다. 모니터는 다음 행동을 실행하거나 별도 오케스트레이터 상태 머신을 만들지 않는다.
- 에이전트별 이름(없으면 type/ID), 수행 작업(근거 없으면 미확인), 실행·대기·종료·실패·확인 불가 및 최근 관측 시각을 제공한다. 도구 오류는 활동 오류이지 곧바로 에이전트 최종 실패가 아니다. 서브에이전트 응답 종료와 작업 검증 성공도 구분한다.
- 훅은 해당 모니터가 활성일 때만 최소 메타데이터를 수집한다. 비활성일 때 무기록·짧은 no-op, 오류가 나도 Claude 실행을 막거나 기존 Stop 훅의 제어 결정을 변경하지 않는다. 병렬 이벤트의 유실·중복·순서 뒤바뀜·부분 쓰기를 고려한다.
- 세션 식별·수집 이벤트·프로세스 소유권을 실제 Claude에서 먼저 관측한다. SessionEnd는 정상 종료 경로로 사용하고, 비정상 종료는 실제 소유 Claude 프로세스의 생존 확인으로 보완한다. 실행 명령을 띄운 일시적 셸 PID나 단순 `ppid` 추측에 연결하지 않는다.
- 정상 종료는 이벤트 수신 후 2초 이내, 비정상 프로세스 종료는 10초 이내 서버가 내려가는 것을 목표로 테스트한다. 유휴 시간만으로 사용자 입력을 기다리는 살아 있는 Claude를 종료 처리하지 않는다. `/clear` 등 세션 식별자가 교체되는 경계도 문서화하고 이전 세션 모니터를 새 세션에 자동 이전하지 않는다.
- 소유 세션/프로세스 연결을 검증할 수 없으면 자동 종료 보장이라고 표시하지 않는다. 필요한 호스트 관측이 불가능하면 검증을 pending으로 남기며 기능 완료로 봉인하지 않는다.
- `.forge/monitor/`는 자체 ignore와 세션별 격리. 임시 PID·접속 키는 보관 모드에서도 종료 시 제거하고 활동 요약만 보관한다. 죽은 세션 정리는 해당 세션 소유권·보관 정책을 확인하며, 동시 실행 세션이나 기존 보관 기록을 지우지 않는다.
- 서버와 훅은 Node로 실행되며 bash·PowerShell·Unix 프로세스 명령을 필수 의존성으로 두지 않는다. Node 전용 진입점과 Windows 실행 경로를 검증하고 최소 Node 버전을 명시한다. 루트 package.json은 문서 도구 경계를 유지한다.
- 모든 API/갱신 연결은 키를 검사하고, 임의 파일 읽기·경로 탈출·HTML 실행을 허용하지 않는다. 기록과 작업 제목은 데이터로 렌더한다. 브라우저는 작업 실행/삭제 API를 제공하지 않는다.

## 작업 슬라이스

- [ ] S1. 호스트 입력·소유 세션 관측과 테스트 기반 마련 — 완료 기준: 실제 Claude 세션의 시작/턴 종료/서브에이전트/세션 종료에서 수집 필드와 소유 프로세스 연결을 관측하고, 익명화한 다중 세션·다중 에이전트 픽스처 및 실패하는 기능 테스트를 남긴다. 정상/강제 종료의 독립 재현을 포함한다.
- [ ] S2. 상태 조회·이벤트 수집 — 완료 기준: 동일 forge 상태에 기존 조회와 모니터가 일치하고, 서로 다른 세션 이벤트와 불완전·중복 이벤트를 주입해도 상태가 섞이거나 성공으로 오인되지 않는다. (depends: S1)
- [ ] S3. Node 서버·on/off·소유권·보관 — 완료 기준: 실제 HTTP 서버에서 기본/외부 바인딩, 키 검사, 중복 on/off, 설정 유지, 정상/강제 종료, delete/keep 정리가 아래 기능 테스트를 통과한다. (depends: S2)
- [ ] S4. A안 대시보드 — 완료 기준: 실제 데이터 갱신과 기록 조회가 동작하고, 데스크톱·좁은 화면에서 정상/빈 상태/실패/확인 불가/연결 종료를 브라우저로 확인한다. (depends: S3)
- [ ] S5. 스킬·훅·설정·문서 배선 — 완료 기준: 설치한 플러그인에서 첫 on의 질문·설정 저장·다음 on의 재사용·fg-config 변경·off가 동작하고, 지원하지 않는 호스트는 수집 지원을 거짓 안내하지 않는다. (depends: S3)
- [ ] S6. OS별 통합 검증 — 완료 기준: macOS·Linux·Windows의 Node 테스트와 실제 Claude 세션의 자동 종료 관측 근거가 있으며, 기존 release/hook/status 검사가 통과하고 문서·화면 검증이 완료된다. (depends: S4, S5)

## 완료 정의와 작성 시점 기준선

모든 명령은 리포 루트에서 실행한다. 아래 기준선은 2026-10-20 이 계획 작성 중 실제 실행 결과다.

1. `node --test scripts/forge-monitor.test.js` → exit 0. **전진 체크**: 현재 파일이 없어 exit 1 (`Could not find`). 이것은 아직 기능 테스트의 red가 아니다. S1에서 테스트를 먼저 작성해 기능 미구현으로 실패함을 확인한 뒤 구현하고 green을 증명한다.
   - 테스트는 테스트 이름만 열거하거나 fixture 자체만 검사하지 않고, 배포될 Node 진입점·훅 설정을 실제로 실행한다. 포트/프로세스/HTTP 응답/디스크 결과를 단언한다.
   - 현재/다른 브랜치 및 2개 이상 세션·에이전트, 상태 파일 누락/교체, 위조 session ID, 진행률 근거 없음, 이벤트 누락·중복·오류, 첫 설정 미설정/설정됨/손상됨/잘못된 값, 다음 시작부터 변경 적용, 보관분 조회와 delete 격리를 포함한다.
   - 키 누락/오류 거부, HTML 문자 이스케이프, 경로 탈출 거부, IPv4 loopback 기본/명시적 wildcard 바인딩, 점유 포트, 중복 시작, 종료 후 listener와 소유 자식 프로세스 정리, 다른 세션 생존, 유휴 Claude 유지, 소유 프로세스 강제 종료, 재사용 PID/낡은 상태를 포함한다.
   - macOS/Linux/Windows CI에서 동일 명령을 실행하도록 별도 모니터 워크플로를 배선한다. shell/PowerShell 없는 Node 경로도 검사한다. 로컬 macOS 결과만으로 Windows 성공을 선언하지 않는다.
2. `bash hooks/run-hook.test.sh` → exit 0. **회귀 가드**: 기준선 26 passed / 0 failed. 기존 훅 디스패치의 동작 보존이 목적이라 작성 전 통과가 정상이다.
3. `bash scripts/forge-status.parity.test.sh` → exit 0. **회귀 가드**: 기준선 PARITY OK. 상태 조회를 공유하더라도 기존 CLI의 출력 동치를 유지한다.
4. `npm run release:check` → exit 0. **회귀 가드**: 기준선 forge 0.9.6 공유 스킬·4개 호스트 어댑터 검사 통과. 이 작업에서 버전을 올리지 않는다.
5. `npm run docs:build` → exit 0. **문서 검증**: 기준선 exit 127 (`vitepress: command not found`), 현재 문서 의존성 미설치. 실행 단계에서 잠금 파일에 맞춰 의존성을 준비한 뒤 재검증한다. 현재 결과를 문서 결함이나 통과로 취급하지 않는다.
6. **실제 호스트 UAT**: 설치 후 새 Claude 세션에서 on→주/서브에이전트 활동→Stop에도 서버 유지→off, on→Claude 정상 종료, on→소유 Claude 강제 종료를 각 관측한다. 훅 설치/변경은 세션 재시작 후 적용됨을 안내한다. 모의 이벤트만으로 대체하지 않는다. 호스트/OS/버전·절차·소요시간·결과를 run.md에 기록한다. 기준선: 모니터 미구현으로 미수행.
7. **화면 UAT**: A안의 단계 흐름과 두 패널, 한국어, 데이터 변경 반영, 마지막 갱신, 빈/실패/unknown/종료 상태를 1440px와 390px에서 확인한다. 스크린샷과 모든 자산 응답을 검사한다. 시각 판단은 자동 텍스트 검사로 대체할 수 없어 브라우저 확인을 병행한다. 기준선: 선택용 showme 시안만 있고 제품은 없다.
8. **문서·배포 경로 검증**: 아래 적용 지점을 각 확인한다. 문서 빌드 통과만으로 외부 링크와 설치 경로가 유효하다고 단정하지 않는다.
   - `skills/fg-monitor/SKILL.md`, `skills/fg-config/SKILL.md`, `skills/fg-help/SKILL.md` 및 카탈로그를 실제 읽는 참조 파일.
   - `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`의 제품 목록 설명(버전 유지, 공통 skill 트리 유지).
   - `hooks/hooks.json`, 해당 Node 훅과 진입 래퍼, 기존 SessionStart/Stop 회귀. 필요하면 `hooks/run-hook.cmd`를 호환되게 확장하되 관련 테스트를 함께 보강한다.
   - `README.md`/`README.ko.md`, `docs/skills.md`/`docs/en/skills.md`, `docs/state-contract.md`/`docs/en/state-contract.md`, `docs/index.html`의 실제 스킬 목록·개수와 KO/EN 짝.
   - `CLAUDE.md`의 구조·훅·Node 예외 설명, `skills/fg-run/FORGE-ROOT.md`의 모니터 전역 경로 예외. 호스트 지원표가 있는 `docs/codex.md`/`docs/en/codex.md`, `docs/opencode.md`/`docs/en/opencode.md`, `docs/pi.md`/`docs/en/pi.md`의 해당 주장만 동기화한다. 미관측 capability를 true로 올리지 않는다.
   - `.forge/codebase/ARCHITECTURE.md`, `STRUCTURE.md`, `STACK.md`, `INTEGRATIONS.md`, `TESTING.md`, `CONVENTIONS.md`, `CONCERNS.md` 중 변경되는 사실을 갱신하고 미관측은 표시한다. 작업 브랜치 상태 문서와 지도는 서로 다른 경로 규칙을 따른다.

## 실행 시 유의사항

- 설정 선택은 사용자 제품 흐름에 구현할 내용이다. 계획 단계에서 실제 `monitorRetention` 값을 임의로 선택하거나 `.forge/config.json`을 수정하지 않는다.
- 현재 코딩 호스트는 Codex이고 대상 제품은 Claude Code다. 로컬에 Claude Code 2.1.303과 Node v24.13.0이 있음을 확인했으나, 설치 존재만으로 훅/자동 종료 UAT가 완료된 것은 아니다.
- 이슈 연동 마감은 CLAUDE.md 규칙을 따르되 현재 브랜치는 `feat-fg-monitor-web-dashboard`다. 검증 전 완료 처리나 무관한 main push를 하지 않는다.
