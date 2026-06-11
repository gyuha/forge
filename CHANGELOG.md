# Changelog

## [0.4.5] - 2026-06-11

### Changed
- **루프 핸드오프 전환을 진술형으로 통일 — 체이닝은 fg-next 전담 ([ADR-0015](./.forge/adr/0015-fg-run-handoff-menu-others-stated.md)).** 각 스킬 끝의 "진행할까요?" 전환 허락 질문을 걷어내고 다음 단계·트리거를 알린 뒤 멈추도록 바꿨다(드리프트 교정 — CLAUDE.md 규약은 원래 "전한다"였다). 예외는 분기가 가장 많은 `fg-run` 종료뿐 — 3지 명시 메뉴(회고 / 바로 종료=skip+봉인 / 프롬프트로 나가기, "바로 종료"는 저-divergence에서만)를 유지한다. `fg-ask`·`fg-learn`·`fg-done`·`fg-status` 핸드오프를 진술형으로, `fg-ask`의 실행모드 질문(워크플로우 vs 직접)을 제거(fg-run이 자체 결정), README 양쪽 "Overall flow" 서술을 함께 갱신.
- **전 스킬 `Language` 지시문 강화.** "always converse in the user's language"를, 사용자에게 출력하는 모든 메시지(질문·메뉴·상태/다음단계·핸드오프)를 사용자 언어로 쓰고 이 파일의 영문을 그대로 복창(mirror)하지 말 것으로 13개 스킬 전부 명문화.

## [0.4.4] - 2026-06-11

### Added
- **신규 `fg-eco` 스킬 — 위임 서브에이전트 모델 티어링 토글(루프 밖, 12번째 스킬).** `.forge/config.json`의 `eco` 키를 켜고 끈다(`fg-eco on|off`, 인자 없으면 상태 표시+켜기/끄기 선택). 켜면 `fg-run`이 Dynamic Workflow/실행 서브에이전트 모델을 **sonnet으로 캡** — 내리기만 하고(티어 업그레이드 금지) 사용자의 명시적 모델 지시가 우선하며, 메인 세션 모델은 건드리지 않는다(스킬은 세션 모델을 바꿀 수 없음 — 설계·완료는 사용자가 고른 모델 그대로, 강력=메인 세션·일반=위임 실행의 2단 구조). fg-map은 의도적으로 범위 밖(지도 품질=그릴링 연료) ([ADR-0014](./.forge/adr/0014-fg-eco-subagent-model-tiering.md)).

### Changed
- README 양쪽의 `.forge/` 디렉터리 트리에 누락 항목 보충: `config.json`(영속 — 3키 `tdd`·`eco`·`defaultBranch`, 전역)·`quick/LOG.md`(휘발). fg-tdd·FORGE-ROOT의 config 키 서술도 3키 체제로 갱신.

## [0.4.3] - 2026-06-11

### Changed
- **브랜치 영속 연료 읽기 오버레이 (ADR-0011 개정).** 비-기본 브랜치의 그릴링 연료(CONTEXT.md·adr/·retro/) 읽기가 최상위 `.forge/` 베이스 위에 브랜치 루트를 오버레이한다(브랜치 우선) — 갓 만든 브랜치가 main의 용어·결정을 못 보던 실명 문제 해소. 쓰기·ADR 채번은 브랜치 루트 그대로(단일 정의: `skills/fg-run/FORGE-ROOT.md`).
- **`fg-merge` 견고화** — ADR 재부여를 "전체 old→new 맵 선구축 → placeholder 일괄 치환, incoming 문서만" 으로 바꿔 순차 치환 캐스케이드/타깃 참조 오염 차단; 채번이 `retired/` 포함; 브랜치 backlog plan을 통합 목록에 추가(slug `-2`·task 번호 재부여)하고 halt 게이트를 진짜 in-flight 상태(active slot·executed/·pending quick 항목)로 축소; 통합 결과 커밋 리마인드 추가.
- **`fg-done` 봉인 절차 견고화** — STATUS 마감을 이동 전에 수행(close-out-before-move)하고, 중단된 봉인(half-seal)을 빈 상태 선언 전에 감지·완결; 검증·회고 게이트의 per-task 평가 명시(Run-all fail-stop 혼합 상태에서 통과 작업은 계속 봉인).
- **`fg-run` unpark 전제 구체화** — 활성 슬롯 점유 시 unpark하지 않고 대기, 슬롯이 비면 재진입 시 자동으로 최상위 회수 후보로 표면화.

