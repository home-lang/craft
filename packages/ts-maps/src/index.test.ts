/**
 * Smoke tests for `@craft-native/ts-maps`. Runs under Bun's `bun:test`
 * with `very-happy-dom` providing a DOM shim (see `test/preload.ts`).
 */

import { describe, expect, it } from 'bun:test'
import {
  cameraToCamera,
  coordinateFromLatLng,
  craftCoordToLatLng,
  latLngFromCoordinate,
  latLngToCraftCoord,
  regionFromBounds,
  tsMapsProvider,
} from './index'
import { LatLng } from 'ts-maps'

describe('tsMapsProvider', () => {
  it('matches the Zig MapProvider.ts_maps tag', () => {
    expect(tsMapsProvider).toBe('ts_maps')
  })
})

describe('adapters.craftCoordToLatLng', () => {
  it('produces a LatLng at the right coordinates', () => {
    const ll = craftCoordToLatLng({ latitude: 40, longitude: -74 })
    expect(ll).toBeInstanceOf(LatLng)
    expect(ll.lat).toBe(40)
    expect(ll.lng).toBe(-74)
  })

  it('round-trips losslessly via latLngToCraftCoord', () => {
    const coord = { latitude: 37.7749, longitude: -122.4194 }
    const back = latLngToCraftCoord(craftCoordToLatLng(coord))
    expect(back.latitude).toBeCloseTo(coord.latitude, 10)
    expect(back.longitude).toBeCloseTo(coord.longitude, 10)
  })
})

describe('spec-named aliases', () => {
  it('latLngFromCoordinate is an alias for craftCoordToLatLng', () => {
    const ll = latLngFromCoordinate({ latitude: 10, longitude: 20 })
    expect(ll.lat).toBe(10)
    expect(ll.lng).toBe(20)
  })

  it('coordinateFromLatLng is an alias for latLngToCraftCoord', () => {
    const coord = coordinateFromLatLng(new LatLng(1, 2))
    expect(coord.latitude).toBe(1)
    expect(coord.longitude).toBe(2)
  })
})

describe('adapters.cameraToCamera', () => {
  it('converts camera fields and re-maps heading -> bearing', () => {
    const opts = cameraToCamera({
      center: { latitude: 10, longitude: 20 },
      zoom: 12,
      pitch: 45,
      heading: 90,
    })
    expect(opts.zoom).toBe(12)
    expect(opts.pitch).toBe(45)
    expect(opts.bearing).toBe(90)
    expect(opts.center.lat).toBe(10)
    expect(opts.center.lng).toBe(20)
  })
})

describe('regionFromBounds', () => {
  it('returns null for an empty list', () => {
    expect(regionFromBounds([])).toBeNull()
  })

  it('centers on the midpoint and spans the delta', () => {
    const region = regionFromBounds([
      { latitude: 0, longitude: 0 },
      { latitude: 10, longitude: 10 },
    ])
    expect(region).not.toBeNull()
    expect(region!.center.latitude).toBe(5)
    expect(region!.center.longitude).toBe(5)
    expect(region!.span.latitude_delta).toBe(10)
    expect(region!.span.longitude_delta).toBe(10)
  })
})

describe('createMapView', () => {
  // The DOM shim occasionally has loading issues (see preload.ts); if
  // `document` isn't available we skip this block rather than fail.
  const hasDom = typeof document !== 'undefined'
  const maybe = hasDom ? it : it.skip

  maybe('returns an instance with id, container, and map', async () => {
    // Dynamic import keeps the module from being evaluated when the DOM
    // shim couldn't register, which avoids noisy module-load errors in
    // environments where `very-happy-dom` fails to bootstrap.
    const { createMapView } = await import('./MapView')
    const instance = createMapView()
    expect(typeof instance.id).toBe('string')
    // `very-happy-dom` returns a `VirtualElement` proxying `HTMLDivElement`,
    // so `instanceof HTMLDivElement` fails. Feature-check the shape instead.
    expect(instance.container).toBeDefined()
    expect(typeof instance.container.appendChild).toBe('function')
    expect(instance.container.tagName).toBe('DIV')
    expect(instance.map).toBeDefined()
    instance.destroy()
  })
})
