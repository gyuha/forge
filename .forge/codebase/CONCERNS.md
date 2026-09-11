---
last_mapped_commit: 6146cae539151b65850e1e2609bdf8f7e78a1e47
mapped: 2026-09-11
---

# CONCERNS — 기술부채·취약 영역

## 높은 변경 위험 영역

### Markdown이 실행 계약이다

- 제품 동작의 대부분이 코드가 아니라 `skills/*/SKILL.md`의 자연어 지시로 구현된다. 문법 오류 없이도 상충·누락·도달 불가능한 절이 생길 수 있으며, 일반 컴파일러나 타입 검사기가 이를 검출하지 않는다.
- `skills/fg-loop/SKILL.md`(54 KB)와 `skills/fg-loop/INQUIRY.md`(11 KB)는 신규 실행과 재개 실행의 조건부 규칙을 나눠 가진다. 조건부 분할로 내용이나 포인터가 필요한 경로에서 읽히지 않는 결함이 이 디렉터리에서 2026-09-11까지 네 사이클 연속 발생했고, 근거는 `.forge/retro/260911-105936-restore-fg-loop-resume-preflight.md`, `.forge/retro/260911-144856-recut-fg-loop-split-boundary.md`, `.forge/retro/260911-160340-fix-fg-loop-reference-integrity.md`에 있다. 이 결함은 절·파일·링크가 여전히 존재하므로 크기·총량·링크·frontmatter 검사를 모두 통과한다.
- 위 결함의 절반은 기계화됐다. `scripts/forge-doctor.sh`와 `scripts/forge-doctor.js`의 신규 검사 **B21**이 `## N.` 절 안에 있는 `§N` 자기참조를 warning으로 보고하고, `scripts/forge-doctor.test.sh`에 정상·자기참조·`§NN` 접두 3개 케이스가 있다. 두 구현의 주석은 이것이 **설계상 부분 가드**라고 명시한다 — 대상 절이 더는 그 규칙을 담고 있지 않은 교차 절 참조는 의미 판정이라 검출되지 않으며, 그 절반은 `CLAUDE.md`의 두 단계 체크리스트(양방향 상호참조 열거 + 내용 실재 확인)가 담당한다.
- B21의 적용 범위는 `skills/*/SKILL.md`이고 절 인식은 `^## N.` 형식에 의존한다. `INQUIRY.md`·`ALL-MODE.md`·`RECOVERY.md` 같은 동반 파일과 번호 없는 헤딩 구조의 문서는 대상이 아니다. 현재 저장소에서 `scripts/forge-doctor.sh`는 0 errors / 0 warnings로 종료한다.
- `skills/fg-ask/SKILL.md`는 upstream 원문과 파일 하단의 Forge integration 절이 별도로 움직인다. 형식 계약도 `skills/fg-ask/CONTEXT-FORMAT.md`와 `skills/fg-ask/ADR-FORMAT.md`로 분리돼 있어 동시 검토가 필요하다.
- 공통 핸드오프 형식은 `skills/fg-next/HANDOFF.md`에 있지만 이를 참조하는 스킬이 다수다. 공통 설명 규칙은 `scripts/explaining-forge.rule.txt`와 22개 `skills/*/SKILL.md`에 함께 존재한다.
- `scripts/forge-doctor.sh`와 `scripts/forge-doctor.js`가 일부 산문 정합을 검사하지만 키워드·절 경계·개수 기반 검사다(B17 canonical 문단 포함, B20 capability 키 언급, B21 자기참조 포인터). 자연어 규칙 전체의 의미적 동등성은 검사하지 않는다.
- B21의 Bash 구현은 `grep`과 셸 산술로 작성돼 있다. 주석에 기록된 이유는 macOS 기본 `awk`에 3인자 `match()`가 없어 awk 판이 결함이 있는 저장소에서도 0건을 보고했다는 것이다. 같은 종류의 플랫폼 차이는 다른 Bash 검사에도 잠재한다.

### 상태가 파일 묶음으로 분산된다

