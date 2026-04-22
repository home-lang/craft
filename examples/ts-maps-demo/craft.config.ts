import type { CraftAppConfig } from '@craft-native/craft'

const config: CraftAppConfig = {
  name: 'ts-maps Demo',
  version: '1.0.0',
  identifier: 'com.craft.examples.ts-maps-demo',

  window: {
    title: 'ts-maps Demo',
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    resizable: true,
    center: true,
  },

  entry: './src/index.html',

  build: {
    outDir: 'dist',
    sourcemap: true,
    minify: false,
  },

  ios: {
    bundleId: 'com.craft.examples.ts-maps-demo',
    appName: 'ts-maps Demo',
    version: '1.0.0',
    buildNumber: '1',
    deploymentTarget: '15.0',
    deviceFamily: ['iphone', 'ipad'],
    orientations: ['portrait', 'landscape'],
    capabilities: [],
    infoPlist: {
      CFBundleDisplayName: 'ts-maps Demo',
    },
  },

  android: {
    packageName: 'com.craft.examples.tsmapsdemo',
    versionCode: 1,
    versionName: '1.0.0',
    minSdk: 24,
    targetSdk: 34,
    compileSdk: 34,
    permissions: [],
    features: [],
    applicationClass: 'com.craft.examples.tsmapsdemo.DemoApplication',
    mainActivity: 'com.craft.examples.tsmapsdemo.MainActivity',
    theme: '@style/Theme.TsMapsDemo',
  },

  macos: {
    bundleId: 'com.craft.examples.ts-maps-demo',
    appName: 'ts-maps Demo',
    version: '1.0.0',
    buildNumber: '1',
    minimumSystemVersion: '12.0',
    category: 'public.app-category.developer-tools',
    sandbox: false,
    entitlements: {},
    infoPlist: {
      CFBundleDisplayName: 'ts-maps Demo',
    },
  },

  windows: {
    appId: 'TsMapsDemo',
    publisher: 'CN=Craft Examples',
    displayName: 'ts-maps Demo',
    version: '1.0.0.0',
    minWindowsVersion: '10.0.17763.0',
    capabilities: [],
  },

  linux: {
    appName: 'ts-maps-demo',
    executableName: 'ts-maps-demo',
    version: '1.0.0',
    categories: ['Development', 'Utility'],
    mimeTypes: [],
  },
}

export default config
