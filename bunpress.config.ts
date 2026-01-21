import type { BunPressConfig } from 'bunpress'

export default {
  title: 'Craft',
  description: 'Build desktop apps with web languages, powered by Zig',
  lang: 'en-US',

  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/logo.svg' }],
    ['meta', { name: 'theme-color', content: '#5c6bc0' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'Craft - Desktop Apps with Web Languages' }],
    ['meta', { property: 'og:description', content: 'Build desktop apps with web languages, powered by Zig for maximum performance' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:title', content: 'Craft Documentation' }],
    ['meta', { name: 'twitter:description', content: 'Build desktop apps with web languages, powered by Zig' }],
    ['meta', { name: 'keywords', content: 'desktop, webview, zig, electron-alternative' }],
  ],

  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'Craft',

    nav: [
      { text: 'Guide', link: '/intro' },
      { text: 'Features', link: '/features/window-management' },
      { text: 'Advanced', link: '/advanced/configuration' },
      {
        text: 'Links',
        items: [
          { text: 'GitHub', link: 'https://github.com/stacksjs/craft' },
          { text: 'Changelog', link: 'https://github.com/stacksjs/craft/releases' },
          { text: 'Contributing', link: 'https://github.com/stacksjs/contributing' },
        ],
      },
    ],

    sidebar: [
      {
        text: 'Getting Started',
        items: [
          { text: 'Introduction', link: '/intro' },
          { text: 'Installation', link: '/install' },
          { text: 'Usage', link: '/usage' },
          { text: 'Configuration', link: '/config' },
        ],
      },
      {
        text: 'Features',
        items: [
          { text: 'Window Management', link: '/features/window-management' },
          { text: 'Webview Integration', link: '/features/webview-integration' },
          { text: 'IPC Communication', link: '/features/ipc-communication' },
          { text: 'Native APIs', link: '/features/native-apis' },
        ],
      },
      {
        text: 'Advanced',
        items: [
          { text: 'Configuration', link: '/advanced/configuration' },
          { text: 'Custom Bindings', link: '/advanced/custom-bindings' },
          { text: 'Performance', link: '/advanced/performance' },
          { text: 'Cross-Platform', link: '/advanced/cross-platform' },
        ],
      },
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/stacksjs/craft' },
      { icon: 'discord', link: 'https://discord.gg/stacksjs' },
    ],

    editLink: {
      pattern: 'https://github.com/stacksjs/craft/edit/main/docs/:path',
      text: 'Edit this page on GitHub',
    },

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright 2024-present Stacks.js Contributors',
    },

    search: {
      provider: 'local',
    },
  },
} satisfies BunPressConfig
