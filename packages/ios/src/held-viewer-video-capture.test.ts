import { expect, test } from 'bun:test'
import { appendFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { captureHeldViewerVideo } from '../scripts/held-viewer-capture'
import { createTempDir, removeTempDir } from '../../typescript/src/temp-dir'

const simulator = '9E10C320-E7FF-4D3E-ADE8-9A75FC60EC16'
const pixel = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=', 'base64')

for (const alteredAnchor of [false, true]) {
  test(`video evidence ${alteredAnchor ? 'rejects a substituted anchor' : 'records before readiness and verifies actual captured PTS after release'}`, async () => {
    const dir = createTempDir('craft-held-video-pipeline-')
    try {
      const output = join(dir, 'evidence'), log = join(dir, 'log'), ready = join(dir, 'ready'), swiftc = join(dir, 'swiftc'), macosSdk = join(dir, 'MacOSX.sdk')
      writeFileSync(swiftc, 'synthetic compiler')
      writeFileSync(log, '')
      const calls: string[][] = []
      const completed = { code: 0, signal: null, stdout: '', stderr: '', timedOut: false, cancelled: false, processGroup: 123, groupDisposed: true as const }
      let now = 102
      const run = captureHeldViewerVideo({ output, log, done: join(dir, 'done'), ready, simulator, timeoutMs: 3000 }, {
        prepare: async () => ({ simctl: '/synthetic/simctl', simctlSha256: 'verified-tool' }),
        xcrun: '/usr/bin/xcrun', now: () => now,
        command: async (args) => {
          calls.push(args)
          if (args.includes('--find')) {
            expect(args).toEqual(['/usr/bin/xcrun', '--sdk', 'macosx', '--find', 'swiftc'])
            return { ...completed, stdout: swiftc }
          }
          if (args.includes('--show-sdk-path')) {
            expect(args).toEqual(['/usr/bin/xcrun', '--sdk', 'macosx', '--show-sdk-path'])
            return { ...completed, stdout: macosSdk }
          }
          if (args[0] === swiftc) {
            expect(args).toEqual([swiftc, '-sdk', macosSdk, join(import.meta.dir, '../scripts/held-viewer-frame.swift'), '-o', join(output, 'held-viewer-frame')])
            return completed
          }
          if (args[1]?.endsWith('held-viewer-record.ts')) {
            expect(existsSync(ready)).toBe(false)
            await Bun.write(args[4]!, 'actual synthetic movie')
            await Bun.write(args[7]!, JSON.stringify({ completed: true, spawnWall: 99, readyWall: 99.1 }))
            await Bun.write(args[5]!, 'Recording started')
            const deadline = performance.now() + 2000
            while (!existsSync(args[6]!) && performance.now() < deadline) await Bun.sleep(10)
            expect(existsSync(args[6]!)).toBe(true)
            return completed
          }
          expect(args[0]).toBe(join(output, 'held-viewer-frame'))
          expect(args.slice(4)).toEqual(['99', '99.1', '102', '108'])
          await Bun.write(args[2]!, pixel)
          const hash = (bytes: Uint8Array | string) => new Bun.CryptoHasher('sha256').update(bytes).digest('hex')
          await Bun.write(args[3]!, JSON.stringify({
            verified: true, recordSpawnWall: alteredAnchor ? 98 : 99, recordingStartedObservedWall: 99.1,
            synthesisWall: 102, releasedWall: 108, firstPTS: { value: 0, timescale: 1 },
            selectedPTS: { value: 4, timescale: 1 }, actualPTS: { value: 4, timescale: 1 },
            pngSha256: hash(pixel), movieSha256: hash('actual synthetic movie'),
          }))
          return completed
        },
      })
      const deadline = performance.now() + 2000
      while (!existsSync(ready) && performance.now() < deadline) await Bun.sleep(10)
      expect(existsSync(ready)).toBe(true)
      expect(existsSync(join(output, 'recording-ready'))).toBe(true)
      appendFileSync(log, 'CRAFT_TAB_LCV_HOLD_BEGIN 100\nPress Home for 6 seconds\nSynthesize event\n')
      await Bun.sleep(50)
      now = 108
      appendFileSync(log, 'CRAFT_TAB_LCV_HOLD_END 108\n')
      if (alteredAnchor) await expect(run).rejects.toThrow('Frame timing does not match')
      else await run
      expect(calls.some(args => args.includes('screenshot'))).toBe(false)
      const receipt = JSON.parse(readFileSync(join(output, 'receipt.json'), 'utf8'))
      expect(receipt.verifiedDuringHold).toBe(!alteredAnchor)
      if (!alteredAnchor) {
        expect(receipt.method).toBe('public-simctl-recordVideo-decoded-frame')
        expect(receipt.validated).toEqual({ frameWallEarliest: 103, frameWallLatest: 103.1, frameOffsetFromFirstPTS: 4 })
      }
    }
    finally { removeTempDir(dir) }
  })
}
