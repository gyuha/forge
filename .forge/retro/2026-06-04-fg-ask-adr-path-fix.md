# 2026-06-04 — fg-ask verbatim 본문의 ADR·CONTEXT 경로를 .forge/ 계약에 맞춰 정합 (루프 외 직접 수정)

## 계획 대비 실제
- 계획대로 된 것: 해당 없음 — forge 루프(plan→run)를 거치지 않은 검증·수정 작업이라 짝을 이루는 plan.md/run.md가 없다. 짝 plan이 없으므로 이 회고는 fg-cleanup 봉인 대상이 아닌 orphan 기록이다.
- 차이(divergence): README 검증 도중, ADR을 실제로 *생성하는* fg-ask의 grill-with-docs verbatim 본문만 upstream 경로 `docs/adr/`·루트 `CONTEXT.md`를 보유해, 나머지 계약 전체(`.gitignore` 화이트리스트 `!.forge/adr/`, ADR-FORMAT.md, fg-run·fg-learn·fg-cleanup·PLAN-FORMAT.md의 `.forge/adr/`)와 조용히 충돌하고 있었다. 그대로면 ADR이 `docs/adr/`에 생성돼 git 추적 누락 + 하위 스킬이 못 찾는 상태였다. → fg-ask/SKILL.md의 단일·멀티 컨텍스트 다이어그램과 lazy 생성 문장의 경로 문자열만 `.forge/` 기준으로 교정(그릴링 방법 텍스트는 불변). 멀티 컨텍스트에서도 ADR은 전역 `.forge/adr/` 단일 위치로 통일하고 글로서리(CONTEXT.md)만 코드 옆 유지로 결정.

## 학습
- 다음에 다르게 할 것: **외부 텍스트를 verbatim 이식할 때 verbatim의 경계는 '방법(method)'이지 '경로·이름'이 아니다.** 환경 종속적인 경로/식별자는 반드시 호스트 시스템 계약에 맞춰 정합해야 한다. 이식 직후 `grep -rn`으로 옛 경로(`docs/adr` 등) 잔존 여부를 전수 확인하는 절차를 이식 체크리스트에 넣을 것.
- 후속 함정 주의: CLAUDE.md "알려진 불일치" 섹션은 여전히 fg-ask 본문을 "영문 verbatim"이라 기술한다. 파일 구조 다이어그램 경로가 이제 upstream과 달라졌으므로, upstream grill-with-docs와 재동기화할 때 이 경로 교정이 되돌려지지 않도록 주의.

## 문서 갱신
- CONTEXT.md 승급: 없음 (`.forge/` 채택은 이미 ADR-0001에서 결정됨 — 이번 건은 누락분 정합일 뿐)
- ADR 추가: 없음 (되돌리기 어려움·의외성·트레이드오프 3조건 미충족)
