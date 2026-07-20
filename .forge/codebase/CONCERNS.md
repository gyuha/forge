---
last_mapped_commit: 553484ae395d6ca3df973f5b0cf5762029fd94ec
mapped: 2026-07-20
---

# CONCERNS — 기술 부채·위험·취약 지점

이 리포는 빌드·테스트·CI가 없는 **Markdown/JSON/bash+node 스크립트 플러그인**이다. 따라서 "버그"의 대부분은 코드 결함이 아니라 **여러 파일에 흩어진 사실이 서로 어긋나는 드리프트**다. 아래는 편집 전 반드시 인지해야 할 위험을 파일:라인 증거와 함께 정리한 것이다. 심각도는 `[치명]`(설치 실패·데이터 유출) / `[높음]`(사용자에게 보이는 문서 불일치) / `[중간]`(내부 정합성) / `[낮음]`(경미) 으로 태그한다.

---

## 1. 카탈로그 드리프트 — 스킬 개수·설명 동기화

최근 브랜치 `feature/visual-compose`가 `fg-visual`을 추가하며 스킬 수가 **18 → 19**(루프 밖 유틸리티 14 → 15)로 바뀌었다. 매니페스트·README는 갱신됐으나 **`docs/`의 일부가 아직 18/14로 뒤처져 있다.**

**동기화된(OK) 소스:**
- `.claude-plugin/plugin.json` — description·`version` 0.5.18, fg-visual 포함 `[높음 확인]`
- `.claude-plugin/marketplace.json:19` — `"Nineteen fg-* skills"`, `metadata.version`·`plugins[0].version` 모두 0.5.18 `[높음 확인]`
- `README.md:6` — `"nineteen ... plus fifteen utilities"`, `README.md:14`·`:65` 일관 `[높음 확인]`
- `README.ko.md:6` — `"19개 ... 루프 밖 유틸리티 15개"`, `:14`·`:65` 일관 `[높음 확인]`
- `docs/skills.md:55` — `"## 루프 밖 유틸리티 (15개)"`, fg-visual 카탈로그 행 존재 `[높음 확인]`
- 버전 3곳 모두 `0.5.18`로 동기 `[높음 확인]`

**뒤처진(STALE) 문서 — 반드시 갱신 필요:**
- `docs/index.html:111` — `"18개의 fg- 스킬"` / `"eighteen fg- skills"` → 19여야 함 `[높음]`
- `docs/index.html:197` — `"18개의 스킬."` / `"Eighteen skills."` → 19 `[높음]`
- `docs/index.html:235` — `"루프 밖의 유틸리티 14개"` / `"14 utilities outside the loop"` → 15 `[높음]`
- `docs/index.html:480` — `<meta>` desc `"... eighteen fg- skills."` → nineteen `[높음]`
- `docs/forge-vs-loop-engineering.md:15` — `"forge 자체가 18개 fg-* 스킬(루프 4단계 + 루프 밖 유틸리티 14개)"` → 19 / 15 `[높음]`

**더 심각한 누락 — index.html에 fg-visual 카드가 통째로 없음** `[높음]`:
- `docs/index.html`의 `.fg-grid-utils` 섹션(라인 236~290)은 유틸리티 카드 **14개**만 열거한다: fg-map·fg-quick·fg-status·fg-next·fg-loop·fg-tdd·fg-eco·fg-merge·fg-cleanup·fg-adversarial-review·fg-doctor·fg-drop·fg-agents·fg-statusline. `grep -oE "fg-[a-z-]+" docs/index.html`에 **fg-visual이 0회** 등장한다 — 랜딩 페이지는 개수만 틀린 게 아니라 새 스킬 카드 자체가 빠졌다. 개수 수정 시 카드도 함께 추가해야 한다.

검증 명령: `grep -rniE "18개|eighteen|14개|14 utilities" docs/` 가 위 라인들을 다시 잡아내면 아직 미수정.

---

