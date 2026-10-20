# 실행 기록 — fg-rules 프로젝트 규칙 생성

실행일: 2026-10-20
계획: `plan.md` · TDD off · eco/simple off

## 작업 단위 결과

- S1 규칙 후보 검토·선택 적용·재실행 스킬 — ✅ 구현, 합성 프로젝트 행동 평가 통과.
- S2 공통 규칙 경로·지도 경계·지침 연결 — ✅ 구현, git 추적과 Codex/Claude 새 세션 읽기 관측.
- S3 한영 문서·카탈로그·매니페스트 — ✅ 23개 스킬 동기화, 버전 변경 없음.
- S4 검증·독립 계약 리뷰 — ✅ 릴리스·문서·Pi·doctor 검사와 행동 평가 완료. 호스트별 한계는 아래에 구분.

## 구현

- `skills/fg-rules/SKILL.md`: 기본 전반 분석 및 주제 한정, 실제 코드 근거와 범위, 기존 지침 우선, 후보 검토 전 쓰기 금지, 채택한 추가·수정·삭제만 반영, 수동 수정 보존.
- `skills/fg-rules/CONNECTIONS.md`: 기존 지침 관계별 연결, 호스트 근거 확인, 연결 검증과 새 세션 로드 관측의 구분, 상위 ignore를 고려한 추적 확인.
- `.forge/rules/INDEX.md`와 주제 파일은 사용자가 대상 프로젝트에서 후보를 채택할 때 생성된다. 이번 Forge 저장소에 실제 프로젝트 규칙을 임의로 만들지 않았다.
- `FORGE-ROOT.md`와 `.gitignore`에 최상위 영속 규칙 경로를 반영했다. fg-map은 현재 구현 사실, fg-rules는 채택한 미래 작업 기준이다.
- fg-drop의 제외 대상 및 fg-merge의 비통합 대상을 함께 갱신했다. 규칙은 일반 git 파일이며 브랜치 작업 상태 이동 대상이 아니다.
- 매니페스트 세 파일, README 한영, 문서 사이트 관련 한영 쌍, 랜딩 카드, CLAUDE.md, handoff 제외 목록, Pi 로더 테스트를 갱신했다.
- 코드 지도 6개는 변경된 사실만 수정했다. 전체 재매핑·스탬프 갱신은 하지 않았다. fg-help는 실제 스킬을 탐색하므로 소스 변경이 필요 없었다.

## 계획과 실제 차이

- 독립 계약 리뷰가 “삭제와 대체를 함께 제안했지만 삭제만 채택한 경우”를 발견했다. 선택된 부분집합으로 색인·연결·ignore 변경을 다시 계산하고 새로 생긴 변경만 재검토하도록 보완했다. 원래 승인 경계를 구체화한 수정이며 기능 범위는 같다.
- 실제 참조 탐색에서 `docs/en/index.md`의 스킬 수와 fg-drop/fg-merge의 공통 경로 설명도 갱신했다.
- 새 스킬의 Host contract 줄을 doctor가 읽는 형태에 맞췄다. 교차 절 인용이 없는 제목은 번호 없이 표현했다. 실행 스크립트 자체는 바꾸지 않았다.
- 문서 의존성은 lockfile 기준 `npm ci --ignore-scripts`로 설치했다. 샌드박스 네트워크 제한으로 첫 시도가 실패해 권한 검토를 거쳐 재시도했다. package.json/lockfile 변경 없음.
- 스크린샷 캡처가 CDP timeout으로 실패했다. 같은 탭에서 DOM·실제 자산 응답·테마 상태·계산된 명암비를 확인했다. 픽셀 스크린샷 QA를 완료했다고 주장하지 않는다.
- 커밋·push·이슈 댓글·봉인은 실행하지 않았다.

## 완료 정의: 사전 → 실행 후

| 항목 | 사전 | 실행 후 |
| --- | --- | --- |
| `test -s skills/fg-rules/SKILL.md` | exit 1, 파일 없음 | exit 0, 새 스킬 존재 |
| `npm run release:check` | exit 0 | exit 0, forge 0.9.6 계약 유지 |
| `npm run docs:build` | exit 127, VitePress 미설치 | 의존성 설치 후 exit 0, 최종 빌드 3.63초 |

릴리스 검사는 처음부터 통과한 회귀 가드다. 새 스킬 존재 확인은 생성 여부만 검증하며, 실제 동작은 아래 별도 평가로 확인했다.

