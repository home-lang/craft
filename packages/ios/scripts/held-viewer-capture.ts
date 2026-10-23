import { closeSync, existsSync, mkdirSync, openSync, readSync, statSync } from 'node:fs'
import { isAbsolute, join } from 'node:path'
import { nativeFixtureCommand } from './native-fixture-command'

export const heldViewerTest = 'NativeNavigationUITests/NativeNavigationUITests/testTabBarLargeContentViewerDuringAccessibilityHold'

export function includesHeldViewer(selection: readonly string[]): boolean {
  return !selection.length || selection.some(value => heldViewerTest === value || heldViewerTest.startsWith(`${value}/`))
}

/** Log evidence is a timing gate, never a substitute for reviewing the PNG. */
export class HeldViewerTiming {
  beganAt?: number
  synthesisObservedAt?: number
  captureStartedAt?: number
  captureFinishedAt?: number
  releasedAt?: number
  private press = false

  line(value: string, observedAt: number): boolean {
    const begin = /\bCRAFT_TAB_LCV_HOLD_BEGIN ([\d.]+)/.exec(value)
    const end = /\bCRAFT_TAB_LCV_HOLD_END ([\d.]+)/.exec(value)
    if (begin) {
      if (this.beganAt !== undefined) throw new Error('Duplicate viewer hold marker')
      this.beganAt = Number(begin[1])
    }
    if (this.beganAt === undefined || this.releasedAt !== undefined) return false
    if (/\bPress\b.*\bfor 6(?:\.0+)? seconds\b/.test(value)) this.press = true
    if (end) this.releasedAt = Number(end[1])
    if (this.press && this.synthesisObservedAt === undefined && value.includes('Synthesize event')) {
      this.synthesisObservedAt = observedAt
      return true
    }
    return false
  }

  captured(start: number, finish: number): void {
    this.captureStartedAt = start
    this.captureFinishedAt = finish
  }

  verify(): void {
    const { beganAt: begin, synthesisObservedAt: synthesis, captureStartedAt: start, captureFinishedAt: finish, releasedAt: end } = this
    if ([begin, synthesis, start, finish, end].some(value => value === undefined || !Number.isFinite(value)))
      throw new Error('Missing hold, synthesis, screenshot or release evidence')
    if (!(begin! <= synthesis! && synthesis! + 0.7 <= start! && start! <= finish! && finish! < end!
      && end! - synthesis! >= 5.5))
      throw new Error('The independent screenshot did not complete during the six-second synthesized hold')
  }
}

interface CaptureOptions {
  log: string
  simulator: string
  output: string
  done: string
  startOffset?: number
  signal?: AbortSignal
  timeoutMs?: number
  parentPid?: number
}

