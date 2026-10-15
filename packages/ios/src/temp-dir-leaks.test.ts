/**
 * #357: Craft's builds and tests left a `craft-*` directory in the OS temp
 * folder per run, and a shared Mac ran out of disk twice in one day.
 *
 * Each case runs in a child process whose TMPDIR is a fresh, empty sandbox,
 * so "nothing left behind" is an exact assertion rather than a count taken
 * in a temp folder other processes are writing to.
 */
import { afterAll, describe, expect, it } from 'bun:test'
import { mkdirSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { sweepOrphanedTempDirs } from '../../typescript/src/temp-dir'

const helper = resolve(import.meta.dir, '../../typescript/src/temp-dir.ts')
const iosBuilder = resolve(import.meta.dir, 'index.ts')
const androidBuilder = resolve(import.meta.dir, '../../android/src/index.ts')
const iosTests = resolve(import.meta.dir, 'index.test.ts')

// Not `craft-` prefixed, so neither the code under test nor its sweep can
// mistake the sandbox itself for one of its directories.
const root = mkdtempSync(join(tmpdir(), 'leak-test-'))
afterAll(() => rmSync(root, { recursive: true, force: true }))

let caseNumber = 0
function sandbox(): { temp: string, scripts: string } {
  caseNumber += 1
  const temp = join(root, `case-${caseNumber}`, 'tmp')
  const scripts = join(root, `case-${caseNumber}`, 'scripts')
  mkdirSync(temp, { recursive: true })
  mkdirSync(scripts, { recursive: true })
  return { temp, scripts }
}

function leftovers(temp: string): string[] {
  return readdirSync(temp).filter(name => name.startsWith('craft-'))
}

function env(temp: string): Record<string, string> {
  // TMPDIR is what os.tmpdir() reads on macOS and Linux; TEMP/TMP on Windows.
  return { ...process.env, TMPDIR: temp, TEMP: temp, TMP: temp, CRAFT_IOS_RUNTIME: '' } as Record<string, string>
}

async function run(script: string, temp: string): Promise<{ exitCode: number, output: string }> {
  const child = Bun.spawn([process.execPath, script], { env: env(temp), stdout: 'pipe', stderr: 'pipe' })
  const [stdout, stderr, exitCode] = await Promise.all([new Response(child.stdout).text(), new Response(child.stderr).text(), child.exited])
  return { exitCode, output: stdout + stderr }
}

/** A build the way Stacks' build:ios and build:android drive Craft: init, then build, into scratch output. */
const buildBody = `
import { writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { createTempDir, removeTempDir } from ${JSON.stringify(helper)}
import * as ios from ${JSON.stringify(iosBuilder)}
import * as android from ${JSON.stringify(androidBuilder)}

const iosOut = createTempDir('craft-ios-leak-')
await ios.init({ runtimeDir: null, name: 'Leak Check', output: iosOut, config: { renderer: 'native' } })
const iosBundle = join(iosOut, 'compiled.js')
writeFileSync(iosBundle, 'globalThis.loaded = true')
await ios.build({ output: iosOut, nativeBundlePath: iosBundle, generateProject: false, runtimeDir: null })

const androidOut = createTempDir('craft-android-leak-')
await android.init({ name: 'LeakCheck', packageName: 'dev.craft.leakcheck', output: androidOut, config: { renderer: 'native' }, runtimeDir: null })
const androidBundle = join(androidOut, 'compiled.js')
writeFileSync(androidBundle, 'globalThis.loaded = true')
await android.build({ output: androidOut, nativeBundlePath: androidBundle, compile: false, runtimeDir: null })
`

describe('no craft-* directory outlives a run (#357)', () => {
  it('an iOS + Android init/build that succeeds', async () => {
    const { temp, scripts } = sandbox()
    const script = join(scripts, 'build.ts')
    writeFileSync(script, `${buildBody}\nconsole.log('built')\n`)
    const result = await run(script, temp)
    expect(result.output).toContain('built')
    expect(result.exitCode).toBe(0)
    expect(leftovers(temp)).toEqual([])
  }, 60_000)

  it('the same build when it fails partway', async () => {
    const { temp, scripts } = sandbox()
    const script = join(scripts, 'build-fails.ts')
    // Uncaught: no finally of the caller's runs, only the exit hook.
    writeFileSync(script, `${buildBody}\nthrow new Error('forced failure after the build')\n`)
    const result = await run(script, temp)
    expect(result.output).toContain('forced failure after the build')
    expect(result.exitCode).not.toBe(0)
    expect(leftovers(temp)).toEqual([])
  }, 60_000)

  for (const signal of ['SIGINT', 'SIGTERM'] as const) {
    it(`a run interrupted with ${signal}`, async () => {
      const { temp, scripts } = sandbox()
      const script = join(scripts, 'interrupted.ts')
      writeFileSync(script, `
import { writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { createTempDir } from ${JSON.stringify(helper)}
const dir = createTempDir('craft-interrupted-')
writeFileSync(join(dir, 'project.yml'), 'name: Interrupted')
console.log('ready')
setInterval(() => {}, 1000)
`)
      const child = Bun.spawn([process.execPath, script], { env: env(temp), stdout: 'pipe', stderr: 'inherit' })
      const reader = child.stdout.getReader()
      let seen = ''
      while (!seen.includes('ready')) {
        const { value, done } = await reader.read()
        if (done) break
        seen += new TextDecoder().decode(value)
      }
      expect(leftovers(temp)).toHaveLength(1)
      child.kill(signal)
      const exitCode = await child.exited
      // The default action's status (128 + signal number), not a clean exit.
      expect(exitCode).toBe(signal === 'SIGINT' ? 130 : 143)
      expect(leftovers(temp)).toEqual([])
    }, 30_000)
  }

  it('a run killed outright is swept up by the next one', async () => {
    const { temp, scripts } = sandbox()
    const script = join(scripts, 'killed.ts')
    writeFileSync(script, `
import { createTempDir } from ${JSON.stringify(helper)}
createTempDir('craft-killed-')
console.log('ready')
setInterval(() => {}, 1000)
`)
    const child = Bun.spawn([process.execPath, script], { env: env(temp), stdout: 'pipe', stderr: 'inherit' })
    const reader = child.stdout.getReader()
    await reader.read()
    child.kill('SIGKILL')
    await child.exited
    // SIGKILL cannot be caught; this is the one case the run itself cannot fix.
    expect(leftovers(temp)).toHaveLength(1)
    // What the next Craft process does on its first createTempDir (minus the
    // minimum age, which is there for processes racing on a shared folder).
    // `exited` can resolve a moment before the kernel reaps the child, and a
    // zombie still answers kill(pid, 0); give it that moment.
    for (let attempt = 0; attempt < 50 && leftovers(temp).length; attempt++) {
      sweepOrphanedTempDirs({ root: temp, minAgeMs: 0 })
      if (leftovers(temp).length) await Bun.sleep(20)
    }
    expect(leftovers(temp)).toEqual([])
  }, 30_000)

  it('the iOS builder test suite, and a test file that fails', async () => {
    const { temp, scripts } = sandbox()
    const failing = join(scripts, 'fails.test.ts')
    writeFileSync(failing, `
import { afterAll, expect, it } from 'bun:test'
import { createTempDir, removeAllTempDirs } from ${JSON.stringify(helper)}
afterAll(removeAllTempDirs)
it('fails with a project in temp', () => {
  createTempDir('craft-failing-test-')
  expect(1).toBe(2)
})
`)
    const child = Bun.spawn([process.execPath, 'test', iosTests, failing], { env: env(temp), stdout: 'pipe', stderr: 'pipe', cwd: resolve(import.meta.dir, '..') })
    const [, stderr, exitCode] = await Promise.all([new Response(child.stdout).text(), new Response(child.stderr).text(), child.exited])
    expect(stderr).toContain('1 fail')
    expect(exitCode).not.toBe(0)
    expect(leftovers(temp)).toEqual([])
  }, 120_000)
})
