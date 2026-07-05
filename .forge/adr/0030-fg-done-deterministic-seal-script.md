---
status: accepted
---

# fg-done 봉인을 결정론적 스크립트 프리미티브로 (ADR-0020을 파괴적 seal에 확장)

## 맥락

`fg-done`은 전량 LLM 구동이다 — 매 봉인마다 159줄 SKILL.md를 해석하고, 사전점검·STATUS 마감·`done/` 아카이브 이동·활성 슬롯 비우기를 **각각 별도 bash 왕복(5~6회)** 으로 손수 실행하며, 봉인 가드(verified sealable? retro done-or-skipped?)를 토큰으로 추론한다. 이는 fg-status가 ADR-0020 이전에 겪던 느림과 **동형**이다(원인은 파일 I/O가 아니라 LLM의 긴 산문 해석 + 다중 도구 왕복). 특히 `fg-next all`/`fg-done all`의 **회고 자동 skip + 봉인** 경로는 판단할 게 거의 없는데도 이 무거운 LLM 의례를 매 작업마다 반복한다.

fg-status와 결정적으로 다른 점: **fg-status는 read-only였지만 fg-done은 파일을 이동·삭제(파괴적)** 한다. 그래서 "스크립트화"는 속도만이 아니라 **원자성·안전**의 문제이기도 하다 — LLM이 손으로 여러 bash를 도는 것보다, 게이트를 통과한 뒤 한 번에 STATUS를 제자리 마감하고 이동하는 스크립트가 부분 상태(half-sealed) 위험이 낮다.

## 결정

ADR-0020의 원칙("기계적인 것은 결정론 스크립트, 판단은 산문")을 fg-done에 확장한다. 신규 **`scripts/forge-done.sh`(+ ADR-0022에 따른 `.js` 트윈 + behavior/parity 테스트)** 를 **세 봉인 경로가 공유하는 단일 "한 작업 봉인" 프리미티브**로 둔다 — 대화형 `fg-done`, `fg-done all`, `fg-next all`(fg-done 위임을 통해) 전부 이 스크립트를 호출한다. 그래서 fg-next는 거의 손대지 않고 위임만으로 속도 이득을 상속한다(작은 blast radius).

**스크립트(결정론) 가 하는 것:**
- 사전점검 — empty-state, half-sealed `done/` 복구, 중복 slug 감지, 브랜치 격리 forge 루트 해석(ADR-0011, `resolve-forge-root` 재사용).
- **게이트 강제** — `verified:`가 sealable(`yes`/`skipped`/`n/a`)인가, retro가 done(`.forge/retro/*-<slug>.md` 존재) 또는 skip 지시(`--skip-retro`)인가. 아니면 **비파괴로 즉시 non-zero exit + 사유** 를 내고 아무 파일도 안 건드린다(파괴적 이동은 게이트 통과 후에만).
- STATUS 제자리 마감(`status:`→`done`, `completed:`, `retro:` 자동 해소[경로 또는 skip 사유], `verified:` 보존), 그다음 `done/<date-slug>/`로 아카이브 이동(+`review.md` 있으면 동반) + 활성 슬롯 비우기.

**산문(판단) 이 남기는 것:**
- 게이트 실패 시 라우팅 — `failed`→fg-run fix-and-re-run, `pending`→검증 재개/cleanup-time UAT(스크립트는 refuse만, 파괴적 auto-route는 금지).
- fg-map 제안 · 이슈연동 커밋/push/close · 완료 알림·핸드오프(사용자 언어) · `all` 모드 upfront 확인 게이트 + set-aside 목록(LLM이 대상 수집 → 확인 → 작업별 스크립트 호출).
- **판단 필드 `docs updated:`** 는 스크립트 인자로 LLM이 넘긴다(skip 경로 기본 `none`).
- **skip 결정**은 오케스트레이터(fg-next all/fg-done all/사람)가 내리고 `--skip-retro "<사유>"` 로 스크립트에 전달 — 스크립트는 `retro: skipped (사유)` 기록만 한다(결정은 산문, 기록은 기계).

## 고려한 대안

- **프롬프트만 최적화(스크립트 없이)** — 기각. ADR-0020이 fg-status에서 이미 기각한 형태다. 중복은 없으나 여전히 LLM이 다중 왕복을 돌아 느리다.
- **스크립트가 라우팅까지** — 기각. 게이트 실패 라우팅(failed→fg-run 등)은 판단이고, 스크립트↔SKILL.md에 이중화돼 drift를 부른다. 파괴적 작업의 자동 라우팅은 위험(무한 재실행·의도치 않은 변경 — ADR-0009 정신에 반함).
- **파괴적이라 스크립트화하지 않는다** — 기각. 파괴적이기 때문에 오히려 원자적 스크립트가 손 bash보다 안전하다(게이트-통과-후-이동 + STATUS 제자리 선마감 + behavior/parity 테스트가 안전망). 스크립트화를 막을 이유가 아니라 신중히 할 이유다.

## 결과

- 봉인 로직(게이트 매핑, STATUS 마감 형식)이 이제 **스크립트와 SKILL.md 양쪽에 존재** — ADR-0020과 동일하게 의도적으로 동기 유지, SKILL.md의 관련 섹션이 스크립트 출력·계약의 문서 역할을 한다. 형식 변경 시 두 곳을 함께 고친다.
- **파괴적 프리미티브라 테스트가 load-bearing** — behavior + parity(.sh vs .js) 테스트(ADR-0022)가 회귀 안전망. game-over 버그(task 파일 유실)를 막는다.
- `fg-next all`/`fg-done all`은 fg-done 위임을 통해 속도 이득을 **자동 상속**(fg-next SKILL.md 거의 불변). skip 경로가 가장 스크립트화하기 쉽다(retro 사유 고정, docs=none).
- fg-status(ADR-0020)·fg-statusline(ADR-0017/0029)에 이어 **forge의 세 번째 스크립트 백킹 스킬** — "기계적은 스크립트, 판단은 산문"이 forge의 확립된 패턴이 된다.
