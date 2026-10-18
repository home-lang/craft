import { afterAll, describe, expect, it } from 'bun:test'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { init } from './index'
import { createTempDir, removeAllTempDirs } from '../../typescript/src/temp-dir'

afterAll(removeAllTempDirs)

describe('native Android map provider generation', () => {
  it('builds a MapLibre host without a Google map SDK dependency or key', async () => {
    const output = createTempDir('craft-native-maplibre-')
    await init({ name: 'Native maps', output, runtimeDir: null, config: { renderer: 'native', mapProvider: 'maplibre', enableGeolocation: true } })
    const source = readFileSync(join(output, 'app/src/main/java/com/craft/native/MainActivity.kt'), 'utf8')
    const gradle = readFileSync(join(output, 'app/build.gradle.kts'), 'utf8')
    const manifest = readFileSync(join(output, 'app/src/main/AndroidManifest.xml'), 'utf8')
    expect(source).toContain('MapLibre.getInstance(context)')
    expect(source).toContain('MapView(context)')
    expect(source).toContain('GeoJsonSource("craft-map-overlays")')
    expect(source).toContain('iconRotationAlignment("map")')
    expect(source).toContain('LocationComponentActivationOptions.builder(context, style)')
    expect(source).not.toContain('com.google.android.gms.maps')
    expect(source).not.toContain('GoogleMap')
    expect(source).not.toContain('{{NATIVE_MAP_')
    expect(gradle).toContain('org.maplibre.gl:android-sdk:13.7.1')
    expect(gradle).not.toContain('play-services-maps')
    expect(manifest).not.toContain('com.google.android.geo.API_KEY')
    expect(JSON.parse(readFileSync(join(output, 'craft.config.json'), 'utf8')).mapProvider).toBe('maplibre')
    // Native STX uses the Android JavaScript engine and real views, not the
    // ts-maps DOM adapter mounted as a substitute for the native map.
    expect(source).toContain('JavaScriptSandbox.isSupported()')
    expect(source).not.toContain('import android.webkit.WebView')
  })

  it('keeps the existing Google host when explicitly selected', async () => {
    const output = createTempDir('craft-native-google-map-')
    await init({ name: 'Google maps', output, runtimeDir: null, config: { renderer: 'native', mapProvider: 'google', mapsApiKey: 'restricted-fixture-key' } })
    const source = readFileSync(join(output, 'app/src/main/java/com/craft/native/MainActivity.kt'), 'utf8')
    const gradle = readFileSync(join(output, 'app/build.gradle.kts'), 'utf8')
    const manifest = readFileSync(join(output, 'app/src/main/AndroidManifest.xml'), 'utf8')
    expect(source).toContain('com.google.android.gms.maps.GoogleMap')
    expect(source).not.toContain('org.maplibre.android')
    expect(gradle).toContain('com.google.android.gms:play-services-maps:18.2.0')
    expect(gradle).not.toContain('org.maplibre.gl:android-sdk')
    expect(manifest).toContain('android:name="com.google.android.geo.API_KEY" android:value="restricted-fixture-key"')
  })

  it('does not emit an unused Google map key for a MapLibre app', async () => {
    const output = createTempDir('craft-maplibre-manifest-')
    await init({ name: 'MapLibre', output, runtimeDir: null, config: { renderer: 'native', mapProvider: 'maplibre', mapsApiKey: 'unused-fixture-key' } })
    const manifest = readFileSync(join(output, 'app/src/main/AndroidManifest.xml'), 'utf8')
    expect(manifest).not.toContain('com.google.android.geo.API_KEY')
    expect(manifest).not.toContain('unused-fixture-key')
  })

  it('rejects an unsupported native map provider before generating a project', async () => {
    const output = createTempDir('craft-unknown-map-provider-')
    // Exercise untyped JSON input, which still needs runtime validation.
    await expect(init({ name: 'Unknown maps', output, runtimeDir: null, config: { renderer: 'native', mapProvider: 'unknown' as never } })).rejects.toThrow('Unknown Android native map provider')
  })
})
