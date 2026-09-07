---
author: gyuha
decided: 2026-09-07 14:06
---
# fg-debug — diagnosing-bugs를 vendoring하되 진단에서 멈추고 수정은 루프에 넘긴다

## Status
accepted

## 맥락
forge의 `verified: failed` 경로(fg-run fix-and-re-run · fg-loop 제자리 수리)는 수리를 지시하되 **원인을 어떻게 찾는지**는 말하지 않는다 — 진단 방법론이 비어 있다(GitHub 이슈 #19). mattpocock/skills의 diagnosing-bugs(MIT)는 그 구멍에 정확히 맞는 6단계 규율이다: 타이트한 red-capable 피드백 루프 구축 → 재현+최소화 → 가설 3–5개 랭킹 → 계측 → 수정 전 회귀 테스트 → 정리. 특히 Phase 1의 "이 버그에 red가 뜨는 명령 하나"는 forge가 방금 도입한 fix-forward eval 규칙(ADR `260906-171420`)의 red→green DoD가 요구하는 것 그 자체다.

## 결정
**결정 1: fg-security 패턴으로 vendoring한다 — 원문은 얼리고 접착은 래퍼가.** 원문 `SKILL.md`는 `skills/fg-debug/DIAGNOSE.md`로 개명해 바이트 그대로 두고(자동 탐색 충돌 회피 — fg-security의 AUDIT.md 선례), `scripts/hitl-loop.template.sh`·LICENSE 사본도 원형 유지한다. forge 계약(Explaining forge·핸드오프 표·언어 규칙·루프 접착)은 새로 쓰는 얇은 `SKILL.md` 래퍼가 전담한다. 기각: fg-ask식 verbatim 본문+integration 절 — 이 원본은 eval 규칙·대화 경계와 접점이 많아 verbatim 본문과 접착부가 계속 긴장한다. 기각: 개념 각색 — 138줄짜리 완결된 규율을 다시 쓰는 낭비이고 업스트림 추적이 죽는다.

**결정 2: fg-debug는 진단(Phase 1–4)에서 멈춘다 — 수정은 루프의 것이다.** 원본은 Phase 5–6에서 수정·정리까지 하지만, forge에서 봉인 없는 수정 경로는 재실행 방지·검증 게이트·eval 승급을 전부 우회하는 두 번째 차선이 된다. 진단 출구는 **호출 상태를 수정 크기보다 먼저** 판정한다. **활성 슬롯의 `verified: failed` 작업을 진단했다면 수정이 한 줄이어도 새 backlog plan이나 fg-quick으로 빠지지 않고**, 근본 원인 + red 명령 + 최소 재현 + 기각된 가설을 기존 작업의 fg-run fix-and-re-run 경로에 넘긴다 — 실패 작업은 수정 전 봉인할 수 없고 활성 슬롯이 찬 동안 새 plan도 승격할 수 있으므로, 새 plan은 교착을 만든다. **활성 실패 작업이 없는 독립 진단**에서만 크기를 판정한다: trivial이면 fg-quick, non-trivial이면 사람 승인 후 `<!-- generated-by: fg-debug -->` backlog plan으로 적재한다. 이 plan의 eval은 Phase 1 명령이 영속 체크인지 별도로 판정해 PLAN-FORMAT의 단일 규칙을 따른다; 일회성 curl·trace·HITL 명령이라는 이유만으로 규칙을 충족했다고 보지 않는다. "발견은 유틸리티, 수정은 루프"는 fg-security·fg-adversarial-review가 확립한 가족 계약이다.

**결정 2a: 불확정은 재현 루프 유무와 무관하게 명시적으로 끝낸다.** 루프를 만들지 못했다면 환경 접근·비밀 제거된 자료·임시 계측 허가를 요청한다. 루프는 있지만 원인을 확정하지 못했다면 확보한 red 명령·기각 가설과 함께 추가 계측·도메인 정보·재현 환경을 요청한다. 둘 다 가설만으로 plan을 만들지 않으며, 임시 산출물을 정리한 뒤 필요한 입력과 fg-debug 재호출 방법을 안내한다.

**결정 3: 새 `.forge/` 상태를 만들지 않되, 워킹 트리에 남길 수 있는 진단 산출물을 제한한다.** 비밀 제거가 확인된 최소 fixture와 영속 테스트만 프로젝트 워킹 트리에 둘 수 있다 — 우선순위는 원본 Phase 1 순서 그대로 "올바른 seam의 failing test"다. 인증 헤더·개인정보·비밀이 포함될 수 있는 원본 trace/HAR/log 캡처는 워킹 트리 밖의 임시 위치에서만 다루고, 성공·불확정·fg-quick 이관을 포함한 모든 종료 경로에서 삭제한다. 임시 계측과 throwaway harness도 진단 종료 시 제거한다. 수정에 꼭 필요한 안전한 산출물만 후속 작업에 명시적으로 인계하고, fix plan에는 Phase 6 cleanup slice와 검증을 포함한다. `.forge/debug/` 신설은 기각: 상태 계약·doctor·drop 파장이 줄줄이 딸려온다. 원본 캡처를 리포에 두는 것도 기각: runnable-DoD보다 비밀의 커밋·공유 위험을 우선 차단하며, 재현용으로는 비밀 제거된 fixture만 남긴다.

**결정 4: 이번 적대적 리뷰에서 드러난 계약 드리프트는 fg-doctor의 경고 검사로 영속화한다.** HANDOFF의 선언 개수·실제 적용자 수·CONTEXT의 적용 개수를 대조하고, fg-debug 래퍼가 활성 실패 복귀·영속 eval 판정·모든 종료 경로의 cleanup 계약을 잃으면 경고한다. bash/Node 트윈과 parity 테스트를 함께 둔다. 단순 문자열 존재 DoD가 9/9 green이면서 의미 모순을 놓친 것이 이번 결함의 잔존 원인이므로, 문서 수정만으로 끝내는 안은 기각한다.

**경계.** 무인 주행(fg-next all·fg-loop)은 fg-debug를 **항상 skip**한다 — 가설 랭킹을 사람에게 보여주는 대화형 스킬이고, fg-loop 제자리 수리는 bounded·marker-only 계약이라 6단계 규율을 얹으면 같은 계약에 모순 명령을 넣게 된다(F1 교훈). 배선은 둘뿐: 자연어 트리거 + fg-run `verified: failed` 핸드오프의 권고 한 줄. 이름은 `fg-diagnose`가 아니라 **`fg-debug`** — fg-doctor(forge 상태 건강)와 "진단" 어휘 충돌을 피하고 사용자 발화("debug this"·"디버깅해줘")에 직결시킨다.

## 결과
- `skills/fg-debug/` 4파일 신설(래퍼 SKILL.md + verbatim DIAGNOSE.md·hitl-loop.template.sh·LICENSE), 스킬 21 → 22.
- PLAN-FORMAT의 fix-forward eval 규칙 생산자 열거에 fg-debug 합류(하드 사정거리).
- fg-run `failed` 경로에 진단 권고 한 줄. 카탈로그 동기: 매니페스트 3·README 쌍·docs 쌍·CLAUDE.md·HANDOFF 적용자 목록(14 → 15곳 — README 쌍의 낡은 13도 이번에 정리).
