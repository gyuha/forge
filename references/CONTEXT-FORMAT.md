# CONTEXT.md 형식

> grill-with-docs 계승. `fg-ask`(그릴링 중 인라인 갱신)·`fg-learn`(승급)이 공통으로 사용한다.

## 구조

```md
# {컨텍스트 이름}

{이 컨텍스트가 무엇이고 왜 존재하는지 한두 문장.}

## Language

**Order**:
{용어를 설명하는 한두 문장.}
_Avoid_: Purchase, transaction

**Invoice**:
배송 후 고객에게 보내는 결제 요청.
_Avoid_: Bill, payment request

**Customer**:
주문을 넣는 사람 또는 조직.
_Avoid_: Client, buyer, account
```

## 규칙

- **의견 있게 쓴다.** 같은 개념에 여러 단어가 있으면 가장 좋은 하나를 고르고 나머지는 `_Avoid_`에 둔다.
- **정의는 타이트하게.** 최대 한두 문장. 무엇을 *하는지*가 아니라 무엇*인지*를 정의한다.
- **이 프로젝트 컨텍스트 고유 용어만 넣는다.** 일반 프로그래밍 개념(타임아웃, 에러 타입, 유틸 패턴)은 자주 써도 글로서리에 넣지 않는다. 추가 전에 자문한다: 이 컨텍스트 고유 개념인가, 일반 개념인가? 전자만 들어간다.
- **자연스러운 묶음이 생기면 소제목으로 그룹화**한다. 모든 용어가 하나의 응집된 영역에 속하면 평면 목록도 좋다.

## 단일 vs 멀티 컨텍스트 리포

**단일 컨텍스트(대부분):** 리포 루트에 `CONTEXT.md` 하나.

**멀티 컨텍스트:** 리포 루트의 `CONTEXT-MAP.md`가 컨텍스트들의 위치와 관계를 적는다:

```md
# Context Map

## Contexts

- [Ordering](./src/ordering/CONTEXT.md) — 고객 주문을 받고 추적
- [Billing](./src/billing/CONTEXT.md) — 인보이스 생성, 결제 처리
- [Fulfillment](./src/fulfillment/CONTEXT.md) — 창고 피킹과 배송 관리

## Relationships

- **Ordering → Fulfillment**: Ordering이 `OrderPlaced` 이벤트를 emit, Fulfillment가 소비해 피킹 시작
- **Fulfillment → Billing**: Fulfillment가 `ShipmentDispatched`를 emit, Billing이 소비해 인보이스 생성
- **Ordering ↔ Billing**: `CustomerId`, `Money` 공유 타입
```

스킬은 어떤 구조인지 추론한다:

- `CONTEXT-MAP.md`가 있으면 읽어서 컨텍스트들을 찾는다
- 루트에 `CONTEXT.md`만 있으면 단일 컨텍스트
- 둘 다 없으면 첫 용어가 정리될 때 루트 `CONTEXT.md`를 lazy 생성

멀티 컨텍스트면 현재 주제가 어느 컨텍스트인지 추론한다. 불분명하면 묻는다.
