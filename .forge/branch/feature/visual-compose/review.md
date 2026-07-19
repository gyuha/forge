<!-- forge-slug: fg-visual-companion -->
# 적대적 리뷰 — superpowers Visual Companion vendoring (task 1)

리뷰일: 2026-07-20 · 방식: 6렌즈 병렬 팬아웃 + fix-needed 반박(refute) 패스(Dynamic Workflow, run `wf_670d1206-e28`)

## 한 줄 판정

fix-needed finding **13건**(반박 패스로 걸러진 것 없음 — 반박자 12개 중 다수가 세션 한도로 죽어 finding 유지, 살아남은 반박자는 전부 "finding 유지"로 확증). 심각도: **MAJOR 4건**(핵심은 사실상 1개 이슈를 4개 렌즈가 독립 확증) · MINOR 9건. fix-needed=false 기록용 4건 별도.

**모두 문서/스크립트 계약 수준의 이슈이며, 이 forge 리포 자체에서의 봉인·커밋을 막는 것은 없다**(이 리포는 `.forge/*`를 gitignore하므로 키 유출이 여기서 발생하지 않음). MAJOR들은 **배포/사용자 프로젝트 설치 시점의 제품 결함**이라 봉인 전보다 릴리스 전 fix-forward가 맞다.

## MAJOR — 세션 키가 임의 사용자 프로젝트에서 커밋될 수 있음 (4개 렌즈 독립 CONFIRMED: failure·assumptions·security·misuse)

- **증거**: 이 플러그인은 임의 사용자 프로젝트에서 도는데 forge의 어떤 스킬·스크립트도 그 프로젝트에 `.gitignore`를 만들지 않는다(skills/·scripts/ 전수 grep = 0). 그런데 `skills/fg-visual/SKILL.md:33,49`·`skills/fg-ask/SKILL.md:113`은 `.forge/visual/`이 "gitignored"라고 **무조건 단정**하고, `VISUAL.md:54`의 리마인드는 "정책이 다르면 상기"로 약화돼 있다. `start-server.sh:125-126`이 만드는 `.forge/visual/.last-token`은 `server.cjs`의 `initialToken()`이 **세션 간 재사용하는 영속 키**이고(회전 없음), `state/server-info`는 키 포함 전체 URL을 담는다. 이 키가 서버 주석 스스로 밝히듯 DNS rebinding 방어의 전부다. → gitignore 규칙 없는 프로젝트에서 사용자가 `git add -A && commit`하면 키가 이력에 영구 잔존, 이후 모든 세션에 유효.
- **where**: `skills/fg-visual/scripts/start-server.sh:125-126` · `skills/fg-visual/SKILL.md:33,49` · `skills/fg-ask/SKILL.md:113` · `skills/fg-visual/VISUAL.md:54`
- **권고 fix (fix-forward)**: `start-server.sh`가 세션 dir 생성 시 `${PROJECT_DIR}/.forge/visual/.gitignore`(내용 `*` 한 줄)를 self-drop하는 자기-무시 디렉터리 패턴 추가(cargo/npm 캐시 관례, 결정론적, 모든 프로젝트에서 동작). + `VISUAL.md`/`SKILL.md`/`fg-ask` 불릿의 "gitignored" 무조건 단정을 조건부로 완화하고 업스트림처럼 첫 기동 전 `git check-ignore` 무조건 확인으로 복원. **plan 결정 4("gitignore 수정 불필요")가 forge 리포 자신에서만 검증된 것을 임의 프로젝트로 일반화한 오류**가 근본 원인.

## MAJOR — docs/index.html 랜딩 페이지 19-스킬 동기화 누락 (requirements CONFIRMED)

- **증거**: `docs/index.html`에 stale 카운트 8곳(L7·111·119·121·197·235·479-480: "18개/eighteen 스킬", "14 유틸리티")이 남고 유틸리티 카드 그리드에 fg-visual 부재(grep=0). plan DoD가 "문서(19-스킬 카탈로그) 동기화"를 요구. run.md divergence 4(a)는 `forge-vs-loop-engineering.md`만 인지하고 index.html은 누락 — 같은 클래스의 미인지 drift.
- **where**: `docs/index.html:7,111,119,121,197,235,479-480`
- **권고 fix (fix-forward)**: 카운트 8곳을 19/15로 갱신(KO/EN span 쌍 동시, ADR-0027) + fg-visual 유틸리티 카드 추가. S5가 명시 파일 목록에 index.html을 안 넣은 게 원인 → 아래 run.md 4에 후속 후보로 추가.

## MAJOR — fg-visual stop이 복수/크래시 세션 매칭 시 무엇을 멈출지 미정의 (misuse CONFIRMED)

