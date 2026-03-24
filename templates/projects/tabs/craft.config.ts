import type { CraftAppConfig } from '@craft-native/craft'

const config: CraftAppConfig = {
  name: '{{APP_NAME}}',
  version: '1.0.0',
  identifier: '{{BUNDLE_ID}}',

  window: {
    title: '{{APP_NAME}}',
    width: 400,
    height: 700,
    minWidth: 320,
    minHeight: 568,
    resizable: true,
    center: true
  },

  entry: './index.html',

  ios: {
    bundleId: '{{BUNDLE_ID}}',
    appName: '{{APP_NAME}}',
    version: '1.0.0',
    buildNumber: '1',
    deploymentTarget: '15.0',
    deviceFamily: ['iphone', 'ipad'],
    orientations: ['portrait', 'landscape'],
    capabilities: [],
    infoPlist: {}
  },

  android: {
    packageName: '{{BUNDLE_ID}}',
    versionCode: 1,
    versionName: '1.0.0',
    minSdk: 24,
    targetSdk: 34,
    compileSdk: 34,
    permissions: [],
    features: [],
    applicationClass: '{{BUNDLE_ID}}.App',
    mainActivity: '{{BUNDLE_ID}}.MainActivity',
    theme: '@style/Theme.App'
  }
}

export default config