### Fixed
- ADR 채번이 은퇴(`retired/`) 번호를 재사용할 수 있던 구멍(ADR-FORMAT·fg-merge 채번에 retired/ 포함, never-reuse 불변식 보존).
- `skills/fg-run/FORGE-ROOT.md`의 stale "fg-merge is not built yet" 블록 제거(수동 통합 지시가 7개 스킬에 전파되던 문제).
- README "모든 `.forge/...` 경로가 브랜치 루트로 해석" 과잉 진술에 전역 예외 2개(`config.json`·`codebase/`) 명시(README 양쪽·CLAUDE.md).
- fg-done의 봉인 가능 값을 fg-run과 동일한 `yes (<evidence>)` 형식으로 정렬, STATUS.md 템플릿 모양 통일(생산자 fg-run의 plain `key: value` 기준).
- fg-ask·fg-done·fg-quick·fg-learn의 "`.forge/` 통째 untracked" 단정을 브랜치별 서술로 한정.
- Run-all failed 파킹 provenance 모순(fg-run — Run all은 failed를 파킹하지 않음), fg-learn의 "fg-run은 executed/를 안 읽음" 오서술, fg-status 3b 상태의 스킬·트리거 누락(retro 여부로 fg-learn/fg-done 분기) 등 상태 머신 서술 정합.
- TDD 질문 조건 오서술(켜짐 여부와 무관하게 작업마다 질문, config는 기본 답) — fg-tdd·README 양쪽; fg-tdd config 키 2개(tdd·defaultBranch) 반영.
- README mermaid의 유령 'chores' 엣지 제거, README.ko 누락 트리거 3건 보충, fg-next "verify→done 확장" 절 영문판 보강.
- 회고 "per session" → "per task" 정정(RETRO-FORMAT·fg-learn), part-plan 정렬을 `part: N/M` 숫자 기준으로(10+ 파트 슬러그 오정렬), CLAUDE.md 화이트리스트에 `!.forge/config.json` 추가.
- ADR-0010에 개정 노트(기본 fg-next의 confirm-then-delegate 폐지를 역사로 명시), 코드베이스 지도(`.forge/codebase/`) 갱신.

## [0.4.2] - 2026-06-10

### Changed
- **`fg-run` — Run-all 절차를 `skills/fg-run/RUN-ALL.md`로 분리(progressive disclosure).** 흔한 호출 경로(1작업·단일선택)는 Run-all을 로드하지 않아 fg-run 본문이 ~12% 가벼워지고(28061→24579자), "Run all"을 실제로 고를 때만 그 파일을 참조 로드한다. **동작 불변** — 추출은 재배치일 뿐, rule census로 행동 규칙 19/19가 (SKILL ∪ RUN-ALL)에 보존됨을 입증.

### Added
- **`fg-done` — 봉인 후 codebase 지도 stale 감지 → `fg-map` 제안.** 작업이 `.forge/codebase/`가 서술하는 프로젝트 파일(`.forge/` 밖)을 바꿨고 지도가 존재하면, 봉인 wrap-up에서 `fg-map`을 **제안**한다(자동 실행 아님 — fg-map은 4-agent라 on-demand, ADR-0006의 offer-not-auto 선례). doc-only 작업이나 지도 부재 시엔 침묵. 봉인 가드·순서는 불변.

## [0.4.1] - 2026-06-09

