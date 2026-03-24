import type { CraftAppConfig } from '@craft-native/craft'

const config: CraftAppConfig = {
  name: '{{APP_NAME}}',
  version: '1.0.0',
  identifier: '{{BUNDLE_ID}}',

  window: {
    title: '{{APP_NAME}}',
    width: 1280,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    resizable: true,
    center: true
  },

  entry: './index.html',

  macos: {
    bundleId: '{{BUNDLE_ID}}',
    appName: '{{APP_NAME}}',
    version: '1.0.0',
    buildNumber: '1',
    minimumSystemVersion: '12.0',
    category: 'public.app-category.business',
    sandbox: true,
    entitlements: {},
    infoPlist: {}
  },

  windows: {
    appId: '{{APP_NAME}}',
    publisher: 'CN={{AUTHOR}}',
    displayName: '{{APP_NAME}}',
    version: '1.0.0.0',
    minWindowsVersion: '10.0.17763.0',
    capabilities: ['internetClient']
  }
}

export default config
