# 2026-06-09 — fg-merge 라이프사이클 e2e 테스트 (일괄 승급 2026-06-16)

## Plan vs actual
- What went as planned: 4슬라이스 — 일회용 git 샌드박스 3개(A 기계적·B 충돌-멈춤·C 전제 가드)에서 fg-merge 절차를 dogfood, 세 시나리오 전부 PASS. 실제 리포·릴리스 트리 불가침 확인.
- Divergences: 1건(경미·인라인 fix) — 시나리오 A에서 main에 `.forge/done/`가 없을 때 done 합침 실패. fg-merge가 대상 디렉터리(adr/retro/done) lazy 생성을 명시 안 한 갭 → 작업 내에서 "타깃 부재는 에러 아님, lazy 생성" 한 단락 추가 후 재검증 PASS. 설계 결함 아님(명시만 누락).

## Learnings
- Do differently next time:
  - **지시문 스킬(런타임 없음)도 실제 시나리오 dogfood로 검증 가능하다.** `mktemp -d` git 샌드박스 + 파일 조작으로 절차를 돌려 단언하면 된다. ADR-0009 검증 게이트가 forge 스킬엔 `n/a (런타임 없음)`로 떨어지던 사각을 메우는 방법 — 정적 grep < **샌드박스 dogfood** < 실사용 런타임의 검증 스펙트럼이 있고, 상태를 *변형*하는 유틸리티(fg-merge·fg-done·fg-cleanup)는 dogfood가 grep보다 훨씬 강한 증거를 준다. fg-doctor-retro-pairing-check(2026-06-15)도 같은 패턴(새 검사를 현 `.forge/`에 적용)으로 실증됨.
  - **파일을 이동/병합하는 유틸리티는 "대상 디렉터리가 없으면 만든다"를 빠뜨리기 쉽다** — 소스만 신경 쓰고 타깃 부재를 간과. 이동 절차를 스킬에 적을 땐 lazy-create를 명시할 것(이번 fg-merge 갭이 그 증거).

## Doc updates
- CONTEXT.md promotion: none (새 도메인 용어 없음 — 프로세스 학습)
- ADR added: none (fg-merge 계약은 ADR-0011, lazy-create 보정은 작업 중 fg-merge/SKILL.md에 인라인 반영됨)