### Added
- **`fg-ask` 진입 시 미봉인 이전 작업 알림** — 새 작업 그릴링을 시작할 때 이전 작업이 `status: executed`인데 봉인 안 됨(활성 `run.md` 미봉인 또는 `executed/` 파킹)이면, 한 번만 "먼저 마치기(`fg-next`) / 새 작업 계속"을 묻는다. 미완이 없으면 침묵하고 즉시 그릴링(평소 지연 0). 이 싼 체크는 retro 피드백·codebase 지도 읽기보다 먼저 수행. 미실행 plan(awaiting-run)은 트리거하지 않고, 백로그 공존 설계는 불변. learn-vs-done 판정은 `fg-next`에 위임(복제 없음).

## [0.4.0] - 2026-06-09

### Added
- **신규 `fg-cleanup` 스킬 — 오래된/대체된 ADR 은퇴 유틸리티(루프 밖).** 후보를 근거와 함께 제시하고 사람이 승인하면 각 ADR을 `.forge/adr/retired/<NNNN>-slug.md`로 이동(번호 불변·재사용 없음·삭제 없음, supersede/retire 마킹). `fg-ask`는 `retired/`를 정답소스로 안 읽어 은퇴분이 그릴링 연료에서 빠진다. 스킬 11개로 ([ADR-0012](./.forge/adr/0012-fg-cleanup-renamed-to-fg-done-cleanup-retires-adrs.md)).
- **`fg-merge` 스킬 — 브랜치 격리 통합 유틸리티(루프 밖).** `git merge` 뒤 `.forge/branch/<branch>/`를 `.forge/`로 통합 — ADR 재번호+교차참조 갱신·retro 이동(충돌 시 `-2`)·CONTEXT 용어 병합·done 합침·브랜치 폴더 제거. 기계적 자동, 진짜 충돌(용어 재정의·ADR 모순)에서만 멈춤. 대상 디렉터리는 lazy 생성. git은 직접 안 돌림 ([ADR-0011](./.forge/adr/0011-branch-isolated-forge-root.md)).
- **브랜치별 forge 루트 격리** — 비-기본 브랜치는 forge 루트 전체를 `.forge/branch/<branch>/`에서 운영(git 추적, 네임스페이스 격리로 병렬 브랜치 충돌 차단). 기본 브랜치는 종전대로 `.forge/`. 해석 규칙은 `skills/fg-run/FORGE-ROOT.md` 한 곳 정의 ([ADR-0011](./.forge/adr/0011-branch-isolated-forge-root.md)).
- **`fg-next all` 무인 완주(/goal 페어링) 패턴 문서화** — 하니스 `/goal`과 짝지어 백로그가 빌 때까지 자동 재개. 조건은 "완료 OR 사람 필요 벽"으로 적어 안전 벽에서 풀리게(스킬은 /goal 자동 발동 불가, 사용자가 침).

### Changed
- **봉인 ④단계를 `fg-cleanup` → `fg-done`으로 개명**하고, 루프 ④단계의 *단어*도 `cleanup`/`정리` → `done`/`완료`로 통일 — 흐름은 `질의·계획 → 실행 → 회고 → 완료`. "cleanup"은 이제 ADR 은퇴 스킬(`fg-cleanup`) 전용. fg-done 트리거 `작업 완료`·`봉인`(옛 `작업 정리`·`forge complete` alias) ([ADR-0012](./.forge/adr/0012-fg-cleanup-renamed-to-fg-done-cleanup-retires-adrs.md)).
- **`fg-next all`이 회고를 divergence와 무관하게 항상 자동 skip** — 고-divergence 회고에서 멈추던 것을 제거(forge-meta 작업이 거의 고-div라 매번 멈춰 모멘텀이 사라지던 문제). 멈춤은 `verified: failed`·미검증·진짜 fork·빈 상태 4개. 학습은 run.md에 보존, 승급은 추후 사람 ([ADR-0010](./.forge/adr/0010-fg-next-all-momentum-mode.md) 개정).