/** Runs in an independent process while the existing xcode command stays synchronous. */
export async function captureHeldViewer(options: CaptureOptions, dependencies: {
  now?: () => number
  capture?: (png: string, signal: AbortSignal) => Promise<void>
} = {}): Promise<void> {
  if (![options.log, options.output, options.done].every(isAbsolute) || !/^[\da-f-]{36}$/i.test(options.simulator))
    throw new Error('Viewer capture needs absolute evidence paths and a simulator UUID')
  let offset = options.startOffset ?? 0
  if (!Number.isSafeInteger(offset) || offset < 0) throw new Error('Invalid live log offset')
  mkdirSync(options.output, { recursive: true })
  const timing = new HeldViewerTiming()
  const now = dependencies.now ?? (() => Date.now() / 1000)
  const stop = new AbortController()
  const signal = options.signal ? AbortSignal.any([stop.signal, options.signal]) : stop.signal
  const png = join(options.output, 'during-hold.png')
  const capture = dependencies.capture ?? (async (path, abort) => {
    const result = await nativeFixtureCommand(['xcrun', 'simctl', 'io', options.simulator, 'screenshot', path], {
      cwd: options.output, timeoutMs: 3000, signal: abort,
    })
    if (result.code !== 0) throw new Error(`Independent simulator screenshot failed: ${result.stderr}`)
  })
  let pending: Promise<void> | undefined, failure: unknown, finished = false, remainder = ''
  let doneAt: number | undefined
  const deadline = performance.now() + (options.timeoutMs ?? 45 * 60_000)
  const receipt = (verifiedDuringHold: boolean, error?: string) => ({
    verifiedDuringHold, error, timing, simulator: options.simulator,
    screenshot: png, captureDelayMs: 750,
    beforeAfter: ['XCTest attachment: Large content viewer before hold', 'XCTest attachment: Large content viewer after release'],
    visualReviewRequired: 'The during-hold PNG must show the actual system Large Content Viewer.',
  })
  try {
    while (performance.now() < deadline) {
      signal.throwIfAborted()
      if (options.parentPid) {
        try { process.kill(options.parentPid, 0) }
        catch { throw new Error('Native test harness exited before capture completed') }
      }
      if (existsSync(options.log)) {
        const size = statSync(options.log).size
        if (size < offset) throw new Error('Live navigation log was truncated during capture')
        if (size > offset) {
          const file = openSync(options.log, 'r')
          const chunk = Buffer.alloc(size - offset)
          let read = 0
          try { read = readSync(file, chunk, 0, chunk.length, offset) }
          finally { closeSync(file) }
          offset += read
          const lines = (remainder + chunk.subarray(0, read).toString()).split('\n')
          remainder = lines.pop()!
          for (const line of lines) {
            if (timing.line(line, now())) {
              pending = (async () => {
                await Bun.sleep(750)
                signal.throwIfAborted()
                if (timing.releasedAt !== undefined) throw new Error('Hold ended before the independent capture started')
                const started = now()
                await capture(png, signal)
                timing.captured(started, now())
                const bytes = new Uint8Array(await Bun.file(png).arrayBuffer())
                if (bytes.length < 8 || Buffer.from(bytes.subarray(0, 8)).toString('hex') !== '89504e470d0a1a0a')
                  throw new Error('Independent capture did not produce a PNG')
                finished = true
              })().catch(error => { failure = error })
            }
          }
        }
      }
      if (failure) throw failure
      if (timing.releasedAt !== undefined && finished) {
        timing.verify()
        const hash = new Bun.CryptoHasher('sha256').update(await Bun.file(png).arrayBuffer()).digest('hex')
        await Bun.write(join(options.output, 'receipt.json'), JSON.stringify({ ...receipt(true), sha256: hash }, null, 2))
        return
      }
      if (existsSync(options.done)) {
        doneAt ??= performance.now()
        if (performance.now() - doneAt > 500 && !pending)
          throw new Error('XCTest finished without a synthesized viewer hold')
        if (performance.now() - doneAt > 4000)
          throw new Error('XCTest finished without complete during-hold evidence')
      }
      await Bun.sleep(25)
    }
    throw new Error('Independent viewer capture exceeded the native job backstop')
  }
  catch (error) {
    await Bun.write(join(options.output, 'receipt.json'), JSON.stringify(receipt(false, String(error)), null, 2))
    throw error
  }
  finally {
    stop.abort()
    await pending
  }
}

if (import.meta.main) {
  const [log, simulator, output, done, rawOffset, rawParent] = process.argv.slice(2)
  const controller = new AbortController()
  const cancel = () => controller.abort()
  process.once('SIGTERM', cancel)
  process.once('SIGINT', cancel)
  try {
    if (!log || !simulator || !output || !done) throw new Error('Expected live log, simulator, evidence directory, completion marker and offset')
    await captureHeldViewer({ log, simulator, output, done, startOffset: Number(rawOffset ?? 0), parentPid: Number(rawParent) || undefined, signal: controller.signal })
  }
  catch (error) { console.error(error); process.exitCode = 1 }
  finally { process.off('SIGTERM', cancel); process.off('SIGINT', cancel) }
}