- **증거**: `SKILL.md:25-27`의 stop 탐색("server-info 존재·server-stopped 부재")은 단수 전제. 실측: 같은 프로젝트에 라이브 세션 2개 공존 가능(서버는 EADDRINUSE fallback으로 안전). SIGKILL로 죽은 서버는 server-info 잔존·server-stopped 부재라 이 규칙에 영구 매치 → 죽은 세션을 골라 "중지"를 오보고하는 동안 진짜 라이브 서버 잔존(4h 타임아웃이 백스톱).
- **권고 fix (fix-forward)**: stop 흐름을 "매칭되는 **모든** 세션에 stop-server.sh 실행"으로 명시(스크립트의 instance-id 검증이 stale을 fail-closed 처리하므로 전수 실행이 stale 정리까지 겸함, SKILL.md 한 줄).

## MINOR (CONFIRMED, fix-forward/문서 강화 후보)

1. **포트 fallback 시 VISUAL.md 재시작 지침이 거짓** — EADDRINUSE fallback이면 새 포트+새 토큰인데 `VISUAL.md:79`는 "같은 포트, 새 URL 불필요"로 단정. 재시작 후 port/url을 직전 server-info와 비교해 다르면 새 키 URL 재공유 + 진행 화면 re-push 지침 추가 필요.
2. **두 진입점이 라이브 세션 확인 없이 무조건 새 서버 기동** — fg-visual no-arg·fg-ask 수락 경로 모두. 기존 라이브 세션 재사용 단계 추가 권고.
3. **node 부재 프로젝트에서 오도성 에러** — 기동 실패 시 원인은 server.log에만. 제안/기동 전 `command -v node` 확인 + 실패 시 server.log 확인 지침 추가 권고.
4. **VISUAL.md stop 명령의 `$SESSION_DIR` unquoted** — 공백 경로에서 stop 조용히 실패. `"$SESSION_DIR"` 인용(한 줄).
5. **세션 키 영속 재사용 주의 미기재** — 키가 프로젝트 단위 영속이라 한 번 공유한 URL이 이후 세션에도 유효. VISUAL.md에 공유 주의 + `.last-token` 삭제로 회전하는 법 병기 권고.
6. **VISUAL.md 서버 생존 확인이 파일 존재뿐** — crash/reaper 미감지. `kill -0 $(cat server.pid)` 한 줄 추가 권고.
7. **"전역 예외 두 개" 드리프트가 단일 정의 문서에도** — `skills/fg-run/FORGE-ROOT.md:18-25,58`·`docs/state-contract.md:34`가 "두 개"로 열거를 닫아, `.forge/visual/`을 세 번째 전역으로 선언한 신규 문서와 모순. run.md 4(c)는 CLAUDE.md만 인지 → 범위 확장 필요.
8. **README.md 영문 fg-visual 행에 "once" 누락** — KO 행은 "1회 제안"인데 EN은 "offered just-in-time"로 once 빠짐. 이중언어 동기 규약 위반. `offered once, just-in-time`으로 수정(사소).
9. **fg-merge CONTEXT 파서 불일치 (선재 버그, 이 브랜치 머지엔 무영향)** — `forge-merge.sh`의 `ctx_terms`가 `## X`를 용어로 파싱하나 CONTEXT-FORMAT.md 정본은 `## Language` 아래 `**용어**:`. **검증 결과: 최상위 `.forge/CONTEXT.md`가 없어 GATE 2가 건너뛰어지므로 이 브랜치 머지엔 영향 없음.** 제 변경이 유발한 게 아닌 선재 불일치라 이 작업 범위 밖 — 별도 후속 후보로만 기록.

## 기록용 (fix-needed=false)

- **BRAINSTORM_* env가 superpowers와 이름공간 공유** — 전역 export한 사용자는 양쪽 서버 동작이 함께 바뀜(포트/토큰 핀·BRAINSTORM_OPEN 자동오픈 우회). run.md divergence 3의 "사용자 비가시 내부 식별자" 근거가 부정확 — env는 주변에서 읽히는 공유 인터페이스. 코드 변경 불요(업스트림 원형 유지), 회고에서 근거 문장 교정 권고.
- **VISUAL.md 이벤트 예시 timestamp 초/밀리초 불일치 + id 필드 생략** — 업스트림 승계, 기능 무영향.
- **stop-server.sh의 /tmp rm -rf 가드가 /tmp/../ 우회 가능** — 업스트림 동일, 호출자 신뢰 모델상 현행 유지 정당.

## 라우팅

- **코드/문서 결함(MAJOR 2건 + MINOR 다수)** → 사람 승인 후 fix-forward plan(`fg-visual-companion-fix`). 원 작업 봉인(fg-learn→fg-done) 후 fg-run.
- **plan 전제 오류(결정 4의 gitignore 일반화)** → 근본은 fix-forward로 충분(전제 전면 재설계 아님). 회고에 "검증은 설치 대상 환경 기준으로" 승급 후보.
- **선재 버그(fg-merge 파서)** → 이 작업 무관, 별도 후속.
