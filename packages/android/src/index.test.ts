import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { describe, expect, it } from 'bun:test'
import { build, init, renderAndroidPermissions, syncAndroidWebAssets } from './index'

describe('Craft Android builder', () => {
  it('renders only permissions required by enabled capabilities', () => {
    const permissions = renderAndroidPermissions({
      appName: 'WildLoop',
      packageName: 'org.wildloop.app',
      enableGeolocation: true,
      enableCamera: false,
    })

    expect(permissions).toContain('android.permission.ACCESS_FINE_LOCATION')
    expect(permissions).not.toContain('android.permission.CAMERA')
  })

  it('copies a complete web distribution while preserving native configuration', async () => {
    const root = mkdtempSync(join(tmpdir(), 'craft-android-assets-'))
    const web = join(root, 'web')
    const output = join(root, 'android')
    Bun.spawnSync(['mkdir', '-p', join(web, 'assets')])
    writeFileSync(join(web, 'index.html'), '<main>WildLoop</main>')
    writeFileSync(join(web, 'assets', 'app.js'), 'export {}')
    await init({ name: 'WildLoop', packageName: 'org.wildloop.app', output })

    syncAndroidWebAssets(web, output)

    expect(readFileSync(join(output, 'app/src/main/assets/index.html'), 'utf8')).toContain('WildLoop')
    expect(existsSync(join(output, 'app/src/main/assets/assets/app.js'))).toBe(true)
    expect(existsSync(join(output, 'app/src/main/assets/craft.config.json'))).toBe(true)
  })

  it('generates a least-privilege bridge contract and secure manifest', async () => {
    const output = mkdtempSync(join(tmpdir(), 'craft-android-project-'))
    await init({
      name: 'WildLoop',
      packageName: 'org.wildloop.app',
      output,
      config: { enableHaptics: true, enableGeolocation: true },
    })

    const bridge = readFileSync(join(output, 'app/src/main/java/org/wildloop/app/CraftBridge.kt'), 'utf8')
    const manifest = readFileSync(join(output, 'app/src/main/AndroidManifest.xml'), 'utf8')
    expect(bridge).toContain("craft.contractVersion = '1.0.0'")
    expect(bridge).toContain('haptics: true')
    expect(bridge).toContain('camera: false')
    expect(manifest).toContain('android:allowBackup="false"')
    expect(manifest).toContain('android:usesCleartextTraffic="false"')
  })

  it('marks bundled assets as the remote-app recovery path', async () => {
    const root = mkdtempSync(join(tmpdir(), 'craft-android-fallback-'))
    const web = join(root, 'web')
    const output = join(root, 'android')
    Bun.spawnSync(['mkdir', '-p', web])
    writeFileSync(join(web, 'index.html'), '<main>Available offline</main>')
    await init({ name: 'WildLoop', packageName: 'org.wildloop.app', output })
    await build({ htmlPath: web, devServer: 'https://wildloop.org', output, compile: false })

    const config = JSON.parse(readFileSync(join(output, 'app/src/main/assets/craft.config.json'), 'utf8'))
    const activity = readFileSync(join(output, 'app/src/main/java/org/wildloop/app/MainActivity.kt'), 'utf8')
    expect(config.hasBundledFallback).toBe(true)
    expect(activity).toContain('hasBundledFallback && !loadedBundledFallback')
  })

  it('generates a foreground service for durable background recording', async () => {
    const output = mkdtempSync(join(tmpdir(), 'craft-android-location-'))
    await init({
      name: 'WildLoop',
      packageName: 'org.wildloop.app',
      output,
      config: { enableBackgroundLocation: true },
    })

    const service = readFileSync(join(output, 'app/src/main/java/org/wildloop/app/LocationRecordingService.kt'), 'utf8')
    const bridge = readFileSync(join(output, 'app/src/main/java/org/wildloop/app/CraftBridge.kt'), 'utf8')
    const manifest = readFileSync(join(output, 'app/src/main/AndroidManifest.xml'), 'utf8')
    expect(service).toContain('START_STICKY')
    expect(service).toContain('CraftLocationRecordingStore.append')
    expect(bridge).toContain('startRecording: function(options)')
    expect(bridge).toContain('fun stopLocationRecording()')
    expect(manifest).toContain('android:foregroundServiceType="location"')
  })
})
