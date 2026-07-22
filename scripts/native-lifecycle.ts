#!/usr/bin/env bun

import type { PackageResult } from '../packages/typescript/src/package'
import { createHash } from 'crypto'
import { chmodSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'fs'
import { join, resolve } from 'path'
import { packageApp } from '../packages/typescript/src/package'

type Step = {
  name: string
  command?: string[]
  status: 'passed' | 'failed' | 'skipped'
  output?: string
  error?: string
}

const root = resolve(import.meta.dir, '..')
const platform = process.platform === 'darwin' ? 'macos' : process.platform === 'win32' ? 'windows' : 'linux'
const evidenceLabel = process.env.CRAFT_EVIDENCE_LABEL || `${process.platform}-${process.arch}`
const reportDir = join(root, 'artifacts', 'native-lifecycle', evidenceLabel)
const workDir = join(reportDir, 'work')
const shouldInstall = process.argv.includes('--install')
const steps: Step[] = []

function sha256(path: string): string {
  return createHash('sha256').update(readFileSync(path)).digest('hex')
}

async function command(name: string, argv: string[], expected?: string): Promise<string> {
  const entry: Step = { name, command: argv, status: 'failed' }
  steps.push(entry)
  const proc = Bun.spawn(argv, { stdout: 'pipe', stderr: 'pipe', env: process.env })
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ])
  const output = `${stdout}${stderr}`.trim()
  entry.output = output
  if (exitCode !== 0) {
    entry.error = `${argv[0]} exited with ${exitCode}`
    throw new Error(`${name}: ${entry.error}\n${output}`)
  }
  if (expected !== undefined && !output.includes(expected)) {
    entry.error = `expected output to include ${JSON.stringify(expected)}`
    throw new Error(`${name}: ${entry.error}; got ${JSON.stringify(output)}`)
  }
  entry.status = 'passed'
  return output
}

function requireArtifact(results: PackageResult[], format: string): string {
  const result = results.find(candidate => candidate.format === format)
  if (!result) throw new Error(`packager did not return ${format}`)
  if (!result.success || !result.outputPath) throw new Error(`${format} packaging failed: ${result.error || 'missing output'}`)
  if (!existsSync(result.outputPath)) throw new Error(`${format} output does not exist: ${result.outputPath}`)
  return result.outputPath
}

async function buildFixture(version: string): Promise<string> {
  const source = join(workDir, `fixture-${version}.ts`)
  const binary = join(workDir, `craft-lifecycle-${version}${process.platform === 'win32' ? '.exe' : ''}`)
  writeFileSync(source, `console.log(${JSON.stringify(`craft-lifecycle ${version}`)})\n`)
  await command(`compile fixture ${version}`, ['bun', 'build', '--compile', source, '--outfile', binary])
  if (process.platform !== 'win32') chmodSync(binary, 0o755)
  return binary
}

async function createPackages(version: string, binaryPath: string): Promise<PackageResult[]> {
  const outDir = join(workDir, `packages-${version}`)
  const results = await packageApp({
    name: 'craft-lifecycle',
    version,
    description: 'Craft native package lifecycle contract fixture',
    author: 'Stacks.js',
    binaryPath,
    outDir,
    bundleId: 'dev.craft.lifecycle',
    platforms: [platform],
    macos: { dmg: true, pkg: true },
    windows: { msi: true, zip: true },
    linux: { deb: true, rpm: false, appImage: false, debDependencies: [] },
  })
  const failures = results.filter(result => !result.success)
  if (failures.length) throw new Error(failures.map(result => `${result.format}: ${result.error}`).join('\n'))
  steps.push({ name: `package fixture ${version}`, status: 'passed', output: results.map(result => result.outputPath).join('\n') })
  return results
}

async function exerciseLinux(v1: PackageResult[], v2: PackageResult[]): Promise<void> {
  const first = requireArtifact(v1, 'deb')
  const second = requireArtifact(v2, 'deb')
  await command('install v1', ['sudo', 'dpkg', '-i', first])
  await command('launch v1', ['/usr/bin/craft-lifecycle'], 'craft-lifecycle 1.0.0')
  await command('update to v2', ['sudo', 'dpkg', '-i', second])
  await command('launch v2', ['/usr/bin/craft-lifecycle'], 'craft-lifecycle 1.0.1')
  await command('rollback to v1', ['sudo', 'dpkg', '-i', first])
  await command('launch rollback', ['/usr/bin/craft-lifecycle'], 'craft-lifecycle 1.0.0')
  await command('uninstall', ['sudo', 'dpkg', '--remove', 'craft-lifecycle'])
  if (existsSync('/usr/bin/craft-lifecycle')) throw new Error('Linux uninstall left /usr/bin/craft-lifecycle behind')
  steps.push({ name: 'verify uninstall', status: 'passed' })
}