## 2. 이중 언어 동기화 취약성

두 쌍의 번역 문서는 한쪽만 고치면 조용히 어긋난다(자동 검사 없음, `fg-doctor`의 README 드리프트 검사만 존재):

- **`README.md` ↔ `README.ko.md`** — 현재는 개수·fg-visual 행 모두 동기(위 1절 확인). 규약: 한쪽 편집 시 반드시 짝을 함께 갱신(`CLAUDE.md`의 "README 이중 언어 동기화").
- **`docs/index.html`의 KO/EN span** (`data-l="ko"` / `data-l="en"`, ADR-0027) — 한 파일 안에 두 언어를 나란히 담고 토글로 전환한다. 위 1절의 stale 라인들(111·197·235)은 **KO/EN 양쪽이 함께 18/14로 틀렸다** — 즉 이건 언어 간 divergence가 아니라 KO·EN이 사이좋게 같이 뒤처진 케이스다. 수정 시 두 span을 반드시 함께 고쳐야 divergence를 새로 만들지 않는다.

---

## 3. "전역 예외 두 개" 표현 드리프트 — `.forge/visual/`이 사실상 세 번째 최상위 위치

forge 루트 해석의 단일 정의 문서 `skills/fg-run/FORGE-ROOT.md`는 최상위 `.forge/`에 남는 **전역 예외를 정확히 두 개**(`config.json`, `codebase/`)로 못박는다. 그런데 `fg-visual`이 도입한 `.forge/visual/`는 **모든 브랜치에서 최상위에 사는 세 번째 위치**로 문서화돼 있어, "두 개"라는 열거와 어긋난다.

**"두 개"로 못박는 곳(권위 문서 포함):**
- `skills/fg-run/FORGE-ROOT.md:16` — `"except the two global exemptions below"`
- `skills/fg-run/FORGE-ROOT.md:18` — `"### Global exemptions (always top-level .forge/, never resolved)"` — 이하 20~25행이 config.json·codebase/ **둘만** 열거, `visual/` 미언급 `[중간, 권위 문서라 영향 큼]`
- `skills/fg-run/FORGE-ROOT.md:58` — `"The two global exemptions (.forge/config.json, .forge/codebase/)"`
- `skills/fg-run/FORGE-ROOT.md:62` — `"The global exemptions (config.json, codebase/)"`
- `CLAUDE.md:50` — `"단 전역 예외 두 개(.forge/config.json·.forge/codebase/)"`
- `docs/state-contract.md:34` — `"단 전역 예외 두 개, .forge/config.json ... 과 .forge/codebase/"`
- `skills/fg-ask/SKILL.md:95` · `skills/fg-drop/SKILL.md:14`·`:29` · `skills/fg-merge/SKILL.md:74`·`:128` · `skills/fg-eco/SKILL.md:21` · `skills/fg-tdd/SKILL.md:10` · `skills/fg-map/SKILL.md:12` — 모두 "two global exemptions" = config.json + codebase/

**`.forge/visual/`를 세 번째 최상위로 서술하는 곳:**
- `skills/fg-visual/SKILL.md:33` — `"top-level .forge/visual/<session>/ — a deliberate global location on every branch (like .forge/config.json / .forge/codebase/, never the branch root)"`
- `skills/fg-visual/SKILL.md:49` · `skills/fg-visual/VISUAL.md:54` · `skills/fg-ask/SKILL.md:113` — 동일 취지(`"global like codebase/"`)

**핵심 모순: `CLAUDE.md`가 자기 안에서 충돌한다** `[중간]` — 라인 44(fg-visual 불릿)는 `.forge/visual/`을 `"전역 예외"`라 부르고, 라인 50(브랜치 루트 절)은 `"전역 예외 두 개"`라 못박는다. 같은 파일 안에서 예외 개수가 2개와 3개로 갈린다.

