<!-- forge-slug: opencode-host-adapter-1of4 -->
<!-- task: 1 -->
<!-- part: 1/4 -->
<!-- priority: high -->
<!-- tdd: off -->
# opencode 호스트 어댑터 신설 + HOST.md 선택 규칙 확장

## Goal / Non-goals
- Goal: `hosts/opencode/{interaction.md,execution.md,capabilities.json}`를 신설하고, `core/HOST.md`의 어댑터 선택 규칙이 opencode를 식별하도록 확장한다. capability 값은 **관측된 것만 `true`** (HOST.md 규칙).
- Non-goals: release-check·fg-doctor·docs·README 갱신(태스크 2~4 소관). 스킬 본문(`skills/**`) 수정. opencode 설치 경로 신설. 버전 범프.

## Source of truth
- Glossary terms: 호스트 어댑터, capability — .forge/CONTEXT.md
- Related ADRs: `.forge/adr/260903-080713-*` (Codex 플러그인 매니페스트), core/HOST.md의 capability 계약
- Definition of Done:
  1. `test -f hosts/opencode/interaction.md && test -f hosts/opencode/execution.md && test -f hosts/opencode/capabilities.json` → exit 0 (사전 상태: 세 파일 모두 부재)
  2. `node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync('hosts/opencode/capabilities.json','utf8'));const k=fs.readFileSync('core/HOST.md','utf8').match(/^\| \`[a-z_]+\`/gm).map(s=>s.slice(3,-1));const ck=Object.keys(c);if(ck.length!==k.length||!k.every(x=>x in c)||!ck.every(x=>typeof c[x]==='boolean'))throw new Error('cap mismatch');console.log('OK')"` → `OK` (사전 상태: 파일 부재로 throw)
  3. `grep -c 'opencode' core/HOST.md` ≥ 2 (사전 상태: 0)
  4. `grep -c 'hosts/opencode/' core/HOST.md` ≥ 1 (사전 상태: 0)
  5. `bash scripts/forge-doctor.sh` exit 0, 0 errors (regression guard — 기준선에서 이미 통과 중이므로 회귀 방지용)

## Work slices
- [ ] S1. opencode의 실제 능력을 문서로 확인한다 — 스킬 로딩 경로(`.opencode/skills/`·`.claude/skills/`), 서브에이전트/task 도구 유무, 세션 시작 훅·중단 방지 훅 유무, 플러그인 루트 환경변수 유무. 완료 기준: 9개 capability 각각에 대해 "관측됨/미관측" 판정 근거 한 줄이 execution.md 또는 interaction.md 본문에 반영됨. 미관측은 전부 `false`.
- [ ] S2. `hosts/opencode/capabilities.json` 작성 — HOST.md 표의 9개 키를 정확히, 전부 boolean으로. 완료 기준: DoD 2 통과.
- [ ] S3. `hosts/opencode/interaction.md` 작성(codex 어댑터와 같은 분량·톤, 영문) — 질문 방식과 폴백만 소유하고 상태 모델은 복제하지 않음. 완료 기준: 파일 존재 + `.forge/` 상태 필드 이름이 등장하지 않음(`grep -c 'plan.md\|STATUS.md' hosts/opencode/interaction.md` → 0).
- [ ] S4. `hosts/opencode/execution.md` 작성(영문) — 위임 방식·핸들 회수·`running.md` 기록 계약을 opencode 실정에 맞게 서술하되 결과 정책은 `core/EXECUTION.md`로 위임. 완료 기준: 파일 존재 + `core/EXECUTION.md` 참조 링크 포함.
- [ ] S5. `core/HOST.md`의 "Select the adapter" 절과 어댑터 참조 문장에 opencode를 추가. 완료 기준: DoD 3·4 통과, 그리고 기존 Claude/Codex 판별 규칙의 의미가 바뀌지 않음(추가만).