- 작업 상태는 단일 데이터베이스나 트랜잭션 로그가 아니라 `.forge/plan.md`, `.forge/run.md`, `.forge/STATUS.md`, `.forge/running.md`, `.forge/loop.md`, `.forge/executed/`, `.forge/done/`에 분산된다.
- 기계적 변경 중 위험도가 높은 봉인과 병합은 `scripts/forge-done.*`, `scripts/forge-merge.*`가 임시 디렉터리·롤백 경로를 사용한다. 반면 스킬이 직접 작성하는 plan, run, retro, ADR에는 저장소 전체를 감싸는 공통 트랜잭션 계층이 없다.
- 실행 중복 방지는 활성 작업의 `.forge/running.md`, 무인 drive 연속성은 `.forge/drive.md`에 의존한다. 오래되거나 파싱할 수 없는 marker는 `scripts/forge-doctor.*`와 훅이 별도 규칙으로 판정한다.
- `scripts/`, `hooks/`, `skills/fg-showme/scripts/`의 실행 코드에는 범용 `flock` 또는 lockfile 구현이 없다. 여러 세션이 같은 브랜치의 Forge 상태를 동시에 편집하면 파일 단위 marker가 다루지 않는 쓰기 경합은 직렬화되지 않는다.
- 비기본 브랜치 상태는 `.forge/branch/<branch>/`에 저장되지만 `.forge/config.json`과 `.forge/codebase/`는 모든 브랜치가 공유한다. 병렬 브랜치에서 설정이나 지도를 갱신하면 동일 파일을 수정한다.

## 자동 검증의 공백

- 중앙 테스트 러너가 없다. 동작·패리티 검사는 `scripts/*.test.sh`, `hooks/run-hook.test.sh`, `hooks/run-hook.windows.test.js`를 개별 실행해야 한다.
- 11개 Bash/Node 트윈 중 `scripts/forge-status.*`, `scripts/resolve-forge-root.*`, `scripts/release-check.*`는 전용 behavior 테스트가 없고 parity 테스트만 있다. parity는 두 구현이 같은 결과를 내는지는 보지만 둘이 같은 방식으로 틀린 경우를 독립적으로 배제하지 못한다.
- `.github/workflows/release-check.yml`은 전체 스크립트 테스트를 실행하지 않는다. Bash·Node `release-check`와 `scripts/release-check.parity.test.sh`, Windows 훅 래퍼만 실행한다.
- `.github/workflows/release-check.yml`의 path filter에는 일반 `skills/**`와 대부분의 `scripts/**`가 없다. 다수의 런타임 Markdown 또는 상태 스크립트 변경은 이 CI를 시작하지 않는다.
- `.github/workflows/` 어디에도 `forge-doctor` 호출이 없다. B17·B20·B21 같은 산문 정합 검사는 사람이 수동 실행할 때만 동작하고, `skills/**` 편집은 `.github/workflows/release-check.yml`의 path filter에도 없어 CI가 아예 시작되지 않는다.
- `.github/workflows/docs.yml`은 `main` push와 수동 실행만 선언하고 pull request 이벤트는 선언하지 않는다. 문서 빌드 오류는 PR 단계에서 자동으로 차단되지 않는다.
- 플러그인 본체에는 빌드·패키징 검사가 없으며 설치 실측이 최종 확인 경로다. 이 제한은 `CLAUDE.md`에 명시돼 있다.
- `skills/fg-map/SKILL.md`의 비밀 패턴 검사는 지도 작성 후 에이전트가 수동 실행하는 절차다. `.github/workflows/`에는 `.forge/codebase/*.md`를 대상으로 하는 자동 secret scan이 없다.

## Bash와 Node 트윈 유지보수

- 상태 기계 11개가 Bash와 CommonJS 두 구현으로 유지된다. 목록은 `scripts/forge-*.sh`, `scripts/forge-*.js`, `scripts/resolve-forge-root.*`, `scripts/release-check.*`에 걸쳐 있다.
- 출력, stderr 순서, 종료 코드, 파일 변이를 맞춰야 하므로 한쪽 수정은 대응 트윈과 `scripts/*.parity.test.sh`를 함께 변경해야 한다.
- Bash 구현은 `awk`, `sed`, `grep`, `find`, coreutils와 macOS/Linux 간 차이를 직접 흡수한다. Node 구현은 같은 계약을 별도 파서와 파일 API로 재현한다.
- 루트 `package.json`에 `type: "module"`을 추가하면 `scripts/*.js`의 `require` 기반 CommonJS 실행이 깨진다. VitePress 설정은 `docs/.vitepress/config.mts` 확장자로만 ESM 경계를 유지한다.
- `hooks/run-hook.cmd`는 Windows batch와 Unix heredoc shell을 한 파일에 결합하고 Git Bash 우선·Node 폴백을 구현한다. quoting, 경로 공백, 종료 코드 전달이 한 파일의 두 파서에 동시에 유효해야 한다.

## 훅과 세션 생명주기

