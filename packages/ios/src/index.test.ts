import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { describe, expect, it } from 'bun:test'
import { init, renderOrientations, renderUsageDescriptions, renderUrlTypes, syncWebAssets } from './index'

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
      enableCamera: false,
      enableBiometric: true,
      orientations: ['portrait'] as const,
      urlSchemes: ['wildloop'],
    }

    expect(renderUsageDescriptions(config)).toContain('NSLocationWhenInUseUsageDescription')
    expect(renderUsageDescriptions(config)).toContain('NSFaceIDUsageDescription')
    expect(renderUsageDescriptions(config)).not.toContain('NSCameraUsageDescription')
    expect(renderOrientations(config)).toContain('UIInterfaceOrientationPortrait')
    expect(renderUrlTypes(config)).toContain('<string>wildloop</string>')
  })

  it('generates a production project whose bundled index lives under dist', async () => {
    const output = mkdtempSync(join(tmpdir(), 'craft-ios-project-'))
    await init({
      name: 'WildLoop',
      bundleId: 'org.wildloop.app',
      output,
      config: {
        enableGeolocation: true,
        enableHaptics: true,
        urlSchemes: ['wildloop'],
      },
    })

    const swift = readFileSync(join(output, 'Sources', 'WildLoopApp.swift'), 'utf8')
    const plist = readFileSync(join(output, 'Info.plist'), 'utf8')
    const generatedConfig = JSON.parse(readFileSync(join(output, 'craft.config.json'), 'utf8'))
    expect(swift).toContain('subdirectory: "dist"')
    expect(swift.match(/private var pendingCallbackId/g)?.length).toBe(1)
    expect(plist).toContain('NSLocationWhenInUseUsageDescription')
    expect(plist).toContain('<string>wildloop</string>')
    expect(generatedConfig.enableHaptics).toBe(true)
    expect(generatedConfig.enableSecureStorage).toBe(false)
    expect(generatedConfig.enableScreenCapture).toBe(false)
  })
})
