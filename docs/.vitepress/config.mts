import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'

// The docs site is served at /forge/docs/ while the hand-written landing page
// (docs/index.html) is served at /forge/ — the deploy workflow assembles both
// into one Pages artifact. See .forge/adr/260815-094725-vitepress-docs-site.md.
const BASE = '/forge/docs/'

// The landing lives outside `base`, so it cannot be a root-relative nav link
// (VitePress would prefix it with base and point back inside the docs site).
const LANDING_URL = 'https://gyuha.com/forge/'
const REPO_URL = 'https://github.com/gyuha/forge'

// Korean is the root locale, so its pages keep their original URLs
// (/forge/docs/skills.html); English is layered under /forge/docs/en/.
// Sidebar groups are configuration only — the Markdown files stay flat in
// docs/ and docs/en/ so that README's ./docs/*.md links keep working.
const sidebarKo = [
  { text: '시작하기', link: '/' },
  {
    text: '개념',
    collapsed: false,
    items: [{ text: 'forge vs loop engineering', link: '/forge-vs-loop-engineering' }],
  },
  {
    text: '가이드',
    collapsed: false,
    items: [
      { text: 'Codex에서 사용하기', link: '/codex' },
      { text: 'git 워크플로우', link: '/git-workflow' },
      { text: '팀 워크플로우', link: '/team-workflow' },
      { text: 'fg-agenda 사용 가이드', link: '/agenda' },
      { text: '설정 모드 (simple)', link: '/config-modes' },
    ],
  },
  {
    text: '레퍼런스',
    collapsed: false,
    items: [
      { text: '스킬 상세', link: '/skills' },
      { text: '상태 계약과 디렉터리', link: '/state-contract' },
    ],
  },
]

const sidebarEn = [
  { text: 'Getting started', link: '/en/' },
  {
    text: 'Concepts',
    collapsed: false,
    items: [{ text: 'forge vs loop engineering', link: '/en/forge-vs-loop-engineering' }],
  },
  {
    text: 'Guides',
    collapsed: false,
    items: [
      { text: 'Using with Codex', link: '/en/codex' },
      { text: 'Git workflow', link: '/en/git-workflow' },
      { text: 'Team workflow', link: '/en/team-workflow' },
      { text: 'fg-agenda guide', link: '/en/agenda' },
      { text: 'Config modes (simple)', link: '/en/config-modes' },
    ],
  },
  {
    text: 'Reference',
    collapsed: false,
    items: [
      { text: 'Skills in detail', link: '/en/skills' },
      { text: 'State contract & directories', link: '/en/state-contract' },
    ],
  },
]

export default withMermaid(
  defineConfig({
    title: 'forge',
    base: BASE,
    lastUpdated: true,

    // Assets under docs/public/ are emitted to the site root, so both entries
    // below resolve inside `base` and stay valid in dev and preview too.
    head: [
      // `head` is written out verbatim — VitePress does not prepend `base` here.
      ['link', { rel: 'icon', href: `${BASE}icon.png` }],
    ],

    locales: {
      root: {
        label: '한국어',
        lang: 'ko-KR',
        description: '에이전트 엔지니어링을 위한 Claude Code 워크플로우 플러그인 — 작업 하나를 질의·계획 → 실행 → 회고 → 완료의 한 바퀴로',
        themeConfig: {
          nav: [
            { text: '시작하기', link: '/' },
            { text: '스킬', link: '/skills' },
            { text: '상태 계약', link: '/state-contract' },
            { text: '랜딩', link: LANDING_URL },
          ],
          sidebar: sidebarKo,
          editLink: {
            pattern: `${REPO_URL}/edit/main/docs/:path`,
            text: 'GitHub에서 이 문서 수정하기',
          },
          outline: { level: [2, 3], label: '이 페이지' },
          docFooter: { prev: '이전', next: '다음' },
          darkModeSwitchLabel: '테마',
          lightModeSwitchTitle: '라이트 모드로',
          darkModeSwitchTitle: '다크 모드로',
          returnToTopLabel: '맨 위로',
          sidebarMenuLabel: '메뉴',
          langMenuLabel: '언어 변경',
          lastUpdatedText: '마지막 수정',
          footer: {
            message: 'MIT License',
            copyright: 'forge — Claude Code 워크플로우 플러그인',
          },
        },
      },

      en: {
        label: 'English',
        lang: 'en',
        link: '/en/',
        description: 'An agent-engineering workflow plugin for Claude Code — one task through a single cycle of ask·plan → execute → retro → done',
        themeConfig: {
          nav: [
            { text: 'Getting started', link: '/en/' },
            { text: 'Skills', link: '/en/skills' },
            { text: 'State contract', link: '/en/state-contract' },
            { text: 'Landing', link: LANDING_URL },
          ],
          sidebar: sidebarEn,
          editLink: {
            pattern: `${REPO_URL}/edit/main/docs/:path`,
            text: 'Edit this page on GitHub',
          },
          outline: { level: [2, 3], label: 'On this page' },
          footer: {
            message: 'MIT License',
            copyright: 'forge — a Claude Code workflow plugin',
          },
        },
      },
    },

    themeConfig: {
      // themeConfig.logo IS prefixed with `base` (VPImage calls withBase), so
      // this must be base-relative — writing the full path double-prefixes it.
      logo: '/icon.png',

      socialLinks: [{ icon: 'github', link: REPO_URL }],

      search: {
        provider: 'local',
        options: {
          locales: {
            // `root` is Korean here; `en` keeps the built-in English strings.
            root: {
              translations: {
                button: { buttonText: '검색', buttonAriaLabel: '검색' },
                modal: {
                  displayDetails: '상세 목록 표시',
                  resetButtonTitle: '검색 초기화',
                  backButtonTitle: '검색 닫기',
                  noResultsText: '결과 없음',
                  footer: {
                    selectText: '선택',
                    selectKeyAriaLabel: '엔터',
                    navigateText: '이동',
                    navigateUpKeyAriaLabel: '위 화살표',
                    navigateDownKeyAriaLabel: '아래 화살표',
                    closeText: '닫기',
                    closeKeyAriaLabel: 'esc',
                  },
                },
              },
            },
          },
        },
      },
    },

    mermaid: {
      securityLevel: 'loose',
      // Mermaid under-measures the height of multi-line Korean labels, so the
      // last line spills past the node border. Extra padding absorbs it without
      // editing the diagrams in the Markdown.
      flowchart: { htmlLabels: true, useMaxWidth: true, padding: 22 },
    },
  })
)
