<!-- forge-slug: issue-22-followups -->
<!-- task: 1 -->
<!-- tdd: off -->
# 후속 후보 원장과 기계 판독 상태 출력

## 목표 / 비목표
- 목표: 후속 후보를 followups.md에 영속 기록하고 fg-ask에서 채택 상태를 추적하며 --json으로 상태를 제공한다.
- 비목표: 과거 자유 제목 기록 자동 추출, 배포 버전 범프.

## 근거
- 이슈 추적: GitHub 이슈 #22
- 사용자 요청과 skills/fg-run/FORGE-ROOT.md, 기존 done/merge/status 트윈 계약.
- 완료 정의: loop.md C1~C3 동작 fixture와 기존 회귀 검사 통과. 새 기능 baseline은 미구현, 기존 검사는 회귀 방지 기준.

## 작업 단위
- [ ] S1. 후속 후보 형식과 저장/전이/봉인 구현 — 반복 저장에도 상태 보존, 봉인 실패 시 원본 보존 fixture 통과.
- [ ] S2. status JSON — 전체 작업/원시 상태/loop/followups를 파싱 가능한 JSON으로 반환, 텍스트 호환 유지.
- [ ] S3. 브랜치 통합 — followups 보존 및 task 참조 재매핑 fixture 통과 (depends: S1).
- [ ] S4. 스킬 생산/소비 경로와 양언어 사용자 문서 연결 — 모든 요청 경로 검토 및 docs build 통과 (depends: S1, S2, S3).
