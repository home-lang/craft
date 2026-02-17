import type { CraftConfig } from '@stacksjs/ts-craft'

export default {
  name: 'Music Player',
  version: '1.0.0',

  platforms: {
    ios: {
      bundleId: 'com.example.musicplayer',
      minimumVersion: '15.0',
      capabilities: ['audio', 'background-audio'],
    },
    android: {
      packageName: 'com.example.musicplayer',
      minSdk: 24,
      permissions: ['FOREGROUND_SERVICE', 'WAKE_LOCK'],
    },
    macos: {
      bundleId: 'com.example.musicplayer',
      category: 'music',
      minimumVersion: '12.0',
    },
  },

  build: {
    outDir: 'dist',
    minify: true,
    sourcemap: true,
  },
} satisfies CraftConfig
