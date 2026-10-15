import { afterAll, expect, test } from 'bun:test'
import { rmSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { verifyMacosRelease } from './verify-macos-release'
import { createTempDir, removeAllTempDirs } from '../packages/typescript/src/temp-dir'

// Every scratch directory this file made goes when the file is done (#357).
afterAll(removeAllTempDirs)

test.skipIf(process.platform !== 'darwin')('distribution entitlements allow a standalone signed CLI to start', () => {
  const temp = createTempDir('craft-cli-signing-')
  const run = (args: string[]): string => {
    const result = Bun.spawnSync(args, { cwd: temp, stdout: 'pipe', stderr: 'pipe' })
    expect({ exitCode: result.exitCode, signal: result.signalCode, stderr: result.stderr.toString() })
      .toMatchObject({ exitCode: 0 })
    return result.stdout.toString()
  }
  try {
    writeFileSync(join(temp, 'main.c'), '#include <stdio.h>\nint main(void) { puts("craft version 7.8.9"); return 0; }\n')
    const binary = join(temp, 'craft')
    run(['xcrun', 'clang', 'main.c', '-o', binary])
    run(['codesign', '--force', '--sign', '-', '--options', 'runtime', '--entitlements', resolve(import.meta.dir, 'entitlements-distribution.plist'), binary])
    run(['codesign', '--verify', '--deep', '--strict', binary])
    expect(run([binary, '--version']).trim()).toBe('craft version 7.8.9')
    expect(() => verifyMacosRelease(binary, '7.8.9')).not.toThrow()
    expect(() => verifyMacosRelease(binary, '7.8.10')).toThrow('Expected craft version 7.8.10')
  }
  finally {
    rmSync(temp, { recursive: true, force: true })
  }
}, 30_000)
