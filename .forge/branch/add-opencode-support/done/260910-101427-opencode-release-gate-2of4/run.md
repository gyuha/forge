# RUN — 릴리스 게이트·doctor를 3호스트로 일반화 (하드코딩 제거)

실행 방식: 워크플로우 없이 직접 실행. sh/js 트윈은 한 사람이 동시에 고쳐야 패리티가 유지되므로 분산 위임이 오히려 위험하다.

## 슬라이스별 결과
- S1 `release-check.sh` 호스트 목록 도출 — ✅ 계획대로. `hosts/*/`를 순회해 정렬한 목록을 쓰고, 목록이 비면 `no host adapters found under hosts/` 에러. capability 검증 루프도 같은 목록을 쓴다. ok 메시지도 `claude/codex/opencode`로 동적 출력.
- S2 `release-check.js` 동일 변경 — ✅ 계획대로. `readdirSync(withFileTypes)`로 디렉터리만, 정렬 동일. stdout/stderr/exit code 세 축 모두 sh와 일치 확인.
- S3 패리티 테스트 픽스처 + 케이스 — ⚠ 계획은 "opencode 픽스처 + 어댑터 누락 케이스 1건"이었으나 **5건으로 늘렸다**. 픽스처에 opencode를 넣는 것만으로는 "목록이 도출된다"를 증명하지 못한다(하드코딩 `['claude','codex']`로도 그 픽스처는 통과한다). 그래서 ① 3번째 호스트 어댑터 누락 ② 3번째 호스트 capabilities 검증 ③ 3번째 호스트 문서 쌍 요구 ④ **이름을 모르는 신규 호스트(`newhost`)** ⑤ `hosts/` 비어 있음 — 다섯을 추가했다. ④가 "하드코딩이 아니다"를 실제로 증명하는 유일한 케이스다. 22/22 통과.
- S4 docs 지원표 검사 순서 의존 — ⚠ 계획은 "태스크 3 완료 전에도 exit 0이 되도록 유예 처리"였으나, **태스크 순서를 3→2로 바꿔 해소했다**(게이트를 느슨하게 만들지 않는 쪽). 검사는 `claude`를 제외한 모든 호스트에 `docs/<host>.md`·`docs/en/<host>.md` 쌍을 요구하도록 일반화했고, claude 제외 이유(문서는 Claude Code 기준선으로부터의 *차이*를 적는 자리라 자기 자신과 비교할 페이지가 없다)를 스크립트 주석에 남겼다.
- S5 `forge-doctor` — ✅ 판정: **손대지 않음**. `grep 'hosts/' scripts/forge-doctor.{sh,js}` → 0건으로, doctor는 호스트 어댑터를 애초에 검사하지 않는다. 검사하지 않는 것을 일반화할 수는 없으므로 범위 밖.

## DoD baseline → after
1. `release:check` exit: 0 → 0 ✅
2. mutation(`hosts/opencode/execution.md` 제거): exit 0 · opencode 0건 → **exit 1 · opencode 1건** ✅ ← 본 검사
3. 패리티 테스트: exit 0 · opencode 0건 → exit 0 · opencode 9건 (케이스 22개) ✅
4. 테스트 스위트: 21/21 → 21/21 ✅ (regression guard)
5. `forge-doctor`: 0 errors → 0 errors ✅ (regression guard)

## 계획↔실제 차이 (divergence)
- **S3이 1건→5건으로 늘어난 것이 이번 실행의 핵심 교훈**이다. "opencode를 픽스처에 넣고 어댑터를 지워 본다"는 원래 계획은 **하드코딩된 목록으로도 통과하는 검사**였다 — opencode를 하드코딩 목록에 추가하기만 해도 초록이 된다. 즉 "목록이 도출된다"는 성질을 증명하려면 **스크립트가 이름을 모르는 호스트**가 필요하고, 그것이 케이스 ④다. PLAN-FORMAT의 (e) 규칙("DoD는 산출물의 *동작*을 재지 대리 지표를 재지 않는다")이 테스트 케이스 설계에도 그대로 걸린다는 사실.
- S4의 해법이 계획과 달랐다(유예 처리 → 태스크 순서 교체). 결과적으로 게이트가 더 엄격해졌다 — 앞으로 어떤 호스트를 추가하든 문서 쌍이 없으면 릴리스가 막힌다.
- S5는 계획이 열어 둔 조건부 슬라이스였고 "안 함"으로 닫혔다. 계획이 조건을 명시해 둔 덕에 판단이 필요 없었다.
