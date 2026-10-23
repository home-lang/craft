import { expect, test } from 'bun:test'
import { chmodSync, mkdirSync, readFileSync, realpathSync, symlinkSync, writeFileSync } from 'node:fs'
import { join, win32 } from 'node:path'
import { insideManagedRoot, verifyManagedGit } from './managed-git'
import { createTempDir, removeTempDir } from '../packages/typescript/src/temp-dir'

test('provider containment respects Windows casing and rejects sibling/cross-drive paths', () => {
  expect(insideManagedRoot('D:\\a\\craft\\pantry', 'd:\\A\\craft\\pantry\\git-scm.org\\git.exe', win32)).toBe(true)
  expect(insideManagedRoot('D:\\a\\craft\\pantry', 'D:\\a\\craft\\pantry-other\\git.exe', win32)).toBe(false)
  expect(insideManagedRoot('D:\\a\\craft\\pantry', 'C:\\Git\\git.exe', win32)).toBe(false)
})

test.skipIf(process.platform === 'win32')('uses the declared executable for downstream commands despite an ambient Git', () => {
  const root = createTempDir('craft-managed-git-')
  const previous = process.env.PATH
  try {
    const bin = join(root, 'pantry/.bin')
    const ambient = join(root, 'ambient')
    mkdirSync(bin, { recursive: true })
    mkdirSync(ambient)
    const git = join(bin, 'git')
    writeFileSync(git, '#!/bin/sh\nif [ "$1" = "--version" ]; then echo "git version 2.53.0"; else echo "managed:$*"; fi\n')
    writeFileSync(join(ambient, 'git'), '#!/bin/sh\nexit 91\n')
    chmodSync(git, 0o755)
    chmodSync(join(ambient, 'git'), 0o755)
    process.env.PATH = `${ambient}:${previous}`
    expect(verifyManagedGit(root).executable).toBe(realpathSync(git))
    const run = Bun.spawnSync([process.execPath, join(import.meta.dir, 'managed-git.ts'), 'rev-parse', 'HEAD'], { cwd: root, stdout: 'pipe', stderr: 'pipe' })
    expect(run.exitCode, run.stderr.toString()).toBe(0)
    expect(run.stdout.toString().trim()).toBe('managed:rev-parse HEAD')
    const output = join(root, 'github-output')
    const verify = Bun.spawnSync([process.execPath, join(import.meta.dir, 'managed-git.ts'), '--verify'], { cwd: root, env: { ...process.env, GITHUB_OUTPUT: output }, stdout: 'pipe', stderr: 'pipe' })
    expect(verify.exitCode).toBe(0)
    expect(readFileSync(output, 'utf8')).toBe(`executable=${realpathSync(git)}\n`)
    // A misleading .bin link must not weaken provider ownership.
    const outside = join(root, 'outside-git')
    writeFileSync(outside, '#!/bin/sh\necho "git version 2.53.0"\n')
    chmodSync(outside, 0o755)
    symlinkSync(outside, join(bin, 'escaped-git'))
    expect(insideManagedRoot(realpathSync(join(root, 'pantry')), realpathSync(join(bin, 'escaped-git')))).toBe(false)
  }
  finally {
    process.env.PATH = previous
    removeTempDir(root)
  }
})
