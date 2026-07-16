---
author: gyuha
decided: 2026-07-16
---
# ADR ID를 순차 번호에서 시간 기반 ID로 전환 (+ 저자/결정일 provenance)

## 맥락
forge를 팀(3~20명, feature 브랜치 + PR + fg-merge)에서 쓰려면 ADR이 다중 작성자를 견뎌야 한다. 순차 `NNNN`은 **전역 카운터**라 조율이 필요하다 — 두 사람이 병렬 브랜치에서 각자 `max+1`을 계산하면 같은 번호를 찍고, fg-merge는 통합 시 이를 재번호(placeholder 2-pass cascade 재작성)해야 한다. 이 cascade가 fg-merge의 가장 복잡한 기계이며, ADR 번호가 merge 전까지 확정되지 않아 교차참조가 깨지는 근본 원인이었다. 또 "누가 이 결정을 했나"가 어디에도 기록되지 않았다 — git blame은 fg-merge의 파일 이동·재작성과 PR squash/rebase로 흐려진다.

## 결정
1. **ID 스킴을 시간 기반으로 전환한다**: `YYMMDD-HH` + 소문자 순번(`a`~). 파일명 `<id>-slug.md`, 인용 `ADR-<id>`(예: `ADR-260716-14a`). 그 시(時)의 기존 ID 글자를 스캔(`retired/` 포함)해 다음 빈 글자를 배정하고, 같은 시 충돌이 흔하므로 **첫째부터 항상 글자**를 단다. 배치 생성·크로스 브랜치 우연 충돌 모두 "다음 빈 글자" 단일 규칙으로 처리 — cascade 재번호가 죽는다. 시계에서 민팅하므로 조율 없이 충돌-불가에 가깝고 ID가 생성 시점에 확정되어 교차참조가 안 깨진다.
2. **저자 provenance**: frontmatter `author:`(생성 시 `git config user.name`, 없으면 1회 질문) + `decided: YYYY-MM-DD`. 파일 내용에 실려 fg-merge 이동에도 보존된다(git blame과 정반대 장점).
3. **기존 32개 `NNNN` ADR은 grandfather** — 동결, 재작성·백필 없음. 두 형식이 유효 ID로 공존한다. 수백 개 `ADR-NNNN` 인용 rewrite는 고위험이라 하지 않는다.
4. **fg-ask는 ADR을 전부 본문 읽지 않고 앞 2줄(제목+첫 문장+frontmatter)로 트리아지**한 뒤 관련분만 본문 fetch한다(#3, retro/map 선택적 읽기와 동형) — 장기 프로젝트의 토큰 팽창·새 결정 방해 완화. 파생 인덱스는 sync/drift 부담이 merge 문제를 키우므로 만들지 않는다.

## 트레이드오프 · 기각
- **가독성 vs 조율-프리**: `ADR-260716-14a`는 `ADR-12`보다 구두 참조가 나쁘다. 파일명 slug이 남아 사람은 주제로 부르고 타임스탬프는 유일 prefix 역할만 하므로 수용. 초 단위(`HHMMSS`)는 충돌을 사실상 0으로 만들지만 가독성 대가가 커, 시 단위 + 글자 접미사로 결정(같은 시 충돌은 글자로 국소 해소, cascade는 어차피 죽음).
- **task 번호(`<!-- task: N -->`)는 범위 밖** — 개인적·휘발적·선택 전용("run #7")이라 작은 정수가 UX상 낫고 영속 교차참조가 없으며 fg-merge remap이 충돌을 처리한다. 같은 다중작성자 문제가 있으나 전환 이득<비용.
- **CONTEXT/retro provenance·index 기각** — CONTEXT는 작고 git blame으로 충분(fg-merge가 파일 이동 안 함); retro는 기존 "같은 영역+최근 3~5" 선택 유지. 파생 인덱스 남발 금지(YAGNI).

## 결과 (Consequences)
- fg-merge의 ADR cascade 재번호 절차는 "충돌 시 다음 글자" 국소 규칙으로 대체된다(구현은 별도 작업 `forge-merge-script-extract`). 이 ADR 봉인과 그 작업 봉인 사이에는 ADR-FORMAT(신 규칙)과 fg-merge 본문(구 cascade 서술)이 일시적으로 어긋나는 전이 상태가 존재하며, 후속 작업이 해소한다.
- 이 결정은 **ADR-0011을 부분 개정**한다 — ADR-0011의 "번호 충돌을 생성→머지 재부여로 미룸"(:18)·"timestamp id 거부"(:28)·"브랜치 채번 `max+1`"(:32) 하위 결정을 뒤집는다(브랜치 격리·fg-merge 통합이라는 ADR-0011 핵심 결정은 그대로 유지). 단일 정의 `skills/fg-run/FORGE-ROOT.md`의 채번 절과 ADR-0011:32에 개정 포인터를 함께 남긴다.
- 이 ADR 자체가 forge의 **첫 시간 기반 ID**로, 새 스킴을 dogfood한다.
