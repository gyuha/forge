<!-- forge-slug: opencode-docs-3of4 -->
<!-- task: 3 -->
<!-- part: 3/4 -->
<!-- priority: medium -->
<!-- tdd: off -->
# opencode 지원 문서 이중언어 쌍 + 사이트 배선

## Goal / Non-goals
- Goal: `docs/opencode.md`(한글)·`docs/en/opencode.md`(영문)를 `docs/codex.md` 쌍과 동일한 절 구조로 신설해 9개 capability 지원표를 담고, VitePress 사이드바/네비에 배선해 빌드가 통과하게 한다.
- Non-goals: 랜딩 `docs/index.html` 개편. README 갱신(태스크 4). 기존 codex 문서의 내용 변경(배선 외).

## Source of truth
- Glossary terms: capability, 호스트 어댑터
- Related ADRs: ADR `260815-094725`(문서 사이트 배포)
- Definition of Done:
  1. `test -f docs/opencode.md && test -f docs/en/opencode.md` → exit 0 (사전 상태: 둘 다 부재)
  2. 두 문서가 9개 키를 전부 명명: `for d in docs/opencode.md docs/en/opencode.md; do for k in $(grep -oE '^\| `[a-z_]+`' core/HOST.md | sed -E 's/^\| `([a-z_]+)`/\1/'); do grep -qF "\`$k\`" "$d" || echo "missing $k in $d"; done; done` → 출력 0줄 (사전 상태: 전부 missing)
  3. `for f in docs/*.md; do [ -f "docs/en/$(basename "$f")" ] || echo "missing: docs/en/$(basename "$f")"; done` → 출력 0줄 (사전 상태: 통과 중 — regression guard, 새 ko 문서가 en 짝 없이 들어가는 것을 막음)
  4. 두 문서의 `##` 헤딩 개수가 동일: `[ "$(grep -c '^## ' docs/opencode.md)" = "$(grep -c '^## ' docs/en/opencode.md)" ]` → exit 0
  5. `npm run docs:build` → exit 0 (사전 상태: 통과 중 — 새 페이지의 dead link/미배선을 잡는 regression guard)

## Work slices
- [ ] S1. `docs/codex.md`의 절 구조를 뜯어 동일 골격으로 `docs/opencode.md` 작성(한글) — 지원표는 `hosts/opencode/capabilities.json`의 실제 값을 반영하고, `false`인 항목에는 폴백 동작을 한 줄로 적는다. 완료 기준: DoD 2 중 한글판.
- [ ] S2. `docs/en/opencode.md` 작성 — S1과 절 구조 1:1(헤딩 개수·순서·표 행/열 일치), 링크는 영문판 안에서 닫히게. 완료 기준: DoD 2·4.
- [ ] S3. VitePress 설정(`docs/.vitepress/config.mts`)의 ko/en 사이드바 양쪽에 새 페이지 배선. 완료 기준: DoD 5 통과 + 두 로케일 사이드바 모두에 항목이 존재.