- `hooks/hooks.json`은 `SessionStart`와 `Stop`을 모두 `async: false`로 실행한다. 훅이 느리거나 멈추면 세션 시작 또는 턴 종료 경로가 함께 지연된다.
- `hooks/run-hook.cmd`는 Bash가 있으면 Node보다 Bash를 우선한다. `scripts/forge-hook-session-start.sh`는 활성 상태와 `.forge/executed/` 항목을 순회하며 여러 외부 텍스트 유틸리티를 호출하므로 대기 작업 수에 따라 비용이 증가한다.
- `scripts/forge-hook-stop.*`는 활성 무인 drive에서 종료 코드 2로 호스트의 정지를 거부한다. 30분과 50회 제한, session id 일치, 쓰기 성공 조건을 두며 파싱 실패나 I/O 실패에서는 정지를 허용한다.
- stale `.forge/drive.md`와 `.forge/running.md`는 자동 삭제 대상이 아니라 진단·재진입 판단 대상인 경우가 있다. 사용자는 `scripts/forge-doctor.*` 또는 관련 스킬의 복구 분기를 거쳐야 한다.
- 플러그인 훅과 `.claude/agents/*.md`는 세션 시작 시 로드된다. 설치·생성·수정 직후의 열린 세션에는 새 동작이 반영되지 않는다.

## 호스트 간 기능 차이

- `hosts/claude/capabilities.json`은 9개 capability를 모두 지원으로 선언하지만 `hosts/codex/capabilities.json`은 3개만, `hosts/opencode/capabilities.json`은 0개를 지원으로 선언한다.
- Codex와 opencode에서는 `prevent_stop: false`라 `fg-next all`과 `fg-loop`가 한 턴 안에서 가능한 만큼만 진행하고 재호출로 이어간다. 관련 제한은 `docs/codex.md`, `docs/opencode.md`에 있다.
- Codex와 opencode에서는 `event_wake: false`라 `fg-showme`에서 선택을 확정한 뒤에도 터미널 입력이 하나 필요하다. 호스트 분기는 `skills/fg-showme/SKILL.md`에 있다.
- `fg-agents`의 산출물은 `.claude/agents/<role>.md`다. `hosts/codex/capabilities.json`과 `hosts/opencode/capabilities.json`은 `project_agents`와 `spawn_role`을 `false`로 선언한다.
- `scripts/forge-loop-spend.*`의 기본 계측 대상은 Claude Code transcript 형식이다. Codex와 opencode에서 별도 transcript 경로를 제공하지 않으면 token budget 기능이 `blocked-health`로 멈춘다는 제한이 `docs/codex.md`와 `docs/opencode.md`에 있다.
- `fg-next all`에는 `fg-loop`의 `loop.md`에 해당하는 예산 필드가 없어 token ceiling이 적용되지 않는다. 이 범위 제한은 `skills/fg-loop/SKILL.md`에 후속 작업으로 명시돼 있다.
- opencode는 안정적인 plugin-root 환경 신호가 없어 명시적 호스트 메타데이터가 없으면 `core/HOST.md`의 unknown-host 직렬 폴백으로 내려간다.

## 로컬 브라우저 서버의 보안 경계

- `skills/fg-showme/scripts/start-server.sh`의 기본 bind 주소는 `127.0.0.1`이지만 `--host 0.0.0.0`을 허용한다. 비루프백 바인딩을 선택하면 네트워크 노출 범위가 커진다.
- `skills/fg-showme/scripts/server.cjs`는 URL query의 session key를 cookie와 sessionStorage로 전달한다. 완전한 keyed URL이 브라우저 기록, 화면 공유, 로그에 노출되면 해당 세션에 접근할 수 있다.
- 서버는 query/cookie key의 상수시간 비교, WebSocket Origin 검사, 실제 경로 기반 content sandbox, WebSocket frame 10 MiB 상한을 구현한다.
- 세션 키를 포함하는 `server-info`, 로그, token 파일은 `.forge/showme/<session>/`에 저장된다. `skills/fg-showme/scripts/start-server.sh`가 디렉터리 권한을 제한하고 내부 `.gitignore`를 만들며, `skills/fg-showme/scripts/stop-server.sh`가 종료 시 삭제한다.
- 비정상 종료 후 남은 세션은 다음 시작 시 sweep된다. 정상 운영에서도 240분 idle timeout까지 프로세스와 세션 파일이 남을 수 있다.

## 문서 사이트와 공유 미리보기

