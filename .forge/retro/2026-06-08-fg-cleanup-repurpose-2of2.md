# 2026-06-08 — 신규 fg-cleanup (part 2/2): ADR 은퇴 유틸리티

## 계획 대비 실제
- 계획대로 된 것: 6슬라이스 전부 완료. `skills/fg-cleanup/SKILL.md` 신규(루프 밖 유틸리티, 첫 줄 의도 확인, A+ 후보 제시→사람 승인, `retired/` 이동+마킹, 번호 불변·재사용 금지·삭제 안 함·교차참조 비재작성), fg-ask가 `retired/`를 정답소스에서 제외, gitignore `retired/` 추적 확인, 매니페스트 11개·metadata 불변, CLAUDE/README 양 언어 동기. 스킬 자동탐색 11개(fg-cleanup·fg-done 공존).
- Divergences: 거의 없음. dogfood 결과 **은퇴 후보 0개**(0001~0012 전부 현역 누적 로그) — 예상된 정상 결과.

## 학습
- Do differently next time:
  - **"스킬명 vs stage/도메인 단어" 구분은 개명뿐 아니라 검증에서도 함정이다.** part 1(개명)에서 `fg-cleanup`(스킬)→`fg-done`은 치환하되 `cleanup`(④ stage 단어)은 유지했고, part 2 검증에서 `metadata.description.includes('cleanup')`가 stage 단어에 false-positive를 냈다. 토큰 경계로 치환·검증 범위를 좁히고, "이 단어가 스킬 식별자인가 일반 단어인가"를 매번 구분할 것.
  - **dogfood의 0-결과도 유효한 검증이다.** 신규 fg-cleanup을 이 리포에 돌려 "은퇴할 ADR 없음"을 확인한 것 자체가 도구의 빈-경로(후보 없음)를 실증한다. 은퇴 후보가 0이라고 도구가 미완성인 게 아니다 — "치울 게 없음"을 안전하게 보고하는 경로가 동작함을 본 것.
  - **ADR 제목에 스킬명을 박으면 개명 내성이 떨어진다.** ADR-0009 제목 "봉인 전 검증 게이트 — ... fg-cleanup 가드"가 개명 후 역사↔현재 명칭 불일치를 만들었다(결정은 현역이라 은퇴 대상은 아니고 ADR-0012가 다리를 놓음). 향후 ADR 제목은 stage/결정 중심으로 쓰고 스킬명 의존을 줄이면 개명에 강하다. (관례로 명문화하려면 별도 작업 — 지금은 retro log에 남겨 다음 ADR 작성 fg-ask가 참고.)

## 미해소 후속
- branch isolation의 **fg-merge 라이프사이클 end-to-end 테스트**(2026-06-08-branch-isolation-2of2 회고에서 나온 후속)는 여전히 미수행 — 그 전 배포 보류. 이번 작업과 독립.
- (선택) ADR 제목 관례를 ADR-FORMAT.md/CLAUDE.md에 명문화할지 — 별도 작업 후보.

## 문서 갱신
- CONTEXT.md 승급: 없음 (도메인 용어 없음)
- ADR 추가: 없음 (이 작업이 구현한 결정은 ADR-0012에 이미 기록됨 — 신규 ADR 아님)
