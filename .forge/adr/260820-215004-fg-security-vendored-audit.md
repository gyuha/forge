---
author: gyuha
decided: 2026-08-20 21:50
---
# fg-security — cloudflare security-audit-skill을 vendoring한 루프 밖 보안 감사 스킬 (감사 상태는 최상위 `.forge/security/` 전역 예외)

## Status
accepted

## 맥락

"cloudflare/security-audit-skill을 레퍼런스 삼아 fg에 보안 감사 스킬을 만들어 달라"는 요구가 왔다(GitHub 이슈 #13). [해당 스킬](https://github.com/cloudflare/security-audit-skill)(MIT, 별 2,944개, 최근 커밋 2026-07-06)은 6단계 다중 에이전트 감사다 — recon → 병렬 전문 hunting → 검증 → 리포트 → machine-readable `findings.json` → 후속. 공격 유형별 플레이북 9종(`ATTACK-CLASSES`·`WEB-PROTOCOL-AND-AUTH`·`CLIENT-SIDE`·`AI-AND-LLM`·`MEMORY-SAFETY-AND-BINARY` 등)과 `report-schema.json`·`validate-findings.cjs`를 갖추고 명시적으로 agent-neutral하다. 정직한 설계까지 있다 — *"best single run finds roughly half the total vulnerabilities"*라며 복수 실행을 권하고 이전 `findings.json`을 읽어 중복을 건너뛰고 빈 영역을 겨눈다.

**forge에 이미 보안 커버리지가 있다는 첫 판단은 틀렸다.** `fg-adversarial-review`의 렌즈 4가 "Security · performance · data loss"이지만 그것은 **일반 리뷰의 6분의 1**이고, 이쪽은 플레이북 9종을 갖춘 도메인 특화 감사다. 규모가 다르다.

## 결정

**`fg-security`를 루프 밖 on-demand 유틸리티 스킬로 신설하고, cloudflare 스킬을 vendoring한다.**

**1. `fg-adversarial-review` 확장이 아니라 별 스킬이다.** ADR-0018은 개정(2026-06-14, Codex 적대적 리뷰 반영)으로 *"대상 범위는 활성 슬롯 작업 전용"*을 못 박고 findings 저장처를 활성 슬롯 동반 휘발 `review.md`로 정했다. 그런데 보안 감사의 대상은 **작업이 아니라 코드베이스 전체**이며, 리포별 `findings.json`을 **여러 실행에 걸쳐 유지**해 이전 결과로 빈 영역을 겨눈다. 주제와 상태 모델이 둘 다 다르므로 렌즈 교체로 흡수할 수 없고, 흡수하려면 그 개정이 세운 경계를 깨야 한다.

**2. Vendoring한다 — 얇은 래퍼도, 안 만들기도 아니다.** 얇은 래퍼(방법론은 설치된 외부 스킬에 위임)는 ADR-0007이 *"외부 code-review 스킬 하드 의존 — 거부: 이식성"*으로 **두 번 명시 기각**한 형태다. 안 만들기(사용자가 `.claude/skills/`에 직접 넣어 쓰기)는 forge가 더할 수 있는 유일한 값 — findings가 루프에 들어오는 것 — 을 버린다. 선례는 `fg-visual`이 superpowers 5파일을 MIT 귀속과 함께 복제한 것(ADR `260719-224442`)이고, **그 ADR의 결정 6이 "vendored 업스트림 파일은 bash+node 트윈을 만들지 않고 원형을 유지한다"고 ADR-0022 예외를 이미 명문화**해 뒀으므로 `validate-findings.cjs`에 트윈이 필요 없다. 드리프트 비용은 실측으로 낮았다(업스트림 최근 커밋 2026-07-06, 6주 안정).

**3. 파일 구조는 fg-visual 방식이고 fg-ask 방식은 의도적으로 피한다.** forge가 쓴 짧은 `SKILL.md`(진입·상태·게이트·변환·무인 skip·핸드오프) + vendored 파일 12개는 원형 유지 + `LICENSE` 사본. 업스트림 진입 파일만 `AUDIT.md`로 개명하는데, 이유가 실질적이다 — forge는 `skills/<name>/SKILL.md`로 스킬을 **자동 탐색**하므로 그 이름을 그대로 두면 충돌하고, 하위 디렉터리에 두면 **중첩 SKILL.md가 스킬로 오탐될 위험**이 있다. 나머지 11개는 파일명·내용 그대로여서 업스트림 diff가 쉽다. **fg-ask의 "업스트림 본문 verbatim + 맨 아래 Forge integration 절" 방식은 채택하지 않는다** — CLAUDE.md가 그 구조를 「현재 상태의 알려진 불일치」에 올려 *"둘 중 하나만 고치면 계약이 깨진다"*고 적었으므로, 모델이 아니라 문서화된 흠이다.

**4. 감사 산출물은 최상위 `.forge/security/`에 산다 — 새 전역 예외다(이 ADR의 핵심).** `config.json`·`codebase/`·`visual/`에 이어 네 번째 전역 예외이고, **브랜치별 forge 루트(ADR-0011)에 두지 않는다.** 근거는 구체적이다: `.gitignore`가 `!.forge/branch/`로 비-기본 브랜치의 루트를 **통째로 추적**하므로, 브랜치에서 감사를 돌리면 findings가 커밋·push되어 **공개 리포에 착취 가능한 취약점 목록이 게시된다**(이 리포는 PUBLIC이다). `fg-visual`이 같은 이유로 브랜치 루트를 거부했고(그때 대가는 mockup HTML 혼입, 이번은 취약점 공개), `.gitignore`의 `.forge/*` 기본 제외가 **수정 없이** 이를 덮는다.

**감수하는 대가를 정직하게 적는다** — findings가 git 추적되지 않으므로 **팀 공유가 안 되고 머신을 바꾸면 사라진다.** 업스트림이 다중 실행 메모리로 쓰는 `findings.json`이 바로 그 대상이라 "이전 실행을 읽어 빈 영역을 겨눈다"는 이점이 머신 로컬로 한정된다. 취약점 노출을 피하는 값과 맞바꾼 것이다.

**기각한 대안**: 업스트림 기본값 `~/security-audit-skill/<repo>/run-N/` 유지(리포 밖이라 커밋 경로가 아예 없어 **안전성은 더 강하다**) — 그러나 ADR-0001("모든 forge 문서는 `.forge/` 아래")을 어기고, findings→plan 변환이 `.forge/` 밖을 참조하게 되며, 홈 디렉터리 깊은 곳의 리포트는 사람이 실제로 안 본다. (b)의 잔여 위험은 "누군가 `!.forge/security/`를 화이트리스트에 넣거나 `git add -f`를 하는 것"으로 규율에 의존하고, 이 비대칭은 인정한다.

**5. findings → 백로그 plan은 심각도 게이트 + 사람 승인이다.** CRITICAL/HIGH는 plan 제안(같은 코드 경로면 묶기), MEDIUM은 제안하되 묶기 권고, **LOW/INFO는 리포트에만 남기고 plan을 만들지 않는다.** 이것이 forge의 다른 모든 승급 바(회고 승급·ADR 3조건·CONTEXT.md)와 같은 모양이다 — "전부 승급하면 진짜 중요한 것이 묻힌다". 전부 자동 생성은 기각: 승인 없는 plan 생성은 ADR-0018이 금지하고, 실제 감사는 findings 5~20건을 내므로 **백로그 홍수로 활성 슬롯 1개 규율이 무의미**해진다. 생성 plan은 `<!-- generated-by: fg-security -->` 마커 + 단조 `task:` 번호(ADR-0018 동형)이고, DoD는 *"그 취약점이 더는 재현되지 않음"* — 업스트림이 MEDIUM+ findings의 데이터 흐름을 `FINDINGS-DETAIL.md`에 남기므로 그 재현 경로가 ADR-0009 검증 게이트를 자연스럽게 채운다.

**6. 무인 주행에선 항상 skip.** `fg-next all`·`fg-loop`은 회고처럼 이 감사를 돌리지 않는다 — findings의 진위와 수정 가치 판단은 사람 몫이라는 ADR-0018의 근거가 그대로 적용된다.

## 정직하게 남기는 약점

**ADR-0013의 바("구체적·재현된 통증")를 이 리포에서는 충족하지 못한다.** forge 자체는 Markdown 플러그인이라 공격면이 거의 없다. 통증은 **forge가 구동하는 사용자의 다른 프로젝트**에 있고, 워크플로우 플러그인으로서 정당하지만 실측되지 않았다. 그리고 그 위치가 결정 4의 값을 조건부로 만든다 — **forge를 쓰지 않는 리포에서 감사하면 `.forge/` 통합의 이점이 증발**하고, 그때는 cloudflare 스킬을 직접 쓰는 것이 옳다. 그릴링에서 대상이 forge 리포임을 확인하고 진행했다.

`fg-agenda`(ADR `260805-201313`)가 같은 바를 못 넘고 만들어져 14일간 쓰이지 않은 선례가 있다. 차이는 **이번엔 forge가 덮지 못하는 공백이 실재한다는 것**(도메인 특화 감사 없음, 통합 이음새는 forge 소관)이지만, 그 판단이 틀렸다면 같은 결말이 가능하다.

## Consequences

- **스킬이 22개가 된다** — 매니페스트 2곳(`plugins[].description`; `metadata.description`은 루프 정의라 불변)·README 이중언어 쌍(21→22, 유틸리티 17→18)·`docs/skills.md`+`docs/en/skills.md` 쌍·`CLAUDE.md`의 "루프 밖 스킬" 열거·`.forge/codebase/ARCHITECTURE.md`가 동기 대상.
- **`fg-next/HANDOFF.md`의 "적용 13곳"이 14곳이 된다** — fg-security는 실재하는 다음 단계(findings→plan→fg-run)를 갖기 때문이다.
- **`.forge/security/`가 네 번째 전역 예외로 추가된다** — `fg-doctor`가 이 디렉터리를 모르므로 고아 판정을 하지 않는지 확인이 필요하다(`fg-agenda` ADR이 같은 확인을 요구했던 것과 동형).
- **vendored 파일 12개(약 101 KB)의 유지 책임이 forge에 생긴다** — 업스트림 갱신 추적은 사람의 일이며 자동화하지 않는다.

## 개정 (2026-08-20) — 결정 4 역전: 감사 산출물은 리포 **밖**에 산다 (적대적 리뷰가 보증을 무너뜨림)

봉인 전 적대적 리뷰(6렌즈 팬아웃, 반증 상한 8)가 **critical 하나에 세 렌즈(failure·security·misuse)를 독립 수렴**시켰고, 원 결정의 핵심 보증이 거짓임이 재현으로 확인됐다.

**① 결정 4를 역전한다 — 리포 안은 구조적으로 안전하게 만들 수 없다.** 원 결정은 감사 산출물을 최상위 `.forge/security/`에 두고 *"`.gitignore`의 `.forge/*` 기본 제외가 수정 없이 덮는다"*고 적었다. **그 규칙은 forge 자기 리포에만 있다.** forge는 어디서도 대상 리포에 `.gitignore`를 쓰지 않는다(`grep -rn gitignore scripts/ hooks/` → 0건). 빈 리포에서 재현: `git check-ignore` **exit 1**, `git add -A` → `findings.json` **스테이징**. 그리고 이 ADR 자신이 «정직하게 남기는 약점»에서 의도된 사용처를 *"forge가 구동하는 사용자의 다른 프로젝트"*라고 적었다 — **forge의 `.gitignore`를 가질 가능성이 가장 낮은 리포가 대상**이다. 따라서 업스트림 기본값 `~/security-audit-skill/<repo>/run-<N>/`(리포 밖)으로 되돌린다. 리포 밖은 **커밋 경로가 존재하지 않으므로** 관례에 의존하지 않는다.

**② 두 가지 개념 융합이 이 결함을 만들었다 — 이름을 붙여 둔다.**
- **"전역 예외"(ADR-0011)는 브랜치 네임스페이싱 장치이고 git 추적과 무관하다.** 기존 전역 예외 둘(`!.forge/codebase/`·`!.forge/config.json`)은 **전역 예외이면서 추적된다.** 원 결정문이 "전역 예외 = gitignored"로 붙여 읽는 순간 조건부 가정이 무조건 보증으로 바뀌었다.
- **`.gitignore`는 비-기본 브랜치의 forge 루트를 통째로 추적한다**(`!.forge/branch/`). 브랜치 인식 루트 아래의 것은 브랜치에서 무조건 커밋된다.

**③ forge는 같은 가정을 다른 곳에서 헤지했다 — 가장 위험한 자리에서만 헤지가 사라졌다.** `skills/fg-visual/VISUAL.md:58`은 *"forge's standard `.gitignore` policy … **remind the user if their project's policy differs**"*로 조건부로 적는다. 대가가 mockup HTML인 곳에서는 헤지하고 대가가 **취약점 공개**인 곳에서 무조건 보증으로 등급을 올린 것이라, 기존 가정의 재사용이 아니라 **가장 위험한 자리에서의 등급 상승**이었다.

**④ 기각한 대안 — `git check-ignore` 사전 점검(리뷰어 3명의 제안).** 첫 산출물 전에 커버리지를 확인하고 미커버면 규칙 추가·폴백·거부 중 하나를 하는 안이다. 원래 의도(`.forge/` 통합)를 보존하지만 **산출물 위치가 두 곳이 될 수 있고**(`.gitignore`가 바뀌면 run-1은 리포 안, run-2는 밖) 안전이 걸린 경로에 분기를 넣는다. 이 기능이 막는 실패는 조용하고 되돌릴 수 없으므로 그 경로는 단순해야 하며, **"구조적으로 불가능"이 "점검으로 확인됨"보다 강하다.** 문언만 헤지로 강등하는 안도 기각 — 정직해지는 것이지 안전해지는 것이 아니고, 사용자가 문서를 읽는다는 전제에 취약점 공개를 걸 수 없다.

**⑤ ADR-0001의 명시적 예외를 기록한다.** *"모든 forge 문서는 `.forge/` 아래"*를 어긴다. 근거: 취약점 리포트는 **git에 들어갈 수 없는 유일한 산출물**이라 `.forge/`의 다른 어떤 것과도 성질이 다르다. 예외를 명문화하는 것이 규칙을 늘리는 것보다 정합적이다.

**⑥ 생성 plan은 exploit을 실어 나르지 않는다(major M1).** 리포트가 리포 밖으로 나가면 **plan이 리포 안에 남는 유일한 취약점 정보**가 되고, 비-기본 브랜치의 `backlog/`는 통째로 추적된다. 그러므로 plan은 finding을 **run/index로만 참조**하고 데이터 흐름·payload·재현 커맨드를 **인용하지 않는다.** DoD는 *"이 finding의 재현을 리포트 절차대로 다시 돌려도 발동하지 않음"*으로 적어 exploit 없이 검증 가능하게 한다. 대가: plan이 자족적이지 않아 fg-run의 UAT가 리포 밖 파일을 열어야 한다 — 자족성은 편의이고 유출은 비가역이다. (반증 에이전트 2명이 이걸 *"ADR-0011 기존 설계"*로 기각하려 했으나 성립하지 않는다: 브랜치 backlog 추적은 기존 설계지만 **exploit 재현 경로를 plan에 넣으라는 지시는 원 결정이 만들었다.**)

**⑦ 결정 3의 fg-visual 선례 인용을 정정한다(minor m1).** 원문은 선례를 *"LICENSE 사본 + 파일 헤더"*로 적고 그것을 따른다고 했으나, 실제로는 `LICENSE` 사본 + **진입 파일(`AUDIT.md`) 헤더만**이고 나머지 11개는 헤더가 없다. **의도한 선택이므로 파일이 아니라 문장을 고친다** — MIT는 디렉터리 단위 `LICENSE` 사본과 `SKILL.md`의 출처 명시로 충족되고, 11개를 바이트 동일로 두는 것이 업스트림 diff의 실질 가치다.

**⑧ 원인은 검증 *환경*을 의심하지 않은 것이다.** 노출 검증을 `git check-ignore`로 했는데 **forge 자기 리포에서만** 돌리고 일반화했다. 같은 세션에서 *측정 도구*(`#115`의 1.928배)와 *측정 기준*(2단계 glob이 워크플로우 트랜스크립트 누락)을 의심한 회고를 이미 두 건 썼다 — **도구 → 기준 → 환경**의 세 번째 변종이다. 앞으로 검증을 적을 때 "이게 **어디서** 돌아야 참인가"를 함께 적는다.

**불변**: 결정 1(별 스킬)·2(vendoring)·3의 파일 구조(진입 파일만 개명)·5(심각도 게이트)·6(무인 주행 skip)은 그대로다. 이 개정은 **산출물 위치와 plan의 인용 규칙**만 바꾼다.
