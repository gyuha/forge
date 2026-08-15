---
author: gyuha
decided: 2026-08-15 09:47
---
# 문서 사이트는 VitePress로 짓고, GitHub Pages 소스를 Actions로 옮긴다

`docs/`의 한글 문서 6개는 GitHub에서 읽을 때만 쓸모가 있었고 배포된 사이트(`gyuha.com/forge/`)는 랜딩 `index.html` 한 장뿐이었다. docs.opengsd.net 수준의 문서 사이트(사이드바 네비·검색·다크모드)를 원하면서도 **기존 랜딩을 그대로 유지**해야 하므로, `docs/`를 VitePress 소스로 삼아 `/forge/docs/`에 문서 사이트를 짓고 랜딩은 `/forge/` 루트에 남긴다. 이를 위해 GitHub Pages 소스를 legacy(`main` 브랜치 `/docs` 폴더)에서 **GitHub Actions 아티팩트**로 전환한다 — 워크플로가 VitePress 산출물과 랜딩·이미지를 한 아티팩트로 조립해 올린다.

## Considered Options

- **VitePress (채택)** — 목표한 모양(사이드바·로컬 검색·다크모드)을 GitHub Pages 안에서 재현하는 최선. 대가는 이 리포에 **빌드 시스템이 처음 생긴다**는 것(`package.json`·`node_modules`·CI 워크플로).
- **Jekyll + just-the-docs** — 인프라 변화가 0(GitHub이 서버에서 빌드). 기각 근거: 디자인 자유도가 낮아 목표한 모양에 못 미치고, 문서에 든 Liquid 유사 문법(`{{ }}`)이 충돌할 수 있다.
- **Docsify** — 빌드 없는 클라이언트 렌더링. 기각 근거: SEO가 없고 `#/` 해시 URL이며 검색이 약하다.
- **Mintlify (docs.opengsd.net의 실체)** — 참고 사이트와 동일. 기각 근거: **외부 SaaS 호스팅**이라 문서가 GitHub Pages 밖에서 서빙되어 랜딩과 도메인이 갈라진다. "docs 폴더를 이용해 만들고 랜딩은 유지"라는 요구와 정면 충돌한다.

## Consequences

- **CLAUDE.md의 "빌드·테스트·린트 시스템이 없다. package.json, Makefile, CI 없음"이 더 이상 참이 아니다.** 예외의 범위는 **문서 사이트 한정**이며, 플러그인 본체(스킬 Markdown·매니페스트 JSON)는 여전히 빌드 대상이 아니다. 이 경계를 흐리지 말 것 — `package.json`은 문서 도구이지 플러그인 빌드가 아니다.
- **Markdown 파일은 옮기지 않는다.** `docs/*.md`가 제자리에 남아 VitePress 소스와 GitHub 읽기용을 겸하므로 README의 `./docs/*.md` 링크가 그대로 살아 있다. 사이드바의 그룹(개념·가이드·레퍼런스)은 **설정일 뿐 디렉터리가 아니다**.
- **`.forge/adr/`로 나가는 상대 링크 34개는 절대 GitHub URL로 바꾼다.** VitePress는 소스 루트 밖 상대 링크를 dead link로 보고 빌드를 실패시키는데, `ignoreDeadLinks`로 덮으면 진짜 오타까지 숨는다. 절대 URL은 GitHub과 사이트 양쪽에서 동작한다.
- **랜딩 파일은 `docs/index.html`에 그대로 두고 워크플로가 아티팩트 루트로 복사한다.** 같은 폴더에 문서 홈 `docs/index.md`가 공존해 로컬 dev 서버에서 `/forge/docs/` 경로가 랜딩을 집을 가능성이 있다(빌드 산출물은 무관 — VitePress는 stray `.html`을 emit하지 않는다). 실제로 충돌하면 랜딩을 리포 루트 `landing/`으로 옮기고 워크플로 복사 경로만 고친다(URL 불변).
