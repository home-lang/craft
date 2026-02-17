import type { CraftConfig } from '@stacksjs/ts-craft'

export default {
  name: 'Social',
  version: '1.0.0',

  platforms: {
    ios: {
      bundleId: 'com.example.social',
      minimumVersion: '15.0',
      capabilities: ['push-notifications', 'camera', 'photo-library'],
    },
    android: {
      packageName: 'com.example.social',
      minSdk: 24,
      permissions: ['INTERNET', 'CAMERA', 'READ_MEDIA_IMAGES', 'POST_NOTIFICATIONS'],
    },
    macos: {
      bundleId: 'com.example.social',
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
