import { describe, expect, it } from 'bun:test'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

/*
 * `<Map basemap="...">` is drawn by the host, as well as each platform can.
 * These pin the shape of that on both: the presets, the tile cache, the
 * layering that keeps routes above the topography, and direction marks that
 * thin themselves instead of stacking over the line.
 */
const ios = readFileSync(join(import.meta.dir, '../templates/CraftNativeScreen.swift'), 'utf8')
const android = readFileSync(join(import.meta.dir, '../../android/templates/CraftNativeMapLibre.kt.template'), 'utf8')

describe('native map basemaps', () => {
  it('draws Apple\'s map with real terrain on iOS, and topography over a muted map for outdoors', () => {
    expect(ios).toContain('enum CraftBasemap: String {')
    expect(ios).toContain('case .satellite: preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)')
    expect(ios).toContain('case .hybrid: preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)')
    expect(ios).toContain('case .standard: preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)')
    expect(ios).toContain('case .outdoors: preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)')
    // The topography covers the map, not replaces it: no empty grid while tiles load.
    expect(ios).toContain('configureTiles(basemap == .outdoors ? ["urlTemplate": CraftBasemap.outdoorTiles, "attribution": CraftBasemap.outdoorCredit] : nil, replacesMap: false)')
  })

  it('keeps tiles on disk, and routes above the topography', () => {
    expect(ios).toContain('final class CraftCachedTileOverlay: MKTileOverlay {')
    expect(ios).toContain('configuration.requestCachePolicy = .returnCacheDataElseLoad')
    expect(ios).toContain('insertOverlay(overlay, at: 0, level: replacesMap ? .aboveRoads : .aboveLabels)')
    expect(ios).toContain('addOverlay(overlay, level: .aboveLabels)')
    expect(ios).toContain('addOverlay(polygon, level: .aboveLabels)')
  })

  it('draws direction as small chevrons that MapKit thins by zoom', () => {
    expect(ios).toContain('private static func directionImage(color: UIColor, key: NSString) -> UIImage {')
    expect(ios).toContain('view.displayPriority = .defaultLow')
    expect(ios).toContain('view.collisionMode = .circle')
    expect(ios).toContain('view.displayPriority = .required')
  })

  it('uses a vector style for Android\'s standard basemap, not openstreetmap.org raster tiles', () => {
    expect(android).toContain('"standard" -> {')
    expect(android).toContain('return vectorStylePrefix + "https://tiles.openfreemap.org/styles/liberty"')
    expect(android).toContain('Style.Builder().fromUri(nextStyle.removePrefix(vectorStylePrefix))')
    for (const preset of ['"outdoors"', '"satellite"', '"hybrid"']) expect(android).toContain(`${preset} -> return rasterStyle(`)
  })
})
