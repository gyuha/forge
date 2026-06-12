<!-- forge-slug: fix-marketplace-skill-coverage -->
<!-- task: 24 -->
<!-- generated-by: fg-loop -->
<!-- retro-hint: optional -->
# marketplace.json plugins description에 fg-learn·fg-done 누락 보충 (C5 fix-forward)

## Goal / Non-goals

- Goal: `marketplace.json`의 plugins[0].description이 13개 스킬을 전부 이름으로 커버하도록, 네 루프 스킬을 스테이지 역할 서술에 스킬명을 병기해 `plugin.json`과의 카탈로그 정합성을 회복한다. 정지 체크 C5 통과가 완료 기준.
- Non-goals:
  - `metadata.description`(루프 정의 한 줄 태그라인) 변경 — 배포 규칙상 루프 밖 스킬을 넣지 않는 영역, 손대지 않음.
  - 설명 문구의 의미·구조 재작성 — 스킬명 병기 외 표현 변경 금지(surgical).
  - 버전 범프·배포 — 검증 루프 작업이지 릴리스가 아님.

## Source of truth

- 실패 체크 C5 (`.forge/branch/loop/loop.md`).
- 배포 규칙(CLAUDE.md): plugins[].description은 전체 스킬 목록을 담는 설명.

## Work slices

1. `marketplace.json` plugins[0].description의 루프 4스테이지 서술에 스킬명 병기: `ask·plan (fg-ask)` · `execute (fg-run)` · `retro (fg-learn)` · `done (fg-done)`. 다른 표현은 불변.

## Verification (C5)

- 13개 스킬 디렉터리명이 전부 plugin.json **및** marketplace.json plugins[0].description에 등장(MISS 0).
- `node`로 marketplace.json JSON 유효성 유지.
