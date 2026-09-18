# Pi에서 forge 사용하기

[Pi](https://pi.dev/)는 다른 호스트와 동일한 forge 스킬 22개를 로드하고 저장소의 `.forge/` 상태를 공유한다. 기본 지원은 대화형 계획·순차 실행·검증·봉인을 제공한다. 별도 Pi 확장은 필요 없다.

## 설치와 호출

Pi 지원 변경이 포함된 로컬 체크아웃을 등록한다. Pi가 패키지의 기본 `skills/` 디렉터리를 탐색하므로 별도 Pi 매니페스트나 스킬 사본은 필요 없다.

```bash
git clone https://github.com/gyuha/forge.git ~/.forge
pi install "$HOME/.forge"
```

체크아웃이 이미 있다면 해당 절대 경로를 넘긴다. `pi install`은 로컬 경로를 복사하지 않고 등록하므로 체크아웃을 유지하고 `git pull`로 갱신한다. 전역 대신 현재 프로젝트에 설치하려면 `-l`을 추가한다. 설치 후 새 Pi 세션을 시작한다.

| 목적 | Pi 명령 |
| --- | --- |
| 계획 시작 | `/skill:fg-ask` |
| 계획 실행 | `/skill:fg-run` |
| 학습 기록 | `/skill:fg-learn` |
| 작업 봉인 | `/skill:fg-done` |
| 상태 확인 | `/skill:fg-status` |
| 다음 단계 실행 | `/skill:fg-next` |
| 백로그 주행 | `/skill:fg-next all` |
| 목표 루프 시작 | `/skill:fg-loop <goal>` |

자연어 트리거도 동작한다. 공통 예시의 `/forge:fg-name`은 Pi에서 `/skill:fg-name`으로 바꾸고 인자는 유지한다. Claude Code 플러그인 설치만으로 forge가 Pi에 등록되지는 않는다.

## 호스트와 파일 경로 해석

Pi 어댑터는 명시적인 세션 호스트 정보로 선택한다. 세션에 호스트 정보가 없다면 forge 호출 시 “현재 호스트는 Pi”라고 알려준다. `pi` 실행 파일의 존재나 다른 호스트 변수의 부재는 호스트 식별 근거가 아니다. 호스트를 알 수 없으면 일반 순차 실행 폴백을 유지한다.

Pi는 로드한 스킬의 파일 경로를 제공한다. Forge는 이 경로를 기준으로 동반 파일과 `core/`·`hosts/`·`scripts/`를 찾는다. 설치 루트는 `skills/fg-name/SKILL.md`의 스킬 디렉터리에서 두 단계 위다. `SKILL.md`만 복사하면 의존 파일이 사라지므로 체크아웃 전체를 유지한다. 설치 루트와 작업 프로젝트의 `.forge/` 상태 경로는 별개다. `PLUGIN_ROOT`나 `CLAUDE_PLUGIN_ROOT` 변수를 요구하거나 가정하지 않는다.

## 현재 지원 범위

| 능력 | Pi 상태 | 동작 |
| --- | --- | --- |
| 핵심 루프와 상태 유틸리티 | 지원 | 공통 스킬·검증 게이트·결정론 스크립트 사용 |
| 구조화 메뉴 (`structured_choice`) | `false` | 대화에 번호 선택지 출력 |
| 병렬 위임 (`spawn_parallel`) | `false` | 독립 작업도 순차 실행 |
| 역할 지정 위임 (`spawn_role`) | `false` | 현재 에이전트가 역할 지침 적용 |
| 플러그인 루트 변수 (`plugin_root`) | `false` | 로드한 스킬 경로에서 상대 경로 해석 |
| SessionStart 알림 (`session_start`) | `false` | 세션 진입 시 `/skill:fg-status` 호출 |
| 턴 경계 연속 실행 (`prevent_stop`) | `false` | `fg-next all`·`fg-loop`는 턴 범위 내 실행, 상태를 남기고 재호출로 재개 |
| 프로젝트 에이전트 카드 (`project_agents`) | `false` | `fg-agents` 카드의 Pi 네이티브 생성 미지원 |
| 영속 statusline (`status_display`) | `false` | `/skill:fg-status` 호출 |
| 브라우저 이벤트 재개 (`event_wake`) | `false` | `fg-showme` 화면에서 확인 후 메시지를 보내 재개 |
| `fg-loop` 토큰 상한 | 미지원 | `budget-tokens: none` 사용, 기존 Claude 트랜스크립트 계측기는 Pi 세션을 측정하지 못함 |

9개 플래그는 `hosts/pi/capabilities.json`과 일치한다. 이는 기본 어댑터의 보수적인 지원 선언이며 외부 Pi 확장이 구현할 수 있는 모든 기능의 한계를 뜻하지 않는다. 훅·subagent·자동 재개를 추가하는 확장은 설치하지 않는다. 숫자 토큰 상한이 요청됐으나 측정할 수 없다면 조용히 무시하지 않고 `blocked-health`에서 멈춰야 한다.

## 검증과 재개

검증을 다시 실행하려면 Pi가 설치된 환경에서 `node scripts/pi-host.test.mjs`를 실행한다. 다른 SDK 경로는 `FORGE_PI_PACKAGE_ROOT`로 지정할 수 있다. 이 검사는 모델 호출이나 사용자 설정 변경 없이 임시 설치 경로를 사용한다.

Pi 0.85.1의 실제 로더로 스킬 22개의 이름과 동반 파일 경로를 포함한 리소스 로딩을 확인한다. 이는 탐색·경로 해석 검증이며 인증된 모델로 모든 스킬을 끝까지 실행했다는 의미가 아니다. `npm run release:check`는 기존 호스트와 함께 어댑터 파일·9개 능력 키·해당 문서를 검증한다.

상태는 작업 저장소와 브랜치에 속한다. 다른 호스트에서 계획한 뒤 같은 작업 트리의 Pi에서 `/skill:fg-status`나 `/skill:fg-next`를 호출할 수 있다. 턴 범위 내 주행이 멈춘 뒤 저장된 목표는 `/skill:fg-loop`, 백로그는 `/skill:fg-next all`을 다시 호출해 재개한다.
