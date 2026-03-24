import type { CraftConfig } from 'ts-craft'

export default {
  name: 'Chat',
  version: '1.0.0',

  platforms: {
    ios: {
      bundleId: 'com.example.chat',
      minimumVersion: '15.0',
      capabilities: ['push-notifications', 'background-fetch'],
    },
    android: {
      packageName: 'com.example.chat',
      minSdk: 24,
      permissions: ['INTERNET', 'POST_NOTIFICATIONS', 'VIBRATE'],
    },
    macos: {
      bundleId: 'com.example.chat',
      category: 'social-networking',
      minimumVersion: '12.0',
    },
  },

  build: {
    outDir: 'dist',
    minify: true,
    sourcemap: true,
  },
} satisfies CraftConfig
