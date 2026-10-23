import { expect, test } from 'bun:test'
import { appendFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { captureHeldViewerVideo } from '../scripts/held-viewer-capture'
import { buildHeldViewerExtractor, verifyHeldViewerExtractor } from '../scripts/held-viewer-build'
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
      const now = 102
      let prepared = false
      const command = async (args: string[]) => {
        calls.push(args)
        if (args[1] === 'status_bar') {
          if (args.includes('override')) appendFileSync(log, 'CRAFT_TAB_LCV_HOLD_END 108\n')
          return { ...completed, stdout: args.at(-1) === 'list' ? 'Current Status Bar Overrides:\n=============================\n' : '' }
        }
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
          expect(prepared).toBe(false)
          await Bun.write(join(output, 'held-viewer-frame'), 'synthetic host executable')
          return completed
        }
        if (args[1]?.endsWith('held-viewer-record.ts')) {
          expect(existsSync(ready)).toBe(false)
          await Bun.write(args[4]!, 'actual synthetic movie')
          await Bun.write(args[7]!, JSON.stringify({ completed: true, spawnWall: 99, readyWall: 99.1 }))
          await Bun.write(args[5]!, 'Recording started')
          const deadline = performance.now() + 4000
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
      }
      await buildHeldViewerExtractor(output, { command, xcrun: '/usr/bin/xcrun' })
      const run = captureHeldViewerVideo({ output, log, done: join(dir, 'done'), ready, simulator, timeoutMs: 5000 }, {
        prepare: async () => { prepared = true; return { simctl: '/synthetic/simctl', simctlSha256: 'verified-tool' } },
        now: () => now, command,
      })
      const deadline = performance.now() + 2000
      while (!existsSync(ready) && performance.now() < deadline) await Bun.sleep(10)
      expect(existsSync(ready)).toBe(true)
      expect(existsSync(join(output, 'recording-ready'))).toBe(true)
      appendFileSync(log, 'CRAFT_TAB_LCV_HOLD_BEGIN 100\nPress Home for 6 seconds\nSynthesize event\n')
      await Bun.sleep(50)
      // The actual independent redraw produces the release marker in this
      // synthetic plumbing fixture; product touch timing remains real in CI.
      if (alteredAnchor) await expect(run).rejects.toThrow('Frame timing does not match')
      else await run
      expect(calls.some(args => args.includes('screenshot'))).toBe(false)
      const receipt = JSON.parse(readFileSync(join(output, 'receipt.json'), 'utf8'))
      expect(receipt.verifiedDuringHold).toBe(!alteredAnchor)
      expect(receipt.ownedDisplayStimulus.restored).toBe(true)
      expect(calls.filter(args => args[1] === 'status_bar').map(args => args[3])).toEqual(['list', 'override', 'clear', 'list'])
      if (!alteredAnchor) {
        expect(receipt.method).toBe('public-simctl-recordVideo-decoded-frame')
        expect(receipt.validated).toEqual({ frameWallEarliest: 103, frameWallLatest: 103.1, frameOffsetFromFirstPTS: 4 })
      }
    }
    finally { removeTempDir(dir) }
  })
}


test('capture refuses missing host build evidence before starting live simulator setup', async () => {
  const dir = createTempDir('craft-held-unbuilt-')
  try {
    let prepared = false
    const capture = captureHeldViewerVideo({ output: join(dir, 'evidence'), log: join(dir, 'log'), done: join(dir, 'done'), simulator }, {
      prepare: async () => { prepared = true; return { simctl: '/synthetic/simctl', simctlSha256: 'tool' } },
      command: async () => ({ code: 1, signal: null, stdout: '', stderr: 'unexpected live compiler', timedOut: false, cancelled: false, processGroup: 123, groupDisposed: true }),
    })
    await expect(capture).rejects.toThrow('extractor build receipt')
    expect(prepared).toBe(false)
  }
  finally { removeTempDir(dir) }
})


test('a retained host build rejects a changed binary or source identity', async () => {
  const dir = createTempDir('craft-held-build-identity-')
  try {
    const extractor = join(dir, 'held-viewer-frame')
    const hash = (bytes: string) => new Bun.CryptoHasher('sha256').update(bytes).digest('hex')
    writeFileSync(extractor, 'host executable')
    const source = join(import.meta.dir, '../scripts/held-viewer-frame.swift')
    const receipt = { verified: true, extractor, source, sourceSha256: hash(readFileSync(source, 'utf8')), extractorSha256: hash('host executable') }
    writeFileSync(join(dir, 'extractor-build.json'), JSON.stringify(receipt))
    expect(await verifyHeldViewerExtractor(dir)).toBe(extractor)
    writeFileSync(extractor, 'substituted host executable')
    await expect(verifyHeldViewerExtractor(dir)).rejects.toThrow('does not match')
    writeFileSync(extractor, 'host executable')
    writeFileSync(join(dir, 'extractor-build.json'), JSON.stringify({ ...receipt, sourceSha256: hash('stale Swift source') }))
    await expect(verifyHeldViewerExtractor(dir)).rejects.toThrow('does not match')
  }
  finally { removeTempDir(dir) }
})

test('failed host compiler retains its command result and never produces an accepted build receipt', async () => {
  const dir = createTempDir('craft-held-build-failure-')
  try {
    const swiftc = join(dir, 'swiftc')
    writeFileSync(swiftc, 'synthetic compiler')
    await expect(buildHeldViewerExtractor(dir, {
      xcrun: '/synthetic/xcrun', command: async args => ({
        code: args[0] === swiftc ? 143 : 0, signal: args[0] === swiftc ? 'SIGTERM' : null,
        stdout: args.includes('--find') ? swiftc : '/synthetic/MacOSX.sdk', stderr: '',
        timedOut: args[0] === swiftc, cancelled: false, processGroup: 123, groupDisposed: true,
      }),
    })).rejects.toThrow('Extractor build failed')
    const receipt = JSON.parse(readFileSync(join(dir, 'extractor-build.json'), 'utf8'))
    expect(receipt.verified).toBe(false)
    expect(receipt.calls.at(-1).result).toMatchObject({ code: 143, timedOut: true, groupDisposed: true })
    await expect(verifyHeldViewerExtractor(dir)).rejects.toThrow('does not match')
  }
  finally { removeTempDir(dir) }
})


test('host build resolution and compilation share one finite build budget', async () => {
  const dir = createTempDir('craft-held-build-deadline-')
  try {
    let elapsed = 0, calls = 0
    const swiftc = join(dir, 'swiftc')
    writeFileSync(swiftc, 'synthetic compiler')
    await expect(buildHeldViewerExtractor(dir, {
      xcrun: '/synthetic/xcrun', monotonicNow: () => elapsed,
      command: async () => {
        calls++
        elapsed = 120_001
        return { code: 0, signal: null, stdout: swiftc, stderr: '', timedOut: false, cancelled: false, processGroup: 123, groupDisposed: true }
      },
    })).rejects.toThrow('shared build budget')
    expect(calls).toBe(1)
    const receipt = JSON.parse(readFileSync(join(dir, 'extractor-build.json'), 'utf8'))
    expect(receipt.verified).toBe(false)
    expect(receipt.totalBuildBudgetMs).toBe(120_000)
  }
  finally { removeTempDir(dir) }
})
