/**
 * Scratch directories that do not outlive the process that made them.
 *
 * Every Craft temp directory goes through here: packaging, signing, the
 * updater's staging area, the sidebar config spill file, and the build and
 * test harnesses. Issue #357: a bare `mkdtempSync(join(tmpdir(), 'craft-…'))`
 * per run, with no cleanup or a `finally` that a killed run never reaches,
 * left 1,983 directories (~13 GB) in the macOS per-user temp folder.
 *
 * Three layers, because each one misses something the next one catches:
 *
 * 1. The caller removes the directory when it is done (`withTempDir`, or
 *    `removeTempDir` in a `finally`).
 * 2. Every live directory is also removed on process exit and on SIGINT,
 *    SIGTERM and SIGHUP, which is what a Ctrl-C, a CI timeout or a tool's
 *    kill sends. Node skips `exit` listeners on a signal's default action,
 *    so the signals need their own handlers.
 * 3. SIGKILL cannot be caught, and a synchronous child (`Bun.spawnSync`
 *    running xcodebuild) can hold the event loop until the parent is killed
 *    for good. So each name carries the owning pid (`craft-ios-p4242-a1B2c3`),
 *    and the first directory a later process creates sweeps up any whose
 *    owner is gone.
 */

import { existsSync, mkdtempSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { constants as osConstants, tmpdir } from 'node:os'
import { join } from 'node:path'

/** `craft-<label>-p<pid>-<mkdtemp suffix>`: what the sweep recognises as ours. */
const OWNED_NAME = /^craft-(?:.+-)?p(\d+)-[A-Za-z0-9]{6}$/

/** A directory holding this file was kept on purpose and is never swept. */
const KEEP_MARKER = '.craft-keep'

/** A directory younger than this is left alone even if its pid looks dead. */
const SWEEP_MIN_AGE_MS = 60_000

const SIGNALS = ['SIGINT', 'SIGTERM', 'SIGHUP'] as const
type CleanupSignal = typeof SIGNALS[number]

const live = new Set<string>()
let hooked = false
let swept = false

function removeQuietly(dir: string): void {
  try { rmSync(dir, { recursive: true, force: true }) }
  catch { /* already gone, or busy on Windows; the next sweep gets it */ }
}

/** Remove every directory this process created and has not removed yet. */
export function removeAllTempDirs(): void {
  for (const dir of live) removeQuietly(dir)
  live.clear()
  unhook()
}

function onExit(): void {
  for (const dir of live) removeQuietly(dir)
  live.clear()
}

function onSignal(signal: CleanupSignal): void {
  removeAllTempDirs()
  // Our listener replaced the signal's default action. If nobody else is
  // listening, restore what the default would have done: end the process
  // with the conventional 128 + signal number status.
  if (process.listenerCount(signal) === 0)
    process.exit(128 + (osConstants.signals[signal] ?? 1))
}

const signalHandlers = new Map<CleanupSignal, () => void>(
  SIGNALS.map(signal => [signal, () => onSignal(signal)]),
)

function hook(): void {
  if (hooked) return
  hooked = true
  process.on('exit', onExit)
  for (const [signal, handler] of signalHandlers) {
    // Windows has no SIGHUP to listen for in some runtimes; skip what throws.
    try { process.on(signal, handler) }
    catch { /* unsupported on this platform */ }
  }
}

function unhook(): void {
  if (!hooked) return
  hooked = false
  process.off('exit', onExit)
  for (const [signal, handler] of signalHandlers) process.off(signal, handler)
}

function pidIsAlive(pid: number): boolean {
  try {
    process.kill(pid, 0)
    return true
  }
  catch (error) {
    // EPERM: it exists, it is just not ours to signal.
    return (error as NodeJS.ErrnoException).code === 'EPERM'
  }
}

export interface SweepOptions {
  /** Directory to sweep. Defaults to the OS temp directory. */
  root?: string
  /** Whether a pid still runs. Injected by tests. */
  isAlive?: (pid: number) => boolean
  /** Minimum age before an orphan is removed. */
  minAgeMs?: number
  now?: number
}

/**
 * Remove Craft temp directories whose owning process has exited.
 *
 * Only names this module produced are considered (`craft-…-p<pid>-XXXXXX`),
 * so another tool's `craft-something` directory is never touched. Returns
 * the paths it removed.
 */
export function sweepOrphanedTempDirs(options: SweepOptions = {}): string[] {
  const root = options.root ?? tmpdir()
  const isAlive = options.isAlive ?? pidIsAlive
  const minAge = options.minAgeMs ?? SWEEP_MIN_AGE_MS
  const now = options.now ?? Date.now()
  const removed: string[] = []

  let names: string[]
  try { names = readdirSync(root) }
  catch { return removed }

  for (const name of names) {
    const match = OWNED_NAME.exec(name)
    if (!match) continue
    const pid = Number(match[1])
    if (pid === process.pid || isAlive(pid)) continue
    const path = join(root, name)
    try {
      if (now - statSync(path).mtimeMs < minAge) continue
      if (existsSync(join(path, KEEP_MARKER))) continue
    }
    catch { continue }
    removeQuietly(path)
    removed.push(path)
  }
  return removed
}

/**
 * The mkdtemp prefix for a label: `ios-native` and `craft-ios-native-` both
 * become `craft-ios-native-p<pid>-`.
 */
export function tempDirPrefix(label: string): string {
  const bare = label.replace(/^craft-/, '').replace(/-+$/, '')
  return bare ? `craft-${bare}-p${process.pid}-` : `craft-p${process.pid}-`
}

/**
 * Create a scratch directory in the OS temp folder that is removed when this
 * process ends, however it ends. Remove it sooner with `removeTempDir`.
 */
export function createTempDir(label: string, root: string = tmpdir()): string {
  if (!swept) {
    swept = true
    sweepOrphanedTempDirs({ root })
  }
  hook()
  const dir = mkdtempSync(join(root, tempDirPrefix(label)))
  live.add(dir)
  return dir
}

/** Remove a directory from `createTempDir` now rather than at exit. */
export function removeTempDir(dir: string): void {
  removeQuietly(dir)
  live.delete(dir)
  if (live.size === 0) unhook()
}

/**
 * Let a directory from `createTempDir` outlive the process, for a harness
 * asked to keep its generated project for inspection. The caller now owns
 * it, and its pid-stamped name means a later sweep removes it once this
 * process is gone.
 */
export function keepTempDir(dir: string): void {
  try { writeFileSync(join(dir, KEEP_MARKER), `kept by pid ${process.pid}\n`) }
  catch { /* the directory is gone; nothing to keep */ }
  live.delete(dir)
  if (live.size === 0) unhook()
}

/** Run `fn` with a fresh scratch directory that is removed when it settles. */
export async function withTempDir<T>(label: string, fn: (dir: string) => T | Promise<T>): Promise<T> {
  const dir = createTempDir(label)
  try {
    return await fn(dir)
  }
  finally {
    removeTempDir(dir)
  }
}

/** Directories created here and not yet removed. For tests and diagnostics. */
export function liveTempDirs(): string[] {
  return [...live]
}
