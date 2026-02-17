import type { CraftAppConfig } from '@stacksjs/ts-craft'

const config: CraftAppConfig = {
  name: 'Craft Notes',
  version: '1.0.0',
  identifier: 'com.craft.notes',

  window: {
    title: 'Craft Notes',
    width: 1000,
    height: 700,
    minWidth: 600,
    minHeight: 400,
    center: true
  },

  entry: './index.html',

  macos: {
    bundleId: 'com.craft.notes',
    appName: 'Craft Notes',
    version: '1.0.0',
    buildNumber: '1',
    category: 'public.app-category.productivity',
    entitlements: {
      'com.apple.security.network.client': true
    }
  },

  ios: {
    bundleId: 'com.craft.notes',
    appName: 'Craft Notes',
    version: '1.0.0',
    buildNumber: '1',
    minimumVersion: '15.0',
    permissions: {
      faceId: 'Secure your notes with Face ID'
    }
  },

  android: {
    packageName: 'com.craft.notes',
    appName: 'Craft Notes',
    versionCode: 1,
    versionName: '1.0.0',
    permissions: [
      'android.permission.INTERNET',
      'android.permission.USE_BIOMETRIC'
    ]
  }
}

export default config
