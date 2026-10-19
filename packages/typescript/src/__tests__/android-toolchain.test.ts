import { expect, test } from 'bun:test'
import { readFileSync } from 'node:fs'

const template = readFileSync(new URL('../../../android/templates/build.gradle.kts.project.template', import.meta.url), 'utf8')

test('generated Android builds bundle an R8 version that understands their Kotlin metadata', () => {
  const kotlin = template.match(/id\("org\.jetbrains\.kotlin\.android"\) version "(\d+\.\d+)\.\d+"/)
  const agp = template.match(/id\("com\.android\.application"\) version "(\d+)\.(\d+)\.\d+"/)
  expect(kotlin).not.toBeNull()
  expect(agp).not.toBeNull()

  // AGP bundles R8. Kotlin 2.2 metadata requires R8 8.10.21, shipped by AGP 8.10.
  // https://developer.android.com/build/kotlin-support
  const minimumAgp: Record<string, readonly [number, number]> = {
    '2.0': [8, 5],
    '2.1': [8, 6],
    '2.2': [8, 10],
    '2.3': [8, 13],
  }
  const minimum = minimumAgp[kotlin![1]!]
  expect(minimum).toBeDefined()
  expect(Number(agp![1]) * 100 + Number(agp![2])).toBeGreaterThanOrEqual(minimum![0] * 100 + minimum![1])
})
