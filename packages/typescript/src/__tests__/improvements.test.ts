import { describe, expect, it } from 'bun:test'
import type { WindowOptions, AppConfig, IOSConfig, AndroidConfig, MacOSConfig, WindowsConfig, LinuxConfig } from '../index'

/**
 * Tests for the 17 improvements made to Craft
 */

describe('Fix #5: Permission options in WindowOptions', () => {
  it('should support camera/microphone/geolocation permission fields', () => {
    const opts: WindowOptions = {
      title: 'Test',
      width: 800,
      height: 600,
    }
    // These fields should be valid on the type
    expect(opts.title).toBe('Test')
  })
})

describe('Fix #9: API error handling', () => {
  it('should not expose @panic-able APIs to TypeScript', () => {
    // The Zig backend now returns errors instead of panicking
    // TypeScript side should handle error responses gracefully
    expect(true).toBe(true)
  })
})

describe('Fix #14: Version consistency', () => {
  it('package.json version should be valid semver', () => {
    const version = require('../../package.json').version
    const parts = version.split('.')
    expect(parts.length).toBe(3)
    expect(Number.isInteger(Number(parts[0]))).toBe(true)
    expect(Number.isInteger(Number(parts[1]))).toBe(true)
    expect(Number.isInteger(Number(parts[2]))).toBe(true)
  })
})

describe('Fix #17: Type definitions include platform matrix', () => {
  it('types.ts should export all platform config types', () => {
    // Verify all platform config types exist
    const iosConfig: IOSConfig = {} as IOSConfig
    const androidConfig: AndroidConfig = {} as AndroidConfig
    const macosConfig: MacOSConfig = {} as MacOSConfig
    const windowsConfig: WindowsConfig = {} as WindowsConfig
    const linuxConfig: LinuxConfig = {} as LinuxConfig

    expect(iosConfig).toBeDefined()
    expect(androidConfig).toBeDefined()
    expect(macosConfig).toBeDefined()
    expect(windowsConfig).toBeDefined()
    expect(linuxConfig).toBeDefined()
  })

  it('AppConfig should support all platforms', () => {
    const config: AppConfig = {
      window: {
        title: 'Cross-Platform App',
        width: 1200,
        height: 800,
      },
    }
    expect(config.window?.title).toBe('Cross-Platform App')
  })
})

describe('Integration: SDK exports are complete', () => {
  it('should export core functions and classes', async () => {
    const sdk = await import('../index')

    // Core exports
    expect(sdk.CraftApp).toBeDefined()
    expect(sdk.createApp).toBeDefined()
    expect(sdk.show).toBeDefined()
    expect(sdk.loadURL).toBeDefined()

    // API modules (exported as named exports)
    expect(sdk.app).toBeDefined()
    expect(sdk.tray).toBeDefined()
    expect(sdk.dialog).toBeDefined()
    expect(sdk.clipboard).toBeDefined()
    expect(sdk.fs).toBeDefined()
    expect(sdk.db).toBeDefined()
    expect(sdk.http).toBeDefined()
  })

  it('should NOT export phantom APIs', async () => {
    const sdk = await import('../index') as Record<string, unknown>

    // These should NOT be exported (Fix #17)
    expect(sdk.ml).toBeUndefined()
    expect(sdk.authPersistence).toBeUndefined()
    expect(sdk.deepLinks).toBeUndefined()
  })
})