### Fixed
- `fg-merge`가 대상 디렉터리(`adr/`/`retro/`/`done/`)가 없을 때 lazy 생성하도록 명시 — 라이프사이클 e2e 검증(샌드박스)에서 발견·보강(없으면 folded done 이력이 유실되던 갭).

## [0.3.4] - 2026-06-08

### Fixed
- **`fg-next` 기본 모드가 진행하지 않던 문제** — 다음 단계를 알려주고 멈춰 `fg-status`처럼 행동하던 것을, 다음 단계를 한 줄로 알린 뒤 **곧바로 그 스킬을 호출(진행)**하도록 수정. 재실행 안전성은 `fg-run`·`fg-cleanup`의 기존 가드가 보장하므로 별도 확인 게이트가 불필요. 멈추는 경우는 입력이 필요한 진짜 fork·빈 상태로 한정. `all` 모드의 시작 1회 확인은 그대로 유지.

## [0.3.3] - 2026-06-07

### Fixed
- README(양 언어) 헤더가 루프 밖 스킬을 `fg-map` 하나만 세어 표·본문과 모순되던 것을 정정 — "nine fg-* skills — four loop + five utilities(`fg-map`·`fg-quick`·`fg-status`·`fg-next`·`fg-tdd`)".

## [0.3.2] - 2026-06-07

### Added
- **`fg-next` 스킬** — fg-status의 다음-단계 상태 머신을 참조해 다음 한 수를 도출하고, 한 번 확인 후 그 스킬을 실행하는 루프-밖 오케스트레이터. fg-status는 보고만 하고 fg-next는 행동까지 한다(기본 one-shot). 차갑게 재진입하는 진입점("어디까지 했는지 기억 안 날 때 다음 걸 해줘").
- **`fg-next all` 모멘텀 모드** (ADR-0010) — 백로그가 빌 때까지 선형 기계적 단계(run·n/a/자동검증 verify·저-div 회고 skip·cleanup·다음 승격)를 추천값으로 자동 진행하고, 대화의 벽(실패/검증불가 UAT·고-divergence 회고·진짜 fork·빈 상태)에서 멈춘다. `fg-run` "Run all"의 verify→cleanup 확장 상위집합.

### Changed
- **증거-우선 검증** (ADR-0009 보강) — `fg-run` 핸드오프 UAT가 `verified: yes`를 기록할 때 "어떻게 확인했는지"를 한 줄 증거로 동반한다(`yes (<evidence>)`, 예: `yes (npm test → 42 passing)`). TDD 모드에선 통과한 슬라이스 테스트가 곧 그 증거. 전면 덤프가 아닌 한 줄 경량. `n/a`/`skipped`/`failed`는 불변.

## [0.3.1] - 2026-06-05

### Added
- **봉인 전 검증(UAT) 게이트** (ADR-0009) — 회고 완료만으로 봉인하던 루프에 검증 게이트를 추가해, 한 번도 동작 확인되지 않은 작업이 `done`으로 봉인되는 것을 막는다. 루프 순서는 run → verify → learn → cleanup.
  - `fg-run` — 핸드오프에서 plan 목표/Definition of Done에 대고 UAT를 수행하고 결과를 STATUS `verified:` 필드에 기록(`yes`/`skipped`/`n/a`/`pending`/`failed`).
  - `fg-cleanup` — `verified:`가 봉인 가능 값(`yes`/`skipped`/`n/a`)이 아니면 봉인 차단(no-seal-without-verification), 회고 게이트보다 먼저 확인.
  - `fg-learn` — 검증 통과 시에만 회고 진입.
  - `fg-status` — `done`의 누락 `verified`는 legacy(pre-ADR-0009)로 해석, 활성/파킹의 `pending`과 의미 구분.

## [0.3.0] - 2026-06-05