추가 검사:

- `node scripts/pi-host.test.mjs`: Pi 0.85.1, 23개 스킬·로컬 참조·외부 cwd·상태 fallback 통과. 새 `fg-rules` 로딩도 명시 확인.
- `node scripts/forge-doctor.js`, `bash scripts/forge-doctor.sh`: 최종 모두 0 errors / 0 warnings / 0 info.
- skill-creator의 `quick_validate.py skills/fg-rules`: valid.
- `git diff --check`: 통과.
- README 두 파일 및 docs/skills 한영 카탈로그: 실제 스킬 집합과 각각 23/23 일치.
- skills/state-contract/git-workflow/pi/forge-vs-loop-engineering/index 한영 문서의 헤딩 깊이·순서 구조 일치.
- 매니페스트 버전 네 값은 모두 원래 0.9.6 유지.
- 문서 빌드의 gitignore 하이라이트 fallback·큰 chunk 경고는 남아 있으며 빌드 실패는 아니다.

## 행동 평가: A–F

독립 에이전트가 `/private/tmp/forge-rules-eval-f6hftth2/`의 합성 프로젝트를 생성한 뒤 새 스킬을 읽고 실제 파일을 분석했다. 부모에게 구체적 후보 패치를 제시하고, 시험용 명시 승인을 받은 뒤 적용했다. 시험 승인은 실제 사용자 프로젝트 규칙의 채택과 구분했다.

| 시나리오 | 사전 | 관찰된 결과 |
| --- | --- | --- |
| A 신규 생성 | 스킬 부재 | initial에서 근거 있는 공용 fixture 규칙 제안. 승인 전 파일 해시 동일. 정확히 승인한 규칙·색인·CLAUDE 연결·ignore 4개 경로만 변경 |
| B 기존 지침 충돌 | 스킬 부재 | nested 정책과 충돌하는 후보는 보류. 기존 지침 유지. none에서는 파일 해시 동일·새 규칙 디렉터리 없음 |
| C 재실행·직접 수정 | 스킬 부재 | rerun에서 적용 범위 수정 3개 경로만 반영. 수동 메모·API 규칙·기존 연결 보존. 변경 없는 재실행은 쓰기 0 |
| D 주제 한정 | 스킬 부재 | 테스트 주제 변경만 반영, API 규칙 등 다른 주제의 해시 동일 |
| E 지도 독립 | 스킬 부재 | initial은 지도 없음. rerun의 오래된 지도는 실제 코드와 대조, 지도 해시 유지 |
| F 읽기 연결 | 스킬 부재 | AGENTS→CLAUDE 위임, 지침 없음, 독립된 두 지침, 중첩 지침을 각각 확인. 기존 원문 보존·순환 없음·규칙 본문 복제 없음 |

추가 경계:

- 마지막 규칙 삭제: 별도 deletion 복사본에 승인된 규칙·색인 삭제와 연결 정리를 적용해 최초 setup 파일 해시로 복원. dangling 연결 0.
- 부분 채택: 삭제+대체 제안에서 삭제만 선택하면 새 정리안을 검토해야 하므로 종속 변경을 보류, 쓰기 0.
- 혼용 패턴: camelCase/snake_case 1:1은 근거 부족으로 보류. Prettier가 이미 강제한 세미콜론·따옴표는 규칙으로 중복하지 않음. 해당 fixture 해시 유지.
- B의 기존 정책을 명시적으로 뒤집는 분기는 계약 리뷰로 확인했고, 별도 정책 변경 행동 시험은 하지 않았다. 동시 외부 수정 감지도 계약 리뷰 수준이다.

원시 증거: `REPORT.md`, `evidence.json`, `setup-manifest.json`, `after-manifest.json`이 위 임시 경로에 있다. 초기 스냅샷 SHA256은 initial `079563fbac8597e9ce80818aa21584e0cbb7e5a17fc971238ed22552753d4cb5`, rerun `a62c449fe07e408d74a2900477cfed881194b30d2035efa291098ff2a2865c6f`였다. 임시 파일은 영속 검증 스위트가 아니며, 핵심 결과를 이 기록에 보존한다.

## G: 추적과 새 일반 세션 로딩

