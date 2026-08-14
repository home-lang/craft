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
    expect(readFileSync(join(output, 'app/proguard-rules.pro'), 'utf8')).toContain('android.webkit.JavascriptInterface')
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

  it('uses Firebase Cloud Messaging instead of placeholder push tokens', async () => {
    const root = mkdtempSync(join(tmpdir(), 'craft-android-push-'))
    const output = join(root, 'android')
    const googleServicesFile = join(root, 'google-services.json')
    writeFileSync(googleServicesFile, JSON.stringify({ project_info: { project_number: '1' } }))
    await init({
      name: 'WildLoop',
      packageName: 'org.wildloop.app',
      output,
      config: { enablePushNotifications: true, googleServicesFile },
    })

    const bridge = readFileSync(join(output, 'app/src/main/java/org/wildloop/app/CraftBridge.kt'), 'utf8')
    const appGradle = readFileSync(join(output, 'app/build.gradle.kts'), 'utf8')
    const projectGradle = readFileSync(join(output, 'build.gradle.kts'), 'utf8')
    expect(bridge).toContain('FirebaseMessaging.getInstance().token')
    expect(bridge).not.toContain('push-token-placeholder')
    expect(bridge).not.toContain('?: \\"Review flow failed\\"')
    expect(appGradle).toContain('com.google.firebase:firebase-messaging')
    expect(appGradle).toContain('id("com.google.gms.google-services")')
    expect(projectGradle).toContain('id("com.google.gms.google-services")')
    expect(existsSync(join(output, 'app/google-services.json'))).toBe(true)
  })

  it('declares the libraries used by the generated bridge', async () => {
    const output = mkdtempSync(join(tmpdir(), 'craft-android-dependencies-'))
    await init({ name: 'WildLoop', packageName: 'org.wildloop.app', output })
    const gradle = readFileSync(join(output, 'app/build.gradle.kts'), 'utf8')
    expect(gradle).toContain('androidx.fragment:fragment-ktx')
    expect(gradle).toContain('com.google.mlkit:barcode-scanning')
    expect(gradle).toContain('com.google.mlkit:image-labeling')
    expect(gradle).toContain('com.google.mlkit:object-detection')
    expect(gradle).toContain('com.google.mlkit:text-recognition')
  })

  it('generates Health Connect permissions, APIs, and workout write-back only when enabled', async () => {
    const output = mkdtempSync(join(tmpdir(), 'craft-android-health-'))
    await init({
      name: 'WildLoop',
      packageName: 'org.wildloop.app',
      output,
      config: { enableHealthConnect: true },
    })

    const bridge = readFileSync(join(output, 'app/src/main/java/org/wildloop/app/CraftBridge.kt'), 'utf8')
    const health = readFileSync(join(output, 'app/src/main/java/org/wildloop/app/CraftHealthConnect.kt'), 'utf8')
    const manifest = readFileSync(join(output, 'app/src/main/AndroidManifest.xml'), 'utf8')
    const gradle = readFileSync(join(output, 'app/build.gradle.kts'), 'utf8')
    expect(bridge).toContain('health: true')
    expect(bridge).toContain('saveHealthWorkout')
    expect(health).toContain('HealthConnectClient')
    expect(health).toContain('ExerciseSessionRecord')
    expect(manifest).toContain('android.permission.health.WRITE_EXERCISE')
    expect(manifest).toContain('com.google.android.apps.healthdata')
    expect(manifest).toContain('android.intent.category.HEALTH_PERMISSIONS')
    expect(gradle).toContain('androidx.health.connect:connect-client')
    expect(gradle).toContain('compileSdk = 36')
  })
})
