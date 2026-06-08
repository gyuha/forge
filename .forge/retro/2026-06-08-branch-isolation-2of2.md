# 2026-06-08 — fg-merge 스킬(part 2/2): 브랜치 forge 내용을 .forge/로 통합

## 계획 대비 실제
- 계획대로 된 것: 4슬라이스 전부 완료. `skills/fg-merge/SKILL.md` 생성(선행조건 git merge 먼저·part1 FORGE-ROOT 참조·통합 대상 adr/retro/CONTEXT/done·전역 예외 config/codebase 제외·ADR 재부여 절차·기계적 자동/충돌 시 대화·브랜치 폴더 제거·텍스트 흐름도). 매니페스트 Nine→Ten·metadata 불변·JSON 유효. CLAUDE 루프-밖 목록 + README 양 언어 동기. 2차 Codex 리뷰의 [high] "fg-merge 없이 branch isolation 배포 금지"가 이 작업으로 해소(자동탐색 10개 확인).
- Divergences: 거의 없음. S2(ADR 재부여)를 별도 슬라이스로 두지 않고 S1 본문에 통합 기술한 정도. 검증은 `verified: n/a` — fg-merge는 런타임 없는 지시문 스킬이라 정적 검증(name 자동탐색·6요소·절차·참조·매니페스트·JSON)만 수행.

## 학습
- Do differently next time:
  - **계약을 바꾸는 기능은 통합/되돌림 경로까지 한 묶음으로 계획하라.** branch isolation은 part1(격리·충돌 차단)만으론 no-ship였고, part2(fg-merge 통합 경로)가 생겨야 완결됐다. 다음에 상태 계약·데이터 모델을 바꾸는 작업을 fg-ask로 그릴 때, "되돌리거나 합치는 경로"를 처음부터 같은 작업 묶음(또는 명시적 후속 part)으로 잡을 것 — 그래야 중간 상태로 stranded되지 않는다.
  - **지시문 스킬은 ADR-0009 검증 게이트가 구조적으로 n/a로 떨어진다.** forge는 통째로 "에이전트가 읽고 실행하는 지시문" 리포라, 거의 모든 작업이 런타임 없어 `verified: n/a`가 된다. 정적 grep은 "문서가 맞나"만 보고 "실제로 동작하나"는 못 본다 — 실동작은 라이프사이클을 직접 돌려야(dogfood) 확인된다. 다음에 forge 스킬을 검증할 땐 정적 검증에 더해, 가능하면 실제 시나리오 dogfood를 UAT 증거로 넣을 것. (지금은 한계 관찰에 그침 — 정책 결정으로 굳으면 그때 ADR감.)
  - **큰 계약 변경엔 외부 적대적 리뷰가 실질 가치.** 이번에 Codex 적대적 리뷰가 2회에 걸쳐 (1차) 스코프 누락(fg-map/fg-tdd), (2차) no-ship(fg-merge 없이 배포 금지)을 잡아냈다. ADR-0007(조건부 코드리뷰)의 실증 사례. 다음 큰 계약 변경에도 적대적 검증을 붙일 것.

## 미해소 후속 (중요)
- **fg-merge 실제 라이프사이클 end-to-end 테스트 미수행 → 그 전엔 배포 보류.** 검증 시나리오: 브랜치-로컬 ADR/CONTEXT/retro/done 생성 → git merge → fg-merge 실행 → 번호 재부여·교차참조 갱신·상태 가시성·브랜치 폴더 정리 확인. 봉인 후 fg-ask로 별도 작업화할 후보.

## 문서 갱신
- CONTEXT.md 승급: 없음 (도메인 용어 없음)
- ADR 추가: 없음 (학습 3건 모두 retro log 잔류 — ②는 borderline이나 아직 결정 아닌 한계 관찰이라 미승급)
