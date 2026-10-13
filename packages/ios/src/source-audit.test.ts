import { afterEach, describe, expect, it } from 'bun:test'
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { assertNoApplicationSwiftSources, findApplicationSwiftSources } from './source-audit'

const roots: string[] = []
function root(): string {
  const path = mkdtempSync(join('/tmp', 'craft-swift-audit-'))
  roots.push(path)
  return path
}

afterEach(() => roots.splice(0).forEach(path => rmSync(path, { recursive: true, force: true })))

describe('application Swift source audit', () => {
  it('ignores Craft output and dependency trees but reports app-owned Swift', () => {
    const output = root()
    mkdirSync(join(output, 'storage/framework/mobile/ios'), { recursive: true })
    mkdirSync(join(output, 'node_modules/vendor'), { recursive: true })
    mkdirSync(join(output, 'src'), { recursive: true })
    writeFileSync(join(output, 'storage/framework/mobile/ios/CraftApp.swift'), '')
    writeFileSync(join(output, 'node_modules/vendor/Generated.swift'), '')
    writeFileSync(join(output, 'src/Workout.swift'), '')

    expect(findApplicationSwiftSources(output)).toEqual(['src/Workout.swift'])
    expect(() => assertNoApplicationSwiftSources(output)).toThrow('src/Workout.swift')
  })

  it('accepts an explicit generated path for projects that keep iOS output elsewhere', () => {
    const output = root()
    mkdirSync(join(output, 'ios/Sources'), { recursive: true })
    writeFileSync(join(output, 'ios/Sources/CraftApp.swift'), '')

    expect(findApplicationSwiftSources(output, { ignoredPaths: ['ios'] })).toEqual([])
    expect(() => assertNoApplicationSwiftSources(output, { ignoredPaths: ['ios'] })).not.toThrow()
  })
})
