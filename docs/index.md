# 시작하기

**forge**는 Claude Code 플러그인이다. 하나의 작업을 **한 바퀴의 루프**로 굴린다 — 계획을 그릴링하고(①), 실행하고(②), 배운 것을 문서로 남기고(③), 봉인해 루프를 닫는다(④).

이 사이트는 forge의 **한국어 문서**다. 소개와 스킬 카탈로그 요약은 [랜딩 페이지](https://gyuha.com/forge/)에, 원본 Markdown과 소스는 [GitHub 리포](https://github.com/gyuha/forge)에 있다.

## 설치

Claude Code에서 두 줄이면 끝난다 — DB도 서버도 빌드도 필요 없다.

```
/plugin marketplace add gyuha/forge
/plugin install forge@forge
```

설치는 GitHub 기본 브랜치(`main`)를 당긴다. 로컬 경로로 설치하려면 `gyuha/forge` 자리에 리포 경로를 넣으면 된다.

## 루프 한 바퀴

스킬이 22개지만 평소에는 **3개**로 굴린다.

```
/fg-ask   →   /fg-run   →   /fg-next
 (계획)        (실행)        (다음 단계 자동: 검증 → 회고/봉인)
```

- **`/fg-ask`** — 모든 작업의 시작점. 계획을 한 질문씩 같이 그릴링한다.
- **`/fg-run`** — 계획을 Dynamic Workflow로 실행한다.
- **`/fg-next`** — 다음 한 단계를 알아서 해준다(검증 → 회고 또는 봉인). 또 부르면 계속 진행한다.

한 번 계획하고 끝까지 맡기려면 `/fg-ask` 뒤에 `/fg-next all`을 부르면 된다 — 사람이 필요한 벽에 닿을 때까지 실행·검증·봉인을 이어서 돈다.

길을 잃었을 때: **`/fg-status`** 는 어디까지 했는지 *보여만* 주고, **`/fg-next`** 는 다음 걸 *그냥 해*준다. 사용법이 궁금하면 **`/fg-help`**, 상태가 성한지 궁금하면 **`/fg-doctor`**.

## 어디부터 읽을까

| 알고 싶은 것 | 문서 |
| --- | --- |
| 각 스킬이 무엇을 하고 무엇을 입출력하는지 | [스킬 상세](./skills.md) |
| `.forge/` 파일들이 어떻게 흐르고 무엇이 게이트인지 | [상태 계약과 디렉터리](./state-contract.md) |
| forge가 다른 하네스와 무엇이 다른지 | [forge vs loop engineering](./forge-vs-loop-engineering.md) |
| 브랜치를 쓸 때 forge 상태가 어떻게 격리·통합되는지 | [git 워크플로우](./git-workflow.md) |
| 여럿이 같이 쓸 때의 흐름 | [팀 워크플로우](./team-workflow.md) |
| 아직 결정이 안 선 안개 속 작업을 다루는 법 | [fg-agenda 사용 가이드](./agenda.md) |

## 두 기둥

forge를 고칠 때 이 둘을 깨면 forge가 forge가 아니게 된다.

1. **그릴링은 절대 Dynamic Workflow 안에 넣지 않는다.** 워크플로우는 실행 중 사용자 입력을 받지 못한다. 한 질문씩 주고받는 그릴링은 반드시 워크플로우 밖 대화로 한다.
2. **문서는 산출물이 아니라 루프의 연료다.** 계획에서 다듬은 용어가 실행의 기준이 되고, 회고의 학습이 다음 계획의 출발점이 된다.
