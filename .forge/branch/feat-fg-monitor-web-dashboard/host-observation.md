# Claude 호스트 관측 — 2026-10-20

환경: macOS arm64, Node 24.13.0, Claude Code 2.1.303.
방법: 격리된 `/tmp/forge-monitor-probe`에서 `--setting-sources '' --settings <관측 훅 JSON> --strict-mcp-config --mcp-config '{"mcpServers":{}}' --no-session-persistence`로 테스트 세션을 실행했다. 사용자 작업 세션이나 설치 캐시의 forge 훅을 관측 대상으로 사용하지 않았다.

## 관측 결과

| 세션 | 실제 이벤트 순서 | 결과 |
|---|---|---|
| A — 도구 없는 최소 응답 | SessionStart → UserPromptSubmit → Stop → SessionEnd | 정상 완료, exit 0 |
| B — probe 서브에이전트 1회 | SessionStart → UserPromptSubmit → SubagentStart → SubagentStop → Stop → SessionEnd | spawned 1 / completed 1 / failed 0, exit 0 |

모든 이벤트에서 환경 변수 `CLAUDE_PID`는 해당 테스트 Claude 프로세스 PID와 같았다. `CLAUDE_CODE_SESSION_ID`는 훅 JSON의 `session_id`와 같았다. 서브에이전트 이벤트도 부모 Claude PID와 세션 ID를 유지하고 JSON에 고유 `agent_id` 및 `agent_type: probe`가 추가됐다.

`SessionEnd.reason`은 두 경우 모두 `other`였다. 따라서 reason의 특정 값 하나에만 종료를 연결하지 않는다. `Stop`은 응답 종료, `SessionEnd`는 세션 종료로 구분한다.

수집 코드는 PID·세션·이벤트 이름·에이전트 타입만 관측했다. 환경 변수 키 목록은 진단했지만 인증 토큰 값과 대화 전문은 기록하지 않았다. 제품은 환경 변수 전체를 수집하지 않는다.

추가로 `command: node`, `args: [<관측 스크립트>]`의 exec-form 훅도 같은 설치 버전에서 실행했다. 셸을 거치지 않고 SessionStart → UserPromptSubmit → Stop → SessionEnd가 관측됐고 모든 이벤트의 환경/JSON 세션 ID가 일치했다.

## 초기 제품 서버 통합 관측

`/tmp/forge-monitor-probe/live-uat.cjs`로 새 임시 git 프로젝트의 실제 Claude 세션에 제품 CLI와 훅을 연결했다. 세션 시작 시 서버를 시작하고 모든 관측 이벤트를 제품 수집기로 전달했다.

- 정상 세션: Agent 도구로 probe 서브에이전트 1회 실행. 턴 종료 후 서버는 살아 있고 주 에이전트는 waiting, probe는 ended였다. 입력 스트림을 닫아 실제 Claude가 종료된 뒤 HTTP 서버 종료까지 998ms.
- 강제 종료 세션: 별도 Claude 세션을 시작하고 응답 후 서버 생존을 확인했다. 검증용으로 생성한 Claude 프로세스만 SIGKILL한 뒤 HTTP 서버 종료까지 314ms.
- stderr 오류 없음. 위 시간은 macOS 초기 구현의 실측값이며 모든 OS의 보장값으로 확대하지 않는다. 후속 수정이 끝나면 최종 구현에서도 재검증한다.

## 최종 제품·플러그인 관측

리뷰 수정 후 같은 실제 Claude harness를 다시 실행했다. 정상 종료는 977ms, 생성한 테스트 Claude의 SIGKILL 종료는 108ms 만에 listener가 닫혔다. 두 세션 모두 Stop 후 서버가 유지됐다. 정상 세션에서 주 에이전트 waiting 및 probe 서브에이전트 ended를 관측했다. stderr 오류는 없었다.

별도 새 임시 프로젝트에서 `--plugin-dir`로 작업 트리를 직접 로드했다. Claude 초기 응답에 `forge@inline 0.9.6`과 `forge:fg-monitor`가 등록됐으며, 실제 스킬 대화로 다음을 확인했다.

1. 첫 on: 보관 방식 질문, 설정과 서버는 아직 생성하지 않음.
2. keep 답변: 다른 설정 키를 보존해 저장하고 서버 시작.
3. off 후 on: 질문 없이 keep 재사용.
4. 실제 `forge:fg-config monitorRetention delete`: 설정은 바뀌지만 이미 실행 중인 서버의 keep 정책 유지.
5. off: active 제거, keep 요약 2개 보존. 실제 플러그인 훅의 UserPromptSubmit/PreToolUse/PostToolUse/Stop 관측.

사용자 프로젝트 설정은 변경하지 않았다. 최초 sandbox 시도는 인증 갱신 오류로 도구 실행 전에 멈췄고, 승인된 sandbox 밖 재시도에서 성공했다. 임시 원시 관측에는 만료 접속 키가 포함돼 저장소에 복사하지 않았다.

## 남은 검증과 한계

실제 Claude 관측은 macOS 결과다. Linux에서는 Node 통합 테스트를 실행했지만 실제 Claude 세션은 관측하지 않았고, Windows 실행 환경은 없어 CI 결과를 기다린다. 화면의 DOM·HTTP·갱신 동작은 확인했으나 브라우저 스크린샷 호출이 반복 timeout으로 시각 UAT는 미완료다.

Node의 `process.kill(pid, 0)`만으로 이미 재사용된 PID의 프로세스 생성 시점을 식별할 수는 없다. Linux에서는 `/proc` 생성 식별값도 비교한다. 서버는 외부 PID에 종료 신호를 보내지 않고, 본인 런타임의 무작위 식별자와 인증된 서버 응답으로 중복/낡은 상태를 구분한다. macOS/Windows의 400ms 소유 PID 검사 사이 즉시 재사용 경합은 별도 한계로 남으며 완전한 프로세스 신원 보장으로 표현하지 않는다.
