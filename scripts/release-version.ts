import { appendFileSync, existsSync, readFileSync, realpathSync } from 'node:fs'
import { isAbsolute, join, relative, resolve, sep } from 'node:path'
import { runZig } from './zig'

/** Match CI's core formatting gate before creating an immutable release tag. */
export function validateReleaseFormatting(root: string, env: NodeJS.ProcessEnv = process.env): void {
  const code = runZig(root, ['--core', 'fmt', '--check', 'src/', 'build.zig'], { ...env, CRAFT_ALLOW_UNPINNED_ZIG: undefined })
  if (code !== 0) throw new Error('Release Zig formatting check failed. Run bun run fmt, review the changes, and commit them before releasing.')
}

/** Fail before a bump if a sparse checkout omits manifests that CI will publish. */
export function validateReleaseCheckout(root: string): void {
  const tracked = Bun.spawnSync(['git', 'ls-files', '--', 'packages/*/package.json'], { cwd: root })
  if (tracked.exitCode !== 0) throw new Error('Release preflight must run in the Git checkout')
  const missing = tracked.stdout.toString().trim().split('\n').filter(file => file && !existsSync(join(root, file)))
  if (missing.length)
    throw new Error(`Release checkout omits package manifests: ${missing.join(', ')}. Expand the sparse checkout before releasing.`)
}

/** Refuse missing release tools before a version or immutable tag can change. */
export function validateReleaseDependencies(root: string): void {
  for (const cli of ['@stacksjs/bumpx/bin/cli.js', '@stacksjs/logsmith/bin/cli.js']) {
    try {
      const packageRoot = realpathSync(join(root, 'node_modules', ...cli.split('/').slice(0, 2)))
      const resolved = relative(packageRoot, realpathSync(Bun.resolveSync(cli, root)))
      if (resolved === '..' || resolved.startsWith(`..${sep}`) || isAbsolute(resolved)) throw new Error('The CLI resolved outside the installed project dependency')
    }
    catch (cause) {
      throw new Error(`Cannot resolve release dependency ${cli}. Run bun install --frozen-lockfile before releasing.`, { cause })
    }
  }
}

/** Releases originate from a clean main that matches the current remote. */
export function validateReleaseGit(root: string): void {
  const git = (...args: string[]): string => {
    const result = Bun.spawnSync(['git', ...args], { cwd: root, stdout: 'pipe', stderr: 'pipe', timeout: 30_000 })
    if (result.exitCode !== 0) throw new Error(`Release Git preflight failed: ${result.stderr.toString().trim()}`)
    return result.stdout.toString().trim()
  }
  if (git('branch', '--show-current') !== 'main') throw new Error('Release from main, using an isolated checkout when main is already in use.')
  if (git('status', '--porcelain')) throw new Error('Release requires a clean main checkout.')
  git('fetch', 'origin', 'main')
  if (git('rev-parse', 'HEAD') !== git('rev-parse', 'origin/main')) throw new Error('Release main must match origin/main. Synchronize and verify its checks before releasing.')
}

export function validateReleaseVersion(ref: string, version: string, manifests: Record<string, unknown>): void {
  const errors: string[] = []
  const identifier = '(?:0|[1-9]\\d*|[\\da-z-]*[a-z-][\\da-z-]*)'
  const semver = new RegExp(`^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(?:-${identifier}(?:\\.${identifier})*)?(?:\\+[\\da-z-]+(?:\\.[\\da-z-]+)*)?$`, 'i')
  if (!semver.test(version))
    errors.push(`package.json: invalid release version ${JSON.stringify(version)}`)
  if (!ref.startsWith('refs/tags/'))
    errors.push(`Release requires a tag ref; received ${JSON.stringify(ref)}`)
  else if (ref !== `refs/tags/v${version}`)
    errors.push(`Tag ${ref.slice('refs/tags/'.length)} must equal v${version}`)
  for (const [path, value] of Object.entries(manifests)) {
    if (value !== version)
      errors.push(`${path}: expected ${version}, received ${JSON.stringify(value)}`)
  }
  if (errors.length > 0)
    throw new Error(`Release version validation failed:\n${errors.join('\n')}`)
}

export function checkReleaseVersion(root: string, ref: string): string {
  const canonical = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')).version
  const versions: Record<string, unknown> = {}
  for (const path of new Bun.Glob('packages/*/package.json').scanSync({ cwd: root })) {
    const pkg = JSON.parse(readFileSync(join(root, path), 'utf8'))
    if (!pkg.private) versions[path] = pkg.version
  }
  const zigPath = 'packages/zig/build.zig.zon'
  versions[zigPath] = readFileSync(join(root, zigPath), 'utf8').match(/\.version\s*=\s*"([^"]+)"/)?.[1]
  const pantryPath = 'packages/zig/pantry.json'
  versions[pantryPath] = JSON.parse(readFileSync(join(root, pantryPath), 'utf8')).version
  validateReleaseVersion(ref, canonical, versions)
  return canonical
}

if (import.meta.main) {
  const root = resolve(import.meta.dir, '..')
  if (process.argv.includes('--preflight')) {
    validateReleaseCheckout(root)
    validateReleaseDependencies(root)
    validateReleaseFormatting(root)
    validateReleaseGit(root)
    console.log('Release checkout contains every tracked package manifest')
    process.exit(0)
  }
  const ref = process.argv.includes('--pending')
    ? `refs/tags/v${JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')).version}`
    : process.env.GITHUB_REF ?? ''
  const version = checkReleaseVersion(root, ref)
  console.log(`Verified release v${version}`)
  if (process.env.GITHUB_OUTPUT)
    appendFileSync(process.env.GITHUB_OUTPUT, `version=${version}\n`)
}