**주의 — visual/은 git 처리 방식이 다르다**: config.json·codebase/는 최상위에서 **git 추적**(`.gitignore` 화이트리스트, `.gitignore:9-10`)되지만, `.forge/visual/`은 **모든 브랜치에서 gitignore**된다(`.gitignore:5`의 `.forge/*`가 잡고 `visual/` 화이트리스트 없음). 즉 "최상위 전역 위치"라는 점만 공유하고 추적 정책은 반대다. 문서를 "세 개"로 고칠 땐 이 하위 구분(추적 vs 무시)을 함께 명시해야 오해가 없다. 표현을 통일하려면 FORGE-ROOT.md의 `### Global exemptions` 절이 단일 정의이므로 그곳부터 손대야 한다.

---

## 4. Vendored fg-visual 서버 — 유출·업스트림 진단

`skills/fg-visual/scripts/`는 obra/superpowers v6.1.1을 zero-dependency로 vendoring한 5파일(`server.cjs` 24KB, `start-server.sh`, `stop-server.sh`, `helper.js`, `frame-template.html`)이다. MIT 귀속은 `skills/fg-visual/LICENSE`(Copyright (c) 2025 Jesse Vincent)와 `SKILL.md:10`·`VISUAL.md:5`·각 `.sh` 헤더에 올바로 존재한다 `[높음 확인]`.

### 4-1. 세션 키가 임의 사용자 프로젝트에 커밋될 수 있음 — 적대적 리뷰의 MAJOR `[치명]`

서버는 세션 키(URL 인증 토큰)를 파일로 남긴다:
- `skills/fg-visual/scripts/server.cjs:642` — `.forge/visual/<session>/state/server-info` 기록(키 임베드, mode `0o600`)
- `skills/fg-visual/scripts/server.cjs:630` — `TOKEN_FILE` 기록(mode `0o600`)
- `skills/fg-visual/scripts/start-server.sh:126` — `BRAINSTORM_TOKEN_FILE="${PROJECT_DIR}/.forge/visual/.last-token"`
- `skills/fg-visual/scripts/start-server.sh:114` — 주석: `"Session files (server.log, server-info, .last-token) embed the session key"`

**이 리포 안에서는 안전하다** — `.gitignore:5`의 `.forge/*`가 `.forge/visual/`을 잡고 화이트리스트가 없어 무시된다(`git check-ignore .forge/visual/.last-token` → exit 0 확인). 실제로 `.forge/visual/.last-token`과 세션 로그가 존재하나 추적되지 않는다.

**위험은 forge를 설치한 임의의 사용자 프로젝트다** — 그 프로젝트에 `.forge/visual/`를 무시하는 `.gitignore` 규칙이 없으면 `git add -A` 한 방에 세션 키가 커밋된다. **완화책이 코드가 아니라 prose 안내뿐이다**:
- `skills/fg-visual/VISUAL.md:54` — `"make sure it is gitignored ... remind the user if their project's policy differs"`
- **검증: 어떤 스킬/스크립트도 `.gitignore`를 쓰지 않는다** — `grep -rniE "gitignore" skills/ scripts/`의 히트는 전부 문서 서술이거나 화이트리스트 설명일 뿐, `.gitignore` **파일을 생성·수정하는 코드는 0건**이다(파일 mode `0o600`으로 권한만 조일 뿐 커밋 차단은 사용자에게 위임). 즉 사용자가 forge의 `.gitignore` 관례를 안 쓰는 프로젝트에서 fg-visual을 돌리면 키 유출은 순전히 사용자 규율에 달려 있다.

### 4-2. 업스트림 진단 그대로 유지 `[낮음]`

