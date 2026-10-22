import { lstatSync, mkdirSync, readdirSync, readFileSync, readlinkSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { nativeFixtureCommand } from '../packages/ios/scripts/native-fixture-command'

// This replay diagnoses package provisioning. It is never native acceptance.
const project = process.cwd()
const cli = resolve(process.argv[2] || '')
const output = resolve(process.argv[3] || 'artifacts/native-cache-diagnostic')
if (!process.argv[2]) throw new Error('Expected the exact Pantry 0.11.113 executable')
mkdirSync(output, { recursive: true })

function snapshot() {
  const paths = ['pantry/.bin/git', 'pantry/git-scm.org', 'pantry/git-scm.org/v2', 'pantry/git-scm.org/v2.53', 'pantry/git-scm.org/v2.53.0']
  const prefix = 'pantry/git-scm.org/v2.53.0'
  for (const directory of ['', '/bin', '/lib', '/libexec']) {
    try {
      for (const name of readdirSync(join(project, prefix + directory)).slice(0, 100))
        paths.push(`${prefix}${directory}/${name}`)
    }
    catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error
    }
  }
  return paths.map(path => {
    try {
      const stat = lstatSync(join(project, path))
      return { path, mode: stat.mode.toString(8), uid: stat.uid, gid: stat.gid, size: stat.size, type: stat.isSymbolicLink() ? 'symlink' : stat.isDirectory() ? 'directory' : 'file', target: stat.isSymbolicLink() ? readlinkSync(join(project, path)) : undefined }
    }
    catch (error) { return { path, error: (error as NodeJS.ErrnoException).code } }
  })
}

const version = await nativeFixtureCommand([cli, '--version'], { cwd: project, timeoutMs: 10_000 })
if (version.code !== 0 || !version.stdout.includes('0.11.113') || !version.stdout.includes('3a37ec776'))
  throw new Error('Diagnostic requires the original Pantry 0.11.113 executable')

const before = snapshot()
const git = await nativeFixtureCommand([join(project, 'pantry/git-scm.org/v2.53.0/bin/git'), '--version'], { cwd: project, timeoutMs: 10_000 })
const logPath = join(output, 'native-install.log')
const install = await nativeFixtureCommand([cli, 'install', 'git-scm.org@2.53.0', 'github.com/yonaskolb/XcodeGen@2.46.0', '--no-save', '--verbose'], { cwd: project, timeoutMs: 120_000, logPath })
const log = readFileSync(logPath)
const receipt = {
  kind: 'provisioning-diagnostic-only',
  nativeAcceptance: false,
  sourceCommit: process.env.GITHUB_SHA ?? null,
  restoredCacheKey: process.env.NATIVE_DIAGNOSTIC_CACHE_KEY ?? null,
  pantry: { cli, version },
  git,
  before,
  after: snapshot(),
  install,
  logSha256: new Bun.CryptoHasher('sha256').update(log).digest('hex'),
}
writeFileSync(join(output, 'receipt.json'), `${JSON.stringify(receipt, null, 2)}\n`)
console.log(JSON.stringify(receipt, null, 2))
process.exitCode = install.code || (install.timedOut ? 1 : 0)
