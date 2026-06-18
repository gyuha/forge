# fg-status: survey+테이블은 결정론적 스크립트, next-step은 산문 유지

fg-status가 느렸던 원인은 파일 I/O가 아니라 **LLM이 긴 산문 스킬을 해석**하는 비용이었다 — `.forge/`를 조사하느라(특히 수십 개의 `done/` 디렉터리) 여러 번의 도구 round-trip을 돌고, next-step 5순위 머신을 토큰으로 추론했다. 그래서 **기계적인 survey + 6열 테이블 렌더링을 결정론적 bash 스크립트**(`scripts/forge-status.sh`, 브랜치 루트 해석은 `forge-statusline.sh`에서 재사용)로 옮겨, 스킬은 이를 실행하고 출력을 그대로 전달한다(LLM 거의 0). `--table` 모드는 6열 테이블만 출력하는 "테이블만" 고속 경로다. **next-step 우선순위 머신은 SKILL.md 산문에 그대로 두어 LLM이 도출**하는데, 이는 "fg-status 산문이 '다음에 뭐 할까'의 단일 정답소스"라는 ADR-0017 원칙을 계승하기 위함이다(fg-next도 이 머신을 재사용한다).

## Considered Options

- **스크립트가 next-step까지 (기각)** — 완전 속도 이득이지만 5순위 머신이 스크립트↔SKILL.md 양쪽에 중복돼 drift 위험이 생기고, fg-next가 의존하는 머신을 이중화하며, ADR-0017의 "statusline은 next-step을 재현하지 않는다" 원칙과 충돌한다.
- **프롬프트만 최적화 (기각)** — 스크립트 없이 단일 canonical survey 명령만 지시. 중복은 없으나 여전히 LLM이 테이블·산문을 생성해 스크립트보다 느리다.

## Consequences

- bucket→stage 매핑과 verified/retro→기호(O/~/—/✗, O/X) 매핑이 이제 **스크립트와 SKILL.md 테이블 명세 양쪽에 존재**한다 — 의도적으로 동기 유지하며, SKILL.md의 테이블 섹션은 스크립트 출력 형식의 문서 역할을 한다. 형식을 바꿀 땐 두 곳을 함께 고친다.
- 스크립트는 언어 중립(canonical English 헤더 + slug/날짜/기호)으로 출력하고, 사용자 언어 산문은 next-step 한 줄뿐이다. `--table` 모드는 순수 스크립트 출력이라 LLM이 개입하지 않는다.
- next-step은 스크립트에 없으므로, fg-next는 종전대로 SKILL.md 머신을 따른다(스크립트 호출로 대체하지 않음).
