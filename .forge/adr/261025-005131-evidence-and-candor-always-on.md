---
author: gyuha
decided: 2026-10-25 00:51
---
# 근거 라벨과 "동의가 기본값이 아니다"를 항상-on 규율 `Evidence and candor`로 둔다

## Status
accepted

## 맥락
pstack(Lauren Tan, MIT — `cursor/plugins`의 `pstack/skills/poteto-mode/SKILL.md`)의 응답 규율 두 개를 forge에 들이려는 요청에서 출발했다.

- *"Every claim carries its evidence or its label in the same sentence. Measured, inferred, or guess. A prediction or an unseen cause is a guess. Never hand the human a check you could run."*
- *"No is an acceptable answer. … A recommendation is a judgment, not a validation. Agreement is not the default, candor over sycophancy."*

forge에는 둘 다 없었다. `skills/`·`core/`에 주장의 근거 등급을 요구하는 규칙은 0건이고, fg-ask 본문은 "질문마다 추천 답을 제시하라"고만 할 뿐 사용자 선택지에 대한 반대를 요구하지 않는다. 작성자 개인 CLAUDE.md의 확신도 태그는 그 사람의 환경에만 적용되어 forge 설치자에게 전달되지 않는다.

## 결정
**한 줄 canonical `scripts/evidence-and-candor.rule.txt`를 24개 `SKILL.md`에 `**Evidence and candor**` 문단으로 인라인하고(fg-ask는 Forge integration 불릿), fg-doctor B17이 `scripts/*.rule.txt` 전부를 대조하도록 일반화한다.**

- **라벨은 출처 축 3단계**: 측정·추론·추측. canonical 이름은 영문, 화면은 사용자 언어. "미확인"은 4단계로 만들지 않는다 — 라벨이 아니라 주장이 없는 상태다.
- **확인 우선**: 싸게 확인할 수 있으면 라벨 대신 확인한다. 이 짝 규칙이 없으면 라벨이 확인 회피 면허가 된다.
- **적용면은 대화와 생성 문서(plan·run 기록·회고·ADR) 모두**. 결정론 스크립트 출력은 이미 측정이라 예외.
- **반대 규율 3항**: 판단 먼저(가장 강한 반론, 참이면 "하지 말 것"), 입장 변경은 새 사실·논증으로만, 결정은 사람 — 반대는 한 번 밝히고 사람의 결정대로 진행하며 재논쟁·몰래 다르게 실행하지 않는다.

## 트레이드오프 / 결정 근거
- **문서까지 넓힌 이유 — 문서 속 추측은 번식한다.** 대화의 틀린 말은 그 자리에서 사라지지만 회고에 사실처럼 적힌 추론은 다음 fg-ask의 출발점이 된다(기둥 2). fg-map `#105`의 상속된 거짓 3건이 실례다. 이 점에서 생성 문서를 적용면에서 뺀 `Explaining forge`(ADR `260824-134246`)와 **의도적으로 다르다**.
- **`Explaining forge`에 합치지 않은 이유**: 한 문단 안에서 적용면이 모순된다(대화만 vs 문서 포함). 관심사도 다르다(어휘 vs 정직성).
- **인라인을 참조 파일보다 택한 이유**: 약 5문장으로 `Explaining forge`(3문장)와 ECO.md(40줄)의 사이이며, ADR `260824-134246`의 "3줄은 파일을 못 번다" 논거가 그대로 성립한다. 대가인 24중 복제 드리프트는 B17이 막는다.
- **B17을 새 검사 대신 일반화한 이유**: 같은 종류의 검사를 두 번 구현하지 않고, 다음 규율은 파일 하나로 늘릴 수 있다. canonical은 **한 줄이어야 한다** — `.sh`의 `grep -qF -e`는 여러 줄 패턴을 줄별 OR로 해석해 `.js`의 `includes`와 판정이 갈라진다.
- **알려진 한계**: 라벨 *누락*은 기계로 못 잡는다. 사용자 언어 산문에서 "라벨 없는 주장"을 찾는 탐지기는 부정확함이 실측됐다(의제 결정 8 개정). doctor가 보장하는 것은 규칙 원문의 존재뿐이다.

## 고려한 대안
- **`Explaining forge`에 덧붙이기** — 거부: 위의 적용면 모순, ADR `260824-134246` 개정 필요.
- **단일 정의 문서 + 24곳 참조 한 줄** — 거부: 읽는 에이전트가 파일을 한 번 더 열어야 하고, 참조 누락을 막는 장치가 따로 필요하다.
- **판단 지점(fg-ask 추천·UAT·회고·리뷰)에만 적용** — 거부: 범위 판정이 모호해 기계 강제가 불가능하다.
- **확신도 축 병기** — 거부: 문장당 태그 소음이 두 배이고, 사용자가 원한 것은 출처 축이다.
- **원문 반대 규율만(반복 압박·결정권 미규정)** — 거부: 결정권 미규정이면 그릴링이 논쟁 루프가 되고, 반복에 접으면 동의가 기본값으로 돌아간다.

## Consequences
- 새 스킬은 `Explaining forge`와 함께 `Evidence and candor` 문단도 담아야 하며, 빠뜨리면 B17이 warning으로 잡는다.
- canonical을 바꾸려면 rule 파일과 24개 `SKILL.md`를 함께 고친다.
- 개념 각색이며 코드 vendoring이 아니다(파일 복사 0). 크레딧은 README 이중언어에 둔다.