### Added
- **선택적 TDD 모드 + forge 첫 설정 표면** (3 part로 분할 구현, ADR-0008):
  - `.forge/config.json` — git 추적 영속 설정 파일(`.gitignore` 화이트리스트). forge 첫 "설정" 상태 표면.
  - `fg-tdd` 스킬 — `fg-tdd on|off`로 TDD 모드 토글(인자 없으면 상태 표시), 루프 밖 유틸. 기본값 **off**.
  - `fg-ask` — 그릴링 시작 때 config 기본값으로 "이 작업 TDD로?"를 묻고 plan에 `<!-- tdd: on|off -->` 마커 기록.
  - `fg-run` — plan의 tdd가 on이면 test-first로 실행(슬라이스별 실패 테스트→구현→통과, 완료 기준에 테스트 포함). 외부 TDD 스킬은 선택적, 하드 의존 없음.

## [0.2.11] - 2026-06-05

### Added
- `fg-run`에 **조건부 코드 리뷰** — §3에서 계획-검증(항상)과 코드 품질 리뷰(조건부)를 구분. 변경이 위험 영역(인증·데이터·공개 API·마이그레이션)이거나 클 때만 워크플로우에 리뷰/adversarial-verify 단계(diff를 버그·보안·품질로 점검)를 포함(사소하면 생략). 워크플로우 자체 서브에이전트로 구성(외부 의존 없음), findings는 수정→재검증·잔여 중대건은 run.md 기록. 결정 기록 `.forge/adr/0007-fg-run-conditional-code-review.md`

## [0.2.10] - 2026-06-05

### Changed
- `fg-ask` 핸드오프가 fg-run 안내 직전에 **이번 그릴링이 만든/건드린 문서 경로를 나열** — 백로그 plan(항상) + 갱신한 CONTEXT.md·추가한 ADR(있으면). 사용자가 실행 전 검토하도록 안내

## [0.2.9] - 2026-06-05

### Added
- `fg-ask`에 **조건부 외부 리서치 참고 연료** 단계 — 작업이 리포에 없는 외부 지식(낯선 라이브러리·외부 API·미지 도메인)에 의존하거나 사용자가 요청할 때, 가용한 deep research 역량(예: deep-research 스킬)으로 근거를 모아 그릴링에 보탬. 선택적(없으면 조용히 건너뜀, 하드 의존 없음)·자동 실행 없음(먼저 제안)·그릴링 대체 아님(웹은 참고, 정답 원천은 CONTEXT/ADR). 결정 기록 `.forge/adr/0006-fg-ask-optional-deep-research-fuel.md`

## [0.2.8] - 2026-06-05

