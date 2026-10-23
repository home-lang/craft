import { expect, test } from 'bun:test'
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { nativeFixtureCommand } from './native-fixture-command'

function alive(pid: number): boolean {
  try { process.kill(pid, 0); return true }
  catch (error) { if ((error as NodeJS.ErrnoException).code === 'ESRCH') return false; throw error }
}

test.skipIf(process.platform === 'win32')('a completed native command disposes its owned descendants before returning', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'craft-native-command-'))
  const marker = join(directory, 'owned-child.pid')
  let descendant: number | undefined
  const unrelated = Bun.spawn([process.execPath, '-e', 'setInterval(() => {}, 1000)'], { detached: true, stdin: 'ignore', stdout: 'ignore', stderr: 'ignore' })
  try {
    const source = `
      const child = Bun.spawn([process.execPath, '-e', 'setInterval(() => {}, 1000)'], { stdin: 'ignore', stdout: 'inherit', stderr: 'inherit' });
      await Bun.write(${JSON.stringify(marker)}, String(child.pid));
      process.exit(0);
    `
    const result = await nativeFixtureCommand([process.execPath, '-e', source], { cwd: directory, timeoutMs: 3000 })
    descendant = Number(readFileSync(marker, 'utf8'))
    expect(result.code).toBe(0)
    expect(alive(descendant)).toBe(false)
    expect(alive(unrelated.pid)).toBe(true)
  }
  finally {
    if (descendant === undefined && existsSync(marker)) descendant = Number(readFileSync(marker, 'utf8'))
    if (descendant && alive(descendant)) process.kill(descendant, 'SIGKILL')
    unrelated.kill('SIGKILL')
    await unrelated.exited
    rmSync(directory, { recursive: true, force: true })
  }
}, 5000)

for (const mode of ['timeout', 'cancellation'] as const) {
  test.skipIf(process.platform === 'win32')(`${mode} disposes an uncooperative command and its descendant`, async () => {
    const directory = mkdtempSync(join(tmpdir(), 'craft-native-command-'))
    const marker = join(directory, 'owned-processes.json')
    const controller = new AbortController()
    let trigger: ReturnType<typeof setInterval> | undefined
    try {
      const source = `
        process.on('SIGTERM', () => {});
        const child = Bun.spawn([process.execPath, '-e', 'process.on("SIGTERM", () => {}); setInterval(() => {}, 1000)'], { stdin: 'ignore', stdout: 'ignore', stderr: 'ignore' });
        await Bun.write(${JSON.stringify(marker)}, JSON.stringify({ parent: process.pid, descendant: child.pid }));
        setInterval(() => {}, 1000);
      `
      if (mode === 'cancellation') trigger = setInterval(() => { if (existsSync(marker)) controller.abort() }, 10)
      const started = performance.now()
      const result = await nativeFixtureCommand([process.execPath, '-e', source], { cwd: directory, timeoutMs: mode === 'timeout' ? 1000 : 3000, signal: controller.signal })
      const owned = JSON.parse(readFileSync(marker, 'utf8')) as { parent: number, descendant: number }
      expect(result.timedOut).toBe(mode === 'timeout')
      expect(result.cancelled).toBe(mode === 'cancellation')
      expect(result.code).not.toBe(0)
      expect(alive(owned.parent)).toBe(false)
      expect(alive(owned.descendant)).toBe(false)
      expect(performance.now() - started).toBeLessThan(3000)
    }
    finally {
      if (trigger) clearInterval(trigger)
      if (existsSync(marker)) {
        const owned = JSON.parse(readFileSync(marker, 'utf8')) as { parent: number, descendant: number }
        for (const pid of [owned.parent, owned.descendant]) if (alive(pid)) process.kill(pid, 'SIGKILL')
      }
      rmSync(directory, { recursive: true, force: true })
    }
  }, 5000)
}

test.skipIf(process.platform === 'win32')('a failed command retains its actual status and private diagnostic log', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'craft-native-command-'))
  try {
    const logPath = join(directory, 'diagnostic.log')
    const result = await nativeFixtureCommand([process.execPath, '-e', 'console.log("native stdout"); console.error("native stderr"); process.exit(7)'], { cwd: directory, timeoutMs: 3000, logPath })
    expect(result.code).toBe(7)
    expect(result.timedOut).toBe(false)
    expect(readFileSync(logPath, 'utf8')).toBe('native stdout\nnative stderr\n')
    expect(statSync(logPath).mode & 0o777).toBe(0o600)
  }
  finally { rmSync(directory, { recursive: true, force: true }) }
})