vendoring 원칙상 업스트림 코드를 손대지 않아, 정적 분석이 지적할 항목이 남아 있다:
- `skills/fg-visual/scripts/server.cjs:78` · `:427` — `buffer.slice(...)` 사용. Node에서 `Buffer.prototype.slice`는 **deprecated**(오해 소지 있는 Array 시맨틱 별칭, `Buffer.prototype.subarray` 권장)다. 동작에는 문제없으나 린터·최신 Node 경고 대상. 업스트림 vendoring이라 의도적으로 그대로 둠.
- 업스트림에서 넘어온 **미사용 파라미터**가 존재(적대적 리뷰 지적). 라인 단위로 특정하지는 못했으나(server.cjs 함수 다수), 위 buffer.slice와 함께 "고치지 않고 유지하는 업스트림 진단" 부류다 — vendoring drift를 피하려는 의도적 결정.

이 둘은 기능 결함이 아니라 "upstream fidelity vs lint cleanliness" 트레이드오프다. 손대면 다음 업스트림 동기화 시 conflict가 늘어난다.

---

## 5. 매니페스트 편집 위험 — 깨진 JSON은 조용히 설치 실패

`.claude-plugin/plugin.json`·`.claude-plugin/marketplace.json`이 JSON 파싱에 실패하면 **플러그인 설치가 실패하되 빌드 에러가 없다**(CI 없음). 유일한 안전망은 `CLAUDE.md`가 지정한 수동 검사다 `[치명]`:

```
node -e "['.claude-plugin/plugin.json','.claude-plugin/marketplace.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8'))); console.log('OK')"
```

특히 `plugin.json`의 `description`은 **모든 스킬 설명을 담은 단일 초장문 문자열**(1개 문자열에 19개 스킬 서술)이라, 편집 중 이스케이프·따옴표 실수로 JSON을 깨뜨리기 쉽다. 매니페스트를 손댄 뒤 위 `node -e` 검사를 돌리지 않으면 다음 설치까지 결함이 드러나지 않는다. `fg-doctor`(스크립트 백킹)가 버전 3곳 동기·매니페스트 정합을 CI 없이 게이트할 수 있으나, JSON 문법 자체는 `node -e`가 1차 방어선이다.

두 description의 역할 분리도 주의(`CLAUDE.md` 배포 규칙): `marketplace.json`의 `metadata.description`은 루프 4단계 태그라인이라 루프 밖 유틸리티를 넣으면 안 되고, `plugins[].description`·`plugin.json.description`은 전체 스킬 목록을 담는다. 혼동해 넣으면 루프 정의가 흐려진다.

---

## 6. 브랜치 루트의 미커밋 봉인 상태 — half-sealed 위험 (관측됨)

