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

export default withMermaid(
  defineConfig({
    lang: 'ko-KR',
    title: 'forge',
    description: '하나의 작업을 하나의 사이클로 — Claude Code 루프형 워크플로우 플러그인',
    base: BASE,
    lastUpdated: true,

    head: [
      // Not prefixed with `base` automatically — the path is written out in full.
      ['link', { rel: 'icon', href: '/forge/icon.png' }],
    ],

    themeConfig: {
      logo: '/forge/icon.png',

      nav: [
        { text: '시작하기', link: '/' },
        { text: '스킬', link: '/skills' },
        { text: '상태 계약', link: '/state-contract' },
        { text: '랜딩', link: LANDING_URL },
      ],

      // Sidebar groups are configuration only — the Markdown files stay flat in
      // docs/ so that README's ./docs/*.md links keep working.
      sidebar: [
        { text: '시작하기', link: '/' },
        {
          text: '개념',
          collapsed: false,
          items: [
            { text: 'forge vs loop engineering', link: '/forge-vs-loop-engineering' },
          ],
        },
        {
          text: '가이드',
          collapsed: false,
          items: [
            { text: 'git 워크플로우', link: '/git-workflow' },
            { text: '팀 워크플로우', link: '/team-workflow' },
            { text: 'fg-agenda 사용 가이드', link: '/agenda' },
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
      ],

      search: { provider: 'local' },

      socialLinks: [{ icon: 'github', link: REPO_URL }],

      editLink: {
        pattern: `${REPO_URL}/edit/main/docs/:path`,
        text: 'GitHub에서 이 문서 수정하기',
      },

      outline: { level: [2, 3], label: '이 페이지' },
      docFooter: { prev: '이전', next: '다음' },
      darkModeSwitchLabel: '테마',
      returnToTopLabel: '맨 위로',
      sidebarMenuLabel: '메뉴',
      lastUpdatedText: '마지막 수정',

      footer: {
        message: 'MIT License',
        copyright: 'forge — Claude Code 워크플로우 플러그인',
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
