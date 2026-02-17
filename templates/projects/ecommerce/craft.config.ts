import type { CraftConfig } from '@stacksjs/ts-craft'

export default {
  name: '{{appName}}',
  version: '0.1.0',

  platforms: {
    ios: {
      bundleId: '{{bundleId}}',
      minimumVersion: '15.0',
      capabilities: ['apple-pay', 'push-notifications'],
    },
    android: {
      packageName: '{{packageName}}',
      minSdk: 24,
      permissions: ['INTERNET', 'POST_NOTIFICATIONS'],
    },
    macos: {
      bundleId: '{{bundleId}}',
      category: 'business',
    },
    windows: {
      packageName: '{{packageName}}',
    },
  },

  build: {
    outDir: 'dist',
    minify: true,
    sourcemap: true,
  },
} satisfies CraftConfig
