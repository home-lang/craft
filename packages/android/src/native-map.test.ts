import { afterAll, describe, expect, it } from 'bun:test'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { init } from './index'
import { runKotlinFixture } from './testing'
import { createTempDir, removeAllTempDirs } from '../../typescript/src/temp-dir'

afterAll(removeAllTempDirs)

describe('native Android map provider generation', () => {
  it('keys native Google map overlays by their typed coordinates', async () => {
    const template = readFileSync(join(import.meta.dir, '../templates/CraftNativeMapGoogle.kt.template'), 'utf8')
    const polygon = template.match(/    private data class PolygonValue[^\n]+/)?.[0]
    const key = template.match(/    private fun overlayKey\([\s\S]*?\n    \}/)?.[0]
    if (!polygon || !key) throw new Error('Native Google map overlay declarations are missing')
    await runKotlinFixture(`
data class LatLng(val latitude: Double, val longitude: Double)
${polygon}
${key}
fun main() {
    val markers = mapOf("b" to Pair(LatLng(3.0, 4.0), null), "a" to Pair(LatLng(1.0, 2.0), "label"))
    val lines = mapOf("p" to Triple(listOf(LatLng(5.0, 6.0), LatLng(7.0, 8.0)), 1, 2f))
    val areas = mapOf("g" to PolygonValue(listOf(LatLng(9.0, 10.0), LatLng(11.0, 12.0), LatLng(13.0, 14.0)), 1, 2, 3f))
    val original = overlayKey(markers, lines, areas)
    check(original == "m[a:1.0,2.0|b:3.0,4.0]p[p:5.0,6.0;7.0,8.0]g[g:9.0,10.0;11.0,12.0;13.0,14.0]") { original }
    check(overlayKey(markers, lines + ("p" to Triple(listOf(LatLng(15.0, 16.0)), 1, 2f)), areas) != original)
    check(overlayKey(markers, lines, areas + ("g" to PolygonValue(listOf(LatLng(17.0, 18.0)), 1, 2, 3f))) != original)
    check(overlayKey(markers, lines + ("p" to lines.getValue("p").copy(second = 9, third = 10f)), areas) == original)
    println("PASS native Google map overlay identity follows geometry without reframing for line styling")
}
`)
  }, 180_000)

  it('builds a MapLibre host without a Google map SDK dependency or key', async () => {
    const output = createTempDir('craft-native-maplibre-')
    await init({ name: 'Native maps', packageName: 'com.craft.native', output, runtimeDir: null, config: { renderer: 'native', mapProvider: 'maplibre', enableGeolocation: true } })
    const source = readFileSync(join(output, 'app/src/main/java/com/craft/native/MainActivity.kt'), 'utf8')
    const gradle = readFileSync(join(output, 'app/build.gradle.kts'), 'utf8')
    const manifest = readFileSync(join(output, 'app/src/main/AndroidManifest.xml'), 'utf8')
    expect(source).toContain('MapLibre.getInstance(context)')
    expect(source).toContain('MapView(context)')
    expect(source).toContain('GeoJsonSource("craft-map-overlays")')
    expect(source).toContain('"Map" ->')
    expect(source).toContain('CraftNativeMapView')
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
    await init({ name: 'Google maps', packageName: 'com.craft.native', output, runtimeDir: null, config: { renderer: 'native', mapProvider: 'google', mapsApiKey: 'restricted-fixture-key' } })
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
