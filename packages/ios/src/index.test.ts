import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { describe, expect, it } from 'bun:test'
import {
  init,
  renderBackgroundModes,
  renderEntitlements,
  renderOrientations,
  renderPrivacyManifest,
  renderUsageDescriptions,
  renderUrlTypes,
  syncWebAssets,
} from './index'

describe('Craft iOS builder', () => {
  it('copies a complete web distribution and removes stale assets', () => {
    const root = mkdtempSync(join(tmpdir(), 'craft-ios-assets-'))
    const source = join(root, 'web')
    const output = join(root, 'ios')
    Bun.spawnSync(['mkdir', '-p', join(source, 'assets'), join(output, 'dist')])
    writeFileSync(join(source, 'index.html'), '<main>WildLoop</main>')
    writeFileSync(join(source, 'assets', 'app.js'), 'export {}')
    writeFileSync(join(output, 'dist', 'stale.js'), 'stale')

    syncWebAssets(source, output)

    expect(readFileSync(join(output, 'dist', 'index.html'), 'utf8')).toContain('WildLoop')
    expect(existsSync(join(output, 'dist', 'assets', 'app.js'))).toBe(true)
    expect(existsSync(join(output, 'dist', 'stale.js'))).toBe(false)
  })

  it('renders only metadata for enabled native capabilities', () => {
    const config = {
      appName: 'WildLoop',
      bundleId: 'org.wildloop.app',
      enableGeolocation: true,
      enableBackgroundLocation: true,
      enableCamera: false,
      enableBiometric: true,
      orientations: ['portrait'] as const,
      urlSchemes: ['wildloop'],
    }

    expect(renderUsageDescriptions(config)).toContain('NSLocationWhenInUseUsageDescription')
    expect(renderUsageDescriptions(config)).toContain('NSLocationAlwaysAndWhenInUseUsageDescription')
    expect(renderUsageDescriptions(config)).toContain('NSFaceIDUsageDescription')
    expect(renderUsageDescriptions(config)).not.toContain('NSCameraUsageDescription')
    expect(renderOrientations(config)).toContain('UIInterfaceOrientationPortrait')
    expect(renderUrlTypes(config)).toContain('<string>wildloop</string>')
    expect(renderBackgroundModes(config)).toContain('<string>location</string>')
  })

  it('generates entitlements and privacy declarations from explicit configuration', () => {
    const config = {
      appName: 'WildLoop',
      bundleId: 'org.wildloop.app',
      associatedDomains: ['applinks:wildloop.org'],
      enableHealthKit: true,
      privacy: {
        collectedDataTypes: [{
          type: 'NSPrivacyCollectedDataTypePreciseLocation',
          linked: true,
          purposes: ['NSPrivacyCollectedDataTypePurposeAppFunctionality'],
        }],
        accessedApiTypes: [{
          type: 'NSPrivacyAccessedAPICategoryUserDefaults',
          reasons: ['CA92.1'],
        }],
      },
    }

    expect(renderEntitlements(config)).toContain('applinks:wildloop.org')
    expect(renderEntitlements(config)).toContain('com.apple.developer.healthkit')
    expect(renderPrivacyManifest(config)).toContain('NSPrivacyCollectedDataTypePreciseLocation')
    expect(renderPrivacyManifest(config)).toContain('CA92.1')
  })

  it('generates a production project whose bundled index lives under dist', async () => {
    const output = mkdtempSync(join(tmpdir(), 'craft-ios-project-'))
    await init({
      name: 'WildLoop',
      bundleId: 'org.wildloop.app',
      output,
      config: {
        enableGeolocation: true,
        enableBackgroundLocation: true,
        enableHaptics: true,
        trustedOrigins: ['https://wildloop.org'],
        associatedDomains: ['applinks:wildloop.org'],
        urlSchemes: ['wildloop'],
      },
    })

    const swift = readFileSync(join(output, 'Sources', 'WildLoopApp.swift'), 'utf8')
    const plist = readFileSync(join(output, 'Info.plist'), 'utf8')
    const generatedConfig = JSON.parse(readFileSync(join(output, 'craft.config.json'), 'utf8'))
    expect(swift).toContain('subdirectory: "dist"')
    expect(swift).toContain("craft.contractVersion = '1.0.0'")
    expect(swift).toContain('craft.location = {')
    expect(swift.match(/private var pendingCallbackId/g)?.length).toBe(1)
    expect(plist).toContain('NSLocationWhenInUseUsageDescription')
    expect(plist).toContain('<string>wildloop</string>')
    expect(plist).toContain('<string>location</string>')
    expect(existsSync(join(output, 'Craft.entitlements'))).toBe(true)
    expect(existsSync(join(output, 'PrivacyInfo.xcprivacy'))).toBe(true)
    expect(existsSync(join(output, 'Assets.xcassets', 'AppIcon.appiconset', 'Contents.json'))).toBe(true)
    expect(generatedConfig.enableHaptics).toBe(true)
    expect(generatedConfig.enableSecureStorage).toBe(false)
    expect(generatedConfig.enableScreenCapture).toBe(false)
  })
})
