import type { CraftConfig } from 'ts-craft'

export default {
  name: '{{appName}}',
  version: '0.1.0',

  platforms: {
    ios: {
      bundleId: '{{bundleId}}',
      minimumVersion: '15.0',
      capabilities: ['push-notifications', 'camera', 'photo-library'],
    },
    android: {
      packageName: '{{packageName}}',
      minSdk: 24,
      permissions: ['INTERNET', 'CAMERA', 'READ_MEDIA_IMAGES', 'POST_NOTIFICATIONS'],
    },
    macos: {
      bundleId: '{{bundleId}}',
      category: 'social-networking',
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
