# 실행 기록 — fg-monitor 웹 대시보드

실행일: 2026-10-20
계획: `plan.md` (task 1, tdd on)
브랜치: `feat-fg-monitor-web-dashboard`
결과: 구현·검토 수정 완료, 일부 환경/시각 검증 대기. 커밋·push·봉인은 하지 않았다.

## 슬라이스 결과

- S1 호스트 입력·소유 세션 관측 — ✅ 실제 Claude 주/서브에이전트·Stop·SessionEnd와 정상/강제 종료 관측, 익명화 테스트 입력 포함.
- S2 상태 조회·이벤트 수집 — ✅ 순수 조회 분리, 기존 CLI parity 보존, 세션 격리·부분 쓰기·checkpoint·지연 이벤트 회귀 검증.
- S3 Node 서버·명령·보관 — ✅ 인증 HTTP·기본/외부 바인딩·중복·소유권·설정·keep/delete 검증.
- S4 A안 대시보드 — ⚠ 구현과 실제 브라우저 기능/크기 검증 완료, 스크린샷 시각 검증은 브라우저 도구 오류로 대기.
- S5 스킬·훅·설정·문서 — ✅ 실제 새 Claude에 plugin-dir 설치해 첫 질문·저장·재사용·설정 변경·off 확인.
- S6 OS 통합 검증 — ⚠ macOS Node 24 및 Linux Node 22 통과, Windows/나머지 CI 조합·문서 시각 검증 대기.

## 구현과 검토

`scripts/forge-monitor.js`와 `forge-hook-monitor.js`는 추가 런타임 패키지 없이 Node로 실행한다. UI는 같은 서버에서 제공하며 모든 자산/API에 접속 키가 필요하다. 기본은 127.0.0.1이고 `on --host 0.0.0.0`만 외부 인터페이스를 연다. 브라우저의 쓰기 API는 없다. 첫 보관 선택과 이후 변경은 스킬 및 fg-config로 처리한다.

화면은 한국어 A안의 좌측 프로젝트/보기, 상단 단계, 작업 문서와 에이전트/활동 패널을 구현했다. 계획 체크 항목만 수치화하고 관측이 없으면 확인 불가로 표시한다. 과거 세션과 현재 세션을 합산하지 않는다.

독립 리뷰의 확정 3건을 실행 중 수정했다.

1. 종료 검사와 compaction 사이 SessionEnd 유실 → 영속 sessionEnded 및 단일 compaction 결과로 종료 판단.
2. checkpoint 뒤 늦게 도착한 이벤트가 종료 상태를 되돌림 → 최신 시각과 terminal 상태 보존.
3. 공유 조회가 symlink를 따라 범위 밖 작업을 노출 → 모니터 전용 bounded 조회. 기존 CLI 기본 계약은 유지.

리뷰어가 수정된 세 항목을 다시 확인했고 관련 회귀 3/3 통과를 독립 확인했다. UI의 STATUS 필드도 기존 조회와 같은 bullet/대소문자/괄호 토큰 규칙으로 맞췄다.

## TDD 증거

- 백엔드 최초 기능 테스트: 미구현 assertion 6개 RED → 10개 GREEN.
- UI: 6개 RED → 6개 GREEN.
- 훅 배선: 필수 SessionStart 관측 훅 누락 RED (2 pass / 1 fail) → 3/3 GREEN.
- 리뷰 회귀 3개: RED → GREEN.
- UI STATUS 정규화: `verify !== learn` RED (5 pass / 1 fail) → GREEN.
- 단일 진입점 `node --test scripts/forge-monitor.test.js`가 backend/UI/wiring 모두 실행하도록 통합했다.

## DoD 기준선 → 최종

| 항목 | 기준선 | 최종 관측 |
|---|---|---|
| 1. 모니터 통합 테스트 | 파일 없음 exit 1 (기능 RED 아님) | macOS Node 24.13.0 **22/22**, Linux Node 22 alpine **22/22**, exit 0. 3 OS × Node 22/24 CI 배선 완료, Windows 및 나머지 조합 실행 대기 |
| 2. 기존 훅 | 26 pass / 0 fail | **26 pass / 0 fail**, exit 0 |
| 3. 기존 상태 CLI parity | PARITY OK | **PARITY OK**, exit 0 |
| 4. release check | forge 0.9.6 통과 | **통과**, 버전 유지, 공통 스킬/4개 호스트 어댑터 보존 |
| 5. docs build | 의존성 미설치 exit 127 | 잠금 파일대로 npm ci 후 **exit 0**, 기존 gitignore syntax/chunk size 경고만 존재 |
| 6. 실제 호스트 UAT | 미구현·미수행 | macOS Claude 2.1.303 실제 plugin-dir 스킬 대화 및 훅 수집 확인. 최종 정상 종료 **977ms**, 강제 종료 **108ms**, Stop 후 서버 유지. 다른 OS 실제 Claude 관측 없음 |
| 7. 화면 UAT | 선택용 시안만 존재 | 실제 HTTP UI: 1440px/390px 가로 overflow 없음, 390px 단일 패널 열, 상태 변경 **1285ms**, 기록 선택/실시간 복귀·빈 상태·실패·종료/마지막 관측 확인. CSS/JS **200**. 스크린샷/시각 판단 대기 |
| 8. 문서·배포 경로 | fg-monitor 미등록 | 공통 스킬·설정·11개 Node exec 훅·3개 manifest 설명·KO/EN 문서·카탈로그·지도 갱신. 실제 로컬 plugin-dir 로드 확인. 문서 dark-mode/자산 시각 UAT 대기 |

