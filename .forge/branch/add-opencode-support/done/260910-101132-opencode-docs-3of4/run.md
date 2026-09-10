# RUN — opencode 지원 문서 이중언어 쌍 + 사이트 배선

실행 방식: 워크플로우 없이 직접 실행(문서 저작 3슬라이스, S2가 S1 구조에 종속).

## 슬라이스별 결과
- S1 `docs/opencode.md`(한글) — ✅ 계획대로. `docs/codex.md`의 5절 골격을 그대로 따르고, 지원표는 `hosts/opencode/capabilities.json`의 실제 값(9키 전부 `false`)을 반영하며 각 항목에 fallback 동작을 한 줄씩 달았다. 호스트 식별 신호 부재를 별도 문단으로 경고.
- S2 `docs/en/opencode.md` — ✅ 계획대로. `##` 헤딩 5개로 1:1, 지원표 행/열 일치.
- S3 VitePress ko/en 사이드바 배선 — ✅ 계획대로. 두 로케일의 '가이드/Guides' 그룹에 Codex 바로 다음 위치.

## DoD baseline → after
1. 두 파일 존재: 부재 → 존재 ✅
2. 9개 capability 키 명명: 전부 missing → 양쪽 `missing: none` ✅
3. ko↔en 짝 검사: 0줄 → 0줄 ✅ (regression guard — 새 ko 문서가 en 짝 없이 들어가지 않았음을 확인)
4. `##` 헤딩 수 일치: n/a → ko 5 = en 5 ✅
5. `npm run docs:build`: exit 0 → exit 0 ✅ (regression guard — 새 페이지의 dead link·미배선 없음)

## 계획↔실제 차이 (divergence)
- **의도적 전방 참조 하나**: 두 문서의 「릴리스 검사」 절이 "release:check가 `hosts/` 아래 모든 호스트를 검사한다"고 쓰고 있는데, **이 시점에는 아직 사실이 아니다** — 게이트 일반화는 태스크 2의 산출물이고, 그래서 정지 조건 C3가 지금 fail이다. 같은 주행 안에서 태스크 2가 바로 이어지고 C3가 이를 mutation test로 강제하므로 남겨 두었다. 주행이 태스크 2 전에 벽에 멈추면 이 문장은 거짓이 되므로, 그 경우 이 두 줄이 첫 수리 대상이다.
- **태스크 순서를 2↔3으로 바꿨다.** 계획 자체는 그대로지만 실행 순서가 `part:` 힌트와 어긋난다. 이유: 게이트를 3호스트로 일반화하면 capability 지원표 검사가 `docs/opencode.md`를 요구하는데, 그 문서가 없으면 태스크 2가 자기 DoD 1(`release:check` exit 0)을 만족시킬 수 없다. 게이트를 느슨하게 만들어 순서를 맞추는 대신 순서를 바꿨다 — `part:`는 PLAN-FORMAT상 soft 힌트이므로 계약 위반이 아니다.
