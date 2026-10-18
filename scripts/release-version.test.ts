import { afterAll, expect, test } from 'bun:test'
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { validateReleaseCheckout, checkReleaseVersion, validateReleaseVersion } from './release-version'
import { createTempDir, removeAllTempDirs } from '../packages/typescript/src/temp-dir'

// Every scratch directory this file made goes when the file is done (#357).
afterAll(removeAllTempDirs)

test('accepts a matching tag, including a prerelease', () => {
  for (const version of ['0.0.93', '1.2.3-rc.1', '1.2.3+build.4'])
    expect(() => validateReleaseVersion(`refs/tags/v${version}`, version, { sdk: version })).not.toThrow()
})

test('rejects branch dispatch, missing refs, mismatched tags and malformed versions', () => {
  for (const ref of ['refs/heads/main', '', 'refs/tags/v0.0.92', 'refs/tags/0.0.93', 'refs/tags/v0.0.93/extra'])
    expect(() => validateReleaseVersion(ref, '0.0.93', {})).toThrow()
  for (const version of ['latest', '1.2', '01.2.3', '1.2.3\nversion=4.5.6', '1.2.3-01', '1.2.3-alpha..1', '1.2.3+foo..bar'])
    expect(() => validateReleaseVersion(`refs/tags/v${version}`, version, {})).toThrow()
})

test('reports every mismatched manifest in one diagnostic', () => {
  try {
    validateReleaseVersion('refs/tags/v1.2.3', '1.2.3', { 'packages/android/package.json': '1.2.2', 'packages/ios/package.json': undefined, 'packages/zig/build.zig.zon': '1.0.0' })
    throw new Error('expected validation to reject')
  }
  catch (error) {
    expect(String(error)).toContain('packages/android/package.json')
    expect(String(error)).toContain('packages/ios/package.json')
    expect(String(error)).toContain('packages/zig/build.zig.zon')
  }
})

test('discovers public workspaces and Zig metadata, excluding private examples', () => {
  const temp = createTempDir('craft-release-version-')
  try {
    for (const name of ['sdk', 'example', 'zig']) mkdirSync(join(temp, 'packages', name), { recursive: true })
    writeFileSync(join(temp, 'package.json'), JSON.stringify({ version: '1.2.3' }))
    writeFileSync(join(temp, 'packages/sdk/package.json'), JSON.stringify({ name: 'fixture', version: '1.2.3' }))
    writeFileSync(join(temp, 'packages/example/package.json'), JSON.stringify({ private: true, version: '0.0.1' }))
    writeFileSync(join(temp, 'packages/zig/build.zig.zon'), '.{ .version = "1.2.3", }')
    writeFileSync(join(temp, 'packages/zig/pantry.json'), JSON.stringify({ version: '1.2.3' }))
    expect(checkReleaseVersion(temp, 'refs/tags/v1.2.3')).toBe('1.2.3')
    writeFileSync(join(temp, 'packages/sdk/package.json'), JSON.stringify({ name: 'fixture', version: '1.2.2' }))
    expect(() => checkReleaseVersion(temp, 'refs/tags/v1.2.3')).toThrow('packages/sdk/package.json')
  }
  finally {
    rmSync(temp, { recursive: true, force: true })
  }
})

test('refuses an incomplete sparse release checkout before a version bump', () => {
  const root = createTempDir('craft-release-checkout-')
  mkdirSync(join(root, 'packages', 'react'), { recursive: true })
  const manifest = join(root, 'packages/react/package.json')
  writeFileSync(manifest, '{"version":"1.2.3"}')
  expect(Bun.spawnSync(['git', 'init', '-q'], { cwd: root }).exitCode).toBe(0)
  expect(Bun.spawnSync(['git', 'add', '.'], { cwd: root }).exitCode).toBe(0)
  expect(() => validateReleaseCheckout(root)).not.toThrow()
  rmSync(manifest)
  expect(() => validateReleaseCheckout(root)).toThrow('packages/react/package.json')
})

test('release preflight rejects missing tools before changing package versions or tags', () => {
  const root = createTempDir('craft-release-prerequisites-')
  mkdirSync(join(root, 'scripts'))
  const manifest = '{"version":"1.2.3"}\n'
  writeFileSync(join(root, 'package.json'), manifest)
  writeFileSync(join(root, 'scripts/release-version.ts'), readFileSync(join(import.meta.dir, 'release-version.ts')))
  expect(Bun.spawnSync(['git', 'init', '-q'], { cwd: root }).exitCode).toBe(0)
  const result = Bun.spawnSync([process.execPath, 'scripts/release-version.ts', '--preflight'], { cwd: root, stdout: 'pipe', stderr: 'pipe' })
  expect(result.exitCode).not.toBe(0)
  expect(result.stderr.toString()).toContain('bun install --frozen-lockfile')
  expect(readFileSync(join(root, 'package.json'), 'utf8')).toBe(manifest)
  expect(Bun.spawnSync(['git', 'tag', '--list'], { cwd: root, stdout: 'pipe' }).stdout.toString()).toBe('')
})