async function exerciseMacOS(v1: PackageResult[], v2: PackageResult[]): Promise<void> {
  const first = requireArtifact(v1, 'pkg')
  const second = requireArtifact(v2, 'pkg')
  const app = '/Applications/craft-lifecycle.app'
  const executable = join(app, 'Contents', 'MacOS', 'craft-lifecycle')
  if (existsSync(app)) await command('remove pre-existing fixture', ['sudo', 'rm', '-rf', app])
  await command('install v1', ['sudo', 'installer', '-pkg', first, '-target', '/'])
  await command('launch v1', [executable], 'craft-lifecycle 1.0.0')
  await command('update to v2', ['sudo', 'installer', '-pkg', second, '-target', '/'])
  await command('launch v2', [executable], 'craft-lifecycle 1.0.1')
  await command('rollback to v1', ['sudo', 'installer', '-pkg', first, '-target', '/'])
  await command('launch rollback', [executable], 'craft-lifecycle 1.0.0')
  await command('uninstall', ['sudo', 'rm', '-rf', app])
  await command('forget installer receipt', ['sudo', 'pkgutil', '--forget', 'dev.craft.lifecycle'])
  if (existsSync(app)) throw new Error(`macOS uninstall left ${app} behind`)
  steps.push({ name: 'verify uninstall', status: 'passed' })
}

async function exerciseWindows(v1: PackageResult[], v2: PackageResult[]): Promise<void> {
  const first = requireArtifact(v1, 'msi')
  const second = requireArtifact(v2, 'msi')
  const programFiles = process.env.ProgramFiles || 'C:\\Program Files'
  const executable = join(programFiles, 'craft-lifecycle', 'craft-lifecycle.exe')
  await command('install v1', ['msiexec.exe', '/i', first, '/qn', '/norestart'])
  await command('launch v1', [executable], 'craft-lifecycle 1.0.0')
  await command('update to v2', ['msiexec.exe', '/i', second, '/qn', '/norestart'])
  await command('launch v2', [executable], 'craft-lifecycle 1.0.1')
  await command('rollback to v1', ['msiexec.exe', '/i', first, '/qn', '/norestart'])
  await command('launch rollback', [executable], 'craft-lifecycle 1.0.0')
  await command('uninstall', ['msiexec.exe', '/x', first, '/qn', '/norestart'])
  if (existsSync(executable)) throw new Error(`Windows uninstall left ${executable} behind`)
  steps.push({ name: 'verify uninstall', status: 'passed' })
}

async function main(): Promise<void> {
  rmSync(reportDir, { recursive: true, force: true })
  mkdirSync(workDir, { recursive: true })
  let error: string | undefined
  let packages: PackageResult[] = []
  try {
    const binaryV1 = await buildFixture('1.0.0')
    const binaryV2 = await buildFixture('1.0.1')
    const packagesV1 = await createPackages('1.0.0', binaryV1)
    const packagesV2 = await createPackages('1.0.1', binaryV2)
    packages = [...packagesV1, ...packagesV2]
    if (shouldInstall) {
      if (platform === 'macos') await exerciseMacOS(packagesV1, packagesV2)
      else if (platform === 'windows') await exerciseWindows(packagesV1, packagesV2)
      else await exerciseLinux(packagesV1, packagesV2)
    }
    else {
      steps.push({ name: 'install/update/rollback/uninstall', status: 'skipped', output: 'Pass --install to exercise privileged lifecycle operations.' })
    }
  }
  catch (caught) {
    error = caught instanceof Error ? caught.stack || caught.message : String(caught)
  }

  const artifacts = packages
    .filter(result => result.success && result.outputPath && existsSync(result.outputPath))
    .map(result => ({
      platform: result.platform,
      format: result.format,
      path: result.outputPath!.replace(`${root}/`, ''),
      sha256: sha256(result.outputPath!),
    }))
  const report = {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    revision: process.env.CRAFT_SOURCE_REVISION || process.env.GITHUB_SHA || 'local',
    orchestratorRevision: process.env.CRAFT_SOURCE_REVISION ? process.env.GITHUB_SHA || null : null,
    runner: { os: process.platform, arch: process.arch, bun: Bun.version },
    installLifecycleExercised: shouldInstall,
    status: error ? 'failed' : 'passed',
    artifacts,
    steps,
    error,
  }
  mkdirSync(reportDir, { recursive: true })
  writeFileSync(join(reportDir, 'report.json'), `${JSON.stringify(report, null, 2)}\n`)
  console.log(JSON.stringify(report, null, 2))
  if (error) throw new Error(error)
}

await main()
