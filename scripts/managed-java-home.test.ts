import { afterAll, expect, test } from 'bun:test'
import { chmodSync, mkdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { managedJavaHome } from './managed-java-home'
import { createTempDir, removeAllTempDirs } from '../packages/typescript/src/temp-dir'

afterAll(removeAllTempDirs)

function fixture() {
  const root = createTempDir('craft-managed-jdk-')
  const managed = join(root, 'pantry')
  const home = join(managed, 'openjdk.org', 'v17 fixture')
  mkdirSync(join(home, 'bin'), { recursive: true })
  mkdirSync(join(managed, '.bin'))
  for (const path of [join(home, 'bin/java'), join(home, 'bin/javac'), join(managed, '.bin/javac')]) {
    writeFileSync(path, '#!/bin/sh\nexit 0\n')
    chmodSync(path, 0o755)
  }
  return { root, managed, home }
}

test('preserves the provisioned JDK when javac is a regular forwarding launcher', () => {
  const { root, managed, home } = fixture()
  try {
    expect(managedJavaHome(managed, { JAVA_HOME: home })).toBe(home)
  }
  finally { rmSync(root, { recursive: true, force: true }) }
})

test('rejects missing, relative, foreign and incomplete JDK selections before provisioning devices', () => {
  const { root, managed, home } = fixture()
  try {
    for (const selected of [undefined, '', 'openjdk.org/v17', root, managed])
      expect(() => managedJavaHome(managed, { JAVA_HOME: selected })).toThrow('JDK')
    rmSync(join(home, 'bin/javac'))
    expect(() => managedJavaHome(managed, { JAVA_HOME: home })).toThrow('JDK')
  }
  finally { rmSync(root, { recursive: true, force: true }) }
})

test('rejects non-executable, directory and escaped JDK binaries', () => {
  const { root, managed, home } = fixture()
  const java = join(home, 'bin/java')
  try {
    chmodSync(java, 0o644)
    expect(() => managedJavaHome(managed, { JAVA_HOME: home })).toThrow('JDK')
    rmSync(java)
    mkdirSync(java)
    expect(() => managedJavaHome(managed, { JAVA_HOME: home })).toThrow('JDK')
    rmSync(java, { recursive: true })
    symlinkSync(join(managed, '.bin/javac'), java)
    expect(() => managedJavaHome(managed, { JAVA_HOME: home })).toThrow('JDK')
  }
  finally { rmSync(root, { recursive: true, force: true }) }
})
