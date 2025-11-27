/**
 * Type System Tests
 *
 * Tests for TypeScript type definitions and type safety.
 */

import { describe, expect, it } from 'bun:test'
import type {
  AppConfig,
  WindowConfig,
  MenuConfig,
  TrayConfig,
  NotificationConfig,
  CraftEventType,
  CraftEventMap,
  CraftEventEmitter,
  IOSConfig,
  AndroidConfig,
  MacOSConfig,
  WindowsConfig,
  LinuxConfig,
  CraftAppConfig
} from '../types'

describe('Type Definitions', () => {
  describe('AppConfig', () => {
    it('should define basic app configuration', () => {
      const config: AppConfig = {
        name: 'Test App',
        version: '1.0.0',
        identifier: 'com.test.app'
      }

      expect(config.name).toBe('Test App')
      expect(config.version).toBe('1.0.0')
      expect(config.identifier).toBe('com.test.app')
    })

    it('should support optional fields', () => {
      const config: AppConfig = {
        name: 'Test App',
        version: '1.0.0',
        identifier: 'com.test.app',
        window: {
          title: 'Test Window'
        }
      }

      expect(config.window?.title).toBe('Test Window')
    })
  })

  describe('WindowConfig', () => {
    it('should define window configuration', () => {
      const config: WindowConfig = {
        title: 'My Window',
        width: 800,
        height: 600,
        resizable: true,
        alwaysOnTop: false
      }

      expect(config.title).toBe('My Window')
      expect(config.width).toBe(800)
      expect(config.height).toBe(600)
      expect(config.resizable).toBe(true)
    })

    it('should support all position options', () => {
      const config: WindowConfig = {
        title: 'Test',
        x: 100,
        y: 200,
        center: false
      }

      expect(config.x).toBe(100)
      expect(config.y).toBe(200)
      expect(config.center).toBe(false)
    })
  })

  describe('MenuConfig', () => {
    it('should define menu structure', () => {
      const config: MenuConfig = {
        items: [
          {
            label: 'File',
            submenu: [
              { label: 'New', accelerator: 'Cmd+N' },
              { type: 'separator' },
              { label: 'Quit', role: 'quit' }
            ]
          }
        ]
      }

      expect(config.items).toHaveLength(1)
      expect(config.items[0].label).toBe('File')
      expect(config.items[0].submenu).toHaveLength(3)
    })
  })

  describe('TrayConfig', () => {
    it('should define tray configuration', () => {
      const config: TrayConfig = {
        icon: 'icon.png',
        tooltip: 'My App'
      }

      expect(config.icon).toBe('icon.png')
      expect(config.tooltip).toBe('My App')
    })

    it('should support menu in tray', () => {
      const config: TrayConfig = {
        icon: 'icon.png',
        menu: {
          items: [
            { label: 'Show', click: 'show' },
            { label: 'Quit', click: 'quit' }
          ]
        }
      }

      expect(config.menu?.items).toHaveLength(2)
    })
  })

  describe('NotificationConfig', () => {
    it('should define notification options', () => {
      const config: NotificationConfig = {
        title: 'Hello',
        body: 'World'
      }

      expect(config.title).toBe('Hello')
      expect(config.body).toBe('World')
    })

    it('should support rich notifications', () => {
      const config: NotificationConfig = {
        title: 'Alert',
        body: 'Something happened',
        icon: 'alert.png',
        silent: false,
        actions: [
          { id: 'view', title: 'View' },
          { id: 'dismiss', title: 'Dismiss' }
        ]
      }

      expect(config.actions).toHaveLength(2)
      expect(config.silent).toBe(false)
    })
  })

  describe('CraftEventType', () => {
    it('should include window events', () => {
      const events: CraftEventType[] = [
        'window:focus',
        'window:blur',
        'window:resize',
        'window:move',
        'window:close',
        'window:minimize',
        'window:maximize',
        'window:fullscreen'
      ]

      expect(events).toContain('window:focus')
      expect(events).toContain('window:resize')
    })

    it('should include app events', () => {
      const events: CraftEventType[] = [
        'app:activate',
        'app:deactivate',
        'app:beforeQuit',
        'app:willQuit'
      ]

      expect(events).toContain('app:activate')
      expect(events).toContain('app:beforeQuit')
    })

    it('should include system events', () => {
      const events: CraftEventType[] = [
        'theme:change',
        'network:online',
        'network:offline',
        'battery:low',
        'idle:active'
      ]

      expect(events).toContain('theme:change')
      expect(events).toContain('network:online')
    })
  })

  describe('Platform Configs', () => {
    it('should define iOS configuration', () => {
      const config: IOSConfig = {
        bundleId: 'com.example.app',
        appName: 'Example App',
        version: '1.0.0',
        buildNumber: '1',
        deploymentTarget: '15.0',
        deviceFamily: ['iphone', 'ipad'],
        orientations: ['portrait'],
        capabilities: ['push-notifications'],
        infoPlist: {}
      }

      expect(config.bundleId).toBe('com.example.app')
      expect(config.deviceFamily).toContain('iphone')
    })

    it('should define Android configuration', () => {
      const config: AndroidConfig = {
        packageName: 'com.example.app',
        versionCode: 1,
        versionName: '1.0.0',
        minSdk: 24,
        targetSdk: 34,
        compileSdk: 34,
        permissions: ['CAMERA', 'INTERNET'],
        features: [],
        applicationClass: 'com.example.app.App',
        mainActivity: 'com.example.app.MainActivity',
        theme: '@style/AppTheme'
      }

      expect(config.packageName).toBe('com.example.app')
      expect(config.permissions).toContain('CAMERA')
    })

    it('should define macOS configuration', () => {
      const config: MacOSConfig = {
        bundleId: 'com.example.app',
        appName: 'Example App',
        version: '1.0.0',
        buildNumber: '1',
        minimumSystemVersion: '12.0',
        category: 'public.app-category.productivity',
        sandbox: true,
        entitlements: {
          'com.apple.security.network.client': true
        },
        infoPlist: {}
      }

      expect(config.bundleId).toBe('com.example.app')
      expect(config.sandbox).toBe(true)
    })

    it('should define Windows configuration', () => {
      const config: WindowsConfig = {
        appId: 'ExampleApp',
        publisher: 'CN=Example',
        displayName: 'Example App',
        version: '1.0.0.0',
        minWindowsVersion: '10.0.17763.0',
        capabilities: ['internetClient']
      }

      expect(config.appId).toBe('ExampleApp')
      expect(config.capabilities).toContain('internetClient')
    })

    it('should define Linux configuration', () => {
      const config: LinuxConfig = {
        appName: 'example-app',
        executableName: 'example-app',
        version: '1.0.0',
        categories: ['Utility'],
        mimeTypes: ['text/plain']
      }

      expect(config.appName).toBe('example-app')
      expect(config.categories).toContain('Utility')
    })
  })

  describe('CraftAppConfig', () => {
    it('should combine all platform configs', () => {
      const config: CraftAppConfig = {
        name: 'Cross-Platform App',
        version: '1.0.0',
        identifier: 'com.example.app',
        ios: {
          bundleId: 'com.example.app',
          appName: 'Example App',
          version: '1.0.0',
          buildNumber: '1',
          deploymentTarget: '15.0',
          deviceFamily: ['iphone'],
          orientations: ['portrait'],
          capabilities: [],
          infoPlist: {}
        },
        android: {
          packageName: 'com.example.app',
          versionCode: 1,
          versionName: '1.0.0',
          minSdk: 24,
          targetSdk: 34,
          compileSdk: 34,
          permissions: [],
          features: [],
          applicationClass: 'App',
          mainActivity: 'MainActivity',
          theme: '@style/Theme'
        },
        macos: {
          bundleId: 'com.example.app',
          appName: 'Example App',
          version: '1.0.0',
          buildNumber: '1',
          minimumSystemVersion: '12.0',
          category: 'utility',
          sandbox: false,
          entitlements: {},
          infoPlist: {}
        },
        windows: {
          appId: 'ExampleApp',
          publisher: 'CN=Example',
          displayName: 'Example App',
          version: '1.0.0.0',
          minWindowsVersion: '10.0.0.0',
          capabilities: []
        },
        linux: {
          appName: 'example-app',
          executableName: 'example-app',
          version: '1.0.0',
          categories: [],
          mimeTypes: []
        }
      }

      expect(config.name).toBe('Cross-Platform App')
      expect(config.ios?.bundleId).toBe('com.example.app')
      expect(config.android?.packageName).toBe('com.example.app')
      expect(config.macos?.bundleId).toBe('com.example.app')
      expect(config.windows?.appId).toBe('ExampleApp')
      expect(config.linux?.appName).toBe('example-app')
    })
  })
})
