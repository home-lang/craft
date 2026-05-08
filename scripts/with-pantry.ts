#!/usr/bin/env bun
import { existsSync, readdirSync } from 'node:fs'
import { dirname, delimiter, isAbsolute, join, resolve } from 'node:path'
import { spawnSync } from 'node:child_process'
import { homedir } from 'node:os'
import { fileURLToPath } from 'node:url'

const defaultPackages = ['ziglang.org/v0.17.0-dev']

function repoRoot(): string {
  if (process.env.CRAFT_ROOT && existsSync(process.env.CRAFT_ROOT))
    return resolve(process.env.CRAFT_ROOT)

  return resolve(dirname(fileURLToPath(import.meta.url)), '..')
}

function pathEnvKey(): string {
  return Object.keys(process.env).find(key => key.toLowerCase() === 'path') ?? 'PATH'
}

function candidateRoots(root: string): string[] {
  const parent = dirname(root)
  return [
    process.env.CRAFT_PANTRY_ROOT,
    process.env.PANTRY_ROOT,
    join(homedir(), 'Code/Tools/pantry/pantry'),
    join(parent, 'pantry/pantry'),
    join(root, 'pantry'),
    join(homedir(), 'Code/Tools/pantry'),
    join(parent, 'pantry'),
  ].filter((value): value is string => Boolean(value))
}

function resolvePantryRoot(root: string): string {
  for (const candidate of candidateRoots(root)) {
    if (existsSync(candidate))
      return resolve(candidate)
  }

  throw new Error('Unable to find pantry dependencies. Run `pantry install`, or set CRAFT_PANTRY_ROOT.')
}

function resolvePackageDir(root: string, spec: string): string {
  for (const candidate of candidateRoots(root)) {
    const exact = join(candidate, spec)
    if (existsSync(exact))
      return resolve(exact)
  }

  const slash = spec.lastIndexOf('/')
  if (slash !== -1) {
    const parentSpec = spec.slice(0, slash)
    const versionPrefix = spec.slice(slash + 1)
    for (const candidate of candidateRoots(root)) {
      const parent = join(candidate, parentSpec)
      if (!existsSync(parent))
        continue

      const match = readdirSync(parent)
        .filter(entry => entry.startsWith(versionPrefix) && existsSync(join(parent, entry)))
        .sort()
        .at(-1)

      if (match)
        return resolve(parent, match)
    }
  }

  throw new Error(`Missing pantry package: ${spec}. Run \`pantry install\`, or set CRAFT_PANTRY_ROOT.`)
}

function usage(): never {
  console.error('usage: bun scripts/with-pantry.ts [--cwd DIR] [--package name/version] -- <command> [args...]')
  process.exit(2)
}

const args = process.argv.slice(2)
const packages = [...defaultPackages]
let cwd = ''

while (args.length > 0) {
  const arg = args[0]
  if (arg === '--cwd') {
    args.shift()
    cwd = args.shift() ?? ''
    if (!cwd)
      usage()
    continue
  }
  if (arg === '--package') {
    args.shift()
    const spec = args.shift()
    if (!spec)
      usage()
    packages.push(spec)
    continue
  }
  if (arg === '--print-root') {
    console.log(resolvePantryRoot(repoRoot()))
    process.exit(0)
  }
  if (arg === '--print-path') {
    const root = repoRoot()
    const pantryRoot = resolvePantryRoot(root)
    const pathParts = packages.flatMap((spec) => {
      const packageDir = resolvePackageDir(root, spec)
      const binDir = join(packageDir, 'bin')
      return existsSync(binDir) ? [packageDir, binDir] : [packageDir]
    })
    pathParts.push(join(pantryRoot, '.bin'))
    console.log([...pathParts, process.env[pathEnvKey()] ?? ''].join(delimiter))
    process.exit(0)
  }
  if (arg === '--') {
    args.shift()
    break
  }
  if (arg.startsWith('-')) {
    console.error(`with-pantry: unknown option ${arg}`)
    process.exit(2)
  }
  break
}

if (args.length === 0)
  usage()

const root = repoRoot()
const pantryRoot = resolvePantryRoot(root)
const pathParts = packages.flatMap((spec) => {
  const packageDir = resolvePackageDir(root, spec)
  const binDir = join(packageDir, 'bin')
  return existsSync(binDir) ? [packageDir, binDir] : [packageDir]
})
pathParts.push(join(pantryRoot, '.bin'))

const env = { ...process.env, CRAFT_PANTRY_ROOT: pantryRoot }
const key = pathEnvKey()
env[key] = [...pathParts, env[key] ?? ''].join(delimiter)

const commandCwd = cwd ? (isAbsolute(cwd) ? cwd : join(root, cwd)) : process.cwd()
const child = spawnSync(args[0], args.slice(1), {
  cwd: commandCwd,
  env,
  shell: process.platform === 'win32',
  stdio: 'inherit',
})

if (child.error)
  throw child.error

process.exit(child.status ?? 1)
