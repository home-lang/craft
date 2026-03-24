import type { CraftAppConfig } from 'ts-craft'

const config: CraftAppConfig = {
  // App Identity
  name: 'Craft Todo',
  version: '1.0.0',
  identifier: 'com.craft.examples.todo',

  // Window Configuration
  window: {
    title: 'Craft Todo',
    width: 550,
    height: 700,
    minWidth: 320,
    minHeight: 500,
    resizable: true,
    center: true
  },

  // Entry Point
  entry: './index.html',

  // Build Options
  build: {
    outDir: 'dist',
    sourcemap: true,
    minify: true
  },

  // iOS Configuration
  ios: {
    bundleId: 'com.craft.examples.todo',
    appName: 'Craft Todo',
    version: '1.0.0',
    buildNumber: '1',
    deploymentTarget: '15.0',
    deviceFamily: ['iphone', 'ipad'],
    orientations: ['portrait', 'landscape'],
    capabilities: [],
    infoPlist: {
      CFBundleDisplayName: 'Craft Todo'
    }
  },

  // Android Configuration
  android: {
    packageName: 'com.craft.examples.todo',
    versionCode: 1,
    versionName: '1.0.0',
    minSdk: 24,
    targetSdk: 34,
    compileSdk: 34,
    permissions: [],
    features: [],
    applicationClass: 'com.craft.examples.todo.TodoApplication',
    mainActivity: 'com.craft.examples.todo.MainActivity',
    theme: '@style/Theme.CraftTodo'
  },

  // macOS Configuration
  macos: {
    bundleId: 'com.craft.examples.todo',
    appName: 'Craft Todo',
    version: '1.0.0',
    buildNumber: '1',
    minimumSystemVersion: '12.0',
    category: 'public.app-category.productivity',
    sandbox: true,
    entitlements: {},
    infoPlist: {
      CFBundleDisplayName: 'Craft Todo'
    }
  },

  // Windows Configuration
  windows: {
    appId: 'CraftTodo',
    publisher: 'CN=Craft Examples',
    displayName: 'Craft Todo',
    version: '1.0.0.0',
    minWindowsVersion: '10.0.17763.0',
    capabilities: []
  },

  // Linux Configuration
  linux: {
    appName: 'craft-todo',
    executableName: 'craft-todo',
    version: '1.0.0',
    categories: ['Utility', 'Application'],
    mimeTypes: []
  }
}

export default config
