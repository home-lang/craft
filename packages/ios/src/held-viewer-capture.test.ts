import { describe, expect, test } from 'bun:test'
import { appendFileSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { captureHeldViewer, HeldViewerTiming, heldViewerTest, includesHeldViewer } from '../scripts/held-viewer-capture'
import { createTempDir, removeTempDir } from '../../typescript/src/temp-dir'

const simulator = '9E10C320-E7FF-4D3E-ADE8-9A75FC60EC16'
const begin = 'CRAFT_TAB_LCV_HOLD_BEGIN 100\n'
const gesture = 't = 1.0s Press Home for 6 seconds\nt = 1.1s Synthesize event\n'
// A synthetic pixel tests evidence plumbing, never platform viewer acceptance.
const pixel = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=', 'base64')

function ready(): HeldViewerTiming {
  const timing = new HeldViewerTiming()
  timing.line(begin, 100)
  timing.line('Press Home for 6 seconds', 101)
  expect(timing.line('Synthesize event', 102)).toBe(true)
  return timing
}

describe('independent held viewer capture', () => {
  test('full/core or explicit viewer selection requires evidence, unit/other UI selectors do not', () => {
    for (const selection of [[], ['NativeNavigationUITests'], ['NativeNavigationUITests/NativeNavigationUITests'], [heldViewerTest]])
      expect(includesHeldViewer(selection)).toBe(true)
    expect(includesHeldViewer(['NativeNavigationUnitTests'])).toBe(false)
    expect(includesHeldViewer(['NativeNavigationUITests/NativeNavigationUITests/testOther'])).toBe(false)
  })

  test('marker and idle activity cannot substitute for the actual six-second press synthesis', () => {
    const timing = new HeldViewerTiming()
    expect(timing.line('Synthesize event', 99)).toBe(false)
    timing.line(begin, 100)
    expect(timing.line('Synthesize event', 101)).toBe(false)
    timing.line('Press Home for 0.1 seconds, then drag', 101)
    expect(timing.line('Synthesize event', 101)).toBe(false)
    timing.line('Press Home for 6 seconds', 101)
    expect(timing.line('Wait for idle', 101)).toBe(false)
    expect(timing.line('Synthesize event', 102)).toBe(true)
    expect(timing.line('Synthesize event', 102)).toBe(false)
  })

  test('requires screenshot completion before release and rejects buffered/early captures', () => {
    for (const [start, finish, end] of [[102.8, 103, 108], [102.1, 103, 108], [102.8, 108, 108], [102.8, 109, 108], [102.8, 103, 104]]) {
      const timing = ready()
      timing.captured(start!, finish!)
      timing.line(`CRAFT_TAB_LCV_HOLD_END ${end}`, end!)
      if (end === 108 && finish === 103 && start === 102.8) expect(() => timing.verify()).not.toThrow()
      else expect(() => timing.verify()).toThrow('during the six-second')
    }
    expect(() => ready().verify()).toThrow('Missing')
    const duplicate = ready()
    expect(() => duplicate.line(begin, 104)).toThrow('Duplicate')
  })

  test('tails partial live lines and retains hashed independent PNG with timing receipt', async () => {
    const dir = createTempDir('craft-held-capture-test-')
    const log = join(dir, 'live.log'), done = join(dir, 'done'), output = join(dir, 'evidence')
    const started = performance.now()
    let captureCount = 0
    try {
      writeFileSync(log, `old unrelated output\n${begin}t = 1s Press Home for 6 seconds\nt = 2s Synthesize`)
      const capture = captureHeldViewer({ log, done, output, simulator, startOffset: 'old unrelated output\n'.length, timeoutMs: 3000 }, {
        now: () => 102 + (performance.now() - started) / 1000,
        capture: async (path) => {
          captureCount++
          await Bun.write(path, pixel)
          // The release marker can arrive while the screenshot Promise resolves.
          appendFileSync(log, 'CRAFT_TAB_LCV_HOLD_END 108\n')
        },
      })
      await Bun.sleep(40)
      appendFileSync(log, ' event\n')
      await capture
      const receipt = JSON.parse(readFileSync(join(output, 'receipt.json'), 'utf8'))
      expect(captureCount).toBe(1)
      expect(receipt.verifiedDuringHold).toBe(true)
      expect(receipt.sha256).toBe(new Bun.CryptoHasher('sha256').update(pixel).digest('hex'))
      expect(receipt.timing.captureFinishedAt).toBeLessThan(receipt.timing.releasedAt)
      expect(receipt.visualReviewRequired).toContain('actual system Large Content Viewer')
    }
    finally { removeTempDir(dir) }
  })

  test('completed/buffered hold cannot produce a falsely accepted after-release image', async () => {
    const dir = createTempDir('craft-held-capture-test-')
    let captured = false
    try {
      const log = join(dir, 'live.log'), done = join(dir, 'done'), output = join(dir, 'evidence')
      writeFileSync(log, `${begin}${gesture}CRAFT_TAB_LCV_HOLD_END 108\n`)
      await expect(captureHeldViewer({ log, done, output, simulator, timeoutMs: 2000 }, {
        now: () => 109,
        capture: async () => { captured = true },
      })).rejects.toThrow('Hold ended before')
      expect(captured).toBe(false)
      expect(JSON.parse(readFileSync(join(output, 'receipt.json'), 'utf8')).verifiedDuringHold).toBe(false)
    }
    finally { removeTempDir(dir) }
  })

  test('missing markers, corrupt PNG and cancellation fail closed', async () => {
    const dir = createTempDir('craft-held-capture-test-')
    try {
      const log = join(dir, 'live.log'), done = join(dir, 'done')
      writeFileSync(log, 'No held gesture\n')
      writeFileSync(done, 'finished')
      await expect(captureHeldViewer({ log, done, output: join(dir, 'missing'), simulator, timeoutMs: 1200 })).rejects.toThrow('without a synthesized')
      writeFileSync(log, begin + gesture)
      await expect(captureHeldViewer({ log, done, output: join(dir, 'corrupt'), simulator, timeoutMs: 2000 }, {
        now: () => 102,
        capture: async path => { await Bun.write(path, 'not a PNG') },
      })).rejects.toThrow('did not produce a PNG')
      const controller = new AbortController()
      const cancelled = captureHeldViewer({ log, done, output: join(dir, 'cancelled'), simulator, signal: controller.signal })
      controller.abort(new Error('Owned test cancelled'))
      await expect(cancelled).rejects.toThrow('Owned test cancelled')
    }
    finally { removeTempDir(dir) }
  })
})
