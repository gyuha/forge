---
last_mapped_commit: 553484ae395d6ca3df973f5b0cf5762029fd94ec
mapped: 2026-07-20
---

# TESTING

이 리포는 **플러그인 자체를 위한 단위 테스트·빌드·린트 시스템이 없다** — `package.json`·`Makefile`·`.github`(CI) 모두 부재. 테스트 러너도 없어 각 테스트는 손으로 실행한다. 그러나 **결정론적 스크립트(`scripts/*`)는 테스트를 갖는다.**

## 플러그인 수준 검증 (3가지)

1. **매니페스트 JSON 유효성** — 편집 후 반드시 확인(깨지면 설치 실패). CLAUDE.md의 node 한 줄:
   ```
   node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
   ```
2. **설치 후 트리거** — 실제 동작 테스트는 설치해서 트리거해보는 것뿐. `/plugin install`·`/plugin marketplace update`는 interactive라 에이전트가 실행 못 한다(사용자가 직접). 에이전트가 검증할 수 있는 건 설치 전제뿐 — 원격 main의 버전 3곳(`curl` raw manifest)과 `skills/*/SKILL.md`의 frontmatter `name` 누락 여부(`awk '/^name:/'`).
3. **fg-doctor** — 읽기 전용 무결성 health check(`scripts/forge-doctor.sh`/`.js`). `.forge/` 상태 계약과 문서/매니페스트 정합을 검사해 severity + actionable 수정 안내로 보고. exit `0`(clean)/`1`(warnings)/`2`(errors)라 **AI 없이 CI 게이트**로도 쓴다. 아무것도 쓰지 않고 자동 수정 안 함. 근거: ADR-0019(`.forge/adr/0019-fg-doctor-integrity-check.md`).

## 결정론적 스크립트 테스트 (두 종류)

각 스크립트 primitive는 최대 두 테스트를 가진다. 러너 없이 `bash scripts/<name>.test.sh`로 개별 실행한다.

### (A) 동작 테스트 `*.test.sh` — fixture 기반

임시 디렉터리에 `.forge/` fixture를 시드하고 스크립트를 돌려 **exit code + 결과 파일 트리**(STATUS 내용·아카이브 레이아웃·무엇이 이동/삭제됐나)를 단언한다. 기본은 `.sh`를 대상으로 하되, 환경변수 `FG*_IMPL=.../<name>.js`로 지정하면 **같은 테스트를 `.js` 구현에 재사용**한다(러너가 확장자로 `bash` vs `node`를 고른다). 예: `scripts/forge-done.test.sh`의 `run_done()`는 `case "$SCRIPT" in *.js) node ... ;; *) bash ... ;; esac`.

### (B) 패리티 테스트 `*.parity.test.sh` — sh ≡ js 동치 가드

**같은 fixture에 `.sh`와 `.js`를 둘 다 돌려 결과가 동일함을 단언**한다(ADR-0022). 이것이 이중 유지의 **진짜 drift 가드**이며 fg-doctor의 트윈-존재 정적 검사보다 강력하다. 파일을 변형하는 primitive는 stdout이 아니라 **파일 시스템 결과**로 패리티를 검사한다(`diff -r "$A/.forge" "$B/.forge"` + exit code 동일). 대부분 `set -euo pipefail`로 강화돼 fixture 빌드 실패가 "둘 다 빈 출력 = 동일"로 위양성 통과되는 걸 막는다.

## 스크립트별 테스트 매트릭스

| primitive | 동작 테스트 | 패리티 테스트 | 무엇을 지키나 |
| --- | --- | --- | --- |
| `forge-done` | `scripts/forge-done.test.sh` | `scripts/forge-done.parity.test.sh` | 봉인 게이트 — verify 게이트(sealable 아니면 exit `3`, 파일 불변)·retro 게이트(exit `4`)·중복 done(exit `5`)·빈 상태(exit `2`)·정상 봉인(exit `0`), 비파괴 refuse, STATUS→done, `done/<completed>-<slug>/` 원자 아카이브, `review.md` 이동, executed/ parked 봉인, half-sealed 완결. ADR-0030. |
| `forge-merge` | `scripts/forge-merge.test.sh` | `scripts/forge-merge.parity.test.sh` | 브랜치-forge 통합 exit 계약(`0`/`2`/`3`/`4`/`6`) + 모든 기계적 통합 op + 게이트(in-flight·CONTEXT 재정의·NNNN 충돌)의 비파괴 refuse. |
| `forge-doctor` | `scripts/forge-doctor.test.sh` | `scripts/forge-doctor.parity.test.sh` | 무결성 exit-severity(`0` clean/`1` warn/`2` error) + 대표 체크(A1 orphan run.md·A4 half-sealed done/·A8 orphan branch root·B14 time-ID 유일성/NNNN false-gap 없음 등). |
| `forge-status` | (동작 테스트 없음) | `scripts/forge-status.parity.test.sh` | full·`--table` 두 모드에서 `.forge` fixture 출력 동일성 — 이중 sh/js의 실제 drift 가드. |
| `forge-statusline` | `scripts/forge-statusline.test.sh` | `scripts/forge-statusline.parity.test.sh` | statusline fragment 단계 로직 + sh≡js 출력 동일. |
| `forge-statusline-full` | `scripts/forge-statusline-full.test.sh` | `scripts/forge-statusline-full.parity.test.sh` | 통합(daleseo식) statusline 렌더 — 그룹 `[...]` 레이아웃·model/effort/dir/git·Context/크기/그라디언트 바·세션 그룹($비용/±라인/⏱)·density·compact splice. ANSI 제거 후 비교. |
| `forge-statusline-wrapper` | `scripts/forge-statusline-wrapper.test.sh` | (트윈 없음 — bash 전용) | 원본 statusline 실행 후 forge fragment를 아래 줄로 append하는 wrapper. 동반 파일을 `$CLAUDE_CONFIG_DIR`가 아니라 자기 설치 디렉터리(`BASH_SOURCE`)에서 해석함을 검증. |
| `resolve-forge-root` | (동작 테스트 없음) | `scripts/resolve-forge-root.parity.test.sh` | forge 루트 해석 — sh≡js **및** 기대값 일치를 함께 단언(비-git→`.forge`, 기본 브랜치→`<top>/.forge`, 비-기본 브랜치→`<top>/.forge/branch/<branch>`, nested slash 브랜치, config `defaultBranch`, 서브디렉터리에서도 `<top>` 앵커). |

패리티 테스트만 있고 동작 테스트가 없는 것(`forge-status`·`resolve-forge-root`)은 패리티 테스트가 기대값까지 단언해 correctness도 겸한다. `forge-statusline-wrapper`는 반대로 트윈이 없어 동작 테스트만 있다.

fg-doctor는 별도로 **`scripts/*.sh`마다 `.js` 트윈 존재를 정적 검사**한다(B-check) — 이건 존재 검사(정적 절반)이고, 진짜 동치 가드는 위 패리티 테스트다.

## 벤더 테스트 미포팅

`skills/fg-visual/`은 obra/superpowers v6.1.1의 Visual Companion을 vendoring했지만 **업스트림 테스트 스위트는 의도적으로 포팅하지 않았다**(npm 의존 회피). `skills/fg-visual/scripts/`에는 테스트 파일이 없다(`server.cjs`·`start-server.sh`·`stop-server.sh`·`helper.js`·`frame-template.html`만). 벤더 스크립트는 ADR-0022 트윈 규약 밖이라 패리티 테스트 대상도 아니다. 근거: ADR `260719-224442`.
