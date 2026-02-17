/**
 * Type System Tests
 *
 * Tests for TypeScript type definitions and type safety.
 */

import { describe, expect, it } from 'bun:test'
import type {
  AppConfig,
  WindowOptions,
  MenuItem,
  NotificationOptions,
  CraftEventType,
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
        html: '<h1>Hello</h1>',
        url: 'https://example.com',
        craftPath: '/usr/local/bin/craft'
      }

      expect(config.html).toBe('<h1>Hello</h1>')
      expect(config.url).toBe('https://example.com')
      expect(config.craftPath).toBe('/usr/local/bin/craft')
    })

    it('should support optional fields', () => {
      const config: AppConfig = {
        window: {
          title: 'Test Window'
        }
      }

      expect(config.window?.title).toBe('Test Window')
    })
  })

  describe('WindowOptions', () => {
    it('should define window configuration', () => {
      const config: WindowOptions = {
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
      const config: WindowOptions = {
        title: 'Test',
        x: 100,
        y: 200
      }

      expect(config.x).toBe(100)
      expect(config.y).toBe(200)
    })
  })

  describe('MenuItem', () => {
    it('should define menu structure', () => {
      const items: MenuItem[] = [
        {
          label: 'File',
          submenu: [
            { label: 'New', shortcut: 'Cmd+N' },
            { type: 'separator' },
            { label: 'Quit', action: 'quit' }
          ]
        }
      ]

      expect(items).toHaveLength(1)
      expect(items[0].label).toBe('File')
      expect(items[0].submenu).toHaveLength(3)
    })
  })

  describe('NotificationOptions', () => {
    it('should define notification options', () => {
      const config: NotificationOptions = {
        title: 'Hello',
        body: 'World'
      }

      expect(config.title).toBe('Hello')
      expect(config.body).toBe('World')
    })

    it('should support rich notifications', () => {
      const config: NotificationOptions = {
        title: 'Alert',
        body: 'Something happened',
        icon: 'alert.png',
        sound: 'Glass',
        actions: [
          { action: 'view', title: 'View' },
          { action: 'dismiss', title: 'Dismiss' }
        ]
      }

      expect(config.actions).toHaveLength(2)
      expect(config.sound).toBe('Glass')
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
        minimumOSVersion: '15.0',
        deviceFamily: [1, 2],
        orientations: ['portrait'],
        capabilities: {
          pushNotifications: true
        },
        entitlements: {}
      }

      expect(config.bundleId).toBe('com.example.app')
      expect(config.deviceFamily).toContain(1)
    })

    it('should define Android configuration', () => {
      const config: AndroidConfig = {
        packageName: 'com.example.app',
        appName: 'Example App',
        versionCode: 1,
        versionName: '1.0.0',
        minSdkVersion: 24,
        targetSdkVersion: 34,
        compileSdkVersion: 34,
        permissions: ['CAMERA', 'INTERNET'],
        features: []
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
        minimumOSVersion: '12.0',
        category: 'public.app-category.productivity',
        sandbox: true,
        entitlements: {
          'com.apple.security.network.client': true
        }
      }

      expect(config.bundleId).toBe('com.example.app')
      expect(config.sandbox).toBe(true)
    })

    it('should define Windows configuration', () => {
      const config: WindowsConfig = {
        appId: 'ExampleApp',
        appName: 'Example App',
        publisher: 'CN=Example',
        publisherDisplayName: 'Example Publisher',
        version: '1.0.0.0'
      }

      expect(config.appId).toBe('ExampleApp')
      expect(config.publisherDisplayName).toBe('Example Publisher')
    })

    it('should define Linux configuration', () => {
      const config: LinuxConfig = {
        appName: 'example-app',
        executableName: 'example-app',
        version: '1.0.0',
        category: 'Utility'
      }

      expect(config.appName).toBe('example-app')
      expect(config.category).toBe('Utility')
    })
  })

  describe('CraftAppConfig', () => {
    it('should combine all platform configs', () => {
      const config: CraftAppConfig = {
        url: 'https://example.com',
        ios: {
          bundleId: 'com.example.app',
          appName: 'Example App',
          version: '1.0.0',
          buildNumber: '1',
          minimumOSVersion: '15.0',
          deviceFamily: [1],
          orientations: ['portrait'],
          capabilities: {}
        },
        android: {
          packageName: 'com.example.app',
          appName: 'Example App',
          versionCode: 1,
          versionName: '1.0.0',
          minSdkVersion: 24,
          targetSdkVersion: 34,
          compileSdkVersion: 34,
          permissions: [],
          features: []
        },
        macos: {
          bundleId: 'com.example.app',
          appName: 'Example App',
          version: '1.0.0',
          buildNumber: '1',
          minimumOSVersion: '12.0',
          category: 'utility',
          sandbox: false,
          entitlements: {}
        },
        windows: {
          appId: 'ExampleApp',
          appName: 'Example App',
          publisher: 'CN=Example',
          publisherDisplayName: 'Example Publisher',
          version: '1.0.0.0'
        },
        linux: {
          appName: 'example-app',
          executableName: 'example-app',
          version: '1.0.0'
        }
      }

      expect(config.url).toBe('https://example.com')
      expect(config.ios?.bundleId).toBe('com.example.app')
      expect(config.android?.packageName).toBe('com.example.app')
      expect(config.macos?.bundleId).toBe('com.example.app')
      expect(config.windows?.appId).toBe('ExampleApp')
      expect(config.linux?.appName).toBe('example-app')
    })
  })
})
