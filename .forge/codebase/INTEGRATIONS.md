---
last_mapped_commit: 48899bdb6b04ad575767885a7c741cb2a09bd9d0
mapped: 2026-08-10
---

# INTEGRATIONS — 외부 연동

## 한 줄 요약

데이터베이스·인증 프로바이더·원격 API 호출 코드가 **없다**. 연동 표면은 (1) Claude Code 플러그인 호스트, (2) GitHub(`gh` CLI·raw 콘텐츠, 문서 규칙으로만), (3) 로컬호스트 시각 컴패니언 서버, (4) MIT vendoring 두 건이다.

## 1. Claude Code 플러그인 표면 (주 연동)

- **마켓플레이스 겸 플러그인**: 리포 루트가 곧 플러그인. `.claude-plugin/marketplace.json`의 `plugins[0].source: "./"`. 설치는 GitHub `main` 브랜치를 당긴다(push까지가 배포).
- **스킬 자동 탐색**: `skills/*/SKILL.md` (frontmatter `name`이 식별자).
- **훅**: `hooks/hooks.json` — `SessionStart`(matcher `startup|resume|clear|compact`, `shell: "bash"`, `async: false`)가 `"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd" session-start` 실행. polyglot 래퍼가 `scripts/forge-hook-session-start.sh`(bash 우선) → `.js`(node 폴백) 디스패치, 런타임 없으면 exit 0 침묵. `CLAUDE_PROJECT_DIR` 환경변수로 프로젝트 디렉터리에 앵커.
- **statusline**: `fg-statusline`이 사용자 `settings.json`의 `statusLine` command에 절대경로로 wire. 스크립트는 Claude Code가 stdin으로 주는 세션 JSON(cwd·model·cost·context 필드)을 파싱 (`scripts/forge-statusline-full.sh`/`.js`, 래퍼 `scripts/forge-statusline-wrapper.sh`). 환경변수 계약: `FORGE_SL_PREFIX`, `FORGE_SL_SEP`, `FORGE_SL_DENSITY`, 테스트용 `FORGE_SL_NOW`.
- **서브에이전트 카드**: `fg-agents`가 `.claude/agents/<role>.md` 생성 → fg-run이 `agentType`으로 호출(세션 재시작 후 로드). 이 리포 자체도 3장 보유: `.claude/agents/{manifest-doc-syncer,script-twin-engineer,skill-author}.md`.
- **Dynamic Workflow**: fg-run/fg-loop/fg-adversarial-review가 Claude Code 워크플로우·병렬 서브에이전트 기능을 사용(코드 아닌 스킬 지시문 차원).

## 2. GitHub / `gh` CLI (문서 규칙으로만 — 스크립트에는 없음)

`scripts/`·`skills/`에는 gh/curl 호출 코드가 없다. 전부 `CLAUDE.md`의 에이전트 지시 규칙이다:

- **이슈 연동 봉인** (`CLAUDE.md` "이슈 연동 작업 봉인 규칙"): plan에 `이슈 추적: GitHub 이슈 #N`이 있으면 fg-done 봉인 시 커밋 메시지 `(Fixes #N)` → `git push origin main` → `gh issue comment N` → `gh issue view N --json state` 확인, 필요 시 `gh issue close N`.
- **배포 후 설치 전제 검증**: `curl -fsSL raw.githubusercontent.com/gyuha/forge/main/.claude-plugin/{plugin,marketplace}.json`으로 원격 버전 3곳 확인 (`CLAUDE.md` 배포 규칙).
- **git**: 여러 스킬이 `git` 명령을 지시(브랜치별 forge 루트 판별 `scripts/resolve-forge-root.sh`, `fg-merge <branch>`의 대화형 `git merge` 등). 단 코어 통합 스크립트 `scripts/forge-merge.sh`/`.js`는 의도적으로 git-free(CI에서 AI 없이 사용 가능).

## 3. 시각 컴패니언 로컬 서버 (`fg-visual`)

- `skills/fg-visual/scripts/server.cjs` — zero-dependency Node HTTP+WebSocket(RFC 6455 직접 구현) 서버. **원격 요청·텔레메트리 없음**(파일 헤더에 명시, superpowers 브랜딩/텔레메트리 제거됨).
- 랜덤 하이 포트에 기동(`start-server.sh`), 세션 키 URL 인증(`?key=` 토큰), Origin 검사, 포트/키를 `<project>/.forge/visual/.last-port`에 영속해 재시작 시 재사용. 유휴 자동 종료는 `BRAINSTORM_IDLE_TIMEOUT_MS` 환경변수(기본 4시간).
- 세션 파일은 모든 브랜치에서 최상위 `.forge/visual/<세션>/` (휘발·gitignore).
- 사용자 입력(클릭·텍스트)은 JSONL 이벤트로 에이전트에 회수 — 보조 답변 채널.

## 4. Vendored / 개념 차용 (외부 코드 유입 경로)

| 출처 | 라이선스 | 유입 형태 | 위치 |
| --- | --- | --- | --- |
| obra/superpowers v6.1.1 Visual Companion | MIT (LICENSE 동봉) | 코드 vendoring (5파일) | `skills/fg-visual/scripts/`, `skills/fg-visual/LICENSE` |
| obra/superpowers `run-hook.cmd` polyglot 패턴 | MIT (파일 헤더 귀속) | 코드 차용 + node 폴백 확장 | `hooks/run-hook.cmd` |
| mattpocock/skills Wayfinder | MIT | **개념만** 각색 (파일 복사 없음) | `skills/fg-agenda/SKILL.md` |
| daleseo statusline 스타일 | — | 스타일 참조 | `scripts/forge-statusline-full.sh` |

## 5. 랜딩 페이지 외부 자원

`docs/index.html`이 유일하게 원격 자원을 참조: Google Fonts CDN(`fonts.googleapis.com` — Inter·JetBrains Mono). 그 외 링크는 `github.com/gyuha/forge` 이동뿐.

## 없는 것 (명시적 부재)

- 데이터베이스, 인증 프로바이더, 웹훅 수신, 원격 API 클라이언트, npm 의존성, CI 파이프라인 — 전부 없음. 상태는 로컬 `.forge/` 파일 시스템이 전부다.
