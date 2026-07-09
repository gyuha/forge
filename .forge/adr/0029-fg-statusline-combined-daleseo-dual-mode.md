---
status: accepted
---

# fg-statusline 이중 모드 — daleseo식 통합 시스템+forge statusline (append/merge)

## 맥락

ADR-0017은 `forge-statusline.sh`를 **의도적으로 얇은 forge-전용 판독자**로 못박았다 — forge 루프 상태(active pipeline + backlog/retro 요약)만 그리고, 모델·git·컨텍스트·비용 같은 **시스템 정보는 일절 그리지 않으며**, 기존 statusline이 있으면 wrapper로 감싸 아래 별도 줄로 덧붙인다. 그 결과 statusline을 처음 붙이는 사용자는 "bare forge 진행"만 얻고, 리치한 시스템 대시보드는 스스로 만들어야 했다. 사용자는 daleseo 블로그(https://daleseo.com/claude-code-statusline/)의 statusline을 기반으로, forge가 **시스템 정보까지 직접 렌더링**하고 forge 상태와 **두 가지 방식으로 결합**하기를 요구했다: (1) 기존 statusline에 forge를 **덧붙이는** 방식, (2) 시스템+forge를 **하나의 스크립트로 통째로 합치는** 방식.

## 결정

`fg-statusline`에 **두 설치 모드**를 둔다. ADR-0017의 얇은 forge 판독자(`forge-statusline.sh`/`.js`)와 wrapper는 그대로 두고, **새 통합 스크립트**를 추가한다.

- **방법 1 (append) = ADR-0017의 wrap 그대로.** 베이스 = 사용자가 이미 쓰던 **제3자 statusline**. wrapper가 그 아래 forge fragment를 별도 줄로 덧붙인다. 변경 없음.
- **방법 2 (merge) = 새 통합 스크립트 `forge-statusline-full.sh`/`.js` 트윈(ADR-0022 완전 parity).** forge가 소유하는 단일 명령이 daleseo식 시스템 정보 + forge 진행을 한 스크립트로 출력한다. 3(+1)줄 레이아웃:
  - Line 1: `[모델명 | 추론강도] | 작업 디렉토리 | git 브랜치+상태`
  - Line 2: `Context <bar> N% | Usage <bar> N% (resets in Xm) | Weekly <bar> N% (resets in Xh Ym)`
  - Line 3: `forge | <slug> | <ask→run→learn→done 파이프라인> | <flag>` (기존 fragment의 단계 로직 재사용, 프리픽스만 `⚒`→`forge |`)
  - Line 4(비어있지 않을 때만): `📋 N queued · 📝 M awaiting retro`
  - 임계값별 색(daleseo 기법): 3개 바 전부 `<70 초록 / 70–90 노랑 / ≥90 빨강`, 추론강도는 블로그 effort 색표.
  - 그레이스풀 부재: 필드가 없으면 그 세그먼트만 생략(줄은 남음). `rate_limits`는 Pro/Max 구독자·첫 API 응답 이후에만 오고 각 윈도우가 독립적으로 없을 수 있음, `effort`는 미지원 모델에서 없음, `context %`는 세션 초기 null 가능(0 폴백).
- **설치 결정 트리:** 기존 statusline 있음 → 사용자에게 방법 1/2 선택; 없음 → 방법 2 자동; Windows+기존 있음 → 방법 2만 제시(방법 1 wrapper가 bash 전용이라). 방법 2가 기존 statusline을 교체할 때는 원본을 `forge-statusline-orig.sh`에 보존하고 복원법을 안내한다(파괴적 선택의 되돌림 경로).
- **모드 감지:** settings.json의 command 경로로 설치 모드를 감지(wrapper 경로=방법 1, 통합 스크립트 경로=방법 2). 재실행 = 현재 모드 조용히 refresh, 전환은 한 번만 물음. **새 config 키를 만들지 않는다.**

## 고려한 대안

- **얇은 forge-only 유지(ADR-0017 철학 고수)** — 기각. 사용자가 명시적으로 시스템 정보 렌더링을 요구했고, "통째로 합치기"의 합칠 대상(시스템 콘텐츠)이 forge에 없으면 성립 불가.
- **통합 스크립트 node-only** — 검토했고 두 번 추천했으나 사용자가 **완전 parity(.sh+.js 트윈)** 를 택했다. 중첩 `rate_limits`(콜리전 키 `used_percentage`×3, `resets_at`×2)를 bash+sed로 부모 앵커 추출하는 비용을 감수하는 대신, ADR-0022의 트윈 일관성을 유지한다.
- **시스템 렌더러에 `jq` 사용(블로그 방식)** — 기각. `jq`는 보장되지 않는 새 하드 의존성(ADR-0017 원칙 위반). bash는 방어적 sed(부모 앵커), node는 `JSON.parse`로 처리.
- **방법 2를 한 줄 interleave로** — 초기 추천이었으나 사용자가 3줄 레이아웃으로 오버라이드.
- **Windows용 node wrapper를 이번에 신설(방법 1의 Windows 지원)** — 기각(YAGNI). Windows+기존 statusline은 방법 2(통합, node로 깨끗)로 안내. node wrapper는 여전히 follow-up.

## 결과

- forge가 **시스템 정보(모델/추론강도/디렉터리/git/컨텍스트/rate-limit/비용)를 직접 렌더링**하게 된다 — ADR-0017의 "얇은 forge-전용 판독자" 철학의 경계 있는 확장(방법 1은 그 철학 그대로 남음).
- forge 단계 매핑이 이제 **3곳**(fg-status 정본 · fragment · 통합 스크립트)이 될 위험. 통합 스크립트는 fragment의 단계 로직을 **재사용**하고(복제 금지 — 프리픽스만 파라미터화), consistency 테스트로 드리프트를 막는다.
- `resets_at`은 Unix epoch 초라 `resets_at - now`로 "resets in Xm"을 계산한다(공식 스키마 확인 — 블로그엔 없던 필드).
- 새 스크립트 2종(`forge-statusline-full.sh`/`.js`) + 테스트 2종(behavior + parity)이 설치·refresh 복사 목록에 추가된다.

## 개정 (2026-07-07)

컴팩트 스타일 채택(task #70 그릴링 합의): 세그먼트 구분자 ` | ` → ` · `, Line 2 라벨 Context/Usage/Weekly → Ctx/5h/7d, git 브랜치에 `⎇ ` 접두, Line 2 끝에 `⏱` 세션 경과 세그먼트(`cost.total_duration_ms`→초 내림, 기존 humanize 재사용, cost 부재 시 생략) 추가. 통합 스크립트의 forge 줄 위임 프리픽스는 `forge | ` 오버라이드를 폐지하고 fragment 기본 `⚒ `를 그대로 쓴다 — `FORGE_SL_PREFIX` 위임 메커니즘 자체는 불변.

## 개정 (2026-07-08)

세그먼트 3종 추가(task #71 그릴링 합의). fragment line 1(양 모드 공통)에 **task 번호 `#N`**(활성 plan의 `<!-- task: N -->` 마커에서 slug 앞에 표시 — 마커 없으면 생략, ask 단계엔 없음)과 **맨 끝 모드 인디케이터 세그먼트 ` · Ⓣ Ⓔ`** — `Ⓣ`(U+24C9)는 plan의 `<!-- tdd: on -->`일 때, `Ⓔ`(U+24BA)는 **최상위** `.forge/config.json`의 `eco: true`일 때(브랜치 무관 전역 예외 키 재사용 — ADR-0011; ask 줄에도 적용, idle·`🔁`-only 폴백 줄엔 없음). 켜진 것만 공백 구분으로 표시하고, 하나도 없으면 현행 출력과 완전 동일(후미 구분자 없음 규칙 유지). full 스크립트 line 1의 `⎇` git 세그먼트에 **ahead/behind `↑N ↓N`** 추가 — 브랜치명 뒤·worktree 카운트(`+!?`) 앞, 0이면 각각 생략, upstream 없는 브랜치면 통째 생략(기존 graceful omission 규칙 그대로, stderr 억제). 아이콘은 원문자 계열로 통일 — 🧪·🌱·⚙는 기각(사용자 선택: ⚙는 줄 앞머리 `⚒`와 도구류 모양이 겹침, 이모지 둘은 `Ⓣ`와 계열을 맞추기 위해 교체).

## 개정 (2026-07-10)

task #73 그릴링 합의(daleseo 가이드 재참조). 방법 2에 다음 6가지를 반영하고, 방법 1은 그룹 대괄호·이모지 지시자만 전파받되 `·`·무색·append 성격은 유지한다(두 설치 모드·설치 결정 트리 불변).

1. **밀도 토글 `compact`/`full`** — full 스크립트의 **위치 인자**(`$1`/`argv[2]`, 미지정·미인식→`full`)로 저장. `full`=4줄(현행 골격), `compact`=2줄(시스템+바 한 줄 + fragment 단일 그룹, 세션 그룹 제외). **새 config 키 없음** — 밀도는 wired command에 인코딩(모드를 command 경로로 감지하는 기존 철학과 동형). 설치 시 1회 질문, refresh는 기존 인자 보존.
2. **세 신규 필드**(전부 full의 시스템/사용량 줄): **Context/`<size>`**(`context_window_size`를 라벨 부착 — `>=1e6`→`1M`, else `round/1000`+`K`; 대괄호 그룹과 충돌 회피로 `[1M]` 대신 부착), **동적 이모지**(Context % 기준 🟢<20·⚡20–69·🔥70–89·🚨≥90, Context 앞), **RGB 그라디언트 바**(3바 셀별 truecolor 초→노→빨, 임계 단색 대체), **$비용+±라인**(`cost.total_cost_usd`→`$X.XX` yellow, `total_lines_added/removed`→`+A −R` green/red, full L1 세션 그룹).
3. **구분자 `·`→`|` 원복 + `Ctx`→`Context` 원복**(2026-07-07 개정의 부분 원복). 방법 2 전체가 `|`. fragment는 신설 **`FORGE_SL_SEP`** env로 구분자를 받되 기본 `·`(미설정=방법 1) — full이 `FORGE_SL_SEP=|` 전달. `5h`/`7d` 라벨은 유지(비대칭 감수).
4. **세그먼트 색상**(가이드 팔레트, 라이브 튜닝·ANSI strip): 모델 magenta·`⎇`브랜치 cyan·`$` yellow·`+`green/`−`red·구분자·대괄호 dim·바 그라디언트. 아이콘은 forge 현행(`⎇`) 유지, 🤖·🌿 미도입.
5. **의미 단위 그룹 대괄호 `[...]`**(전역 — fragment가 항상 적용해 방법 1에도 반영). 그룹 사이 공백, 안은 SEP, 빈 그룹 생략. env 토글 없음.
6. **재배치 + 이모지 지시자**: 세션 그룹(⏱/$/±라인)을 full L1 끝으로·L2=바만·L3=`[⚒ #N slug | pipeline | flag]`(verified flag 유지). 모드 지시자 **`Ⓣ`→`🧪`(tdd)·`Ⓔ`→`♻️`(eco)**(2026-07-08의 이모지 기각을 사용자 요청으로 원복) — full 밀도는 L4 큐 그룹, compact는 forge 그룹에 접힘, 실활동(활성 작업/큐)에서만 점등(idle·loop-only 제외). fragment는 이제 **density-aware**(full=작업+큐 2줄·큐 풀텍스트 / compact=단일 그룹·큐 `📋 N` 카운트만·📝 생략). 단계·큐·그룹 로직은 fragment 소유(3중 복제 금지·consistency 테스트 유지).

무인자 출력이 "바이트 동일"이던 하위호환 보장은 폐기(구분자·라벨·그룹·색이 의도적으로 바뀜) — "무인자=full 4줄 **구조** 불변"으로 재정의하고 기존 테스트 픽스처를 전수 갱신. ADR-0017의 "방법 1 = bare forge 진행" 서술도 대괄호·이모지 지시자 반영으로 개정.
