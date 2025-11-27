import type { CraftAppConfig } from 'ts-craft'

const config: CraftAppConfig = {
  name: 'Craft Files',
  version: '1.0.0',
  identifier: 'com.craft.files',

  window: {
    title: 'Craft Files',
    width: 1100,
    height: 700,
    minWidth: 700,
    minHeight: 400,
    center: true
  },

  entry: './index.html',

  macos: {
    bundleId: 'com.craft.files',
    appName: 'Craft Files',
    version: '1.0.0',
    buildNumber: '1',
    category: 'public.app-category.utilities',
    sandbox: true,
    entitlements: {
      'com.apple.security.files.user-selected.read-write': true,
      'com.apple.security.files.downloads.read-write': true
    }
  },

  windows: {
    appId: 'CraftFiles',
    publisher: 'CN=Craft',
    displayName: 'Craft Files',
    version: '1.0.0.0',
    capabilities: ['broadFileSystemAccess']
  },

  linux: {
    name: 'craft-files',
    category: 'Utility'
  }
}

export default config
