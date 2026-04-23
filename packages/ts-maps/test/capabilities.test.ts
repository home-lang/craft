import { describe, expect, test } from 'bun:test'
import { probeCapabilities, supportsAdvancedRendering } from '../src'

describe('probeCapabilities', () => {
  test('returns a defined shape', () => {
    const caps = probeCapabilities()
    expect(typeof caps.webgl2).toBe('boolean')
    expect(typeof caps.webgl1).toBe('boolean')
    expect(typeof caps.offscreenCanvas).toBe('boolean')
    expect(caps.hardwareConcurrency).toBeGreaterThanOrEqual(1)
    expect(caps.devicePixelRatio).toBeGreaterThanOrEqual(1)
    expect(['webgl', 'canvas2d']).toContain(caps.preferredRenderer)
  })

  test('preferredRenderer follows WebGL2 availability', () => {
    const caps = probeCapabilities()
    if (caps.webgl2)
      expect(caps.preferredRenderer).toBe('webgl')
    else
      expect(caps.preferredRenderer).toBe('canvas2d')
  })

  test('pointer + touch event detection reflects global scope', () => {
    const caps = probeCapabilities()
    expect(typeof caps.pointerEvents).toBe('boolean')
    expect(typeof caps.touchEvents).toBe('boolean')
  })
})

describe('supportsAdvancedRendering', () => {
  test('accepts a caps argument and returns boolean', () => {
    const result = supportsAdvancedRendering({
      webgl2: true,
      webgl1: true,
      offscreenCanvas: true,
      hardwareConcurrency: 4,
      devicePixelRatio: 2,
      pointerEvents: true,
      touchEvents: false,
      preferredRenderer: 'webgl',
    })
    expect(result).toBe(true)
  })

  test('false when WebGL2 is unavailable', () => {
    expect(supportsAdvancedRendering({
      webgl2: false,
      webgl1: true,
      offscreenCanvas: false,
      hardwareConcurrency: 8,
      devicePixelRatio: 1,
      pointerEvents: true,
      touchEvents: true,
      preferredRenderer: 'canvas2d',
    })).toBe(false)
  })

  test('false on a single-core host even with WebGL2', () => {
    expect(supportsAdvancedRendering({
      webgl2: true,
      webgl1: true,
      offscreenCanvas: false,
      hardwareConcurrency: 1,
      devicePixelRatio: 1,
      pointerEvents: true,
      touchEvents: false,
      preferredRenderer: 'webgl',
    })).toBe(false)
  })

  test('false when pointer events are missing', () => {
    expect(supportsAdvancedRendering({
      webgl2: true,
      webgl1: true,
      offscreenCanvas: true,
      hardwareConcurrency: 4,
      devicePixelRatio: 1,
      pointerEvents: false,
      touchEvents: true,
      preferredRenderer: 'webgl',
    })).toBe(false)
  })

  test('probe fallback — with no arg it calls probeCapabilities', () => {
    // Just verify the overload doesn't throw; the boolean result depends
    // on whatever the local runtime reports.
    expect(typeof supportsAdvancedRendering()).toBe('boolean')
  })
})
