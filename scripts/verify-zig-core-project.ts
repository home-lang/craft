import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { resolveZig } from './zig'

const source = resolve(import.meta.dir, '..')
const zig = resolveZig(source)
console.log('Tracked core project:', JSON.stringify({ file: join(source, 'packages/zig/build.zig'), exists: existsSync(join(source, 'packages/zig/build.zig')) }))
// Keep the fixture on the checkout's volume. Hosted Windows keeps the
// checkout on D: and the system temporary directory/compiler cache on C:.
const root = mkdtempSync(join(source, '.zig-core-project-'))
const core = join(root, 'packages', 'zig')
try {
  mkdirSync(core, { recursive: true })
  writeFileSync(join(root, 'pantry.lock'), readFileSync(join(source, 'pantry.lock')))
  writeFileSync(join(root, 'package.json'), JSON.stringify({ version: '1.2.3' }))
  writeFileSync(join(root, 'build.zig'), 'const std=@import("std"); pub fn build(b:*std.Build) void {_=b.standardOptimizeOption(.{});}\n')
  writeFileSync(join(core, 'build.zig'), 'const std=@import("std"); pub fn build(b:*std.Build) void {_=b.standardOptimizeOption(.{}); const version=b.option([]const u8,"version","version") orelse "missing"; std.debug.print("PROJECT_VERSION={s}\\n",.{version});}\n')
  const env = { ...process.env, CRAFT_ZIG: zig.path }
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
