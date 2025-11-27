import type { CraftConfig } from 'ts-craft'

export default {
  name: 'Shop',
  version: '1.0.0',

  platforms: {
    ios: {
      bundleId: 'com.example.shop',
      minimumVersion: '15.0',
      capabilities: ['apple-pay', 'push-notifications'],
    },
    android: {
      packageName: 'com.example.shop',
      minSdk: 24,
      permissions: ['INTERNET', 'POST_NOTIFICATIONS'],
    },
    macos: {
      bundleId: 'com.example.shop',
      category: 'business',
      minimumVersion: '12.0',
    },
  },

  build: {
    outDir: 'dist',
    minify: true,
    sourcemap: true,
  },
} satisfies CraftConfig