- main/feature/eval 두 브랜치에서 각 규칙 파일과 색인에 대한 `git check-ignore --no-index -q` 결과 exit 1(제외 아님), 무관한 `.forge/plan.md`는 exit 0(제외 유지). 부모 디렉터리 `.forge/` 제외를 `.forge/*`와 좁은 예외로 바꾼 실제 결과다.
- **Codex CLI 0.159.2**: 생성 결과를 `/private/tmp/forge-rules-fresh-codex`에 복사해 새 ephemeral 세션에서 “Add a small tests/c.test.ts checking the user name, following this project”만 요청했다. fg-rules 호출·규칙 본문 주입 없음. 완료 이벤트에서 CLAUDE.md, `.forge/rules/INDEX.md`, `.forge/rules/testing.md`의 읽기를 관측했고 새 테스트가 `buildUser`를 사용했다. fixture에 테스트 런너가 없어 생성 테스트 실행은 하지 않았다.
- **Claude Code 2.1.303**: 별도 `/private/tmp/forge-rules-fresh-claude`에서 새 print 세션으로 같은 종류의 일반 테스트 작성안을 요청했다. Read/Glob/Grep만 허용, 사용자 설정·MCP는 분리했다. 실제 Read 호출로 INDEX.md와 testing.md를 확인했고 공용 fixture를 사용한 코드를 제안했다. 파일 쓰기 없음.
- Codex 원시 이벤트: `/private/tmp/forge-rules-fresh-codex-events.jsonl`; Claude 원시 이벤트: `/private/tmp/forge-rules-fresh-claude-events.jsonl`. 두 세션 모두 exit 0. 해당 세션 결과를 영구적 준수 보장으로 해석하지 않는다.
- 공식 읽기 메커니즘 근거도 확인했다: https://learn.chatgpt.com/docs/agent-configuration/agents-md 및 https://code.claude.com/docs/en/memory (2026-10-20 열람).
- Pi는 스킬 로더만 검증했다. Pi/opencode의 일반 새 세션 규칙 읽기는 관측하지 않았으며 스킬은 미검증 연결을 미검증으로 보고하도록 한다. 파일명만으로 호스트 지원을 가정하지 않는다.

## 문서 화면

ego-browser의 동일 검증 공간에서 한영 skills의 fg-rules 절, state-contract 규칙 경로, 랜딩의 새 카드와 KO→EN 전환을 확인했다.

- 검증 페이지의 기록된 자산 요청 오류 0, 문서 로고 이미지 로드 정상, 랜딩 배경·아이콘 응답 200.
- skills 다크모드 전환 확인, 가로 overflow 없음.
- state-contract 다크모드 Mermaid 20개 노드의 계산된 라벨/배경 명암비 최소 10.17:1(요구 3:1 이상).
- 새 스킬의 외부 공식 문서 링크 두 개는 실제 열람했다. 이번에 새로 추가한 외부 링크 외의 기존 문서 링크 전체를 재감사하지는 않았다.
- 검증 공간과 로컬 서버는 종료했다. Ego Lite 업데이트 알림만 보고했으며 업데이트하지 않았다.

## 리뷰와 다음 단계

독립 계약 리뷰의 부분 채택 지적 1건을 수정했고 최종 리뷰에서 추가 결함은 없었다. 전체 소프트웨어 실행을 강제하는 기능이 아니라 에이전트가 수행하는 검토형 스킬이다. 합성 행동 평가와 두 호스트의 실제 새 세션 읽기를 근거로 검증을 완료하며, 실행을 반복할 때도 사용자 채택 절차가 유지돼야 한다.

계획과 실제 차이는 작지만 새 기능의 규칙/지도 경계와 부분 채택 학습이 있으므로 기본 다음 단계는 fg-learn이다.

## 리뷰 후 사용자 요청 보완 — 2026-10-20

확정 결함은 없었으나 “리뷰 사항 수정” 요청에 따라 `SKILL.md`의 연결 복구 경로를 명시했다. 규칙 본문 변경 없이 읽기 연결만 독립 후보로 검토·채택할 수 있고, 후보 없음 판정은 연결 후보까지 고려한 뒤 수행한다. 변경 없는 규칙과 색인은 그대로 보존한다.

보완 후 skill-creator 형식 검사, Node doctor(0 errors / 0 warnings), Pi 23개 스킬 로딩 및 `git diff --check`가 통과했다. 문서 사이트·매니페스트 변경은 없으며 새 호스트 실행 시험은 반복하지 않았다. 계획의 승인·보존 범위를 바꾸지 않는 문구 명확화다.
