# RUN — opencode 호스트 어댑터 신설 + HOST.md 선택 규칙 확장

실행 방식: 워크플로우 없이 직접 실행. 5개 슬라이스 전부 문서 저작이고 S2~S5가 S1의 조사 결과에 순차 의존해 서브에이전트 팬아웃 이득이 없다(fg-run "Estimate cost first" 규정).

## 슬라이스별 결과
- S1 opencode 능력 문서 조사(스킬 로딩 경로·서브에이전트·환경변수) — ⚠ 계획은 "9개 각각 관측/미관측 판정 근거 한 줄"을 요구했으나, **관측 가능한 것이 하나도 없었다**. 업스트림 문서 증거가 있는 두 키(`spawn_parallel`·`spawn_role`)만 근거를 표로 남기고 나머지 일곱은 근거 없이 `false`로 두었다. HOST.md의 "관측된 것만 true" 규칙상 문서 증거는 관측이 아니다.
- S2 `hosts/opencode/capabilities.json` — ✅ 계획대로. 9키 전부 boolean, 전부 `false`.
- S3 `hosts/opencode/interaction.md` — ✅ 계획대로. `.forge/` 상태 필드 미등장(0건). "왜 전부 false인가" 절과 플립 후보 표를 추가로 담았다.
- S4 `hosts/opencode/execution.md` — ✅ 계획대로. `core/EXECUTION.md` 위임 링크 포함. 직렬 실행이라 `running.md`의 `workflow:`가 `pending`으로 남고 재진입이 4a case 3(보수적 확인)로 간다는 귀결을 명시.
- S5 `core/HOST.md` 선택 규칙 — ✅ 계획대로(추가만, 기존 Claude/Codex 판별 의미 불변). 규칙을 4→5번으로 밀고 opencode를 4번으로 삽입.

## DoD baseline → after
1. 어댑터 3파일 존재: 부재 → 존재(exit 0) ✅
2. capabilities 9키 boolean 검사: 파일 부재로 throw → `OK` (keys=9) ✅
3. `grep -c opencode core/HOST.md`: 0 → 7 (≥2) ✅
4. `grep -c 'hosts/opencode/' core/HOST.md`: 0 → 1 (≥1) ✅
5. `forge-doctor` exit 0 / 0 errors: 0 errors → 0 errors ✅ (regression guard — 기준선에서 이미 통과 중, 불변이 기대 결과)

## 계획↔실제 차이 (divergence)
- **큰 것 하나**: 계획은 opencode의 능력을 캐내 capability를 채우는 것을 암묵 전제했으나, 실제 판정은 **전부 `false`**로 끝났다. `HOST.md`가 "관측된 것만 `true`"를 못 박고 있고 opencode에서 forge를 실제로 돌려본 적이 없기 때문이다. 결과적으로 이 어댑터는 "이름 붙은 순차 폴백 + 플립 지점"이며, 이것이 정직한 최대치다. 대신 두 플립 후보(`spawn_parallel`·`spawn_role`)의 업스트림 근거를 표로 남겨 다음 사람이 관측만 하면 되게 했다.
- 호스트 식별 신호가 없다는 사실도 조사 중에 드러났다 — opencode는 모든 세션에 존재한다고 믿을 만한 환경변수를 노출하지 않는다. 그래서 선택 규칙 4번을 "명시적 호스트 메타데이터만"으로 좁히고, **다른 두 변수의 부재로 opencode를 추론하지 말 것**을 별도 문단으로 못 박았다(그 부재는 순차 폴백 자신의 조건이라, 추론하면 미상 호스트가 조용히 명명 호스트로 승격된다).
- `.opencode/` 매니페스트를 만들지 않았다 — opencode는 `.claude/skills/`를 그대로 읽으므로 필요가 없다(조사로 확인). 사용자가 정한 "어댑터 완비" 범위와도 일치.
