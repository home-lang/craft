import { afterEach, describe, expect, it } from 'bun:test'
import { existsSync, mkdirSync, mkdtempSync, readdirSync, rmSync, utimesSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import {
  createTempDir,
  keepTempDir,
  liveTempDirs,
  removeAllTempDirs,
  removeTempDir,
  sweepOrphanedTempDirs,
  tempDirPrefix,
  withTempDir,
} from '../temp-dir'

// A sandbox of its own rather than the real temp folder, which other
// processes on a shared machine are writing to at the same time. Named so the
// sweep under test can never match it.
const sandboxes: string[] = []
function sandbox(): string {
  const dir = mkdtempSync(join(tmpdir(), 'temp-dir-test-'))
  sandboxes.push(dir)
  return dir
}

afterEach(() => {
  removeAllTempDirs()
  for (const dir of sandboxes.splice(0)) rmSync(dir, { recursive: true, force: true })
})

function age(path: string, ms: number): void {
  const then = new Date(Date.now() - ms)
  utimesSync(path, then, then)
}

describe('temp dirs (#357)', () => {
  it('stamps the owning pid into every name', () => {
    expect(tempDirPrefix('craft-ios-native-')).toBe(`craft-ios-native-p${process.pid}-`)
    expect(tempDirPrefix('ios-native')).toBe(`craft-ios-native-p${process.pid}-`)
    expect(tempDirPrefix('craft-')).toBe(`craft-p${process.pid}-`)

    const dir = createTempDir('craft-name-')
    expect(dir).toMatch(new RegExp(`/craft-name-p${process.pid}-[A-Za-z0-9]{6}$`))
    expect(existsSync(dir)).toBe(true)
    expect(liveTempDirs()).toContain(dir)
  })

  it('removes a directory and forgets it', () => {
    const dir = createTempDir('craft-remove-')
    writeFileSync(join(dir, 'file'), 'x')
    removeTempDir(dir)
    expect(existsSync(dir)).toBe(false)
    expect(liveTempDirs()).not.toContain(dir)
  })

  it('removes the directory when the work inside withTempDir fails', async () => {
    let seen = ''
    await expect(withTempDir('craft-fails-', (dir) => {
      seen = dir
      writeFileSync(join(dir, 'half-written'), 'x')
      throw new Error('forced failure')
    })).rejects.toThrow('forced failure')
    expect(seen).not.toBe('')
    expect(existsSync(seen)).toBe(false)
  })

  it('removes everything still live in one call', () => {
    const a = createTempDir('craft-a-')
    const b = createTempDir('craft-b-')
    removeAllTempDirs()
    expect(existsSync(a)).toBe(false)
    expect(existsSync(b)).toBe(false)
    expect(liveTempDirs()).toEqual([])
  })

  it('only listens for signals while it has directories to clean', () => {
    const before = process.listenerCount('SIGTERM')
    const dir = createTempDir('craft-listen-')
    expect(process.listenerCount('SIGTERM')).toBe(before + 1)
    expect(process.listenerCount('exit')).toBeGreaterThan(0)
    removeTempDir(dir)
    expect(process.listenerCount('SIGTERM')).toBe(before)
  })

  it('sweeps directories whose process is gone, and nothing else', () => {
    const root = sandbox()
    const dead = join(root, 'craft-ios-native-p999999-aB3dE5')
    const alive = join(root, `craft-ios-native-p${process.pid}-aB3dE5`)
    const other = join(root, 'craft-ios-native-p424242-aB3dE5')
    const young = join(root, 'craft-young-p999998-aB3dE5')
    const kept = join(root, 'craft-kept-p999997-aB3dE5')
    const foreign = join(root, 'craft-something-else')
    const legacy = join(root, 'craft-ios-native-aB3dE5')
    for (const dir of [dead, alive, other, young, kept, foreign, legacy]) mkdirSync(dir)
    writeFileSync(join(kept, '.craft-keep'), '')
    for (const dir of [dead, alive, other, kept, foreign, legacy]) age(dir, 10 * 60_000)

    const removed = sweepOrphanedTempDirs({ root, isAlive: pid => pid === 424242 })

    expect(removed).toEqual([dead])
    expect(readdirSync(root).sort()).toEqual([
      'craft-ios-native-aB3dE5',
      `craft-ios-native-p${process.pid}-aB3dE5`,
      'craft-ios-native-p424242-aB3dE5',
      'craft-kept-p999997-aB3dE5',
      'craft-something-else',
      'craft-young-p999998-aB3dE5',
    ].sort())
  })

  it('a kept directory survives removeAllTempDirs and the sweep', () => {
    const dir = createTempDir('craft-keep-me-')
    keepTempDir(dir)
    removeAllTempDirs()
    expect(existsSync(dir)).toBe(true)
    expect(existsSync(join(dir, '.craft-keep'))).toBe(true)
    rmSync(dir, { recursive: true, force: true })
  })
})