- Open Graph·Twitter Card 메타는 워킹 트리에서 추가됐다. `docs/index.html`이 `og:type`부터 `og:image:alt`까지 선언하고 `docs/.vitepress/config.mts`가 공통 `og:*`·`twitter:card`와 locale별 `og:title`/`og:description`을 넣는다. 두 선언은 별도 파일에 중복되므로 사이트 제목·설명 변경 시 함께 수정해야 한다.
- 미리보기 이미지는 절대 URL `https://gyuha.com/forge/docs/og-image.png`로 하드코딩돼 있고 실제 파일 `docs/public/og-image.png`는 아직 git에 추가되지 않은 상태다. 파일이 커밋·배포되지 않으면 메타는 유효하지만 이미지 요청은 404가 되고, 절대 URL이라 `npm run docs:build`의 dead-link 검사 대상도 아니다.
- `npm run docs:build`의 dead-link 검사는 내부 상대 링크를 다루지만 외부 `https://` 링크의 실재를 검증하지 않는다. 외부 GitHub ADR 링크는 별도 확인이 필요하다고 `CLAUDE.md`가 명시한다.
- HTML 이미지 404는 브라우저 console error만 확인해서는 잡히지 않는다. `.github/workflows/docs.yml`은 조립 결과의 일부 핵심 파일만 `test -f`로 확인하고 페이지 내 모든 asset request를 실행해 검사하지 않는다.
- 한국어·영어 문서는 `docs/*.md`와 `docs/en/*.md`에 쌍으로 존재하고, 랜딩은 한 `docs/index.html` 안의 `data-l="ko"`·`data-l="en"` 텍스트를 함께 유지한다. 번역 구조 동기화는 주로 작성 규칙과 리뷰에 의존한다.

## 접근성·표현

- `skills/fg-showme/scripts/frame-template.html`은 라이트 테마의 6개 색상 조합이 WCAG AA 또는 비텍스트 3:1 기준에 미달한다고 주석으로 명시하고 현재 디자인 선택으로 수용한다.
- Mermaid 노드의 다크 모드 대비는 Markdown 작성자가 `style`의 전경색까지 지정해야 한다. 이 검사는 `npm run docs:build`가 자동 판정하지 않으며 `CLAUDE.md`가 시각 확인을 요구한다.
- `scripts/forge-status.sh`와 상태줄 구현은 터미널 폭, ANSI 색상, UTF-8 바이트 폭을 직접 처리한다. 패리티 테스트가 일부 한글 경로를 포함하지만 실제 터미널 렌더러별 폭 차이는 남는다.

## 외부 소스와 배포 드리프트

- `skills/fg-security/`, `skills/fg-debug/`, `skills/fg-showme/`, `hooks/run-hook.cmd`에는 외부 프로젝트에서 가져온 코드·문서가 포함된다. 각 디렉터리의 `LICENSE`와 소스 머리말이 출처·로컬 수정을 기록한다.
- `skills/fg-security/SKILL.md`는 vendored 파일을 byte-for-byte 유지하도록 요구하고 Forge 연결부만 별도 절에서 관리한다. upstream 갱신 시 로컬 연결 규칙과 원본 보존을 함께 확인해야 한다.
- `skills/fg-showme/`는 upstream 형태를 유지하지만 branding, telemetry 제거, 테마, 세션 저장소, 인증, wake 동작을 로컬 수정했다. 단순 upstream 덮어쓰기로 갱신할 수 없다.
- 플러그인 버전은 `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`의 두 위치, `.codex-plugin/plugin.json`에 걸쳐 4개 값이 동기돼야 한다. `scripts/release-check.*`와 `scripts/forge-doctor.*`가 이 드리프트를 검사한다.
- 2026-09-11 시점의 워킹 트리에는 출처가 다른 미커밋 변경이 섞여 있다. `skills/fg-loop/*`·`scripts/forge-doctor.*`·`CLAUDE.md`는 참조 정합 작업의 산물이고 `docs/.vitepress/config.mts`·`docs/index.html`·`docs/public/og-image.png`는 별개의 문서 사이트 작업이다. `CLAUDE.md`의 배포 규칙은 무관한 변경을 릴리스 커밋에 섞지 않도록 요구하므로 커밋 분리 판단이 필요하다.
- README와 문서 사이트가 각각 한국어·영어 사본을 유지하고, Claude·Codex·opencode 지원표가 `hosts/*/capabilities.json`의 선언을 설명한다. capability 변경은 JSON, 호스트 어댑터, 두 언어 문서를 함께 수정해야 한다.
