import { expect, test } from 'bun:test'
import { join } from 'node:path'

async function invoke(argument: string) {
  const child = Bun.spawn([process.execPath, join(import.meta.dir, '../scripts/test-native-render.ts'), argument], {
    env: { ...process.env, PATH: '' }, stdout: 'pipe', stderr: 'pipe',
  })
  const [status, stdout, stderr] = await Promise.all([child.exited, new Response(child.stdout).text(), new Response(child.stderr).text()])
  return { status, output: stdout + stderr }
}

test('native renderer help exits before generating a project or accessing a simulator', async () => {
  const result = await invoke('--help')
  expect(result.status).toBe(0)
  expect(result.output).toContain('Usage:')
  expect(result.output).not.toContain('Initializing Craft')
})

test('unknown native renderer arguments fail before running device tests', async () => {
  const result = await invoke('--not-a-test-option')
  expect(result.status).not.toBe(0)
  expect(result.output).toContain('Unknown native renderer test argument:')
  expect(result.output).not.toContain('Initializing Craft')
})
