#!/usr/bin/env bun
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { delimiter, dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const templates = ['minimal', 'full-featured', 'todo-app']

function run(cmd: string[], cwd: string, env: NodeJS.ProcessEnv = process.env): void {
  const proc = Bun.spawnSync(cmd, {
    cwd,
    env,
    stdout: 'pipe',
    stderr: 'pipe',
  })

  if (!proc.success) {
    process.stdout.write(proc.stdout)
    process.stderr.write(proc.stderr)
    throw new Error(`Command failed in ${cwd}: ${cmd.join(' ')}`)
  }
}

const tmp = mkdtempSync(join(tmpdir(), 'craft-create-smoke-'))

try {
  for (const template of templates) {
    const appName = `smoke-${template}`
    run(['bun', join(root, 'packages/create-craft/bin/cli.ts'), appName, '--template', template, '--skip-install'], tmp)

    const appDir = join(tmp, appName)
    const packagePath = join(appDir, 'package.json')
    const pkg = JSON.parse(readFileSync(packagePath, 'utf-8'))
    pkg.dependencies['@craft-native/craft'] = `file:${join(root, 'packages/typescript')}`
    writeFileSync(packagePath, `${JSON.stringify(pkg, null, 2)}\n`)

    run(['bun', 'install'], appDir)
    run(['bun', 'run', 'build'], appDir)
    run(['bun', 'run', 'doctor'], appDir, {
      ...process.env,
      PATH: [join(root, 'bin'), join(root, 'packages/zig/zig-out/bin'), process.env.PATH ?? ''].join(delimiter),
    })
  }
}
finally {
  rmSync(tmp, { recursive: true, force: true })
}

console.log(`Verified create-craft templates: ${templates.join(', ')}`)