### Changed
- **작업에 고정 번호(#N) 부여** — fg-ask가 plan 생성 시 단조증가 번호를 `<!-- task: N -->` 마커로 매기고(max+1, forge-slug처럼 영속), fg-status No. 컬럼이 이 고정 번호를 표시, fg-run 메뉴가 `#N`을 보이고 번호로 지목·선택. priority는 정렬, 번호는 식별/지목용. 0.2.7의 위치 기반 행번호를 대체. 앞으로 생성분만 부여(기존 작업은 `—`), fg-quick 제외. 결정 기록 `.forge/adr/0005-monotonic-task-numbers.md`

## [0.2.7] - 2026-06-05

### Changed
- `fg-status` 표에 **순번(No.) 컬럼** 추가 — 섹션별 1부터 표시 순서 행 번호. 미완료 작업은 priority→part→slug 순(= #1이 fg-run이 다음 제시할 작업), done은 최근순. 새 순서 마커는 만들지 않음(순서는 기존 priority/part가 담당, 번호는 표시용)

## [0.2.6] - 2026-06-05

### Changed
- **큰 작업을 순서 힌트 가진 part-plan들로 분할** — fg-ask가 합의된 작업이 독립 배포/검증/봉인 가능한 덩어리로 분해되면(판단 기반) 거대 plan 대신 여러 part-plan(`<base>-NofM` 슬러그 + `<!-- part: N/M -->` 마커)으로 백로그에 적재. fg-run은 part를 순서대로 `(part N/M)` 라벨로 보여주고 하나씩 순차 완성을 권장(소프트 순서 — 하드 의존 아님, 각 part 독립 봉인 가능). PLAN-FORMAT 분할 규칙에 크기/분해 트리거 추가. 결정 기록 `.forge/adr/0004-split-oversized-tasks-into-ordered-parts.md`

## [0.2.5] - 2026-06-04

### Changed
- 백로그에 미실행 plan이 여럿일 때 `fg-run` 선택 메뉴를 **우선순위순(`high → medium → low`)으로 정렬** — plan의 `<!-- priority: high|medium|low -->` 마커 기준(무표기=medium, 동순위 slug 알파벳). "모두 실행" 순차 순서도 동일하게 따름. 자동 선택은 도입하지 않음(메뉴 선택 유지). PLAN-FORMAT에 priority 마커 정의, fg-ask가 그릴링 중 설정 가능

### Added
- `.forge/codebase/` 코드베이스 지도 7개 문서(fg-map 산출 — STACK·INTEGRATIONS·ARCHITECTURE·STRUCTURE·CONVENTIONS·TESTING·CONCERNS)

## [0.2.4] - 2026-06-04

### Changed
- `fg-status` 출력을 `Date | Task | Stage | Retro` 4열 테이블로 정리 — 단계는 현재 단계 하나만(버킷 매핑), 회고는 O/X(완료 O · 건너뜀 X · 미정 —). 직전의 파이프라인 배지를 대체
- `fg-status` SKILL.md 본문을 영문으로 통일(출력 라벨·테이블 컬럼은 canonical English, 출력은 사용자 언어로 렌더) — 스킬 본문 영문 작성 규약에 맞춤

## [0.2.3] - 2026-06-04

### Changed
- `fg-status` 출력에 **작업별 `ask · run · learn · done` 단계 배지** 추가 — 각 작업이 4단계 루프에서 어디까지 왔는지 한 줄로 표시(✓ 통과 · ▶ 현재 · — 미도달 · —(skip) 건너뜀). 버킷 위치 + STATUS `retro` 필드에서만 도출(읽기 전용 유지)

## [0.2.2] - 2026-06-04

### Added
- `fg-status` 스킬 — **루프 밖 읽기 전용 상태 리포터**. `.forge/`를 조사해 진행 중(active·backlog·executed)은 상세, 완료·빠른작업은 요약으로 출력하고, 상태 머신으로 지금 필요한 다음 단계 하나와 트리거를 표시한다. 아무 파일도 쓰지 않고 자동 실행도 하지 않는다. 트리거: "forge status", "어디까지 했지"

## [0.2.1] - 2026-06-04

### Added
- `fg-quick` 스킬 — 사소한 작업용 **루프 밖 경량 차선**. 그릴링은 유지(가볍게)하되 형식 산출물(ADR·plan·run·STATUS·done·회고)을 만들지 않고 `.forge/quick/LOG.md`에 한 줄만 기록한 뒤 직접 실행. 메인 루프의 활성 슬롯·backlog·done과 격리되며, 비-trivial로 드러나면 fg-ask로 bail. 결정 기록 `.forge/adr/0003-fg-quick-lightweight-lane.md`. 트리거: "forge quick", "이거 빨리 해줘"

## [0.2.0] - 2026-06-04

### Changed
- `fg-execute` 스킬을 **`fg-run`으로 개명** — 호출은 `/forge:fg-run`, 주 트리거는 "forge run"("forge execute"는 legacy alias로 유지). 디렉터리(`skills/fg-run/`, `PLAN-FORMAT.md` 동반)·식별자·전 문서의 참조를 fg-run으로 통일. 루프 스테이지 라벨 "② Execute"는 유지(skill id ≠ stage 라벨, fg-learn/Retro 선례와 동일). 동작·상태 계약은 불변

### Added
- 회고(fg-learn)를 **저-divergence 사소한 작업에 한해 건너뛸 수 있는 경로** — fg-run 핸드오프가 명시 선택지로 제시(자동 아님, 고-divergence 미제시), STATUS.md `retro: skipped (사유)` 기록, fg-cleanup이 봉인 가드 통과로 인정. plan의 `<!-- retro-hint: optional -->`는 비구속 힌트. 결정 기록 `.forge/adr/0002-optional-retro-skip.md`

### Fixed
- fg-ask verbatim 본문의 ADR·글로서리 경로(`docs/adr/`·루트 `CONTEXT.md`)를 forge `.forge/` 계약(`​.forge/adr/`·`.forge/CONTEXT.md`)에 맞춰 정합 — ADR이 추적·참조 안 되는 위치에 생성되던 버그
- README 스킬 카탈로그·태그라인·Mermaid를 실제 스킬 동작(fg-map 포함 5개, fg-run 조건부 메뉴·STATUS 출력)과 동기화

## [0.1.2] - 2026-06-04

### Added
- `fg-map` 스킬 — 코드베이스를 4개 병렬 서브에이전트로 분석해 `.forge/codebase/`에 7개 구조 문서(STACK·INTEGRATIONS·ARCHITECTURE·STRUCTURE·CONVENTIONS·TESTING·CONCERNS)를 직접 작성하는 루프 밖 온디맨드 유틸리티. 에이전트는 확인만 반환해 context rot을 줄이고, `last_mapped_commit` 스탬프로 신선도를 표시. fg-ask가 그릴링 전 이 지도를 읽음
- 결정 기록 `.forge/adr/0001-docs-into-forge.md`

### Changed
- 모든 forge 문서를 `.forge/` 단일 디렉터리 하위로 통합 — 영속 문서(`CONTEXT.md`·`adr/`·`retro/`·`codebase/`)는 `docs/`·루트에서 `.forge/` 하위로 이동
- `.gitignore`를 화이트리스트 패턴으로 교체 — `.forge/`를 기본 제외하고 영속 문서 4종만 추적, 휘발 상태(plan/run/STATUS/backlog/executed/done)는 제외
- 5개 스킬·4개 형식 문서·CLAUDE.md·README(영/한)의 경로 참조를 새 구조로 갱신 (멀티 컨텍스트는 코드 옆 배치 유지로 예외)
- worktree 폴더를 `.gitignore`에 추가

## [0.1.1] - 2026-06-04

### Changed
- `fg-complete`를 `fg-cleanup`으로 개명, 4단계 명칭을 "완료"에서 "정리"로 통일 (기존 "forge complete" 트리거는 alias로 유지)
- 매니페스트 설명 영문화 — `plugin.json`·`marketplace.json`의 description을 영문으로 통일
- README 태그라인을 4단계 표기(`ask·plan → execute → retro → cleanup`)로 정리, `fg-plan` 통합 문구 명확화
- README Install 섹션 보강 — 로컬 클론 설치, main 브랜치 노트, 업데이트·제거 명령
- CLAUDE.md에 배포 규칙 추가, JSON 검증을 python3에서 node로 교체

## [0.1.0] - 2026-06-03

### Added
- 최초 릴리스 — `fg-*` 4단계 루프 스킬: `fg-ask`(질의·계획·그릴링), `fg-execute`(Dynamic Workflow 실행), `fg-learn`(회고·문서 승급), `fg-cleanup`(정리·봉인·재실행 방지)
- `fg-ask`에 grill-with-docs 원문 verbatim 이식 (`CONTEXT-FORMAT.md`/`ADR-FORMAT.md` 포함), 기존 `fg-plan` 단계를 `fg-ask`로 통합
- 백로그·작업 선택 메뉴("모두 실행" 지원)·회고 환류 도입, 스킬 본문 영문화
- 스킬별 형식 문서 체계 (`PLAN-FORMAT.md`, `RETRO-FORMAT.md`)
- `README.md`(영문)/`README.ko.md`(한글) 번역 쌍과 동기화 규칙
