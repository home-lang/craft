import { existsSync, mkdirSync } from 'node:fs'
import { isAbsolute, join } from 'node:path'
import { nativeFixtureCommand } from './native-fixture-command'

const source = join(import.meta.dir, 'held-viewer-frame.swift')
const hash = async (path: string) => new Bun.CryptoHasher('sha256').update(await Bun.file(path).arrayBuffer()).digest('hex')

/** Build the host tool with the fixture, before the bounded live capture setup. */
export async function buildHeldViewerExtractor(output: string, dependencies: {
  command?: typeof nativeFixtureCommand
  xcrun?: string
  monotonicNow?: () => number
  signal?: AbortSignal
} = {}): Promise<void> {
  if (!isAbsolute(output)) throw new Error('Extractor build output must be absolute')
  mkdirSync(output, { recursive: true })
  const extractor = join(output, 'held-viewer-frame'), receipt = join(output, 'extractor-build.json')
  if ([extractor, receipt].some(existsSync)) throw new Error('Extractor build evidence already exists')
  const now = dependencies.monotonicNow ?? (() => performance.now())
  const deadline = now() + 120_000
  const calls: { args: string[], timeoutMs: number, result?: Awaited<ReturnType<typeof nativeFixtureCommand>> }[] = []
  let swiftc: string | undefined, swiftcSha256: string | undefined, macosSdk: string | undefined
  const evidence = { source, sourceSha256: await hash(source), extractor, totalBuildBudgetMs: 120_000, calls }
  const run = async (args: string[]) => {
    const call: typeof calls[number] = { args, timeoutMs: Math.floor(deadline - now()) }
    calls.push(call)
    if (call.timeoutMs <= 0) throw new Error('Extractor build exhausted its shared build budget')
    const result = await (dependencies.command ?? nativeFixtureCommand)(args, { cwd: output, timeoutMs: call.timeoutMs, signal: dependencies.signal })
    call.result = result
    if (result.code !== 0 || result.timedOut || result.cancelled) throw new Error(`Extractor build failed: ${JSON.stringify(call)}`)
    return result
  }
  try {
    const xcrun = dependencies.xcrun ?? Bun.which('xcrun')
    if (!xcrun || !isAbsolute(xcrun)) throw new Error('Cannot resolve public Apple compiler tools')
    swiftc = (await run([xcrun, '--sdk', 'macosx', '--find', 'swiftc'])).stdout.trim()
    if (!isAbsolute(swiftc)) throw new Error('Apple compiler resolver returned a relative path')
    swiftcSha256 = await hash(swiftc)
    macosSdk = (await run([xcrun, '--sdk', 'macosx', '--show-sdk-path'])).stdout.trim()
    if (!isAbsolute(macosSdk)) throw new Error('Apple compiler resolver returned a relative macOS SDK path')
    await run([swiftc, '-sdk', macosSdk, source, '-o', extractor])
    await Bun.write(receipt, JSON.stringify({ ...evidence, verified: true, swiftc, swiftcSha256, macosSdk, extractorSha256: await hash(extractor) }, null, 2))
  }
  catch (error) {
    await Bun.write(receipt, JSON.stringify({ ...evidence, verified: false, swiftc, swiftcSha256, macosSdk, error: String(error) }, null, 2))
    throw error
  }
}

/** The watcher consumes the exact host binary built from this Swift source. */
export async function verifyHeldViewerExtractor(output: string): Promise<string> {
  const receipt = join(output, 'extractor-build.json'), extractor = join(output, 'held-viewer-frame')
  if (!await Bun.file(receipt).exists()) throw new Error('Missing extractor build receipt; build the fixture before live capture')
  const built = await Bun.file(receipt).json()
  if (built.verified !== true || built.extractor !== extractor || built.source !== source
    || built.sourceSha256 !== await hash(source) || built.extractorSha256 !== await hash(extractor))
    throw new Error('Extractor build receipt does not match the current source and host binary')
  return extractor
}
