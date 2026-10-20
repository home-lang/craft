import { existsSync, mkdtempSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { resolveZig } from './zig'
import { createHash } from 'node:crypto'
import { cpus } from 'node:os'

const source = resolve(import.meta.dir, '..')
const zig = resolveZig(source)
if (process.platform === 'win32') {
  const provenance = Bun.spawnSync(['pwsh', '-NoProfile', '-NonInteractive', '-File', join(source, 'scripts/inspect-windows-source.ps1'), '-Stage', 'compiler'], { cwd: source, stdout: 'pipe', stderr: 'pipe' })
  console.log('Source after compiler:', provenance.stdout.toString(), provenance.stderr.toString())
}
const trackedBuild = join(source, 'packages/zig/build.zig')
console.log('Tracked core project:', JSON.stringify({ file: trackedBuild, exists: existsSync(trackedBuild), sha256: existsSync(trackedBuild) ? createHash('sha256').update(readFileSync(trackedBuild)).digest('hex') : null, bun: Bun.version, executable: process.execPath, cpu: cpus()[0]?.model, platform: process.platform }))
const zigLibrary = join(dirname(realpathSync(zig.path)), 'lib/std/zig.zig')
console.log('Pinned compiler bytes:', JSON.stringify({ executable: zig.path, sha256: createHash('sha256').update(readFileSync(zig.path)).digest('hex'), library: zigLibrary, librarySha256: existsSync(zigLibrary) ? createHash('sha256').update(readFileSync(zigLibrary)).digest('hex') : null }))
// Keep the fixture on the checkout's volume. Hosted Windows keeps the
// checkout on D: and the system temporary directory/compiler cache on C:.
const root = mkdtempSync(join(source, '.zig-core-project-'))
const core = join(root, 'packages', 'zig')
try {
  mkdirSync(core, { recursive: true })
  if (process.platform === 'win32') {
    const volumes = Bun.spawnSync(['pwsh', '-NoProfile', '-NonInteractive', '-Command', 'Get-Volume | Where-Object { $_.DriveLetter -in @("C", "D") } | Select-Object DriveLetter,FileSystemType,HealthStatus | ConvertTo-Json -Compress'], { stdout: 'pipe', stderr: 'pipe' })
    console.log('Native source/cache volumes:', volumes.stdout.toString(), volumes.stderr.toString())
  }
  const native = Bun.spawnSync([zig.path, 'run', join(source, 'scripts/zig-source-cache-probe.zig'), '--cache-dir', join(root, 'io-build-cache'), '--', join(source, 'packages/zig'), join(root, 'io-manifest-cache')], { cwd: join(source, 'packages/zig'), stdout: 'pipe', stderr: 'pipe' })
  console.log('Native source/cache probe:', native.exitCode, native.stdout.toString(), native.stderr.toString())
  if (native.exitCode !== 0) throw new Error('The pinned native source/cache I/O probe failed.')
  writeFileSync(join(root, 'pantry.lock'), readFileSync(join(source, 'pantry.lock')))
  writeFileSync(join(root, 'package.json'), JSON.stringify({ version: '1.2.3' }))
  writeFileSync(join(root, 'build.zig'), 'const std=@import("std"); pub fn build(b:*std.Build) void {_=b.standardOptimizeOption(.{});}\n')
  writeFileSync(join(core, 'build.zig'), 'const std=@import("std"); pub fn build(b:*std.Build) void {_=b.standardOptimizeOption(.{}); const version=b.option([]const u8,"version","version") orelse "missing"; std.debug.print("PROJECT_VERSION={s}\\n",.{version});}\n')
  const manifest = { name: 'craft', fingerprint: '0xf45c4a848bf58c1c' }
  writeFileSync(join(core, 'build.zig.zon'), `.{ .name=.${manifest.name}, .fingerprint=${manifest.fingerprint}, .version="1.2.3", .dependencies=.{ .fixture=.{ .path="../../dependency" } }, .paths=.{"build.zig","build.zig.zon"} }\n`)
  const dependency = join(root, 'dependency')
  mkdirSync(dependency)
  writeFileSync(join(dependency, 'build.zig'), 'const std=@import("std"); pub fn build(b:*std.Build) void {_=b;}\n')
  writeFileSync(join(dependency, 'build.zig.zon'), `.{ .name=.${manifest.name}, .fingerprint=${manifest.fingerprint}, .version="0.0.1", .paths=.{"build.zig","build.zig.zon"} }\n`)
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