테스트는 실제 포트/CLI 프로세스/HTTP/디스크 결과를 검사한다. 2개 세션·브랜치 캡처, 빈/잘못된 설정, 인증 실패, 외부 바인딩, 점유 포트, 중복/동시 on, off, 살아 있는 유휴 owner, owner 종료, 낡은 PID, 보관 격리, 1000개 이상 이벤트 compaction, symlink/큰 파일 차단을 포함한다.

브라우저는 테스트 전용 임시 프로젝트를 사용했다. `<img src=x onerror=window.monitorXSS=1>` 제목이 문자로 표시되고 img 요소 0, 실행 false임을 확인했다. 서버를 종료한 뒤 `연결 끊김 · 마지막 상태`와 마지막 관측 시각을 확인했고 테스트 서버/브라우저 공간을 정리했다. 실제 사용자 프로젝트의 보관 설정은 바꾸지 않았다.

## 남은 검증·계획 대비 차이

- Windows 실행 환경이 없으므로 `monitor-check.yml`의 Windows 및 전체 Node matrix CI 결과가 필요하다. CI 파일 존재는 통과 근거가 아니다. 원격 CI를 실행할 push는 하지 않았다.
- 브라우저 Page.captureScreenshot이 반복 timeout/Unable to capture screenshot으로 실패했다. native 화면 접근도 cgWindowNotFound로 실패했다. DOM·실제 브라우저 동작 검사를 스크린샷 검증으로 대체해 완료 선언하지 않는다. Ego Lite 업데이트 알림은 있었으나 업데이트하지 않았다.
- 문서 빌드는 통과했지만 다크모드 시각 검증은 미완료다. 이번 변경의 제품 문서 단락에는 신규 외부 URL을 추가하지 않았다. 설치 경로는 로컬 plugin-dir로 검증했으며 GitHub 기본 브랜치 설치는 아직 변경 전이다.
- macOS/Windows에서 PID가 검사 간격 사이 즉시 재사용되는 경합은 Node만으로 완전 식별하지 못한다. Linux는 /proc 생성 식별값을 추가 비교한다. 외부 PID에는 종료 신호를 보내지 않는다.
- 세부 호스트 관측과 스킬 대화 결과는 `host-observation.md`에 기록했다. 원시 대화/접속 키는 보관하지 않았다.

확정된 제품 실패는 수정·재검증했지만 위 환경/시각 UAT가 남아 `verified: pending`으로 기록한다. 검증을 완료하기 전 회고/봉인으로 진행하지 않는다.

## 검증 재개 — 2026-10-20

기존 구현 워크플로를 다시 실행하거나 새 에이전트를 띄우지 않고 미수행 조합만 검증했다.

- macOS Node 22: `npm exec --yes --cache /tmp/forge-monitor-npm-cache --package=node@22 -- node --test scripts/forge-monitor.test.js` → 22/22, exit 0.
- Linux Node 24: 공식 `node:24-alpine` 컨테이너에서 같은 테스트 → 22/22, exit 0.
- 앞선 macOS Node 24/Linux Node 22를 합쳐 로컬에서 가능한 네 조합 모두 통과했다.
- `gh run list --repo gyuha/forge --branch feat-fg-monitor-web-dashboard` → 실행 기록 없음. Windows CI는 아직 이 미커밋 변경을 받지 못했다.
- 원격 검증을 위한 커밋·push·초안 PR과, 스크린샷 오류 복구를 위한 Ego Lite 업데이트는 사용자 결정을 요청했다. 응답 전에는 수행하지 않는다.

현재 남은 항목은 Windows Node 22/24 CI와 화면/문서 시각 검증이며, 이 확인 없이는 verified를 yes로 바꾸지 않는다.
