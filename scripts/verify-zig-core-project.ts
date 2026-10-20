import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { resolveZig } from './zig'

const source = resolve(import.meta.dir, '..')
const zig = resolveZig(source)
console.log('Tracked core project:', JSON.stringify({ file: join(source, 'packages/zig/build.zig'), exists: existsSync(join(source, 'packages/zig/build.zig')) }))
const root = mkdtempSync(join(tmpdir(), 'craft-core-project-'))
const core = join(root, 'packages', 'zig')
try {
  mkdirSync(core, { recursive: true })
  writeFileSync(join(root, 'pantry.lock'), readFileSync(join(source, 'pantry.lock')))
  writeFileSync(join(root, 'package.json'), JSON.stringify({ version: '1.2.3' }))
  writeFileSync(join(root, 'build.zig'), 'const std=@import("std"); pub fn build(b:*std.Build) void {_=b.standardOptimizeOption(.{});}\n')
  writeFileSync(join(core, 'build.zig'), 'const std=@import("std"); pub fn build(b:*std.Build) void {_=b.standardOptimizeOption(.{}); const version=b.option([]const u8,"version","version") orelse "missing"; std.debug.print("PROJECT_VERSION={s}\\n",.{version});}\n')
  const env = { ...process.env, CRAFT_ZIG: zig.path }
  const child = Bun.spawnSync([process.execPath, '-p', 'process.cwd()'], { cwd: core, env, stdout: 'pipe', stderr: 'pipe' })
  console.log('Requested/observed child cwd:', JSON.stringify({ requested: core, observed: child.stdout.toString().trim(), status: child.exitCode }))
  for (const mode of ['default', 'absolute', 'relative'] as const) {
    const cwd = mode === 'relative' ? root : core
    const args = mode === 'default' ? [] : ['--build-file', mode === 'absolute' ? join(core, 'build.zig') : 'packages/zig/build.zig']
    const result = Bun.spawnSync([zig.path, 'build', ...args, '-Dversion=1.2.3'], { cwd, env, stdout: 'pipe', stderr: 'pipe' })
    console.log(JSON.stringify({ mode, cwd, status: result.exitCode, stdout: result.stdout.toString(), stderr: result.stderr.toString() }))
  }
  const runner = join(root, 'runner.ts')
  writeFileSync(runner, `import {runZig} from ${JSON.stringify(join(source, 'scripts/zig.ts'))};process.exitCode=runZig(${JSON.stringify(root)},['--core','--versioned','build']);\n`)
  const result = Bun.spawnSync([process.execPath, runner], { cwd: root, env, stdout: 'pipe', stderr: 'pipe' })
  console.log(result.stdout.toString(), result.stderr.toString())
  // The root wrapper rejects -Dversion. A successful configure therefore
  // proves core selection even when Zig reuses its cached configuration.
  if (result.exitCode !== 0)
    throw new Error('The actual pinned compiler did not configure the selected core project with its package version.')
}
finally {
  rmSync(root, { recursive: true, force: true })
}
