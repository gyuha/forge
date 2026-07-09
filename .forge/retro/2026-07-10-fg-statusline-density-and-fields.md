# 2026-07-10 — fg-statusline 개선 (밀도 토글 + 가이드 필드 + 구분자/라벨 원복 + 색상 + 그룹 대괄호 + 재배치)

## 계획 대비 실행
- 계획대로 된 것:
  - S1~S5 전부 구현·검증. 밀도 토글(compact/full, command 위치 인자)·세 신규 필드(Context/크기·동적 이모지+그라디언트 바·$비용/±라인)·`|`/`Context` 원복·가이드 팔레트 색·의미 단위 그룹 대괄호(전역)·세션 그룹 L1 재배치·`🧪`/`♻️` 지시자·verified flag 위치·density-aware fragment.
  - 테스트 6종 green(fragment 35·fragment PARITY OK·full 32/32·full PARITY OK·wrapper 7)·manifest OK·설치본 라이브 스모크 일치·sh↔node 동일. ADR-0029(2026-07-10)·ADR-0017 개정.
- Divergences (전부 저-divergence·예견/사소):
  1. 실행 순서를 S3(fragment)→S1/S2/S4(full)로 재조정 — full이 fragment에 위임하므로 토대 먼저. #71 교훈의 자연스러운 귀결.
  2. Dynamic Workflow 대신 직접 실행 — 완전 직렬 + 정밀 계약 보유 → 위임 드리프트 회피. fg-run 비용판단 + #71·fg-merge 선례.
  3. TDD를 전-포맷 리라이트에 맞게 적용(계약-수준 red→green).
  4. fragment 모드-지시자 idle 게이트(계획 미명시 보정).
  5. compact 코너 케이스(항상 한 줄·📋 N 카운트·📝 생략) 실행 중 확정.
  6. plan의 ADR-0022 파일명 오기(존재하는 파일, 비차단).

## 학습
- 다음에 다르게 할 점:
  - **위임 구조는 토대부터 구현한다.** full→fragment처럼 A가 B의 출력을 소비하면, B(fragment)를 먼저 구현·green 시킨 뒤 A(full)를 얹어야 A의 테스트가 실재 B 출력에 대고 검증된다. #71은 "직렬로 계획하라"였는데, 여기에 **"직렬 순서 = 피위임자(토대) 먼저"**를 더한다. 계획의 slice 번호(S1=full 먼저)와 실제 구현 순서(fragment 먼저)가 어긋날 수 있음을 계획 단계에서 인지할 것.
  - **전-포맷 리라이트에서는 계약-수준 TDD.** 출력 포맷 전체가 바뀌어 거의 모든 픽스처가 동시에 변경되는 작업은, 슬라이스별 micro red→green이 비현실적(각 슬라이스가 픽스처를 반쯤 갱신한 상태를 남김). 대신 **새 계약 전체를 갱신 픽스처에 못박아 red를 만들고 구현으로 green**을 만드는 게 낫다 — 테스트가 계약을 핀하고 통과하는 TDD 규율은 그대로 유지되면서 중간 broken 상태를 피한다. tdd:on이어도 이 형태가 정답인 작업 유형이 있다.
  - **표시 지시자를 옮길 땐 "idle엔 아무것도"(ADR-0017)를 재확인.** 모드 지시자(🧪/♻️)를 line 1→line 2로 옮기니 eco가 전역 config라 idle repo에도 `[♻️]`가 샐 뻔했다. 지시자는 **실활동(활성 작업/큐)에서만** 렌더하도록 게이트해야 fragment의 핵심 원칙이 유지된다. 지시자 재배치 = 게이트 재점검 트리거.
  - **밀도/변형 UI는 흔한 케이스만 스케치하면 코너가 미결로 남는다.** compact를 활성-작업 케이스로만 스케치받아, "활성 작업 없는 compact"·"큐만 있는 compact"·"await 표기"가 구현 시 미결이었다. 밀도 변형을 합의할 때 idle·부분-상태 변형까지 한 번 훑을 것.
  - plan에서 ADR을 인용할 땐 실제 파일명을 확인(`ls .forge/adr/NNNN-*`)해 슬러그 오기를 막는다.

## Doc updates
- CONTEXT.md 승급: none (`FORGE_SL_SEP`·density는 구현 env/인자 — 도메인 용어 아님)
- ADR 추가: none (설계 결정은 실행 중 ADR-0029 2026-07-10 개정 + ADR-0017 개정에 이미 기록)
