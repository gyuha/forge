# 2026-09-08 — Codex event_wake 가능성 조사: 수단 존재·관측 미완 → false 유지, "미확인"

## 계획 대비 실제
- 계획대로 된 것: 두 슬라이스 착지, DoD 4/4. 조사는 문서만이 아니라 **로컬 실측**이었다 — 이 머신에 `codex-cli 0.153.4`가 있어 `codex --help`·`codex queue --help`·`codex features list`·`~/.codex/config.toml`·`~/.codex/hooks.json`을 직접 읽었다. 1차 출처는 공식 릴리스 노트 `rust-v0.149.0`("Added `codex queue`" · "Queued messages now wake idle sessions reliably"). 결론과 출처는 plan이 지정한 대로 ADR `260908-200753` 개정 절에 남겼다(DoD 4 — 기계 확인 불가 항목의 감지 가능한 산출물).
- 발산: 값은 `false` 그대로지만 **결론의 성격이 바뀌었다** — "가능성 조사"가 "구현 로드맵"이 됐다. Codex의 wake는 Claude의 `Monitor`(에이전트가 파일을 pull)와 달리 `codex queue`(외부가 push)라, fg-showme가 쓰려면 (a) events를 tail해 `codex queue`를 부르는 watcher (b) `SessionStart` 훅 페이로드의 `session_id`가 필요하다. 지원표 상태는 "미지원"이 아니라 "미확인"이 정확해서 어휘를 바꿨다(`spawn_role`·`structured_choice` 행과 같은 값).

## 학습
- 다음에 다르게 할 것:
  1. **외부 도구 표면은 로컬 실측이 2차 문서보다 우선한다.** 검색이 건넨 KB가 `codex --session-name`을 말했지만 0.153.4의 help에 그 플래그가 없다. 그대로 믿었으면 plan에 존재하지 않는 수단이 들어갔을 것이다. 로컬에 도구가 있으면 `--help`를 먼저 읽는다.
  2. **"관측"의 표면을 먼저 정한다.** HOST.md가 요구하는 관측은 "fg-showme가 Codex 세션 안에서 깨어난다"이고, 그건 Claude Code 세션에서는 원리적으로 불가능하다. `codex exec` 실험을 검토했지만 exec는 턴 후 종료해 idle 상태가 없어 관측 대상이 아니고, 사용자 쿼터로 애매한 결과만 낼 것이라 하지 않았다 — plan이 "추정으로 채우지 않는다"고 못 박은 덕에 멈출 수 있었다.
  3. **1차 출처 URL은 살아 있는지부터 본다.** `developers.openai.com/codex/cli/features`는 quickstart로 리다이렉트되고 CLI 레퍼런스는 404였다. 닿은 1차 출처는 GitHub 릴리스 노트 하나였다. 조사 plan의 DoD에 "출처"를 요구한 것이 맞았다 — 없었으면 KB 인용으로 끝났을 것이다.
  4. 훅은 **관찰 전용**(턴을 시작 못 함)이라 wake의 후보에서 빠진다 — 그러나 `session_id`를 주는 유일한 표면이라 watcher의 전제가 된다. 두 역할을 섞지 않고 적어야 다음 구현자가 헷갈리지 않는다.

## 문서 갱신
- CONTEXT.md 승급: 없음(push/pull은 구현 형태이고 도메인 용어가 아니다).
- ADR 추가: 없음 — `260908-200753`에 "개정 2026-09-08" 절로 결론·출처 4건 기록(신규가 아닌 개정).

## 후속 작업 후보
- **push형 wake 어댑터**: fg-showme가 `event_wake`=false인 Codex에서 세션 시작 시 `tail -F events | grep confirm: | xargs codex queue --thread "$SESSION_ID"` 류 watcher를 띄우고, `SessionStart` 훅이 `session_id`를 보존하는 경로 — 구현 + **Codex 세션에서 실측** → 그때 `event_wake: true`. 별개 fg-ask(구현·관측·ADR 개정 셋을 한 plan에 담지 말고 분할 판단).