`git status`에서 `feature/visual-compose` 브랜치 루트에 **미커밋 삭제 + 미추적 done/**이 관측된다 `[중간, 관측 사실 / 해석은 중간]`:

```
 D .forge/branch/feature/visual-compose/STATUS.md
 D .forge/branch/feature/visual-compose/plan.md
 D .forge/branch/feature/visual-compose/review.md
 D .forge/branch/feature/visual-compose/run.md
   (미추적) .forge/branch/feature/visual-compose/done/260720-074407-fg-visual-companion
```

이는 fg-visual 작업의 봉인(active slot → `done/260720-074407-fg-visual-companion`)이 **파일 이동은 됐으나 아직 커밋되지 않은** 상태로 보인다. `FORGE-ROOT.md:58`이 경고하는 바로 그 함정이다 — 비-기본 브랜치의 forge 루트는 **통째로 git 추적**되므로 봉인이 만든 이동은 "코드 변경처럼 브랜치에 커밋"해야 하며, `"an uncommitted branch root never reaches the default branch for fg-merge to integrate"`. 미커밋 상태로 두면 나중에 `git merge` → `fg-merge` 통합 시 done 이력이 기본 브랜치에 도달하지 못한다. 세션 시작 스냅샷은 clean이었으나 이후 상태가 바뀐 것으로, 진행 중 봉인일 가능성이 높다(해석 신뢰도 중간).

참고: 같은 `git status`에 `.forge/codebase/*.md`의 M/D도 보이는데, 이는 **현재 병렬 fg-map 실행(본 매퍼 포함)이 지도 문서를 재작성 중**이기 때문이다 — 정상.

---

## 7. ADR ID 충돌 엣지

ADR 번호 체계가 **두 세대 공존**(grandfather)한다 — `.forge/adr/`에 순차 `NNNN`(0001~0032, 32개)과 시간기반 `YYMMDD-HH+letter`(예: `260716-13a`, `260719-161701`)가 섞여 있다(ADR-FORMAT.md). 브랜치 루트에도 `.forge/branch/feature/visual-compose/adr/260719-224442-vendor-superpowers-visual-companion.md`가 대기 중이다.

- **fg-merge 통합 규칙**: 시간ID ADR을 그대로 옮기되 **정확한 ID 충돌 시 다음 글자**로 밀고(cascade 재번호 없음), 참조를 갱신한다(`FORGE-ROOT.md:62`, `skills/fg-merge/SKILL.md`). 시간ID는 시계에서 발급돼 병렬 브랜치가 공유 카운터에서 충돌하지 않는다.
- **엣지**: 매니페스트가 명시하듯 fg-merge는 `"an incoming NNNN collision"`(순차 ID 충돌)에서 **non-zero로 정지**한다 — 순차 세대는 동결됐으므로 새 브랜치가 순차 ID를 새로 만들지 않는 한 안전. 현재 대기 중인 브랜치 ADR은 시간기반이라 0001~0032와 충돌하지 않는다 `[중간]`.

**관련 내부 정합 관측** `[중간]`: `FORGE-ROOT.md:29`의 read-overlay 절이 ADR-0011의 `"branch-max+1"` 전제를 **개정**하며, 시간기반 ID 도입과 fg-merge 통합 재작성이 `"the fg-merge integration rewrite lands in task forge-merge-script-extract"`로 미룬다고 서술한다. 즉 문서상 ADR-0011 원문과 개정(overlay) 사이에 전제 차이가 남아 있어, ADR-0011 본문만 읽는 편집자는 옛 `max+1` 모델을 따를 위험이 있다. 편집 시 FORGE-ROOT.md의 개정 노트를 반드시 함께 참조할 것.

---

## 8. 그 밖의 취약 지점

- **fg-ask verbatim ↔ Forge integration 이중 계약** `[중간]`: `skills/fg-ask/SKILL.md`는 grill-with-docs 원본을 영문 verbatim으로 옮긴 본문과, 맨 아래 forge 루프 연결(백로그 산출·핸드오프·회고 환류) 섹션이 **따로 움직인다**(`CLAUDE.md`의 "알려진 불일치"). 둘 중 하나만 고치면 상태 계약이 깨진다.
- **스킬 식별자 = frontmatter `name`, 디렉터리명 아님** `[낮음]`: 자동 탐색은 `skills/*/SKILL.md`의 `name:`으로 한다. 디렉터리명과 `name`이 어긋나거나 `name:`이 누락되면 스킬이 조용히 로드 안 됨. 설치 전 검사: `awk '/^name:/' skills/*/SKILL.md`로 누락 확인(`CLAUDE.md` 배포 규칙).
- **`.claude/agents/` 세션 1회 로드 제약** `[낮음]`: fg-agents가 세션 중 만든 role 카드는 **재시작 전에는** fg-run이 픽업 못 한다(ADR-0024). 문서화된 의도이나, "만들자마자 안 됨"으로 오인하기 쉬운 함정.
- **스크립트 트윈(.sh/.js) 동기 부담** `[낮음]`: `scripts/`의 결정론 스크립트는 bash·node 쌍(예: `forge-done.sh`/`.js`, `forge-merge`, `forge-doctor`, `forge-status`, `resolve-forge-root`, `forge-statusline-full`)으로 존재하고 `*.parity.test.sh`가 등가성을 검사한다. 한쪽만 고치면 parity가 깨진다 — 스크립트 로직 수정 시 반드시 두 언어를 함께 갱신. fg-doctor가 트윈 누락을 잡는다.
