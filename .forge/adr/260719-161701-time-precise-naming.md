---
author: gyuha
decided: 2026-07-19 16:17
---
# ADR·done·retro 명명을 초 단위 시각(YYMMDD-HHMMSS)으로 통일

## 맥락
260716-13a가 ADR ID를 순차 `NNNN` → `YYMMDD-HH`+글자(시 단위)로 옮겼으나, 실사용에서 두 불편이 드러났다: (1) done/·retro/는 여전히 날짜만(`YYYY-MM-DD-slug`)이라 같은 날 여러 작업이 slug 알파벳순으로 섞여 **완료 순서가 안 보인다**, (2) ADR(`YYMMDD-HH`)과 done/retro(`YYYY-MM-DD`)의 **형식이 불일치**한다. 시(HH) 단위 granularity는 같은 시간대 작업에 늘 글자를 강제해 장황하기도 하다.

## 결정
ADR ID·done/·retro/의 명명을 **`YYMMDD-HHMMSS`(초 단위 로컬 시각) + 충돌 시에만 시리얼 소문자**로 통일한다.

- **기본은 글자 없음**(`260719-161701-slug`). 같은 초에 또 생성되면 다음 빈 글자 추가(`…161701a`, `b`…). bare = 같은-초 충돌 없음.
- **타임스탬프는 각 액션 시각**: ADR = 생성(fg-ask), done = 봉인(fg-done), retro = 회고(fg-learn).
- **ADR `decided`에 시각(분 단위) 추가**: `YYYY-MM-DD HH:MM` — provenance는 사람이 읽으니 분이면 충분하고, 파일명(초)과 용도가 다르다.
- **적용 대상**: ADR·done·retro만. `executed/`·`dropped/`는 전이 상태라 slug-only 유지.

## 트레이드오프 / 근거
- **연대순 정렬 + 형식 통일**: 초 단위라 같은 날/시 작업도 파일명만으로 완료 순서가 드러나고, 세 위치(ADR·done·retro)가 한 형식을 공유한다.
- **Grandfather(무손실)**: 기존 `NNNN`·`YYMMDD-HH` ADR과 `YYYY-MM-DD` done/retro는 그대로 둔다. 날짜만 있는 구 파일은 **초 시각이 아예 없어 진실한 마이그레이션이 불가**(mtime/git은 지어낸 값)하고, forge는 플러그인이라 사용자 프로젝트의 과거 파일을 대신 rename할 수 없다. 대신 **스크립트가 구·신 형식을 모두 인지** — 시각ID는 "`YYMMDD-` 뒤 2 또는 6자리 + 선택 글자", done/retro는 "`YYYY-MM-DD` 또는 `YYMMDD-HHMMSS[글자]`".
- **260716-13a 개정**: 시간기반·coordination-free·provenance 원칙은 유지하고, granularity(시→초)·글자 규칙(항상→충돌 시만)만 개정하며 done/retro까지 확장한다.

## 결과 (Consequences)
- 형식 문서 갱신: `ADR-FORMAT.md`·`RETRO-FORMAT.md`(·`PLAN-FORMAT.md`).
- 지시문 갱신: fg-ask(ADR 채번)·fg-learn(retro 명명).
- 스크립트 갱신(TDD): `forge-done`(done 디렉터리 명명 + 충돌 시리얼), `forge-status`/`forge-doctor`/`forge-merge`(구·신 다형식 파싱). test twin(behavior + parity)을 신형식으로 확장.
- 260716-13a에 개정 노트 추가.
- **3형식 공존**(`NNNN`·`YYMMDD-HH`·`YYMMDD-HHMMSS`)으로 스크립트 인식 복잡도가 늘지만, 무손실·무churn과 교환한다.

## 고려한 대안
- **마이그레이션(전부 rename)** — 날짜만 있는 구 파일에 초를 지어내야 하고, ADR citation 전수 수정·사용자 프로젝트 rename가 불가 → 거부(grandfather).
- **done/retro를 기존 ADR 형식 `YYMMDD-HH`에 맞추기** — 시 단위라 같은 시간 작업이 여전히 글자 필요·연대순 정렬이 약함 → 거부(HHMMSS가 정렬·유일성 우수).
- **초 단위에도 항상 글자** — 초 단위면 충돌이 드물어 늘 글자는 장황 → 거부(충돌 시만).
